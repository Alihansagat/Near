"""Daily category choices, shared by both partners and stable for the day."""
QUESTIONS = {
    'fun': ['If we could travel anywhere tomorrow, where would we go?', 'What do you want us to do together?'],
    'deep': ['What makes you feel loved?', 'How can I support you this week?'],
    'future': ['Where do you imagine us living in 5 years?', 'What would our perfect Sunday look like?'],
    'random': ['What is the weirdest thing you did today?', 'What little thing made you smile today?'],
}


def category_question(category, day):
    options = QUESTIONS[category]
    return options[day.toordinal() % len(options)]
