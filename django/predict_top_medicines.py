import os
import django
import pandas as pd
from datetime import datetime
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings
import pytz 
from django.conf import settings
from django.db.models import Sum, F

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings') 
django.setup()

from accounts.models import InStoreOrder, OnlineOrder, Medicine, InStoreOrderItem, OnlineOrderItem

# Ignore harmless warnings from the model fitting process
warnings.filterwarnings("ignore")

def predict_top_medicines():
    """
    Predicts the top-selling medicines for the first week of 2025.
    """
    print("--- Starting top-selling medicines prediction for Week 1, 2025 ---")
    
    # Define the date range and make it timezone-aware
    manila_tz = pytz.timezone(settings.TIME_ZONE)
    start_date = manila_tz.localize(datetime(2023, 1, 1))
    end_date = manila_tz.localize(datetime(2024, 12, 31))
    
    try:
        # Use Django ORM to fetch the raw data needed for analysis
        print("Fetching raw sales data from the database...")
        in_store_sales = InStoreOrderItem.objects.filter(
            order__date_created__gte=start_date, 
            order__date_created__lte=end_date
        ).values('order__date_created', 'inventory_id__medicine__name', 'quantity_sold')

        online_sales = OnlineOrderItem.objects.filter(
            order__date_created__gte=start_date,
            order__date_created__lte=end_date
        ).values('order__date_created', 'inventory_id__medicine__name', 'quantity_sold')
        
        # Combine the querysets and convert to a pandas DataFrame
        combined_sales = list(in_store_sales) + list(online_sales)
        
    except Exception as e:
        print(f"An error occurred while fetching data: {e}")
        return

    if not combined_sales:
        print("No sales data found for 2023-2024. Please ensure your database is populated.")
        return

    df = pd.DataFrame(combined_sales)
    df.rename(columns={'order__date_created': 'date', 'inventory_id__medicine__name': 'medicine_name'}, inplace=True)
    df.set_index('date', inplace=True)
    
    # Group the DataFrame by week and medicine name to get weekly sales
    print("Aggregating weekly sales data using pandas...")
    weekly_sales_df = df.groupby([pd.Grouper(freq='W'), 'medicine_name']).agg(
        total_sales=('quantity_sold', 'sum')
    ).reset_index()
    
    # Store forecasts for each medicine
    forecasted_sales = {}
    
    all_medicines = Medicine.objects.values_list('name', flat=True)

    print("\n--- Generating weekly forecasts for each medicine... ---")
    
    for medicine_name in all_medicines:
        # Get weekly sales data for the current medicine
        medicine_df = weekly_sales_df[weekly_sales_df['medicine_name'] == medicine_name].copy()
        
        # Check if there is enough data for forecasting
        if len(medicine_df) < 20: 
            continue
            
        medicine_df.set_index('date', inplace=True)

        # Use a simple SARIMA model for weekly data
        try:
            model = SARIMAX(
                medicine_df['total_sales'],
                order=(0, 1, 1),
                seasonal_order=(0, 1, 1, 52),
                enforce_stationarity=False,
                enforce_invertibility=False
            )
            results = model.fit(disp=False)
            
            # Forecast the quantity for the next 1 week
            forecast = results.get_forecast(steps=1)
            predicted_quantity = forecast.predicted_mean.iloc[0]
            
            # Ensure the forecast is not negative
            if predicted_quantity > 0:
                forecasted_sales[medicine_name] = predicted_quantity
        
        except Exception as e:
            print(f"Could not fit model for {medicine_name}: {e}") # Uncomment for debugging
            pass
            
    # Sort medicines by their forecasted sales in descending order
    sorted_forecasts = sorted(forecasted_sales.items(), key=lambda item: item[1], reverse=True)
    
    print("\n--- Top 10 Most Sold Medicines Forecast for Week 1, 2025 ---")
    
    if not sorted_forecasts:
        print("No forecasts could be generated. This may be due to insufficient data for the models.")
    else:
        # Print the top 10 results
        for i, (medicine, quantity) in enumerate(sorted_forecasts[:10]):
            print(f"{i+1}. {medicine}: {int(round(quantity))} units")

if __name__ == '__main__':
    predict_top_medicines()