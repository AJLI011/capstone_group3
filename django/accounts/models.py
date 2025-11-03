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


#--------10/1/25
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
    
    # Existing Foreign Key
    supplier = models.ForeignKey('Supplier', on_delete=models.SET_NULL, null=True, blank=True)
    
    # Snapshot for supplier name (already implemented)
    supplier_name = models.CharField(
        max_length=255, 
        null=True, 
        blank=True,
        default='[Supplier Deleted]' # Fallback for safety and readability
    )
    
    # 
    supplier_contact_num = models.CharField(
        max_length=20, # Use a max length appropriate for contact numbers
        null=True, 
        blank=True,
        default='N/A' # Fallback for safety and display
    )
    
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


#================================09/26/25 ELTON=================================================================================
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
    
    # --- START OF NEW FIELDS ---
    staff_name = models.CharField(max_length=100, default='[Deleted Staff]') # NEW FIELD
    staff_role = models.CharField(max_length=20, default='[Deleted Role]') # NEW FIELD
    # --- END OF NEW FIELDS ---
    
    medicine = models.ForeignKey('Medicine', on_delete=models.SET_NULL, null=True, blank=True)
    medicine_name_log = models.CharField(max_length=100, default='[Unknown]')
    action_type = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)
    description = models.TextField()
    

    class Meta:
        db_table = 'inventory_logs'
        ordering = ['-timestamp']

    def __str__(self):
        # Update __str__ to use the snapshot for robustness
        staff_display = self.staff_name_snapshot if self.user is None else str(self.user)
        
        if self.medicine:
            return f"{staff_display} - {self.action_type} - {self.medicine.name}"
        else:
            return f"{staff_display} - {self.action_type} - [Medicine Deleted]"

#================================09/26/25 ELTON=================================================================================

        



#--------------------------10-2-25----------------------------------------
# Models for In-store Sales and Orders
class InStoreOrder(models.Model):
    class Meta:
        db_table = 'in_store_orders_tbl'

    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]
    
    # --- NEW SNAPSHOT FIELDS ---
    staff_name = models.CharField(
        max_length=255, 
        null=True,
        blank=True,
        default= "[STAFF NAME]",
    )
    cashier_name = models.CharField(
        max_length=255, 
        null=True,
        blank=True,
        default= "[CASHIER NAME]",
    )
    staff = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True)
    cashier = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, blank=True, related_name='approved_orders')
    date_created = models.DateTimeField(auto_now_add=True) #-------- Remove comment after dummy data is completed
    #date_created = models.DateTimeField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    is_pwd = models.BooleanField(default=False)
    total_amount_before_discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    total_amount_after_discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    #--9/29/25-- ADDED
    has_prescription_required_item = models.BooleanField(default=False)
    

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
# models.py

class EmployeeLog(models.Model):
    ACTION_CHOICES = [
        ('login', 'Login'),
        ('logout', 'Logout'),
    ]

    staff = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, related_name='logs')
    action = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)

    #Snapshot Fields 
    staff_name = models.CharField(
        max_length=255, 
        null=True, 
        blank=True, 
        default='[Deleted Staff]'
    )
    staff_role = models.CharField(
        max_length=50, 
        null=True, 
        blank=True, 
        default='[Deleted Role]'
    )
    # ----------------------------------------

    class Meta:
        db_table = 'employee_logs'
        ordering = ['-timestamp']

    def __str__(self):
        # Update the __str__ to use the snapshot name if staff is null
        staff_display = self.staff_name if not self.staff else self.staff.email
        return f"{staff_display} - {self.action} at {self.timestamp}"

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
#---------------10-5-25----------------------------------------------
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
    date_fulfilled = models.DateTimeField(null=True, blank=True) #ADDED THIS FOR ONLINE SALES REPORT
    
    # Foreign Keys (Used SET_NULL so the record doesn't prevent deletion,
    # and rely on the snapshot fields to keep the name).
    initiated_by = models.ForeignKey(
        'Staff', 
        on_delete=models.SET_NULL, # Allows staff member to be deleted
        related_name='initiated_online_orders', 
        null=True, 
        blank=True
    )
    approved_by = models.ForeignKey(
        'Staff', 
        on_delete=models.SET_NULL, # Allows staff member to be deleted
        related_name='approved_online_orders', 
        null=True, 
        blank=True
    )
    
    # Snapshot Fields (to preserve the name after staff deletion)
    initiated_by_name = models.CharField(
        max_length=100, 
        null=True, 
        blank=True,
        default= "[STAFF NAME]",
    )
    approved_by_name = models.CharField(
        max_length=100, 
        null=True, 
        blank=True,
        default= "[CASHIER NAME]",
    )

    # Role Snapshot Fields
    initiated_by_role_snapshot = models.CharField(max_length=50, null=True, blank=True)
    approved_by_role_snapshot = models.CharField(max_length=50, null=True, blank=True)
    
    # --- END OF NEW ADDED LINES ---
    
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

    # NEW FIELD ADDED FOR OVERSTOCKING PREVENTION
    reorder_level = models.PositiveIntegerField(default=0)

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
    
