import os
import django
import pandas as pd
from datetime import datetime, timedelta
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings
import pytz 
from django.conf import settings
from django.db.models import Sum, F
from django.core.management.base import BaseCommand, CommandError 

# Set up Django environment (optional/redundant in a Command class, but fine)
# Note: django.setup() is generally not needed inside the Command's handle.
# django.setup() 

from accounts.models import (
    InStoreOrder, OnlineOrder, Medicine, InStoreOrderItem,
    OnlineOrderItem, ForecastReport, ForecastItem, TotalQuantity
)

warnings.filterwarnings("ignore")

# ----------------------------------------------------------------------
# Corrected Django Management Command Class
# ----------------------------------------------------------------------
class Command(BaseCommand):
    help = 'Runs the SARIMA model to forecast demand for ALL qualifying medicines for the next week and saves the report.'

    def handle(self, *args, **options):
        """
        The main entry point for the custom management command.
        """
        # Call the ALL medicines forecast method
        self.predict_and_save_all_medicines() # <--- MODIFIED CALL

    def predict_and_save_all_medicines(self): # <--- MODIFIED METHOD NAME
        """
        Predicts demand for ALL qualifying medicines and saves the forecast to the database.
        """
        
        # Calculate the start date of the next week
        today = datetime.now()
        next_sunday = today + timedelta(days=(6 - today.weekday()))
        next_week_start_date = next_sunday.date()

        # --- Precautionary check ---
        if ForecastReport.objects.filter(week_start_date=next_week_start_date).exists():
            self.stdout.write(self.style.NOTICE(
                f"A forecast for the week of {next_week_start_date} already exists. Skipping new forecast generation."
            ))
            return
            
        self.stdout.write(self.style.SUCCESS(
            f"--- Starting new forecast generation for the week of {next_week_start_date} ---"
        ))
        
        # Define the historical data range dynamically
        manila_tz = pytz.timezone(settings.TIME_ZONE)
        end_date = next_week_start_date - timedelta(days=1)
        start_date = end_date - timedelta(days=2 * 365) # Use 2 years of history
        
        start_date_aware = manila_tz.localize(datetime.combine(start_date, datetime.min.time()))
        end_date_aware = manila_tz.localize(datetime.combine(end_date, datetime.max.time()))
        
        self.stdout.write(
            f"Fetching raw sales data from {start_date_aware.date()} to {end_date_aware.date()}..."
        )
        
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
        df.set_index('date', inplace=True)
        
        self.stdout.write("Aggregating weekly sales data using pandas...")
        weekly_sales_df = df.groupby([pd.Grouper(freq='W'), 'medicine_name']).agg(
            total_sales=('quantity_sold', 'sum')
        ).reset_index()
        
        forecasted_sales = {}
        all_medicines = Medicine.objects.values_list('name', flat=True)

        self.stdout.write("\n--- Generating weekly forecasts for each medicine... ---")
        
        for medicine_name in all_medicines:
            medicine_df = weekly_sales_df[weekly_sales_df['medicine_name'] == medicine_name].copy()
            
            # Use 52 weeks (1 year) as a minimum for weekly seasonality (52)
            if len(medicine_df) < 52: 
                continue
                
            medicine_df.set_index('date', inplace=True)

            try:
                model = SARIMAX(
                    medicine_df['total_sales'],
                    order=(0, 1, 1),
                    seasonal_order=(0, 1, 1, 52),
                    enforce_stationarity=False,
                    enforce_invertibility=False
                )
                results = model.fit(disp=False)
                
                forecast = results.get_forecast(steps=1)
                predicted_quantity = forecast.predicted_mean.iloc[0]
                
                if predicted_quantity > 0:
                    forecasted_sales[medicine_name] = predicted_quantity 
            
            except Exception as e:
                # Silently skip medicines that fail the model fitting
                pass
                
        # Sort all successfully forecasted medicines (for ranking)
        sorted_forecasts = sorted(forecasted_sales.items(), key=lambda item: item[1], reverse=True)
        
        if not sorted_forecasts:
            self.stdout.write(self.style.WARNING(
                "No forecasts could be generated. This may be due to insufficient data for the models."
            ))
            return

        # UPDATED LOG MESSAGE TO REFLECT SAVING ALL FORECASTS
        self.stdout.write(self.style.SUCCESS(
            f"\n--- Saving {len(sorted_forecasts)} generated forecasts for the week of {next_week_start_date} ---"
        ))

        try:
            report = ForecastReport.objects.create(week_start_date=next_week_start_date)
        except Exception as e:
            self.stderr.write(self.style.ERROR(
                f"Failed to create ForecastReport for {next_week_start_date}: {e}"
            ))
            return

        # KEY CHANGE: USE ALL sorted_forecasts, DO NOT SLICE TO [:10]
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
                
                # --- START: Reorder Level and Restock Logic ---
                forecasted_quantity = int(round(quantity))

                # 1. Define the Reorder Level (ROL)
                SAFETY_STOCK_PERCENTAGE = 0.30
                safety_stock = int(round(forecasted_quantity * SAFETY_STOCK_PERCENTAGE))
                reorder_level = forecasted_quantity + safety_stock

                # 2. Calculate the Restock Amount
                restock_amount = 0 
                if current_stock < reorder_level: # Only restock if stock is below ROL
                    needed_to_reach_rol = reorder_level - current_stock
                    restock_amount = max(0, needed_to_reach_rol)
                # --- END: Reorder Level and Restock Logic ---

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
                        rank=i + 1 # Rank based on overall forecast volume
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
                f"Successfully saved {len(forecast_item_objects)} forecasts to the database."
            ))
        else:
            self.stdout.write(self.style.WARNING("No forecasts to save."))