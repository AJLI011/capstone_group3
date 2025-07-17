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
