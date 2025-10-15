import os
import django
import pandas as pd
import numpy as np 
from datetime import datetime, timedelta, date
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings
import pytz 
from django.conf import settings
from django.db.models import Sum, F
from django.core.management.base import BaseCommand, CommandError 

# --- IMPORTS for Django Models ---
from accounts.models import (
    InStoreOrder, OnlineOrder, Medicine, InStoreOrderItem,
    OnlineOrderItem, ForecastReport, ForecastItem, TotalQuantity
)

warnings.filterwarnings("ignore")

# ----------------------------------------------------------------------
# 🌟 Utility Function to make Time Series Dense (FIXED - using forced timedelta)
# ----------------------------------------------------------------------
def make_ts_dense(df, start_date, end_date, medicine_name):
    """
    Creates a continuous weekly time series for a single medicine by 
    filling missing weeks within the date range with 0 sales.
    
    Uses a forced start date 104 weeks prior to end_date to ensure 
    the resulting time series is exactly 104 points long.
    """
    # 1. Create a full weekly date range
    # Calculate a start date 104 weeks prior to the end date to guarantee the length.
    forced_start_date = end_date - timedelta(weeks=104) 

    # Use 'W-SUN' to ensure the week boundaries are consistent (Sunday end).
    full_range = pd.date_range(start=forced_start_date, end=end_date, freq='W-SUN') 
    
    # 2. Filter and prepare the existing data
    medicine_df = df[df['medicine_name'] == medicine_name].copy()
    
    # Check if there's any data for this medicine
    if medicine_df.empty:
        # Return a DataFrame with the correct columns, but no data.
        return pd.DataFrame(columns=['date', 'total_sales', 'medicine_name'])
        
    medicine_df.set_index('date', inplace=True)
    
    # 3. Resample, sum, and reindex to fill missing weeks with 0
    ts = medicine_df['total_sales'].resample('W-SUN').sum().reindex(full_range, fill_value=0)
    
    # 4. Convert back to the expected DataFrame format
    result_df = ts.reset_index().rename(columns={'index': 'date', 'total_sales': 'total_sales'})
    result_df['medicine_name'] = medicine_name
    return result_df


# ----------------------------------------------------------------------
# 🌟 Symmetrical MAPE (sMAPE) Calculation Utility Function
# ----------------------------------------------------------------------
def calculate_smape(actuals, forecasts):
    """
    Calculates the Symmetrical Mean Absolute Percentage Error (sMAPE).
    """
    # Convert to NumPy arrays for vectorized operations
    A = np.array(actuals)
    F = np.array(forecasts)
    
    # Calculate the numerator: Absolute difference
    numerator = np.abs(F - A)
    
    # Calculate the denominator: Sum of absolute values
    denominator = np.abs(A) + np.abs(F)
    
    # Handle the case where both A and F are zero to prevent division by zero.
    smape_terms = np.divide(
        numerator, 
        denominator, 
        out=np.zeros_like(numerator, dtype=float), 
        where=denominator != 0
    )
    
    # Calculate sMAPE percentage
    smape = 100 * np.mean(smape_terms)
    return smape

