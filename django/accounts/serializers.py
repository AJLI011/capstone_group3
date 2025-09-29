from rest_framework import serializers
from .models import (
    Customer, Staff, Supplier, Medicine, Inventory, TotalQuantity, Promo, InventoryLog, 
    InStoreOrder, InStoreOrderItem, EmployeeLog, OrderLog, OnlineOrder, OnlineOrderItem, Prescription,
    PrescriptionImage, CustomerFCMToken, ForecastReport, ForecastItem, StaffFCMToken
)
from django.contrib.auth.hashers import make_password
from decimal import Decimal
from datetime import date
from django.db import transaction
from django.db.models import F, Sum
from django.utils.timezone import now
from django.utils import timezone # add this (elton)
from rest_framework.validators import UniqueValidator



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













#=================================================================================================
#MODIFIED THE FF FOR BARCODE DUPLICATION PREVENTION WHEN ADDING
class MedicineSerializer(serializers.ModelSerializer):
    supplier_name = serializers.StringRelatedField(source='supplier', read_only=True)
    barcode = serializers.CharField(
        required=False,  # Make the field optional for partial updates
        validators=[UniqueValidator(queryset=Medicine.objects.all())]
    )

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
        # Your existing update logic
        if 'barcode' in validated_data and validated_data['barcode'] == instance.barcode:
            validated_data.pop('barcode')
        return super().update(instance, validated_data)

#=================================================================================================


















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







#===========================09/13/25 (ELTON)========================================================
# For Inventory Logs
class InventoryLogSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    medicine_name = serializers.SerializerMethodField()

    class Meta:
        model = InventoryLog
        fields = ['id', 'user_name', 'medicine_name', 'action_type', 'timestamp', 'description']

    def get_user_name(self, obj):
        if obj.user:
            return f"{obj.user.name}, {obj.user.role}"
        return "Unknown"

    def get_medicine_name(self, obj):
        # ✅ It's better to return None or a predictable empty string
        return obj.medicine_name_log
#===========================09/13/25 (ELTON)========================================================










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



#==========================9/15/25=================================
# Customer Promo Medicines View
class PromoMedicineSerializer(serializers.ModelSerializer):
    # These fields are defined with a source to pull data from the related Medicine model
    id = serializers.IntegerField(source='medicine.id', read_only=True)
    name = serializers.CharField(source='medicine.name', read_only=True)
    generic_name = serializers.CharField(source='medicine.generic_name', read_only=True)
    price = serializers.DecimalField(source='medicine.price', max_digits=8, decimal_places=2, read_only=True)
    image = serializers.SerializerMethodField()

    class Meta:
        # The model for this serializer is Inventory
        model = Inventory
        # You must explicitly list ALL the fields you want to include in the API response.
        # This is where the error comes from.
        fields = ['id', 'name', 'generic_name', 'price', 'image']

    def get_image(self, obj):
        request = self.context.get('request', None)
        if obj.medicine.image and hasattr(obj.medicine.image, 'url'):
            if request:
                return request.build_absolute_uri(obj.medicine.image.url)
            return obj.medicine.image.url
        return '' # Return an empty string if there's no image
