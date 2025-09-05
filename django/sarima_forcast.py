import pandas as pd
import matplotlib.pyplot as plt
from statsmodels.tsa.seasonal import seasonal_decompose
from statsmodels.tsa.statespace.sarimax import SARIMAX
import warnings
import os

# Use a non-GUI backend to prevent TclError
plt.switch_backend('Agg')

# Ignore harmless warnings
warnings.filterwarnings("ignore")

def sarima_forecast():
    """Performs time series analysis and SARIMA forecasting on daily sales data."""

    # Load the daily sales data from the CSV file
    df = pd.read_csv('daily_sales_data.csv')

    # Set the 'date' column as the index and convert it to a datetime object
    df['date'] = pd.to_datetime(df['date'])
    df.set_index('date', inplace=True)
    df.index.freq = 'D'  # Set the frequency to daily

    print("--- Time Series Data Loaded ---")
    print(df.head())
    
    # 1. Visualize the raw data
    plt.figure(figsize=(12, 6))
    df['order_count'].plot(title='Daily Order Count (2023-2024)')
    plt.xlabel('Date')
    plt.ylabel('Order Count')
    plt.savefig('daily_order_count_plot.png')
    plt.close()

    # 2. Decompose the time series
    # m=7 as we expect a weekly seasonality (sales fluctuations on weekdays vs. weekends)
    decomposition = seasonal_decompose(df['order_count'], model='additive', period=7)
    
    # Plot the decomposed components
    fig = decomposition.plot()
    fig.set_size_inches(12, 8)
    fig.savefig('time_series_decomposition.png')
    plt.close()

    # 3. Determine SARIMA parameters
    # The decomposition plot suggests a seasonal period of 7 days (m=7).
    # Based on the plots:
    # d=1 might be needed if there's a strong trend. The plot shows a slight trend.
    # D=1 is likely needed due to the clear weekly seasonality.
    # For p, q, P, Q, we can start with common values or a grid search.
    # For this example, we'll use a simple set of parameters as a starting point.
    
    # SARIMA(p, d, q)(P, D, Q)m
    # We will use SARIMA(1, 1, 1)(1, 1, 1, 7)
    
    # 4. Build and fit the SARIMA model
    print("\n--- Fitting the SARIMA model... This may take a few moments. ---")
    model = SARIMAX(df['order_count'], order=(1, 1, 1), seasonal_order=(1, 1, 1, 7))
    results = model.fit(disp=False)
    print("\n--- Model Summary ---")
    print(results.summary())

    # 5. Forecast future demand
    # Forecast for the next 30 days
    n_forecast = 30
    forecast = results.get_forecast(steps=n_forecast)
    forecast_df = forecast.summary_frame(alpha=0.05)

    # Plot the forecast
    plt.figure(figsize=(12, 6))
    df['order_count'].plot(label='Historical Data')
    forecast.predicted_mean.plot(label='Forecasted Orders')
    
    # Use integer index to access confidence interval columns
    lower_ci = forecast_df.iloc[:, 1]
    upper_ci = forecast_df.iloc[:, 2]

    plt.fill_between(forecast_df.index,
                     lower_ci,
                     upper_ci,
                     color='k', alpha=.15, label='95% Confidence Interval')

    plt.title(f'Daily Order Count Forecast for the Next {n_forecast} Days')
    plt.xlabel('Date')
    plt.ylabel('Order Count')
    plt.legend()
    plt.savefig('demand_forecast_plot.png')
    plt.close()
    
    print(f"\n--- Forecast for the next {n_forecast} days ---")
    print(forecast_df)

if __name__ == '__main__':
    sarima_forecast()