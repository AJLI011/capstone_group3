import uuid
import logging
import pandas as pd

#===========9/13/25 elton
from .pagination import InventoryLogPagination
#9/15/25 elton
from rest_framework.generics import ListAPIView
from .pagination import PromoMedicinePagination


from datetime import date, timedelta, datetime
from decimal import Decimal

from django.db import transaction
from django.conf import settings
from django.core.mail import send_mail
from django.core.management import call_command
from django.http import JsonResponse, HttpResponseNotFound, HttpResponse
from django.shortcuts import render, get_object_or_404
from django.utils import timezone
from django.db.models import F, Prefetch, DecimalField, Sum, Q, OuterRef, Subquery
from django.contrib.auth.hashers import check_password, make_password
from django.db.models import Count

from rest_framework import serializers, status, generics
from rest_framework.decorators import api_view, authentication_classes, permission_classes, parser_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.views import APIView

from .models import (
    Customer, Staff, Supplier, Medicine, Inventory, TotalQuantity, Promo, 
    InventoryLog, EmployeeLog, InStoreOrder, InStoreOrderItem, OrderLog, 
    OnlineOrder, OnlineOrderItem, Prescription, PrescriptionImage,
    CustomerFCMToken, ForecastReport, ForecastItem, StaffFCMToken, ReturnedMedicine
)
from .serializers import (
    CustomerSerializer, StaffSerializer, SupplierSerializer, PromoSerializer,
    InventoryDashboardSerializer, MedicineSerializer, InventoryCreateSerializer, 
    InventorySerializer, InventoryListSerializer, InventoryBatchDetailSerializer, 
    TotalQuantitySerializer, InventoryLogSerializer, InStoreOrderSerializer, 
    MedicineInventorySerializer, PromoMedicineSerializer, CustomerMedicineSerializer,
    EmployeeLogSerializer, CashierInStoreOrderSerializer, InStoreOrderItemSerializer, 
    OrderLogSerializer, CustomerPromoMedicineDetailSerializer, CustomerMedicineDetailSerializer, 
    OnlineOrderItemReadSerializer, OnlineOrderListSerializer, OnlineOrderItemCreateSerializer, 
    OnlineOrderCreateSerializer, OnlineOrderLogDetailsSerializer, InStoreSalesTransactionSerializer, 
    PrescriptionOrderSerializer, CombinedPrescriptionSerializer, PrescriptionImageSerializer,
    LowStockSerializer, ForecastItemSerializer, ForecastReportSerializer, MedicineForecastSerializer,
    DailyReportSerializer,
)

from .serializers import OrderLogSerializer
from .models import OrderLog



#==============9/1/25=====================
from rest_framework.decorators import api_view, authentication_classes, permission_classes, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Q
from .models import Prescription
#==============9/1/25=====================

from django.db import transaction
from django.db.models import F
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from datetime import datetime, timedelta
from django.utils import timezone
from decimal import Decimal
from rest_framework import generics, pagination


#=============================

from backend.firebase import send_fcm_notification
from django.utils.timezone import now
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

#===========9/13/25 LAZY LOADING=====
from django.core.paginator import Paginator



#======9/20/25 fixes to low stock
from django.db.models import F, Case, When, IntegerField
from django.utils import timezone
from .models import TotalQuantity, Medicine, Inventory # Ensure Inventory is imported
from rest_framework.response import Response
from rest_framework.decorators import api_view
from .serializers import LowStockSerializer


#--------
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response

from django.utils import timezone
from datetime import datetime, time # Import the 'time' class

#----#----------9/23/25
from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from datetime import datetime, time
import pytz # Import pytz for timezone support


#---
from django.db.models import F, ExpressionWrapper, DecimalField, Sum
from django.db.models.functions import Coalesce

# TEMPORARY in-memory dictionary to store reset tokens (DO NOT use in production)
reset_tokens = {}

# ─────────── REGISTRATION ───────────

@api_view(['POST'])
def register_customer(request):
    serializer = CustomerSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response({'message': 'Customer registered successfully'}, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# ─────────── LOGIN ───────────

@api_view(['POST'])
def login_user(request):
    email = request.data.get('email')
    password = request.data.get('password')

    try:
        customer = Customer.objects.get(email=email)
        # Assuming you're using Django's check_password
        if check_password(password, customer.password):
            return Response({
                'message': 'Login successful',
                'user_type': 'customer',
                'view': 'customer_view',
                'id': customer.id,       # <-- Added
                'name': customer.name,   # <-- Added
                'email': customer.email  # <-- Added
            })
    except Customer.DoesNotExist:
        pass

    try:
        staff = Staff.objects.get(email=email)
        if check_password(password, staff.password):
            return Response({
                'message': 'Login successful',
                'user_type': 'staff',
                'role': staff.role,
                'view': f'{staff.role}_view',
                'id': staff.id,
                'name': staff.name,
                'email': staff.email
            })
    except Staff.DoesNotExist:
        pass

    return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)

# ─────────── PASSWORD RESET ───────────

@api_view(['POST'])
def forgot_password(request):
    email = request.data.get('email')

    user = None
    user_type = ''

    try:
        user = Customer.objects.get(email=email)
        user_type = 'customer'
    except Customer.DoesNotExist:
        try:
            user = Staff.objects.get(email=email)
            user_type = 'staff'
        except Staff.DoesNotExist:
            return Response({'error': 'No account found with that email'}, status=status.HTTP_404_NOT_FOUND)

    token = str(uuid.uuid4())
    reset_tokens[token] = {'email': email, 'user_type': user_type}

    reset_link = f'http://127.0.0.1:8000/reset-password/{token}/'

    subject = 'Reset your password'
    message = f'Click the link below to reset your password:\n\n{reset_link}'
    send_mail(subject, message, settings.EMAIL_HOST_USER, [email])

    return Response({'message': 'Reset link sent to email'}, status=status.HTTP_200_OK)

@api_view(['GET', 'POST'])
def reset_password(request, token):
    print('Received token:', token)
    print('Stored tokens:', reset_tokens)
    data = reset_tokens.get(token)
    if not data:
        return render(request, 'reset_credentials/reset_password.html', {'error': 'Invalid or expired token'})

    if request.method == 'POST':
        pw1 = request.POST.get('password1')
        pw2 = request.POST.get('password2')

        if pw1 != pw2:
            return render(request, 'reset_credentials/reset_password.html', {'error': 'Passwords do not match'})

        email = data['email']
        if data['user_type'] == 'customer':
            user = Customer.objects.get(email=email)
        else:
            user = Staff.objects.get(email=email)

        user.password = make_password(pw1)
        user.save()

        reset_tokens.pop(token, None)

        return render(request, 'reset_credentials/reset_password.html', {'success': 'Password reset successful'})

    return render(request, 'reset_credentials/reset_password.html')

# ─────────── CUSTOMER MANAGEMENT ───────────

@api_view(['GET'])
def get_all_customers(request):
    customers = Customer.objects.all()
    serializer = CustomerSerializer(customers, many=True)
    return Response(serializer.data)

