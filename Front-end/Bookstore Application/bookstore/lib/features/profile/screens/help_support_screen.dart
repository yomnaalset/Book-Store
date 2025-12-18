import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.helpSupportTitle),
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
                  Text(
                    localizations.errorLoadingHelpContent,
                    style: const TextStyle(
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
                    child: Text(localizations.retry),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                  child: Row(
                    children: [
                      const Icon(
                        Icons.help_outline,
                        size: 32,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              localizations.howCanWeHelp,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXS),
                            Text(
                              localizations.findAnswers,
                              style: const TextStyle(
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
                _buildSectionTitle(localizations.quickHelp),
                const SizedBox(height: AppDimensions.spacingM),
                _buildHelpTile(
                  title: localizations.frequentlyAskedQuestions,
                  subtitle: localizations.findAnswersCommon(
                    helpSupportProvider.faqs.length,
                  ),
                  icon: Icons.quiz_outlined,
                  onTap: () => _showFAQ(context, helpSupportProvider),
                ),
                _buildHelpTile(
                  title: localizations.userGuide,
                  subtitle: localizations.learnHowToUse(
                    helpSupportProvider.userGuides.length,
                  ),
                  icon: Icons.book_outlined,
                  onTap: () => _showUserGuide(context, helpSupportProvider),
                ),
                _buildHelpTile(
                  title: localizations.troubleshooting,
                  subtitle: localizations.fixCommonIssues(
                    helpSupportProvider.troubleshootingGuides.length,
                  ),
                  icon: Icons.build_outlined,
                  onTap: () =>
                      _showTroubleshooting(context, helpSupportProvider),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Contact Support
                _buildSectionTitle(localizations.contactSupportAdmin),
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
                    title: localizations.noSupportContacts,
                    subtitle: localizations.contactInfoNotAvailable,
                    icon: Icons.info_outline,
                    onTap: () {},
                  ),

                const SizedBox(height: AppDimensions.spacingXL),

                // App Information
                _buildSectionTitle(localizations.appInformation),
                const SizedBox(height: AppDimensions.spacingM),
                _buildInfoCard(
                  title: localizations.version,
                  value: '1.0.0',
                  icon: Icons.info_outline,
                ),
                _buildInfoCard(
                  title: localizations.lastUpdatedLabel,
                  value: 'December 2024',
                  icon: Icons.update_outlined,
                ),
                _buildInfoCard(
                  title: localizations.developer,
                  value: 'ReadGo Team',
                  icon: Icons.code_outlined,
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Feedback
                _buildSectionTitle(localizations.feedback),
                const SizedBox(height: AppDimensions.spacingM),
                _buildHelpTile(
                  title: localizations.rateTheApp,
                  subtitle: localizations.rateUsOnStore,
                  icon: Icons.star_outline,
                  onTap: () => _rateApp(context),
                ),
                _buildHelpTile(
                  title: localizations.sendFeedback,
                  subtitle: localizations.shareThoughts,
                  icon: Icons.feedback_outlined,
                  onTap: () => _sendFeedback(context),
                ),
                _buildHelpTile(
                  title: localizations.reportABug,
                  subtitle: localizations.helpUsImprove,
                  icon: Icons.bug_report_outlined,
                  onTap: () => _reportBug(context),
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // Legal
                _buildSectionTitle(localizations.legal),
                const SizedBox(height: AppDimensions.spacingM),
                _buildHelpTile(
                  title: localizations.termsOfService,
                  subtitle: localizations.readTerms,
                  icon: Icons.description_outlined,
                  onTap: () => _showTermsOfService(context),
                ),
                _buildHelpTile(
                  title: localizations.privacyPolicy,
                  subtitle: localizations.learnDataProtection,
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
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.frequentlyAskedQuestions),
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
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  // User Guide Dialog
  void _showUserGuide(BuildContext context, HelpSupportProvider provider) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.userGuide),
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
            child: Text(localizations.close),
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
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.troubleshooting),
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
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  // Contact Support Methods
  void _openLiveChat(BuildContext context, String contactInfo) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.liveChat),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.liveChatNotAvailable),
            const SizedBox(height: 16),
            Text(localizations.contactUrl(contactInfo)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _sendEmail(BuildContext context, String contactInfo) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.emailSupport),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.sendUsEmail),
            const SizedBox(height: 16),
            Text(localizations.emailLabelWithValue(contactInfo)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _makePhoneCall(BuildContext context, String contactInfo) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.phoneSupport),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.callUsAssistance),
            const SizedBox(height: 16),
            Text(localizations.phoneLabelWithValue(contactInfo)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  // Other methods (simplified for now)
  void _showDetailedGuide(BuildContext context, UserGuide guide) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide.title),
        content: SingleChildScrollView(child: Text(guide.content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
          ),
        ],
      ),
    );
  }

  void _rateApp(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.rateAppNotImplemented)),
    );
  }

  void _sendFeedback(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.sendFeedbackNotImplemented)),
    );
  }

  void _reportBug(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localizations.reportBugNotImplemented)),
    );
  }

  void _showTermsOfService(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizations.termsNotAvailable)));
  }

  void _showPrivacyPolicy(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(localizations.privacyNotAvailable)));
  }
}
