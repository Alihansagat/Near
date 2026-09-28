from pillow_heif import register_heif_opener
from datetime import timedelta
from io import BytesIO
from zoneinfo import ZoneInfo
from PIL import Image, ImageOps, UnidentifiedImageError
from django.core.files.base import ContentFile
from django.db import transaction, IntegrityError
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, serializers, status, viewsets
from rest_framework.decorators import api_view, action, permission_classes
from rest_framework.exceptions import ValidationError, PermissionDenied
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.views import TokenObtainPairView
from .models import User, Couple, MeetingCountdown, DailyPhotoPrompt, DailyPhotoSubmission, DailyQuestion, DailyAnswer, VirtualDate, invite_code, DailyQuestionChoice
from .serializers import UserSerializer, RegisterSerializer, CoupleSerializer, DailyPhotoSubmissionSerializer, DailyAnswerSerializer, VirtualDateSerializer, MeetingSerializer

register_heif_opener(thumbnails=False)


@api_view(['GET'])
@permission_classes([AllowAny])
def health(request):
    return Response({'status': 'ok'})


def couple_for(user):
    if not user.couple_id:
        raise ValidationError({'couple': 'Create or join a couple first.'})
    return Couple.objects.get(pk=user.couple_id)


def day_for(couple):
    return timezone.now().astimezone(ZoneInfo(couple.time_zone)).date()


def both(couple, rows):
    return couple.user_2_id is not None and {couple.user_1_id, couple.user_2_id}.issubset({r.user_id for r in rows})


class LoginView(TokenObtainPairView):
    def post(self, request, *args, **kwargs):
        data = request.data.copy()
        if isinstance(data.get('email'), str):
            data['email'] = data['email'].strip().lower()
        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)
        return Response(serializer.validated_data)


class RegisterView(generics.CreateAPIView):
    permission_classes = [AllowAny]
    serializer_class = RegisterSerializer

    def perform_create(self, serializer):
        try:
            with transaction.atomic():
                serializer.save()
        except IntegrityError:
            raise ValidationError({'email': 'Email already registered.'})


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    def get_object(self):
        return self.request.user


@api_view(['POST'])
def logout(request):
    refresh = request.data.get('refresh')
    try:
        token = RefreshToken(refresh)
        if str(token['user_id']) != str(request.user.id):
            raise PermissionDenied()
        token.blacklist()
    except (TypeError, KeyError, TokenError):
        raise ValidationError('Invalid refresh token.')
    return Response(status=204)


