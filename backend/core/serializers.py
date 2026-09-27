from django.contrib.auth.password_validation import validate_password
from django.utils import timezone
from rest_framework import serializers
from .models import User, Couple, DailyPhotoSubmission, DailyAnswer, VirtualDate, MeetingCountdown


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'email', 'full_name', 'avatar', 'mascot', 'mood', 'mood_day', 'latitude', 'longitude', 'time_zone', 'couple']
        read_only_fields = ['id', 'email', 'couple', 'mood_day']


    def validate(self, attrs):
        for key, bound in [('latitude', 90), ('longitude', 180)]:
            if attrs.get(key) is not None and not -bound <= attrs[key] <= bound:
                raise serializers.ValidationError({key: 'Invalid coordinate.'})
        lat = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        lon = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        if (lat is None) != (lon is None):
            raise serializers.ValidationError('Provide both coordinates.')
        return attrs

    def update(self, instance, validated_data):
        if 'mood' in validated_data:
            from zoneinfo import ZoneInfo
            zone = instance.couple.time_zone if instance.couple_id else instance.time_zone
            validated_data['mood_day'] = timezone.now().astimezone(ZoneInfo(zone)).date() if validated_data['mood'] else None
        return super().update(instance, validated_data)


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, max_length=128)

    class Meta:
        model = User
        fields = ['email', 'password', 'full_name', 'time_zone']

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('Email already registered.')
        return value

    def validate(self, attrs):
        validate_password(attrs['password'], User(email=attrs['email'], full_name=attrs['full_name']))
        return attrs

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class CoupleSerializer(serializers.ModelSerializer):
    user_1 = UserSerializer(read_only=True)
    user_2 = UserSerializer(read_only=True)

    class Meta:
        model = Couple
        fields = ['id', 'user_1', 'user_2', 'relationship_start_date', 'distance_start_date', 'invite_code', 'time_zone', 'distance_km']
        read_only_fields = ['id', 'invite_code']

    def validate_relationship_start_date(self, value):
        if value > timezone.localdate():
            raise serializers.ValidationError('Relationship start cannot be in the future.')
        return value


class DailyPhotoSubmissionSerializer(serializers.ModelSerializer):
    photo_url = serializers.SerializerMethodField()

    class Meta:
        model = DailyPhotoSubmission
        fields = ['id', 'user', 'day', 'photo_url', 'created_at']

    def get_photo_url(self, obj):
        # Defense in depth: never expose the partner's storage URL before reveal.
        if obj.user_id != self.context['request'].user.id and not self.context.get('revealed', False):
            return None
        return obj.photo_url


class DailyAnswerSerializer(serializers.ModelSerializer):
    answer_text = serializers.SerializerMethodField()

    class Meta:
        model = DailyAnswer
        fields = ['id', 'question', 'user', 'answer_text', 'created_at']

    def get_answer_text(self, obj):
        if obj.user_id != self.context['request'].user.id and not self.context.get('revealed', False):
            return None
        return obj.answer_text


class VirtualDateSerializer(serializers.ModelSerializer):
    class Meta:
        model = VirtualDate
        fields = ['id', 'couple', 'creator', 'type', 'scheduled_at', 'status', 'note', 'detail']
        read_only_fields = ['id', 'couple', 'creator', 'status']

    def validate_scheduled_at(self, value):
        if value <= timezone.now():
            raise serializers.ValidationError('Choose a future time.')
        return value


class MeetingSerializer(serializers.ModelSerializer):
    class Meta:
        model = MeetingCountdown
        fields = ['id', 'target_date', 'title', 'location', 'kind']
        read_only_fields = ['id']