@api_view(['GET', 'PUT', 'DELETE'])
def customer_detail(request, customer_id):
    try:
        customer = Customer.objects.get(id=customer_id)
    except Customer.DoesNotExist:
        return Response({'error': 'Customer not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = CustomerSerializer(customer)
        return Response(serializer.data)

    if request.method == 'PUT':
        serializer = CustomerSerializer(customer, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    customer.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)

# ─────────── SUPPLIER MANAGEMENT ───────────

@api_view(['GET', 'POST'])
def supplier_list(request):
    if request.method == 'GET':
        suppliers = Supplier.objects.all()
        serializer = SupplierSerializer(suppliers, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        serializer = SupplierSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'DELETE'])
def supplier_detail(request, pk):
    try:
        supplier = Supplier.objects.get(pk=pk)
    except Supplier.DoesNotExist:
        return Response({'error': 'Supplier not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = SupplierSerializer(supplier)
        return Response(serializer.data)

    elif request.method == 'PUT':
        serializer = SupplierSerializer(supplier, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        supplier.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

# ─────────── STAFF (EMPLOYEE) MANAGEMENT ───────────

@api_view(['GET', 'POST'])
def get_all_staff(request):
    if request.method == 'GET':
        staff_members = Staff.objects.all()
        serializer = StaffSerializer(staff_members, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        serializer = StaffSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET', 'PUT', 'DELETE'])
def staff_detail(request, staff_id):
    try:
        staff = Staff.objects.get(id=staff_id)
    except Staff.DoesNotExist:
        return Response({'error': 'Staff not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = StaffSerializer(staff)
        return Response(serializer.data)

    elif request.method == 'PUT':
        serializer = StaffSerializer(staff, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        staff.delete()
        return Response(status=status.HTTP_204_NO_CONTENT) # Fixed typo: NO_NO_CONTENT to NO_CONTENT

# ─────────── STAFF PROFILE ───────────

@api_view(['PUT'])
def update_staff_profile(request, staff_id):
    try:
        staff = Staff.objects.get(id=staff_id)
    except Staff.DoesNotExist:
        return Response({'error': 'Staff not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = StaffSerializer(staff, data=request.data, partial=True)
    if serializer.is_valid():
        serializer.save()
        return Response({'message': 'Profile updated', 'staff': serializer.data})
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def get_staff_profile(request, staff_id):
    try:
        staff = Staff.objects.get(id=staff_id)
    except Staff.DoesNotExist:
        return Response({'error': 'Staff not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = StaffSerializer(staff)
    return Response(serializer.data)


@api_view(['PUT'])
def change_staff_password(request, staff_id):
    try:
        staff = Staff.objects.get(id=staff_id)
    except Staff.DoesNotExist:
        return Response({'error': 'Staff not found'}, status=status.HTTP_404_NOT_FOUND)

    current_password = request.data.get('current_password')
    new_password = request.data.get('new_password')

    if not current_password or not new_password:
        return Response({'error': 'Both current and new password are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if not check_password(current_password, staff.password):
        return Response({'error': 'Current password is incorrect.'}, status=status.HTTP_400_BAD_REQUEST) # Fixed typo: BAD_BAD_REQUEST to BAD_REQUEST

    staff.password = make_password(new_password)
    staff.save()
    return Response({'message': 'Password changed successfully'}, status=status.HTTP_200_OK)



























#----------9/30/25
# ─────────── MEDICINE MANAGEMENT ───────────

@api_view(['GET', 'POST'])
@parser_classes([MultiPartParser, FormParser])
def medicine_list(request):
    if request.method == 'GET':
        medicines = Medicine.objects.all()
        serializer = MedicineSerializer(medicines, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        serializer = MedicineSerializer(data=request.data)
        if serializer.is_valid():
            medicine = serializer.save()

            # Log the 'Add' action
            staff_id = request.data.get('staff_id')
            if staff_id:
                try:
                    staff_user = Staff.objects.get(id=staff_id)
                    InventoryLog.objects.create(
                        user=staff_user,
                        medicine=medicine,
                        action_type='Add',
                        staff_name=staff_user.name,
                        staff_role=staff_user.role,
                        description=f"Added new medicine: {medicine.name}",
                        medicine_name_log=medicine.name, # <-- Add this line
                        timestamp=timezone.now()
                    )
                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging action.")

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)    



# ---------------10/1/25
@api_view(['GET', 'PUT', 'DELETE'])
@parser_classes([MultiPartParser, FormParser])
def medicine_detail(request, pk):
    try:
        medicine = Medicine.objects.get(pk=pk)
    except Medicine.DoesNotExist:
        return Response({'error': 'Medicine not found'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        serializer = MedicineSerializer(medicine)
        return Response(serializer.data)

    elif request.method == 'PUT':
        # ✅ Store old values before updating
        old_data = {
            'price': str(medicine.price),
            'restock_quantity': str(medicine.restock_quantity),
            'category': medicine.category,
            'dosage_form': medicine.dosage_form,
            'supplier_id': medicine.supplier.id if medicine.supplier else None,
            # 💡 SNAPSHOT CHANGE: Use the new persistent supplier_name field for OLD data
            'supplier_name': medicine.supplier_name, 
        }

        serializer = MedicineSerializer(medicine, data=request.data, partial=True)
        if serializer.is_valid():
            # serializer.save() runs the logic in MedicineSerializer to update the snapshot
            serializer.save() 

            staff_id = request.data.get('staff_id')
            if staff_id:
                try:
                    staff_user = Staff.objects.get(id=staff_id)

                    # ✅ Get updated instance from DB (with new values)
                    updated_medicine = Medicine.objects.get(pk=pk)

                    new_data = {
                        'price': str(updated_medicine.price),
                        'restock_quantity': str(updated_medicine.restock_quantity),
                        'category': updated_medicine.category,
                        'dosage_form': updated_medicine.dosage_form,
                        'supplier_id': updated_medicine.supplier.id if updated_medicine.supplier else None,
                        # 💡 SNAPSHOT CHANGE: Use the new persistent supplier_name field for NEW data
                        'supplier_name': updated_medicine.supplier_name,
                    }

                    updated_fields = []

                    if old_data['price'] != new_data['price']:
                        updated_fields.append(f"Price changed from {old_data['price']} to {new_data['price']}")

                    if old_data['restock_quantity'] != new_data['restock_quantity']:
                        updated_fields.append(f"Restock Quantity changed from {old_data['restock_quantity']} to {new_data['restock_quantity']}")

                    if old_data['category'] != new_data['category']:
                        updated_fields.append(f"Category changed from '{old_data['category']}' to '{new_data['category']}'")

                    if old_data['dosage_form'] != new_data['dosage_form']:
                        updated_fields.append(f"Dosage Form changed from '{old_data['dosage_form']}' to '{new_data['dosage_form']}'")

                    if old_data['supplier_id'] != new_data['supplier_id']:
                        updated_fields.append(f"Supplier changed from '{old_data['supplier_name']}' to '{new_data['supplier_name']}'")

                    if updated_fields:
                        description = "Updated medicine: " + "; ".join(updated_fields)
                        InventoryLog.objects.create(
                            user=staff_user,
                            medicine=updated_medicine,
                            action_type='Update',
                            description=description,
                            staff_name=staff_user.name,
                            staff_role=staff_user.role,
                            medicine_name_log=updated_medicine.name,
                            timestamp=timezone.now() # Manually set the timestamp
                        )

                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging action.")

            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        staff_id = request.GET.get('staff_id')
        medicine_name = medicine.name

        try:
            with transaction.atomic():

                # ⭐ CRITICAL FIX: Find and permanently update the excluded items ⭐
                # 1. Identify all OnlineOrderItems linked to this medicine 
                #    in 'pending' or 'ready for pickup' orders.
                affected_items_qs = OnlineOrderItem.objects.filter(
                    order__status__in=['pending', 'ready for pickup'],
                    inventory_id__medicine=medicine 
                ).select_related('order').distinct()
                
                from decimal import Decimal

                # 2. Iterate and permanently set the price of the excluded item to 0.00
                for item in affected_items_qs:
                    item.price_at_sale = Decimal('0.00') 
                    # The deletion of Inventory below will set inventory_id=NULL (due to models.SET_NULL), 
                    # but we are setting the crucial financial field here.
                    item.save(update_fields=['price_at_sale']) 
                
                # 3. Recalculate totals for all affected orders 
                # (to reflect the 0.00 item price immediately in the UI)
                orders_to_recalculate_ids = {item.order_id for item in affected_items_qs}
                
                for order_id in orders_to_recalculate_ids:
                    order = OnlineOrder.objects.get(id=order_id)
                    
                    # Recalculate based on available items (which now includes 0.00 price for excluded item)
                    new_total_before = order.items.aggregate(
                        total_before=Coalesce(
                            Sum(F('price_at_sale') * F('quantity_sold')),
                            Decimal('0.00')
                        )
                    )['total_before']

                    # Apply discount if applicable
                    new_total_after = new_total_before
                    if order.is_pwd:
                        new_total_after = new_total_before - (new_total_before * Decimal('0.20'))

                    order.total_amount_before_discount = new_total_before
                    order.total_amount_after_discount = new_total_after
                    order.save(update_fields=['total_amount_before_discount', 'total_amount_after_discount'])
                
                
                # Step 4: Proceed with the deletion of Inventory and Medicine (original logic)
                # Delete related inventory batches.
                Inventory.objects.filter(medicine=medicine).delete()

                # Delete related total quantity record.
                TotalQuantity.objects.filter(medicine=medicine).delete()

                # Now, safely delete the Medicine record itself.
                medicine.delete()

            if staff_id:
                try:
                    staff_user = Staff.objects.get(id=staff_id)
                    # This section remains unchanged as it doesn't log supplier name
                    InventoryLog.objects.create(
                        user=staff_user,
                        medicine=None,
                        action_type='Delete',
                        description=f"Deleted medicine: {medicine_name}",
                        medicine_name_log=medicine_name, # <-- Add this line to save the name
                        timestamp=timezone.now(),
                        staff_name=staff_user.name,
                        staff_role=staff_user.role,
                    )
                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging delete.")

            return Response(status=status.HTTP_204_NO_CONTENT)

        except Exception as e:
            print(f"Error during medicine deletion: {e}")
            return Response({'error': 'An error occurred during the deletion process.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)        
    #----------10/1/25
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    


#-----------9/30/25    
# =================== INVENTORY MANAGEMENT -------------------- # Renamed comment for clarity
class InventoryCreateView(APIView):
    def post(self, request, *args, **kwargs):
        serializer = InventoryCreateSerializer(data=request.data)
        if serializer.is_valid():
            inventory_item = serializer.save()  # Save and get the created Inventory instance

            # ✅ Restock logging
            staff_id = request.data.get('staff_id')
            if staff_id:
                try:
                    staff_user = Staff.objects.get(id=staff_id)
                    medicine = inventory_item.medicine
                    batch = inventory_item.batch_num
                    qty_to_add = inventory_item.quantity

                    InventoryLog.objects.create(
                        user=staff_user,
                        medicine=medicine,
                        action_type='Restock',
                        description=f"Restocked {qty_to_add} units (Batch: {batch})",
                        medicine_name_log=medicine.name, # ✅ Add this
                        staff_name=staff_user.name,
                        staff_role=staff_user.role,
                    )
                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging restock action.")

            return Response(serializer.data, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


























#======== 9/29/25 LAZY LOADING CHANGE===================================

@api_view(['GET'])
def get_inventory_list(request):
    # Retrieve limit and offset from query parameters, with default values
    limit = int(request.GET.get('limit', 10))
    offset = int(request.GET.get('offset', 0))
    
    # NEW: Retrieve search query and category filter
    search_query = request.GET.get('q', None)
    category_filter = request.GET.get('category', None)

    # Clean expired promos (assuming this is a necessary pre-processing step)
    clean_expired_promos()

    # Get the base queryset
    queryset = TotalQuantity.objects.select_related('medicine').all()
    
    # NEW: Apply filtering based on category
    if category_filter:
        # Assuming the 'category' is a field on the 'medicine' model
        queryset = queryset.filter(medicine__category=category_filter) 
    
    # NEW: Apply search filtering based on name or generic name
    if search_query:
        queryset = queryset.filter(
            Q(medicine__name__icontains=search_query) |
            Q(medicine__generic_name__icontains=search_query)
        )

    # ORDER IT BY NAME before slicing
    queryset = queryset.order_by('medicine__name') 

    # Get the total count of items AFTER filtering, but BEFORE pagination
    total_count = queryset.count() 
    
    # Apply slicing to the queryset based on offset and limit
    paginated_queryset = queryset[offset:offset + limit]

    # Serialize the paginated data
    serializer = InventoryListSerializer(paginated_queryset, many=True, context={'request': request})
    
    # MODIFIED: Return the paginated data along with the total count
    return Response({
        'items': serializer.data,
        'total_count': total_count,
        'has_more': (offset + limit) < total_count, # Helpful boolean for the front end
    })
#=====================================================






def clean_expired_promos():
    # Your existing logic for cleaning expired promos
    pass






















@api_view(['GET'])
def get_medicine_by_barcode(request, barcode):
    try:
        medicine = Medicine.objects.get(barcode=barcode)
    except Medicine.DoesNotExist:
        return Response({'error': 'Medicine not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = MedicineSerializer(medicine)
    return Response(serializer.data)

####### FOR INVENTORY 
# main inventory screen - with total qty


# 2. batch level details for a selected medicine
#--------OLD OUTDATED VERSION
#@api_view(['GET'])
#def get_batch_details(request, medicine_id):
    batches = Inventory.objects.filter(medicine__id=medicine_id)
    if not batches.exists():
        return Response({'message': 'No batches found.'}, status=status.HTTP_404_NOT_FOUND)

    serializer = InventoryBatchDetailSerializer(batches, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

#======= 9/29/25 LAZY LOADING CHANGE ===============
@api_view(['GET'])
def get_batch_details(request, medicine_id):
    today = timezone.now().date()
    
    # NEW: Get limit and offset from request query parameters.
    limit = int(request.query_params.get('limit', 10))
    offset = int(request.query_params.get('offset', 0))

    # IMPORTANT: Order the queryset first before slicing.
    # We'll order by expiration date in ascending order.
    batches = Inventory.objects.filter(
        medicine__id=medicine_id,
        exp_date__gt=today  # strictly greater than today → exclude expired
    ).order_by('exp_date') 

    if not batches.exists():
        return Response({'message': 'No active batches found.'}, status=status.HTTP_404_NOT_FOUND)

    # MODIFIED: Apply slicing to the queryset using the offset and limit.
    paginated_batches = batches[offset:offset + limit]

    serializer = InventoryBatchDetailSerializer(paginated_batches, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

#============================================


# ✅ Total quantities (all medicines) — exclude expired
@api_view(['GET'])
def total_quantities(request):
    today = timezone.now().date()

    inventory_totals = (
        Inventory.objects
        .filter(exp_date__gt=today)  # strictly greater than today → exclude expired
        .values(
            'medicine_id',
            'medicine__name',
            'medicine__generic_name',
            'medicine__image',
            'medicine__category'
        )
        .annotate(total_quantity=Sum('quantity'))
        .order_by('medicine__name')
    )

    return JsonResponse(list(inventory_totals), safe=False)

# =================== Expiration Dashboard -------------------- =================09/05/2025===================
# ✅ Good Stocks:
# Medicines that either:
# - Expire more than 15 days from today
class GoodStockView(generics.ListAPIView):
    serializer_class = InventoryDashboardSerializer

    def get_queryset(self):
        today = date.today()
        threshold_date = today + timedelta(days=15)
        return Inventory.objects.filter(
        exp_date__gt=threshold_date,
        quantity__gt=0 # ✅ NEW: Exclude batches with 0 quantity
        )

# ⚠️ Expiring Soon:
# Medicines that will expire within the next 15 days (but not yet expired),
# and were not received today
class ExpiringSoonView(generics.ListAPIView):
    serializer_class = InventoryDashboardSerializer

    def get_queryset(self):
        today = date.today()
        return Inventory.objects.filter(
            exp_date__gt=today,
            exp_date__lte=today + timedelta(days=15),
            quantity__gt=0 # ✅ NEW: Exclude batches with 0 quantity
        )

# ❌ Expired:
# Medicines that are already expired (today or earlier)
class ExpiredView(generics.ListAPIView):
    serializer_class = InventoryDashboardSerializer

    def get_queryset(self):
        today = date.today()
        return Inventory.objects.filter(
            exp_date__lte=today,
            quantity__gt=0 # ✅ NEW: Exclude batches with 0 quantity
        )

#--------------------09/30/2025--------------------------- 
# #Return Medicine 
@api_view(['DELETE'])
def delete_expired_batch(request, pk):
    try:
        inventory_item = Inventory.objects.get(pk=pk)

        # 1. Check if this inventory item was sold as part of an online order
        online_order_item = OnlineOrderItem.objects.filter(inventory_id=inventory_item).first()

        # Capture info before deletion
        medicine = inventory_item.medicine
        quantity = inventory_item.quantity
        batch = inventory_item.batch_num
        exp_date = inventory_item.exp_date
        
        # 🔐 Get staff from query param (Flutter: ?staff_id=123)
        staff_id = request.query_params.get('staff_id')
        staff_user = Staff.objects.filter(id=staff_id).first()

        # ✅ CRITICAL SECTION: Create the returned medicine record
        if online_order_item:
            ReturnedMedicine.objects.create(
                medicine=medicine,
                # ✅ FINAL, UNAMBIGUOUS FIX: Explicitly pass the ID of the object.
                online_order_item_id=online_order_item.id,
                batch_num=batch,
                exp_date=exp_date,
                quantity=quantity,
                returned_by=staff_user
            )
        else:
            ReturnedMedicine.objects.create(
                medicine=medicine,
                batch_num=batch,
                exp_date=exp_date,
                quantity=quantity,
                returned_by=staff_user
            )

        # Create the inventory log entry
        if staff_user:
            InventoryLog.objects.create(
                user=staff_user,
                medicine=medicine,
                action_type='Expiration Return',
                description=f"Returned {quantity} units of {medicine.name} (Batch: {batch}) due to expiration",
                medicine_name_log=medicine.name, # ✅ Add this line
                staff_name=staff_user.name,
                staff_role=staff_user.role,
            )

        # Now, and only now, delete the item from the Inventory table
        inventory_item.delete()

        return Response({"message": "Batch archived and deleted successfully"}, status=status.HTTP_204_NO_CONTENT)

    except Inventory.DoesNotExist:
        return Response({"error": "Inventory item not found"}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:

        return Response({"error": f"An unexpected error occurred: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)



#--------------------09/30/2025--------------------------- 
# Promo Medicine
@api_view(['POST'])
def set_promo(request, inventory_id):
    clean_expired_promos()
    try:
        inventory_item = Inventory.objects.get(pk=inventory_id)
    except Inventory.DoesNotExist:
        return Response({'error': 'Inventory item not found'}, status=status.HTTP_404_NOT_FOUND)

    start_date = request.data.get('start_date')
    end_date = request.data.get('end_date')
    staff_id = request.data.get('staff_id')

    if not start_date or not end_date:
        return Response({'error': 'Start and end date required'}, status=status.HTTP_400_BAD_REQUEST)

    # Save promo entry
    promo = Promo.objects.create(
        inventory_id=inventory_item,
        start_date=start_date,
        end_date=end_date
    )

    # Mark inventory as promo
    inventory_item.is_promo = True
    inventory_item.save()

    # ✅ Log the promo setting
    if staff_id:
        try:
            staff = Staff.objects.get(id=staff_id)
            InventoryLog.objects.create(
                user=staff,
                medicine=inventory_item.medicine,
                action_type='Promo Set',
                staff_name=staff.name,
                staff_role=staff.role,
                description=f"Set promo for batch {inventory_item.batch_num} from {start_date} to {end_date}",
                medicine_name_log=inventory_item.medicine.name # ✅ Add this line
            )
        except Staff.DoesNotExist:
            print(f"Staff with ID {staff_id} not found for promo logging.")

    return Response({'message': 'Promo set successfully'}, status=status.HTTP_200_OK)


#--------------------09/30/2025--------------------------- 
@api_view(['POST'])
def remove_promo(request):
    try:
        inventory_id = request.data.get('inventory_id')
        staff_id = request.data.get('staff_id')
        inventory = Inventory.objects.get(id=inventory_id)

        # Reset is_promo flag
        inventory.is_promo = False
        inventory.save()

        # ✅ Delete the promo
        Promo.objects.filter(inventory_id=inventory).delete()

        # ✅ Log the promo removal
        if staff_id:
            try:
                staff = Staff.objects.get(id=staff_id)
                InventoryLog.objects.create(
                    user=staff,
                    medicine=inventory.medicine,
                    action_type='Promo Removed',
                    staff_name=staff.name,
                    staff_role=staff.role,
                    description=f"Removed promo for batch {inventory.batch_num}",
                    medicine_name_log=inventory.medicine.name # ✅ Add this line
                )
            except Staff.DoesNotExist:
                print(f"Staff with ID {staff_id} not found for promo logging.")

        return JsonResponse({'message': 'Promo removed successfully'})
    except Inventory.DoesNotExist:
        return JsonResponse({'error': 'Inventory not found'}, status=404)
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)


def clean_expired_promos():
    today = date.today()
    
    # Get expired promos (based on end date)
    expired_promos = Promo.objects.filter(end_date__lt=today)

    # Get promos linked to expired inventory (based on inventory.exp_date)
    medicine_expired_promos = Promo.objects.filter(inventory_id__exp_date__lte=today)

    # Union both QuerySets
    all_to_clean = expired_promos.union(medicine_expired_promos)

    for promo in all_to_clean:
        inventory_item = promo.inventory_id
        inventory_item.is_promo = False
        inventory_item.save()
        promo.delete()







#=========================================09/13/25 (ELTON)=========================================

# For Inventory Logs
@api_view(['GET'])
def inventory_logs(request):
    """
    Returns a paginated list of inventory logs.
    """
    # Create an instance of the custom paginator
    paginator = InventoryLogPagination()
    
    # Get all logs, sorted by timestamp
    # MODIFIED: Removed 'user' from select_related for a slight performance optimization, 
    # as the staff name/role is now read directly from the log record (snapshot).
    logs = InventoryLog.objects.select_related('medicine').all() 

    # Paginate the queryset
    paginated_logs = paginator.paginate_queryset(logs, request)

    # If there are no more pages, return an empty list
    if paginated_logs is not None:
        serializer = InventoryLogSerializer(paginated_logs, many=True)
        return paginator.get_paginated_response(serializer.data)
    else:
        # This case is for when pagination returns None, though it's rare with DRF's default behavior
        serializer = InventoryLogSerializer(logs, many=True)
        return Response(serializer.data)
#=========================================09/13/25 (ELTON)=========================================






# ─────────── SALES ───────────

@api_view(['GET'])
def get_item_by_barcode(request, barcode):
    """
    API endpoint to retrieve all available inventory batches for a medicine,
    ordered by their expiration date (FEFO logic), excluding expired items.
    """
    try:
        # Find the medicine with the given barcode
        medicine_item = Medicine.objects.get(barcode=barcode)
        
        # Find all inventory items for this medicine with quantity > 0,
        # order them by expiration date, and exclude any that are expired (exp_date > today)
        inventory_items = Inventory.objects.filter(
            medicine=medicine_item,
            quantity__gt=0,
            exp_date__gt=date.today()  # <-- The filter is now strictly greater than today
        ).order_by('exp_date')

        if not inventory_items.exists():
            return Response({'error': 'No available inventory found for this medicine'}, status=status.HTTP_404_NOT_FOUND)

    except Medicine.DoesNotExist:
        return Response({'error': 'Medicine not found for this barcode'}, status=status.HTTP_404_NOT_FOUND)
    
    serializer = MedicineInventorySerializer(inventory_items, many=True, context={'request': request})
    
    return Response(serializer.data, status=status.HTTP_200_OK)


#===============9/13/2025=============================
#----------Customer Side Mainview----------------

class PromoMedicineView(ListAPIView):
    serializer_class = PromoMedicineSerializer
    pagination_class = PromoMedicinePagination # Use the new pagination class

    def get_queryset(self):
        today = now().date()
        
        # This is the correct way to get unique medicines for MySQL
        # 1. Get the list of unique medicine IDs
        promo_medicine_ids = Inventory.objects.filter(
            promo__start_date__lte=today,
            promo__end_date__gte=today
        ).values_list('medicine__id', flat=True).distinct()

        # 2. Filter the queryset to include only these unique medicine IDs
        queryset = Inventory.objects.filter(
            medicine__id__in=promo_medicine_ids,
            promo__start_date__lte=today,
            promo__end_date__gte=today
        ).order_by('medicine__id')

        return queryset
        
# Keep the existing function as is
def trigger_update_total_quantity(request):
    call_command('update_total_quantities')
    return JsonResponse({'status': 'success'})


#========================9/13/25=========================================

class PromoMedicineDetailView(APIView):
    def get(self, request, pk):
        medicine = get_object_or_404(Medicine, pk=pk)
        serializer = CustomerPromoMedicineDetailSerializer(medicine, context={'request': request})
        return Response(serializer.data)


#========= 9/24/25 UPDATED 4 LAZY LOADING ================
#For Normal Medicine 
#For Normal Medicine 
@api_view(['GET'])
def get_customer_medicines(request):
    """
    Retrieves a list of normal medicines for the customer view with lazy loading and filtering.
    """
    # NEW: Get lazy loading parameters from the request.
    limit = int(request.query_params.get('limit', 10))
    offset = int(request.query_params.get('offset', 0))
    
    # MODIFIED: Get category and search query from request.
    category = request.query_params.get('category', None)
    search_query = request.query_params.get('search', None)

    # Start with the base queryset and apply sorting first.
    queryset = TotalQuantity.objects.select_related('medicine').all().order_by('medicine__name')
    
    # Apply category filter
    if category and category != 'all':
        queryset = queryset.filter(medicine__category=category)
    
    # NEW: Apply search filter using a Q object for combined search.
    if search_query:
        queryset = queryset.filter(
            Q(medicine__name__icontains=search_query) |
            Q(medicine__generic_name__icontains=search_query)
        )
    
    # MODIFIED: Apply pagination to the filtered queryset.
    paginated_queryset = queryset[offset:offset + limit]

    # Extract the medicine objects from the paginated inventory items.
    medicines = [item.medicine for item in paginated_queryset]
    
    # Serialize the paginated list of medicines.
    serializer = CustomerMedicineSerializer(medicines, many=True, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)

#===================================================================

@api_view(['GET'])
def get_customer_medicine_detail(request, pk):
    """
    Retrieves the detailed information for a single medicine.
    """
    medicine = get_object_or_404(Medicine, pk=pk)
    serializer = CustomerMedicineDetailSerializer(medicine, context={'request': request})
    return Response(serializer.data)

def trigger_update_total_quantity(request):
    """
    Triggers the management command to update total quantities.
    (This function seems unrelated to the filtering issue but is kept for completeness)
    """
    call_command('update_total_quantities')
    return JsonResponse({'status': 'success'})




















#----------9/23/25
#----------Employee Logs Views-------
@api_view(['GET', 'POST'])
def employee_logs_view(request):
    if request.method == 'GET':
        logs = EmployeeLog.objects.all()
        serializer = EmployeeLogSerializer(logs, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        # Create a mutable copy of the request data
        data = request.data.copy()
        
        # Manually add the current timezone-aware timestamp
        data['timestamp'] = timezone.now()
        
        serializer = EmployeeLogSerializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
#----------9/23/25





















# ---------------9/30/25
#------------ PENDING ORDER----------
#----------ORDER LOGS PT 1 - FOR CASHER (INSTORE)---------
#modified some parts of the pending order view for the order logs

#combined logic from previous InStoreOrderProcessingView with recent 8/12/25
#--9/29/25 MODIFIED FOR CASHIER PRESCRIPTION DIALOGUE BOX
class InStoreOrderProcessingView(APIView):
    """
    API endpoint for cashiers to view, approve, or reject pending in-store orders.
    """

    def get(self, request):
        """
        Get all orders that are pending cashier approval.
        """
        pending_orders = InStoreOrder.objects.filter(status='pending').select_related('staff').prefetch_related(
            Prefetch('items', queryset=InStoreOrderItem.objects.select_related('inventory_id__medicine'))
        )
        serializer = CashierInStoreOrderSerializer(pending_orders, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, order_id):
        """
        Approve or reject a pending in-store order.
        Includes a check for prescription-required items to prompt a warning.
        """
        new_status = request.data.get('status')
        cashier_id = request.data.get('cashier_id')
        force_approve = request.data.get('force_approve', False) # NEW: Get the force_approve flag
        
        if not new_status or new_status not in ['approved', 'rejected']:
            return Response({'error': 'Invalid status provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            with transaction.atomic():
                try:
                    order = InStoreOrder.objects.select_for_update().get(id=order_id, status='pending')
                except InStoreOrder.DoesNotExist:
                    return Response({'error': 'Pending order not found'}, status=status.HTTP_404_NOT_FOUND)
                
                # Retrieve cashier user once to avoid duplicate calls
                try:
                    cashier_user = Staff.objects.get(id=cashier_id)
                except Staff.DoesNotExist:
                    return Response({'error': f'Cashier with ID {cashier_id} not found'}, status=status.HTTP_404_NOT_FOUND)

                if new_status == 'approved':
                    # Check if the order requires a prescription
                    if order.has_prescription_required_item and not force_approve:
                        has_image = PrescriptionImage.objects.filter(prescription__in_store_order=order).exists()
                        
                        if has_image:
                            # Scenario 1: Image exists. Trigger a verification dialogue.
                            return Response(
                                {
                                    "warning": "This order contains items that require a prescription. An image has been uploaded. Please verify before approving.",
                                    "has_image": True
                                },
                                status=status.HTTP_202_ACCEPTED
                            )
                        else:
                            # Scenario 2: No image exists. Trigger a warning dialogue.
                            return Response(
                                {
                                    "warning": "This order contains items that require a prescription, and no image has been uploaded. Do you want to approve it anyway?",
                                    "has_image": False
                                },
                                status=status.HTTP_202_ACCEPTED
                            )

                    # Process each item in the order to update inventory
                    order_items = InStoreOrderItem.objects.filter(order=order)
                    for item in order_items:
                        # ADDED CHECK: Ensure the order item is linked to an inventory item
                        if not item.inventory_id:
                            transaction.set_rollback(True)
                            return Response(
                                {'error': f"Order item for '{item.medicine_name}' is not linked to an inventory item."},
                                status=status.HTTP_400_BAD_REQUEST
                            )
                        
                        total_to_deduct = item.quantity_sold + item.free_quantity_given
                        batch = item.inventory_id
                        
                        if batch.quantity < total_to_deduct:
                            transaction.set_rollback(True)
                            return Response(
                                {'error': f"Insufficient stock for {batch.medicine.name}. "
                                          f"Available: {batch.quantity}, Required: {total_to_deduct}"},
                                status=status.HTTP_400_BAD_REQUEST
                            )
                        
                        batch.quantity = F('quantity') - total_to_deduct
                        batch.save(update_fields=['quantity'])
                        
                        InventoryLog.objects.create(
                            user=cashier_user, #NEW
                            medicine=batch.medicine,
                            action_type='Sold',
                            staff_name=cashier_user.name,
                            staff_role=cashier_user.role,
                            description=f"Approved sale of {total_to_deduct} units "
                                        f"of {batch.medicine.name} (Batch: {batch.batch_num}) "
                                        f"from In-Store Order #{order.id}.",
                            medicine_name_log=batch.medicine.name # <-- Add this line
                        )
                    
                    order.cashier = cashier_user #NEW
                    order.status = 'approved'
                    order.save(update_fields=['status', 'cashier'])
                    
                    OrderLog.objects.create(
                        staff_user=cashier_user,
                        in_store_order=order,
                        action_type='in_store_approve',
                        description=f'Sale transaction approved by {cashier_user.name}'
                    )
                    
                    return Response({'message': 'Order approved and inventory updated'}, status=status.HTTP_200_OK)
                
                elif new_status == 'rejected':
                    order.cashier = cashier_user
                    order.status = 'rejected'
                    order.save(update_fields=['status', 'cashier'])
                    
                    OrderLog.objects.create(
                        staff_user=cashier_user,
                        in_store_order=order,
                        action_type='in_store_reject',
                        description=f'Sale transaction rejected by {cashier_user.name}'
                    )
                    return Response({'message': 'Order rejected'}, status=status.HTTP_200_OK)

        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR) 
       
        
        
    
#----------ORDER LOGS PT 2 - FOR STAFF (INSTORE)---------
#--9/29/25 MODIFIED FOR CASHIER DIALOGUE BOX 
@api_view(['POST'])
def process_instore_order(request):
    """
    API endpoint for staff to create a pending in-store order.
    """
    serializer = InStoreOrderSerializer(data=request.data)
    if serializer.is_valid():
        try:
            # 1. Save the order with a 'pending' status.
            order = serializer.save()

            # NEW LOGIC --9/25/25--
            # Check if any items in the order require a prescription
            prescription_needed = False
            for item_data in request.data.get('items', []):
                # We need to get the medicine instance from the inventory ID
                inventory_id = item_data.get('inventory_id')
                if inventory_id:
                    try:
                        inventory_item = Inventory.objects.get(id=inventory_id)
                        if inventory_item.medicine.requires_prescription:
                            prescription_needed = True
                            break  # We found one, no need to check others
                    except Inventory.DoesNotExist:
                        # Log or handle this case if necessary, but don't stop the process
                        pass
            
            # Update the order object if a prescription is needed
            if prescription_needed:
                order.has_prescription_required_item = True
                order.save(update_fields=['has_prescription_required_item'])
            
            # 2. Get the staff user ID from the request data
            staff_id = request.data.get('staff')
            staff_user = Staff.objects.get(id=staff_id)
            
            # 3. Create a log entry for the 'initiate sale' action
            OrderLog.objects.create(
                staff_user=staff_user,
                in_store_order=order,
                action_type='initiate_sale',
                description='Sale submitted for approval'
            )

            return Response({
                "message": "Order submitted successfully for cashier approval",
                "order_id": order.id,
                "total_before_discount": float(order.total_amount_before_discount),
                "total_after_discount": float(order.total_amount_after_discount),
            }, status=status.HTTP_201_CREATED)
        except Staff.DoesNotExist:
            return Response({"error": "Staff member not found."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            return Response({"error": f"Failed to process order: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
    return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)
















#------------------ ORDER LOGS VIEW -------------------
class OrderLogPagination(pagination.PageNumberPagination):
    page_size = 20  # Set the number of items per page
    page_size_query_param = 'page_size'
    max_page_size = 100

class OrderLogsListView(generics.ListAPIView):
    """
    API endpoint to retrieve paginated order logs.
    
    This view uses a custom pagination class to limit the number of
    records returned per request. It leverages select_related and 
    prefetch_related for efficient database queries.
    """
    queryset = OrderLog.objects.all().select_related(
        'staff_user', 
        'in_store_order__staff',
        'online_order__customer'
    ).prefetch_related(
        'in_store_order__items__inventory_id__medicine',
        'online_order__items__inventory_id__medicine'
    ).order_by('-timestamp')
    
    serializer_class = OrderLogSerializer
    pagination_class = OrderLogPagination




















#------------------ CUSTOMER ONLINE ORDERS -------------------
@api_view(['POST'])
def create_online_order(request):
    """
    API endpoint to create a new online order from the Flutter app.
    This now correctly uses the OnlineOrderCreateSerializer.
    """
    serializer = OnlineOrderCreateSerializer(data=request.data)
    if serializer.is_valid():
        try:
            # This 'save' call triggers the create method in the OnlineOrderCreateSerializer
            order = serializer.save()
            return Response(
                {'message': 'Order created successfully!', 'order_id': order.id},
                status=status.HTTP_201_CREATED
            )
        except serializers.ValidationError as e:
            return Response({"error": e.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            print(f"[ONLINE ORDER ERROR] {e}")
            return Response({"error": f"Failed to process order: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
















#----------9/23/25-----------------------------------------------------------------------------------[as of 4:30 pm aaron]
@api_view(['GET'])
def get_online_customer_orders(request, customer_id):
    """
    API endpoint to retrieve all online orders for a specific customer.
    Dynamically recalculates total amount for orders with deleted items.
    """
    try:
        # Get all orders for the customer
        orders = OnlineOrder.objects.filter(customer__id=customer_id).order_by('-date_created')

        for order in orders:
            # Check if the order status is 'pending' or 'ready for pickup'
            if order.status in ['pending', 'ready for pickup']:
                # Calculate the new total based on available items
                new_total_before = order.items.filter(
                    inventory_id__isnull=False
                ).aggregate(
                    total_before=Coalesce(
                        Sum(F('price_at_sale') * F('quantity_sold')),
                        Decimal('0.00')
                    )
                )['total_before']

                # Check if all items in the order were deleted
                if new_total_before == 0 and order.items.count() > 0:
                    # Cancel the order and save the change
                    order.status = 'cancelled'
                    order.total_amount_before_discount = new_total_before
                    order.total_amount_after_discount = new_total_before
                    order.save(update_fields=['status', 'total_amount_before_discount', 'total_amount_after_discount'])
                    continue  # Move to the next order

                # Apply discount if applicable
                new_total_after = new_total_before
                if order.is_pwd:
                    new_total_after = new_total_before - (new_total_before * Decimal('0.20'))

                # Update the order in the database only if the total has changed
                if order.total_amount_after_discount != new_total_after:
                    order.total_amount_before_discount = new_total_before
                    order.total_amount_after_discount = new_total_after
                    order.save(update_fields=['total_amount_before_discount', 'total_amount_after_discount'])
        
        # Re-fetch the queryset to get the updated values from the database
        orders = OnlineOrder.objects.filter(customer__id=customer_id).order_by('-date_created')

        serializer = OnlineOrderListSerializer(orders, many=True, context={'request': request})
        return Response(serializer.data)

    except OnlineOrder.DoesNotExist:
        return Response({"detail": "No online orders found for this customer."}, status=status.HTTP_404_NOT_FOUND)
    
#----------9/23/25-----------------------------------------------------------------------------------[as of 4:30 pm aaron]

















    

@api_view(['PUT'])
def cancel_online_order(request, order_id):
    """
    API endpoint to cancel an online order without affecting inventory.
    """
    try:
        with transaction.atomic():
            order = OnlineOrder.objects.select_for_update().get(pk=order_id)

            if order.status == 'pending':
                order.status = 'cancelled'
                order.save()
                return Response(
                    {"detail": "Online order cancelled successfully."},
                    status=status.HTTP_200_OK
                )
            else:
                return Response(
                    {"detail": f"Order status is '{order.status}' and cannot be cancelled."},
                    status=status.HTTP_400_BAD_REQUEST
                )
    except OnlineOrder.DoesNotExist:
        return Response({"detail": "Online order not found."}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        print(f"[CANCEL ORDER ERROR] {e}")
        return Response({"detail": f"An unexpected error occurred: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)





























# ---------------9/26/25
# Cashier and Staff Confirm Online Order
# -------------------------------
# Get Pending Online Orders
# -------------------------------
@api_view(['GET'])
def get_pending_online_orders(request):
    """
    API view for staff to get a list of all online orders with a 'pending' status.
    """
    try:
        # Fetch only orders that are in a 'pending' or 'ready for pickup' status
        orders = OnlineOrder.objects.filter(
            status__in=['pending', 'ready for pickup']
        ).prefetch_related(
            Prefetch(
                'items',
                queryset=OnlineOrderItem.objects.select_related('inventory_id__medicine')
            )
        ).order_by('-date_created')


        # 💡 NEW/MODIFIED LOGIC: Loop through orders to recalculate and save totals 💡
        for order in orders:
            # Only need to check the items for active status since it's already pending/ready
            new_total_before = order.items.filter(
                inventory_id__isnull=False
            ).aggregate(
                total_before=Coalesce(
                    Sum(F('price_at_sale') * F('quantity_sold')),
                    Decimal('0.00')
                )
            )['total_before']

            # Apply discount if applicable
            new_total_after = new_total_before
            if order.is_pwd:
                new_total_after = new_total_before - (new_total_before * Decimal('0.20'))

            # Check if all items in the order were deleted, and auto-cancel if so
            if new_total_before == 0 and order.items.count() > 0:
                order.status = 'cancelled'
                order.total_amount_before_discount = new_total_before
                order.total_amount_after_discount = new_total_before
                order.save(update_fields=['status', 'total_amount_before_discount', 'total_amount_after_discount'])
            
            # Update the order in the database only if the total has changed
            # This is crucial for subsequent staff actions (confirm/finalize)
            elif order.total_amount_after_discount != new_total_after:
                order.total_amount_before_discount = new_total_before
                order.total_amount_after_discount = new_total_after
                order.save(update_fields=['total_amount_before_discount', 'total_amount_after_discount'])


        # Re-fetch the queryset to get the updated values from the database
        orders = OnlineOrder.objects.filter(
            status__in=['pending', 'ready for pickup']
        ).order_by('-date_created')

        serializer = OnlineOrderListSerializer(orders, many=True)
        return Response(serializer.data)
        
    except Exception as e:
        print(f"[GET PENDING ONLINE ORDERS ERROR] {e}")
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

# -------------------------------
# Confirm Online Order
# -------------------------------
@api_view(['PUT'])
def confirm_online_order(request, orderId):
    """
    API view for staff to confirm a pending online order.
    Changes the status from 'pending' to 'ready for pickup'.
    Sends a push notification to the customer if a token exists.
    """
    try:
        staff_id = request.data.get('staff_id')
        if not staff_id:
            return Response({'error': 'Staff ID is required'}, status=status.HTTP_400_BAD_REQUEST)

        staff_user = Staff.objects.get(id=staff_id)

        with transaction.atomic():
            order = OnlineOrder.objects.get(id=orderId)

            if order.status == 'pending':
                # Update the order status
                order.status = 'ready for pickup'
                order.save()

                # Check for and update related Prescription status
                try:
                    prescription = Prescription.objects.get(online_order=order, status='pending')
                    prescription.status = 'ready for pickup'
                    prescription.save()
                except Prescription.DoesNotExist:
                    pass

                # Create a log entry for the confirmed online order
                OrderLog.objects.create(
                    staff_user=staff_user,
                    online_order=order,
                    action_type='online_confirmed',
                    description=f'Online order confirmed by staff member {staff_user.name} ({staff_user.role}).'
                )

                # -------------------------------
                # Send push notification to customer
                # -------------------------------
                try:
                    # FIX: Use .filter() to get all tokens and iterate through them
                    token_objects = CustomerFCMToken.objects.filter(customer=order.customer)
                    
                    if not token_objects.exists():
                        print(f"⚠️ No FCM tokens found for customer {order.customer.id}.")
                    else:
                        for token_obj in token_objects:
                            send_fcm_notification(
                                token=token_obj.token,
                                title="Your order is ready for pickup",
                                body=f"Hi {order.customer.name}, your order has been confirmed."
                            )
                except Exception as e:
                    # Log the error but continue the process
                    print(f"[FCM SEND ERROR] {e}")

                # This is the single, final success response
                return Response(
                    {"detail": "Online order confirmed successfully."},
                    status=status.HTTP_200_OK
                )
            else:
                return Response(
                    {"detail": f"Order status is '{order.status}' and cannot be confirmed."},
                    status=status.HTTP_400_BAD_REQUEST
                )
    except Staff.DoesNotExist:
        return Response({'error': 'Staff member not found'}, status=status.HTTP_404_NOT_FOUND)
    except OnlineOrder.DoesNotExist:
        return Response({"detail": "Online order not found."}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        print(f"[CONFIRM ORDER ERROR] {e}")
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )



















   
# Cashier Apply Discount
logger = logging.getLogger(__name__)

@api_view(['PUT'])
def update_order_discount(request, orderId):
    """
    Updates the discount for an online order.
    """
    try:
        # Fetch the order by its ID
        order = OnlineOrder.objects.get(id=orderId)
        
        # Check if the order status is 'pending' or 'ready for pickup'.
        # This prevents changes to already completed or cancelled orders.
        if order.status in ['pending', 'ready for pickup']:
            # Get the is_pwd value from the request body. Default to False if not provided.
            is_pwd_discount = request.data.get('is_pwd', False)
            
            if is_pwd_discount:
                # Apply a 20% discount (0.80) to the total amount before discount
                order.total_amount_after_discount = order.total_amount_before_discount * Decimal('0.80')
                order.is_pwd = True
            else:
                # Revert the discount if the checkbox is unchecked
                order.total_amount_after_discount = order.total_amount_before_discount
                order.is_pwd = False

            order.save()
            
            # Return the updated order data so the frontend can refresh the UI
            serializer = OnlineOrderListSerializer(order)
            return Response(
                {"message": "Discount updated successfully.", "order": serializer.data},
                status=status.HTTP_200_OK
            )
        else:
            # If the order is not in an editable status, return an error
            return Response(
                {"error": "Cannot update discount on a completed or cancelled order."},
                status=status.HTTP_400_BAD_REQUEST
            )

    except OnlineOrder.DoesNotExist:
        # Handle the case where no order is found with the given ID
        return Response({"error": "Order not found."}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        # Log and return a generic server error for any other exceptions
        logger.error(f"[UPDATE DISCOUNT ERROR] {e}")
        return Response({"error": "An unexpected error occurred."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

# Cashier Remove Item
@api_view(['DELETE'])
def remove_online_order_item(request, orderId, itemId):
    """
    API view to remove a specific item from an online order that is ready for pickup.
    This view will not affect the inventory, and will permanently delete the item.
    """
    try:
        # Validate that orderId and itemId are integers
        orderId = int(orderId)
        itemId = int(itemId)

        # Use an atomic transaction to ensure all database operations succeed or fail together
        with transaction.atomic():
            # Get the order and the item to be removed. The order must be 'ready for pickup'.
            order = OnlineOrder.objects.get(id=orderId, status='ready for pickup')
            order_item = OnlineOrderItem.objects.get(id=itemId, order=order)
            
            # Recalculate the order's total amount before applying the discount
            price_of_removed_item = order_item.quantity_sold * order_item.price_at_sale
            order.total_amount_before_discount -= price_of_removed_item
            
            # Recalculate the after-discount total based on whether a discount was applied
            if order.is_pwd:
                order.total_amount_after_discount = order.total_amount_before_discount * Decimal('0.80')
            else:
                order.total_amount_after_discount = order.total_amount_before_discount

            # Delete the order item permanently
            order_item.delete()

            # Save the updated order
            order.save()

            # Check if the order is now empty after the item was removed
            if not order.items.exists():
                order.status = 'cancelled'
                order.save()
                return Response(
                    {"detail": "Order item removed, and the order has been cancelled because it is now empty."},
                    status=status.HTTP_200_OK
                )
            
            # If the order is not empty, return the updated order data
            serializer = OnlineOrderListSerializer(order)
            return Response(
                {"detail": "Order item removed and order total updated successfully.", "order": serializer.data},
                status=status.HTTP_200_OK
            )

    except ValueError:
        # Catch a ValueError if the orderId or itemId can't be converted to an integer
        return Response(
            {"detail": "Invalid order or item ID format. IDs must be integers."},
            status=status.HTTP_400_BAD_REQUEST
        )
    except OnlineOrder.DoesNotExist:
        # If the order is not found or not in the 'ready for pickup' status
        return Response(
            {"detail": "Online order not found or is not ready for pickup."},
            status=status.HTTP_404_NOT_FOUND
        )
    except OnlineOrderItem.DoesNotExist:
        # If the specific item is not found within the order
        return Response(
            {"detail": "Order item not found."},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        # Log and return a generic server error for any other exceptions
        logger.error(f"[REMOVE ORDER ITEM ERROR] {e}")
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['PUT'])
def cancel_online_order_cashier(request, orderId):
    """
    API view to cancel an online order that is ready for pickup.
    This will not affect the inventory.
    """
    try:
        staff_id = request.data.get('staff_id')
        if not staff_id:
            return Response({'error': 'Staff ID is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        staff_user = Staff.objects.get(id=staff_id)
        
        with transaction.atomic():
            order = OnlineOrder.objects.get(id=orderId, status='ready for pickup')
            
            # Update the order status to 'cancelled' and save the change
            order.status = 'cancelled'
            order.save()
            
            # NEW: Create a log entry for the cancelled online order
            OrderLog.objects.create(
                staff_user=staff_user,
                online_order=order,
                action_type='online_cancelled',
                description=f'Online order cancelled by cashier {staff_user.name}.'
            )
            
            return Response(
                {"detail": "Online order cancelled successfully."},
                status=status.HTTP_200_OK
            )
    except Staff.DoesNotExist:
        return Response({'error': 'Staff member not found'}, status=status.HTTP_404_NOT_FOUND)
    except OnlineOrder.DoesNotExist:
        return Response(
            {"detail": "Online order not found or is not ready for pickup."},
            status=status.HTTP_404_NOT_FOUND
        )
    except Exception as e:
        logger.error(f"[CANCEL ORDER ERROR] {e}")
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )











# ---------------9/30/25
#=====================9/1/25===================    ===================== 9/4/25 (online orders added in inventory logs)===================
#--9/29/25-- MODIFIED FOR DIALOGUE BOX
@api_view(['PUT'])
def finalize_online_order(request, orderId):
    """
    API view to finalize an online order after pickup.
    This marks the order status as 'completed' and deducts the inventory.
    
    This function now correctly handles both regular and promo items, deducting
    from their respective inventory batches using FEFO logic.
    """
    try:
        staff_id = request.data.get('staff_id')
        force_approve = request.data.get('force_approve', False) # <-- Add this line
        if not staff_id:
            return Response({'error': 'Staff ID is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        staff_user = Staff.objects.get(id=staff_id)

        with transaction.atomic():
            order = OnlineOrder.objects.get(id=orderId, status='ready for pickup')

            # ======== NEW PRESCRIPTION LOGIC FOR DIALOGUE BOX ========
            force_approve = request.data.get('force_approve', False)
            
            # Determine if any item in the order requires a prescription
            order_requires_prescription = any(
                item.inventory_id.medicine.requires_prescription for item in order.items.all()
            )

            # Check for a prescription image if required and force_approve is not set
            if order_requires_prescription and not force_approve:
                has_image = PrescriptionImage.objects.filter(prescription__online_order=order).exists()

                if has_image:
                    return Response(
                        {
                            "warning": "This order contains items that require a prescription. An image has been uploaded.",
                            "has_image": True
                        },
                        status=status.HTTP_202_ACCEPTED
                    )
                else:
                    return Response(
                        {
                            "warning": "This order contains items that require a prescription, and no image has been uploaded.",
                            "has_image": False
                        },
                        status=status.HTTP_202_ACCEPTED
                    )
            # ==========================================================

            # ORIGINAL CODE CONTINUES HERE
            
            # Step 1: Aggregate the total quantity required for each medicine,
            # separating regular and promo items.
            regular_items_to_deduct = {}
            promo_items_to_deduct = {}
            
            for item in order.items.all():
                # CRITICAL FIX: Skip items that are deleted/unlinked from inventory.
                # This prevents the 500 error (AttributeError).
                if not item.inventory_id or not item.inventory_id.medicine:
                    continue
                    
                medicine_id = item.inventory_id.medicine.id
                quantity_needed = item.quantity_sold + item.free_quantity_given
                
                if item.inventory_id.is_promo:
                    # This is a promo item
                    if medicine_id not in promo_items_to_deduct:
                        promo_items_to_deduct[medicine_id] = {
                            'name': item.inventory_id.medicine.name,
                            'quantity': 0
                        }
                    promo_items_to_deduct[medicine_id]['quantity'] += quantity_needed
                else:
                    # This is a regular item
                    if medicine_id not in regular_items_to_deduct:
                        regular_items_to_deduct[medicine_id] = {
                            'name': item.inventory_id.medicine.name,
                            'quantity': 0
                        }
                    regular_items_to_deduct[medicine_id]['quantity'] += quantity_needed

            # Step 2: Deduct from regular inventory batches (is_promo=False)
            for medicine_id, data in regular_items_to_deduct.items():
                required_quantity = data['quantity']
                medicine_name = data['name']
                
                # Get all regular batches for this medicine, ordered by expiry date (FEFO)
                batches = Inventory.objects.select_for_update().filter(
                    medicine_id=medicine_id,
                    is_promo=False, # Filter for regular stock
                    quantity__gt=0,
                ).order_by('exp_date')
                
                # Check if there is enough total stock before starting the deduction loop
                total_available_stock = sum(batch.quantity for batch in batches)
                if total_available_stock < required_quantity:
                    raise ValueError(
                        f"Insufficient regular stock for {medicine_name}. Available: {total_available_stock}, Required: {required_quantity}"
                    )
                
                remaining_to_deduct = required_quantity
                for batch in batches:
                    if remaining_to_deduct <= 0:
                        break 
                    amount_to_take = min(remaining_to_deduct, batch.quantity)
                    batch.quantity -= amount_to_take
                    batch.save()
                    remaining_to_deduct -= amount_to_take

                    # Log the sale in InventoryLog for the specific batch
                    InventoryLog.objects.create(
                        user=staff_user,
                        medicine=batch.medicine,
                        staff_name=staff_user.name,
                        staff_role=staff_user.role,
                        action_type='Sold',
                        description=f"Sold {amount_to_take} units of '{batch.medicine.name}' (Batch: {batch.batch_num}) from online order #{orderId}.",
                        medicine_name_log=batch.medicine.name # <-- Add this line
                    )

            # Step 3: Deduct from promo inventory batches (is_promo=True)
            for medicine_id, data in promo_items_to_deduct.items():
                required_quantity = data['quantity']
                medicine_name = data['name']
                
                # Get all promo batches for this medicine, ordered by expiry date (FEFO)
                batches = Inventory.objects.select_for_update().filter(
                    medicine_id=medicine_id,
                    is_promo=True, # Filter for promo stock
                    quantity__gt=0,
                ).order_by('exp_date')
                
                # Check if there is enough total stock before starting the deduction loop
                total_available_stock = sum(batch.quantity for batch in batches)
                if total_available_stock < required_quantity:
                    raise ValueError(
                        f"Insufficient promo stock for {medicine_name}. Available: {total_available_stock}, Required: {required_quantity}"
                    )
                
                remaining_to_deduct = required_quantity
                for batch in batches:
                    if remaining_to_deduct <= 0:
                        break 
                    amount_to_take = min(remaining_to_deduct, batch.quantity)
                    batch.quantity -= amount_to_take
                    batch.save()
                    remaining_to_deduct -= amount_to_take

                    # Log the sale in InventoryLog for the specific batch
                    InventoryLog.objects.create(
                        user=staff_user,
                        medicine=batch.medicine,
                        action_type='Sold',
                        staff_name=staff_user.name,
                        staff_role=staff_user.role,
                        description=f"Sold {amount_to_take} units of '{batch.medicine.name}' (Batch: {batch.batch_num}) from online order #{orderId}."
                        f"({item.quantity_sold} paid, {item.free_quantity_given} free).",
                        medicine_name_log=batch.medicine.name # <-- Add this line
                    )

            # Step 4: Update the order status and create a log entry after successful deduction.
            # This is the correct order of operations.
            from .serializers import OnlineOrderListSerializer

            order.date_fulfilled = timezone.now()
            order.status = 'completed'
            order.save()
            
            # Create the log entry after the order is successfully finalized and saved.
            OrderLog.objects.create(
                staff_user=staff_user,
                online_order=order,
                action_type='online_picked_up',
                description=f'Online order marked as picked up'
            )

            # The serializer automatically handles the date formatting correctly
            serializer = OnlineOrderListSerializer(order)
            return Response(serializer.data, status=status.HTTP_200_OK)

    except Staff.DoesNotExist:
        return Response({'error': 'Staff member not found'}, status=status.HTTP_404_NOT_FOUND)
    except OnlineOrder.DoesNotExist:
        return Response(
            {"detail": "Online order not found or is not ready for pickup."},
            status=status.HTTP_404_NOT_FOUND
        )
    except ValueError as ve:
        return Response(
            {"detail": str(ve)},
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        # A more robust error logging and handling mechanism might be needed for production
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
        
#==================================================================================================





        
#------instore sales transaction views----------------

class InStoreSalesTransactionView(generics.ListAPIView):
    # Make sure this serializer is imported correctly
    # from .serializers import InStoreSalesTransactionSerializer
    serializer_class = InStoreSalesTransactionSerializer

    def get_queryset(self):
        queryset = InStoreOrder.objects.all().order_by('-date_created')

        filter_date_str = self.request.query_params.get('date', None)

        if filter_date_str:
            try:
                filter_date = date.fromisoformat(filter_date_str)
                # Filter for records from the start of the day to the end of the day
                start_of_day = filter_date
                end_of_day = filter_date + timedelta(days=1)
                
                queryset = queryset.filter(date_created__gte=start_of_day, date_created__lt=end_of_day)
            except ValueError:
                pass

        return queryset    






# ---------------9/26/25
# Online Orders Transaction for Manager View
#--------------------09/14/2025--------------------------- fixing return medicine
# Online Orders Transaction
@api_view(['GET'])
def completed_online_orders_report(request):
    """
    API endpoint to retrieve all completed online orders with detailed breakdowns.
    """
    try:
        # Start with all completed orders
        completed_orders = OnlineOrder.objects.filter(status='completed')

        # Check if a date parameter is provided in the query
        date_param = request.query_params.get('date')

        if date_param:
            try:
                # Convert the string date to a naive date object
                target_date = datetime.strptime(date_param, '%Y-%m-%d').date()

                # Get the timezone set in your Django settings
                local_timezone = timezone.get_current_timezone()

                # Create timezone-aware start and end datetimes for the target day
                start_of_day = timezone.make_aware(
                    datetime.combine(target_date, datetime.min.time()),
                    local_timezone
                )
                end_of_day = timezone.make_aware(
                    datetime.combine(target_date, datetime.max.time()),
                    local_timezone
                )

                # Filter for orders created within this precise date range
                completed_orders = completed_orders.filter(
                    date_created__range=(start_of_day, end_of_day)
                )
            
            except ValueError:
                return Response(
                    {"error": "Invalid date format. Use YYYY-MM-DD."}, 
                    status=status.HTTP_400_BAD_REQUEST
                )
        
        # Order the results by creation date
        completed_orders = completed_orders.order_by('-date_created')

        orders_data = []
        for order in completed_orders:
            # Get initiated and approved staff from logs
            initiated_by_log = OrderLog.objects.filter(online_order=order, action_type='online_confirmed').first()
            approved_by_log = OrderLog.objects.filter(online_order=order, action_type='online_picked_up').first()
            
            # Get the customer type based on the 'is_pwd' field
            customer_type = 'Discounted' if order.is_pwd else 'Regular'
            
            # Get the timestamp from the 'date_created' field and format it
            fulfilled_timestamp = order.date_created.isoformat() if order.date_created else 'N/A'
            
            # Calculate subtotal and discount
            subtotal_amount = order.total_amount_before_discount
            discount_amount = subtotal_amount - order.total_amount_after_discount
            
            # Get items
            items_data = []
            # ⭐ CRITICAL FIX: Filter out items with a zero sale price.
            # This safely excludes the item that was removed while pending 
            # (Ascof), without using inventory_id which breaks historical data.
            for item in order.items.filter(price_at_sale__gt=0):
                # 💡 SIMPLIFIED AND FIXED LOGIC 💡
                # The medicine_name is now stored directly on the OnlineOrderItem
                # So you don't need to check the inventory_id at all for the name.
                
                items_data.append({
                    'medicine_name': item.medicine_name,
                    'generic_name': item.generic_name,
                    'quantity_ordered': item.quantity_sold,
                    'promo_quantity': item.free_quantity_given,
                    'item_total': float(item.price_at_sale * item.quantity_sold),
                })
            
            initiated_by_name = 'N/A'
            initiated_by_role = 'N/A'
            if initiated_by_log and initiated_by_log.staff_user:
                initiated_by_name = initiated_by_log.staff_user.name
                initiated_by_role = initiated_by_log.staff_user.role.capitalize()

            approved_by_name = 'N/A'
            approved_by_role = 'N/A'
            if approved_by_log and approved_by_log.staff_user:
                approved_by_name = approved_by_log.staff_user.name
                approved_by_role = approved_by_log.staff_user.role.capitalize()
            
            orders_data.append({
                'order_id': order.id,
                'customer_name': order.customer.name,
                'customer_type': customer_type,
                'initiated_by_name': initiated_by_name,
                'initiated_by_role': initiated_by_role,
                'approved_by_name': approved_by_name,
                'approved_by_role': approved_by_role,
                'total_amount': float(order.total_amount_after_discount),
                'subtotal_amount': float(subtotal_amount),
                'discount_amount': float(discount_amount),
                'fulfilled_timestamp': fulfilled_timestamp,
                'medicines_ordered': items_data,
            })
        
        return Response(orders_data, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({"error": f"An unexpected error occurred: {str(e)}"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)








        
#--------------------09/14/2025--------------------------- fixing return medicine
#===================In-store Sales Report=================   =================09/05/2025===================
class InStoreSalesReportView(APIView):
    def get(self, request, *args, **kwargs):
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')

        if not start_date_str or not end_date_str:
            return Response(
                {"error": "Please provide both start_date and end_date query parameters in YYYY-MM-DD format."},
                status=400
            )

        try:
            start_datetime = timezone.make_aware(datetime.strptime(start_date_str, '%Y-%m-%d'))
            end_datetime = timezone.make_aware(datetime.strptime(end_date_str, '%Y-%m-%d') + timedelta(days=1) - timedelta(seconds=1))
        except ValueError:
            return Response({"error": "Invalid date format. Please use YYYY-MM-DD."}, status=400)

        # **CRITICAL CHANGE HERE: FILTER DIRECTLY ON InStoreOrder**
        approved_orders = InStoreOrder.objects.filter(
            status='approved',
            date_created__range=[start_datetime, end_datetime]
        ).select_related('staff', 'cashier').prefetch_related(
            Prefetch('items', queryset=InStoreOrderItem.objects.select_related('inventory_id__medicine'))
        )

        total_revenue = sum(o.total_amount_after_discount for o in approved_orders)

        sales_data = {}
        for order in approved_orders:
            if order.total_amount_before_discount > 0:
                discount_percentage = (order.total_amount_before_discount - order.total_amount_after_discount) / order.total_amount_before_discount
            else:
                discount_percentage = Decimal('0.00')

            for item in order.items.all():  # Use .all() since it's already prefetched
                # --- CORRECTED LOGIC START ---
                # Check for the medicine_name field first, since it is now populated
                if item.medicine_name:
                    medicine_name = item.medicine_name
                else:
                    # Fallback for the old records that were not backfilled with a name
                    medicine_name = "N/A"
                # --- CORRECTED LOGIC END ---

                if medicine_name not in sales_data:
                    sales_data[medicine_name] = {
                        'quantity_sold': 0,
                        'total_sale': Decimal('0.00')
                    }
                
                sales_data[medicine_name]['quantity_sold'] += item.quantity_sold + item.free_quantity_given
                
                discounted_price_at_sale = item.price_at_sale * (1 - discount_percentage)
                item_total_sale = item.quantity_sold * discounted_price_at_sale
                sales_data[medicine_name]['total_sale'] += item_total_sale

        formatted_sales_data = [
            {
                'medicine': name,
                'quantity_sold': data['quantity_sold'],
                'total_sale': data['total_sale']
            }
            for name, data in sales_data.items()
        ]

        response_data = {
            'total_revenue': total_revenue,
            'reporting_period': {
                'start_date': start_date_str,
                'end_date': end_date_str
            },
            'sales_report': formatted_sales_data
        }

        return Response(response_data)









# ---------------9/26/25
#--------------------09/14/2025--------------------------- fixing return medicine
#===================Online Sales Report=================  
class OnlineSalesReportView(APIView):
    def get(self, request, *args, **kwargs):
        start_date_str = request.query_params.get('start_date')
        end_date_str = request.query_params.get('end_date')

        # Debug: print the raw query params
        print(f"DEBUG: Raw start_date_str={start_date_str}, end_date_str={end_date_str}")

        if not start_date_str or not end_date_str:
            return Response(
                {"error": "Please provide both start_date and end_date in YYYY-MM-DD format."},
                status=400
            )

        try:
            # Parse and make timezone-aware
            start_datetime = timezone.make_aware(
                datetime.strptime(start_date_str, '%Y-%m-%d')
            )
            end_datetime = timezone.make_aware(
                datetime.strptime(end_date_str, '%Y-%m-%d') + timedelta(days=1) - timedelta(seconds=1)
            )
        except ValueError:
            return Response({"error": "Invalid date format. Please use YYYY-MM-DD."}, status=400)

        # Debug: print the aware datetimes
        print(f"DEBUG: start_datetime={start_datetime}, end_datetime={end_datetime}")

        # Filter completed online orders within date range
        completed_orders = OnlineOrder.objects.filter(
            status='completed',
            date_fulfilled__range=[start_datetime, end_datetime]
        )
        
        print(f"DEBUG: completed_orders.count()={completed_orders.count()}")

        # Calculate total revenue
        total_revenue = sum(order.total_amount_after_discount for order in completed_orders)
        print(f"DEBUG: total_revenue={total_revenue}")
        
        # Aggregate sales by medicine
        sales_data = {}
        for order in completed_orders:
            # Check for a discount applied to the entire order (e.g., PWD discount)
            if order.total_amount_before_discount > 0:
                discount_percentage = (order.total_amount_before_discount - order.total_amount_after_discount) / order.total_amount_before_discount
            else:
                discount_percentage = Decimal('0.00')

            # ⭐ THE FINAL FIX APPLIED CORRECTLY: Filter out excluded items (price_at_sale = 0)
            order_items = OnlineOrderItem.objects.filter(order=order, price_at_sale__gt=0)
            
            # Iterate through each item in the order to aggregate sales and quantities.
            for item in order_items:
                # --- CORRECTED LOGIC START ---
                if item.medicine_name:
                    med_name = item.medicine_name
                elif item.inventory_id:
                    # Fallback for old records if name wasn't backfilled
                    med_name = item.inventory_id.medicine.name
                else:
                    # Final fallback for records with no inventory link
                    med_name = "N/A"
                # --- CORRECTED LOGIC END ---
                
                if med_name not in sales_data:
                    sales_data[med_name] = {
                        'quantity_sold': 0,
                        'total_sale': 0
                    }
                
                # The total number of items sold is the sum of paid and free quantities.
                sales_data[med_name]['quantity_sold'] += item.quantity_sold + item.free_quantity_given
                
                # Apply the discount percentage to the price of each paid item.
                # Free items (price_at_sale=0) will still contribute 0 to the total sale.
                discounted_price_at_sale = item.price_at_sale * (1 - discount_percentage)
                item_total_sale = item.quantity_sold * discounted_price_at_sale
                sales_data[med_name]['total_sale'] += item_total_sale

        # Format sales data
        formatted_sales = [
            {
                'medicine': name,
                'quantity_sold': data['quantity_sold'],
                'total_sale': data['total_sale']
            }
            for name, data in sales_data.items()
        ]

        return Response({
            'total_revenue': total_revenue,
            'reporting_period': {
                'start_date': start_date_str,
                'end_date': end_date_str
            },
            'sales_report': formatted_sales
        })

# --- NEW ENDPOINT FOR COMPREHENSIVE REPORT ---
@api_view(['GET'])
def get_comprehensive_transaction_report(request):
    """
    API endpoint to retrieve a combined report of all sales and returned medicines.
    
    This report unifies data from InStoreOrder, OnlineOrder, and ReturnedMedicine,
    allowing for a single, comprehensive view of all stock movements.
    """
    start_date_str = request.query_params.get('start_date')
    end_date_str = request.query_params.get('end_date')

    if not start_date_str or not end_date_str:
        return Response(
            {"error": "Please provide both start_date and end_date query parameters in YYYY-MM-DD format."},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        start_datetime = timezone.make_aware(datetime.strptime(start_date_str, '%Y-%m-%d'))
        end_datetime = timezone.make_aware(datetime.strptime(end_date_str, '%Y-%m-%d') + timedelta(days=1) - timedelta(seconds=1))
    except ValueError:
        return Response({"error": "Invalid date format. Please use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

    # 1. Fetch In-Store Sales Data
    # The prefetch is now simplified since we no longer need the inventory_id for the name
    in_store_sales = InStoreOrder.objects.filter(
        status='approved',
        date_created__range=[start_datetime, end_datetime]
    ).prefetch_related(
        Prefetch('items', queryset=InStoreOrderItem.objects.all())
    )

    # 2. Fetch Online Sales Data
    # The prefetch is now simplified since we no longer need the inventory_id for the name
    online_sales = OnlineOrder.objects.filter(
        status='completed',
        date_fulfilled__range=[start_datetime, end_datetime]
    ).prefetch_related(
        Prefetch('items', queryset=OnlineOrderItem.objects.all())
    )

    # 3. Fetch Returned Medicine Data
    returned_items = ReturnedMedicine.objects.filter(
        returned_at__range=[start_datetime, end_datetime]
    ).select_related('medicine')

    # Now, combine all data into a single list
    combined_transactions = []

    # Process In-Store Sales
    for order in in_store_sales:
        items_list = []
        for item in order.items.all():
            # --- CORRECTED LOGIC ---
            items_list.append({
                'medicine_name': item.medicine_name, # Get name from the fixed field
                'quantity': item.quantity_sold + item.free_quantity_given,
                'price_at_transaction': float(item.price_at_sale),
            })
        combined_transactions.append({
            'transaction_type': 'In-Store Sale',
            'date': order.date_created,
            'total_amount': float(order.total_amount_after_discount),
            'items': items_list,
        })

    # Process Online Sales
    for order in online_sales:
        items_list = []
        for item in order.items.all():
            # --- CORRECTED LOGIC ---
            items_list.append({
                'medicine_name': item.medicine_name, # Get name from the fixed field
                'quantity': item.quantity_sold + item.free_quantity_given,
                'price_at_transaction': float(item.price_at_sale),
            })
        combined_transactions.append({
            'transaction_type': 'Online Sale',
            'date': order.date_fulfilled,
            'total_amount': float(order.total_amount_after_discount),
            'items': items_list,
        })

    # Process Returned Medicines
    for item in returned_items:
        combined_transactions.append({
            'transaction_type': 'Returned',
            'date': item.returned_at,
            'total_amount': None,  # No total amount for returns
            'items': [{
                'medicine_name': item.medicine.name,
                'quantity': item.quantity,
                'price_at_transaction': None, # No price for return since it's an expense
            }],
        })

    # Sort the combined list by date, from newest to oldest
    combined_transactions.sort(key=lambda x: x['date'], reverse=True)

    return Response(combined_transactions, status=status.HTTP_200_OK)














#---presc-----------------------------------
# ─────────── STAFF PRESCRIPTION VIEWS ───────────
@api_view(['GET'])
@authentication_classes([])
@permission_classes([AllowAny])
def list_pending_prescription_orders(request):
    """
    API endpoint to retrieve all pending in-store orders that require a prescription.
    This version only shows prescriptions that do not have images yet.
    """
    # Find all pending Prescription records.
    # Use select_related and prefetch_related for efficient fetching of related data.
    pending_prescriptions = Prescription.objects.filter(
        status='pending'
    ).filter(
        images__isnull=True
    ).select_related(
        'in_store_order__staff'
    ).prefetch_related(
        'in_store_order__items__inventory_id__medicine'
    )

    # Use a serializer to format the data for the response
    serializer = PrescriptionOrderSerializer(pending_prescriptions, many=True)
    
    return Response(serializer.data, status=status.HTTP_200_OK)

@api_view(['GET'])
@authentication_classes([])
@permission_classes([AllowAny])
def list_all_pending_prescriptions(request):
    """
    API endpoint to retrieve all pending in-store prescriptions and 
    'ready for pickup' online prescriptions for staff.
    This version only shows prescriptions that do not have images yet.
    """
    pending_prescriptions = Prescription.objects.filter(
        (Q(status='pending') | Q(status='ready for pickup')) & Q(images__isnull=True)
    ).select_related(
        'in_store_order__staff', 
        'online_order__customer'
    ).prefetch_related(
        'in_store_order__items__inventory_id__medicine',
        'online_order__items__inventory_id__medicine'
    ).order_by('-date_uploaded')

    serializer = CombinedPrescriptionSerializer(pending_prescriptions, many=True)
    
    return Response(serializer.data, status=status.HTTP_200_OK)

# ─────────── NEW VIEW FOR IMAGE UPLOAD ───────────
@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser])
def upload_prescription_images(request, pk):
    """
    API endpoint to upload multiple images for a specific prescription.
    """
    try:
        prescription = Prescription.objects.get(pk=pk)
    except Prescription.DoesNotExist:
        return Response({'error': 'Prescription not found.'}, status=status.HTTP_404_NOT_FOUND)

    images = request.FILES.getlist('images')

    if not images:
        return Response({'error': 'No images were uploaded.'}, status=status.HTTP_400_BAD_REQUEST)

    for image_file in images:
        PrescriptionImage.objects.create(prescription=prescription, image=image_file)

    # You can return a simple success message or the updated prescription object
    return Response({'message': f'Successfully uploaded {len(images)} images for Prescription ID: {pk}.'}, status=status.HTTP_201_CREATED)

# ─────────── CASHIER PRESCRIPTION VIEWS ───────────
@api_view(['GET'])
@authentication_classes([])
@permission_classes([AllowAny])
def list_cashier_prescriptions(request):
    """
    API endpoint for cashiers to view prescription orders that already have images.
    """
    # Filter for prescriptions that have at least one associated image.
    cashier_prescriptions = Prescription.objects.filter(
        images__isnull=False
    ).select_related(
        'in_store_order__staff', 
        'online_order__customer'
    ).prefetch_related(
        'in_store_order__items__inventory_id__medicine',
        'online_order__items__inventory_id__medicine'
    ).distinct().order_by('-date_uploaded')

    serializer = CombinedPrescriptionSerializer(cashier_prescriptions, many=True)
    
    return Response(serializer.data, status=status.HTTP_200_OK)























# ─────────── MANAGER EXPIRATION NOTIFICATION ───────────
@api_view(['POST'])
def check_expired_and_notify_manager(request):
    """
    Checks for expired medicines and sends an SMS notification to the manager if any are found.
    """
    # This check is removed for the quick fix
    # if not request.user.is_authenticated or not request.user.is_manager:
    #     return Response({'error': 'You do not have permission to perform this action.'}, status=status.HTTP_403_FORBIDDEN)
    
    # Get the Staff profile of the manager with the correct role (adjust this to match your model)
    try:
        manager_profile = Staff.objects.get(role='manager')
        manager_number = manager_profile.contact_num
    except Staff.DoesNotExist:
        return Response({'error': 'Staff profile for manager not found.'}, status=status.HTTP_404_NOT_FOUND)

    today = date.today()
    expired_items = Inventory.objects.filter(exp_date__lte=today, quantity__gt=0).select_related('medicine')

    if expired_items.exists():
        message_lines = ["EXPIRATION ALERT"]
        message_lines.append("The following medicines have expired:")
        
        for item in expired_items:
            # Added the batch number to the message content
            message_lines.append(f"  * {item.medicine.name} (Batch: {item.batch_num}, Qty: {item.quantity})")
            
        message = "\n".join(message_lines)
        
        success, response_data = send_sms(manager_number, message)
        
        if success:
            return Response({'message': 'Manager notified of expired stocks via SMS.', 'sms_response': response_data}, status=status.HTTP_200_OK)
        else:
            return Response({'message': 'Failed to send SMS notification.', 'sms_response': response_data}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

    return Response({'message': 'No expired medicines found. No SMS sent.'}, status=status.HTTP_200_OK)


#-----PUSH NOTIF
# -------------------------------
# Save Customer FCM Token
# -------------------------------
@api_view(['POST'])
def save_customer_fcm_token(request):
    """
    Save or update the FCM token for a customer.
    """
    try:
        fcm_token = request.data.get('fcm_token')
        customer_id = request.data.get('customer_id')

        if not fcm_token or not customer_id:
            return Response(
                {'error': 'FCM token and Customer ID are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            customer_instance = Customer.objects.get(id=customer_id)
        except Customer.DoesNotExist:
            return Response({'error': 'Customer not found.'}, status=status.HTTP_404_NOT_FOUND)

        # ✅ CORRECTED LOGIC: Use 'token' as the lookup key, and update the 'customer'
        token_obj, created = CustomerFCMToken.objects.update_or_create(
            token=fcm_token,  # Lookup by token
            defaults={'customer': customer_instance}, # Update the customer
        )

        if created:
            return Response({'detail': 'FCM token created successfully.'}, status=status.HTTP_201_CREATED)
        else:
            return Response({'detail': 'FCM token updated successfully.'}, status=status.HTTP_200_OK)

    except Exception as e:
        print(f"[SAVE FCM TOKEN ERROR] {e}")
        return Response({'error': 'An unexpected error occurred.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    
    
    
    
    
    
    
    
    
    
#----FOR DASHBOARD

# total summary of earning (both online and instore)
@api_view(['GET'])
def total_combined_earnings(request):
    """
    Calculates the total earnings from both approved in-store and online orders.
    """
    # Sum the total_amount_after_discount for all approved in-store orders
    in_store_total = InStoreOrder.objects.filter(status__iexact='approved').aggregate(
        total=Sum('total_amount_after_discount')
    )['total'] or 0

    # Corrected: Sum the 'total_amount_after_discount' for all completed online orders
    online_total = OnlineOrder.objects.filter(status__iexact='completed').aggregate(
        total=Sum('total_amount_after_discount')
    )['total'] or 0

    combined_total = in_store_total + online_total

    return Response({'total_earnings': combined_total})








#------9/20/25 changes
# for low stocks:
@api_view(['GET'])
def low_stock_list(request):
    """
    Returns a list of unexpired medicines with a total quantity at or below 
    their restock threshold, based on dosage form.
    """
    # Define the dynamic thresholds based on dosage form
    low_stock_threshold = Case(
        When(medicine__dosage_form__in=['tablet', 'capsule'], then=20),
        When(medicine__dosage_form='syrup', then=10),
        default=F('medicine__restock_quantity'), # Fallback to restock_quantity if needed
        output_field=IntegerField(),
    )

    low_stock_medicines = TotalQuantity.objects.filter(
        total_quantity__lte=low_stock_threshold,
        medicine__inventory_entries__exp_date__gt=timezone.now().date()
    ).distinct().select_related('medicine')

    serializer = LowStockSerializer(low_stock_medicines, many=True)
    return Response(serializer.data)
#------9/20/25 changes






#total count
@api_view(['GET'])
def total_medicine_count(request):
    """
    Returns the total number of medicines in the database.
    """
    total_count = Medicine.objects.count()
    return Response({'total_count': total_count})


# ====================================================================
# DEMAND FORECASTING VIEWS
# ====================================================================

# NEW VIEW: This is the view that your Flutter app's POST request calls
@api_view(['POST'])
def generate_forecast_report(request):
    """
    API endpoint to trigger the generation of a new demand forecast report.
    This is where you will add your core forecasting logic.
    """
    if request.method == 'POST':
        try:
            # TODO: Implement your full forecasting logic here.
            # 1. Fetch sales data for all medicines.
            # 2. Process data and apply your forecasting model.
            # 3. Calculate current stock and restock amounts.
            # 4. Save the new ForecastReport and its ForecastItems to the database.

            # For now, we will just return a success message.
            # Replace this with your actual logic.
            return Response(
                {'message': 'Forecast generation initiated successfully.'},
                status=status.HTTP_200_OK
            )
        except Exception as e:
            return Response(
                {'error': f"An error occurred during forecast generation: {e}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

# The view to retrieve the latest report
class LatestForecastReportView(generics.RetrieveAPIView):
    """
    API view to retrieve the latest demand forecast report.
    """
    queryset = ForecastReport.objects.all()
    serializer_class = ForecastReportSerializer

    def get_object(self):
        try:
            return ForecastReport.objects.latest('week_start_date')
        except ForecastReport.DoesNotExist:
            return None

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        if instance is None:
            return Response(
                {"detail": "No demand forecast reports have been generated yet."},
                status=status.HTTP_404_NOT_FOUND
            )
        
        serializer = self.get_serializer(instance)
        return Response(serializer.data)

# The view to retrieve historical sales data for a specific medicine
class MedicineSalesHistoryView(APIView):
    """
    API endpoint to retrieve a medicine's weekly sales history.
    """
    def get(self, request, medicine_id, *args, **kwargs):
        try:
            medicine = Medicine.objects.get(pk=medicine_id)
        except Medicine.DoesNotExist:
            return Response(
                {"detail": "Medicine not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        end_date = datetime.now()
        start_date = end_date - timedelta(days=2 * 365) # Use 2 years of history

        try:
            in_store_sales = InStoreOrderItem.objects.filter(
                inventory_id__medicine=medicine,
                order__date_created__gte=start_date, 
                order__date_created__lte=end_date
            ).values('order__date_created', 'quantity_sold')

            online_sales = OnlineOrderItem.objects.filter(
                inventory_id__medicine=medicine,
                order__date_created__gte=start_date,
                order__date_created__lte=end_date
            ).values('order__date_created', 'quantity_sold')
            
            combined_sales = list(in_store_sales) + list(online_sales)

        except Exception as e:
            return Response(
                {"error": f"An error occurred while fetching data: {e}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        if not combined_sales:
            return Response({"detail": "No historical sales data found for this medicine."}, status=status.HTTP_200_OK)

        df = pd.DataFrame(combined_sales)
        df.rename(columns={'order__date_created': 'date'}, inplace=True)
        df.set_index('date', inplace=True)
        
        weekly_sales_df = df.groupby(pd.Grouper(freq='W')).agg(
            total_sales=('quantity_sold', 'sum')
        ).reset_index()

        historical_data = [
            {'week_start_date': row['date'].strftime('%Y-%m-%d'), 'sales': row['total_sales']}
            for index, row in weekly_sales_df.iterrows()
        ]

        return Response(historical_data, status=status.HTTP_200_OK)
    

















#----------10/1/25


# ==================== PURCHASE REQUEST LOGIC ===========================

class PurchaseRequestListView(APIView):
    def get(self, request, *args, **kwargs):
        latest_report = ForecastReport.objects.order_by('-date_generated').first()

        if not latest_report:
            return Response({"error": "No forecast reports found."}, status=status.HTTP_404_NOT_FOUND)

        # CRITICAL: We MUST include 'medicine__supplier' here again.
        # This allows us to access the Supplier data directly when it exists.
        forecast_items = ForecastItem.objects.filter(
            forecast_report=latest_report,
            restock_amount__gt=0,
            medicine__isnull=False
        ).select_related('medicine', 'medicine__supplier').order_by('rank') # Re-added 'medicine__supplier'

        purchase_request_list = []
        for item in forecast_items:
            medicine = item.medicine
            supplier = medicine.supplier # Will be the Supplier object (if exists) or None (if deleted)

            # --- Conditional Logic to determine Supplier Data Source ---
            if supplier:
                # SCENARIO 1: Supplier EXISTS (supplier is a valid object)
                # Use the LIVE data from the Supplier model to ensure it's up-to-date.
                supplier_name_data = supplier.name
                contact_num_data = supplier.contact
            else:
                # SCENARIO 2: Supplier is DELETED (supplier is None)
                # Fall back to the resilient snapshot data on the Medicine model.
                supplier_name_data = medicine.supplier_name if medicine.supplier_name else '[N/A - Snapshot Missing]'
                contact_num_data = medicine.supplier_contact_num if medicine.supplier_contact_num else 'N/A'
            # -----------------------------------------------------------

            # Construct the item data
            purchase_request_list.append({
                'no': item.rank,
                'medicine_name': medicine.name,
                'restock_amount': item.restock_amount,
                'units_per_items': medicine.restock_quantity,
                'supplier_name': supplier_name_data, # Use the determined data
                'contact_num': contact_num_data      # Use the determined data
            })

        return Response(purchase_request_list, status=status.HTTP_200_OK)
# ==================== END PURCHASE REQUEST LOGIC ===========================
#----------9/23/25
















#--------EXPIRATION NOTIFICATION
# -------------------------------
# Save Staff FCM Token
# -------------------------------
@api_view(['POST'])
def save_staff_fcm_token(request):
    """
    Save or update the FCM token for a staff member.
    """
    try:
        fcm_token = request.data.get('fcm_token')
        staff_id = request.data.get('staff_id')

        if not fcm_token or not staff_id:
            return Response(
                {'error': 'FCM token and Staff ID are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            staff_instance = Staff.objects.get(id=staff_id)
        except Staff.DoesNotExist:
            return Response({'error': 'Staff member not found.'}, status=status.HTTP_404_NOT_FOUND)

        # Use update_or_create to handle new or existing tokens
        token_obj, created = StaffFCMToken.objects.update_or_create(
            token=fcm_token,
            defaults={'staff': staff_instance},
        )

        if created:
            return Response({'detail': 'FCM token for staff created successfully.'}, status=status.HTTP_201_CREATED)
        else:
            return Response({'detail': 'FCM token for staff updated successfully.'}, status=status.HTTP_200_OK)

    except Exception as e:
        print(f"[SAVE STAFF FCM TOKEN ERROR] {e}")
        return Response({'error': 'An unexpected error occurred.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
#============================PUSH NOTIF EXPIRY NOTIF END===============================


#MEDICINES LIST NEW VIEW FOR BARCODE DUPLICATION PREVENTION============================
@api_view(['GET'])
def check_barcode_existence(request, barcode):
    """
    Checks if a medicine with the given barcode already exists.
    """
    exists = Medicine.objects.filter(barcode=barcode).exists()
    return Response({'exists': exists})















#----------9/23/25
#-----------
class DailyReportsView(APIView):
    def get(self, request, *args, **kwargs):
        date_str = request.query_params.get('date')
        
        if not date_str:
            return Response({"error": "Date parameter is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            selected_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return Response({"error": "Invalid date format. Use YYYY-MM-DD."}, status=status.HTTP_400_BAD_REQUEST)

        # ⚡️ THE FIX: Explicitly set the timezone to 'Asia/Manila'
        manila_tz = pytz.timezone('Asia/Manila')
        start_of_day = manila_tz.localize(datetime.combine(selected_date, time.min))
        end_of_day = manila_tz.localize(datetime.combine(selected_date, time.max))

        # Fetch logs within the localized time range
        employee_logs_queryset = EmployeeLog.objects.filter(timestamp__range=(start_of_day, end_of_day)).order_by('-timestamp')
        order_logs_queryset = OrderLog.objects.filter(timestamp__range=(start_of_day, end_of_day)).order_by('-timestamp')
        inventory_logs_queryset = InventoryLog.objects.filter(timestamp__range=(start_of_day, end_of_day)).order_by('-timestamp')

        daily_report_data = {
            'employee_logs': employee_logs_queryset,
            'order_logs': order_logs_queryset,
            'inventory_logs': inventory_logs_queryset,
        }

        serializer = DailyReportSerializer(daily_report_data)
        
        return Response(serializer.data, status=status.HTTP_200_OK)
#----------9/23/25