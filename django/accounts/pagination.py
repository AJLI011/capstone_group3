# pagination.py
from rest_framework.pagination import PageNumberPagination

class InventoryLogPagination(PageNumberPagination):
    page_size = 10  # Number of items per page
    page_size_query_param = 'page_size' # Allows client to specify page size
    max_page_size = 100 # Maximum page size allowed



class PromoMedicinePagination(PageNumberPagination):
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 100