"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
# backend/urls.py

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.shortcuts import redirect

# urlpatterns = [
#     path('admin/', admin.site.urls),
#     path('api/', include('accounts.urls')),
#     path('reset-password/<str:token>/', reset_password, name='reset_password'),  # needed for email reset
# ]

urlpatterns = [
    path('', lambda request: redirect('/admin/', permanent=False)),  # Redirect root to /admin
    path('admin/', admin.site.urls),
    path('api/', include('accounts.urls')),
]

# Serve uploaded media files ONLY during development (when DEBUG is True)
if settings.DEBUG: # This is line 30
    # This line MUST be indented, typically by 4 spaces
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)