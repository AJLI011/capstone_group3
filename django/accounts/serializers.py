from rest_framework import serializers
from .models import Customer, Staff, Supplier, Medicine, Inventory, TotalQuantity, Promo, InventoryLog, InStoreOrder, InStoreOrderItem, EmployeeLog, OrderLog, OnlineOrder, OnlineOrderItem, OrderLog
from .models import Prescription, PrescriptionImage
from django.contrib.auth.hashers import make_password
from decimal import Decimal
from datetime import date
from django.db import transaction
from django.db.models import F, Sum
from django.utils.timezone import now



class CustomerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Customer
        fields = ['id', 'email', 'password', 'name', 'contact_num']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        return super().create(validated_data)

    def update(self, instance, validated_data):
        if 'password' in validated_data and validated_data['password']:
            validated_data['password'] = make_password(validated_data['password'])
        else:
            validated_data.pop('password', None)
        return super().update(instance, validated_data)


class StaffSerializer(serializers.ModelSerializer):
    class Meta:
        model = Staff
        fields = ['id', 'email', 'password', 'name', 'role', 'contact_num']
        extra_kwargs = {'password': {'write_only': True}}

    def create(self, validated_data):
        validated_data['password'] = make_password(validated_data['password'])
        return super().create(validated_data)

    def update(self, instance, validated_data):
        if 'password' in validated_data and validated_data['password']:
            validated_data['password'] = make_password(validated_data['password'])
        else:
            validated_data.pop('password', None)
        return super().update(instance, validated_data)


class SupplierSerializer(serializers.ModelSerializer):
    class Meta:
        model = Supplier
        fields = '__all__'


class MedicineSerializer(serializers.ModelSerializer):
    supplier_name = serializers.StringRelatedField(source='supplier', read_only=True)

    class Meta:
        model = Medicine
        fields = [
            'id',
            'name',
            'generic_name',
            'barcode',
            'category',
            'dosage_form',
            'supplier',
            'supplier_name',
            'restock_quantity',
            'price',
            'requires_prescription',
            'image',
            'created_at',
            'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def update(self, instance, validated_data):
        if 'barcode' in validated_data and validated_data['barcode'] == instance.barcode:
            validated_data.pop('barcode')

        return super().update(instance, validated_data)


# New Serializer for Inventory
class InventorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Inventory
        fields = ['id', 'medicine', 'batch_num', 'exp_date', 'date_received', 'quantity', 'is_promo', 'promo_start_date']
        read_only_fields = ['date_received', 'is_promo']


class InventoryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Inventory
        fields = ['medicine', 'batch_num', 'exp_date', 'quantity']


# Serializer for main inventory screen (with total quantity)
class InventoryListSerializer(serializers.ModelSerializer):
    medicine_id = serializers.IntegerField(source='medicine.id')
    name = serializers.CharField(source='medicine.name')
    generic_name = serializers.CharField(source='medicine.generic_name')
    category = serializers.CharField(source='medicine.category')
    price = serializers.DecimalField(source='medicine.price', max_digits=8, decimal_places=2)
    image = serializers.SerializerMethodField()

    class Meta:
        model = TotalQuantity
        fields = ['medicine_id', 'name', 'generic_name', 'category', 'price', 'image', 'total_quantity']

    def get_image(self, obj):
        request = self.context.get('request')
        image = obj.medicine.image
        if image and hasattr(image, 'url'):
            return request.build_absolute_uri(image.url)
        return None


# Serializer for batch-level details (for selected medicine)
class InventoryBatchDetailSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='medicine.name', read_only=True)
    generic_name = serializers.CharField(source='medicine.generic_name.name', read_only=True, default="N/A")
    price = serializers.DecimalField(source='medicine.price', max_digits=8, decimal_places=2, read_only=True)
    is_promo = serializers.SerializerMethodField()
    promo_start_date = serializers.SerializerMethodField()
    promo_end_date = serializers.SerializerMethodField()

    class Meta:
        model = Inventory
        fields = [
            'id',
            'batch_num',
            'exp_date',
            'quantity',
            'date_received',
            'name',
            'generic_name',
            'price',
            'is_promo',
            'promo_start_date',
            'promo_end_date',
        ]

    def get_is_promo(self, obj):
        promo = Promo.objects.filter(inventory_id=obj.id).first()
        today = date.today()
        return (
            promo is not None and
            promo.start_date is not None and
            promo.start_date <= today and
            (promo.end_date is None or promo.end_date >= today)
        )

    def get_promo_start_date(self, obj):
        promo = Promo.objects.filter(inventory_id=obj.id).first()
        return promo.start_date if promo else None

    def get_promo_end_date(self, obj):
        promo = Promo.objects.filter(inventory_id=obj.id).first()
        return promo.end_date if promo else None


