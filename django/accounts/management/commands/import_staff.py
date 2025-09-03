import csv
from django.core.management.base import BaseCommand
from django.db import IntegrityError
from accounts.models import Staff  # Correctly import your Staff model

class Command(BaseCommand):
    help = 'Imports staff data from a specific CSV file.'

    def handle(self, *args, **kwargs):
        file_path = 'accounts/datas/SQL DATAS - ACCOUNTS_STAFF.csv'
        self.stdout.write(f"Attempting to import data from: {file_path}")

        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                reader = csv.reader(f)
                # Skip the header row
                next(reader, None)

                rows_processed = 0
                rows_created = 0
                rows_updated = 0
                rows_skipped = 0
                
                for row in reader:
                    # Check if the row has the expected number of columns (5)
                    if len(row) != 5:
                        self.stdout.write(self.style.WARNING(f"Skipping malformed row: {row}. Expected 5 columns, but got {len(row)}."))
                        rows_skipped += 1
                        continue

                    # Unpack the row data according to your CSV structure
                    # Assuming the order is: email, password, name, role, contact_num
                    email, password, name, role, contact_num = [item.strip() for item in row]

                    try:
                        # Find an existing staff member by email
                        staff_obj, created = Staff.objects.get_or_create(
                            email=email,
                            defaults={
                                'password': password,
                                'name': name,
                                'role': role,
                                'contact_num': contact_num if contact_num else None
                            }
                        )
                        
                        if created:
                            self.stdout.write(self.style.SUCCESS(f"Successfully created new staff member: {email}"))
                            rows_created += 1
                        else:
                            # Update the existing staff member's details
                            staff_obj.password = password
                            staff_obj.name = name
                            staff_obj.role = role
                            staff_obj.contact_num = contact_num if contact_num else None
                            staff_obj.save()
                            self.stdout.write(self.style.WARNING(f"Updated existing staff member: {email}"))
                            rows_updated += 1

                        rows_processed += 1

                    except IntegrityError:
                        self.stdout.write(self.style.ERROR(f"Integrity Error: A record with email '{email}' already exists."))
                        rows_skipped += 1
                    except Exception as e:
                        self.stdout.write(self.style.ERROR(f"An unexpected error occurred while processing row {rows_processed + 1} ({email}): {e}"))
                        rows_skipped += 1
            
            self.stdout.write(self.style.SUCCESS("---------------------------------------"))
            self.stdout.write(self.style.SUCCESS("CSV Import Summary:"))
            self.stdout.write(self.style.SUCCESS(f"Total rows processed: {rows_processed}"))
            self.stdout.write(self.style.SUCCESS(f"New staff members created: {rows_created}"))
            self.stdout.write(self.style.WARNING(f"Existing staff members updated: {rows_updated}"))
            self.stdout.write(self.style.ERROR(f"Rows skipped due to errors: {rows_skipped}"))
            self.stdout.write(self.style.SUCCESS("---------------------------------------"))
            self.stdout.write(self.style.SUCCESS("Import process completed."))

        except FileNotFoundError:
            self.stdout.write(self.style.ERROR(f"Error: The file '{file_path}' was not found."))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"An error occurred during file processing: {e}"))