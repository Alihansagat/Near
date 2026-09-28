from django.test import TestCase, override_settings
from django.core.files.base import ContentFile
from rest_framework.exceptions import ValidationError
from core.storage import DatabaseMediaStorage
from core.models import StoredMedia


class DatabaseStorageTests(TestCase):
    def test_file_survives_new_storage_instance(self):
        storage = DatabaseMediaStorage()
        name = storage.save('couples/1/photo.jpg', ContentFile(b'image-data'))
        reopened = DatabaseMediaStorage()
        self.assertEqual(reopened.open(name).read(), b'image-data')
        self.assertEqual(reopened.size(name), 10)
        reopened.delete(name)
        self.assertFalse(storage.exists(name))

    @override_settings(DATABASE_MEDIA_LIMIT_BYTES=12)
    def test_quota_rejects_new_file_without_damaging_existing(self):
        storage = DatabaseMediaStorage()
        storage.save('one.jpg', ContentFile(b'1234567890'))
        with self.assertRaises(ValidationError):
            storage.save('two.jpg', ContentFile(b'123'))
        self.assertEqual(StoredMedia.objects.count(), 1)
