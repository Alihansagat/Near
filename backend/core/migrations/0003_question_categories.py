from django.db import migrations


def categorize_legacy_questions(apps, schema_editor):
    Question = apps.get_model('core', 'DailyQuestion')
    categories = {
        'What made you smile today?': 'random',
        'Where should we travel together?': 'fun',
        'What is your favorite memory of us?': 'deep',
        'How can I support you this week?': 'deep',
        'What would our perfect Sunday look like?': 'future',
        'What do you miss most about us?': 'deep',
        'What are you grateful for today?': 'random',
    }
    for text, category in categories.items():
        Question.objects.filter(category='connection', question_text=text).update(category=category)


class Migration(migrations.Migration):
    dependencies = [('core', '0002_meetingcountdown_kind_virtualdate_detail_and_more')]
    operations = [migrations.RunPython(categorize_legacy_questions, migrations.RunPython.noop)]
