import uuid
from django.core.mail import send_mail
from django.conf import settings
from django.shortcuts import render
from django.contrib.auth.hashers import check_password, make_password
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from .serializers import CustomerSerializer, StaffSerializer, SupplierSerializer
from .models import Customer, Staff, Supplier

from .models import Medicine
from .serializers import MedicineSerializer

from rest_framework.decorators import parser_classes
from rest_framework.parsers import MultiPartParser, FormParser

from rest_framework.views import APIView
from .models import Inventory # Corrected import from ExpirationList to Inventory
from .serializers import InventoryCreateSerializer, InventorySerializer # Corrected serializer imports

from .serializers import InventoryDashboardSerializer
from rest_framework import generics
from datetime import date, timedelta

from django.http import JsonResponse, HttpResponseNotFound

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
        if check_password(password, customer.password):
            return Response({'message': 'Login successful', 'user_type': 'customer', 'view': 'customer_view'})
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
            serializer.save()
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
        serializer = MedicineSerializer(medicine, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        
        # This will print serializer errors to your Django server console
        print(serializer.errors)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == 'DELETE':
        medicine.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
    
# =================== INVENTORY MANAGEMENT -------------------- # Renamed comment for clarity
class InventoryCreateView(APIView): # Renamed class from ExpirationListCreateView
    def post(self, request, *args, **kwargs):
        serializer = InventoryCreateSerializer(data=request.data) # Changed serializer
        if serializer.is_valid():
            inventory_item = serializer.save() # Renamed variable
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def get_inventory_list(request): # Renamed function from get_expiration_list
    inventory_items = Inventory.objects.select_related('medicine').all() # Changed model and variable
    serializer = InventorySerializer(inventory_items, many=True) # Changed serializer and variable
    return Response(serializer.data)

@api_view(['GET'])
def get_medicine_by_barcode(request, barcode):
    try:
        medicine = Medicine.objects.get(barcode=barcode)
    except Medicine.DoesNotExist:
        return Response({'error': 'Medicine not found'}, status=status.HTTP_404_NOT_FOUND)

    serializer = MedicineSerializer(medicine)
    return Response(serializer.data)


# =================== Expiration Dashboard -------------------- # 
# ✅ Good Stocks:
# Medicines that either:
# - Expire more than 15 days from today, OR
# - Were received today (even if expiring soon)
# =================== Expiration Dashboard -------------------- # 
# ✅ Good Stocks: Expiry date is more than 30 days from today
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

@api_view(['DELETE'])
def delete_expired_batch(request, pk):
    try:
        inventory_item = Inventory.objects.get(pk=pk)
        inventory_item.delete()
        return Response({"message": "Deleted successfully"}, status=status.HTTP_204_NO_CONTENT)
    except Inventory.DoesNotExist:
        return Response({"error": "Inventory item not found"}, status=status.HTTP_404_NOT_FOUND)