#==========================9/15/25=================================






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
        # local import of Inventory avoids circular import problems
        from .models import Inventory
        today = timezone.now().date()
        total = Inventory.objects.filter(
            medicine=obj,
            is_promo=True,
            # This is the line you need to change:
            exp_date__gt=today
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












#============================9/1/25============================================
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
        today = timezone.now().date()
        total = Inventory.objects.filter(
            medicine=obj,
            is_promo=False,
            # This is the line you need to change: ADD THIS (Elton)
            exp_date__gt=today
        ).aggregate(total=Sum('quantity'))['total']
        return total or 0

    def get_stock_status(self, obj):
        return "In Stock" if self.get_quantity(obj) > 0 else "Out of Stock"
#=================================9/1/25=============================================================























#----------9/23/25


# Employee Logs serializer
class EmployeeLogSerializer(serializers.ModelSerializer):
    # Accept staff ID on write (this is already correct)
    staff = serializers.PrimaryKeyRelatedField(queryset=Staff.objects.all(), write_only=True)

    # ✅ Use SerializerMethodField for related fields to handle them properly
    staff_name = serializers.SerializerMethodField()
    staff_role = serializers.SerializerMethodField()

    class Meta:
        model = EmployeeLog
        fields = ['id', 'staff', 'staff_name', 'staff_role', 'action', 'timestamp']
        # read_only_fields are not needed for SerializerMethodField
        # read_only_fields = ['id', 'staff_name', 'staff_role', 'timestamp']

    def get_staff_name(self, obj):
        return obj.staff.name if obj.staff else None

    def get_staff_role(self, obj):
        return obj.staff.role if obj.staff else None

# =====================================
# IN-STORE ORDERS SERIALIZERS

class InStoreOrderItemSerializer(serializers.ModelSerializer):
    # Use SerializerMethodField for all related data that can be null
    medicine_name = serializers.SerializerMethodField()
    barcode = serializers.SerializerMethodField()
    batch_num = serializers.SerializerMethodField()
    exp_date = serializers.SerializerMethodField()
    # No change needed for price_at_sale as it's a direct field on the model

    class Meta:
        model = InStoreOrderItem
        fields = [
            'id', 
            'medicine_name', 
            'barcode', 
            'batch_num', 
            'exp_date', 
            'quantity_sold', 
            'free_quantity_given', 
            'price_at_sale'
        ]

    def get_medicine_name(self, obj):
        if obj.inventory_id and obj.inventory_id.medicine:
            return obj.inventory_id.medicine.name
        return "N/A"

    def get_barcode(self, obj):
        if obj.inventory_id and obj.inventory_id.medicine:
            return obj.inventory_id.medicine.barcode
        return "N/A"

    def get_batch_num(self, obj):
        if obj.inventory_id:
            return obj.inventory_id.batch_num
        return "N/A"

    def get_exp_date(self, obj):
        if obj.inventory_id:
            return obj.inventory_id.exp_date
        return "N/A"
#----------9/23/25
























class CashierInStoreOrderSerializer(serializers.ModelSerializer):
    items = InStoreOrderItemSerializer(many=True, read_only=True)
    staff_name = serializers.CharField(source='staff.name', read_only=True)
    # **THIS IS THE NEW FIELD
    cashier_name = serializers.CharField(source='cashier.name', read_only=True)
    # --9/29/25-- ADDED
    has_prescription_required_item = serializers.BooleanField(read_only=True)

    class Meta:
        model = InStoreOrder
        # **ADD 'cashier_name' to the fields list**
        # --9/29/25 ADDED 'has_prescription_required_item'
        fields = ['id', 'staff_name', 'cashier_name', 'is_pwd', 'total_amount_before_discount', 'total_amount_after_discount', 'items', 'has_prescription_required_item']





#--------------------09/14/2025--------------------------- fixing return medicine
class InStoreOrderSerializer(serializers.ModelSerializer):
    items = serializers.ListField(child=serializers.DictField())
    staff = serializers.PrimaryKeyRelatedField(queryset=Staff.objects.all())

    class Meta:
        model = InStoreOrder
        fields = ['staff', 'is_pwd', 'items', 'status']
        read_only_fields = ['status']
    
    def validate_items(self, value):
        if not value:
            raise serializers.ValidationError("Order must contain at least one item.")
        
        for item in value:
            inventory_id = item.get('inventory_id')
            if not inventory_id:
                raise serializers.ValidationError("Each item must have an inventory_id.")
            quantity_sold = item.get('quantity_sold', 0)
            free_quantity_given = item.get('free_quantity_given', 0)
            if quantity_sold <= 0 and free_quantity_given <= 0:
                raise serializers.ValidationError("Quantity sold or free quantity must be greater than zero.")
        
        return value

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        staff = validated_data['staff']
        is_pwd = validated_data.get('is_pwd', False)
        
        try:
            with transaction.atomic():
                order = InStoreOrder.objects.create(staff=staff, is_pwd=is_pwd)
                
                total_before = Decimal('0.00')
                order_items_to_create = []

                for item_data in items_data:
                    inventory_id = item_data.get('inventory_id')
                    quantity_to_sell = item_data.get('quantity_sold', 0)
                    free_quantity_to_give = item_data.get('free_quantity_given', 0)
                    
                    try:
                        selected_batch = Inventory.objects.get(id=inventory_id)
                    except Inventory.DoesNotExist:
                        order.delete()
                        raise serializers.ValidationError(f"Selected batch with ID {inventory_id} does not exist.")
                    
                    # --- START OF CHANGE ---
                    # Capture the medicine's name and generic name from the Inventory's medicine
                    medicine_name = selected_batch.medicine.name
                    generic_name = selected_batch.medicine.generic_name

                    order_items_to_create.append(
                        InStoreOrderItem(
                            order=order,
                            inventory_id=selected_batch,
                            quantity_sold=quantity_to_sell,
                            free_quantity_given=free_quantity_to_give,
                            price_at_sale=selected_batch.medicine.price,
                            # New fields added here:
                            medicine_name=medicine_name,
                            generic_name=generic_name,
                        )
                    )
                    # --- END OF CHANGE ---
                                 
                    total_before += quantity_to_sell * selected_batch.medicine.price

                InStoreOrderItem.objects.bulk_create(order_items_to_create)

                requires_prescription = selected_batch.medicine.requires_prescription
                if requires_prescription:
                    Prescription.objects.create(
                        in_store_order=order,
                        status='pending'
                    )

                discount = total_before * Decimal('0.20') if is_pwd else Decimal('0.00')
                order.total_amount_before_discount = total_before
                order.total_amount_after_discount = total_before - discount
                order.save()

                return order
        except Exception as e:
            if 'order' in locals() and order.pk:
                order.delete()
            raise serializers.ValidationError(
                f"Failed to create pending order: {str(e)}"
            )
            
                 
                 
                 
     
     
     
     
        
                        

#----------9/23/25-----------------------------------------------------------------------------------            
# ORDER LOGS SERIALIZERS

class InStoreOrderItemSerializer(serializers.ModelSerializer):
    # This correctly uses a SerializerMethodField to prevent crashes
    medicine_name = serializers.SerializerMethodField()

    class Meta:
        model = InStoreOrderItem
        fields = ['id', 'medicine_name', 'quantity_sold', 'price_at_sale']

    def get_medicine_name(self, obj):
        # Gracefully handle the case where the inventory_id is null
        if obj.inventory_id and obj.inventory_id.medicine:
            return obj.inventory_id.medicine.name
        # Fallback to the snapshot field on the model
        return obj.medicine_name if obj.medicine_name else "N/A"
    
    
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


#----------9/23/25-----------------------------------------------------------------------------------




















# ---------------9/26/25
#----------9/23/25-----------------------------------------------------------------------------------[as of 4:30 pm aaron]
#=================================9/1/25===============================
    
class OnlineOrderItemReadSerializer(serializers.ModelSerializer):
    # Change 'medicine' to a SerializerMethodField
    medicine = serializers.SerializerMethodField()
    
    class Meta:
        model = OnlineOrderItem
        fields = [
            'id', 
            'medicine',
            'quantity_sold', 
            'free_quantity_given', 
            'price_at_sale'
        ]

    def get_medicine(self, obj):
        # Check if the inventory link and the related medicine still exist
        if obj.inventory_id and obj.inventory_id.medicine:
            # If they exist, return the medicine's data.
            return {
                'name': obj.inventory_id.medicine.name,
                'generic_name': obj.inventory_id.medicine.generic_name,
                'requires_prescription': obj.inventory_id.medicine.requires_prescription,
                'image': obj.inventory_id.medicine.image.url if obj.inventory_id.medicine.image else None,
                'is_deleted': False
            }
        else:
            # If the medicine is deleted or the link is broken,
            # return a placeholder object with an 'is_deleted' flag,
            # but use the snapshot fields for the name.
            return {
                'name': obj.medicine_name,
                'generic_name': obj.generic_name,
                'requires_prescription': False,
                'image': None,
                'is_deleted': True
            }
            
    # ⭐ NEW: Override to_representation to set price_at_sale to 0 for deleted items
    def to_representation(self, instance):
        representation = super().to_representation(instance)
        
        # Check if the medicine is marked as deleted by the get_medicine method logic
        # This is the most reliable way to check for a broken link
        is_deleted = not (instance.inventory_id and instance.inventory_id.medicine)
        
        if is_deleted:
            # If the item is deleted/unavailable, ensure the price is 0.00.
            # This will make the itemTotal in the Flutter app 0.0, triggering 
            # the "deleted" UI logic.
            representation['price_at_sale'] = Decimal('0.00').quantize(Decimal('.01'))

        return representation

#----------9/23/25-----------------------------------------------------------------------------------[as of 4:30 pm aaron]
    
    
    
    
    














    
# New serializer for Online order details within a log
class OnlineOrderLogDetailsSerializer(serializers.ModelSerializer):
    items = OnlineOrderItemReadSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)

    class Meta:
        model = OnlineOrder
        fields = ['id', 'customer_name', 'customer_email', 'items']





        
        
        
        
        
        
        
        
        
        