# ----------------------------------------------------------------------
# Corrected Django Management Command Class
# ----------------------------------------------------------------------
class Command(BaseCommand):
    help = 'Runs the SARIMA model to forecast demand for ALL qualifying medicines for the next week and saves the report, including sMAPE model accuracy.'

    def handle(self, *args, **options):
        """
        The main entry point for the custom management command.
        """
        self.predict_and_save_all_medicines() 

    def validate_model_smape(self, weekly_sales_df, all_medicines):
        """
        Performs a walk-forward validation on the last 12 weeks of data 
        and reports the average sMAPE for all successful models.
        """
        self.stdout.write(self.style.NOTICE("\n--- Starting Model Validation (sMAPE Back-test on last 3 months) ---"))
        
        all_smapes = []
        
        # Define the validation size (3 months of weekly data)
        validation_size = 12 
        # Minimum required data to train (at least 1 year) + validate (3 months) = 64 weeks
        min_required_data = 52 + validation_size 

        # Iterate over all medicines to validate the model's performance
        for medicine_name in all_medicines:
            # medicine_df is now guaranteed to be continuous (filled with zeros)
            medicine_df = weekly_sales_df[weekly_sales_df['medicine_name'] == medicine_name].copy()
            
            # The length check should now pass for all products with any sales history
            if len(medicine_df) < min_required_data: 
                continue
                
            medicine_df.set_index('date', inplace=True)
            time_series = medicine_df['total_sales']
            
            # Use the last 12 weeks for the validation set
            train = time_series.iloc[:-validation_size]
            test = time_series.iloc[-validation_size:]
            
            # Walk-forward validation (predicting one step ahead 12 times)
            history = train.tolist()
            predictions = []
            
            try:
                for t in range(len(test)):
                    # Train model on current history
                    model = SARIMAX(
                        history,
                        # SARIMA(0, 1, 1)x(0, 1, 1, 52)
                        order=(0, 1, 1),
                        seasonal_order=(0, 1, 1, 52),
                        enforce_stationarity=False,
                        enforce_invertibility=False
                    )
                    # Suppress model fitting output
                    results = model.fit(disp=False) 
                    
                    # Make one-step forecast
                    output = results.forecast(steps=1)
                    yhat = output.iloc[0]
                    predictions.append(yhat)
                    
                    # Add actual observation to history for the next iteration
                    obs = test.iloc[t]
                    history.append(obs)
                
                # Calculate sMAPE for this medicine's predictions
                actuals = test.values
                smape_value = calculate_smape(actuals, predictions)
                all_smapes.append(smape_value)
                
            except Exception:
                # Silently skip medicines that fail validation (e.g., convergence error)
                pass

        if all_smapes:
            avg_smape = np.mean(all_smapes)
            self.stdout.write(self.style.SUCCESS(
                f"\n✅ Model Validation Complete: Average sMAPE across {len(all_smapes)} medicines is: {avg_smape:.2f}%"
            ))
            return avg_smape
        else:
            self.stdout.write(self.style.WARNING("No medicine had enough **continuous** data (64 weeks minimum) to perform sMAPE validation."))
            return None

    def predict_and_save_all_medicines(self): 
        """
        Predicts demand for ALL qualifying medicines and saves the forecast to the database.
        """
        
        # Calculate the start date of the next week
        today = datetime.now() 
        # Find the next Sunday
        next_sunday = today + timedelta(days=(6 - today.weekday()))
        next_week_start_date = next_sunday.date() 

        # Define the historical data range dynamically (2 years is 104 weeks)
        manila_tz = pytz.timezone(settings.TIME_ZONE)
        end_date = date(2024, 12, 31) # Fixed end date for dummy data
        start_date = end_date - timedelta(days=2 * 365) # Approx start date (2023-01-01)
        
        # Timezone-aware dates for Django ORM
        start_date_aware = manila_tz.localize(datetime.combine(start_date, datetime.min.time()))
        end_date_aware = manila_tz.localize(datetime.combine(end_date, datetime.max.time()))
        
        self.stdout.write(
            f"Fetching raw sales data from {start_date_aware.date()} to {end_date_aware.date()}..."
        )
        
        # --- Data Fetching ---
        try:
            in_store_sales = InStoreOrderItem.objects.filter(
                order__date_created__gte=start_date_aware, 
                order__date_created__lte=end_date_aware
            ).values('order__date_created', 'inventory_id__medicine__name', 'quantity_sold')

            online_sales = OnlineOrderItem.objects.filter(
                order__date_created__gte=start_date_aware,
                order__date_created__lte=end_date_aware
            ).values('order__date_created', 'inventory_id__medicine__name', 'quantity_sold')
            
            combined_sales = list(in_store_sales) + list(online_sales)
            
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"An error occurred while fetching data: {e}"))
            return

        if not combined_sales:
            self.stdout.write(self.style.WARNING("No sales data found for the specified date range. Cannot generate forecast."))
            return

        df = pd.DataFrame(combined_sales)
        df.rename(columns={'order__date_created': 'date', 'inventory_id__medicine__name': 'medicine_name'}, inplace=True)
        
        self.stdout.write("Aggregating weekly sales data using pandas...")
        # Initial aggregation of multiple sales within the same week (still sparse)
        weekly_sales_df_sparse = df.groupby([pd.Grouper(key='date', freq='W'), 'medicine_name']).agg(
            total_sales=('quantity_sold', 'sum')
        ).reset_index()
        
        all_medicines = Medicine.objects.values_list('name', flat=True)

        # ----------------------------------------------------------------------
        # 🚨 FIX: MAKE TIME SERIES DENSE 🚨
        # This resolves the sMAPE validation failure due to sparse data.
        # ----------------------------------------------------------------------
        self.stdout.write(self.style.NOTICE("Making weekly time series dense (filling zero-sales weeks)..."))
        
        processed_dfs = []
        
        for medicine_name in all_medicines:
            # Pass native date objects directly (start_date, end_date)
            dense_df = make_ts_dense(weekly_sales_df_sparse, start_date, end_date, medicine_name)
            
            # Only include if it has at least 52 weeks of sales (even if 0) 
            if len(dense_df) >= 52:
                processed_dfs.append(dense_df)

        # Combine all the dense (continuous) time series into the final DataFrame
        weekly_sales_df = pd.concat(processed_dfs, ignore_index=True)
        # ----------------------------------------------------------------------

        # ----------------------------------------------------------------------
        # 🌟 STEP 1: Run sMAPE validation and capture the result
        # ----------------------------------------------------------------------
        avg_smape = self.validate_model_smape(weekly_sales_df, all_medicines)
        # ----------------------------------------------------------------------

        forecasted_sales = {}
        
        self.stdout.write("\n--- Generating weekly forecasts for each medicine... ---")
        
        # Iterate over medicines that passed the 52-week check
        for medicine_name in weekly_sales_df['medicine_name'].unique():
            # Filter the already dense DataFrame
            medicine_df = weekly_sales_df[weekly_sales_df['medicine_name'] == medicine_name].copy()
            
            # The length is guaranteed to be >= 52 due to the check above, but we set index now.
            medicine_df.set_index('date', inplace=True)

            try:
                # SARIMAX model fitting and forecasting
                model = SARIMAX(
                    medicine_df['total_sales'],
                    order=(0, 1, 1),
                    seasonal_order=(0, 1, 1, 52),
                    enforce_stationarity=False,
                    enforce_invertibility=False
                )
                results = model.fit(disp=False)
                
                # Get one-step ahead forecast
                forecast = results.get_forecast(steps=1)
                predicted_quantity = forecast.predicted_mean.iloc[0]
                
                # Only save positive forecasts
                if predicted_quantity > 0:
                    # Use integer for the database save
                    forecasted_sales[medicine_name] = predicted_quantity 
            
            except Exception:
                # Silently skip medicines that fail the model fitting
                pass
                
        # --- Saving the Report ---
        sorted_forecasts = sorted(forecasted_sales.items(), key=lambda item: item[1], reverse=True)
        
        if not sorted_forecasts:
            self.stdout.write(self.style.WARNING(
                "No positive forecasts could be generated for any medicine."
            ))
            return

        self.stdout.write(self.style.SUCCESS(
            f"\n--- Saving {len(sorted_forecasts)} generated forecasts for the week of {next_week_start_date} ---"
        ))

        try:
            # ----------------------------------------------------------------------
            # 🌟 STEP 2: Include sMAPE in the ForecastReport creation
            # ----------------------------------------------------------------------
            report = ForecastReport.objects.create(
                week_start_date=next_week_start_date,
                model_accuracy_smape=avg_smape if avg_smape is not None else 0.0 # Save sMAPE if successful
            )
        except Exception as e:
            self.stderr.write(self.style.ERROR(
                f"Failed to create ForecastReport for {next_week_start_date}: {e}"
            ))
            return

        all_successful_forecasts = sorted_forecasts 
        forecast_item_objects = []

        # Fetch all current stocks in a single query for efficiency
        medicine_quantities = {
            item.medicine_id: item.total_quantity 
            for item in TotalQuantity.objects.all()
        }

        # Loop through ALL successful forecasts
        for i, (medicine_name, quantity) in enumerate(all_successful_forecasts):
            try:
                medicine_obj = Medicine.objects.get(name=medicine_name)
                current_stock = medicine_quantities.get(medicine_obj.pk, 0)
                
                # --- Reorder Level and Restock Logic ---
                forecasted_quantity = int(round(quantity))

                # 1. Define the Reorder Level (ROL)
                SAFETY_STOCK_PERCENTAGE = 0.30
                safety_stock = int(round(forecasted_quantity * SAFETY_STOCK_PERCENTAGE))
                reorder_level = forecasted_quantity + safety_stock

                # 2. Calculate the Restock Amount
                restock_amount = 0 
                if current_stock < reorder_level: 
                    needed_to_reach_rol = reorder_level - current_stock
                    restock_amount = max(0, needed_to_reach_rol)
                # --- End Logic ---

                forecast_item_objects.append(
                    ForecastItem(
                        forecast_report=report,
                        medicine=medicine_obj,
                        medicine_name=medicine_obj.name, 
                        generic_name=medicine_obj.generic_name,
                        forecasted_quantity=forecasted_quantity,
                        current_stock=current_stock,
                        restock_amount=restock_amount,
                        reorder_level=reorder_level,
                        rank=i + 1
                    )
                )
            except Medicine.DoesNotExist:
                self.stdout.write(self.style.WARNING(
                    f"Warning: Medicine '{medicine_name}' not found in the database. Skipping."
                ))
                continue
        
        if forecast_item_objects:
            ForecastItem.objects.bulk_create(forecast_item_objects)
            self.stdout.write(self.style.SUCCESS(
                f"Successfully saved {len(forecast_item_objects)} forecasts and the sMAPE result to the database."
            ))
        else:
            self.stdout.write(self.style.WARNING("No forecasts to save."))