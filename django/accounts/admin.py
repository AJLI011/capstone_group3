from django.contrib import admin
from .models import Staff, Customer
from django.contrib.auth.hashers import make_password

@admin.register(Staff)
class StaffAdmin(admin.ModelAdmin):
    list_display = ('name', 'email', 'role', 'contact_num')  # Show in list view
    search_fields = ('name', 'email', 'role', 'contact_num')  # Enable search

    def save_model(self, request, obj, form, change):
        if form.cleaned_data.get('password'):
            obj.password = make_password(form.cleaned_data['password'])
        super().save_model(request, obj, form, change)

@admin.register(Customer)
class CustomerAdmin(admin.ModelAdmin):
    list_display = ('name', 'email', 'contact_num')  # Show in list view
    search_fields = ('name', 'email', 'contact_num')  # Enable search

    def save_model(self, request, obj, form, change):
        if form.cleaned_data.get('password'):
            obj.password = make_password(form.cleaned_data['password'])
        super().save_model(request, obj, form, change)
