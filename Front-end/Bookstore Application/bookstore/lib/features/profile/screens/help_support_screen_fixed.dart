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
                  onTap: () => _showTermsOfService(context),
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
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary),
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
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Text(
          value,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  // FAQ Dialog
  void _showFAQ(BuildContext context, HelpSupportProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.faqs.length,
            itemBuilder: (context, index) {
              final faq = provider.faqs[index];
              return ExpansionTile(
                title: Text(faq.question),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(faq.answer),
                  ),
                ],
              );
            },
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

  // User Guide Dialog
  void _showUserGuide(BuildContext context, HelpSupportProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('User Guide'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.userGuides.length,
            itemBuilder: (context, index) {
              final guide = provider.userGuides[index];
              return Card(
                child: ListTile(
                  title: Text(guide.title),
                  subtitle: Text(guide.content),
                  onTap: () {
                    // Show detailed guide
                    _showDetailedGuide(context, guide);
                  },
                ),
              );
            },
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

  // Troubleshooting Dialog
  void _showTroubleshooting(
    BuildContext context,
    HelpSupportProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Troubleshooting'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: provider.troubleshootingGuides.length,
            itemBuilder: (context, index) {
              final guide = provider.troubleshootingGuides[index];
              return ExpansionTile(
                title: Text(guide.title),
                subtitle: Text(guide.description),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(guide.solution),
                  ),
                ],
              );
            },
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

  // Contact Support Methods
  void _openLiveChat(BuildContext context, String contactInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Live Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Live chat is not available at the moment.'),
            const SizedBox(height: 16),
            Text('Contact URL: $contactInfo'),
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

  void _sendEmail(BuildContext context, String contactInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Send us an email and we\'ll get back to you.'),
            const SizedBox(height: 16),
            Text('Email: $contactInfo'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Call us for immediate assistance.'),
            const SizedBox(height: 16),
            Text('Phone: $contactInfo'),
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

  // Other methods (simplified for now)
  void _showDetailedGuide(BuildContext context, UserGuide guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide.title),
        content: SingleChildScrollView(child: Text(guide.content)),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Rate app functionality not implemented')),
    );
  }

  void _sendFeedback(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Send feedback functionality not implemented'),
      ),
    );
  }

  void _reportBug(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report bug functionality not implemented')),
    );
  }

  void _showTermsOfService(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terms of service not available')),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy policy not available')),
    );
  }
}
