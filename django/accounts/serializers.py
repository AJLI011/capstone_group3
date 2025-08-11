from rest_framework import serializers
from .models import Customer, Staff, Supplier, Medicine, Inventory, TotalQuantity, Promo, InventoryLog, InStoreOrder, InStoreOrderItem, EmployeeLog, OrderLog, OnlineOrder, OnlineOrderItem

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

#order logs (wala pa yung online order here)
# Model for Order Logs
# =====================================
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

class OrderLogSerializer(serializers.ModelSerializer):
    staff_name = serializers.CharField(source='staff_user.name', read_only=True)
    staff_role = serializers.CharField(source='staff_user.role', read_only=True)
    
    in_store_order_details = InStoreOrderDetailsSerializer(source='in_store_order', read_only=True)

    class Meta:
        model = OrderLog
        fields = ['id', 'staff_name', 'staff_role', 'in_store_order_details', 'action_type', 'description', 'timestamp']

# Online Orders Serializers
class OnlineOrderItemReadSerializer(serializers.ModelSerializer):
    medicine = MedicineSerializer(source='inventory_id.medicine')
    free_quantity_given = serializers.IntegerField()

    class Meta:
        model = OnlineOrderItem
        fields = ['medicine', 'quantity_sold', 'free_quantity_given', 'price_at_sale']


class OnlineOrderListSerializer(serializers.ModelSerializer):
    # Removed the redundant `source='items'`
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

    class Meta:
        model = OnlineOrderItem
        fields = ['medicine_id', 'quantity_sold', 'free_quantity_given']


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

        try:
            with transaction.atomic():
                order = OnlineOrder(
                    customer=customer,
                    is_pwd=is_pwd,
                    pickup_schedule=pickup_schedule,
                )

                medicine_ids = [item['medicine_id'] for item in items_data]

                all_batches = Inventory.objects.filter(
                    medicine__in=medicine_ids,
                    quantity__gt=0,
                    exp_date__gt=date.today()
                ).order_by('exp_date')

                order_items_to_create = []

                for item_data in items_data:
                    medicine = item_data['medicine_id']
                    quantity_sold = item_data['quantity_sold']
                    free_quantity_given = item_data.get('free_quantity_given', 0)
                    total_to_deduct = quantity_sold + free_quantity_given
                    remaining_to_deduct = total_to_deduct

                    try:
                        total_quantity_obj = TotalQuantity.objects.get(medicine=medicine)
                        if total_quantity_obj.total_quantity < total_to_deduct:
                            raise serializers.ValidationError(
                                f"Not enough stock for {medicine.name}. "
                                f"Requested: {total_to_deduct}, "
                                f"Available: {total_quantity_obj.total_quantity}"
                            )
                    except TotalQuantity.DoesNotExist:
                        raise serializers.ValidationError(
                            f"Stock for {medicine.name} not found."
                        )

                    available_batches = all_batches.filter(medicine=medicine)
                    
                    for batch in available_batches:
                        if remaining_to_deduct <= 0:
                            break
                        
                        quantity_from_batch = min(remaining_to_deduct, batch.quantity)
                        sold_from_batch = min(quantity_from_batch, quantity_sold)
                        free_from_batch = quantity_from_batch - sold_from_batch
                        
                        order_items_to_create.append(
                            OnlineOrderItem(
                                order=order,
                                inventory_id=batch,
                                quantity_sold=sold_from_batch,
                                free_quantity_given=free_from_batch,
                                price_at_sale=medicine.price
                            )
                        )
                        remaining_to_deduct -= quantity_from_batch
                        quantity_sold -= sold_from_batch
                        
                        batch.quantity -= quantity_from_batch
                        
                    if remaining_to_deduct > 0:
                        raise serializers.ValidationError(
                            f"Internal Error: Could not deduct all requested quantity for {medicine.name}. Remaining: {remaining_to_deduct}"
                        )

                    total_before += item_data['quantity_sold'] * medicine.price

                order.total_amount_before_discount = total_before
                discount = total_before * Decimal('0.20') if is_pwd else Decimal('0.00')
                order.total_amount_after_discount = total_before - discount
                order.save()
                
                Inventory.objects.bulk_update(all_batches, ['quantity'])

                for item in order_items_to_create:
                    item.order = order
                OnlineOrderItem.objects.bulk_create(order_items_to_create)

                return order
        except Exception as e:
            raise serializers.ValidationError(f"Failed to process order: {str(e)}")