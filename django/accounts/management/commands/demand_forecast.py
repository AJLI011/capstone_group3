from django.core.management.base import BaseCommand
from django.db.models import Sum, F
from django.db.models.functions import TruncWeek
from accounts.models import Medicine, InStoreOrderItem, OnlineOrderItem
import pandas as pd
from statsmodels.tsa.statespace.sarimax import SARIMAX

class Command(BaseCommand):
    help = 'Forecasts medicine demand using the SARIMA model from sales data.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE('Starting demand forecasting for all medicines...'))

        # Get all unique medicines to forecast for
        medicines_to_forecast = Medicine.objects.all()
        # You can limit this to a specific number if needed, e.g., .all()[:50]

        for medicine in medicines_to_forecast:
            self.stdout.write(self.style.NOTICE(f'-- Processing medicine: {medicine.name} --'))

            # --- 1. Fetch and aggregate online sales data ---
            online_sales = OnlineOrderItem.objects.filter(
                inventory_id__medicine=medicine
            ).annotate(
                week=TruncWeek('order__date_created')
            ).values('week').annotate(
                total_sales=Sum('quantity_sold')
            ).order_by('week')

            # --- 2. Fetch and aggregate in-store sales data ---
            in_store_sales = InStoreOrderItem.objects.filter(
                inventory_id__medicine=medicine
            ).annotate(
                week=TruncWeek('order__date_created')
            ).values('week').annotate(
                total_sales=Sum('quantity_sold')
            ).order_by('week')

            # --- 3. Combine both sales data into a single DataFrame ---
            online_df = pd.DataFrame(list(online_sales))
            in_store_df = pd.DataFrame(list(in_store_sales))

            if online_df.empty and in_store_df.empty:
                self.stdout.write(self.style.WARNING(f'No sales data found for {medicine.name}. Skipping...'))
                continue

            combined_df = pd.concat([online_df, in_store_df])
            combined_df.set_index('week', inplace=True)
            
            # Group by week and sum quantities
            weekly_sales = combined_df.groupby(combined_df.index)['total_sales'].sum()
            weekly_sales = weekly_sales.asfreq('W', fill_value=0) # Resample to ensure all weeks are present, filling missing with 0

            # --- 4. Fit the SARIMA model ---
            if len(weekly_sales) < 52: # Minimum data points for a seasonal model with s=52
                self.stdout.write(self.style.WARNING(f'Not enough data for a seasonal forecast for {medicine.name}. Skipping...'))
                continue
                
            order = (1, 1, 1)
            seasonal_order = (1, 1, 1, 52) 
            
            try:
                model = SARIMAX(weekly_sales,
                                order=order,
                                seasonal_order=seasonal_order,
                                enforce_stationarity=False,
                                enforce_invertibility=False)
                results = model.fit(disp=False)
                
                # --- 5. Forecast the next 4 weeks ---
                forecast_steps = 4
                forecast = results.get_forecast(steps=forecast_steps)
                forecast_df = forecast.predicted_mean.rename('forecast')
                
                # Round to nearest whole number since we can't sell half a medicine
                forecast_df = forecast_df.round().astype(int)
                
                self.stdout.write(self.style.SUCCESS(f'\nForecast for {medicine.name} for the next {forecast_steps} weeks:'))
                self.stdout.write(str(forecast_df))
                self.stdout.write(self.style.NOTICE('--------------------------------------------------'))
            
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'An error occurred while forecasting for {medicine.name}: {e}'))
            
        self.stdout.write(self.style.SUCCESS('Demand forecasting for all medicines completed.'))