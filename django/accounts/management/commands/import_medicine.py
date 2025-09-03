import csv
from decimal import Decimal
from datetime import datetime
from django.core.management.base import BaseCommand
from accounts.models import Medicine

class Command(BaseCommand):
    help = 'Import medicines from CSV'

    def handle(self, *args, **options):
        file_path = "accounts/datas/SQL DATAS - MEDICINES_LIST.csv"

        with open(file_path, newline='', encoding="utf-8") as file:
            reader = csv.reader(file)
            next(reader)  # skip header

            for row in reader:
                med = Medicine(
                    name=row[0],
                    generic_name=row[1],
                    barcode=row[2],
                    category=row[3],
                    dosage_form=row[4],
                    supplier_id=int(row[5]) if row[5] else None,
                    restock_quantity=int(row[6]),
                    price=Decimal(row[7]),
                    requires_prescription=row[8].strip().lower() == "true",
                )
                med.save()

                # override auto fields if CSV has values
                if row[9]:
                    med.created_at = datetime.strptime(row[9], "%Y-%m-%d %H:%M:%S")
                if row[10]:
                    med.updated_at = datetime.strptime(row[10], "%Y-%m-%d %H:%M:%S")
                if row[9] or row[10]:
                    med.save(force_update=True)
