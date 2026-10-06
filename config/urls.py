from django.urls import include, path

urlpatterns = [
    path("", include("sales.urls")),
]
