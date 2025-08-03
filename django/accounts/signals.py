from django.db.models.signals import pre_save, post_save, post_delete
from django.dispatch import receiver
from .models import Inventory, TotalQuantity
from django.db import models
from django.utils.timezone import now

# Cache the old quantity
@receiver(pre_save, sender=Inventory)
def cache_old_quantity(sender, instance, **kwargs):
    if instance.pk:
        try:
            old_instance = Inventory.objects.get(pk=instance.pk)
            instance._old_quantity = old_instance.quantity
        except Inventory.DoesNotExist:
            instance._old_quantity = None
    else:
        instance._old_quantity = None

# Update on save
@receiver(post_save, sender=Inventory)
def update_total_quantity_on_save(sender, instance, created, **kwargs):
    medicine = instance.medicine

    # Only update if quantity changed or created
    if created or getattr(instance, "_old_quantity", None) != instance.quantity:
        total_qty = Inventory.objects.filter(
            medicine=medicine,
            exp_date__gt=now()
        ).aggregate(total=models.Sum('quantity'))['total'] or 0

        TotalQuantity.objects.update_or_create(
            medicine=medicine,
            defaults={'total_quantity': total_qty}
        )

# Update on delete
@receiver(post_delete, sender=Inventory)
def update_total_quantity_on_delete(sender, instance, **kwargs):
    medicine = instance.medicine
    total_qty = Inventory.objects.filter(
        medicine=medicine,
        exp_date__gt=now()
    ).aggregate(total=models.Sum('quantity'))['total'] or 0

    TotalQuantity.objects.update_or_create(
        medicine=medicine,
        defaults={'total_quantity': total_qty}
    )