# ---------------9/26/25
#----------9/23/25-----------------------------------------------------------------------------------[as of 4:30 pm aaron]       
class OnlineOrderListSerializer(serializers.ModelSerializer):
    items = OnlineOrderItemReadSerializer(many=True, read_only=True)
    customer_name = serializers.CharField(source='customer.name', read_only=True)
    customer_email = serializers.CharField(source='customer.email', read_only=True)
    pickup_schedule = serializers.DateTimeField(read_only=True)
    fulfilled_timestamp = serializers.DateTimeField(source='date_fulfilled', read_only=True)
    
    # This field is now redundant. The Flutter side should handle displaying all
    # items from the 'items' list and marking the deleted ones.
    # deleted_item_name = serializers.SerializerMethodField()
    
    class Meta:
        model = OnlineOrder
        fields = [
            'id', 'customer_name', 'customer_email', 'date_created',
            'status', 'total_amount_before_discount', 'total_amount_after_discount',
            'is_pwd', 'items', 'pickup_schedule', 'fulfilled_timestamp',
            # 'deleted_item_name', # Remove this line
        ]

    # You can remove this entire method since the front-end will no longer use it.
    # def get_deleted_item_name(self, obj):
    #     if obj.status == 'cancelled' and obj.total_amount_after_discount == 0:
    #         first_item = obj.items.first()
    #         if first_item:
    #             return first_item.medicine_name
    #     return None

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        
        # Check if the order is cancelled.
        if representation['status'] == 'cancelled':
            # For cancelled orders, we want to show all original items,
            # including those that are now marked as deleted.
            return representation

        # For all other statuses, filter out deleted items.
        #serialized_items = representation['items']
        #available_items = [
            #item for item in serialized_items
            #if not item.get('medicine', {}).get('is_deleted', False)
        #]
        #representation['items'] = available_items
        
        # This logic is now handled in the view, so this part is redundant,
        # but leaving it here doesn't hurt.
        #if representation['status'] in ['pending', 'ready for pickup'] and not available_items:
            #instance.status = 'cancelled'
            #instance.save(update_fields=['status'])
            #representation['status'] = 'cancelled'
        
        return representation
    
    