# For Expiration Dashboard
class InventoryDashboardSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='medicine.name')
    generic_name = serializers.CharField(source='medicine.generic_name')
    dosage_form = serializers.CharField(source='medicine.dosage_form')
    supplier_name = serializers.CharField(source='medicine.supplier.name', default=None)
    barcode = serializers.CharField(source='medicine.barcode')

    class Meta:
        model = Inventory
        fields = [
            'id',
            'batch_num',
            'exp_date',
            'quantity',
            'medicine_name',
            'generic_name',
            'dosage_form',
            'supplier_name',
            'barcode',
            'is_promo',
        ]


# Total Quantity
class TotalQuantitySerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='medicine.name', read_only=True)
    generic_name = serializers.CharField(source='medicine.generic_name', read_only=True)
    image = serializers.ImageField(source='medicine.image', read_only=True)
    category = serializers.CharField(source='medicine.category', read_only=True)

    class Meta:
        model = TotalQuantity
        fields = ['medicine', 'medicine_name', 'generic_name', 'category', 'image', 'total_quantity']


# Serializer for Promo
class PromoSerializer(serializers.ModelSerializer):
    class Meta:
        model = Promo
        fields = '__all__'


# For Inventory Logs
class InventoryLogSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    medicine_name = serializers.CharField(source='medicine.name')

    class Meta:
        model = InventoryLog
        fields = ['id', 'user_name', 'medicine_name', 'action_type', 'timestamp', 'description']

    def get_user_name(self, obj):
        if obj.user:
            return f"{obj.user.name}, {obj.user.role}"
        return "Unknown"


# =====================================
# SALES
# New: Serializer for returning multiple batches for a medicine
class MedicineInventorySerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='medicine.name')
    price = serializers.DecimalField(source='medicine.price', max_digits=8, decimal_places=2)
    barcode = serializers.CharField(source='medicine.barcode')
    image = serializers.SerializerMethodField()

    class Meta:
        model = Inventory
        fields = [
            'id',  # inventory_tbl id
            'medicine_id',  # medicine_list id
            'name',
            'barcode',
            'batch_num',
            'quantity',
            'exp_date',  # Added expiration date
            'price',
            'is_promo',
            'image',
        ]

    def get_image(self, obj):
        request = self.context.get('request')
        image = obj.medicine.image
        if image and hasattr(image, 'url'):
            return request.build_absolute_uri(image.url)
        return None


# =====================================
# Serializer for a single order item with FEFO logic
class FEFOOrderItemSerializer(serializers.Serializer):
    medicine_id = serializers.PrimaryKeyRelatedField(queryset=Medicine.objects.all())
    quantity_sold = serializers.IntegerField(min_value=1)
    free_quantity_given = serializers.IntegerField(default=0, min_value=0)
    is_promo = serializers.BooleanField(default=False)


# Customer Promo Medicines View
class PromoMedicineSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source='medicine.id', read_only=True)
    name = serializers.CharField(source='medicine.name', read_only=True)
    generic_name = serializers.CharField(source='medicine.generic_name', read_only=True)
    price = serializers.DecimalField(source='medicine.price', max_digits=8, decimal_places=2, read_only=True)
    image = serializers.SerializerMethodField()

    class Meta:
        model = Inventory
        fields = ['id, name', 'generic_name', 'image', 'price']

    def get_image(self, obj):
        request = self.context.get('request', None)
        if obj.medicine.image and hasattr(obj.medicine.image, 'url'):
            if request:
                return request.build_absolute_uri(obj.medicine.image.url)
            return obj.medicine.image.url
        return None
    
class CustomerPromoMedicineDetailSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    quantity = serializers.SerializerMethodField()
    stock_status = serializers.SerializerMethodField()
    start_date = serializers.SerializerMethodField()
    end_date = serializers.SerializerMethodField()

    class Meta:
        model = Medicine
        fields = [
            'id',
            'name',
            'generic_name',
            'dosage_form',
            'price',
            'image',
            'requires_prescription',
            'quantity',
            'stock_status',
            'start_date',
            'end_date',
        ]

    def get_image(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            return request.build_absolute_uri(obj.image.url)
        return ""

    def get_quantity(self, obj):
        from .models import Inventory
        # sum only promo inventory batches of this medicine
        total = Inventory.objects.filter(
            medicine=obj,
            is_promo=True
        ).aggregate(total=Sum('quantity'))['total']
        return total or 0

    def get_stock_status(self, obj):
        return "In Stock" if self.get_quantity(obj) > 0 else "Out of Stock"

    def get_start_date(self, obj):
        from .models import Promo
        # find earliest start_date of active promos for this medicine's promo inventories
        promos = Promo.objects.filter(
            inventory_id__medicine=obj,
            inventory_id__is_promo=True,
            end_date__gte=now().date()  # promo is still active
        ).order_by('start_date')
        if promos.exists():
            return promos.first().start_date
        return None

    def get_end_date(self, obj):
        from .models import Promo
        promos = Promo.objects.filter(
            inventory_id__medicine=obj,
            inventory_id__is_promo=True,
            end_date__gte=now().date()
        ).order_by('end_date')
        if promos.exists():
            return promos.last().end_date
        return None    


#Normal medicine 
class CustomerMedicineSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = Medicine
        fields = ['id', 'name', 'generic_name', 'price', 'image']

    def get_image(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            return request.build_absolute_uri(obj.image.url)
        return ""
    
class CustomerMedicineDetailSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    quantity = serializers.SerializerMethodField()
    stock_status = serializers.SerializerMethodField()

    class Meta:
        model = Medicine
        fields = [
            'id',
            'name',
            'generic_name',
            'dosage_form',
            'price',
            'image',
            'requires_prescription',
            'quantity',
            'stock_status'
        ]

    def get_image(self, obj):
        request = self.context.get('request')
        if obj.image and hasattr(obj.image, 'url'):
            return request.build_absolute_uri(obj.image.url)
        return ""

    def get_quantity(self, obj):
        # local import of Inventory avoids circular import problems
        from .models import Inventory
        total = Inventory.objects.filter(
            medicine=obj,
            is_promo=False
        ).aggregate(total=Sum('quantity'))['total']
        return total or 0

    def get_stock_status(self, obj):
        return "In Stock" if self.get_quantity(obj) > 0 else "Out of Stock"


# Employee Logs serializer
class EmployeeLogSerializer(serializers.ModelSerializer):
    # Accept staff ID on write
    staff = serializers.PrimaryKeyRelatedField(queryset=Staff.objects.all(), write_only=True)

    # Expose readable fields for the response
    staff_name = serializers.CharField(source='staff.name', read_only=True)
    staff_role = serializers.CharField(source='staff.role', read_only=True)

    class Meta:
        model = EmployeeLog
        fields = ['id', 'staff', 'staff_name', 'staff_role', 'action', 'timestamp']
        read_only_fields = ['id', 'staff_name', 'staff_role', 'timestamp']


# =====================================
# IN-STORE ORDERS SERIALIZERS

class InStoreOrderItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='inventory_id.medicine.name', read_only=True)
    barcode = serializers.CharField(source='inventory_id.medicine.barcode', read_only=True)
    batch_num = serializers.CharField(source='inventory_id.batch_num', read_only=True)
    exp_date = serializers.DateField(source='inventory_id.exp_date', read_only=True)

    class Meta:
        model = InStoreOrderItem
        fields = ['id', 'medicine_name', 'barcode', 'batch_num', 'exp_date', 'quantity_sold', 'free_quantity_given', 'price_at_sale']


class CashierInStoreOrderSerializer(serializers.ModelSerializer):
    items = InStoreOrderItemSerializer(many=True, read_only=True)
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = InStoreOrder
        fields = ['id', 'staff_name', 'is_pwd', 'total_amount_before_discount', 'total_amount_after_discount', 'items']

class InStoreOrderSerializer(serializers.ModelSerializer):
    # This now expects a list of items with medicine_id and total quantity
    items = FEFOOrderItemSerializer(many=True)
    staff = serializers.PrimaryKeyRelatedField(queryset=Staff.objects.all())

    class Meta:
        model = InStoreOrder
        fields = ['staff', 'is_pwd', 'items', 'status']
        read_only_fields = ['status']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        staff = validated_data['staff']
        is_pwd = validated_data.get('is_pwd', False)

        total_before = Decimal('0.00')

        try:
            with transaction.atomic():
                # Create the order with a 'pending' status (default)
                order = InStoreOrder.objects.create(staff=staff, is_pwd=is_pwd)

                # Get all available inventory batches for the requested medicines
                all_batches = Inventory.objects.filter(
                    medicine__in=[item['medicine_id'] for item in items_data],
                    quantity__gt=0,
                    exp_date__gt=date.today()
                ).order_by('exp_date')

                # Create a map for quick batch lookup
                batch_map = {batch.id: batch for batch in all_batches}
                
                order_items_to_create = []

                for item_data in items_data:
                    medicine = item_data['medicine_id']
                    quantity_to_sell = item_data['quantity_sold']
                    free_quantity_to_give = item_data['free_quantity_given']
                    total_to_deduct = quantity_to_sell + free_quantity_to_give

                    # Get batches for this specific medicine
                    available_batches = [
                        batch for batch in all_batches if batch.medicine_id == medicine.id
                    ]

                    # Perform a dry run to check if enough stock exists
                    current_deducted = 0
                    for batch in available_batches:
                        can_deduct_from_batch = min(
                            batch.quantity, 
                            total_to_deduct - current_deducted
                        )
                        current_deducted += can_deduct_from_batch

                    if current_deducted < total_to_deduct:
                        raise serializers.ValidationError(
                            f"Not enough stock for {medicine.name}. "
                            f"Requested: {total_to_deduct}, "
                            f"Available: {current_deducted}"
                        )
                    
                    # Create the order items without touching inventory
                    current_allocated_sold = 0
                    current_allocated_free = 0

                    for batch in available_batches:
                        if current_allocated_sold >= quantity_to_sell and current_allocated_free >= free_quantity_to_give:
                            break
                        
                        available_in_batch = batch.quantity
                        
                        # Allocate sold quantity first
                        sold_to_allocate = min(
                            quantity_to_sell - current_allocated_sold,
                            available_in_batch
                        )
                        available_in_batch -= sold_to_allocate
                        
                        # Allocate free quantity next
                        free_to_allocate = min(
                            free_quantity_to_give - current_allocated_free,
                            available_in_batch
                        )
                        
                        order_items_to_create.append(
                            InStoreOrderItem(
                                order=order,
                                inventory_id=batch,
                                quantity_sold=sold_to_allocate,
                                free_quantity_given=free_to_allocate,
                                price_at_sale=medicine.price
                            )
                        )
                        
                        current_allocated_sold += sold_to_allocate
                        current_allocated_free += free_to_allocate

                    # Add to the total before discount
                    total_before += quantity_to_sell * medicine.price

                # Create all order items in a single bulk operation
                InStoreOrderItem.objects.bulk_create(order_items_to_create)

                # Calculate and update totals for the order
                discount = total_before * Decimal('0.20') if is_pwd else Decimal('0.00')
                order.total_amount_before_discount = total_before
                order.total_amount_after_discount = total_before - discount
                order.save()

                return order
        except Exception as e:
            raise serializers.ValidationError(
                f"Failed to process order: {str(e)}"
            )

# ORDER LOGS SERIALIZERS

class InStoreOrderItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='inventory_id.medicine.name', read_only=True)
    
    class Meta:
        model = InStoreOrderItem
        fields = ['id', 'medicine_name', 'quantity_sold', 'price_at_sale']

