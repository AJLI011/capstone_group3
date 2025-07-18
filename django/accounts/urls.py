from django.urls import path
from . import views
from .views import medicine_list 
from .views import medicine_list, medicine_detail 

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
]