#----------9/23/25-----------------------------------------------------------------------------------[as of 4:30 pm aaron]




















        
    

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








#----------9/23/25-----------------------------------------------------------------------------------
#--------------------09/14/2025--------------------------- fixing return medicine
class OnlineOrderCreateSerializer(serializers.ModelSerializer):
    items = OnlineOrderItemCreateSerializer(many=True, write_only=True)
    customer_id = serializers.PrimaryKeyRelatedField(
        queryset=Customer.objects.all(), source='customer', write_only=True
    )
    pickup_schedule = serializers.DateTimeField(write_only=True)
    id = serializers.IntegerField(read_only=True)
    date_created = serializers.DateTimeField(read_only=True) # Added this line

    class Meta:
        model = OnlineOrder
        fields = ['id', 'customer_id', 'is_pwd', 'items', 'pickup_schedule', 'date_created'] # Added 'date_created' here

    def create(self, validated_data):
        items_data = validated_data.pop('items')
        pickup_schedule = validated_data.pop('pickup_schedule')
        customer = validated_data['customer']
        is_pwd = validated_data.get('is_pwd', False)
        
        total_before = Decimal('0.00')
        order_items_to_create = []
        is_prescription_required = False

        try:
            with transaction.atomic():
                for item_data in items_data:
                    # ... (rest of the create method remains the same) ...
                    medicine = item_data['medicine_id']
                    quantity_sold_initial = item_data['quantity_sold']
                    free_quantity_given_initial = item_data.get('free_quantity_given', 0)
                    is_promo = item_data['is_promo']

                    if medicine.requires_prescription:
                        is_prescription_required = True
                    
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
                        
                        medicine_name = inventory_batch.medicine.name
                        generic_name = inventory_batch.medicine.name
                        
                        order_items_to_create.append(
                            OnlineOrderItem(
                                inventory_id=inventory_batch,
                                quantity_sold=quantity_sold_initial,
                                free_quantity_given=free_quantity_given_initial,
                                price_at_sale=medicine.price,
                                medicine_name=medicine_name,
                                generic_name=generic_name,
                            )
                        )
                    except Exception as e:
                        raise serializers.ValidationError(
                            f"Error processing item {medicine.name}: {str(e)}"
                        )

                    total_before += quantity_sold_initial * medicine.price

                order = OnlineOrder.objects.create(
                    customer=customer,
                    is_pwd=is_pwd,
                    pickup_schedule=pickup_schedule,
                    status='pending',
                    total_amount_before_discount=total_before,
                    total_amount_after_discount=total_before - (total_before * Decimal('0.20') if is_pwd else Decimal('0.00'))
                )

                for item in order_items_to_create:
                    item.order = order

                OnlineOrderItem.objects.bulk_create(order_items_to_create)

                if is_prescription_required:
                    Prescription.objects.create(
                        online_order=order,
                        status='pending'
                    )

                return order
        except Exception as e:
            raise serializers.ValidationError(f"Failed to process order: {str(e)}")
