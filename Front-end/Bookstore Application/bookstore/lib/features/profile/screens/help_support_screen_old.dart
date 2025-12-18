import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../help_support/providers/help_support_provider.dart';
import '../../help_support/models/help_support_models.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  @override
  void initState() {
    super.initState();
    _loadHelpSupportData();
  }

  Future<void> _loadHelpSupportData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final helpSupportProvider = Provider.of<HelpSupportProvider>(
        context,
        listen: false,
      );

      if (authProvider.token != null) {
        debugPrint('HelpSupportScreen: Loading help and support data...');
        await helpSupportProvider.loadHelpSupportData(
          token: authProvider.token!,
        );
        debugPrint(
          'HelpSupportScreen: Help and support data loaded successfully',
        );
      } else {
        debugPrint('HelpSupportScreen: No token available');
      }
    } catch (e) {
      debugPrint('HelpSupportScreen: Error loading help and support data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Consumer<HelpSupportProvider>(
        builder: (context, helpSupportProvider, child) {
          if (helpSupportProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (helpSupportProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  const Text(
                    'Error loading help content',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    helpSupportProvider.error!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                  ElevatedButton(
                    onPressed: _loadHelpSupportData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How can we help you?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: AppDimensions.spacingXS),
                            Text(
                              'Find answers to common questions or contact our support team',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Quick Help
                _buildSectionTitle('Quick Help'),
                const SizedBox(height: AppDimensions.spacingM),
                _buildHelpTile(
                  title: 'Frequently Asked Questions',
                  subtitle:
                      'Find answers to common questions (${helpSupportProvider.faqs.length} available)',
                  icon: Icons.quiz_outlined,
                  onTap: () => _showFAQ(context, helpSupportProvider),
                ),
                _buildHelpTile(
                  title: 'User Guide',
                  subtitle:
                      'Learn how to use the app effectively (${helpSupportProvider.userGuides.length} articles)',
                  icon: Icons.book_outlined,
                  onTap: () => _showUserGuide(context, helpSupportProvider),
                ),
                _buildHelpTile(
                  title: 'Troubleshooting',
                  subtitle:
                      'Fix common issues and problems (${helpSupportProvider.troubleshootingGuides.length} guides)',
                  icon: Icons.build_outlined,
                  onTap: () =>
                      _showTroubleshooting(context, helpSupportProvider),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Contact Support
                _buildSectionTitle('Contact Support (Admin Only)'),
                const SizedBox(height: AppDimensions.spacingM),
                if (helpSupportProvider.supportContacts.isNotEmpty)
                  ...helpSupportProvider.supportContacts.map(
                    (contact) => _buildHelpTile(
                      title: contact.title,
                      subtitle: contact.description,
                      icon: _getContactIcon(contact.contactType),
                      onTap: () => _openContactSupport(context, contact),
                    ),
                  )
                else
                  _buildHelpTile(
                    title: 'No Support Contacts Available',
                    subtitle:
                        'Contact information is not available at this time',
                    icon: Icons.info_outline,
                    onTap: () {},
                  ),

                const SizedBox(height: AppDimensions.spacingXL),

                // App Information
                _buildSectionTitle('App Information'),
                const SizedBox(height: AppDimensions.spacingM),
                _buildInfoCard(
                  title: 'Version',
                  value: '1.0.0',
                  icon: Icons.info_outline,
                ),
                _buildInfoCard(
                  title: 'Last Updated',
                  value: 'December 2024',
                  icon: Icons.update_outlined,
                ),
                _buildInfoCard(
                  title: 'Developer',
                  value: 'ReadGo Team',
                  icon: Icons.code_outlined,
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Feedback
                _buildSectionTitle('Feedback'),
                const SizedBox(height: AppDimensions.spacingM),
                _buildHelpTile(
                  title: 'Rate the App',
                  subtitle: 'Rate us on the app store',
                  icon: Icons.star_outline,
                  onTap: () => _rateApp(context),
                ),
                _buildHelpTile(
                  title: 'Send Feedback',
                  subtitle: 'Share your thoughts and suggestions',
                  icon: Icons.feedback_outlined,
                  onTap: () => _sendFeedback(context),
                ),
                _buildHelpTile(
                  title: 'Report a Bug',
                  subtitle: 'Help us improve by reporting issues',
                  icon: Icons.bug_report_outlined,
                  onTap: () => _reportBug(context),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Legal
                _buildSectionTitle('Legal'),
                const SizedBox(height: AppDimensions.spacingM),
                _buildHelpTile(
                  title: 'Terms of Service',
                  subtitle: 'Read our terms and conditions',
                  icon: Icons.description_outlined,
                  onTap: () => _showTerms(context),
                ),
                _buildHelpTile(
                  title: 'Privacy Policy',
                  subtitle: 'Learn how we protect your data',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => _showPrivacyPolicy(context),
                ),

                const SizedBox(height: AppDimensions.spacingXL),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method to get contact icon based on type
  IconData _getContactIcon(String contactType) {
    switch (contactType) {
      case 'live_chat':
        return Icons.chat_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'phone':
        return Icons.phone_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // Open contact support based on type
  void _openContactSupport(BuildContext context, SupportContact contact) {
    switch (contact.contactType) {
      case 'live_chat':
        _openLiveChat(context, contact.contactInfo);
        break;
      case 'email':
        _sendEmail(context, contact.contactInfo);
        break;
      case 'phone':
        _makePhoneCall(context, contact.contactInfo);
        break;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildHelpTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: AppDimensions.spacingM),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFAQ(BuildContext context, HelpSupportProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Q: How do I borrow a book?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('A: Go to the book detail page and tap "Borrow" button.'),
              SizedBox(height: 16),
              Text(
                'Q: How long can I keep a borrowed book?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('A: The standard borrowing period is 14 days.'),
              SizedBox(height: 16),
              Text(
                'Q: Can I extend my borrowing period?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'A: Yes, you can request an extension from your borrow history.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showUserGuide(BuildContext context, HelpSupportProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Guide'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Getting Started',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('1. Browse books by category or search for specific titles'),
              Text('2. Tap on a book to view details and borrow options'),
              Text('3. Add books to your cart for purchase'),
              Text('4. Manage your borrowed books in the profile section'),
              SizedBox(height: 16),
              Text(
                'Borrowing Books',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Standard borrowing period: 14 days'),
              Text('• Maximum 3 books at a time'),
              Text('• Extensions available for most books'),
              Text('• Return books on time to avoid fines'),
              SizedBox(height: 16),
              Text(
                'Account Management',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('• Update your profile information'),
              Text('• Change password in settings'),
              Text('• View borrowing history'),
              Text('• Manage notifications'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTroubleshooting(
    BuildContext context,
    HelpSupportProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Troubleshooting'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Common Issues',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'App won\'t load:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('• Check your internet connection'),
              Text('• Restart the app'),
              Text('• Clear app cache in settings'),
              SizedBox(height: 12),
              Text(
                'Can\'t borrow books:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('• Ensure you\'re logged in'),
              Text('• Check if you\'ve reached the borrowing limit'),
              Text('• Verify the book is available'),
              SizedBox(height: 12),
              Text(
                'Login issues:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('• Verify your email and password'),
              Text('• Try resetting your password'),
              Text('• Contact support if problems persist'),
              SizedBox(height: 12),
              Text(
                'Still having issues?',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text('Contact our support team for personalized help.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openLiveChat(BuildContext context, String contactInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, size: 48, color: AppColors.primary),
            SizedBox(height: 16),
            Text('Live chat is currently unavailable.'),
            SizedBox(height: 8),
            Text('Please use email or phone support instead.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail(context, 'support@library.com');
            },
            child: const Text('Email Support'),
          ),
        ],
      ),
    );
  }

  void _sendEmail(BuildContext context, String contactInfo) {
    _showEmailDialog(context);
  }

  void _showEmailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Support (Admin Only)'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Email: admin@elibrary.com'),
            SizedBox(height: 8),
            Text('Subject: Admin Support Request'),
            SizedBox(height: 8),
            Text('This contact is for administrators only.'),
            SizedBox(height: 8),
            Text('We typically respond within 24 hours.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _makePhoneCall(BuildContext context, String contactInfo) {
    _showPhoneDialog(context);
  }

  void _showPhoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Support (Admin Only)'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Phone: +1 (234) 567-890'),
            SizedBox(height: 8),
            Text('Hours: Monday - Friday, 9 AM - 6 PM'),
            SizedBox(height: 8),
            Text('This contact is for administrators only.'),
            SizedBox(height: 8),
            Text('We\'re here to help!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _rateApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Our App'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, size: 48, color: Colors.amber),
            SizedBox(height: 16),
            Text('We appreciate your feedback!'),
            SizedBox(height: 8),
            Text(
              'Please rate us on the app store to help others discover our app.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Redirecting to app store...'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Rate Now'),
          ),
        ],
      ),
    );
  }

  void _sendFeedback(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('We value your input!'),
            SizedBox(height: 8),
            Text(
              'Please share your thoughts, suggestions, or ideas to help us improve the app.',
            ),
            SizedBox(height: 16),
            Text('Email: admin@elibrary.com (Admin Only)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail(context, 'support@library.com');
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  void _reportBug(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Bug'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bug_report, size: 48, color: AppColors.error),
            SizedBox(height: 16),
            Text('Found a bug? We want to know!'),
            SizedBox(height: 8),
            Text(
              'Please describe the issue you encountered and we\'ll work to fix it.',
            ),
            SizedBox(height: 16),
            Text('Email: admin@elibrary.com (Admin Only)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendEmail(context, 'support@library.com');
            },
            child: const Text('Report Bug'),
          ),
        ],
      ),
    );
  }

  void _showTerms(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '1. Acceptance of Terms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('By using this app, you agree to be bound by these terms.'),
              SizedBox(height: 12),
              Text(
                '2. Use of the Service',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '• You may use the app for personal, non-commercial purposes',
              ),
              Text('• You must not violate any laws or regulations'),
              Text('• You are responsible for maintaining account security'),
              SizedBox(height: 12),
              Text(
                '3. Borrowing and Returns',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Books must be returned on time'),
              Text('• Late returns may result in fines'),
              Text('• Damaged books may incur replacement costs'),
              SizedBox(height: 12),
              Text('4. Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                'Your personal information is protected as described in our Privacy Policy.',
              ),
              SizedBox(height: 12),
              Text(
                '5. Changes to Terms',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'We may update these terms at any time. Continued use constitutes acceptance.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Information We Collect',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Personal information (name, email, phone)'),
              Text('• Borrowing history and preferences'),
              Text('• App usage data and analytics'),
              SizedBox(height: 12),
              Text(
                'How We Use Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• To provide library services'),
              Text('• To send important notifications'),
              Text('• To improve app functionality'),
              Text('• To prevent fraud and ensure security'),
              SizedBox(height: 12),
              Text(
                'Information Sharing',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'We do not sell or share your personal information with third parties except:',
              ),
              Text('• When required by law'),
              Text('• To protect our rights and safety'),
              Text('• With your explicit consent'),
              SizedBox(height: 12),
              Text(
                'Data Security',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'We use industry-standard security measures to protect your data.',
              ),
              SizedBox(height: 12),
              Text(
                'Your Rights',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('• Access your personal data'),
              Text('• Request data correction'),
              Text('• Request data deletion'),
              Text('• Opt out of marketing communications'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
