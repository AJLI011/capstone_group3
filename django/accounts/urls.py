from django.urls import path
from . import views
from .views import medicine_list, medicine_detail, order_logs_list_view
from .views import InventoryCreateView
from .views import get_inventory_list
from .views import GoodStockView, ExpiringSoonView, ExpiredView
from .views import delete_expired_batch, remove_promo, get_customer_medicines
from .views import inventory_logs, PromoMedicineView, PromoMedicineDetailView, get_customer_medicine_detail

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
    path('inventory/add/', InventoryCreateView.as_view(), name='inventory-add'), # Changed URL path and view class
    path('inventory/', get_inventory_list, name='inventory-list'), # Changed URL path and view function
    path('medicines/barcode/<str:barcode>/', views.get_medicine_by_barcode, name='get-medicine-by-barcode'),
    path('api/inventory/total-quantities/', views.total_quantities, name='total_quantities'),
    path('inventory/batches/<int:medicine_id>/', views.get_batch_details, name='inventory-batch-details'),

    # Expiration tracking
    path('medicines/good-stock/', GoodStockView.as_view(), name='good-stock'),
    path('medicines/expiring-soon/', ExpiringSoonView.as_view(), name='expiring-soon'),
    path('medicines/expired/', ExpiredView.as_view(), name='expired-medicines'),

    # Return Medicine
    path('medicines/delete/<int:pk>/', delete_expired_batch, name='delete-expired-batch'),

    # Promo Medicine
    path('inventory/<int:inventory_id>/set-promo/', views.set_promo, name='set_promo'),
    path('inventory/remove-promo/', views.remove_promo, name='remove_promo'),


    #Inventory Logs
    path('inventory-logs/', inventory_logs, name='inventory_logs'),
    
    #Sales Function
    path('sales/barcode/<str:barcode>/', views.get_item_by_barcode, name='get_item_by_barcode'),
    path('sales/process/', views.process_instore_order, name='process_instore_order'),

    #Customer Promo View
    path('medicine/promos/', PromoMedicineView.as_view(), name='promo-medicines'),

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
    
    # Order Logs
    path('order-logs/', views.order_logs_list_view, name='order-logs'),

    # Online Orders
    path('customer/<str:customer_id>/online-orders/', views.get_online_customer_orders, name='get_online_customer_orders'),
    path('customer/cancel-online-order/<int:order_id>/', views.cancel_online_order, name='cancel_online_order'),
    path('customer/online-orders/create/', views.create_online_order, name='create_online_order'),
]

