from django.core.management.base import BaseCommand
from django.utils.timezone import now
from accounts.models import Inventory, TotalQuantity  # Use correct app name here
from django.db.models import Sum

class Command(BaseCommand):
    help = 'Update TotalQuantity by recalculating non-expired inventories'

    def handle(self, *args, **kwargs):
        medicines = Inventory.objects.values_list('medicine', flat=True).distinct()
        for medicine_id in medicines:
            total_qty = Inventory.objects.filter(
                medicine_id=medicine_id,
                exp_date__gt=now()
            ).aggregate(total=Sum('quantity'))['total'] or 0

            TotalQuantity.objects.update_or_create(
                medicine_id=medicine_id,
                defaults={'total_quantity': total_qty}
            )

        self.stdout.write(self.style.SUCCESS("✅ Total quantities updated successfully."))
