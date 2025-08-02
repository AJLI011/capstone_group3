from rest_framework import serializers
from .models import Customer, Staff, Supplier, Medicine, Inventory, InStoreOrder, InStoreOrderItem, Promo

from django.contrib.auth.hashers import make_password
from decimal import Decimal
from django.db import transaction
from django.utils import timezone


# Add this constant for the PWD discount rate
PWD_DISCOUNT_RATE = Decimal('0.20')


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
        fields = ['id', 'medicine', 'batch_num', 'exp_date', 'date_received', 'quantity']
        read_only_fields = ['date_received']

class InventoryCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Inventory
        fields = ['medicine', 'batch_num', 'exp_date', 'quantity']


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
        ]

# serializer to get medicine details for promo
class PromoMedicineSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        fields = ['id', 'name', 'generic_name', 'barcode', 'price']


# Serializer for Promotions
class PromoSerializer(serializers.ModelSerializer):
    medicine = PromoMedicineSerializer(source='inventory_id.medicine', read_only=True)

    class Meta:
        model = Promo
        fields = ['id', 'inventory_id', 'start_date', 'end_date', 'medicine']  # removed get_free_quantity


# A serializer for In-store Orders that includes nested items
class InStoreOrderSerializer(serializers.ModelSerializer):
    items = serializers.JSONField(write_only=True)

    class Meta:
        model = InStoreOrder
        fields = [
            'id', 
            'staff', 
            'date_created', 
            'is_completed', 
            'is_pwd',
            'total_amount_before_discount',
            'total_amount_after_discount',
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
            # Create base order
            order = InStoreOrder.objects.create(
                staff=validated_data['staff'],
                is_pwd=is_pwd,
                total_amount_before_discount=Decimal('0.00'),
                total_amount_after_discount=Decimal('0.00')
            )

            for item_data in items_data:
                inventory_id = item_data.get('inventory_id')
                quantity_sold = item_data.get('quantity_sold')

                try:
                    inventory_item = Inventory.objects.select_related('medicine').get(pk=inventory_id)
                    medicine = inventory_item.medicine
                    price_at_sale = medicine.price
                except Inventory.DoesNotExist:
                    raise serializers.ValidationError(f"Inventory item with ID {inventory_id} does not exist.")

                # --- Check if this item is on promo ---
                is_promo = Promo.objects.filter(
                    inventory_id=inventory_id,
                    start_date__lte=timezone.now().date(),
                    end_date__gte=timezone.now().date()
                ).exists()

                # Apply 1:1 promo logic if active
                free_quantity = quantity_sold if is_promo else 0

                # Check inventory sufficiency
                total_required_quantity = quantity_sold + free_quantity
                if inventory_item.quantity < total_required_quantity:
                    raise serializers.ValidationError(
                        f"Not enough stock for inventory ID {inventory_id}. Required: {total_required_quantity}, Available: {inventory_item.quantity}"
                    )

                # Update total before any discounts
                item_total = Decimal(quantity_sold) * price_at_sale
                total_amount_before_discount += item_total

                # Create the item record
                InStoreOrderItem.objects.create(
                    order=order,
                    inventory_id_id=inventory_id,
                    quantity_sold=quantity_sold,
                    free_quantity_given=free_quantity,
                    price_at_sale=price_at_sale
                )

                # Deduct from inventory
                inventory_item.quantity -= total_required_quantity
                inventory_item.save()

            # --- Apply PWD discount if applicable ---
            if is_pwd:
                total_amount_after_discount = total_amount_before_discount * (1 - PWD_DISCOUNT_RATE)
            else:
                total_amount_after_discount = total_amount_before_discount

            # Save totals
            order.total_amount_before_discount = total_amount_before_discount
            order.total_amount_after_discount = total_amount_after_discount
            order.save()

        return order