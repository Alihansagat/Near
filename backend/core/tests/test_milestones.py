from datetime import date, timedelta
from unittest.mock import patch
from rest_framework.test import APITestCase
from . import test_api
from core.models import ImportantDate, ModePeriod, DailyQuestion, DailyAnswer
from core.milestones import notifications, mode_summary
from core.question_content import QUESTIONS, category_question


class MilestoneTests(APITestCase):
    setUp = test_api.CoupleApiTests.setUp
    as_user = test_api.CoupleApiTests.as_user
    photo = test_api.CoupleApiTests.photo

    def test_dates_edit_delete_and_other_couple_cannot_access(self):
        self.as_user(self.a)
        response = self.client.post('/api/important-dates/', {'title': 'Birthday', 'date': '2000-02-29', 'yearly': True, 'remind_days': 3}, format='json')
        self.assertEqual(response.status_code, 201)
        url = f"/api/important-dates/{response.data['id']}/"
        self.as_user(self.b)
        self.assertEqual(self.client.patch(url, {'title': 'Her birthday'}).status_code, 200)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        self.assertEqual(self.client.delete(url).status_code, 404)
        self.as_user(self.a)
        self.assertEqual(self.client.delete(url).status_code, 204)

    def test_leap_birthday_and_month_end_anniversary(self):
        self.couple.relationship_start_date = date(2025, 12, 31)
        ImportantDate.objects.create(couple=self.couple, title='Birthday', date=date(2000, 2, 29), remind_days=2)
        events = notifications(self.couple, date(2026, 2, 28))
        self.assertEqual({e['title'] for e in events}, {'Birthday', '2 months together'})
        self.assertTrue(all(e['days'] == 0 for e in events))

    def test_modes_are_shared_idempotent_and_months_are_clipped(self):
        self.as_user(self.a)
        with patch('core.milestones.day_for', return_value=date(2026, 8, 29)):
            self.assertEqual(self.client.post('/api/life/', {'mode': 'together'}).status_code, 200)
            self.client.post('/api/life/', {'mode': 'together'})
        self.as_user(self.b)
        with patch('core.milestones.day_for', return_value=date(2026, 9, 4)):
            result = self.client.post('/api/life/', {'mode': 'apart'})
            self.assertEqual(result.data['days']['together'], 6)
            self.client.post('/api/life/', {'mode': 'together'})
            self.client.post('/api/life/', {'mode': 'apart'})
        self.assertEqual(ModePeriod.objects.filter(couple=self.couple, ended_on=None).count(), 1)
        summary = mode_summary(self.couple, date(2026, 10, 2), date(2026, 9, 1), date(2026, 10, 1))
        self.assertEqual(summary['days'], {'together': 3, 'apart': 27})

    def test_wish_report_private_media_and_recap(self):
        self.as_user(self.a)
        wish = self.client.post('/api/wishlist/', {'title': 'Trip'}).data
        result = self.client.patch(f"/api/wishlist/{wish['id']}/", {'completed': True, 'report': 'We went!', 'report_photo': self.photo()}, format='multipart')
        self.assertEqual(result.status_code, 200)
        self.assertIsNotNone(result.data['completed_at'])
        self.as_user(self.b)
        media = self.client.get(result.data['report_photo_url'])
        self.assertEqual(media.status_code, 200)
        b''.join(media.streaming_content)
        recap = self.client.get('/api/recap/', {'month': self.day.strftime('%Y-%m')})
        self.assertEqual(recap.data['dreams'], 1)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        self.assertEqual(self.client.get(result.data['report_photo_url']).status_code, 404)

    def test_hug_only_receiver_sees_latest(self):
        self.as_user(self.a)
        hug = self.client.post('/api/messages/hug/').data
        self.assertIsNone(self.client.get('/api/messages/latest-hug/').data['id'])
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/messages/latest-hug/').data['id'], hug['id'])

    def test_questions_created_without_scheduler_and_do_not_cycle(self):
        DailyQuestion.objects.filter(pk=self.question.pk).delete()
        self.as_user(self.a)
        one = self.client.get('/api/home/').data['question']
        self.assertIsNotNone(one)
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/home/').data['question'], one)
        for category, questions in QUESTIONS.items():
            self.assertEqual(len(questions), len(set(questions)))
            day = date(2026, 9, 1)
            self.assertNotEqual(category_question(category, day), category_question(category, day + timedelta(days=1)))
            self.assertIsNone(category_question(category, day + timedelta(days=len(questions))))

    def test_iphone_heic_daily_photo(self):
        from io import BytesIO
        from PIL import Image
        from django.core.files.uploadedfile import SimpleUploadedFile
        data = BytesIO()
        Image.new('RGB', (16, 16), color='pink').save(data, format='HEIF')
        self.as_user(self.a)
        result = self.client.post('/api/daily/photo/', {'photo': SimpleUploadedFile('iphone.heic', data.getvalue(), content_type='image/heic')}, format='multipart')
        self.assertEqual(result.status_code, 201)

    def test_calendar_contains_alarms_and_escaped_titles(self):
        self.as_user(self.a)
        ImportantDate.objects.create(couple=self.couple, title='Birthday, love\nBEGIN:VEVENT', date=self.day, remind_days=3)
        result = self.client.get('/api/important-dates/calendar/')
        self.assertEqual(result.status_code, 200)
        content = result.content.decode()
        self.assertIn('TRIGGER:-P3D', content)
        self.assertIn('Birthday\\, love\\nBEGIN:VEVENT', content)
        self.assertIn('months together', content)

    def test_backdated_history_updates_totals_and_rejects_overlap_atomically(self):
        self.as_user(self.a)
        today = self.day
        history = [
            {'mode': 'apart', 'start': str(today - timedelta(days=100)), 'end': str(today - timedelta(days=10))},
            {'mode': 'together', 'start': str(today - timedelta(days=10)), 'end': None},
        ]
        response = self.client.put('/api/life/', {'history': history}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['days'], {'apart': 90, 'together': 10})
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/life/').data['days']['apart'], 90)
        history[1]['start'] = str(today - timedelta(days=50))
        self.assertEqual(self.client.put('/api/life/', {'history': history}, format='json').status_code, 400)
        self.assertEqual(self.client.get('/api/life/').data['days']['apart'], 90)
        history[1]['start'] = str(today + timedelta(days=1))
        self.assertEqual(self.client.put('/api/life/', {'history': history}, format='json').status_code, 400)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        self.client.put('/api/life/', {'history': []}, format='json')
        self.as_user(self.a)
        self.assertEqual(self.client.get('/api/life/').data['days']['apart'], 90)