#=================================9/1/25=============================================================
#----------9/23/25-----------------------------------------------------------------------------------




























#-------- in store transactions serializers--------------------
# New serializer for Staff to get their name and role
class StaffDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = Staff
        fields = ['name', 'role']

#--------------------09/14/2025--------------------------- fixing return medicine
# Corrected nested serializer for InStoreOrderItem
class ManagerInStoreOrderItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(read_only=True)
    price_per_item = serializers.DecimalField(source='price_at_sale', max_digits=10, decimal_places=2, read_only=True)
    is_promo = serializers.SerializerMethodField()

    class Meta:
        model = InStoreOrderItem
        fields = [
            'quantity_sold',
            'free_quantity_given',
            'is_promo',
            'medicine_name',
            'price_per_item',
        ]

    def get_is_promo(self, obj):
        # Check if inventory_id is not null before trying to access its fields
        if obj.inventory_id:
            return obj.inventory_id.is_promo
        return False
    
    
    
    
    
    
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
        try:
            # Correctly use the related name 'logs'
            approval_log = obj.logs.get(action_type='in_store_approve')
            return approval_log.staff_user.name
        except OrderLog.DoesNotExist:
            return "N/A"
            
    def get_discount_amount(self, obj):
        if obj.is_pwd:
            return obj.total_amount_before_discount - obj.total_amount_after_discount
        return Decimal('0.00')


