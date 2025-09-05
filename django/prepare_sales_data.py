import os
import django
import pandas as pd
from datetime import datetime, timedelta
import pytz 
from django.conf import settings

# Set up Django environment
# IMPORTANT: Replace 'your_project_name.settings' with the name of your Django project.
# For example, if your project is named 'pharmacy_system', this line should be:
# os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'pharmacy_system.settings')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from accounts.models import InStoreOrder, OnlineOrder

def aggregate_sales_data():
    """Aggregates daily order data from InStoreOrder and OnlineOrder models
    for the years 2023 and 2024 and saves it to a CSV file."""
    
    print("Fetching and aggregating sales data for 2023-2024...")
    
    # Get the project's timezone from Django settings
    manila_tz = pytz.timezone(settings.TIME_ZONE)
    
    # Make the start and end dates timezone-aware
    start_date = manila_tz.localize(datetime(2023, 1, 1))
    end_date = manila_tz.localize(datetime(2024, 12, 31))

    # Filter orders using timezone-aware datetimes
    in_store_orders = InStoreOrder.objects.filter(date_created__gte=start_date, date_created__lte=end_date)
    online_orders = OnlineOrder.objects.filter(date_created__gte=start_date, date_created__lte=end_date)
    
    combined_orders = []
    for order in in_store_orders:
        combined_orders.append({'date': order.date_created.date()})
    
    for order in online_orders:
        combined_orders.append({'date': order.date_created.date()})

    # Create a pandas DataFrame from the combined data
    df = pd.DataFrame(combined_orders)
    
    # Aggregate by day
    daily_orders = df.groupby('date').size().reset_index(name='order_count')
    
    # Fill in any missing dates with zero orders to create a complete time series
    date_range = pd.date_range(start=start_date.date(), end=end_date.date())
    daily_orders['date'] = pd.to_datetime(daily_orders['date'])
    daily_orders = daily_orders.set_index('date').reindex(date_range).fillna(0).rename_axis('date').reset_index()
    daily_orders['order_count'] = daily_orders['order_count'].astype(int)

    # Save to a CSV file
    csv_file_path = 'daily_sales_data.csv'
    daily_orders.to_csv(csv_file_path, index=False)
    
    print(f"\nSales data successfully aggregated and saved to '{csv_file_path}'.")
    print("Ready for time-series forecasting!")
    print("\n--- Aggregated Data Preview ---")
    print(daily_orders.head())
    print("\n-------------------------------\n")

if __name__ == '__main__':
    aggregate_sales_data()