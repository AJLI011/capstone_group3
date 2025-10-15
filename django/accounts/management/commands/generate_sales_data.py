import os
import django
import random
import argparse # Import argparse for dynamic date arguments
from faker import Faker
from datetime import datetime, timedelta, date, time
import pytz
from django.conf import settings
from django.db import transaction
from django.core.management.base import BaseCommand, CommandError # Use CommandError for argument validation
from django.db.models import Q # Import Q objects for conditional filtering

# Assuming these models are correctly defined in your 'accounts' app
from accounts.models import (
    Supplier, Medicine, Inventory, InStoreOrder, InStoreOrderItem, 
    OnlineOrder, OnlineOrderItem, Customer, Staff, OrderLog
)

# Helper function to get a random choice from a field's choices tuple
def get_random_choice(choices):
    """Returns a random key from a Django choices tuple."""
    return random.choice([choice[0] for choice in choices])

# Define a shared mapping for all medicine data
MEDICINE_DATA = {
    'Biogesic': 'Paracetamol', 'Alaxan': 'Ibuprofen + Paracetamol', 
    'Decolgen': 'Paracetamol + Phenylephrine + Chlorphenamine Maleate',
    'Neozep': 'Phenylephrine + Chlorphenamine Maleate + Paracetamol', 
    'Bioflu': 'Phenylephrine + Chlorphenamine Maleate + Paracetamol + Phenylpropanolamine',
    'Amoxicillin': 'Amoxicillin', 'Mefenamic Acid': 'Mefenamic Acid', 
    'Paracetamol': 'Paracetamol', 'Cetirizine': 'Cetirizine', 
    'Loperamide': 'Loperamide', 'Ibuprofen': 'Ibuprofen', 
    'Cefalexin': 'Cefalexin', 'Metformin': 'Metformin', 
    'Omeprazole': 'Omeprazole', 'Loratadine': 'Loratadine', 
    'Ventolin': 'Salbutamol', 'Salbutamol': 'Salbutamol', 
    'Aspirin': 'Aspirin', 'Diatabs': 'Loperamide Hydrochloride',
    'Kremil-S': 'Aluminum Hydroxide + Magnesium Hydroxide + Simeticone', 
    'Ascof': 'Vitex negundo L. (Lagundi)', 'Solmux': 'Carbocisteine',
    'Tuseran Forte': 'Dextromethorphan + Phenylpropanolamine + Paracetamol', 
    'Robitussin': 'Guaifenesin', 'Mucosolvan': 'Ambroxol',
    'Advil': 'Ibuprofen', 'Voltaren': 'Diclofenac', 
    'Plavix': 'Clopidogrel', 'Lipitor': 'Atorvastatin',
    'Norvasc': 'Amlodipine', 'Losartan': 'Losartan', 
    'Cozaar': 'Losartan', 'Zestril': 'Lisinopril',
    'Gabapentin': 'Gabapentin', 'Augmentin': 'Amoxicillin + Clavulanic Acid', 
    'Medicol': 'Ibuprofen', 'Novaluzid': 'Magnesium Hydroxide + Dried Aluminum Hydroxide Gel',
    'Maalox': 'Aluminum Hydroxide + Magnesium Hydroxide', 
    'Motilium': 'Domperidone', 'Buscopan': 'Hyoscine Butylbromide',
    'Lincocin': 'Lincomycin', 'Clindamycin': 'Clindamycin', 
    'Azithromycin': 'Azithromycin', 'Bactrim': 'Trimethoprim + Sulfamethoxazole',
    'Zithromax': 'Azithromycin', 'Celebrex': 'Celecoxib', 
    'Arcoxia': 'Etoricoxib', 'Dolfenal': 'Mefenamic Acid',
    'Ponstan': 'Mefenamic Acid', 'Virlix': 'Cetirizine'
}