#---presc---------------------------------------
# =====================================
# PRESCRIPTION VIEW SERIALIZERS

class PrescriptionImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PrescriptionImage
        fields = ['image']

class PrescriptionItemSerializer(serializers.ModelSerializer):
    medicine_name = serializers.CharField(source='inventory_id.medicine.name', read_only=True)
    is_promo = serializers.BooleanField(source='inventory_id.is_promo', read_only=True)
    requires_prescription = serializers.BooleanField(source='inventory_id.medicine.requires_prescription', read_only=True)

    class Meta:
        model = InStoreOrderItem
        fields = ['medicine_name', 'quantity_sold', 'free_quantity_given', 'price_at_sale', 'is_promo', 'requires_prescription']


class PrescriptionOrderSerializer(serializers.ModelSerializer):
    staff_name = serializers.CharField(source='in_store_order.staff.name', read_only=True)
    order_id = serializers.IntegerField(source='in_store_order.id', read_only=True)
    order_items = PrescriptionItemSerializer(source='in_store_order.items', many=True, read_only=True)
    is_pwd = serializers.BooleanField(source='in_store_order.is_pwd', read_only=True)
    images = PrescriptionImageSerializer(many=True, read_only=True) # New field to handle multiple images

    class Meta:
        model = Prescription
        fields = ['id', 'order_id', 'staff_name', 'order_items', 'is_pwd', 'status', 'images', 'date_uploaded']

    def to_representation(self, instance):
        representation = super().to_representation(instance)
        
        # Calculate totals on the fly
        subtotal = sum(
            item['quantity_sold'] * item['price_at_sale'] 
            for item in representation['order_items']
        )
        
        discount = 0
        if representation['is_pwd']:
            discount = subtotal * 0.20
            
        total = subtotal - discount
        
        representation['total_amount_before_discount'] = "{:.2f}".format(subtotal)
        representation['total_amount_after_discount'] = "{:.2f}".format(total)
        representation['discount_amount'] = "{:.2f}".format(discount)
        
        return representation

class CombinedPrescriptionSerializer(serializers.ModelSerializer):
    order_id = serializers.SerializerMethodField()
    order_type = serializers.SerializerMethodField()
    staff_or_customer_name = serializers.SerializerMethodField()
    total_amount_after_discount = serializers.SerializerMethodField()
    images = PrescriptionImageSerializer(many=True, read_only=True) # New field for multiple images
    discount_amount = serializers.SerializerMethodField()
    total_amount_before_discount = serializers.SerializerMethodField()
    is_pwd = serializers.SerializerMethodField()
    order_items = serializers.SerializerMethodField()
    
    class Meta:
        model = Prescription
        fields = [
            'id', 'order_id', 'images', 'status', 'date_uploaded',
            'order_type', 'staff_or_customer_name', 'total_amount_after_discount',
            'discount_amount', 'total_amount_before_discount', 'is_pwd', 'order_items'
        ]

    def get_order_id(self, obj):
        if obj.in_store_order_id:
            return obj.in_store_order_id
        return obj.online_order_id

    def get_order_type(self, obj):
        if obj.in_store_order_id:
            return 'in_store'
        return 'online'

    def get_staff_or_customer_name(self, obj):
        if obj.in_store_order:
            return obj.in_store_order.staff.name
        elif obj.online_order:
            return obj.online_order.customer.name
        return None
    
    def get_total_amount_after_discount(self, obj):
        if obj.in_store_order:
            return obj.in_store_order.total_amount_after_discount
        elif obj.online_order:
            return obj.online_order.total_amount_after_discount
        return None

    def get_discount_amount(self, obj):
        if obj.in_store_order:
            return obj.in_store_order.total_amount_before_discount - obj.in_store_order.total_amount_after_discount
        elif obj.online_order:
            return obj.online_order.total_amount_before_discount - obj.online_order.total_amount_after_discount
        return 0

    def get_total_amount_before_discount(self, obj):
        if obj.in_store_order:
            return obj.in_store_order.total_amount_before_discount
        elif obj.online_order:
            return obj.online_order.total_amount_before_discount
        return 0

    def get_is_pwd(self, obj):
        """
        Retrieves the is_pwd status from the associated order.
        """
        if obj.in_store_order:
            return obj.in_store_order.is_pwd
        elif obj.online_order:
            return obj.online_order.is_pwd
        return False
        
    def get_order_items(self, obj):
        if obj.in_store_order:
            items = InStoreOrderItem.objects.filter(order=obj.in_store_order)
            return InStoreOrderItemSerializer(items, many=True, context=self.context).data
        elif obj.online_order:
            items = OnlineOrderItem.objects.filter(order=obj.online_order)
            return OnlineOrderItemReadSerializer(items, many=True, context=self.context).data
        return []
    
