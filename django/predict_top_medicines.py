import os
import django
import pandas as pd
from datetime import datetime, timedelta
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings
import pytz 
from django.conf import settings
from django.db.models import Sum, F

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings') 
django.setup()

from accounts.models import InStoreOrder, OnlineOrder, Medicine, InStoreOrderItem, OnlineOrderItem, ForecastReport, ForecastItem

warnings.filterwarnings("ignore")

def predict_and_save_top_medicines(forecast_date=None):
    """
    Predicts the top-selling medicines and saves the forecast to the database.
    
    Args:
        forecast_date (datetime.date, optional): A specific date to forecast for. 
            If not provided, the script will forecast for the next upcoming week.
    """
    if forecast_date:
        print(f"\n--- Running in TEST mode for forecast date: {forecast_date} ---")
        today_for_forecast = forecast_date
    else:
        today_for_forecast = datetime.now()

    # Calculate the start date of the week to forecast
    # This logic remains dynamic based on the provided date or current date
    next_sunday = today_for_forecast + timedelta(days=(6 - today_for_forecast.weekday()))
    next_week_start_date = next_sunday.date()

    # --- Precautionary check at the very beginning of the script ---
    if ForecastReport.objects.filter(week_start_date=next_week_start_date).exists():
        print(f"A forecast for the week of {next_week_start_date} already exists. Skipping new forecast generation.")
        return
        
    print(f"--- Starting new forecast generation for the week of {next_week_start_date} ---")
    
    # Define the historical data range dynamically
    manila_tz = pytz.timezone(settings.TIME_ZONE)
    end_date = next_week_start_date - timedelta(days=1)
    start_date = end_date - timedelta(days=2 * 365) # Use 2 years of history before the forecast date
    
    start_date = manila_tz.localize(datetime.combine(start_date, datetime.min.time()))
    end_date = manila_tz.localize(datetime.combine(end_date, datetime.max.time()))
    
    print(f"Fetching raw sales data from {start_date.date()} to {end_date.date()}...")
    
    try:
        in_store_sales = InStoreOrderItem.objects.filter(
            order__date_created__gte=start_date, 
            order__date_created__lte=end_date
        ).values('order__date_created', 'inventory_id__medicine__name', 'quantity_sold')

        online_sales = OnlineOrderItem.objects.filter(
            order__date_created__gte=start_date,
            order__date_created__lte=end_date
        ).values('order__date_created', 'inventory_id__medicine__name', 'quantity_sold')
        
        combined_sales = list(in_store_sales) + list(online_sales)
        
    except Exception as e:
        print(f"An error occurred while fetching data: {e}")
        return

    if not combined_sales:
        print("No sales data found for the specified date range.")
        return

    df = pd.DataFrame(combined_sales)
    df.rename(columns={'order__date_created': 'date', 'inventory_id__medicine__name': 'medicine_name'}, inplace=True)
    df.set_index('date', inplace=True)
    
    print("Aggregating weekly sales data using pandas...")
    weekly_sales_df = df.groupby([pd.Grouper(freq='W'), 'medicine_name']).agg(
        total_sales=('quantity_sold', 'sum')
    ).reset_index()
    
    forecasted_sales = {}
    all_medicines = Medicine.objects.values_list('name', flat=True)

    print("\n--- Generating weekly forecasts for each medicine... ---")
    
    for medicine_name in all_medicines:
        medicine_df = weekly_sales_df[weekly_sales_df['medicine_name'] == medicine_name].copy()
        
        if len(medicine_df) < 20: 
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
            
            # Forecast for the next 1 week
            forecast = results.get_forecast(steps=1)
            predicted_quantity = forecast.predicted_mean.iloc[0]
            
            if predicted_quantity > 0:
                forecasted_sales[medicine_name] = predicted_quantity
        
        except Exception as e:
            pass
            
    sorted_forecasts = sorted(forecasted_sales.items(), key=lambda item: item[1], reverse=True)
    
    if not sorted_forecasts:
        print("No forecasts could be generated. This may be due to insufficient data for the models.")
        return

    print(f"\n--- Saving top 10 forecasts for the week of {next_week_start_date} ---")

    try:
        report = ForecastReport.objects.create(week_start_date=next_week_start_date)
    except Exception as e:
        print(f"Failed to create ForecastReport for {next_week_start_date}: {e}")
        return

    top_10_forecasts = sorted_forecasts[:10]
    forecast_item_objects = []
    
    for i, (medicine_name, quantity) in enumerate(top_10_forecasts):
        try:
            medicine_obj = Medicine.objects.get(name=medicine_name)
            
            forecast_item_objects.append(
                ForecastItem(
                    forecast_report=report,
                    medicine=medicine_obj,
                    forecasted_quantity=int(round(quantity)),
                    rank=i + 1
                )
            )
        except Medicine.DoesNotExist:
            print(f"Warning: Medicine '{medicine_name}' not found in the database. Skipping.")
            continue
    
    if forecast_item_objects:
        ForecastItem.objects.bulk_create(forecast_item_objects)
        print("Forecasts saved to the database successfully.")
    else:
        print("No forecasts to save.")

if __name__ == '__main__':
    # --- Example of how to call it dynamically ---
    # To run for the upcoming week (production mode)
    predict_and_save_top_medicines(datetime(2025,9,14))
    
    # To run for a specific week in the past or future (testing mode)
    # Uncomment the line below to test a specific date
    # Make sure to run `python manage.py makemigrations` and `python manage.py migrate` again if you are changing your models.
    # predict_and_save_top_medicines(datetime(2025, 1, 1))