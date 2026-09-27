"""Couple-scoped relationship features and authenticated media delivery."""
import mimetypes
import math
from pathlib import Path
from django.db import transaction
from django.http import FileResponse, StreamingHttpResponse, HttpResponse, Http404
from django.shortcuts import get_object_or_404
from rest_framework import serializers, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import Envelope, EnvelopeAttachment, StoryEntry, PartnerMessage, MapPlace, WishlistItem
from .views import couple_for


class AttachmentSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = EnvelopeAttachment
        fields = ['id', 'kind', 'name', 'url']

    def get_url(self, obj):
        return f'/api/relationship-media/attachment/{obj.pk}/'


class EnvelopeSerializer(serializers.ModelSerializer):
    attachments = AttachmentSerializer(many=True, read_only=True)

    class Meta:
        model = Envelope
        fields = ['id', 'creator', 'title', 'text', 'created_at', 'attachments']
        read_only_fields = ['creator', 'created_at']


class StorySerializer(serializers.ModelSerializer):
    photo_url = serializers.SerializerMethodField()
    photo = serializers.ImageField(required=False, write_only=True)

    class Meta:
        model = StoryEntry
        fields = ['id', 'date', 'photo', 'photo_url', 'location', 'text', 'emoji']

    def validate_photo(self, value):
        if value.size > 10 * 1024 * 1024:
            raise serializers.ValidationError('Upload a photo up to 10 MB.')
        return value

    def get_photo_url(self, obj):
        return f'/api/relationship-media/story/{obj.pk}/' if obj.photo else None


class MessageSerializer(serializers.ModelSerializer):
    class Meta:
        model = PartnerMessage
        fields = ['id', 'sender', 'text', 'created_at']
        read_only_fields = ['sender', 'created_at']


class CoordinateField(serializers.FloatField):
    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        if not math.isfinite(value):
            raise serializers.ValidationError('Invalid coordinate.')
        return value


class PlaceSerializer(serializers.ModelSerializer):
    latitude = CoordinateField(min_value=-90, max_value=90)
    longitude = CoordinateField(min_value=-180, max_value=180)

    class Meta:
        model = MapPlace
        fields = ['id', 'title', 'latitude', 'longitude']


class WishlistSerializer(serializers.ModelSerializer):
    class Meta:
        model = WishlistItem
        fields = ['id', 'title', 'completed']


class CoupleViewSet(viewsets.ModelViewSet):
    def get_queryset(self):
        return self.serializer_class.Meta.model.objects.filter(couple=couple_for(self.request.user))

    def perform_create(self, serializer):
        serializer.save(couple=couple_for(self.request.user))


class EnvelopeViewSet(CoupleViewSet):
    serializer_class = EnvelopeSerializer
    http_method_names = ['get', 'post', 'head', 'options']

    @transaction.atomic
    def perform_create(self, serializer):
        uploads = self.request.FILES.getlist('files')
        if len(uploads) > 12:
            raise serializers.ValidationError('Attach up to 12 files.')
        extensions = {'photo': {'.jpg', '.jpeg', '.png', '.webp'}, 'video': {'.mp4', '.mov', '.webm'}, 'audio': {'.mp3', '.m4a', '.wav', '.ogg', '.aac'}}
        checked = []
        for upload in uploads:
            kind = next((key for key, values in extensions.items() if Path(upload.name).suffix.lower() in values), None)
            if not kind or upload.size > 50 * 1024 * 1024:
                raise serializers.ValidationError('Use a supported photo, video, or audio file up to 50 MB.')
            if kind == 'photo':
                serializers.ImageField().run_validation(upload)
                upload.seek(0)
            checked.append((upload, kind))
        if not checked and not serializer.validated_data.get('text'):
            raise serializers.ValidationError('Add a text message or attachment.')
        envelope = serializer.save(couple=couple_for(self.request.user), creator=self.request.user)
        for upload, kind in checked:
            EnvelopeAttachment.objects.create(envelope=envelope, file=upload, kind=kind, name=upload.name[:255])


class StoryViewSet(CoupleViewSet):
    serializer_class = StorySerializer


class MessageViewSet(CoupleViewSet):
    serializer_class = MessageSerializer
    http_method_names = ['get', 'post', 'head', 'options']

    def perform_create(self, serializer):
        couple = couple_for(self.request.user)
        if not couple.user_2_id:
            raise serializers.ValidationError('Connect your partner first.')
        serializer.save(couple=couple, sender=self.request.user)

    @action(detail=False, methods=['post'])
    def hug(self, request):
        serializer = self.get_serializer(data={'text': '🫂'})
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        return Response(serializer.data, status=201)


class PlaceViewSet(CoupleViewSet):
    serializer_class = PlaceSerializer


class WishlistViewSet(CoupleViewSet):
    serializer_class = WishlistSerializer


class RelationshipMediaView(APIView):
    def get(self, request, kind, pk):
        couple = couple_for(request.user)
        if kind == 'attachment':
            obj = get_object_or_404(EnvelopeAttachment, pk=pk, envelope__couple=couple)
            file = obj.file
        elif kind == 'story':
            obj = get_object_or_404(StoryEntry, pk=pk, couple=couple)
            if not obj.photo:
                raise Http404
            file = obj.photo
        else:
            raise Http404
        content_type = mimetypes.guess_type(file.name)[0] or 'application/octet-stream'
        size = file.size
        byte_range = request.headers.get('Range')
        if byte_range:
            # AVPlayer and other native media players request byte ranges.
            import re
            match = re.fullmatch(r'bytes=(\d*)-(\d*)', byte_range)
            try:
                if not match or not any(match.groups()):
                    raise ValueError
                first, last = match.groups()
                start = int(first) if first else max(0, size - int(last))
                end = min(int(last), size - 1) if first and last else size - 1
                if start < 0 or start > end or start >= size:
                    raise ValueError
            except ValueError:
                response = HttpResponse(status=416)
                response['Content-Range'] = f'bytes */{size}'
                return response
            def chunks():
                stream = file.open('rb')
                try:
                    stream.seek(start)
                    remaining = end - start + 1
                    while remaining:
                        chunk = stream.read(min(65536, remaining))
                        if not chunk:
                            break
                        remaining -= len(chunk)
                        yield chunk
                finally:
                    stream.close()
            response = StreamingHttpResponse(chunks(), status=206, content_type=content_type)
            response['Content-Range'] = f'bytes {start}-{end}/{size}'
            response['Content-Length'] = str(end - start + 1)
        else:
            response = FileResponse(file.open('rb'), content_type=content_type)
        response['Accept-Ranges'] = 'bytes'
        response['Cache-Control'] = 'private, no-store'
        response['X-Content-Type-Options'] = 'nosniff'
        return response
