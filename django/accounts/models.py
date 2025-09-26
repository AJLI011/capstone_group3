from django.db import models

# For staff roles like admin, manager, cashier, staff
class Staff(models.Model):
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('manager', 'Manager'),
        ('cashier', 'Cashier'),
        ('staff', 'Staff'),
    ]
 
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=128)
    name = models.CharField(max_length=100, default='Unknown')
    role = models.CharField(max_length=20, choices=ROLE_CHOICES)
    contact_num = models.CharField(max_length=20, blank=True, null=True)

    def __str__(self):
        return f"{self.role} - {self.email}"


# For customers (they register via app)
class Customer(models.Model):
    name = models.CharField(max_length=100)
    email = models.EmailField(unique=True)
    contact_num = models.CharField(max_length=20, blank=True, null=True)
    password = models.CharField(max_length=128)

    def __str__(self):
        return self.email


# For suppliers
class Supplier(models.Model):
    name = models.CharField(max_length=100)
    contact = models.CharField(max_length=100)

    def __str__(self):
        return self.name


class Medicine(models.Model):
    class Meta:
        db_table = 'medicines_list'

    DOSAGE_CHOICES = [
        ('tablet', 'Tablet'),
        ('syrup', 'Syrup'),
        ('capsule', 'Capsule'),
    ]

    CATEGORY_CHOICES = [
        ('analgesics', 'Analgesics'),
        ('antibiotics', 'Antibiotics'),
        ('antivirals', 'Antivirals'),
        ('antihypertensives', 'Antihypertensives'),
        ('antidiabetics', 'Antidiabetics'),
        ('gastrointestinal_medicines', 'Gastrointestinal Medicines'),
        ('antihistamines', 'Antihistamines'),
        ('cough_and_cold_medicines', 'Cough and Cold Medicines'),
        ('vitamins_and_supplements', 'Vitamins and Supplements'),
        ('cardiovascular_medicines', 'Cardiovascular Medicines'),
        ('anti_asthma_and_respiratory_medicines', 'Anti-asthma and Respiratory Medicines'),
        ('antimalarials', 'Antimalarials'),
        ('antiparasitics', 'Antiparasitics'),
    ]

    name = models.CharField(max_length=100)
    generic_name = models.CharField(max_length=100, blank=True)
    barcode = models.CharField(max_length=50, unique=True)
    category = models.CharField(max_length=100, choices=CATEGORY_CHOICES)
    dosage_form = models.CharField(max_length=50, choices=DOSAGE_CHOICES)
    supplier = models.ForeignKey('Supplier', on_delete=models.SET_NULL, null=True, blank=True)
    restock_quantity = models.PositiveIntegerField(default=0)
    price = models.DecimalField(max_digits=8, decimal_places=2)
    requires_prescription = models.BooleanField(default=False)
    image = models.ImageField(upload_to='medicine_images/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class Inventory(models.Model): 
    class Meta:
        db_table = 'inventory_tbl'
        unique_together = ('medicine', 'batch_num')

    medicine = models.ForeignKey('Medicine', on_delete=models.CASCADE, related_name='inventory_entries') 
    batch_num = models.CharField(max_length=100)
    exp_date = models.DateField()
    date_received = models.DateField(auto_now_add=True)
    quantity = models.PositiveIntegerField(default=0)
    is_promo = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.medicine.name} - Batch {self.batch_num}"


class TotalQuantity(models.Model):
    class Meta:
        db_table = 'total_quantity_tbl'

    medicine = models.ForeignKey('Medicine', on_delete=models.CASCADE, unique=True, related_name='total_quantity_entry')
    total_quantity = models.PositiveIntegerField(default=0)
    

    def __str__(self):
        return f"{self.medicine.name} - Total Qty: {self.total_quantity}"


# Model for Promotions
class Promo(models.Model):
    class Meta:
        db_table = 'promo_tbl'

    inventory_id = models.ForeignKey('Inventory', on_delete=models.CASCADE)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)

    def __str__(self):
        return f"Promo for {self.inventory_id.medicine.name}"


#================================8/31/25 changes
# Model for Inventory Logs
class InventoryLog(models.Model):
    ACTION_CHOICES = [
        ('Add', 'Add'),
        ('Sold', 'Sold'),
        ('Restock', 'Restock'),
        ('Return', 'Return'),
        ('Delete', 'Delete'),
        ('Update', 'Update'),
        ('Promo', 'Promo'),
    ]

    user = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True)
    # Corrected line below:
    medicine = models.ForeignKey('Medicine', on_delete=models.SET_NULL, null=True, blank=True)
    medicine_name_log = models.CharField(max_length=100, default='[Unknown]') # Add this new field to store the medicine's name
    action_type = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)
    description = models.TextField()
    

    class Meta:
        db_table = 'inventory_logs'
        ordering = ['-timestamp']

    def __str__(self):
        # You may need to update this to handle the case where medicine is null
        if self.medicine:
            return f"{self.user} - {self.action_type} - {self.medicine.name}"
        else:
            return f"{self.user} - {self.action_type} - [Medicine Deleted]"

