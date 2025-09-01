# your_app_name/management/commands/notify_expired.py

from django.core.management.base import BaseCommand
from datetime import date
from your_app_name.models import Inventory, Staff
from your_app_name.sms_utility import send_sms

class Command(BaseCommand):
    help = 'Checks for expired medicines and sends an SMS notification to the manager.'

    def handle(self, *args, **options):
        self.stdout.write("Checking for expired medicines...")
        
        try:
            manager_profile = Staff.objects.get(role='manager')
            manager_number = manager_profile.contact_num
        except Staff.DoesNotExist:
            self.stdout.write(self.style.ERROR('Staff profile for manager not found.'))
            return

        today = date.today()
        expired_items = Inventory.objects.filter(exp_date__lte=today, quantity__gt=0).select_related('medicine')

        if expired_items.exists():
            message_lines = ["⚠️ EXPIRATION ALERT ⚠️"]
            message_lines.append("The following medicines have expired:")
            
            for item in expired_items:
                message_lines.append(f"- {item.medicine.name} (Batch: {item.batch_number}, Qty: {item.quantity})")
                
            message = "\n".join(message_lines)
            
            success, response_data = send_sms(manager_number, message)
            
            if success:
                self.stdout.write(self.style.SUCCESS('Manager notified of expired stocks via SMS.'))
            else:
                self.stdout.write(self.style.ERROR(f"Failed to send SMS notification: {response_data.get('message', 'Unknown error')}"))

        else:
            self.stdout.write('No expired medicines found. No SMS sent.')
            
        self.stdout.write("Finished checking.")