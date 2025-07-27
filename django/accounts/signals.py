from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Inventory, TotalQuantity, models

@receiver([post_save, post_delete], sender=Inventory)
def update_total_quantity(sender, instance, **kwargs):
    medicine = instance.medicine

    # Recalculate total quantity for this medicine across all its batches
    total_qty = Inventory.objects.filter(medicine=medicine).aggregate(total=models.Sum('quantity'))['total'] or 0

    # Update or create the TotalQuantity entry
    TotalQuantity.objects.update_or_create(
        medicine=medicine,
        defaults={'total_quantity': total_qty}
    )
