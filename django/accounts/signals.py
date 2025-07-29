from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Medicine, Inventory, TotalQuantity
from django.db import models
from datetime import date

# 1. When a new Medicine is created, create an Inventory row for it
@receiver(post_save, sender=Medicine)
def create_inventory_entry(sender, instance, created, **kwargs):
    if created:
        Inventory.objects.get_or_create(
            medicine=instance,
            defaults={
                'batch_num': 'N/A',
                'exp_date': date(2099, 12, 31),  # Dummy far-future expiry
                'quantity': instance.restock_quantity
            }
        )

# 2. When an Inventory is added or changed, update TotalQuantity accordingly
@receiver([post_save, post_delete], sender=Inventory)
def update_total_quantity(sender, instance, **kwargs):
    medicine = instance.medicine
    total_qty = Inventory.objects.filter(medicine=medicine).aggregate(
        total=models.Sum('quantity'))['total'] or 0

    TotalQuantity.objects.update_or_create(
        medicine=medicine,
        defaults={'total_quantity': total_qty}
    )
