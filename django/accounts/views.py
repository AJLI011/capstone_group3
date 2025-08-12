import uuid
from django.core.mail import send_mail
from django.conf import settings
from django.shortcuts import render
from django.contrib.auth.hashers import check_password, make_password
from rest_framework import serializers
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from rest_framework.decorators import parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.views import APIView
from rest_framework import generics
from datetime import date, timedelta
from django.http import JsonResponse, HttpResponseNotFound
from django.db.models import F, Prefetch
from django.utils.timezone import now
from django.core.management import call_command
from django.db import transaction
from django.shortcuts import get_object_or_404
from decimal import Decimal
import logging
from django.db import transaction
from django.utils import timezone

from .models import (
    Customer, Staff, Supplier, Medicine, Inventory, TotalQuantity, Promo, InventoryLog, EmployeeLog, InStoreOrder, InStoreOrderItem, OrderLog, OnlineOrder, OnlineOrderItem
)
from .serializers import (
    CustomerSerializer, StaffSerializer, SupplierSerializer, PromoSerializer,
    InventoryDashboardSerializer, MedicineSerializer, 
    InventoryCreateSerializer, InventorySerializer, InventoryListSerializer, 
    InventoryBatchDetailSerializer, TotalQuantitySerializer, InventoryLogSerializer,
    InStoreOrderSerializer, MedicineInventorySerializer, PromoMedicineSerializer, CustomerMedicineSerializer,
    EmployeeLogSerializer, CashierInStoreOrderSerializer, InStoreOrderItemSerializer, OrderLogSerializer, CustomerPromoMedicineDetailSerializer,
    CustomerMedicineDetailSerializer, OnlineOrderItemReadSerializer, OnlineOrderListSerializer, OnlineOrderItemCreateSerializer, OnlineOrderCreateSerializer,
    OnlineOrderLogDetailsSerializer
)




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
            staff_id = request.data.get('staff_id')  # You must send this from Flutter
            if staff_id:
                try:
                    staff_user = Staff.objects.get(id=staff_id)
                    InventoryLog.objects.create(
                        user=staff_user,
                        medicine=medicine,
                        action_type='Add',
                        description=f"Added new medicine: {medicine.name}"
                    )
                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging action.")

            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


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
            'supplier_name': medicine.supplier.name if medicine.supplier else "None",
        }

        serializer = MedicineSerializer(medicine, data=request.data, partial=True)
        if serializer.is_valid():
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
                        'supplier_name': updated_medicine.supplier.name if updated_medicine.supplier else "None",
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
                            description=description
                        )

                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging action.")

            return Response(serializer.data, status=status.HTTP_200_OK)

    elif request.method == 'DELETE':
        staff_id = request.GET.get('staff_id')
        medicine_name = medicine.name
        medicine.delete()

        if staff_id:
            try:
                staff_user = Staff.objects.get(id=staff_id)
                InventoryLog.objects.create(
                    user=staff_user,
                    medicine=None,
                    action_type='Delete',
                    description=f"Deleted medicine: {medicine_name}"
                )
            except Staff.DoesNotExist:
                print(f"Staff ID {staff_id} not found while logging delete.")

        return Response(status=status.HTTP_204_NO_CONTENT)

    
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
                        description=f"Restocked {qty_to_add} units (Batch: {batch})"
                    )
                except Staff.DoesNotExist:
                    print(f"Staff ID {staff_id} not found while logging restock action.")

            return Response(serializer.data, status=status.HTTP_201_CREATED)

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)



