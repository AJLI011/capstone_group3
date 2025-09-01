from django.core.management.base import BaseCommand
from django.utils import timezone
from accounts.models import Inventory, Staff  # Import your Inventory and Staff models
from accounts.sms_utility import send_sms  # Import your send_sms function
import logging

# Set up logging
logger = logging.getLogger(__name__)

class Command(BaseCommand):
    help = 'Checks for expired medicines and sends an SMS notification to the pharmacy manager.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE('Starting check for expired medicines...'))

        try:
            # Find the manager's phone number
            try:
                manager_profile = Staff.objects.get(role='manager')
                manager_number = manager_profile.contact_num
            except Staff.DoesNotExist:
                self.stdout.write(self.style.ERROR('Staff profile for manager not found. Cannot send SMS.'))
                logger.error('Staff profile for manager not found.')
                return

            today = timezone.localdate()  # Use timezone.localdate() to get today's date
            
            # Find expired medicines
            expired_items = Inventory.objects.filter(exp_date__lte=today, quantity__gt=0)
            
            if expired_items.exists():
                self.stdout.write(self.style.WARNING(f'Found {expired_items.count()} expired medicine items.'))
                
                # Prepare the SMS message
                message_lines = ["EXPIRATION ALERT"]
                message_lines.append("The following medicines have expired:")
                
                for item in expired_items:
                    message_lines.append(f"  * {item.medicine.name} (Batch: {item.batch_num}, Qty: {item.quantity})")
                    # You may want to update the inventory to mark it as expired here
                    # For example: item.is_expired = True; item.save()
                    
                message = "\n".join(message_lines)
                
                # Send the SMS notification using your existing utility function
                success, response_data = send_sms(manager_number, message)
                
                if success:
                    self.stdout.write(self.style.SUCCESS('Successfully sent SMS notification to manager.'))
                    logger.info('Successfully sent SMS notification for expired medicines.')
                else:
                    self.stdout.write(self.style.ERROR(f'Failed to send SMS notification. API response: {response_data}'))
                    logger.error(f'Failed to send SMS notification: {response_data}')
            else:
                self.stdout.write(self.style.SUCCESS('No expired medicines found. No SMS sent.'))
        
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'An error occurred: {e}'))
            logger.error(f'An error occurred while checking for expired medicines: {e}')