#--------------------10/10/2025--------------------------- fixing return medicine - aaron
# --- ReturnTransaction Model (With Staff Snapshot Logic) ---
class ReturnTransaction(models.Model):
    class Meta:
        db_table = 'return_transactions_tbl'
        ordering = ['-returned_at'] 

    STATUS_CHOICES = [
        ('PENDING', 'Pending Verification'),
        ('VERIFIED', 'Verified'),
        ('REJECTED', 'Verification Rejected'),
    ]

    staff = models.ForeignKey('Staff', on_delete=models.SET_NULL, null=True, related_name='return_transactions')
    # Snapshot field for the staff's name
    staff_name_snapshot = models.CharField(
        max_length=100, 
        blank=True, 
        null=True,
        # This holds the staff name in case the original staff user is deleted
    )
    
    returned_at = models.DateTimeField(auto_now_add=True)
    verification_status = models.CharField(
        max_length=20, 
        choices=STATUS_CHOICES,
        default='PENDING'
    )
    notes = models.TextField(blank=True, null=True)

    def save(self, *args, **kwargs):
        """Populate the staff name snapshot before saving."""
        # Only set the snapshot if the FK is present AND the snapshot hasn't been set yet
        if self.staff and not self.staff_name_snapshot:
            # Assuming Staff model has a 'name' attribute
            self.staff_name_snapshot = self.staff.name 
            
        super().save(*args, **kwargs)

    def __str__(self):
        # Use the snapshot if the staff FK is null
        staff_display = self.staff_name_snapshot 
        if self.staff:
            staff_display = self.staff.name # Prioritize the live FK data if available
        elif not staff_display:
            staff_display = 'N/A' # Fallback if both are missing
            
        return f"Return Txn {self.pk} by {staff_display}"