class CoupleView(APIView):
    def get(self, request):
        return Response(CoupleSerializer(couple_for(request.user)).data)

    @transaction.atomic
    def post(self, request):
        user = User.objects.select_for_update().get(pk=request.user.pk)
        if user.couple_id:
            raise ValidationError('Already in a couple.')
        serializer = CoupleSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        couple = serializer.save(user_1=user, time_zone=user.time_zone)
        user.couple = couple
        user.save(update_fields=['couple'])
        return Response(CoupleSerializer(couple).data, status=201)

    def patch(self, request):
        serializer = CoupleSerializer(couple_for(request.user), data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class InviteThrottle(UserRateThrottle):
    scope = 'invite'


class JoinCoupleView(APIView):
    throttle_classes = [InviteThrottle]

    @transaction.atomic
    def post(self, request):
        user = User.objects.select_for_update().get(pk=request.user.pk)
        if user.couple_id:
            raise ValidationError('Already in a couple.')
        code = request.data.get('invite_code')
        if not isinstance(code, str) or not 10 <= len(code) <= 64:
            raise ValidationError('Invalid invitation.')
        couple = Couple.objects.select_for_update().filter(invite_code=code).first()
        if not couple or couple.user_2_id or couple.user_1_id == user.id:
            raise ValidationError('Invitation unavailable.')
        couple.user_2 = user
        couple.invite_code = invite_code()  # Consume the original invitation.
        couple.save(update_fields=['user_2', 'invite_code'])
        user.couple = couple
        user.save(update_fields=['couple'])
        return Response(CoupleSerializer(couple).data)


class RotateInviteView(APIView):
    def post(self, request):
        couple = couple_for(request.user)
        couple.invite_code = invite_code()
        couple.save(update_fields=['invite_code'])
        return Response({'invite_code': couple.invite_code})


def question_details(couple, question):
    if question is None:
        return None
    choice = DailyQuestionChoice.objects.filter(couple=couple, question=question).first()
    return {
        'id': question.id,
        'question_text': choice.question_text if choice else question.question_text,
        'category': choice.category if choice else question.category,
    }


def daily_payload(request, couple, day):
    photos = list(DailyPhotoSubmission.objects.filter(couple=couple, day=day))
    from .question_content import ensure_daily_question
    question = ensure_daily_question(day) if day == day_for(couple) else DailyQuestion.objects.filter(date=day).first()
    answers = list(DailyAnswer.objects.filter(couple=couple, question=question)) if question else []
    photo_reveal, answer_reveal = both(couple, photos), both(couple, answers)
    prompt = DailyPhotoPrompt.objects.filter(date=day).first()
    return {
        'day': str(day), 'photo_prompt': prompt.prompt_text if prompt else 'A little piece of your day',
        'photos': DailyPhotoSubmissionSerializer(photos, many=True, context={'request': request, 'revealed': photo_reveal}).data,
        'photos_revealed': photo_reveal,
        'question': question_details(couple, question),
        'question_category_locked': bool(answers),
        'answers': DailyAnswerSerializer(answers, many=True, context={'request': request, 'revealed': answer_reveal}).data,
        'answers_revealed': answer_reveal,
    }


class HomeView(APIView):
    def get(self, request):
        couple = couple_for(request.user)
        day = day_for(couple)
        meeting = couple.meetings.filter(target_date__gte=day, kind='meeting').order_by('target_date').first()
        # Home keeps the latest photo ritual for 24 hours; archive remains permanent.
        recent = DailyPhotoSubmission.objects.filter(couple=couple, created_at__gt=timezone.now()-timedelta(hours=24)).order_by('-day').first()
        recent_photos = daily_payload(request, couple, recent.day) if recent else None
        if recent_photos:
            recent_photos['photos'] = [p for p in recent_photos['photos'] if timezone.datetime.fromisoformat(p['created_at'].replace('Z', '+00:00')) > timezone.now()-timedelta(hours=24)]
            recent_photos['photos_revealed'] = len(recent_photos['photos']) == 2
        next_date = VirtualDate.objects.filter(couple=couple, scheduled_at__gt=timezone.now(), status__in=['pending', 'accepted']).order_by('scheduled_at').first()
        return Response({'next_date': VirtualDateSerializer(next_date).data if next_date else None, 'recent_photo_day': recent_photos, 'couple': CoupleSerializer(couple).data, 'days_apart': max(0, (day - couple.distance_start_date).days) if couple.distance_start_date else None, 'days_together': max(0, (day - couple.relationship_start_date).days), 'meeting': MeetingSerializer(meeting).data if meeting else None, 'days_until_meeting': (meeting.target_date - day).days if meeting else None, **daily_payload(request, couple, day)})


class SubmitPhotoView(APIView):
    @transaction.atomic
    def post(self, request):
        couple = Couple.objects.select_for_update().get(pk=couple_for(request.user).pk)
        day = day_for(couple)
        if DailyPhotoSubmission.objects.filter(couple=couple, user=request.user, day=day).exists():
            raise ValidationError('Photo already submitted today.')
        upload = request.FILES.get('photo')
        if not upload or upload.size > 10 * 1024 * 1024:
            raise ValidationError('Upload an image up to 10 MB.')
        # Decode, resize and re-encode: strips EXIF/GPS and rejects disguised files.
        try:
            with Image.open(upload) as image:
                if image.width * image.height > 25_000_000:
                    raise ValidationError('Image exceeds 25 megapixels.')
                image = ImageOps.exif_transpose(image).convert('RGB')
                image.thumbnail((2048, 2048))
                buffer = BytesIO()
                image.save(buffer, format='JPEG', quality=88)
        except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
            raise ValidationError('Invalid image.')
        submission = DailyPhotoSubmission(couple=couple, user=request.user, day=day)
        submission.photo.save('photo.jpg', ContentFile(buffer.getvalue()), save=False)
        try:
            submission.save()
        except Exception:
            submission.photo.delete(save=False)
            raise
        return Response(daily_payload(request, couple, day), status=201)


class ChooseQuestionCategoryView(APIView):
    @transaction.atomic
    def post(self, request):
        from .question_content import QUESTIONS, category_question
        couple = Couple.objects.select_for_update().get(pk=couple_for(request.user).pk)
        category = serializers.ChoiceField(choices=list(QUESTIONS)).run_validation(request.data.get('category'))
        day = day_for(couple)
        if category_question(category, day) is None:
            raise ValidationError('You have explored every question in this collection. More questions are needed.')
        question, _ = DailyQuestion.objects.get_or_create(date=day, defaults={
            'category': 'random', 'question_text': category_question('random', day),
        })
        current = question_details(couple, question)
        if category == current['category']:
            return Response(daily_payload(request, couple, day))
        if DailyAnswer.objects.filter(couple=couple, question=question).exists():
            raise ValidationError('A partner has already answered. Choose a new category tomorrow.')
        DailyQuestionChoice.objects.update_or_create(couple=couple, question=question, defaults={
            'category': category, 'question_text': question.question_text if category == question.category else category_question(category, day),
        })
        return Response(daily_payload(request, couple, day))


class SubmitAnswerView(APIView):
    @transaction.atomic
    def post(self, request):
        couple = Couple.objects.select_for_update().get(pk=couple_for(request.user).pk)
        question = get_object_or_404(DailyQuestion, date=day_for(couple))
        current = question_details(couple, question)
        if (('question_id' in request.data and str(request.data['question_id']) != str(question.id)) or
                ('question_category' in request.data and request.data['question_category'] != current['category'])):
            raise ValidationError('The question changed. Refresh and answer the current question.')
        field = serializers.CharField(max_length=5000, allow_blank=False)
        answer = field.run_validation(request.data.get('answer_text'))
        if DailyAnswer.objects.filter(question=question, user=request.user).exists():
            raise ValidationError('Already answered today.')
        DailyAnswer.objects.create(question=question, couple=couple, user=request.user, answer_text=answer)
        return Response(daily_payload(request, couple, day_for(couple)), status=201)


class MomentsView(APIView):
    def get(self, request):
        couple = couple_for(request.user)
        try:
            page = max(1, int(request.query_params.get('page', '1')))
        except ValueError:
            raise ValidationError('Invalid page.')
        photos = DailyPhotoSubmission.objects.filter(couple=couple).order_by().values_list('day', flat=True)
        answers = DailyAnswer.objects.filter(couple=couple).order_by().values_list('question__date', flat=True)
        month = request.query_params.get('month')
        if month:
            try:
                start = timezone.datetime.strptime(month, '%Y-%m').date().replace(day=1)
                if month != start.strftime('%Y-%m'):
                    raise ValueError()
            except ValueError:
                raise ValidationError('Use month YYYY-MM.')
            end = (start.replace(day=28) + timedelta(days=4)).replace(day=1)
            photos = photos.filter(day__gte=start, day__lt=end)
            answers = answers.filter(question__date__gte=start, question__date__lt=end)
            days = photos.union(answers).order_by('day')
            return Response({'count': days.count(), 'next': None, 'results': [daily_payload(request, couple, day) for day in days]})
        days = photos.union(answers).order_by('-day')
        count = days.count()
        selected = days[(page-1)*20:page*20]
        return Response({'count': count, 'next': page+1 if count>page*20 else None, 'results': [daily_payload(request, couple, day) for day in selected]})


class VirtualDateViewSet(viewsets.ModelViewSet):
    serializer_class = VirtualDateSerializer
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        return VirtualDate.objects.filter(couple=couple_for(self.request.user))

    def perform_create(self, serializer):
        couple = couple_for(self.request.user)
        if not couple.user_2_id:
            raise ValidationError('Invite your partner first.')
        serializer.save(couple=couple, creator=self.request.user)

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def reschedule(self, request, pk=None):
        date = get_object_or_404(self.get_queryset().select_for_update(), pk=pk)
        if date.creator_id == request.user.id:
            raise PermissionDenied('Only the invited partner can suggest another time.')
        if date.status != 'pending' or date.scheduled_at <= timezone.now():
            raise ValidationError('This invitation is no longer pending.')
        field = serializers.DateTimeField()
        proposed = field.run_validation(request.data.get('scheduled_at'))
        if proposed <= timezone.now():
            raise ValidationError('Choose a future time.')
        date.scheduled_at = proposed
        date.creator = request.user
        date.save(update_fields=['scheduled_at', 'creator'])
        return Response(self.get_serializer(date).data)

    @action(detail=True, methods=['post'])
    @transaction.atomic
    def respond(self, request, pk=None):
        date = get_object_or_404(self.get_queryset().select_for_update(), pk=pk)
        if date.creator_id == request.user.id:
            raise PermissionDenied('Only the invited partner can respond.')
        new_status = request.data.get('status')
        if date.status != 'pending' or new_status not in ['accepted', 'declined'] or date.scheduled_at <= timezone.now():
            raise ValidationError('Invalid or expired invitation transition.')
        date.status = new_status
        date.save(update_fields=['status'])
        return Response(self.get_serializer(date).data)


class MeetingViewSet(viewsets.ModelViewSet):
    serializer_class = MeetingSerializer
    def get_queryset(self):
        return MeetingCountdown.objects.filter(couple=couple_for(self.request.user)).order_by('target_date')
    def perform_create(self, serializer):
        serializer.save(couple=couple_for(self.request.user))


class PrivatePhotoView(APIView):
    # Development storage also stays private; never serve MEDIA_ROOT publicly.
    def get(self, request, path):
        photo = get_object_or_404(DailyPhotoSubmission, photo=path, couple=couple_for(request.user))
        rows = list(DailyPhotoSubmission.objects.filter(couple=photo.couple, day=photo.day))
        if photo.user_id != request.user.id and not both(photo.couple, rows):
            raise PermissionDenied()
        response = FileResponse(photo.photo.open('rb'), content_type='image/jpeg')
        response['Cache-Control'] = 'private, no-store'
        return response