class InStoreOrderDetailsSerializer(serializers.ModelSerializer):
    items = InStoreOrderItemSerializer(many=True, read_only=True)
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = InStoreOrder
        fields = ['id', 'staff_name', 'items']

# Modified OrderLogSerializer to handle both in-store and online orders
class OrderLogSerializer(serializers.ModelSerializer):
    staff_name = serializers.CharField(source='staff_user.name', read_only=True)
    staff_role = serializers.CharField(source='staff_user.role', read_only=True)

    order_details = serializers.SerializerMethodField()

    class Meta:
        model = OrderLog
        fields = ['id', 'staff_name', 'staff_role', 'order_details', 'action_type', 'description', 'timestamp']

    def get_order_details(self, obj):
        if obj.in_store_order:
            # If it's an in-store order, use the existing InStoreOrderDetailsSerializer
            return InStoreOrderDetailsSerializer(obj.in_store_order).data
        elif obj.online_order:
            # If it's an online order, use the new OnlineOrderLogDetailsSerializer
            return OnlineOrderLogDetailsSerializer(obj.online_order).data
        return None

# --- Online Orders Serializers ---
class OnlineOrderItemReadSerializer(serializers.ModelSerializer):
    # This is the correct way to get the medicine name
    medicine_name = serializers.CharField(source='inventory_id.medicine.name') 
    price_at_sale = serializers.DecimalField(max_digits=10, decimal_places=2)

    # REMOVE the get_medicine_name method
    # It is not needed and causes redundancy.

    class Meta:
        model = OnlineOrderItem
        fields = [
            'id', 
            'medicine_name',   # <-- Don't forget the comma here
            'quantity_sold', 
            'free_quantity_given', 
            'price_at_sale'
        ]