#-----PUSH NOTIF

class CustomerFCMTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomerFCMToken
        fields = ['id', 'customer', 'token', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']



#====================================09/13/24 DASHBOARD (ELTON) ===================================#
#low stocks & totalqty

class LowStockSerializer(serializers.ModelSerializer):
    # This correctly gets the medicine's name
    name = serializers.CharField(source='medicine.name')
    # This correctly gets the medicine's generic name
    generic_name = serializers.CharField(source='medicine.generic_name')
    
    # NEW: Get the restock_quantity directly from the related Medicine model
    restock_quantity = serializers.IntegerField(source='medicine.restock_quantity')

    # NEW: Get the supplier's name by following the 'medicine' and 'supplier' relationships
    supplier_name = serializers.CharField(source='medicine.supplier.name')
    
    # NEW: Get the supplier's contact number
    contact_num = serializers.CharField(source='medicine.supplier.contact')

    class Meta:
        model = TotalQuantity
        fields = [
            'name',
            'generic_name',
            'total_quantity',
            'restock_quantity',
            'supplier_name',
            'contact_num'
        ]

#====================================09/13/24 DASHBOARD (ELTON) ===================================# 


#Demand Forecasting
# This keeps the API response clean and fast.
class MedicineForecastSerializer(serializers.ModelSerializer):
    class Meta:
        model = Medicine
        fields = ['id', 'name', 'generic_name']
















#----------9/23/25-------------------------------------------------------------------------------------
# NEW: Serializer for the forecast items.
class ForecastItemSerializer(serializers.ModelSerializer):
    # Use the simplified MedicineForecastSerializer to represent the medicine object.
    medicine = MedicineForecastSerializer(read_only=True)

    class Meta:
        model = ForecastItem
        # UPDATED FIELDS: Add 'medicine_name' and 'generic_name' to the fields list
        fields = [
            'rank',
            'forecasted_quantity',
            'current_stock',
            'restock_amount',
            'medicine',
            'medicine_name', # <--- ADD THIS FIELD
            'generic_name' # <--- ADD THIS FIELD
        ]
#----------9/23/25-------------------------------------------------------------------------------------



















# NEW: Main serializer for the forecast report.
class ForecastReportSerializer(serializers.ModelSerializer):
    # The 'items' field here will return a list of all ForecastItem objects
    # related to this report.
    items = ForecastItemSerializer(many=True, read_only=True)

    class Meta:
        model = ForecastReport
        fields = ['week_start_date', 'date_generated', 'items']

#-----EXPIRY NOTIFICATION
class StaffFCMTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = StaffFCMToken
        fields = ['id', 'staff', 'token', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
        
        

#-----------------
class DailyReportSerializer(serializers.Serializer):
    employee_logs = EmployeeLogSerializer(many=True, read_only=True)
    order_logs = OrderLogSerializer(many=True, read_only=True)
    inventory_logs = InventoryLogSerializer(many=True, read_only=True)