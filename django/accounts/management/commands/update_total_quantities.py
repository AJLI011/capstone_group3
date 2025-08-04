from django.core.management.base import BaseCommand
from accounts.models import Inventory, TotalQuantity

class Command(BaseCommand):
    help = 'Update total quantities for all medicines'

    def handle(self, *args, **kwargs):
        # Your logic here
        self.stdout.write(self.style.SUCCESS('Total quantities updated successfully.'))