# New serializer for Online order details within a log
class OnlineOrderLogDetailsSerializer(serializers.ModelSerializer):
    items = OnlineOrderItemReadSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)

    class Meta:
        model = OnlineOrder
        fields = ['id', 'customer_name', 'customer_email', 'items']

# --- Online Orders Serializers ---
class OnlineOrderItemReadSerializer(serializers.ModelSerializer):
    medicine = MedicineSerializer(source='inventory_id.medicine')
    free_quantity_given = serializers.IntegerField()

    class Meta:
        model = OnlineOrderItem
        fields = ['id', 'medicine', 'quantity_sold', 'free_quantity_given', 'price_at_sale']


class OnlineOrderListSerializer(serializers.ModelSerializer):
    items = OnlineOrderItemReadSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    pickup_schedule = serializers.DateTimeField(read_only=True)

    class Meta:
        model = OnlineOrder
        fields = [
            'id', 'customer_name', 'customer_email', 'date_created',
            'status', 'total_amount_before_discount', 'total_amount_after_discount',
            'is_pwd', 'items', 'pickup_schedule'
        ]


class OnlineOrderItemCreateSerializer(serializers.ModelSerializer):
    medicine_id = serializers.PrimaryKeyRelatedField(
        queryset=Medicine.objects.all(), write_only=True
    )
    quantity_sold = serializers.IntegerField(min_value=1)
    free_quantity_given = serializers.IntegerField(default=0, min_value=0)
    is_promo = serializers.BooleanField()

    class Meta:
        model = OnlineOrderItem
        fields = ['medicine_id', 'quantity_sold', 'free_quantity_given', 'is_promo']

    def validate(self, data):
        """
        Custom validation to ensure that `is_promo` flag matches the actual promo status
        of the medicine in the inventory. We're not deducting from the inventory here.
        """
        medicine = data.get('medicine_id')
        is_promo_requested = data.get('is_promo')
        
        if not medicine:
            raise serializers.ValidationError("Medicine ID is required.")

        has_active_promo = Inventory.objects.filter(
            medicine=medicine,
            is_promo=True,
            quantity__gt=0,
            exp_date__gt=date.today()
        ).exists()

        if is_promo_requested and not has_active_promo:
            raise serializers.ValidationError({
                'is_promo': "This medicine is not currently on promotion. Please set 'is_promo' to False."
            })
        
        return data


