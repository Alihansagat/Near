from django.db import migrations


def refresh(apps, schema_editor):
    # Preserve any prompt already seen through a saved choice or answer.
    from core.question_content import category_question, QUESTIONS
    from django.utils import timezone
    Question = apps.get_model('core', 'DailyQuestion')
    old = ['If we could travel anywhere tomorrow, where would we go?', 'What makes you feel loved?',
           'Where do you imagine us living in 5 years?', 'What is the weirdest thing you did today?',
           'What do you want us to do together?', 'How can I support you this week?',
           'What would our perfect Sunday look like?', 'What little thing made you smile today?']
    for question in Question.objects.filter(date__gte=timezone.localdate(), question_text__in=old, dailyanswer__isnull=True, dailyquestionchoice__isnull=True):
        category = list(QUESTIONS)[question.date.toordinal() % 4]
        text = category_question(category, question.date)
        if text:
            question.category, question.question_text = category, text
            question.save(update_fields=['category', 'question_text'])


class Migration(migrations.Migration):
    dependencies = [('core', '0007_wishlistitem_completed_at_wishlistitem_report_and_more')]
    operations = [migrations.RunPython(refresh, migrations.RunPython.noop)]
