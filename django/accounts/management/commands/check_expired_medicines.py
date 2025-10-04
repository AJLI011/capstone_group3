# In your `your_app/management/commands/` directory, create this new file
# make sure to change 'your_app' to the name of your app
import datetime
from django.core.management.base import BaseCommand
from django.db.models import F
from accounts.models import Inventory, Staff, StaffFCMToken
from backend.firebase import send_fcm_notification

class Command(BaseCommand):
    help = 'Checks for expired medicines and sends a push notification to managers.'

    def handle(self, *args, **options):
        # 1. Find all expired inventory items
        today = datetime.date.today()
        expired_items = Inventory.objects.filter(exp_date__lte=today)

        if not expired_items.exists():
            self.stdout.write(self.style.SUCCESS('No expired medicines found.'))
            return

        # 2. Get the tokens for all manager accounts
        manager_tokens = StaffFCMToken.objects.filter(staff__role='manager').values_list('token', flat=True)

        if not manager_tokens:
            self.stdout.write(self.style.WARNING('No manager FCM tokens found. No notifications will be sent.'))
            return
        
        # 3. Prepare the notification
        total_expired = expired_items.count()
        title = f"🔔 {total_expired} Expired Medicine(s)"
        body = f"Please check the inventory. There are {total_expired} item(s) that have expired as of today."

        # 4. Send the notification to each manager
        for token in manager_tokens:
            send_fcm_notification(
                token=token,
                title=title,
                body=body
            )
            self.stdout.write(self.style.SUCCESS(f"✅ Notification sent to manager token: {token}"))

        self.stdout.write(self.style.SUCCESS(f"Task completed. {total_expired} expired item(s) found."))