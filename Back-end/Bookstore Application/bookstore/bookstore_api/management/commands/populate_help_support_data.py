from django.core.management.base import BaseCommand
from bookstore_api.models import FAQ, UserGuide, TroubleshootingGuide, SupportContact


class Command(BaseCommand):
    help = 'Populate help and support data with sample content'

    def handle(self, *args, **options):
        self.stdout.write('Creating sample help and support data...')

        # Create sample FAQs
        faqs_data = [
            {
                'question': 'How do I borrow a book?',
                'answer': 'To borrow a book, search for it in the library catalog, tap on the book, and click the "Borrow" button. You can borrow up to 5 books at a time for 14 days.',
                'category': 'borrowing',
                'order': 1
            },
            {
                'question': 'How do I return a book?',
                'answer': 'To return a book, go to your profile, tap on "Borrowed Books", find the book you want to return, and tap "Return". You can also return books early.',
                'category': 'borrowing',
                'order': 2
            },
            {
                'question': 'What if I forget my password?',
                'answer': 'If you forget your password, go to the login screen and tap "Forgot Password". Enter your email address and follow the instructions sent to your email.',
                'category': 'account',
                'order': 1
            },
            {
                'question': 'How do I update my profile information?',
                'answer': 'Go to your profile screen and tap the edit icon. You can update your personal information, address, and contact details.',
                'category': 'account',
                'order': 2
            },
            {
                'question': 'Why is the app running slowly?',
                'answer': 'Try closing and reopening the app, or restart your device. Make sure you have a stable internet connection. If the problem persists, contact support.',
                'category': 'technical',
                'order': 1
            }
        ]

        for faq_data in faqs_data:
            FAQ.objects.get_or_create(
                question=faq_data['question'],
                defaults=faq_data
            )

        # Create sample user guides
        user_guides_data = [
            {
                'title': 'Getting Started with the Library App',
                'content': 'Welcome to our digital library! This guide will help you get started with browsing, borrowing, and managing your books.',
                'section': 'getting_started',
                'order': 1
            },
            {
                'title': 'How to Search for Books',
                'content': 'Use the search bar to find books by title, author, or category. You can also use filters to narrow down your results.',
                'section': 'browsing_books',
                'order': 1
            },
            {
                'title': 'Managing Your Borrowed Books',
                'content': 'Keep track of your borrowed books, due dates, and renewal options in your profile section.',
                'section': 'borrowing',
                'order': 1
            },
            {
                'title': 'Setting Up Notifications',
                'content': 'Configure your notification preferences to receive updates about due dates, new books, and library news.',
                'section': 'notifications',
                'order': 1
            }
        ]

        for guide_data in user_guides_data:
            UserGuide.objects.get_or_create(
                title=guide_data['title'],
                defaults=guide_data
            )

        # Create sample troubleshooting guides
        troubleshooting_data = [
            {
                'title': 'App Won\'t Start',
                'description': 'The app crashes or won\'t open when you tap the icon.',
                'solution': '1. Force close the app and try again\n2. Restart your device\n3. Check if you have the latest version\n4. Clear app cache in device settings',
                'category': 'app_crash',
                'order': 1
            },
            {
                'title': 'Can\'t Log In',
                'description': 'You\'re unable to log in with your credentials.',
                'solution': '1. Check your internet connection\n2. Verify your email and password\n3. Try resetting your password\n4. Contact support if the problem persists',
                'category': 'login',
                'order': 1
            },
            {
                'title': 'Books Not Syncing',
                'description': 'Your borrowed books or reading progress isn\'t syncing across devices.',
                'solution': '1. Check your internet connection\n2. Log out and log back in\n3. Refresh the app by pulling down\n4. Contact support if sync issues continue',
                'category': 'sync',
                'order': 1
            }
        ]

        for trouble_data in troubleshooting_data:
            TroubleshootingGuide.objects.get_or_create(
                title=trouble_data['title'],
                defaults=trouble_data
            )

        # Create sample support contacts
        support_contacts_data = [
            {
                'contact_type': 'live_chat',
                'title': 'Live Chat Support',
                'description': 'Chat with our support team in real-time',
                'contact_info': 'https://support.library.com/chat',
                'is_admin_only': True,
                'available_hours': '9 AM - 6 PM (Mon-Fri)',
                'order': 1
            },
            {
                'contact_type': 'email',
                'title': 'Email Support',
                'description': 'Send us an email and we\'ll get back to you',
                'contact_info': 'support@library.com',
                'is_admin_only': True,
                'available_hours': '24/7',
                'order': 2
            },
            {
                'contact_type': 'phone',
                'title': 'Phone Support',
                'description': 'Call us for immediate assistance',
                'contact_info': '+1-800-LIBRARY',
                'is_admin_only': True,
                'available_hours': '9 AM - 5 PM (Mon-Fri)',
                'order': 3
            }
        ]

        for contact_data in support_contacts_data:
            SupportContact.objects.get_or_create(
                contact_type=contact_data['contact_type'],
                title=contact_data['title'],
                defaults=contact_data
            )

        self.stdout.write(
            self.style.SUCCESS('Successfully created help and support data!')
        )
