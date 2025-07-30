from rest_framework import serializers
from .models import Customer, Staff, Supplier, Medicine, Inventory, InStoreOrder, InStoreOrderItem, Promo

from django.contrib.auth.hashers import make_password

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
class InventorySerializer(serializers.ModelSerializer): # Renamed class
    class Meta:
        model = Inventory # Changed from ExpirationList
        fields = ['id', 'medicine', 'batch_num', 'exp_date', 'date_received', 'quantity'] # Added quantity since it's in the model
        read_only_fields = ['date_received']

class InventoryCreateSerializer(serializers.ModelSerializer): # Renamed class
    class Meta:
        model = Inventory # Changed from ExpirationList
        fields = ['medicine', 'batch_num', 'exp_date', 'quantity'] # Added quantity


# For Expiration Dashboard
class InventoryDashboardSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='medicine.name')
    generic_name = serializers.CharField(source='medicine.generic_name')
    dosage_form = serializers.CharField(source='medicine.dosage_form')
    supplier_name = serializers.CharField(source='medicine.supplier.name', default=None)  # Adjust if needed
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
        fields = ['id', 'inventory_id', 'start_date', 'end_date', 'medicine']

# A serializer for In-store Order Items
class InStoreOrderItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = InStoreOrderItem
        fields = ['inventory_id', 'quantity_sold', 'free_quantity_given', 'price_at_sale']

# A serializer for In-store Orders that includes nested items
class InStoreOrderSerializer(serializers.ModelSerializer):
    items = InStoreOrderItemSerializer(many=True, read_only=True)

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
        items_data = self.context.get('request').data.get('items')
        
        order = InStoreOrder.objects.create(
            staff=validated_data['staff'],
            is_pwd=validated_data.get('is_pwd', False),
            total_amount_before_discount=validated_data.get('total_amount_before_discount', 0),
            total_amount_after_discount=validated_data.get('total_amount_after_discount', 0)
        )
        
        for item_data in items_data:
            inventory_id = item_data.get('inventory_id')
            quantity_sold = item_data.get('quantity_sold')
            free_quantity_given = item_data.get('free_quantity_given')
            price_at_sale = item_data.get('price_at_sale')
            
            # Create OrderItem entry
            InStoreOrderItem.objects.create(
                order=order,
                inventory_id_id=inventory_id,
                quantity_sold=quantity_sold,
                free_quantity_given=free_quantity_given,
                price_at_sale=price_at_sale
            )

            # Update inventory quantity
            inventory_item = Inventory.objects.get(pk=inventory_id)
            inventory_item.quantity -= (quantity_sold + free_quantity_given)
            inventory_item.save()

        return order