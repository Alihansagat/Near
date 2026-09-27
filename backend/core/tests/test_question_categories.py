from rest_framework.test import APITestCase
from . import test_api
from core.models import DailyAnswer


class QuestionCategoryTests(APITestCase):
    setUp = test_api.CoupleApiTests.setUp
    as_user = test_api.CoupleApiTests.as_user
    photo = test_api.CoupleApiTests.photo

    def choose(self, category):
        return self.client.post('/api/daily/question/category/', {'category': category}, format='json')

    def test_all_categories_switch_persist_and_are_shared(self):
        self.as_user(self.a)
        for category in ['deep', 'fun', 'random', 'future']:
            response = self.choose(category)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.data['question']['category'], category)
            self.assertTrue(response.data['question']['question_text'])
            self.assertFalse(response.data['question_category_locked'])
        self.as_user(self.b)
        home = self.client.get('/api/home/').data
        self.assertEqual(home['question'], response.data['question'])
        self.assertEqual(self.choose('invalid').status_code, 400)
        self.as_user(self.other)
        self.client.post('/api/couple/', {}, format='json')
        self.as_user(self.other)
        self.assertEqual(self.client.get('/api/home/').data['question']['category'], 'connection')

    def test_answers_lock_category_and_archive_keeps_selected_question(self):
        self.as_user(self.a)
        chosen = self.choose('deep').data['question']
        answer = {'answer_text': 'Being heard', 'question_id': chosen['id'], 'question_category': 'deep'}
        self.assertEqual(self.client.post('/api/daily/answer/', answer, format='json').status_code, 201)
        self.as_user(self.b)
        self.assertEqual(self.choose('fun').status_code, 400)
        home = self.client.get('/api/home/').data
        self.assertTrue(home['question_category_locked'])
        self.assertIsNone(home['answers'][0]['answer_text'])
        self.assertEqual(self.client.post('/api/daily/answer/', answer, format='json').status_code, 201)
        archive = self.client.get('/api/moments/').data['results'][0]
        self.assertEqual(archive['question'], chosen)
        self.assertTrue(archive['answers_revealed'])

    def test_stale_answer_draft_is_rejected_after_partner_switches(self):
        self.as_user(self.a)
        self.choose('deep')
        self.as_user(self.b)
        self.choose('fun')
        self.as_user(self.a)
        result = self.client.post('/api/daily/answer/', {'answer_text': 'Old draft', 'question_id': self.question.id, 'question_category': 'deep'}, format='json')
        self.assertEqual(result.status_code, 400)
        self.assertFalse(DailyAnswer.objects.filter(couple=self.couple).exists())
