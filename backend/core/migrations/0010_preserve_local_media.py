from django.conf import settings
from django.db import migrations
from pathlib import Path


def preserve(apps, schema_editor):
    if settings.STORAGES['default']['BACKEND'] != 'core.storage.DatabaseMediaStorage':
        return
    Media = apps.get_model('core', 'StoredMedia')
    # Imports any files still available at upgrade time; never invents missing data.
    root = Path(settings.MEDIA_ROOT)
    used = sum(Media.objects.values_list('size', flat=True))
    for path in root.rglob('*') if root.exists() else []:
        if not path.is_file() or path.is_symlink():
            continue
        name = path.relative_to(root).as_posix()
        size = path.stat().st_size
        if Media.objects.filter(name=name).exists():
            continue
        if used + size > settings.DATABASE_MEDIA_LIMIT_BYTES:
            raise RuntimeError('Existing media exceeds database budget; configure S3 before migrating.')
        Media.objects.create(name=name, size=size, data=path.read_bytes())
        used += size


class Migration(migrations.Migration):
    dependencies = [('core', '0009_mediabudget_storedmedia')]
    operations = [migrations.RunPython(preserve, migrations.RunPython.noop)]