@api_view(['GET'])
def get_inventory_list(request):
    clean_expired_promos()
    queryset = TotalQuantity.objects.select_related('medicine').all()
    serializer = InventoryListSerializer(queryset, many=True, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
def get_medicine_by_barcode(request, barcode):
    try:
        medicine = Medicine.objects.get(barcode=barcode)
    except Medicine.DoesNotExist:
        return Response({'error': 'Medicine not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = MedicineSerializer(medicine)
    return Response(serializer.data)

# FOR INVENTORY 
# main inventory screen - with total qty


# 2. batch level details for a selected medicine
@api_view(['GET'])
def get_batch_details(request, medicine_id):
    batches = Inventory.objects.filter(medicine__id=medicine_id)
    if not batches.exists():
        return Response({'message': 'No batches found.'}, status=status.HTTP_404_NOT_FOUND)

    serializer = InventoryBatchDetailSerializer(batches, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

# for total quantity
@api_view(['GET'])
def total_quantities(request):
    inventory_items = Inventory.objects.select_related('medicine_id').all()

    results = []

    for item in inventory_items:
        medicine = item.medicine_id  # thanks to ForeignKey
        results.append({
            "medicine_id": medicine.id,
            "name": medicine.name,
            "generic_name": medicine.generic_name,
            "image": medicine.image.url if medicine.image else "",
            "category": medicine.category,
            "total_quantity": item.total_quantity,
        })

    return Response(results)

# =================== Expiration Dashboard -------------------- # 
# ✅ Good Stocks:
# Medicines that either:
# - Expire more than 15 days from today
class GoodStockView(generics.ListAPIView):
    serializer_class = InventoryDashboardSerializer

    def get_queryset(self):
        today = date.today()
        threshold_date = today + timedelta(days=15)
        return Inventory.objects.filter(exp_date__gt=threshold_date)

# ⚠️ Expiring Soon:
# Medicines that will expire within the next 15 days (but not yet expired),
# and were not received today
class ExpiringSoonView(generics.ListAPIView):
    serializer_class = InventoryDashboardSerializer

    def get_queryset(self):
        today = date.today()
        return Inventory.objects.filter(
            exp_date__gt=today,
            exp_date__lte=today + timedelta(days=15)
        )

# ❌ Expired:
# Medicines that are already expired (today or earlier)
class ExpiredView(generics.ListAPIView):
    serializer_class = InventoryDashboardSerializer

    def get_queryset(self):
        today = date.today()
        return Inventory.objects.filter(exp_date__lte=today)

#Return Medicine
@api_view(['DELETE'])
def delete_expired_batch(request, pk):
    try:
        inventory_item = Inventory.objects.get(pk=pk)

        # Capture info before deletion
        medicine = inventory_item.medicine
        quantity = inventory_item.quantity
        batch = inventory_item.batch_num

        inventory_item.delete()

        # 🔐 Get staff from query param (Flutter: ?staff_id=123)
        staff_id = request.query_params.get('staff_id')
        if staff_id:
            try:
                staff_user = Staff.objects.get(id=staff_id)
                InventoryLog.objects.create(
                    user=staff_user,
                    medicine=medicine,
                    action_type='Return',
                    description=f"Returned {quantity} units of {medicine.name} (Batch: {batch}) due to expiration"
                )
            except Staff.DoesNotExist:
                print(f"Staff ID {staff_id} not found while logging action.")

        return Response({"message": "Deleted successfully"}, status=status.HTTP_204_NO_CONTENT)

    except Inventory.DoesNotExist:
        return Response({"error": "Inventory item not found"}, status=status.HTTP_404_NOT_FOUND)


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
                description=f"Set promo for batch {inventory_item.batch_num} from {start_date} to {end_date}"
            )
        except Staff.DoesNotExist:
            print(f"Staff with ID {staff_id} not found for promo logging.")

    return Response({'message': 'Promo set successfully'}, status=status.HTTP_200_OK)


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
                    description=f"Removed promo for batch {inventory.batch_num}"
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

# For Inventory Logs
from .serializers import InventoryLogSerializer

@api_view(['GET'])
def inventory_logs(request):
    logs = InventoryLog.objects.select_related('user', 'medicine').all()
    serializer = InventoryLogSerializer(logs, many=True)
    return Response(serializer.data)

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


#----------Customer Side Mainview----------------

class PromoMedicineView(APIView):
    def get(self, request):
        today = now().date()

        # Get all promo-active inventory batches
        promo_batches = Inventory.objects.filter(
            promo__start_date__lte=today,
            promo__end_date__gte=today
        ).select_related('medicine')

        data = []
        seen_medicine_ids = set()

        for batch in promo_batches:
            medicine = batch.medicine
            if medicine.id not in seen_medicine_ids:
                seen_medicine_ids.add(medicine.id)
                data.append({
                    'id': medicine.id, 
                    'name': medicine.name,
                    'generic_name': medicine.generic_name,
                    'image': request.build_absolute_uri(medicine.image.url) if medicine.image else '',
                    'price': float(medicine.price)
                })

        return Response(data)
        
def trigger_update_total_quantity(request):
    call_command('update_total_quantities')
    return JsonResponse({'status': 'success'})

class PromoMedicineDetailView(APIView):
    def get(self, request, pk):
        medicine = get_object_or_404(Medicine, pk=pk)
        serializer = CustomerPromoMedicineDetailSerializer(medicine, context={'request': request})
        return Response(serializer.data)


#For Normal Medicine
@api_view(['GET'])
def get_customer_medicines(request):
    inventory_items = TotalQuantity.objects.select_related('medicine').all()
    medicines = [item.medicine for item in inventory_items]
    serializer = CustomerMedicineSerializer(medicines, many=True, context={'request': request})
    return Response(serializer.data)

@api_view(['GET'])
def get_customer_medicine_detail(request, pk):
    medicine = get_object_or_404(Medicine, pk=pk)
    serializer = CustomerMedicineDetailSerializer(medicine, context={'request': request})
    return Response(serializer.data)
def trigger_update_total_quantity(request):
    call_command('update_total_quantities')
    return JsonResponse({'status': 'success'})

@api_view(['GET'])
def get_customer_medicines(request):
    inventory_items = TotalQuantity.objects.select_related('medicine').all()
    medicines = [item.medicine for item in inventory_items]
    serializer = CustomerMedicineSerializer(medicines, many=True, context={'request': request})
    return Response(serializer.data)


#----------Employee Logs Views-------
@api_view(['GET', 'POST'])
def employee_logs_view(request):
    if request.method == 'GET':
        logs = EmployeeLog.objects.all()
        serializer = EmployeeLogSerializer(logs, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        serializer = EmployeeLogSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

#------------ PENDING ORDER----------
#----------ORDER LOGS PT 1 - FOR CASHER (INSTORE)---------
#modified some parts of the pending order view for the order logs
class InStoreOrderProcessingView(APIView):
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
        Approve or Reject an order.
        """
        try:
            order = InStoreOrder.objects.get(id=order_id, status='pending')
        except InStoreOrder.DoesNotExist:
            return Response({'error': 'Pending order not found'}, status=status.HTTP_404_NOT_FOUND)

        new_status = request.data.get('status')
        staff_id = request.data.get('cashier_id') # We will rename this to staff_id to be more consistent
        
        if not new_status or new_status not in ['approved', 'rejected']:
            return Response({'error': 'Invalid status provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            staff_user = Staff.objects.get(id=staff_id)
        except Staff.DoesNotExist:
            return Response({'error': f'Staff member with ID {staff_id} not found'}, status=status.HTTP_404_NOT_FOUND)
        
        if new_status == 'approved':
            try:
                with transaction.atomic():
                    order_items = InStoreOrderItem.objects.filter(order=order)
                    for item in order_items:
                        total_to_deduct = item.quantity_sold + item.free_quantity_given
                        batch = item.inventory_id
                        
                        batch.quantity = F('quantity') - total_to_deduct
                        batch.save(update_fields=['quantity'])
                        
                        # Existing InventoryLog is here
                        InventoryLog.objects.create(
                            user=staff_user,
                            medicine=batch.medicine,
                            action_type='Sold',
                            description=f"Approved sale of {total_to_deduct} units "
                                        f"of {batch.medicine.name} (Batch: {batch.batch_num}) "
                                        f"from In-Store Order #{order.id}."
                        )

                    # NEW: Create a log entry for the approved order
                    OrderLog.objects.create(
                        staff_user=staff_user,
                        in_store_order=order,
                        action_type='approve',
                        description='Sale transaction approved'
                    )

                    order.status = 'approved'
                    order.save(update_fields=['status'])
                    
                    return Response({'message': 'Order approved and inventory updated'}, status=status.HTTP_200_OK)
            
            except Exception as e:
                return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        elif new_status == 'rejected':
            # NEW: Create a log entry for the rejected order
            OrderLog.objects.create(
                staff_user=staff_user,
                in_store_order=order,
                action_type='reject',
                description='Sale transaction rejected'
            )
            order.status = 'rejected'
            order.save(update_fields=['status'])
            return Response({'message': 'Order rejected'}, status=status.HTTP_200_OK)

#----------ORDER LOGS PT 2 - FOR STAFF (INSTORE)---------
@api_view(['POST'])
def process_instore_order(request):
    serializer = InStoreOrderSerializer(data=request.data)
    if serializer.is_valid():
        try:
            # First, save the order as you did before
            order = serializer.save()

            # Now, get the staff user ID from the request data
            staff_id = request.data.get('staff')  # The serializer uses 'staff'
            staff_user = Staff.objects.get(id=staff_id)
            
            # Create a log entry for the 'initiate sale' action
            OrderLog.objects.create(
                staff_user=staff_user,
                in_store_order=order,
                action_type='initiate_sale',
                description='Sale submitted for approval'
            )

            return Response({
                "message": "Order processed successfully",
                "order_id": order.id,
                "total_before_discount": float(order.total_amount_before_discount),
                "total_after_discount": float(order.total_amount_after_discount),
            }, status=status.HTTP_201_CREATED)
        except Staff.DoesNotExist:
            return Response({"error": "Staff member not found."}, status=status.HTTP_404_NOT_FOUND)
        except serializers.ValidationError as e:
            return Response({"error": e.detail}, status=status.HTTP_400_BAD_REQUEST)
        except Exception as e:
            # Log the error for backend debugging
            print(f"[PROCESS ORDER ERROR] {e}")
            return Response({"error": f"Failed to process order: {str(e)}"}, status=status.HTTP_400_BAD_REQUEST)

    return Response({"error": serializer.errors}, status=status.HTTP_400_BAD_REQUEST)

#------------------ ORDER LOGS VIEW -------------------
@api_view(['GET'])
def order_logs_list_view(request):
    """
    API endpoint to retrieve all order logs.
    This version uses select_related and prefetch_related for optimal performance
    with both in-store and online orders.
    """
    logs = OrderLog.objects.all().select_related(
        'staff_user', 
        'in_store_order__staff',
        'online_order__customer'
    ).prefetch_related(
        'in_store_order__items__inventory_id__medicine',
        'online_order__items__inventory_id__medicine'
    ).order_by('-timestamp')
    
    serializer = OrderLogSerializer(logs, many=True)
    return Response(serializer.data, status=status.HTTP_200_OK)

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

@api_view(['GET'])
def get_online_customer_orders(request, customer_id):
    """
    API endpoint to retrieve all online orders for a specific customer.
    """
    try:
        orders = OnlineOrder.objects.filter(customer__id=customer_id).order_by('-date_created')
        serializer = OnlineOrderListSerializer(orders, many=True, context={'request': request})
        return Response(serializer.data)
    except OnlineOrder.DoesNotExist:
        return Response({"detail": "No online orders found for this customer."}, status=status.HTTP_404_NOT_FOUND)

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

# Cashier and Staff Confirm Online Order
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
        serializer = OnlineOrderListSerializer(orders, many=True)
        return Response(serializer.data)
    except Exception as e:
        print(f"[GET PENDING ONLINE ORDERS ERROR] {e}")
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['PUT'])
def confirm_online_order(request, orderId):
    """
    API view for staff to confirm a pending online order.
    Changes the status from 'pending' to 'ready for pickup'.
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

                # NEW: Create a log entry for the confirmed online order
                OrderLog.objects.create(
                    staff_user=staff_user,
                    online_order=order,
                    action_type='online_confirmed',
                    description=f'Online order confirmed by staff member {staff_user.name} ({staff_user.role}).'
                )

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

@api_view(['PUT'])
def finalize_online_order(request, orderId):
    """
    API view to finalize an online order after pickup.
    This marks the order status as 'completed' and deducts the inventory.
    """
    try:
        staff_id = request.data.get('staff_id')
        if not staff_id:
            return Response({'error': 'Staff ID is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        staff_user = Staff.objects.get(id=staff_id)

        with transaction.atomic():
            order = OnlineOrder.objects.get(id=orderId, status='ready for pickup')
            
            # Create a dictionary to hold the total quantity to deduct for each medicine
            medicine_deductions = {}

            for item in order.items.all():
                medicine_id = item.inventory_id.medicine.id
                
                # Calculate total quantity to deduct by summing sold and free quantities
                quantity_to_deduct = item.quantity_sold + item.free_quantity_given
                
                if medicine_id in medicine_deductions:
                    medicine_deductions[medicine_id]['quantity'] += quantity_to_deduct
                else:
                    medicine_deductions[medicine_id] = {
                        'quantity': quantity_to_deduct,
                        'inventory_batch': item.inventory_id,
                        'medicine_name': item.inventory_id.medicine.name
                    }

            # Now iterate through the deductions and update the inventory
            for medicine_id, data in medicine_deductions.items():
                inventory_batch = data['inventory_batch']
                total_quantity_to_deduct = data['quantity']
                medicine_name = data['medicine_name']

                # Check for sufficient stock before performing the deduction
                if inventory_batch.quantity < total_quantity_to_deduct:
                    raise ValueError(
                        f"Insufficient stock for {medicine_name}. Available: {inventory_batch.quantity}, Required: {total_quantity_to_deduct}"
                    )
                
                inventory_batch.quantity -= total_quantity_to_deduct
                inventory_batch.save()
            
            # Update the order status to 'completed' and record the fulfillment date
            order.status = 'completed'
            order.date_fulfilled = timezone.now()
            order.save()

            # NEW: Create a log entry for the picked up online order
            OrderLog.objects.create(
                staff_user=staff_user,
                online_order=order,
                action_type='online_picked_up',
                description=f'Online order marked as picked up by cashier {staff_user.name}.'
            )

            return Response(
                {"detail": "Online order finalized successfully, inventory deducted."},
                status=status.HTTP_200_OK
            )
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
        logger.error(f"[FINALIZE ORDER ERROR] {e}")
        return Response(
            {"detail": f"An unexpected error occurred: {str(e)}"},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )