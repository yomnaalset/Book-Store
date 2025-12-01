import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkAuthStatus();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Wait for animation to complete
      await _animationController.forward();

      if (!mounted) return;

      // Wait for auth provider to finish loading
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Wait for auth provider to finish loading with a timeout
      int attempts = 0;
      const maxAttempts = 50; // 5 seconds max (50 * 100ms)

      while (authProvider.isLoading && attempts < maxAttempts && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Navigate based on authentication status and user role
        debugPrint('SplashScreen: Checking authentication status');
        debugPrint(
          'SplashScreen: isAuthenticated: ${authProvider.isAuthenticated}',
        );
        debugPrint('SplashScreen: userRole: ${authProvider.userRole}');

        if (authProvider.isAuthenticated) {
          debugPrint(
            'SplashScreen: User is authenticated, navigating to dashboard',
          );
          // Navigate to appropriate dashboard based on user role
          final userRole = authProvider.userRole;
          if (userRole == 'admin') {
            debugPrint('SplashScreen: Navigating to admin dashboard');
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          } else if (userRole == 'library_admin') {
            debugPrint('SplashScreen: Navigating to library dashboard');
            Navigator.pushReplacementNamed(context, '/library/dashboard');
          } else if (userRole == 'delivery_admin') {
            debugPrint('SplashScreen: Navigating to delivery dashboard');
            Navigator.pushReplacementNamed(context, '/delivery/dashboard');
          } else {
            debugPrint('SplashScreen: Navigating to customer home');
            // Default to customer home (for 'customer' or any other role)
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          debugPrint(
            'SplashScreen: User not authenticated, navigating to login',
          );
          debugPrint(
            'SplashScreen: About to call Navigator.pushReplacementNamed(context, \'/login\')',
          );
          Navigator.pushReplacementNamed(context, '/login');
          debugPrint('SplashScreen: Navigator.pushReplacementNamed called');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'App initialization error. Please try again.';
          _isLoading = false;
        });

        debugPrint('Error in splash screen: $e');

        // On error, wait a moment then navigate to login
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusXL,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.library_books,
                            size: 60,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppDimensions.spacingXL),

                // App Name
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'E-Library',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeXXXL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppDimensions.spacingM),

                // Tagline
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        'Your Digital Library Companion',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          color: AppColors.white,
                          fontWeight: FontWeight.w300,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppDimensions.spacingXXL),

                // Error Message or Loading Indicator
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingL,
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: AppDimensions.fontSizeM,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _isLoading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                              strokeWidth: 2.0,
                            )
                          : const Text(
                              'Redirecting to login...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: AppDimensions.fontSizeM,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
