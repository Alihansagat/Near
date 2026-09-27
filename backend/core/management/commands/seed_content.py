from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import DailyPhotoPrompt, DailyQuestion

class Command(BaseCommand):
    help = 'Create the next 365 daily prompts (idempotent).'
    def handle(self, *args, **kwargs):
        questions = [
            ('fun', 'If we could travel anywhere tomorrow, where would we go?'),
            ('deep', 'What makes you feel loved?'),
            ('future', 'Where do you imagine us living in 5 years?'),
            ('random', "What is the weirdest thing you did today?"),
            ('fun', 'What do you want us to do together?'),
            ('deep', 'How can I support you this week?'),
            ('future', 'What would our perfect Sunday look like?'),
            ('random', 'What little thing made you smile today?'),
        ]
        prompts = ['Show me your morning.', 'Something that reminds you of us', 'Your favorite corner', 'A little joy today', 'The sky above you', 'Your evening ritual', 'Your smile']
        for offset in range(-1, 366):
            day = timezone.localdate() + timedelta(days=offset)
            DailyQuestion.objects.get_or_create(date=day, defaults={'question_text': questions[offset % len(questions)][1], 'category': questions[offset % len(questions)][0]})
            DailyPhotoPrompt.objects.get_or_create(date=day, defaults={'prompt_text': prompts[offset % len(prompts)]})
        self.stdout.write(self.style.SUCCESS('Daily content ready.'))
