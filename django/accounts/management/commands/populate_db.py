# accounts/management/commands/populate_db.py

import random
from datetime import datetime, timedelta, date
from django.core.management.base import BaseCommand
from accounts.models import Medicine, Staff, Inventory, InStoreOrder, InStoreOrderItem, OnlineOrder, OnlineOrderItem, Customer, Supplier

class Command(BaseCommand):
    help = 'Populates the database with dummy data for demand forecasting.'

    def handle(self, *args, **kwargs):
        self.stdout.write('Starting database population...')

        # Create dummy users and suppliers
        staff_member, created = Staff.objects.get_or_create(email='test_staff@pharmacy.com', defaults={'name': 'Test Staff', 'role': 'cashier', 'password': 'password'})
        self.stdout.write(f"Staff: {staff_member.name} created or exists.")

        customer, created = Customer.objects.get_or_create(email='test_customer@mail.com', defaults={'name': 'Test Customer', 'password': 'password'})
        self.stdout.write(f"Customer: {customer.name} created or exists.")

        supplier, created = Supplier.objects.get_or_create(name='Dummy Supplier')
        self.stdout.write(f"Supplier: {supplier.name} created or exists.")

        # Create 100 dummy medicines and their corresponding inventory entries
        num_medicines = 100
        medicine_names = [f'Medicine_{i}' for i in range(1, num_medicines + 1)]
        medicines = []
        for name in medicine_names:
            med, created = Medicine.objects.get_or_create(
                name=name,
                defaults={
                    'generic_name': f'Generic_{name}',
                    'barcode': str(random.randint(1000000000, 9999999999)),
                    'category': random.choice(['analgesics', 'antibiotics', 'vitamins_and_supplements']),
                    'dosage_form': random.choice(['tablet', 'syrup', 'capsule']),
                    'price': random.uniform(50, 200),
                    'supplier': supplier,
                    'requires_prescription': random.choice([True, False]),
                    'restock_quantity': random.randint(100, 500),
                }
            )
            inv, created = Inventory.objects.get_or_create(
                medicine=med,
                batch_num=f'BATCH_{med.id}',
                defaults={'quantity': 5000, 'exp_date': date(2028, 1, 1)}
            )
            medicines.append({'med': med, 'inv': inv})

        self.stdout.write(f"{num_medicines} medicines and inventory entries created.")

        # Generate sales data over a 3-year period
        num_days = 365 * 3  # 3 years
        in_store_count = 0
        online_count = 0

        self.stdout.write('Generating sales data with consistent daily sales...')
        
        # This will create a large dataset to ensure density for each medicine
        for i in range(num_days):
            sale_date = datetime.now() - timedelta(days=num_days - i)

            for med_dict in medicines:
                # 3-5 sales per day for each medicine to ensure density
                num_sales_today = random.randint(3, 5) 
                
                for _ in range(num_sales_today):
                    quantity = random.randint(1, 10)

                    if random.choice([True, False]):
                        order = InStoreOrder.objects.create(
                            staff=staff_member,
                            date_created=sale_date,
                            status='approved',
                            total_amount_before_discount=0,
                            total_amount_after_discount=0,
                        )
                        InStoreOrderItem.objects.create(
                            order=order,
                            inventory_id=med_dict['inv'],
                            quantity_sold=quantity,
                            price_at_sale=med_dict['med'].price
                        )
                        in_store_count += 1
                    else:
                        order = OnlineOrder.objects.create(
                            customer=customer,
                            date_created=sale_date,
                            status='completed',
                            total_amount_before_discount=0,
                            total_amount_after_discount=0,
                            date_fulfilled=sale_date
                        )
                        OnlineOrderItem.objects.create(
                            order=order,
                            inventory_id=med_dict['inv'],
                            quantity_sold=quantity,
                            price_at_sale=med_dict['med'].price
                        )
                        online_count += 1
        
        total_entries = in_store_count + online_count
        self.stdout.write(f"Data generation complete. Total entries: {total_entries}. In-store items: {in_store_count}, Online items: {online_count}")