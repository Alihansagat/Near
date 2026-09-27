"""Run on PostgreSQL: SQLite cannot exercise row locking."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from unittest import skipUnless
from django.db import connection, close_old_connections
from django.test import TransactionTestCase
from rest_framework.test import APIClient
from core.models import User, Couple


@skipUnless(connection.vendor == 'postgresql', 'Requires PostgreSQL row locks')
class InviteRaceTests(TransactionTestCase):
    def test_only_one_partner_can_claim_invitation(self):
        owner = User.objects.create_user('owner@example.com', 'strong-password')
        client = APIClient()
        client.force_authenticate(owner)
        response = client.post('/api/couple/', {}, format='json')
        code = response.data['invite_code']
        contenders = [User.objects.create_user(f'user{i}@example.com', 'strong-password') for i in range(2)]
        barrier = Barrier(2)

        def join(user_id):
            close_old_connections()
            try:
                user = User.objects.get(pk=user_id)
                client = APIClient()
                client.force_authenticate(user)
                barrier.wait(timeout=10)
                return client.post('/api/couple/join/', {'invite_code': code}, format='json').status_code
            finally:
                close_old_connections()

        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(join, [user.id for user in contenders]))
        self.assertEqual(sorted(results), [200, 400])
        couple = Couple.objects.get(pk=response.data['id'])
        self.assertEqual(couple.members.count(), 2)
        self.assertIn(couple.user_2_id, [user.id for user in contenders])
