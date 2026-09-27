from datetime import timedelta
from rest_framework.test import APITestCase
from . import test_api


class CountdownEditTests(APITestCase):
    setUp = test_api.CoupleApiTests.setUp
    as_user = test_api.CoupleApiTests.as_user
    photo = test_api.CoupleApiTests.photo

    def test_edit_and_delete_update_next_meeting_for_both_partners(self):
        self.as_user(self.a)
        first = self.client.post('/api/meetings/', {'title': 'First', 'kind': 'meeting', 'location': 'Almaty', 'target_date': str(self.day + timedelta(days=10))}, format='json').data
        second = self.client.post('/api/meetings/', {'title': 'Second', 'kind': 'meeting', 'target_date': str(self.day + timedelta(days=20))}, format='json').data
        url = f"/api/meetings/{first['id']}/"
        self.as_user(self.b)
        response = self.client.patch(url, {'title': 'Updated', 'location': 'Paris', 'target_date': str(self.day + timedelta(days=5))}, format='json')
        self.assertEqual(response.status_code, 200)
        home = self.client.get('/api/home/').data
        self.assertEqual(home['meeting']['title'], 'Updated')
        self.assertEqual(home['meeting']['location'], 'Paris')
        self.assertEqual(home['days_until_meeting'], 5)
        self.assertEqual(self.client.get('/api/meetings/').data['count'], 2)
        self.assertEqual(self.client.patch(url, {'kind': 'trip'}, format='json').status_code, 200)
        self.assertEqual(self.client.get('/api/home/').data['meeting']['id'], second['id'])
        self.assertEqual(self.client.delete(url).status_code, 204)
        self.assertEqual(self.client.delete(f"/api/meetings/{second['id']}/").status_code, 204)
        self.as_user(self.a)
        self.assertIsNone(self.client.get('/api/home/').data['meeting'])
        self.assertIsNone(self.client.get('/api/home/').data['days_until_meeting'])

    def test_foreign_couple_cannot_edit_or_delete_countdown(self):
        self.as_user(self.a)
        event = self.client.post('/api/meetings/', {'title': 'Private', 'target_date': str(self.day + timedelta(days=1))}, format='json').data
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        url = f"/api/meetings/{event['id']}/"
        self.assertEqual(self.client.patch(url, {'title': 'Changed'}, format='json').status_code, 404)
        self.assertEqual(self.client.delete(url).status_code, 404)
