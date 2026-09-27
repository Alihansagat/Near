import tempfile
from datetime import timedelta
from io import BytesIO
from unittest.mock import patch
from PIL import Image
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.core.cache import cache
from django.utils import timezone
from rest_framework.test import APITestCase
from core.models import User, Couple, DailyQuestion, DailyPhotoSubmission, DailyAnswer
from core.views import day_for


class CoupleApiTests(APITestCase):
    def setUp(self):
        cache.clear()  # Throttle keys must not leak between isolated test users.
        self.media = tempfile.TemporaryDirectory()
        self.override = override_settings(MEDIA_ROOT=self.media.name, STORAGES={'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'}}, REST_FRAMEWORK={
            'DEFAULT_AUTHENTICATION_CLASSES': ['rest_framework_simplejwt.authentication.JWTAuthentication'],
            'DEFAULT_PERMISSION_CLASSES': ['rest_framework.permissions.IsAuthenticated'],
            'DEFAULT_THROTTLE_RATES': {'anon': '10000/hour', 'user': '10000/hour', 'invite': '10000/hour'},
        })
        self.override.enable()
        self.addCleanup(self.media.cleanup)
        self.addCleanup(self.override.disable)
        self.a = User.objects.create_user('a@example.com', 'some-strong-password!', full_name='Ali')
        self.b = User.objects.create_user('b@example.com', 'some-strong-password!', full_name='Aisha')
        self.other = User.objects.create_user('other@example.com', 'some-strong-password!', full_name='Other')
        self.client.force_authenticate(self.a)
        result = self.client.post('/api/couple/', {}, format='json')
        self.assertEqual(result.status_code, 201)
        self.code = result.data['invite_code']
        self.couple = Couple.objects.get(pk=result.data['id'])
        self.a.refresh_from_db()
        self.client.force_authenticate(self.b)
        self.assertEqual(self.client.post('/api/couple/join/', {'invite_code': self.code}).status_code, 200)
        self.b.refresh_from_db()
        self.couple.refresh_from_db()
        self.day = day_for(self.couple)
        self.question = DailyQuestion.objects.create(date=self.day, question_text='What made you smile?', category='connection')

    def as_user(self, user):
        user.refresh_from_db()
        self.client.force_authenticate(user)

    def photo(self):
        file = BytesIO()
        Image.new('RGB', (8, 8), color='pink').save(file, 'PNG')
        return SimpleUploadedFile('photo.png', file.getvalue(), content_type='image/png')

    def test_mascot_mood_persist_and_are_visible_only_in_own_couple(self):
        self.as_user(self.a)
        response = self.client.patch('/api/me/', {'mascot': 'female', 'mood': 'anxious'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.a.refresh_from_db()
        self.assertEqual((self.a.mascot, self.a.mood), ('female', 'anxious'))
        self.as_user(self.b)
        partner = self.client.get('/api/home/').data['couple']['user_1']
        self.assertEqual((partner['mascot'], partner['mood']), ('female', 'anxious'))
        self.assertEqual(self.client.patch('/api/me/', {'mood': 'invalid'}, format='json').status_code, 400)
        self.assertEqual(self.client.patch('/api/me/', {'mascot': 'invalid'}, format='json').status_code, 400)
        self.b.refresh_from_db()
        self.assertEqual(self.b.mood, '')
        self.as_user(self.other)
        self.assertEqual(self.client.get('/api/home/').status_code, 400)
        self.as_user(self.a)
        self.assertEqual(self.client.patch('/api/me/', {'mood': ''}, format='json').status_code, 200)
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/home/').data['couple']['user_1']['mood'], '')

    def test_invitation_consumed_and_membership_exclusive(self):
        self.as_user(self.other)
        self.assertEqual(self.client.post('/api/couple/join/', {'invite_code': self.code}).status_code, 400)
        self.as_user(self.a)
        self.assertEqual(self.client.post('/api/couple/', {}).status_code, 400)
        self.assertEqual(self.client.post('/api/couple/join/', {'invite_code': self.couple.invite_code}).status_code, 400)

    def test_photos_hidden_in_home_archive_and_direct_media(self):
        self.as_user(self.b)
        self.assertEqual(self.client.post('/api/daily/photo/', {'photo': self.photo()}, format='multipart').status_code, 201)
        photo = DailyPhotoSubmission.objects.get(user=self.b)
        self.as_user(self.a)
        home = self.client.get('/api/home/').data
        self.assertFalse(home['photos_revealed'])
        self.assertIsNone(home['photos'][0]['photo_url'])
        archive = self.client.get('/api/moments/').data
        self.assertIsNone(archive['results'][0]['photos'][0]['photo_url'])
        self.assertEqual(self.client.get(photo.photo.url).status_code, 403)
        revealed = self.client.post('/api/daily/photo/', {'photo': self.photo()}, format='multipart')
        self.assertEqual(revealed.status_code, 201)
        self.assertTrue(revealed.data['photos_revealed'])
        self.assertTrue(all(p['photo_url'] for p in revealed.data['photos']))
        self.assertEqual(self.client.get(photo.photo.url).status_code, 200)
        self.assertEqual(self.client.post('/api/daily/photo/', {'photo': self.photo()}, format='multipart').status_code, 400)

    def test_answers_unlock_only_after_both_answer(self):
        self.as_user(self.b)
        self.assertEqual(self.client.post('/api/daily/answer/', {'answer_text': 'A private thought'}).status_code, 201)
        self.as_user(self.a)
        home = self.client.get('/api/home/').data
        self.assertIsNone(home['answers'][0]['answer_text'])
        archive = self.client.get('/api/moments/').data
        self.assertIsNone(archive['results'][0]['answers'][0]['answer_text'])
        response = self.client.post('/api/daily/answer/', {'answer_text': 'My thought'})
        self.assertTrue(response.data['answers_revealed'])
        self.assertEqual(len(response.data['answers']), 2)
        self.assertEqual(self.client.post('/api/daily/answer/', {'answer_text': 'Change'}).status_code, 400)

    def test_date_permissions_and_status_machine(self):
        self.as_user(self.a)
        result = self.client.post('/api/dates/', {'type': 'movie', 'scheduled_at': (timezone.now()+timedelta(days=2)).isoformat(), 'status': 'accepted'}, format='json')
        self.assertEqual(result.status_code, 201)
        self.assertEqual(result.data['status'], 'pending')
        url = f"/api/dates/{result.data['id']}/respond/"
        self.assertEqual(self.client.post(url, {'status': 'accepted'}).status_code, 403)
        self.as_user(self.other)
        self.client.post('/api/couple/', {})
        self.other.refresh_from_db()
        self.assertEqual(self.client.post(url, {'status': 'accepted'}).status_code, 404)
        self.as_user(self.b)
        self.assertEqual(self.client.post(url, {'status': 'accepted'}).status_code, 200)
        self.assertEqual(self.client.post(url, {'status': 'declined'}).status_code, 400)

    def test_invalid_dates_answers_and_photos(self):
        self.as_user(self.a)
        self.assertEqual(self.client.post('/api/dates/', {'type': 'movie', 'scheduled_at': (timezone.now()-timedelta(days=1)).isoformat()}).status_code, 400)
        self.assertEqual(self.client.post('/api/daily/answer/', {'answer_text': '   '}).status_code, 400)
        self.assertEqual(self.client.post('/api/daily/photo/', {'photo': SimpleUploadedFile('x.jpg', b'not an image')}, format='multipart').status_code, 400)

    def test_shared_day_and_foreign_question_injection(self):
        self.couple.time_zone = 'Pacific/Kiritimati'
        self.couple.save()
        instant = timezone.datetime(2026, 1, 1, 15, tzinfo=timezone.get_default_timezone())
        with patch('core.views.timezone.now', return_value=instant):
            self.assertEqual(str(day_for(self.couple)), '2026-01-02')
        self.day = day_for(self.couple)
        self.question.date = self.day
        self.question.save(update_fields=['date'])
        foreign = DailyQuestion.objects.create(date=self.day-timedelta(days=1), question_text='Yesterday', category='x')
        self.as_user(self.a)
        response = self.client.post('/api/daily/answer/', {'answer_text': 'Today', 'question': foreign.id, 'user': self.b.id})
        self.assertEqual(response.status_code, 201)
        self.assertTrue(DailyAnswer.objects.filter(question=self.question, user=self.a).exists())

    def test_third_party_cannot_see_private_media(self):
        self.as_user(self.a)
        self.client.post('/api/daily/photo/', {'photo': self.photo()}, format='multipart')
        photo = DailyPhotoSubmission.objects.get(user=self.a)
        self.as_user(self.other)
        self.client.post('/api/couple/', {})
        self.other.refresh_from_db()
        self.assertEqual(self.client.get(photo.photo.url).status_code, 404)
        self.assertEqual(self.client.get('/api/moments/').data['count'], 0)

    def test_auth_password_validation_and_refresh_rotation(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get('/api/home/').status_code, 401)
        response = self.client.post('/api/auth/register/', {'email': 'new@example.com', 'full_name': 'New', 'password': '123'}, format='json')
        self.assertEqual(response.status_code, 400)
        tokens = self.client.post('/api/auth/token/', {'email': ' A@EXAMPLE.COM ', 'password': 'some-strong-password!'}, format='json')
        self.assertEqual(tokens.status_code, 200)
        refresh = tokens.data['refresh']
        rotated = self.client.post('/api/auth/refresh/', {'refresh': refresh}, format='json')
        self.assertEqual(rotated.status_code, 200)
        self.assertEqual(self.client.post('/api/auth/refresh/', {'refresh': refresh}).status_code, 401)

    def test_solo_couple_never_reveals(self):
        self.as_user(self.other)
        self.client.post('/api/couple/', {})
        self.other.refresh_from_db()
        result = self.client.post('/api/daily/answer/', {'answer_text': 'Just me'})
        self.assertFalse(result.data['answers_revealed'])

    def test_invalid_time_zone(self):
        self.as_user(self.a)
        self.assertEqual(self.client.patch('/api/couple/', {'time_zone': 'Not/AZone'}, format='json').status_code, 400)

    def test_countdown_categories_do_not_replace_next_meeting(self):
        self.as_user(self.a)
        for kind, days in [('birthday', 1), ('meeting', 12), ('trip', 30)]:
            response = self.client.post('/api/meetings/', {'kind': kind, 'title': kind, 'target_date': str(self.day + timedelta(days=days))})
            self.assertEqual(response.status_code, 201)
        home = self.client.get('/api/home/').data
        self.assertEqual(home['days_until_meeting'], 12)
        self.assertEqual(home['meeting']['kind'], 'meeting')

    def test_reschedule_requires_partner_and_returns_invitation_to_sender(self):
        self.as_user(self.a)
        invitation = self.client.post('/api/dates/', {'type': 'coffee', 'detail': 'Our favorite cafe', 'scheduled_at': (timezone.now()+timedelta(days=2)).isoformat()}).data
        url = f"/api/dates/{invitation['id']}/reschedule/"
        data = {'scheduled_at': (timezone.now()+timedelta(days=3)).isoformat()}
        self.assertEqual(self.client.post(url, data).status_code, 403)
        self.as_user(self.b)
        self.assertEqual(self.client.post(url, {'scheduled_at': (timezone.now()-timedelta(days=1)).isoformat()}).status_code, 400)
        response = self.client.post(url, data)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['creator'], self.b.id)
        self.assertEqual(response.data['detail'], 'Our favorite cafe')
        self.assertEqual(self.client.post(url, data).status_code, 403)
        self.as_user(self.a)
        self.assertEqual(self.client.post(f"/api/dates/{invitation['id']}/respond/", {'status': 'accepted'}).status_code, 200)

    def test_home_photo_expires_after_24_hours_but_stays_in_memories(self):
        self.as_user(self.a)
        self.client.post('/api/daily/photo/', {'photo': self.photo()}, format='multipart')
        self.assertIsNotNone(self.client.get('/api/home/').data['recent_photo_day'])
        DailyPhotoSubmission.objects.filter(user=self.a).update(day=self.day-timedelta(days=1), created_at=timezone.now()-timedelta(hours=25))
        self.assertIsNone(self.client.get('/api/home/').data['recent_photo_day'])
        self.assertEqual(self.client.get('/api/moments/').data['count'], 1)

    def test_month_capsule_is_complete_chronological_and_private(self):
        from datetime import date
        self.as_user(self.a)
        for number in range(1, 32):
            day = date(2025, 1, number)
            question = DailyQuestion.objects.create(date=day, question_text='A memory', category='fun')
            DailyAnswer.objects.create(question=question, couple=self.couple, user=self.a, answer_text=str(number))
        capsule = self.client.get('/api/moments/?month=2025-01').data
        self.assertEqual(capsule['count'], 31)
        self.assertEqual(capsule['results'][0]['day'], '2025-01-01')
        self.assertEqual(capsule['results'][-1]['day'], '2025-01-31')
        self.assertIsNone(capsule['next'])
        self.assertEqual(self.client.get('/api/moments/?month=bad').status_code, 400)
        self.as_user(self.other)
        self.client.post('/api/couple/', {})
        self.other.refresh_from_db()
        self.assertEqual(self.client.get('/api/moments/?month=2025-01').data['count'], 0)
