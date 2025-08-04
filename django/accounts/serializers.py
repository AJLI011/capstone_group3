from rest_framework import serializers
from .models import (
    Customer, Staff, Supplier, Medicine, Inventory, TotalQuantity,
    Promo, InventoryLog, InStoreOrder, InStoreOrderItem
)

from django.contrib.auth.hashers import make_password
from django.utils import timezone
from decimal import Decimal
from django.db import transaction
from django.utils.timezone import now, localtime  # Import localtime

# Constants
PWD_DISCOUNT_RATE = Decimal('0.20')

# --- Customer & Staff ---
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

# --- Supplier ---
class SupplierSerializer(serializers.ModelSerializer):
    class Meta:
        model = Supplier
        fields = '__all__'

# --- Medicine ---
class MedicineSerializer(serializers.ModelSerializer):
    supplier_name = serializers.StringRelatedField(source='supplier', read_only=True)

    class Meta:
        model = Medicine
        fields = [
            'id', 'name', 'generic_name', 'barcode', 'category', 'dosage_form',
            'supplier', 'supplier_name', 'restock_quantity', 'price',
            'requires_prescription', 'image', 'created_at', 'updated_at',
        ]
        read_only_fields = ['created_at', 'updated_at']

    def update(self, instance, validated_data):
        if 'barcode' in validated_data and validated_data['barcode'] == instance.barcode:
            validated_data.pop('barcode')
        return super().update(instance, validated_data)

# --- Inventory ---
class InventorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Inventory
        fields = [
            'id', 'medicine', 'batch_num', 'exp_date',
            'date_received', 'quantity', 'is_promo', 'promo_start_date'
        ]
        read_only_fields = ['date_received', 'is_promo']


class InventoryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Inventory
        fields = ['medicine', 'batch_num', 'exp_date', 'quantity']


# --- Inventory Dashboard ---
class InventoryDashboardSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='medicine.name')
    generic_name = serializers.CharField(source='medicine.generic_name')
    dosage_form = serializers.CharField(source='medicine.dosage_form')
    supplier_name = serializers.CharField(source='medicine.supplier.name', default=None)
    barcode = serializers.CharField(source='medicine.barcode')

    class Meta:
        model = Inventory
        fields = [
            'id', 'batch_num', 'exp_date', 'quantity',
            'medicine_name', 'generic_name', 'dosage_form',
            'supplier_name', 'barcode', 'is_promo'
        ]


# --- Inventory List ---
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


# --- Inventory Batch Detail ---
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
            'id', 'batch_num', 'exp_date', 'quantity', 'date_received',
            'name', 'generic_name', 'price',
            'is_promo', 'promo_start_date', 'promo_end_date',
        ]

    def get_is_promo(self, obj):
        promo = Promo.objects.filter(inventory_id=obj.id).first()
        today = now().date()  # This is the same logic as before, which seems correct for a `DateField`
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


# --- Total Quantity ---
class TotalQuantitySerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='medicine.name', read_only=True)
    generic_name = serializers.CharField(source='medicine.generic_name', read_only=True)
    image = serializers.ImageField(source='medicine.image', read_only=True)
    category = serializers.CharField(source='medicine.category', read_only=True)

    class Meta:
        model = TotalQuantity
        fields = ['medicine', 'medicine_name', 'generic_name', 'category', 'image', 'total_quantity']


# --- Promo Serializers ---
class PromoMedicineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        fields = ['id', 'name', 'generic_name', 'barcode', 'price']


class PromoSerializer(serializers.ModelSerializer):
    medicine = PromoMedicineSerializer(source='inventory_id.medicine', read_only=True)

    class Meta:
        model = Promo
        fields = ['id', 'inventory_id', 'start_date', 'end_date', 'medicine']


# --- Inventory Logs ---
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


# --- InStore Orders ---
class InStoreOrderSerializer(serializers.ModelSerializer):
    items = serializers.JSONField(write_only=True)

    class Meta:
        model = InStoreOrder
        fields = [
            'id', 'staff', 'date_created', 'is_completed', 'is_pwd',
            'total_amount_before_discount', 'total_amount_after_discount',
            'items'
        ]
        read_only_fields = ['id', 'date_created']

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        is_pwd = validated_data.get('is_pwd', False)

        if validated_data['staff'].role != 'staff':
            raise serializers.ValidationError("Only staff users can create in-store sales.")

        total_amount_before_discount = Decimal('0.00')
        total_amount_after_discount = Decimal('0.00')

        with transaction.atomic():
            order = InStoreOrder.objects.create(
                staff=validated_data['staff'],
                is_pwd=is_pwd,
                total_amount_before_discount=Decimal('0.00'),
                total_amount_after_discount=Decimal('0.00')
            )

            # --- Simplified logic here ---
            today = now().date()

            for item_data in items_data:
                inventory_id = item_data.get('inventory_id')
                quantity_sold = item_data.get('quantity_sold')
                free_quantity_from_client = item_data.get('free_quantity_given', 0)

                try:
                    inventory_item = Inventory.objects.select_related('medicine').get(pk=inventory_id)
                    medicine = inventory_item.medicine
                    price_at_sale = medicine.price
                except Inventory.DoesNotExist:
                    raise serializers.ValidationError(f"Inventory item with ID {inventory_id} does not exist.")
                
                is_promo_db = Promo.objects.filter(
                    inventory_id=inventory_id,
                    start_date__lte=today,
                    end_date__gte=today
                ).exists()

                if not is_promo_db and free_quantity_from_client > 0:
                    raise serializers.ValidationError(
                        f"Promo quantity must be 0 for a non-promo item (Inventory ID: {inventory_id})."
                    )

                total_required_quantity = quantity_sold + free_quantity_from_client
                if inventory_item.quantity < total_required_quantity:
                    raise serializers.ValidationError(
                        f"Not enough stock for inventory ID {inventory_id}. Required: {total_required_quantity}, Available: {inventory_item.quantity}"
                    )

                item_total = Decimal(quantity_sold) * price_at_sale
                total_amount_before_discount += item_total

                InStoreOrderItem.objects.create(
                    order=order,
                    inventory_id_id=inventory_id,
                    quantity_sold=quantity_sold,
                    free_quantity_given=free_quantity_from_client,
                    price_at_sale=price_at_sale
                )

                inventory_item.quantity -= total_required_quantity
                inventory_item.save()

            if is_pwd:
                total_amount_after_discount = total_amount_before_discount * (1 - PWD_DISCOUNT_RATE)
            else:
                total_amount_after_discount = total_amount_before_discount

            order.total_amount_before_discount = total_amount_before_discount
            order.total_amount_after_discount = total_amount_after_discount
            order.save()

        return order