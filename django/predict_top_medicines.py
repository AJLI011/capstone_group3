import os
import django
import pandas as pd
from datetime import datetime
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings') 
django.setup()

from accounts.models import InStoreOrder, OnlineOrder, Medicine

# Ignore harmless warnings from the model fitting process
warnings.filterwarnings("ignore")

def predict_top_medicines():
    """
    Predicts the top-selling medicines for the first week of 2025.
    """
    print("--- Starting top-selling medicines prediction for Week 1, 2025 ---")
    
    start_date = datetime(2023, 1, 1)
    end_date = datetime(2024, 12, 31)

    sales_data = []

    try:
        # Fetch all InStoreOrder objects in the date range
        in_store_orders = InStoreOrder.objects.filter(date_created__date__range=(start_date, end_date))
        
        # Now, loop through the orders and get their related items using the correct 'items' related_name
        for order in in_store_orders:
            for item in order.items.all():
                medicine_name = item.inventory_id.medicine.name
                sales_data.append({
                    'date': order.date_created,
                    'medicine_name': medicine_name,
                    'quantity': item.quantity_sold
                })

    except Exception as e:
        print(f"An error occurred while fetching InStoreOrder data: {e}")
        return

    try:
        # Fetch all OnlineOrder objects in the date range
        online_orders = OnlineOrder.objects.filter(date_created__date__range=(start_date, end_date))
        
        # Now, loop through the orders and get their related items using the correct 'items' related_name
        for order in online_orders:
            for item in order.items.all():
                medicine_name = item.inventory_id.medicine.name
                sales_data.append({
                    'date': order.date_created,
                    'medicine_name': medicine_name,
                    'quantity': item.quantity_sold
                })
            
    except Exception as e:
        print(f"An error occurred while fetching OnlineOrder data: {e}")
        return
    
    if not sales_data:
        print("No sales data found for 2023-2024. Please ensure your database is populated.")
        return

    df = pd.DataFrame(sales_data)
    df['date'] = pd.to_datetime(df['date'])
    df.set_index('date', inplace=True)
    
    # Aggregate sales data on a weekly basis for each medicine
    weekly_sales = df.groupby([pd.Grouper(freq='W'), 'medicine_name'])['quantity'].sum().reset_index()
    
    # Store forecasts for each medicine
    forecasted_sales = {}
    
    all_medicines = Medicine.objects.values_list('name', flat=True)

    print("\n--- Generating weekly forecasts for each medicine... ---")
    
    for medicine_name in all_medicines:
        # Get weekly sales data for the current medicine
        medicine_df = weekly_sales[weekly_sales['medicine_name'] == medicine_name].copy()
        
        # Check if there is enough data for forecasting
        if len(medicine_df) < 20: 
            continue

        medicine_df.set_index('date', inplace=True)
        medicine_df.index.freq = 'W'
        
        # Use a simple SARIMA model for weekly data
        try:
            model = SARIMAX(
                medicine_df['quantity'],
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
            pass
            
    # Sort medicines by their forecasted sales in descending order
    sorted_forecasts = sorted(forecasted_sales.items(), key=lambda item: item[1], reverse=True)
    
    print("\n--- Top 10 Most Sold Medicines Forecast for Week 1, 2025 ---")
    
    # Print the top 10 results
    for i, (medicine, quantity) in enumerate(sorted_forecasts[:10]):
        print(f"{i+1}. {medicine}: {int(round(quantity))} units")

if __name__ == '__main__':
    predict_top_medicines()