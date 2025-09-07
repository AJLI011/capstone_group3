import os
import django
import random
from faker import Faker
from datetime import datetime, timedelta, date, time
import pytz 
from django.conf import settings 

from django.core.management.base import BaseCommand
from accounts.models import Supplier, Medicine, Inventory, InStoreOrder, InStoreOrderItem, Staff

class Command(BaseCommand):
    help = 'Generates dummy in-store order data for the year 2024.'
    
    def create_dummy_medicines(self):
        self.stdout.write(self.style.NOTICE('Checking for existing suppliers and medicines...'))
        
        if Medicine.objects.count() >= 50:
            self.stdout.write(self.style.SUCCESS('50 medicines already exist. Skipping creation.'))
            return

        supplier_names = ['PharmaCorp', 'MediSupply', 'Global Drugs Inc.']
        suppliers = []
        for name in supplier_names:
            supplier, created = Supplier.objects.get_or_create(name=name, defaults={'contact': Faker().phone_number()})
            suppliers.append(supplier)
            if created:
                self.stdout.write(f'Created supplier: {name}')

        categories = [choice[0] for choice in Medicine.CATEGORY_CHOICES]
        
        # --- START OF CHANGES ---
        # The specific list of 50 medicine names should be defined here
        MEDICINE_DATA = {
            'Biogesic': 'Paracetamol',
            'Alaxan': 'Ibuprofen + Paracetamol',
            'Decolgen': 'Paracetamol + Phenylephrine + Chlorphenamine Maleate',
            'Neozep': 'Phenylephrine + Chlorphenamine Maleate + Paracetamol',
            'Bioflu': 'Phenylephrine + Chlorphenamine Maleate + Paracetamol + Phenylpropanolamine',
            'Amoxicillin': 'Amoxicillin',
            'Mefenamic Acid': 'Mefenamic Acid',
            'Paracetamol': 'Paracetamol',
            'Cetirizine': 'Cetirizine',
            'Loperamide': 'Loperamide',
            'Ibuprofen': 'Ibuprofen',
            'Cefalexin': 'Cefalexin',
            'Metformin': 'Metformin',
            'Omeprazole': 'Omeprazole',
            'Loratadine': 'Loratadine',
            'Ventolin': 'Salbutamol',
            'Salbutamol': 'Salbutamol',
            'Aspirin': 'Aspirin',
            'Diatabs': 'Loperamide Hydrochloride',
            'Kremil-S': 'Aluminum Hydroxide + Magnesium Hydroxide + Simeticone',
            'Ascof': 'Vitex negundo L. (Lagundi)',
            'Solmux': 'Carbocisteine',
            'Tuseran Forte': 'Dextromethorphan + Phenylpropanolamine + Paracetamol',
            'Robitussin': 'Guaifenesin',
            'Mucosolvan': 'Ambroxol',
            'Advil': 'Ibuprofen',
            'Voltaren': 'Diclofenac',
            'Plavix': 'Clopidogrel',
            'Lipitor': 'Atorvastatin',
            'Norvasc': 'Amlodipine',
            'Losartan': 'Losartan',
            'Cozaar': 'Losartan',
            'Zestril': 'Lisinopril',
            'Gabapentin': 'Gabapentin',
            'Augmentin': 'Amoxicillin + Clavulanic Acid',
            'Medicol': 'Ibuprofen',
            'Novaluzid': 'Magnesium Hydroxide + Dried Aluminum Hydroxide Gel',
            'Maalox': 'Aluminum Hydroxide + Magnesium Hydroxide',
            'Motilium': 'Domperidone',
            'Buscopan': 'Hyoscine Butylbromide',
            'Lincocin': 'Lincomycin',
            'Clindamycin': 'Clindamycin',
            'Azithromycin': 'Azithromycin',
            'Bactrim': 'Trimethoprim + Sulfamethoxazole',
            'Zithromax': 'Azithromycin',
            'Celebrex': 'Celecoxib',
            'Arcoxia': 'Etoricoxib',
            'Dolfenal': 'Mefenamic Acid',
            'Ponstan': 'Mefenamic Acid',
            'Virlix': 'Cetirizine'
        }

        # Iterate through the dictionary to create each medicine
        for name, generic_name in MEDICINE_DATA.items():
            barcode = Faker().unique.ean13()
            price = round(random.uniform(6, 150), 2)
            category = random.choice(categories)
            
            dosage_form = random.choice([choice[0] for choice in Medicine.DOSAGE_CHOICES])
            
            supplier = random.choice(suppliers)

            medicine, created = Medicine.objects.get_or_create(
                name=name,
                defaults={
                    'generic_name': generic_name,
                    'category': category,
                    'dosage_form': dosage_form,
                    'supplier': supplier,
                    'restock_quantity': random.choice([50, 100]),
                    'price': price,
                    'requires_prescription': random.choice([True, False]),
                    'barcode': barcode # Add barcode to defaults
                }
            )
            if created:
                self.stdout.write(f'Created medicine: {medicine.name}')
            else:
                self.stdout.write(f'Medicine already exists: {medicine.name}')

        # --- END OF CHANGES ---
        self.stdout.write(self.style.SUCCESS('Finished creating dummy suppliers and medicines.'))
        
    def create_dummy_inventory(self):
        self.stdout.write(self.style.NOTICE('Creating dummy inventory...'))
        
        medicines = Medicine.objects.all()
        if not medicines.exists():
            self.stdout.write(self.style.WARNING('No medicines found. Please run create_dummy_medicines first.'))
            return

        for medicine in medicines:
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
        self.stdout.write(self.style.NOTICE('Creating a large set of dummy in-store sales records for 2024...'))
        self.stdout.write(self.style.WARNING('This process will take a significant amount of time and resources. Please be patient.'))
        
        staff_user = Staff.objects.get(role='staff')
        inventory_items = Inventory.objects.all()
        
        if not staff_user or not inventory_items.exists():
            self.stdout.write(self.style.WARNING('Prerequisite data (staff, inventory) not found. Please run previous functions first.'))
            return

        # Define the date range for 2024
        manila_tz = pytz.timezone(settings.TIME_ZONE)
        
        # MODIFIED: Use date objects for the loop to avoid ambiguity
        start_date = date(2024, 1, 1)
        end_date = date(2024, 12, 31)
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
                random_time = time(random_hour, random_minute, random.randint(0, 59))
                
                # CORRECTED: Use datetime.combine() to create a naive datetime object
                order_time_naive = datetime.combine(current_date, random_time)
                # Then localize it with the correct timezone
                order_time = manila_tz.localize(order_time_naive)
                
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
                self.stdout.write(f'Progress: {day_offset}/{total_days} days generated for 2024.')

        self.stdout.write(self.style.SUCCESS('Finished creating dummy in-store sales records for 2024.'))

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('Starting dummy data generation for in-store 2024...'))
        
        self.create_dummy_medicines()
        self.create_dummy_inventory()
        self.create_dummy_users()
        self.create_in_store_sales()
        
        self.stdout.write(self.style.SUCCESS('In-store data generation for 2024 completed successfully!'))