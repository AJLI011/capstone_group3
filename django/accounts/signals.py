from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Medicine, Inventory, TotalQuantity
from django.db import models

# ✅ Update total_quantity whenever Inventory is created, updated, or deleted
@receiver([post_save, post_delete], sender=Inventory)
def update_total_quantity(sender, instance, **kwargs):
    medicine = instance.medicine
    total_qty = Inventory.objects.filter(medicine=medicine).aggregate(
        total=models.Sum('quantity'))['total'] or 0

    TotalQuantity.objects.update_or_create(
        medicine=medicine,
        defaults={'total_quantity': total_qty}
    )

# ✅ Optional: Ensure a new TotalQuantity record is created with 0 total for new medicines
@receiver(post_save, sender=Medicine)
def create_total_quantity_entry(sender, instance, created, **kwargs):
    if created:
        TotalQuantity.objects.get_or_create(
            medicine=instance,
            defaults={'total_quantity': 0}
        )