class OnlineOrderCreateSerializer(serializers.ModelSerializer):
    items = OnlineOrderItemCreateSerializer(many=True, write_only=True)
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(), source='customer', write_only=True
    )
    pickup_schedule = serializers.DateTimeField(write_only=True)
    id = serializers.IntegerField(read_only=True)

    class Meta:
        model = OnlineOrder
        fields = ['id', 'customer_id', 'is_pwd', 'items', 'pickup_schedule']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        pickup_schedule = validated_data.pop('pickup_schedule')
        customer = validated_data['customer']
        is_pwd = validated_data.get('is_pwd', False)
        
        total_before = Decimal('0.00')
        order_items_to_create = []

        try:
            with transaction.atomic():
                for item_data in items_data:
                    medicine = item_data['medicine_id']
                    quantity_sold_initial = item_data['quantity_sold']
                    free_quantity_given_initial = item_data.get('free_quantity_given', 0)
                    is_promo = item_data['is_promo']
                    
                    # Prepare the order item without affecting inventory
                    try:
                        inventory_batch = Inventory.objects.filter(
                            medicine=medicine,
                            is_promo=is_promo,
                            quantity__gt=0,
                            exp_date__gt=date.today()
                        ).order_by('exp_date').first()
                        
                        if not inventory_batch:
                            raise serializers.ValidationError(
                                f"No available inventory batch found for {medicine.name}."
                            )

                        order_items_to_create.append(
                            OnlineOrderItem(
                                inventory_id=inventory_batch,
                                quantity_sold=quantity_sold_initial,
                                free_quantity_given=free_quantity_given_initial,
                                price_at_sale=medicine.price
                            )
                        )
                    except Exception as e:
                        raise serializers.ValidationError(
                            f"Error processing item {medicine.name}: {str(e)}"
                        )

                    total_before += quantity_sold_initial * medicine.price

                # Create the order once all checks pass
                order = OnlineOrder.objects.create(
                    customer=customer,
                    is_pwd=is_pwd,
                    pickup_schedule=pickup_schedule,
                    status='pending',
                    total_amount_before_discount=total_before,
                    total_amount_after_discount=total_before - (total_before * Decimal('0.20') if is_pwd else Decimal('0.00'))
                )

                # Assign the newly created order to each order item
                for item in order_items_to_create:
                    item.order = order

                # Bulk create order items
                OnlineOrderItem.objects.bulk_create(order_items_to_create)

                return order
        except Exception as e:
            raise serializers.ValidationError(f"Failed to process order: {str(e)}")

#-------- in store transactions serializers--------------------
# New serializer for Staff to get their name and role
class StaffDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = Staff
        fields = ['name', 'role']

# New nested serializer for InStoreOrderItem
class ManagerInStoreOrderItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='inventory_id.medicine.name', read_only=True)
    is_promo = serializers.BooleanField(source='inventory_id.is_promo', read_only=True)
    price_per_item = serializers.DecimalField(source='price_at_sale', max_digits=8, decimal_places=2, read_only=True)

    class Meta:
        model = InStoreOrderItem
        fields = [
            'medicine_name', 
            'quantity_sold', 
            'free_quantity_given', 
            'is_promo', 
            'price_per_item'
        ]

