"""Shared dates, calendar-day mode history, and private monthly recaps."""
import calendar
from datetime import date, timedelta
from django.db import transaction
from django.http import HttpResponse
from rest_framework.decorators import action
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import ImportantDate, ModePeriod, Couple, DailyPhotoSubmission, DailyAnswer, StoryEntry, WishlistItem
from .relationship import CoupleViewSet
from .views import couple_for, day_for


class ImportantDateSerializer(serializers.ModelSerializer):
    remind_days = serializers.IntegerField(min_value=0, max_value=30)

    class Meta:
        model = ImportantDate
        fields = ['id', 'title', 'date', 'yearly', 'remind_days']


class ImportantDateViewSet(CoupleViewSet):
    serializer_class = ImportantDateSerializer

    @action(detail=False, methods=['get'])
    def calendar(self, request):
        couple = couple_for(request.user)
        today = day_for(couple)
        events = []
        for item in self.get_queryset():
            targets = [month_day(y, item.date.month, item.date.day) for y in range(today.year, today.year + 5)] if item.yearly else [item.date]
            for target in targets:
                if target >= today:
                    events.append((f'date-{item.pk}-{target}', item.title, target, item.remind_days))
        start = couple.relationship_start_date
        elapsed = max(1, (today.year - start.year) * 12 + today.month - start.month)
        for months in range(elapsed, elapsed + 36):
            year, month = divmod(start.year * 12 + start.month - 1 + months, 12)
            target = month_day(year, month + 1, start.day)
            if target >= today:
                events.append((f'month-{months}', f'{months} months together', target, 1))
        def escape(value):
            return value.replace('\\', '\\\\').replace('\n', '\\n').replace(';', '\\;').replace(',', '\\,').replace('\r', '')
        lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//Near//Important dates//EN', 'CALSCALE:GREGORIAN']
        for uid, title, target, reminder in events:
            lines += ['BEGIN:VEVENT', f'UID:{couple.pk}-{uid}@near', 'DTSTAMP:' + today.strftime('%Y%m%d') + 'T000000Z',
                      'DTSTART;VALUE=DATE:' + target.strftime('%Y%m%d'), 'DTEND;VALUE=DATE:' + (target + timedelta(days=1)).strftime('%Y%m%d'),
                      'SUMMARY:' + escape(title), 'BEGIN:VALARM', f'TRIGGER:-P{reminder}D', 'ACTION:DISPLAY', 'DESCRIPTION:' + escape(title), 'END:VALARM', 'END:VEVENT']
        lines += ['END:VCALENDAR']
        response = HttpResponse('\r\n'.join(lines) + '\r\n', content_type='text/calendar; charset=utf-8')
        response['Content-Disposition'] = 'attachment; filename="near-dates.ics"'
        response['Cache-Control'] = 'private, no-store'
        return response


def month_day(year, month, day):
    return date(year, month, min(day, calendar.monthrange(year, month)[1]))


def notifications(couple, today):
    result = []
    for event in ImportantDate.objects.filter(couple=couple):
        target = event.date
        if event.yearly:
            target = month_day(today.year, target.month, target.day)
            if target < today:
                target = month_day(today.year + 1, event.date.month, event.date.day)
        remaining = (target - today).days
        if 0 <= remaining <= event.remind_days:
            result.append({'title': event.title, 'date': str(target), 'days': remaining})
    start = couple.relationship_start_date
    months = (today.year - start.year) * 12 + today.month - start.month
    target = month_day(today.year, today.month, start.day)
    if target < today:
        months += 1
        target = month_day(today.year + (today.month == 12), today.month % 12 + 1, start.day)
    if months > 0 and 0 <= (target - today).days <= 7:
        result.append({'title': f'{months} months together', 'date': str(target), 'days': (target - today).days})
    return sorted(result, key=lambda row: row['date'])


def mode_summary(couple, today, start=None, end=None):
    periods = list(ModePeriod.objects.filter(couple=couple))
    totals = {'apart': 0, 'together': 0}
    for period in periods:
        left = max(period.started_on, start or period.started_on)
        right = min(period.ended_on or today, end or today)
        totals[period.mode] += max(0, (right-left).days)
    active = next((p for p in periods if p.ended_on is None), None)
    return {'mode': active.mode if active else None, 'since': str(active.started_on) if active else None,
            'days': totals, 'history': [{'mode': p.mode, 'start': str(p.started_on), 'end': str(p.ended_on) if p.ended_on else None} for p in periods]}


class LifeView(APIView):
    def get(self, request):
        couple = couple_for(request.user)
        today = day_for(couple)
        return Response({'notifications': notifications(couple, today), **mode_summary(couple, today)})

    @transaction.atomic
    def post(self, request):
        couple = Couple.objects.select_for_update().get(pk=couple_for(request.user).pk)
        mode = request.data.get('mode')
        if mode not in ('apart', 'together'):
            raise serializers.ValidationError('Choose Apart or Together.')
        today = day_for(couple)
        active = ModePeriod.objects.filter(couple=couple, ended_on=None).first()
        if active and active.mode == mode:
            return self.get(request)
        if active and active.started_on == today:
            active.mode = mode
            active.save(update_fields=['mode'])
        else:
            if active:
                active.ended_on = today
                active.save(update_fields=['ended_on'])
            ModePeriod.objects.create(couple=couple, mode=mode, started_on=today)
        return self.get(request)


class RecapView(APIView):
    def get(self, request):
        couple = couple_for(request.user)
        today = day_for(couple)
        last = today.replace(day=1) - timedelta(days=1)
        try:
            start = date.fromisoformat(request.query_params.get('month', last.strftime('%Y-%m')) + '-01')
        except ValueError:
            raise serializers.ValidationError('Use YYYY-MM.')
        end = month_day(start.year + (start.month == 12), start.month % 12 + 1, 1)
        if start > today:
            raise serializers.ValidationError('This month has not started yet.')
        photos = DailyPhotoSubmission.objects.filter(couple=couple, day__gte=start, day__lt=end)
        answers = DailyAnswer.objects.filter(couple=couple, question__date__gte=start, question__date__lt=end)
        return Response({'month': start.strftime('%Y-%m'), 'complete': end <= today,
                         'daily_photos': photos.count(), 'photo_days': photos.values('day').distinct().count(),
                         'answers': answers.count(), 'memories': StoryEntry.objects.filter(couple=couple, date__gte=start, date__lt=end).count(),
                         'dreams': WishlistItem.objects.filter(couple=couple, completed=True, completed_at__date__gte=start, completed_at__date__lt=end).count(),
                         **mode_summary(couple, today, start, end)})
