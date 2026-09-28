from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from core import views, relationship
router = DefaultRouter()
router.register('dates', views.VirtualDateViewSet, basename='date')
router.register('meetings', views.MeetingViewSet, basename='meeting')
router.register('envelopes', relationship.EnvelopeViewSet, basename='envelope')
router.register('story', relationship.StoryViewSet, basename='story')
router.register('messages', relationship.MessageViewSet, basename='message')
router.register('places', relationship.PlaceViewSet, basename='place')
router.register('wishlist', relationship.WishlistViewSet, basename='wishlist')
urlpatterns = [
    path('health/', views.health),
    path('api/relationship-media/<str:kind>/<int:pk>/', relationship.RelationshipMediaView.as_view()),
    path('api/auth/register/', views.RegisterView.as_view()),
    path('api/auth/token/', views.LoginView.as_view()),
    path('api/auth/refresh/', TokenRefreshView.as_view()),
    path('api/auth/logout/', views.logout),
    path('api/me/', views.MeView.as_view()),
    path('api/couple/', views.CoupleView.as_view()),
    path('api/couple/join/', views.JoinCoupleView.as_view()),
    path('api/couple/rotate-invite/', views.RotateInviteView.as_view()),
    path('api/home/', views.HomeView.as_view()),
    path('api/daily/photo/', views.SubmitPhotoView.as_view()),
    path('api/daily/question/category/', views.ChooseQuestionCategoryView.as_view()),
    path('api/daily/answer/', views.SubmitAnswerView.as_view()),
    path('api/moments/', views.MomentsView.as_view()),
    path('api/', include(router.urls)),
    path('media/<path:path>', views.PrivatePhotoView.as_view()),
]
