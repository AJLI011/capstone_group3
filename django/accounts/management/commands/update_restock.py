from django.core.management.base import BaseCommand
from accounts.models import Medicine

class Command(BaseCommand):
    help = 'Updates the restock quantity for all medicines to a default value.'

    def handle(self, *args, **kwargs):
        try:
            # Update all medicine objects in the database
            updated_count = Medicine.objects.all().update(restock_quantity=20)
            self.stdout.write(self.style.SUCCESS(f'Successfully updated restock quantity for {updated_count} medicines to 20.'))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'An error occurred: {e}'))