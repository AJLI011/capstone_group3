# C:\Users\Aaron\Desktop\capstone_group3\django\accounts\management\commands\predict_top_medicines.py

import os
import django
import pandas as pd
from datetime import datetime, timedelta
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings
import pytz 
from django.conf import settings
from django.db.models import Sum, F
from django.core.management.base import BaseCommand, CommandError # <-- NEW IMPORT

# Set up Django environment
# NOTE: In a management command, django.setup() is usually not needed here, 
# but keeping it won't hurt if the file is occasionally run standalone.
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings') 
# The next line is often unnecessary inside a Command's handle method
# django.setup() 

# UPDATED IMPORT: Added TotalQuantity model
from accounts.models import (
    InStoreOrder, OnlineOrder, Medicine, InStoreOrderItem,
    OnlineOrderItem, ForecastReport, ForecastItem, TotalQuantity
)

warnings.filterwarnings("ignore")

# ----------------------------------------------------------------------
# NEW: Define the Command Class
# ----------------------------------------------------------------------
class Command(BaseCommand):
    help = 'Runs the SARIMA model to forecast top medicine demands for the next week and saves the report.'

    def handle(self, *args, **options):
        """
        The main entry point for the custom management command.
        """
        # The logic of your original predict_and_save_top_medicines function goes here.
        self.predict_and_save_top_medicines()

    def predict_and_save_top_medicines(self):
        """
        Predicts the top-selling medicines and saves the forecast to the database.
        This script is designed to be run weekly and will always forecast the upcoming week.
        """
        # Use self.stdout.write instead of print for proper Django command output
        
        # Calculate the start date of the next week
        today = datetime.now()
        # Find the next Sunday (the start of the week in pandas' 'W' frequency)
        next_sunday = today + timedelta(days=(6 - today.weekday()))
        next_week_start_date = next_sunday.date()

        # --- Precautionary check at the very beginning of the script ---
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
        start_date = end_date - timedelta(days=2 * 365) # Use 2 years of history before the forecast date
        
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
        # Note: Use the index of the dataframe for Grouper, which is 'date' after set_index
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
                
                # Forecast the next period after the last index date
                forecast = results.get_forecast(steps=1)
                predicted_quantity = forecast.predicted_mean.iloc[0]
                
                if predicted_quantity > 0:
                    # Save the raw forecasted number before rounding
                    forecasted_sales[medicine_name] = predicted_quantity 
            
            except Exception as e:
                # Optionally log the medicine that failed if needed, but 'pass' is fine for known SARIMA fitting issues
                # self.stderr.write(f"SARIMA failed for {medicine_name}: {e}")
                pass
                
        sorted_forecasts = sorted(forecasted_sales.items(), key=lambda item: item[1], reverse=True)
        
        if not sorted_forecasts:
            self.stdout.write(self.style.WARNING(
                "No forecasts could be generated. This may be due to insufficient data for the models."
            ))
            return

        self.stdout.write(self.style.SUCCESS(
            f"\n--- Saving top 10 forecasts for the week of {next_week_start_date} ---"
        ))

        try:
            report = ForecastReport.objects.create(week_start_date=next_week_start_date)
        except Exception as e:
            self.stderr.write(self.style.ERROR(
                f"Failed to create ForecastReport for {next_week_start_date}: {e}"
            ))
            return

        top_10_forecasts = sorted_forecasts[:10]
        forecast_item_objects = []

        # Fetch all current stocks in a single query for efficiency
        medicine_quantities = {
            item.medicine_id: item.total_quantity 
            for item in TotalQuantity.objects.all()
        }

        for i, (medicine_name, quantity) in enumerate(top_10_forecasts):
            try:
                # Get medicine object (or use select_related/prefetch_related if doing more than just pk lookup)
                medicine_obj = Medicine.objects.get(name=medicine_name)
                
                # Get the current stock from the pre-fetched dictionary
                current_stock = medicine_quantities.get(medicine_obj.pk, 0)
                
                # Calculate the restock amount
                forecasted_quantity = int(round(quantity))
                # Restock amount is how much needs to be ordered to meet the forecast
                restock_amount = max(0, forecasted_quantity - current_stock) 

                forecast_item_objects.append(
                    ForecastItem(
                        forecast_report=report,
                        medicine=medicine_obj,
                        # Added the snapshot fields here
                        medicine_name=medicine_obj.name, 
                        generic_name=medicine_obj.generic_name,
                        # End added fields
                        forecasted_quantity=forecasted_quantity,
                        current_stock=current_stock,
                        restock_amount=restock_amount,
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
            self.stdout.write(self.style.SUCCESS("Forecasts saved to the database successfully."))
        else:
            self.stdout.write(self.style.WARNING("No forecasts to save."))

# ----------------------------------------------------------------------
# REMOVED: The if __name__ == '__main__': block
# Django's management utility handles execution through the Command class.
# ----------------------------------------------------------------------