# Main serializer for the manager's sales log
class InStoreSalesTransactionSerializer(serializers.ModelSerializer):
    staff = serializers.CharField(source='staff.name', read_only=True)
    cashier = serializers.SerializerMethodField()
    items = ManagerInStoreOrderItemSerializer(many=True, read_only=True)
    
    # Custom fields for subtotal and discount
    subtotal = serializers.DecimalField(source='total_amount_before_discount', max_digits=10, decimal_places=2, read_only=True)
    discount_amount = serializers.SerializerMethodField()
    
    class Meta:
        model = InStoreOrder
        fields = [
            'id', 
            'date_created', 
            'is_pwd', 
            'staff', 
            'cashier', 
            'subtotal',
            'discount_amount',
            'total_amount_after_discount',
            'items',
            'status'
        ]
    
    def get_cashier(self, obj):
        # First, try to get the cashier from the InStoreOrderApproval table (for new data).
        if hasattr(obj, 'approval') and obj.approval and obj.approval.cashier:
            return obj.approval.cashier.name
        
        # If no approval record exists but the order has a final status, use the staff name instead.
        if obj.status in ['approved', 'rejected']:
            return obj.staff.name
            
        # For pending orders with no approval record, return "N/A".
        return "N/A"

    def get_discount_amount(self, obj):
        if obj.is_pwd:
            return obj.total_amount_before_discount - obj.total_amount_after_discount
        return Decimal('0.00')


# =================== PRESCRIPTION SERIALIZERS ===================
from .models import InStoreOrder, InStoreOrderItem, OnlineOrder, OnlineOrderItem

class PrescriptionInStoreOrderItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='inventory_id.medicine.name', read_only=True)
    generic_name = serializers.CharField(source='inventory_id.medicine.generic_name', read_only=True)
    is_promo = serializers.BooleanField(source='inventory_id.is_promo', read_only=True)

    class Meta:
        model = InStoreOrderItem
        fields = ['id', 'medicine_name', 'generic_name', 'quantity_sold', 'free_quantity_given', 'price_at_sale', 'is_promo']


class PrescriptionInStoreOrderSerializer(serializers.ModelSerializer):
    staff_name = serializers.CharField(source='staff.name', read_only=True)
    items = PrescriptionInStoreOrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = InStoreOrder
        fields = [
            'id',
            'staff_name',
            'date_created',
            'status',
            'is_pwd',
            'total_amount_before_discount',
            'total_amount_after_discount',
            'items',
        ]


class PrescriptionOnlineOrderItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='inventory_id.medicine.name', read_only=True)
    generic_name = serializers.CharField(source='inventory_id.medicine.generic_name', read_only=True)
    is_promo = serializers.BooleanField(source='inventory_id.is_promo', read_only=True)

    class Meta:
        model = OnlineOrderItem
        fields = ['id', 'medicine_name', 'generic_name', 'quantity_sold', 'free_quantity_given', 'price_at_sale', 'is_promo']


class PrescriptionOnlineOrderSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    items = PrescriptionOnlineOrderItemSerializer(many=True, read_only=True)

    class Meta:
        model = OnlineOrder
        fields = [
            'id',
            'customer_name',
            'date_created',
            'status',
            'is_pwd',
            'total_amount_before_discount',
            'total_amount_after_discount',
            'pickup_schedule',
            'items',
        ]


class PrescriptionImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionImage
        fields = ['id', 'image', 'uploaded_at']


class PrescriptionSerializer(serializers.ModelSerializer):
    images = PrescriptionImageSerializer(many=True, read_only=True)
    in_store_order_details = PrescriptionInStoreOrderSerializer(source='in_store_order', read_only=True)
    online_order_details = PrescriptionOnlineOrderSerializer(source='online_order', read_only=True)
    staff_name = serializers.CharField(source='staff.name', read_only=True)

    class Meta:
        model = Prescription
        fields = [
            'id',
            'staff',
            'staff_name',
            'order_type',
            'in_store_order',
            'online_order',
            'in_store_order_details',
            'online_order_details',
            'created_at',
            'images',
        ]
