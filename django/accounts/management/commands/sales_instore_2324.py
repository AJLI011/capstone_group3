import os
import django
import random
from faker import Faker
from datetime import datetime, timedelta, date, time
import pytz
from django.conf import settings
from django.db import transaction, models

from django.core.management.base import BaseCommand
# Assuming these models are correctly defined in your 'accounts' app
from accounts.models import Supplier, Medicine, Inventory, InStoreOrder, InStoreOrderItem, Staff, OrderLog 

# Helper function to get a random choice from a field's choices tuple
def get_random_choice(choices):
    return random.choice([choice[0] for choice in choices])

class Command(BaseCommand):
    # UPDATED HELP TEXT
    help = 'Generates dummy in-store order data from 2023-01-01 up to the end of September 2025.'
    
    def create_dummy_medicines(self):
        self.stdout.write(self.style.NOTICE('Checking for existing suppliers and medicines...'))
        
        # Stop if enough medicines already exist
        if Medicine.objects.count() >= 50:
            self.stdout.write(self.style.SUCCESS('50 medicines already exist. Skipping creation.'))
            return

        supplier_names = ['PharmaCorp', 'MediSupply', 'Global Drugs Inc.']
        suppliers = []
        fake = Faker()
        
        for name in supplier_names:
            # Use msisdn and slice for a clean, limit-friendly contact number for Supplier
            supplier_contact = fake.msisdn()[:20] 
            supplier, created = Supplier.objects.get_or_create(name=name, defaults={'contact': supplier_contact})
            suppliers.append(supplier)
            if created:
                self.stdout.write(f'Created supplier: {name}')

        # The original script had an issue here: categories was only one random choice, not the list of all categories.
        # This is corrected below.
        
        # Data for Medicine names and their generic counterparts
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
        
        # Prices for specific medicines
        MEDICINE_PRICES = {
            'Biogesic': 5.00,
            'Alaxan': 8.75,
            'Decolgen': 8.75,
            'Neozep': 7.00,
            'Bioflu': 9.00,
            'Amoxicillin': 20.75,
            'Mefenamic Acid': 5.25,
            'Paracetamol': 2.75,
            'Cetirizine': 16.00,
            'Loperamide': 8.50,
            'Ibuprofen': 9.00,
            'Cefalexin': 21.25,
            'Metformin': 4.25,
            'Omeprazole': 39.75,
            'Loratadine': 19.25,
            'Ventolin': 339.75,
            'Salbutamol': 5.00,
            'Aspirin': 2.50,
            'Diatabs': 8.50,
            'Kremil-S': 21.25,
            'Ascof': 8.75,
            'Solmux': 12.50,
            'Tuseran Forte': 11.25,
            'Robitussin': 12.00,
            'Mucosolvan': 20.75,
            'Advil': 9.00,
            'Voltaren': 42.50,
            'Plavix': 75.75,
            'Lipitor': 35.25,
            'Norvasc': 21.75,
            'Losartan': 17.00,
            'Cozaar': 23.25,
            'Zestril': 28.25,
            'Gabapentin': 42.25,
            'Augmentin': 67.25,
            'Medicol': 7.25,
            'Novaluzid': 16.00,
            'Maalox': 12.25,
            'Motilium': 42.75,
            'Buscopan': 34.50,
            'Lincocin': 38.00,
            'Clindamycin': 38.50,
            'Azithromycin': 67.20,
            'Bactrim': 33.00,
            'Zithromax': 151.43,
            'Celebrex': 55.50,
            'Arcoxia': 72.75,
            'Dolfenal': 20.75,
            'Ponstan': 40.50,
            'Virlix': 37.00
        }
        
        for name, generic_name in MEDICINE_DATA.items():
            barcode = fake.unique.ean13()
            
            # Get the price from the new dictionary, or a random one if not found
            price = MEDICINE_PRICES.get(name, round(random.uniform(6, 150), 2))
            
            # Use the helper function to select a random category key
            category = get_random_choice(Medicine.CATEGORY_CHOICES)
            
            # Use the helper function to select a random dosage form key
            dosage_form = get_random_choice(Medicine.DOSAGE_CHOICES)
            
            supplier = random.choice(suppliers)

            medicine, created = Medicine.objects.get_or_create(
                name=name,
                defaults={
                    'generic_name': generic_name,
                    'category': category,
                    'dosage_form': dosage_form,
                    'supplier': supplier,
                    
                    # Add the snapshot fields, using the supplier's current data
                    'supplier_name': supplier.name,
                    'supplier_contact_num': supplier.contact,
                    
                    'restock_quantity': random.choice([50, 100]),
                    'price': price,
                    'requires_prescription': random.choice([True, False]),
                    'barcode': barcode 
                }
            )
            if created:
                self.stdout.write(f'Created medicine: {medicine.name} with price: {medicine.price}')
            else:
                self.stdout.write(f'Medicine already exists: {medicine.name}')
                
        self.stdout.write(self.style.SUCCESS('Finished creating dummy suppliers and medicines.'))
    
    def create_dummy_inventory(self):
        self.stdout.write(self.style.NOTICE('Creating dummy inventory...'))
        
        medicines = Medicine.objects.all()
        if not medicines.exists():
            self.stdout.write(self.style.WARNING('No medicines found. Please run create_dummy_medicines first.'))
            return

        for medicine in medicines:
            # Check if inventory already exists for this medicine to prevent duplicates
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
        # UPDATED MESSAGE
        self.stdout.write(self.style.NOTICE('Creating a large set of dummy in-store sales records from 2023-01-01 up to the end of September 2025...'))
        self.stdout.write(self.style.WARNING('This process will take a significant amount of time and resources. Please be patient.'))
        
        try:
            staff_user = Staff.objects.get(role='staff')
            cashier_user = Staff.objects.get(role='cashier')
        except Staff.DoesNotExist:
            self.stdout.write(self.style.WARNING('Staff or Cashier user not found. Please run create_dummy_users first.'))
            return
            
        initial_inventory_items = list(Inventory.objects.all())
        
        if not initial_inventory_items:
            self.stdout.write(self.style.WARNING('No inventory items found. Please run create_dummy_inventory first.'))
            return

        try:
            manila_tz = pytz.timezone(settings.TIME_ZONE)
        except AttributeError:
            self.stdout.write(self.style.ERROR('TIME_ZONE not set in settings.py or invalid. Using UTC.'))
            manila_tz = pytz.utc
        
        # 🌟 MODIFICATION 1: SET DATE RANGE TO END OF SEPTEMBER 2025
        start_date = date(2023, 1, 1)
        end_date = date(2025, 9, 30) # <--- UPDATED END DATE
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
        
        num_orders_per_day_range = (40, 60)

        # 1. DEFINE POPULARITY WEIGHTS FOR DEMAND SKEW
        medicine_popularity = {
            'Biogesic': 10, 'Paracetamol': 8, 'Decolgen': 7, 'Alaxan': 6, 'Neozep': 6, 
            'Ibuprofen': 5, 'Cetirizine': 4, 'Loperamide': 4, 
            'Metformin': 3, 'Losartan': 3, # Common maintenance drugs
            # Less common/specialty items have lower weights
            'Plavix': 1, 'Gabapentin': 1, 'Zithromax': 1, 'Ventolin': 2,
            'Amoxicillin': 5, 'Cefalexin': 4, 'Azithromycin': 4 # Popular Antibiotics
        }
        default_weight = 1

        weighted_inventory_list = []
        for item in initial_inventory_items:
            weight = medicine_popularity.get(item.medicine.name, default_weight)
            # Create the weighted list
            weighted_inventory_list.extend([item] * weight) 
            
        if not weighted_inventory_list:
             weighted_inventory_list = initial_inventory_items
        
        # 2. DEFINE TREND PARAMETER
        # Small, cumulative daily growth factor (~20% growth over 2 years, or 0.1% daily)
        daily_growth_rate = 0.001 


        for day_offset in range(total_days + 1):
            current_date = start_date + timedelta(days=day_offset)
            current_month = current_date.month

            # Apply trend
            current_trend_multiplier = 1 + (day_offset * daily_growth_rate)

            # Define wet vs dry season (Wet season in PH is typically June to November)
            season = 'dry_season'
            if current_month in [6, 7, 8, 9, 10, 11]:
                season = 'wet_season'
            
            # Apply trend to the base number of orders
            base_orders = random.randint(*num_orders_per_day_range)
            num_orders_per_day = int(base_orders * current_trend_multiplier)

            for _ in range(num_orders_per_day):
                with transaction.atomic():
                    random_hour = random.randint(9, 21)
                    random_minute = random.randint(0, 59)
                    random_time = time(random_hour, random_minute, random.randint(0, 59))
                    
                    order_time_naive = datetime.combine(current_date, random_time)
                    order_time = manila_tz.localize(order_time_naive)
                    
                    sales_multiplier = 1.0
                    for time_period, (start_h, end_h, multiplier) in time_of_day_map.items():
                        if start_h <= random_hour <= end_h:
                            sales_multiplier = multiplier
                            break

                    order = InStoreOrder.objects.create(
                        staff=staff_user, 
                        cashier=cashier_user,
                        staff_name=staff_user.name,
                        cashier_name=cashier_user.name,
                        date_created=order_time,
                        status='approved',
                    )
                    
                    OrderLog.objects.create(
                        in_store_order=order,
                        staff_user=staff_user,
                        action_type='initiate_sale',
                        description=f'In-store sale initiated by {staff_user.name}',
                        timestamp=order_time
                    )
                    
                    OrderLog.objects.create(
                        in_store_order=order,
                        staff_user=cashier_user,
                        action_type='in_store_approve',
                        description=f'In-store order approved by {cashier_user.name}',
                        timestamp=order_time
                    )
                    
                    num_items_in_order = random.randint(1, 3)
                    total_before = 0
                    total_after = 0
                    items_added = set()

                    for _ in range(num_items_in_order):
                        # 3. USE WEIGHTED LIST for ITEM SELECTION
                        selected_item = random.choice(weighted_inventory_list)
                        
                        if selected_item.id in items_added:
                            continue
                        items_added.add(selected_item.id)

                        medicine_category = selected_item.medicine.category
                        item_multiplier = seasonality_map.get(medicine_category, {}).get(season, 1.0)
                        
                        # 4. IMPLEMENT QUANTITY NOISE VARIATION
                        item_weight = medicine_popularity.get(selected_item.medicine.name, default_weight)
                        
                        # Higher weight means a higher max quantity and a larger range of noise
                        min_qty = 1 
                        max_qty = min(8, item_weight) + random.randint(0, 3) # Max quantity up to 11 for high-demand items
                        base_quantity = random.randint(min_qty, max_qty)
                        
                        quantity_sold = int(base_quantity * sales_multiplier * item_multiplier)
                        
                        if quantity_sold < 1:
                            quantity_sold = 1

                        price_at_sale = selected_item.medicine.price
                        
                        InStoreOrderItem.objects.create(
                            order=order,
                            inventory_id=selected_item,
                            quantity_sold=quantity_sold,
                            price_at_sale=price_at_sale,
                            medicine_name=selected_item.medicine.name,
                            generic_name=selected_item.medicine.generic_name
                        )
                        
                        total_before += price_at_sale * quantity_sold
                        total_after = total_before
                    
                    if items_added:
                        order.total_amount_before_discount = total_before
                        order.total_amount_after_discount = total_after
                        order.save()
                    else:
                        order.delete()
            
            # UPDATED PROGRESS MESSAGE
            if day_offset % 60 == 0:
                self.stdout.write(f'Progress: {day_offset}/{total_days} days generated (2023-2025).')

    def handle(self, *args, **options):
        # UPDATED MESSAGE
        self.stdout.write(self.style.SUCCESS('Starting dummy data generation for in-store 2023-2025 (~2.75 years) up to September 30, 2025...'))
        
        self.create_dummy_medicines()
        self.create_dummy_inventory()
        self.create_dummy_users()
        self.create_in_store_sales()
        
        self.stdout.write(self.style.SUCCESS('In-store data generation for ~2.75 years completed successfully!'))