from django.http import JsonResponse
from django.urls import path, include


def healthz(_request):
    return JsonResponse({"status": "ok"})

urlpatterns = [
    path("healthz", healthz),
    path("api/users/", include(("api.routers", "api"), namespace="api")),
]
