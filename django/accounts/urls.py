# urls.py

#--paths lang binago pero 10/31/25
from django.urls import path
from . import views
from .views import (
    medicine_list, medicine_detail,InventoryCreateView,get_inventory_list,GoodStockView, ExpiringSoonView, ExpiredView,
    remove_promo, get_customer_medicines,inventory_logs, PromoMedicineView, PromoMedicineDetailView, 
    get_customer_medicine_detail,InStoreSalesReportView,OnlineSalesReportView, LatestForecastReportView, MedicineSalesHistoryView, 
    OrderLogsListView, UnaddressedExpiringStockView, MedicineForecastByNameView, # PurchaseRequestListView REMOVED
    PurchaseRequestView
    
)
from .views import get_comprehensive_transaction_report

urlpatterns = [
    # Authentication
    path('register/', views.register_customer),
    path('login/', views.login_user),
    path('forgot-password/', views.forgot_password),
    path('reset-password/<str:token>/', views.reset_password, name='reset-password'),

    #-------------admin features--------------
    # Customers
    path('customers/', views.get_all_customers),
    path('customers/<int:customer_id>/', views.customer_detail),

    # Suppliers
    path('suppliers/', views.supplier_list),
    path('suppliers/<int:pk>/', views.supplier_detail),

    # Staff / Employees
    path('staff/', views.get_all_staff),
    path('staff/<int:staff_id>/', views.staff_detail),

    # Admin profile (GET and PUT by ID)
    path('staff/<int:staff_id>/profile/', views.get_staff_profile, name='get_staff_profile'),
    path('staff/<int:staff_id>/update-profile/', views.update_staff_profile, name='update_staff_profile'),
    path('staff/<int:staff_id>/change-password/', views.change_staff_password, name='change_staff_password'),
    
    #----------------manager features----------------
    #medicines list
    path('medicines/', medicine_list, name='medicine-list'),
    path('medicines/<int:pk>/', medicine_detail, name='medicine-detail'), 

    # ─────────── INVENTORY / RESTOCKING API ─────────── # Renamed comment
    path('inventory/add/', InventoryCreateView.as_view(), name='inventory-add'), 
    path('inventory/', get_inventory_list, name='inventory-list'),
    path('medicines/barcode/<str:barcode>/', views.get_medicine_by_barcode, name='get-medicine-by-barcode'),
    path('inventory/total-quantities/', views.total_quantities, name='total_quantities'), 
    path('inventory/batches/<int:medicine_id>/', views.get_batch_details, name='inventory-batch-details'),

    # Expiration tracking
    path('medicines/good-stock/', GoodStockView.as_view(), name='good-stock'),
    path('medicines/expiring-soon/', ExpiringSoonView.as_view(), name='expiring-soon'),
    path('medicines/expiring-soon/unaddressed/', UnaddressedExpiringStockView.as_view(), name='unaddressed-expiring-soon'),
    path('medicines/expired/', ExpiredView.as_view(), name='expired-medicines'),


    # Return Medicine
    path('medicines/delete/<int:pk>/', views.delete_expired_batch, name='delete-expired-batch'),
    path('medicines/batch_delete/', views.delete_expired_medicines_batch, name='delete-expired-medicines-batch'),
    path('returns/upload-verification/', views.upload_return_verification_images, name='upload_verification'),
    path('returns/<int:transaction_id>/items/', views.get_returned_transaction_items, name='get_transaction_items'),
    path('returns/pending/', views.list_pending_returns, name='list_pending_returns'), 
    path('returns/all/', views.list_all_return_transactions, name='list_all_return_transactions'), 

    # Promo Medicine
    path('inventory/<int:inventory_id>/set-promo/', views.set_promo, name='set_promo'),
    path('inventory/remove-promo/', views.remove_promo, name='remove_promo'),
    path('promos/ending-soon/', views.promos_ending_soon, name='promos-ending-soon'), 

    #Inventory Logs
    path('inventory-logs/', inventory_logs, name='inventory_logs'),
    
    #Sales Function (instore)
    path('sales/barcode/<str:barcode>/', views.get_item_by_barcode, name='get_item_by_barcode'),
    path('sales/process/', views.process_instore_order, name='process_instore_order'),

    #Customer Promo View
    path('medicine/promos/', PromoMedicineView.as_view(), name='promo-medicines'),
    path('medicine/promos/<int:pk>/', PromoMedicineDetailView.as_view(), name='promo-medicine-detail'),

    # Customer Medicine View
    path('customer/medicines/', get_customer_medicines),
    path('customer/medicines/<int:pk>/', get_customer_medicine_detail),
    
    #employee logs
    path('employee-logs/', views.employee_logs_view, name='employee-logs'),
    
    #pending order
    path('sales/pending-orders/', views.InStoreOrderProcessingView.as_view(), name='pending-orders'),
    path('sales/pending-orders/<int:order_id>/', views.InStoreOrderProcessingView.as_view(), name='process-pending-order'),
    path('sales/order-items/<int:item_id>/', views.InStoreOrderItemDeleteView.as_view(), name='delete-order-item'),
    
    # Order Logs
    path('order-logs/', OrderLogsListView.as_view(), name='order-logs'),

    # Online Orders
    path('customer/<str:customer_id>/online-orders/', views.get_online_customer_orders, name='get_online_customer_orders'),
    path('customer/cancel-online-order/<int:order_id>/', views.cancel_online_order, name='cancel_online_order'),
    path('customer/online-orders/create/', views.create_online_order, name='create_online_order'),
    
    #Staff Online Orders
    path('staff/online-orders/', views.get_pending_online_orders, name='staff-pending-orders'),
    path('staff/confirm-online-order/<int:orderId>/', views.confirm_online_order, name='staff-confirm-order'),

    # Cashier Online Orders
    path('cashier/online-orders/', views.get_pending_online_orders, name='cashier-pending-orders'),
    path('cashier/confirm-online-order/<int:orderId>/', views.confirm_online_order, name='cashier-confirm-order'),
    path('cashier/online-orders/<int:orderId>/update-discount/', views.update_order_discount, name='cashier-update-order-discount'),
    path('cashier/online-orders/<int:orderId>/items/<int:itemId>/', views.remove_online_order_item, name='cashier-remove-online-order-item'),
    path('cashier/online-orders/<int:orderId>/cancel/', views.cancel_online_order_cashier, name='cashier-cancel-online-order'),
    path('cashier/online-orders/<int:orderId>/finalize/', views.finalize_online_order, name='cashier-finalize-online-order'),
    
    #instore sales transaction
    path('in-store-transactions/', views.InStoreSalesTransactionView.as_view(), name='in-store-transactions'),

    #instore sales report
    path('in-store-sales-report/', InStoreSalesReportView.as_view(), name='in-store-sales-report'),

    # Online Sales Transaction
    path('manager/completed-online-orders/', views.completed_online_orders_report, name='completed-online-orders-report'),
    path('cashier/completed-online-orders/', views.completed_online_orders_report, name='cashier-online-orders-report'),
    
    #Online Sales Report
    path('online-sales-report/', OnlineSalesReportView.as_view(), name='online-sales-report'),

   #--------------------09/14/2025--------------------------- fixing return medicine
    #Fetching Sales Transactions and Reports of Returned Medicines
    path('transactions/report/', views.get_comprehensive_transaction_report, name='comprehensive-report'),


    # ─────────── PRESCRIPTION SALES VIEW ───────────
    #--------STAFF PESCRIPTION VIEWS----------
    path('prescriptions/pending/', views.list_all_pending_prescriptions, name='list_all_pending_prescriptions'),
    
    # New URL for image uploads
    path('prescriptions/<int:pk>/upload-images/', views.upload_prescription_images, name='upload-prescription-images'),
    
    #--------CASHIER PRESCRIPTION VIEWS--------
    path('prescriptions/cashier/', views.list_cashier_prescriptions, name='list_cashier_prescriptions'),
    
    # ----------------- Customer FCM Token -----------------
    path('customer/save-fcm-token/', views.save_customer_fcm_token, name='save_customer_fcm_token'),
    
    #--------for DASHBOARD
    path('sales/total-earnings/', views.total_combined_earnings, name='total_combined_earnings'),
    path('medicines/low-stock/', views.low_stock_list, name='low_stock_list'),
    path('medicines/total/', views.total_medicine_count, name='total-medicines'),

    #--------for DEMAND FORECASTING
    path('forecast/latest/', LatestForecastReportView.as_view(), name='latest-forecast'),
    path('forecast/history/<int:medicine_id>/', MedicineSalesHistoryView.as_view(), name='medicine-sales-history'),
    path('forecast/generate/', views.generate_forecast_report, name='generate_forecast'), 
    path('forecast/medicine/', MedicineForecastByNameView.as_view(), name='search_medicine_forecast'),



   # Make sure to import the new view class: from .views import PurchaseRequestView
    path('purchase-request/', PurchaseRequestView.as_view(), name='purchase-request'),
    
    #----------EXPIRY NOTIFICATION
    # API endpoint to save staff FCM tokens
    path('save-staff-fcm-token/', views.save_staff_fcm_token, name='save_staff_fcm_token'),
    
    #medicines_list new url for ensuring one barcode for medicine and no duplication:
    path('medicines/check_barcode/<str:barcode>/', views.check_barcode_existence, name='check_barcode_existence'),
    
    
    #daily reports
    path('daily-reports/', views.DailyReportsView.as_view(), name='daily_reports'),
]