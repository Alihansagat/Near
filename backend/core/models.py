import secrets
import uuid
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.core.exceptions import ValidationError
from django.db import models
from django.db.models import Q, F
from django.db.models.functions import Lower
from django.utils import timezone


def invite_code():
    return secrets.token_urlsafe(18)


def private_photo_path(instance, filename):
    return f'couples/{instance.couple_id}/{uuid.uuid4().hex}.jpg'


def validate_time_zone(value):
    try:
        ZoneInfo(value)
    except (ZoneInfoNotFoundError, ValueError):
        raise ValidationError('Use an IANA time zone, e.g. Asia/Almaty.')


class UserManager(BaseUserManager):
    use_in_migrations = True

    def create_user(self, email, password=None, **extra):
        if not email:
            raise ValueError('Email is required.')
        user = self.model(email=email.strip().lower(), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra):
        extra.update(is_staff=True, is_superuser=True)
        return self.create_user(email, password, **extra)


class User(AbstractUser):
    username = None
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=120)
    avatar = models.URLField(blank=True)
    mascot = models.CharField(max_length=8, blank=True, default='', choices=[('male', 'Male'), ('female', 'Female')])
    mood = models.CharField(max_length=12, blank=True, default='', choices=[
        ('joyful', 'Happy'), ('loving', 'Loved'), ('missing', 'Missing you'),
        ('anxious', 'Anxious'), ('sleepy', 'Tired'), ('angry', 'Angry'), ('sad', 'Sad'),
    ])
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    mood_day = models.DateField(null=True, blank=True)
    time_zone = models.CharField(max_length=64, default='UTC', validators=[validate_time_zone])
    # One canonical membership enforces that nobody can belong to two couples.
    couple = models.ForeignKey('Couple', null=True, blank=True, on_delete=models.SET_NULL, related_name='members')
    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['full_name']
    objects = UserManager()

    class Meta:
        constraints = [models.UniqueConstraint(Lower('email'), name='unique_email_ci')]


class Couple(models.Model):
    user_1 = models.OneToOneField(User, on_delete=models.PROTECT, related_name='started_couple')
    user_2 = models.OneToOneField(User, null=True, blank=True, on_delete=models.PROTECT, related_name='joined_couple')
    relationship_start_date = models.DateField(default=timezone.localdate)
    distance_start_date = models.DateField(null=True, blank=True)
    invite_code = models.CharField(max_length=64, unique=True, default=invite_code)
    time_zone = models.CharField(max_length=64, default='UTC', validators=[validate_time_zone])
    distance_km = models.PositiveIntegerField(null=True, blank=True)

    class Meta:
        constraints = [models.CheckConstraint(condition=~Q(user_1=F('user_2')), name='different_partners')]


class MeetingCountdown(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE, related_name='meetings')
    target_date = models.DateField()
    title = models.CharField(max_length=160)
    location = models.CharField(max_length=200, blank=True)
    kind = models.CharField(max_length=16, default='meeting', choices=[('meeting', 'Next meeting'), ('anniversary', 'Anniversary'), ('birthday', 'Birthday'), ('trip', 'Trip'), ('other', 'Other')])


class DailyPhotoPrompt(models.Model):
    prompt_text = models.CharField(max_length=250)
    date = models.DateField(unique=True)


class DailyPhotoSubmission(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    day = models.DateField()
    # Store a private object key, never a permanent public URL.
    photo = models.ImageField(upload_to=private_photo_path)
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def photo_url(self):
        return self.photo.url

    class Meta:
        constraints = [models.UniqueConstraint(fields=['couple', 'user', 'day'], name='one_photo_per_day')]
        ordering = ['-day', 'id']


class DailyQuestion(models.Model):
    question_text = models.CharField(max_length=500)
    category = models.CharField(max_length=60)
    date = models.DateField(unique=True)


class DailyAnswer(models.Model):
    question = models.ForeignKey(DailyQuestion, on_delete=models.CASCADE)
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    answer_text = models.TextField(max_length=5000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['question', 'user'], name='one_answer_per_question')]
        ordering = ['-created_at']


class VirtualDate(models.Model):
    class Type(models.TextChoices):
        MOVIE = 'movie', 'Movie'
        DINNER = 'dinner', 'Dinner'
        GAMING = 'gaming', 'Gaming'
        COFFEE = 'coffee', 'Coffee'
        MUSIC = 'music', 'Music'
        QUIZ = 'quiz', 'Quiz'
        TALK = 'talk', 'Just talk'
        SURPRISE = 'surprise', 'Surprise'
        WALK = 'walk', 'Walk'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        ACCEPTED = 'accepted', 'Accepted'
        DECLINED = 'declined', 'Declined'

    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    creator = models.ForeignKey(User, on_delete=models.CASCADE)
    type = models.CharField(max_length=16, choices=Type.choices)
    scheduled_at = models.DateTimeField()
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.PENDING)
    detail = models.CharField(max_length=200, blank=True)
    note = models.TextField(max_length=2000, blank=True)

    class Meta:
        ordering = ['scheduled_at', 'id']


def relationship_media_path(instance, filename):
    from pathlib import Path
    return f'relationship/{uuid.uuid4().hex}{Path(filename).suffix.lower()}'


class Envelope(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    creator = models.ForeignKey(User, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    text = models.TextField(max_length=10000, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at', '-id']


class EnvelopeAttachment(models.Model):
    envelope = models.ForeignKey(Envelope, on_delete=models.CASCADE, related_name='attachments')
    file = models.FileField(upload_to=relationship_media_path)
    kind = models.CharField(max_length=10, choices=[('photo', 'Photo'), ('video', 'Video'), ('audio', 'Voice message')])
    name = models.CharField(max_length=255)


class StoryEntry(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    date = models.DateField()
    photo = models.ImageField(upload_to=relationship_media_path, blank=True)
    location = models.CharField(max_length=200, blank=True)
    text = models.TextField(max_length=5000)
    emoji = models.CharField(max_length=32, default='❤️')

    class Meta:
        ordering = ['date', 'id']


class PartnerMessage(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    text = models.TextField(max_length=5000)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at', '-id']


class MapPlace(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    latitude = models.FloatField()
    longitude = models.FloatField()

    class Meta:
        ordering = ['id']


class WishlistItem(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    completed = models.BooleanField(default=False)

    class Meta:
        ordering = ['completed', 'id']


class DailyQuestionChoice(models.Model):
    couple = models.ForeignKey(Couple, on_delete=models.CASCADE)
    question = models.ForeignKey(DailyQuestion, on_delete=models.CASCADE)
    category = models.CharField(max_length=16)
    question_text = models.CharField(max_length=500)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['couple', 'question'], name='one_question_choice_per_couple_day')]
