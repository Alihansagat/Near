from django.core.files.uploadedfile import SimpleUploadedFile
from . import test_api
from rest_framework.test import APITestCase


class RelationshipTests(APITestCase):
    setUp = test_api.CoupleApiTests.setUp
    as_user = test_api.CoupleApiTests.as_user
    photo = test_api.CoupleApiTests.photo

    def test_mood_daily_stamp(self):
        self.as_user(self.a)
        response = self.client.patch('/api/me/', {'mood': 'sad'}, format='json')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['mood_day'], str(self.day))
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/home/').data['couple']['user_1']['mood'], 'sad')

    def test_story_order_and_private_photo(self):
        self.as_user(self.a)
        later = self.client.post('/api/story/', {'date': '2025-09-22', 'text': 'Today', 'emoji': '❤️', 'photo': self.photo()}, format='multipart')
        self.assertEqual(later.status_code, 201)
        self.client.post('/api/story/', {'date': '2025-01-16', 'text': 'We met', 'location': 'Almaty'}, format='json')
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/story/').data['results'][0]['text'], 'We met')
        url = later.data['photo_url']
        response = self.client.get(url)
        self.assertEqual(response.status_code, 200)
        b''.join(response.streaming_content)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.other.refresh_from_db()
        self.as_user(self.other)
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(self.client.get('/api/story/').data['count'], 0)

    def test_envelope_all_media_and_custom_title(self):
        self.as_user(self.a)
        response = self.client.post('/api/envelopes/', {'title': 'Open when you need a smile', 'text': 'Love you', 'files': [self.photo(), SimpleUploadedFile('voice.wav', b'RIFFtest', content_type='audio/wav'), SimpleUploadedFile('movie.mp4', b'video', content_type='video/mp4')]}, format='multipart')
        self.assertEqual(response.status_code, 201)
        self.assertEqual({a['kind'] for a in response.data['attachments']}, {'photo', 'audio', 'video'})
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/envelopes/').data['count'], 1)
        for attachment in response.data['attachments']:
            media = self.client.get(attachment['url'])
            self.assertEqual(media.status_code, 200)
            b''.join(media.streaming_content)
        self.as_user(self.a)
        self.assertEqual(self.client.post('/api/envelopes/', {'title': 'Empty'}, format='json').status_code, 400)
        self.assertEqual(self.client.post('/api/envelopes/', {'title': 'Bad', 'files': [SimpleUploadedFile('bad.html', b'<html>')]}, format='multipart').status_code, 400)

    def test_hug_messages_coordinates_and_wishlist(self):
        self.as_user(self.a)
        self.assertEqual(self.client.post('/api/messages/hug/').status_code, 201)
        self.as_user(self.b)
        self.assertEqual(self.client.get('/api/messages/').data['results'][0]['text'], '🫂')
        self.assertEqual(self.client.patch('/api/me/', {'latitude': 100, 'longitude': 10}, format='json').status_code, 400)
        self.assertEqual(self.client.patch('/api/me/', {'latitude': 40}, format='json').status_code, 400)
        self.assertEqual(self.client.patch('/api/me/', {'latitude': 40, 'longitude': 10}, format='json').status_code, 200)
        self.assertEqual(self.client.post('/api/places/', {'title': 'First date', 'latitude': 40, 'longitude': 10}, format='json').status_code, 201)
        wish = self.client.post('/api/wishlist/', {'title': 'See the sea'}, format='json')
        self.as_user(self.a)
        self.assertEqual(self.client.patch(f"/api/wishlist/{wish.data['id']}/", {'completed': True}, format='json').status_code, 200)

    def test_media_ranges_and_couple_isolation(self):
        self.as_user(self.a)
        envelope = self.client.post('/api/envelopes/', {'title': 'Open when you miss me', 'files': [SimpleUploadedFile('voice.wav', b'0123456789', content_type='audio/wav')]}, format='multipart')
        url = envelope.data['attachments'][0]['url']
        for header, expected, content_range in [('bytes=2-5', b'2345', 'bytes 2-5/10'), ('bytes=-3', b'789', 'bytes 7-9/10'), ('bytes=7-', b'789', 'bytes 7-9/10')]:
            response = self.client.get(url, HTTP_RANGE=header)
            self.assertEqual(response.status_code, 206)
            self.assertEqual(response['Content-Range'], content_range)
            self.assertEqual(b''.join(response.streaming_content), expected)
        self.assertEqual(self.client.get(url, HTTP_RANGE='bytes=20-30').status_code, 416)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        self.assertEqual(self.client.get(url).status_code, 404)
        self.assertEqual(self.client.get(url, HTTP_RANGE='bytes=0-1').status_code, 404)
        self.assertEqual(self.client.get(f"/api/envelopes/{envelope.data['id']}/").status_code, 404)
        self.assertEqual(self.client.get('/api/envelopes/').data['count'], 0)
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(url).status_code, 401)

    def test_shared_records_cannot_be_changed_by_another_couple(self):
        self.as_user(self.a)
        wish = self.client.post('/api/wishlist/', {'title': 'First trip'}, format='json')
        place = self.client.post('/api/places/', {'title': 'First date', 'latitude': 10, 'longitude': 20}, format='json')
        self.assertEqual(self.client.post('/api/places/', {'title': 'Invalid', 'latitude': 'NaN', 'longitude': 20}, format='json').status_code, 400)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        for path in [f"/api/wishlist/{wish.data['id']}/", f"/api/places/{place.data['id']}/"]:
            self.assertEqual(self.client.patch(path, {'title': 'Changed'}, format='json').status_code, 404)
            self.assertEqual(self.client.delete(path).status_code, 404)
