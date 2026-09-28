"""Deterministic daily prompts; no AI subscription or scheduler required."""
from datetime import date
from itertools import product

TOPICS = [
    'our first conversation', 'our first date', 'a rainy afternoon', 'a weekend away',
    'our favorite song', 'a homemade dinner', 'a childhood memory', 'a difficult week',
    'our next trip', 'a quiet morning', 'a surprise visit', 'our shared home',
    'a family tradition', 'a new hobby', 'a small celebration', 'an unexpected kindness',
    'a place we love', 'an adventure outdoors', 'a personal goal', 'a funny misunderstanding',
    'a perfect evening', 'a handmade gift', 'a long phone call', 'our next anniversary',
    'a comforting routine', 'a favorite photograph', 'a lesson we learned', 'a dream we share',
    'a meal from another country', 'a day without our phones', 'a winter holiday', 'a summer evening',
    'a new city', 'a favorite book', 'a movie night', 'a moment of courage',
    'a meaningful compliment', 'a time we helped each other', 'a new beginning', 'an ordinary Tuesday',
]
TEMPLATES = {
 'fun': ['What playful challenge could we invent around {}?', 'What would a comedy scene about {} look like?', 'What unexpected twist would you add to {}?', 'What nickname would you give a story about {}?', 'What would we pack for an adventure inspired by {}?', 'What song would be the soundtrack to {}?'],
 'deep': ['What does {} teach you about feeling loved?', 'What would you like me to understand about {}?', 'What emotion comes up when you imagine {}?', 'How could we support each other through {}?', 'What personal value do you associate with {}?', 'What would make you feel safe sharing a story about {}?'],
 'future': ['How would you like us to plan {}?', 'What tradition could we build around {}?', 'What small step could bring us closer to {}?', 'How would you make space in our life for {}?', 'What would you want to remember in five years about {}?', 'What would make our version of {} uniquely ours?'],
 'random': ['What color comes to mind when you think of {}?', 'What scent reminds you of {}?', 'What tiny detail would you notice first about {}?', 'Who would you invite to share a story about {}?', 'What question would you ask me about {}?', 'What object would you keep to remember {}?'],
}
PERSPECTIVES = ['', ' What would you want me to notice?', ' How would your answer have differed a year ago?', ' What is one thing we could try today?', ' Which part matters most to you?', ' What would you like to ask me in return?', ' How could we make this easier while apart?', ' How would this feel when we are together?']
QUESTIONS = {key: [template.format(topic) + perspective for perspective, template, topic in product(PERSPECTIVES, templates, TOPICS)] for key, templates in TEMPLATES.items()}


def category_question(category, day):
    # Each category has 1,920 distinct prompts. Never silently cycle the bank.
    options = QUESTIONS[category]
    index = (day - date(2026, 9, 1)).days
    if index < 0:
        index = 0
    if index >= len(options):
        return None
    return options[index]


def ensure_daily_question(day):
    from .models import DailyQuestion
    category = list(QUESTIONS)[day.toordinal() % 4]
    text = category_question(category, day)
    if text is None:
        return DailyQuestion.objects.filter(date=day).first()
    return DailyQuestion.objects.get_or_create(date=day, defaults={
        'category': category, 'question_text': text,
    })[0]
