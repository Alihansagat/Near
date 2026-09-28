from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from core.models import DailyPhotoPrompt, DailyQuestion
from core.question_content import ensure_daily_question

class Command(BaseCommand):
    help = 'Create the next 365 daily prompts (idempotent).'
    def handle(self, *args, **kwargs):
        prompts = ['Show me your morning.', 'Something that reminds you of us', 'Your favorite corner', 'A little joy today', 'The sky above you', 'Your evening ritual', 'Your smile']
        for offset in range(-1, 366):
            day = timezone.localdate() + timedelta(days=offset)
            ensure_daily_question(day)
            DailyPhotoPrompt.objects.get_or_create(date=day, defaults={'prompt_text': prompts[offset % len(prompts)]})
        self.stdout.write(self.style.SUCCESS('Daily content ready.'))