#================================8/31/25 changes

        

# Models for In-store Sales and Orders
class InStoreOrder(models.Model):
    class Meta:
        db_table = 'in_store_orders_tbl'

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    staff = models.ForeignKey('Staff', on_delete=models.CASCADE)
    cashier = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, blank=True, related_name='approved_orders')
    date_created = models.DateTimeField(auto_now_add=True) #-------- Remove comment after dummy data is completed
    #date_created = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    is_pwd = models.BooleanField(default=False)
    total_amount_before_discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_amount_after_discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    
    

    def __str__(self):
        return f"In-Store Order #{self.id} by {self.staff.email}"


#--------------------09/14/2025--------------------------- fixing return medicine
class InStoreOrderItem(models.Model):
    class Meta:
        db_table = 'in_store_order_items_tbl'

    order = models.ForeignKey('InStoreOrder', on_delete=models.CASCADE, related_name='items')
    inventory_id = models.ForeignKey('Inventory', on_delete=models.SET_NULL, null=True)
    quantity_sold = models.PositiveIntegerField(default=1)
    free_quantity_given = models.PositiveIntegerField(default=0)
    price_at_sale = models.DecimalField(max_digits=8, decimal_places=2)
    # Add these two new fields
    medicine_name = models.CharField(max_length=255, null=True, blank=True)
    generic_name = models.CharField(max_length=255, null=True, blank=True)

    def __str__(self):
        return f"{self.inventory_id.medicine.name} - {self.quantity_sold} sold"






#Model for Employee Log
class EmployeeLog(models.Model):
    ACTION_CHOICES = [
        ('login', 'Login'),
        ('logout', 'Logout'),
    ]

    staff = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, related_name='logs')
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)


    class Meta:
        db_table = 'employee_logs'
        ordering = ['-timestamp']

    def __str__(self):
        staff_str = self.staff.email if self.staff else 'Unknown staff'
        return f"{staff_str} - {self.action} at {self.timestamp}"

# Model for Order Logs
class OrderLog(models.Model):
    ACTION_CHOICES = [
        ('initiate_sale', 'Initiate Sale (In-store)'),
        ('in_store_approve', 'Approve In-store Order'),
        ('in_store_reject', 'Reject In-store Order'),
        ('online_confirmed', 'Online Order Confirmed'),
        ('online_cancelled', 'Online Order Cancelled'),
        ('online_picked_up', 'Online Order Picked Up'),
    ]

    staff_user = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, blank=True, related_name='order_logs')
    in_store_order = models.ForeignKey('InStoreOrder', on_delete=models.SET_NULL, null=True, blank=True, related_name='logs')
    online_order = models.ForeignKey('OnlineOrder', on_delete=models.SET_NULL, null=True, blank=True, related_name='logs')
    action_type = models.CharField(max_length=20, choices=ACTION_CHOICES)
    description = models.TextField(blank=True, null=True)
    
    timestamp = models.DateTimeField(auto_now_add=True) #-------- Remove comment after dummy data is completed
    #timestamp = models.DateTimeField()
    class Meta:
        db_table = 'order_logs'
        ordering = ['-timestamp']

    def __str__(self):
        order_str = ""
        if self.in_store_order:
            order_str = f"In-store Order #{self.in_store_order.id}"
        elif self.online_order:
            order_str = f"Online Order #{self.online_order.id}"
        
        staff_str = self.staff_user.name if self.staff_user else 'System'
        return f"OrderLog - {self.action_type} for {order_str} by {staff_str}"
        
