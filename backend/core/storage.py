"""Durable private media for small two-person deployments without object storage."""
from django.conf import settings
from django.core.files.base import ContentFile
from django.core.files.storage import Storage
from django.db import transaction
from django.db.models import Sum
from django.utils.deconstruct import deconstructible
from rest_framework.exceptions import ValidationError


@deconstructible
class DatabaseMediaStorage(Storage):
    def _open(self, name, mode='rb'):
        from .models import StoredMedia
        try:
            obj = StoredMedia.objects.get(name=name)
        except StoredMedia.DoesNotExist:
            raise FileNotFoundError(name)
        return ContentFile(bytes(obj.data), name=name)

    @transaction.atomic
    def _save(self, name, content):
        from .models import StoredMedia, MediaBudget
        limit = getattr(settings, 'DATABASE_MEDIA_LIMIT_BYTES', 200 * 1024 * 1024)
        if content.size > 50 * 1024 * 1024:
            raise ValidationError('Attach a file up to 50 MB.')
        MediaBudget.objects.get_or_create(pk=1)
        MediaBudget.objects.select_for_update().get(pk=1)
        used = StoredMedia.objects.aggregate(total=Sum('size'))['total'] or 0
        if used + content.size > limit:
            raise ValidationError('Your shared media storage is full. Connect object storage before adding more files.')
        data = content.read()
        StoredMedia.objects.create(name=name, data=data, size=len(data))
        return name

    def exists(self, name):
        from .models import StoredMedia
        return StoredMedia.objects.filter(name=name).exists()

    def size(self, name):
        from .models import StoredMedia
        return StoredMedia.objects.values_list('size', flat=True).get(name=name)

    def delete(self, name):
        from .models import StoredMedia
        StoredMedia.objects.filter(name=name).delete()

    def url(self, name):
        from urllib.parse import quote
        return '/media/' + quote(name)