# --- ReturnedMedicine Model (With Medicine Name Retention and Snapshot Logic) ---
class ReturnedMedicine(models.Model):
    class Meta:
        db_table = 'returned_medicines_tbl'

    return_transaction = models.ForeignKey(
        'ReturnTransaction', 
        on_delete=models.CASCADE, 
        related_name='returned_items',
        null=True,  
        blank=True  
    )
    
    # CRITICAL FIX: Changed on_delete to SET_NULL to retain the historical 
    # record even if the Medicine object is deleted.
    medicine = models.ForeignKey(
        'Medicine', 
        on_delete=models.SET_NULL, 
        null=True # Required for SET_NULL
    )
    
    # Snapshot field for the medicine's name
    medicine_name_snapshot = models.CharField(max_length=255, blank=True, null=True) 
    
    # NEW SNAPSHOT FIELDS ADDED:
    generic_name_snapshot = models.CharField(max_length=255, blank=True, null=True) # Captures Medicine.generic_name
    supplier_name_snapshot = models.CharField(max_length=255, blank=True, null=True) # Captures Medicine.supplier.name
    
    # Existing fields that hold core data
    online_order_item = models.ForeignKey('OnlineOrderItem', on_delete=models.SET_NULL, null=True, blank=True)
    batch_num = models.CharField(max_length=100)
    exp_date = models.DateField()
    quantity = models.IntegerField(default=0)
    returned_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        """Populate all relevant snapshots before saving."""
        if self.medicine:
            
            # 1. Snapshot the Medicine's own fields
            if not self.medicine_name_snapshot:
                self.medicine_name_snapshot = self.medicine.name
            if not self.generic_name_snapshot:
                # Assuming Medicine model has a 'generic_name' attribute
                self.generic_name_snapshot = self.medicine.generic_name
            
            # 2. Snapshot the Supplier's name (traversing the FK)
            if self.medicine.supplier and not self.supplier_name_snapshot:
                # Assuming Supplier model has a 'name' attribute
                self.supplier_name_snapshot = self.medicine.supplier.name
            elif not self.supplier_name_snapshot:
                 # Fallback if Medicine exists but its Supplier FK is missing/null
                 self.supplier_name_snapshot = '[Supplier N/A]'

        # Safety: If the medicine FK is somehow missing at save time, set a fallback
        elif self.medicine_name_snapshot is None:
             self.medicine_name_snapshot = '[Medicine Deleted]'
             self.generic_name_snapshot = '[N/A]'
             self.supplier_name_snapshot = '[N/A]'
             
        super().save(*args, **kwargs)

    def __str__(self):
        tx_pk = self.return_transaction.pk if self.return_transaction else 'N/A'
        
        # Prioritize live FK data, otherwise use the snapshot
        medicine_display = self.medicine_name_snapshot
        if self.medicine:
            medicine_display = self.medicine.name 
        elif not medicine_display:
            medicine_display = 'N/A' 
            
        return f"Item: {medicine_display} (Txn: {tx_pk})"
    

# --- ReturnVerificationImage Model (No changes needed) ---
class ReturnVerificationImage(models.Model):
    class Meta:
        db_table = 'return_verification_images_tbl'

    return_transaction = models.ForeignKey(
        ReturnTransaction, 
        on_delete=models.CASCADE, 
        related_name='verification_images'
    )
    
    image = models.ImageField(upload_to='return_verification_photos/%Y/%m/%d/')
    uploaded_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Image for Txn {self.return_transaction.pk}"

#------10/31/25
class PurchaseRequest(models.Model):

    class Meta:
        db_table = 'purchase_request_tbl'

    # The manager FK is removed. 'manager_name' will be set manually (or hardcoded) for testing.
    manager_name = models.CharField(max_length=100, default='System Test User') # Optional: Set a default for easy creation
    # Submission timestamp
    request_date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"PR-{self.id} by {self.manager_name} on {self.request_date.strftime('%Y-%m-%d')}"


class PurchaseRequestItem(models.Model):
    
    class Meta:
        db_table = 'purchase_request_item_tbl'

    # MANDATORY FKs
    purchase_request = models.ForeignKey(PurchaseRequest, on_delete=models.CASCADE, related_name='items')
    # Use PROTECT to prevent accidental deletion of a medicine with active PRs
    medicine = models.ForeignKey(Medicine, on_delete=models.PROTECT, null=True, blank=True) 
    
    # CORE TRANSACTIONAL QUANTITIES
    restock_amount = models.IntegerField() # Manager's final order (from Forecasted Tab)
    suggested_amount = models.IntegerField() # System's suggestion (from Low Stock Tab)
    
    # CRITICAL SNAPSHOT FIELD (for auditability if medicine is deleted or renamed)
    medicine_name_snapshot = models.CharField(max_length=100) 
    
    def __str__(self):
        return f"{self.restock_amount} of {self.medicine_name_snapshot} for PR-{self.purchase_request.id}"

    # Auto-sets the medicine_name_snapshot on save if the medicine link exists
    def save(self, *args, **kwargs):
        if self.medicine and not self.medicine_name_snapshot:
            self.medicine_name_snapshot = self.medicine.name
        super().save(*args, **kwargs)