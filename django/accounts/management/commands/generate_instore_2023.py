from django.core.management.base import BaseCommand
import random
from faker import Faker
from datetime import datetime, timedelta
import pytz 
from accounts.models import Supplier, Medicine, Inventory, InStoreOrder, InStoreOrderItem, Customer, Staff

class Command(BaseCommand):
    help = 'Generates dummy in-store order data for the year 2023.'
    
    def create_dummy_medicines(self):
        self.stdout.write(self.style.NOTICE('Creating dummy suppliers and medicines...'))
        
        supplier_names = ['PharmaCorp', 'MediSupply', 'Global Drugs Inc.']
        suppliers = []
        for name in supplier_names:
            supplier, created = Supplier.objects.get_or_create(name=name, defaults={'contact': Faker().phone_number()})
            suppliers.append(supplier)
            if created:
                self.stdout.write(f'Created supplier: {name}')

        categories = [choice[0] for choice in Medicine.CATEGORY_CHOICES]
        
        for i in range(50):
            name = Faker().unique.word().capitalize() + ' Medicine'
            generic_name = Faker().word() + ' Generic'
            barcode = Faker().unique.ean13()
            price = round(random.uniform(50, 500), 2)
            category = random.choice(categories)
            
            dosage_form = random.choice([choice[0] for choice in Medicine.DOSAGE_CHOICES])
            
            supplier = random.choice(suppliers)

            medicine, created = Medicine.objects.get_or_create(
                barcode=barcode,
                defaults={
                    'name': name,
                    'generic_name': generic_name,
                    'category': category,
                    'dosage_form': dosage_form,
                    'supplier': supplier,
                    'restock_quantity': random.randint(50, 200),
                    'price': price,
                    'requires_prescription': random.choice([True, False])
                }
            )
            if created:
                self.stdout.write(f'Created medicine: {medicine.name}')

        self.stdout.write(self.style.SUCCESS('Finished creating dummy suppliers and medicines.'))
        
    def create_dummy_inventory(self):
        self.stdout.write(self.style.NOTICE('Creating dummy inventory...'))
        
        medicines = Medicine.objects.all()
        if not medicines.exists():
            self.stdout.write(self.style.WARNING('No medicines found. Please run create_dummy_medicines first.'))
            return

        for medicine in medicines:
            batch_num = Faker().unique.isbn13()
            exp_date = Faker().date_between(start_date='+1y', end_date='+3y')
            quantity = random.randint(100, 500)
            
            Inventory.objects.create(
                medicine=medicine,
                batch_num=batch_num,
                exp_date=exp_date,
                quantity=quantity,
                is_promo=random.choice([True, False])
            )
        
        self.stdout.write(self.style.SUCCESS('Finished creating dummy inventory.'))
    
    def create_dummy_users(self):
        self.stdout.write(self.style.NOTICE('Creating dummy staff...'))
        
        staff_roles = ['cashier', 'staff']
        for role in staff_roles:
            email = f'{role}@example.com'
            Staff.objects.get_or_create(
                email=email,
                defaults={
                    'password': 'testpassword123',
                    'name': Faker().name(),
                    'role': role,
                    'contact_num': Faker().msisdn()[:20]
                }
            )
        
        self.stdout.write(self.style.SUCCESS('Finished creating dummy staff.'))
    
    def create_in_store_sales(self):
        self.stdout.write(self.style.NOTICE('Creating a large set of dummy in-store sales records for 2023...'))
        self.stdout.write(self.style.WARNING('This process will take a significant amount of time and resources. Please be patient.'))
        
        staff_user = Staff.objects.get(role='staff')
        inventory_items = Inventory.objects.all()
        
        if not staff_user or not inventory_items.exists():
            self.stdout.write(self.style.WARNING('Prerequisite data (staff, inventory) not found. Please run previous functions first.'))
            return

        # Define the date range for 2023
        start_date = datetime(2023, 1, 1)
        end_date = datetime(2023, 12, 31)
        total_days = (end_date - start_date).days
        
        seasonality_map = {
            'cough_and_cold_medicines': {'wet_season': 2.0, 'dry_season': 0.8},
            'antihistamines': {'dry_season': 1.5, 'wet_season': 0.8},
            'vitamins_and_supplements': {'wet_season': 1.5, 'dry_season': 1.0},
            'gastrointestinal_medicines': {'dry_season': 1.3, 'wet_season': 1.0},
        }

        time_of_day_map = {
            'morning': (9, 11, 1.2),
            'afternoon': (12, 17, 1.5),
            'evening': (18, 21, 1.0),
        }
        
        # Sales range for a small independent pharmacy
        num_orders_per_day_range = (50, 70)

        for day_offset in range(total_days + 1):
            current_date = start_date + timedelta(days=day_offset)
            current_month = current_date.month

            season = 'dry_season'
            if current_month in [6, 7, 8, 9, 10, 11]:
                season = 'wet_season'
            
            num_orders_per_day = random.randint(*num_orders_per_day_range)

            for _ in range(num_orders_per_day):
                # Randomize order time between 9 AM and 9 PM
                random_hour = random.randint(9, 21)
                random_minute = random.randint(0, 59)
                order_time = current_date.replace(hour=random_hour, minute=random_minute, second=random.randint(0, 59))
                
                sales_multiplier = 1.0
                for time_period, (start_h, end_h, multiplier) in time_of_day_map.items():
                    if start_h <= random_hour <= end_h:
                        sales_multiplier = multiplier
                        break

                order = InStoreOrder.objects.create(
                    staff=staff_user,
                    date_created=order_time,
                    status='approved',
                    total_amount_before_discount=0,
                    total_amount_after_discount=0
                )
                
                num_items_in_order = random.randint(1, 3)
                total_before = 0
                total_after = 0
                
                for _ in range(num_items_in_order):
                    selected_item = random.choice(inventory_items)
                    medicine_category = selected_item.medicine.category
                    
                    item_multiplier = seasonality_map.get(medicine_category, {}).get(season, 1.0)
                    
                    base_quantity = random.randint(1, 5)
                    quantity_sold = int(base_quantity * sales_multiplier * item_multiplier)
                    
                    if quantity_sold < 1:
                        quantity_sold = 1

                    price_at_sale = selected_item.medicine.price
                    
                    InStoreOrderItem.objects.create(
                        order=order,
                        inventory_id=selected_item,
                        quantity_sold=quantity_sold,
                        price_at_sale=price_at_sale
                    )
                    
                    total_before += price_at_sale * quantity_sold
                    total_after = total_before
                
                order.total_amount_before_discount = total_before
                order.total_amount_after_discount = total_after
                order.save()
            
            if day_offset % 30 == 0:
                self.stdout.write(f'Progress: {day_offset}/{total_days} days generated for 2023.')

        self.stdout.write(self.style.SUCCESS('Finished creating dummy in-store sales records for 2023.'))

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting dummy data generation for in-store 2023...'))
        
        self.create_dummy_medicines()
        self.create_dummy_inventory()
        self.create_dummy_users()
        self.create_in_store_sales()
        
        self.stdout.write(self.style.SUCCESS('In-store data generation for 2023 completed successfully!'))