MEDICINE_PRICES = {
    'Biogesic': 5.00, 'Alaxan': 8.75, 'Decolgen': 8.75, 'Neozep': 7.00, 
    'Bioflu': 9.00, 'Amoxicillin': 20.75, 'Mefenamic Acid': 5.25, 'Paracetamol': 2.75,
    'Cetirizine': 16.00, 'Loperamide': 8.50, 'Ibuprofen': 9.00, 'Cefalexin': 21.25, 
    'Metformin': 4.25, 'Omeprazole': 39.75, 'Loratadine': 19.25, 'Ventolin': 339.75,
    'Salbutamol': 5.00, 'Aspirin': 2.50, 'Diatabs': 8.50, 'Kremil-S': 21.25, 
    'Ascof': 8.75, 'Solmux': 12.50, 'Tuseran Forte': 11.25, 'Robitussin': 12.00,
    'Mucosolvan': 20.75, 'Advil': 9.00, 'Voltaren': 42.50, 'Plavix': 75.75, 
    'Lipitor': 35.25, 'Norvasc': 21.75, 'Losartan': 17.00, 'Cozaar': 23.25, 
    'Zestril': 28.25, 'Gabapentin': 42.25, 'Augmentin': 67.25, 'Medicol': 7.25,
    'Novaluzid': 16.00, 'Maalox': 12.25, 'Motilium': 42.75, 'Buscopan': 34.50, 
    'Lincocin': 38.00, 'Clindamycin': 38.50, 'Azithromycin': 67.20, 'Bactrim': 33.00,
    'Zithromax': 151.43, 'Celebrex': 55.50, 'Arcoxia': 72.75, 'Dolfenal': 20.75,
    'Ponstan': 40.50, 'Virlix': 37.00
}

