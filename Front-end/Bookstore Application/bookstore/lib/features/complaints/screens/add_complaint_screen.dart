import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/customer_complaints_provider.dart';
import '../models/customer_complaint.dart';
import '../../../core/localization/app_localizations.dart';

class AddComplaintScreen extends StatefulWidget {
  final CustomerComplaint? complaint;

  const AddComplaintScreen({super.key, this.complaint});

  @override
  State<AddComplaintScreen> createState() => _AddComplaintScreenState();
}

class _AddComplaintScreenState extends State<AddComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _selectedComplaintType = CustomerComplaint.typeApp;

  @override
  void initState() {
    super.initState();
    if (widget.complaint != null) {
      _messageController.text = widget.complaint!.message;
      _selectedComplaintType = widget.complaint!.complaintType;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitComplaint() async {
    if (!mounted || !_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final complaintsProvider = Provider.of<CustomerComplaintsProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      complaintsProvider.setToken(authProvider.token);
    }

    CustomerComplaint? complaint;
    if (widget.complaint != null) {
      // Update existing complaint
      complaint = await complaintsProvider.updateComplaint(
        id: widget.complaint!.id,
        message: _messageController.text.trim(),
        complaintType: _selectedComplaintType,
      );
    } else {
      // Create new complaint
      complaint = await complaintsProvider.createComplaint(
        message: _messageController.text.trim(),
        complaintType: _selectedComplaintType,
      );
    }

    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    if (complaint != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.complaint != null
                ? localizations.complaintUpdatedSuccessfully
                : localizations.complaintSubmittedSuccessfully,
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complaintsProvider.error ??
                (widget.complaint != null
                    ? localizations.failedToUpdateComplaint
                    : localizations.failedToSubmitComplaint),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.complaint != null
              ? localizations.editComplaint
              : localizations.addComplaint,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<CustomerComplaintsProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Complaint Type
                  Text(
                    localizations.complaintType,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedComplaintType,
                    decoration: InputDecoration(
                      labelText: localizations.selectComplaintType,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: CustomerComplaint.typeApp,
                        child: Text(localizations.complaintTypeApp),
                      ),
                      DropdownMenuItem(
                        value: CustomerComplaint.typeDelivery,
                        child: Text(localizations.complaintTypeDelivery),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedComplaintType = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.pleaseSelectComplaintType;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // Complaint Content
                  Text(
                    localizations.complaintDetails,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      labelText: localizations.describeYourComplaint,
                      hintText: localizations.provideComplaintDetails,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 8,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return localizations.pleaseEnterComplaintDetails;
                      }
                      if (value.trim().length < 10) {
                        return localizations.provideMoreDetails;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: provider.isLoading ? null : _submitComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            widget.complaint != null
                                ? localizations.updateComplaintButton
                                : localizations.submitComplaintButton,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
