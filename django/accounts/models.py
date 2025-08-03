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

    medicine = models.OneToOneField('Medicine', on_delete=models.CASCADE, primary_key=True)
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
    medicine = models.ForeignKey('Medicine', on_delete=models.CASCADE)
    action_type = models.CharField(max_length=20, choices=ACTION_CHOICES)
    timestamp = models.DateTimeField(auto_now_add=True)
    description = models.TextField()

    class Meta:
        db_table = 'inventory_logs'
        ordering = ['-timestamp']

    def __str__(self):
        return f"{self.user} - {self.action_type} - {self.medicine.name}"