class Command(BaseCommand):
    help = 'Generates dummy in-store and online sales data for a specified year range (default: 2023 to yesterday).'
    
    def add_arguments(self, parser):
        parser.add_argument(
            '--start_year',
            type=int,
            default=2023,
            help='The starting year for sales data generation (e.g., 2023).'
        )
        parser.add_argument(
            '--end_year',
            type=int,
            default=datetime.now().year,
            help='The ending year for sales data generation (e.g., 2025). Defaults to the current year.'
        )

    def create_dummy_medicines(self):
        self.stdout.write(self.style.NOTICE('Checking/Creating suppliers and medicines...'))
        
        if Medicine.objects.count() >= 50 and Supplier.objects.count() >= 3:
            self.stdout.write(self.style.SUCCESS('Enough suppliers/medicines already exist. Skipping creation.'))
            return

        supplier_names = ['PharmaCorp', 'MediSupply', 'Global Drugs Inc.']
        suppliers = []
        fake = Faker()
        
        for name in supplier_names:
            supplier_contact = fake.msisdn()[:20] 
            supplier, created = Supplier.objects.get_or_create(name=name, defaults={'contact': supplier_contact})
            suppliers.append(supplier)

        for name, generic_name in MEDICINE_DATA.items():
            barcode = fake.unique.ean13()
            price = MEDICINE_PRICES.get(name, round(random.uniform(6, 150), 2))
            category = get_random_choice(Medicine.CATEGORY_CHOICES)
            dosage_form = get_random_choice(Medicine.DOSAGE_CHOICES)
            supplier = random.choice(suppliers)

            Medicine.objects.get_or_create(
                name=name,
                defaults={
                    'generic_name': generic_name, 'category': category, 'dosage_form': dosage_form,
                    'supplier': supplier, 'supplier_name': supplier.name, 
                    'supplier_contact_num': supplier.contact, 'restock_quantity': random.choice([50, 100]),
                    'price': price, 'requires_prescription': random.choice([True, False]), 'barcode': barcode 
                }
            )
            
        self.stdout.write(self.style.SUCCESS('Finished creating dummy suppliers and medicines.'))
    
    def create_dummy_inventory(self):
        self.stdout.write(self.style.NOTICE('Creating dummy inventory...'))
        medicines = Medicine.objects.all()
        
        if not medicines.exists():
            raise CommandError('No medicines found. Cannot create inventory.')

        for medicine in medicines:
            # Only create inventory if it doesn't exist to prevent duplicates on reruns
            if Inventory.objects.filter(medicine=medicine).exists():
                continue

            batch_num = Faker().unique.isbn13()
            exp_date = Faker().date_between(start_date='now', end_date='+2y')
            quantity = random.randint(30, 70)
            
            Inventory.objects.create(
                medicine=medicine,
                batch_num=batch_num,
                exp_date=exp_date,
                quantity=quantity,
                is_promo=False
            )
        
        self.stdout.write(self.style.SUCCESS('Finished creating dummy inventory.'))

    def create_dummy_users(self):
        self.stdout.write(self.style.NOTICE('Creating dummy customers and staff...'))
        fake = Faker()
        
        # Create 10 dummy customers
        for _ in range(10):
            Customer.objects.get_or_create(
                email=fake.unique.email(),
                defaults={
                    'name': fake.name(),
                    'contact_num': fake.msisdn()[:20],
                    'password': 'testpassword123'
                }
            )
            
        # Create staff and cashier users
        staff_roles = ['cashier', 'staff']
        for role in staff_roles:
            email = f'{role}@example.com'
            Staff.objects.get_or_create(
                email=email,
                defaults={
                    'password': 'testpassword123',
                    'name': fake.name(),
                    'role': role,
                    'contact_num': fake.msisdn()[:20]
                }
            )
            
        self.stdout.write(self.style.SUCCESS('Finished creating dummy customers and staff.'))

    def create_sales(self, start_date, end_date):
        self.stdout.write(self.style.WARNING(f'Generating sales data from {start_date} to {end_date}...'))
        
        # --- Common Prerequisite Data ---
        try:
            staff_user = Staff.objects.get(role='staff')
            cashier_user = Staff.objects.get(role='cashier')
            customers = list(Customer.objects.all())
        except Staff.DoesNotExist:
            raise CommandError('Staff or Cashier user not found.')
        
        initial_inventory_items = list(Inventory.objects.all())
        if not initial_inventory_items:
            raise CommandError('No inventory items found. Cannot generate sales.')

        try:
            manila_tz = pytz.timezone(settings.TIME_ZONE)
        except AttributeError:
            manila_tz = pytz.utc
        
        # --- Time and Seasonality Mappings ---
        seasonality_map = {
            'cough_and_cold_medicines': {'wet_season': 2.0, 'dry_season': 0.8},
            'antihistamines': {'dry_season': 1.5, 'wet_season': 0.8},
            'vitamins_and_supplements': {'wet_season': 1.5, 'dry_season': 1.0},
            'gastrointestinal_medicines': {'dry_season': 1.3, 'wet_season': 1.0},
        }
        time_of_day_map = {
            'morning': (9, 11, 1.2), 'afternoon': (12, 17, 1.5), 'evening': (18, 21, 1.0),
        }
        
        # Base order count per day (slight difference for in-store vs. online)
        in_store_range = (40, 60)
        online_range = (50, 70) 

        # --- Dynamic Date Iteration ---
        total_days = (end_date - start_date).days
        
        for day_offset in range(total_days + 1):
            current_date = start_date + timedelta(days=day_offset)
            current_month = current_date.month

            # Determine season
            season = 'dry_season'
            if current_month in [6, 7, 8, 9, 10, 11]:
                season = 'wet_season'
            
            # Check for existing sales on this date to skip generation
            in_store_sales_exist = InStoreOrder.objects.filter(
                date_created__date=current_date
            ).exists()
            online_sales_exist = OnlineOrder.objects.filter(
                date_created__date=current_date
            ).exists()
            
            if in_store_sales_exist and online_sales_exist:
                if day_offset % 90 == 0:
                    self.stdout.write(self.style.NOTICE(f'Skipping existing sales for {current_date.isoformat()}...'))
                continue
            
            # --- IN-STORE SALES GENERATION (Only if it doesn't exist) ---
            if not in_store_sales_exist:
                self._generate_in_store_sales_for_day(
                    current_date, staff_user, cashier_user, initial_inventory_items, 
                    seasonality_map, time_of_day_map, in_store_range, manila_tz, season
                )
            
            # --- ONLINE SALES GENERATION (Only if it doesn't exist) ---
            if not online_sales_exist:
                self._generate_online_sales_for_day(
                    current_date, staff_user, cashier_user, customers, initial_inventory_items,
                    seasonality_map, time_of_day_map, online_range, manila_tz, season
                )

            if day_offset % 30 == 0:
                self.stdout.write(f'Progress: {day_offset}/{total_days} days generated ({current_date.isoformat()}).')

        self.stdout.write(self.style.SUCCESS('Sales generation process completed!'))
        
    def _generate_in_store_sales_for_day(self, current_date, staff_user, cashier_user, inventory, seasonality_map, time_of_day_map, range_tuple, manila_tz, season):
        num_orders = random.randint(*range_tuple)
        
        for _ in range(num_orders):
            with transaction.atomic():
                random_hour = random.randint(9, 21)
                random_minute = random.randint(0, 59)
                random_time = time(random_hour, random_minute, random.randint(0, 59))
                order_time_naive = datetime.combine(current_date, random_time)
                order_time = manila_tz.localize(order_time_naive)
                
                sales_multiplier = 1.0
                for _, (start_h, end_h, multiplier) in time_of_day_map.items():
                    if start_h <= random_hour <= end_h:
                        sales_multiplier = multiplier
                        break

                order = InStoreOrder.objects.create(
                    staff=staff_user, cashier=cashier_user,
                    staff_name=staff_user.name, cashier_name=cashier_user.name,
                    date_created=order_time, status='approved',
                )
                
                # OrderLogs
                OrderLog.objects.create(in_store_order=order, staff_user=staff_user, action_type='initiate_sale', timestamp=order_time)
                OrderLog.objects.create(in_store_order=order, staff_user=cashier_user, action_type='in_store_approve', timestamp=order_time)
                
                total_before = 0
                items_added = set()
                num_items_in_order = random.randint(1, 3)

                for _ in range(num_items_in_order):
                    selected_item = random.choice(inventory)
                    
                    if selected_item.id in items_added: continue
                    items_added.add(selected_item.id)

                    medicine_category = selected_item.medicine.category
                    item_multiplier = seasonality_map.get(medicine_category, {}).get(season, 1.0)
                    
                    base_quantity = random.randint(1, 5)
                    quantity_sold = int(base_quantity * sales_multiplier * item_multiplier)
                    if quantity_sold < 1: quantity_sold = 1

                    price_at_sale = selected_item.medicine.price
                    
                    InStoreOrderItem.objects.create(
                        order=order, inventory_id=selected_item, quantity_sold=quantity_sold,
                        price_at_sale=price_at_sale, medicine_name=selected_item.medicine.name,
                        generic_name=selected_item.medicine.generic_name
                    )
                    
                    total_before += price_at_sale * quantity_sold
                
                if items_added:
                    order.total_amount_before_discount = total_before
                    order.total_amount_after_discount = total_before # No discount logic applied
                    order.save()
                else:
                    order.delete() # Delete empty order

    def _generate_online_sales_for_day(self, current_date, staff_user, cashier_user, customers, inventory, seasonality_map, time_of_day_map, range_tuple, manila_tz, season):
        num_orders = random.randint(*range_tuple)
        
        staff_name = staff_user.name
        staff_role = staff_user.role
        cashier_name = cashier_user.name
        cashier_role = cashier_user.role

        for _ in range(num_orders):
            with transaction.atomic():
                # Order time for customer submission
                random_hour = random.randint(9, 21)
                random_minute = random.randint(0, 59)
                random_time = time(random_hour, random_minute, random.randint(0, 59))
                order_time_naive = datetime.combine(current_date, random_time)
                order_time = manila_tz.localize(order_time_naive)
                
                sales_multiplier = 1.0
                for _, (start_h, end_h, multiplier) in time_of_day_map.items():
                    if start_h <= random_hour <= end_h:
                        sales_multiplier = multiplier
                        break

                customer = random.choice(customers)
                
                pickup_delta_days = random.randint(0, 1)
                pickup_schedule_time_naive = datetime.combine(current_date + timedelta(days=pickup_delta_days), time(random.randint(9, 21), random.randint(0, 59)))
                pickup_schedule = manila_tz.localize(pickup_schedule_time_naive)
                date_fulfilled_time = pickup_schedule + timedelta(minutes=random.randint(15, 60))
                
                order = OnlineOrder.objects.create(
                    customer=customer, date_created=order_time, status='completed',
                    pickup_schedule=pickup_schedule, date_fulfilled=date_fulfilled_time,
                    initiated_by=staff_user, approved_by=cashier_user,
                    initiated_by_name=staff_name, approved_by_name=cashier_name,
                    initiated_by_role_snapshot=staff_role, approved_by_role_snapshot=cashier_role,
                )
                
                # OrderLogs
                OrderLog.objects.create(online_order=order, staff_user=staff_user, action_type='online_confirmed', timestamp=order_time + timedelta(minutes=random.randint(5, 15)))
                OrderLog.objects.create(online_order=order, staff_user=cashier_user, action_type='online_picked_up', timestamp=date_fulfilled_time)
                
                total_before = 0
                items_added = set()
                num_items_in_order = random.randint(1, 3)
                
                for _ in range(num_items_in_order):
                    selected_item = random.choice(inventory)
                    if selected_item.id in items_added: continue
                    items_added.add(selected_item.id)

                    medicine_category = selected_item.medicine.category
                    item_multiplier = seasonality_map.get(medicine_category, {}).get(season, 1.0)
                    
                    base_quantity = random.randint(1, 5)
                    quantity_sold = int(base_quantity * sales_multiplier * item_multiplier)
                    if quantity_sold < 1: quantity_sold = 1

                    price_at_sale = selected_item.medicine.price
                    
                    OnlineOrderItem.objects.create(
                        order=order, inventory_id=selected_item, quantity_sold=quantity_sold,
                        price_at_sale=price_at_sale, medicine_name=selected_item.medicine.name,
                        generic_name=selected_item.medicine.generic_name
                    )
                    
                    total_before += price_at_sale * quantity_sold
                
                if items_added:
                    order.total_amount_before_discount = total_before
                    order.total_amount_after_discount = total_before
                    order.save()
                else:
                    order.delete()

    def handle(self, *args, **options):
        start_year = options['start_year']
        end_year = options['end_year']
        
        if start_year > end_year:
            raise CommandError("Start year cannot be after end year.")
        
        # Determine the dynamic end date (yesterday's date)
        today = date.today()
        dynamic_end_date = today - timedelta(days=1)
        
        # Ensure the start date is January 1st of the start_year
        start_date = date(start_year, 1, 1)
        
        # If the requested end_year is the current year, set the end_date to yesterday.
        # Otherwise, set it to December 31st of the requested end_year.
        if end_year == today.year:
            end_date = dynamic_end_date
        else:
            end_date = date(end_year, 12, 31)

        self.stdout.write(self.style.SUCCESS('Starting unified dummy data generation...'))
        
        self.create_dummy_medicines()
        self.create_dummy_inventory()
        self.create_dummy_users()
        
        # Run the main generation function with the calculated date range
        self.create_sales(start_date, end_date)
        
        self.stdout.write(self.style.SUCCESS(f'All sales data from {start_date} to {end_date} generated or skipped successfully! 🎉'))