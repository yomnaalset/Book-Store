from django.urls import path
from bookstore_api.views.user_views import (
    RegisterView, LoginView, LogoutView, PasswordResetRequestView,
    PasswordResetView, ChangePasswordView, UserProfileView, CustomerAccountView,
    UserTypeOptionsView, LanguageOptionsView, UserLanguagePreferenceView,
    ApplicationLanguageView, ChangeEmailView, LibraryManagerProfileView
)
from bookstore_api.views.user_preferences_views import (
    NotificationPreferencesView
)
from bookstore_api.views.help_support_views import (
    HelpSupportDataView, FAQListView, UserGuideListView, 
    TroubleshootingGuideListView, SupportContactListView
)

user_urls = [
    path('register/', RegisterView.as_view(), name='register'),
    path('register/user-types/', UserTypeOptionsView.as_view(), name='user_type_options'),
    path('login/', LoginView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
    path('password-reset-request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('password-reset-confirm/<uidb64>/<token>/', PasswordResetView.as_view(), name='password_reset_confirm'),
    path('change-password/', ChangePasswordView.as_view(), name='change_password'),
    path('change-email/', ChangeEmailView.as_view(), name='change_email'),
    path('profile/', UserProfileView.as_view(), name='user_profile'),
    path('library-manager/profile/', LibraryManagerProfileView.as_view(), name='library_manager_profile'),
    path('account/', CustomerAccountView.as_view(), name='customer_account'),
    # Language preference endpoints
    path('languages/', LanguageOptionsView.as_view(), name='language_options'),
    path('language-preference/', UserLanguagePreferenceView.as_view(), name='user_language_preference'),
    path('application-language/', ApplicationLanguageView.as_view(), name='application_language'),
    # User preferences endpoints
    path('notification-preferences/', NotificationPreferencesView.as_view(), name='notification_preferences'),
    # Help and support endpoints
    path('help-support/', HelpSupportDataView.as_view(), name='help_support_data'),
    path('help-support/faqs/', FAQListView.as_view(), name='faq_list'),
    path('help-support/user-guides/', UserGuideListView.as_view(), name='user_guide_list'),
    path('help-support/troubleshooting/', TroubleshootingGuideListView.as_view(), name='troubleshooting_list'),
    path('help-support/contacts/', SupportContactListView.as_view(), name='support_contacts'),
]