# =================== NEW MODELS FOR ONLINE ORDERS ===================
class OnlineOrder(models.Model):
    ORDER_STATUS = [
        ('pending', 'Pending'),
        ('ready_for_pickup', 'Ready for Pickup'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    ]
    customer = models.ForeignKey(Customer, on_delete=models.CASCADE)
    date_created = models.DateTimeField(auto_now_add=True) #-------- Remove comment after dummy data is completed
    #date_created = models.DateTimeField()
    status = models.CharField(max_length=20, choices=ORDER_STATUS, default='pending')
    is_pwd = models.BooleanField(default=False)
    total_amount_before_discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_amount_after_discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    pickup_schedule = models.DateTimeField(null=True, blank=True)
    date_fulfilled = models.DateTimeField(null=True, blank=True) #ADDED THIS FOR ONLINE SALES REPORT!
    
    class Meta:
        db_table = 'online_orders_tbl'

    def __str__(self):
        return f"Online Order {self.id} by {self.customer.name}"


#--------------------09/14/2025--------------------------- fixing return medicine
class OnlineOrderItem(models.Model):
    order = models.ForeignKey('OnlineOrder', on_delete=models.CASCADE, related_name='items')
    # The corrected line:
    inventory_id = models.ForeignKey('Inventory', on_delete=models.SET_NULL, null=True, blank=True)
    quantity_sold = models.PositiveIntegerField(default=1)
    free_quantity_given = models.PositiveIntegerField(default=0)
    price_at_sale = models.DecimalField(max_digits=8, decimal_places=2)
    # 💡 ADD THIS FIELD 💡
    medicine_name = models.CharField(max_length=100)
    generic_name = models.CharField(max_length=100, blank=True)
    class Meta:
        db_table = 'online_order_items_tbl'
        
    def __str__(self):
        if self.inventory_id:
            return f"{self.inventory_id.medicine.name} - {self.quantity_sold} sold"
        else:
            return f"Medicine Not Found - {self.quantity_sold} sold"


#============================================================================================================================
#model for instore sales tranaction
# class InStoreOrderApproval(models.Model):
#     class Meta:
#         db_table = 'in_store_order_approvals_tbl'
        
#     order = models.OneToOneField('InStoreOrder', on_delete=models.CASCADE, related_name='approval')
#     cashier = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, related_name='approved_in_store_orders')
#     approval_date = models.DateTimeField(auto_now_add=True)

#     def __str__(self):
#         return f"Order #{self.order.id} approved by {self.cashier.name if self.cashier else 'Unknown'}"
    
#--presc
# Models for Prescription
#============================================================================================================================

class Prescription(models.Model):
    class Meta:
        db_table = 'prescriptions_tbl'

    # Changed from OneToOneField to ForeignKey and added a new one for online orders
    in_store_order = models.ForeignKey('InStoreOrder', on_delete=models.SET_NULL, related_name='prescription_required', null=True, blank=True)
    online_order = models.ForeignKey('OnlineOrder', on_delete=models.SET_NULL, related_name='prescription_required', null=True, blank=True)
    
    # The prescription_image field is removed here
    status = models.CharField(max_length=20, default='pending')
    date_uploaded = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        if self.in_store_order:
            return f"Prescription for In-store Order #{self.in_store_order.id}"
        elif self.online_order:
            return f"Prescription for Online Order #{self.online_order.id}"
        return f"Prescription for an unknown order"

# New model to handle multiple prescription images
class PrescriptionImage(models.Model):
    class Meta:
        db_table = 'prescription_images_tbl'

    prescription = models.ForeignKey('Prescription', on_delete=models.CASCADE, related_name='images')
    image = models.ImageField(upload_to='prescriptions/')
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image for Prescription #{self.prescription.id}"
    

#-----PUSH NOTIFS
class CustomerFCMToken(models.Model):
    customer = models.ForeignKey('Customer', on_delete=models.CASCADE, related_name='fcm_tokens')
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.customer.email} - {self.token}"


#-----DEMAND FORECASTING
#-----DEMAND FORECASTING
class ForecastReport(models.Model):
    class Meta:
        db_table = 'demand_forecast_report_tbl'
        unique_together = ('week_start_date',)

    week_start_date = models.DateField()
    date_generated = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Forecast Report for the week of {self.week_start_date}"












#----------9/23/25
# This is the child table for your two-table approach
class ForecastItem(models.Model):
    class Meta:
        db_table = 'demand_forecast_items_tbl'

    forecast_report = models.ForeignKey(
        'ForecastReport',
        on_delete=models.CASCADE,
        related_name='items'
    )
    # The foreign key is now nullable to preserve data
    medicine = models.ForeignKey('Medicine', on_delete=models.SET_NULL, null=True, blank=True)
    
    # Snapshot fields to retain the medicine's information
    medicine_name = models.CharField(max_length=100, blank=True, null=True)
    generic_name = models.CharField(max_length=100, blank=True, null=True)
    
    forecasted_quantity = models.PositiveIntegerField()
    current_stock = models.PositiveIntegerField(default=0)
    restock_amount = models.IntegerField(default=0)
    rank = models.PositiveIntegerField()

    def __str__(self):
        # Use the snapshot name if the medicine link is null
        if self.medicine_name:
            return f"Rank {self.rank}: {self.medicine_name} - {self.forecasted_quantity} units"
        return f"Rank {self.rank}: [Medicine Deleted] - {self.forecasted_quantity} units"
#----------9/23/25















    
    
    
    
#-----EXPIRY NOTIFICATION
class StaffFCMToken(models.Model):
    """Model to store FCM tokens for staff members."""
    staff = models.ForeignKey('Staff', on_delete=models.CASCADE, related_name='fcm_tokens')
    token = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.staff.name} - {self.token}"
    
#--------------------09/14/2025--------------------------- fixing return medicine
# Returned Medicine
class ReturnedMedicine(models.Model):
    class Meta:
        db_table = 'returned_medicines_tbl'

    medicine = models.ForeignKey(Medicine, on_delete=models.CASCADE)
    online_order_item = models.ForeignKey('OnlineOrderItem', on_delete=models.SET_NULL, null=True, blank=True)
    batch_num = models.CharField(max_length=100)
    exp_date = models.DateField()
    quantity = models.IntegerField(default=0)
    returned_at = models.DateTimeField(auto_now_add=True)
    returned_by = models.ForeignKey(Staff, on_delete=models.SET_NULL, null=True)

    def __str__(self):
        return f"Returned: {self.medicine.name} ({self.batch_num})"