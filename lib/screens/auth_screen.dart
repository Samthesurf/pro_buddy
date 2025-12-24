import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import '../bloc/auth_cubit.dart';
import '../bloc/auth_state.dart';
import '../core/routes.dart';
import '../services/api_service.dart';

class AuthScreen extends StatefulWidget {
  final bool isSignIn;
  final Map<String, dynamic>? onboardingData;

  const AuthScreen({
    super.key,
    this.isSignIn = true,
    this.onboardingData,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isSignIn;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isSavingData = false;
  bool _hasSaveError = false;

  @override
  void initState() {
    super.initState();
    _isSignIn = widget.isSignIn;

    // Check if we are already authenticated when entering this screen with data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AuthCubit>().state;
      if (state.status == AuthStatus.authenticated) {
        _handleAuthenticated(state);
      }
    });
  }

  Map<String, dynamic>? get _onboardingData {
    if (widget.onboardingData != null) return widget.onboardingData;
    // We access ModalRoute safely here as this getter is called in build/listener
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      return args;
    }
    return null;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    final cubit = context.read<AuthCubit>();

    if (_isSignIn) {
      cubit.signInWithEmail(email: email, password: password);
    } else {
      cubit.signUpWithEmail(email: email, password: password, name: name);
    }
  }

  Future<void> _handleAuthenticated(AuthState state) async {
    if (_isSavingData || _hasSaveError) return;

    // Check for deferred onboarding data
    final data = _onboardingData;
    
    // Check if this is legacy goal data (has 'content' key with a non-null String value)
    final hasLegacyGoalData = data != null && data['content'] is String;
    
    // Check if this is new onboarding data (has 'onboarding_data' key)
    final hasNewOnboardingData = data != null && data['onboarding_data'] != null;
    
    if (hasLegacyGoalData) {
      // Legacy flow: save goals from GoalsInputScreen
      setState(() {
        _isSavingData = true;
        _hasSaveError = false;
      });

      try {
        await ApiService.instance.saveGoals(
          content: data['content'] as String,
          reason: data['reason'] as String?,
          timeline: data['timeline'] as String?,
        );

        if (!mounted) return;

        // Continue to Goal Discovery
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.goalDiscovery,
          arguments: const {'fromOnboarding': true},
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSavingData = false;
          _hasSaveError = true;
        });
      }
    } else if (hasNewOnboardingData) {
      // New onboarding flow: data was collected via quiz/challenges/habits screens
      // Don't save challenges/habits as "goals" - they are routines to achieve goals
      // The Goal Discovery will ask for the actual primary goal
      setState(() {
        _isSavingData = true;
        _hasSaveError = false;
      });
      
      try {
        // Save onboarding preferences (challenges, habits) separately from primary goals
        final onboardingData = data['onboarding_data'] as Map<String, dynamic>?;
        if (onboardingData != null) {
          await ApiService.instance.saveOnboardingPreferences(
            challenges: (onboardingData['challenges'] as List<dynamic>?)?.cast<String>() ?? [],
            habits: (onboardingData['habits'] as List<dynamic>?)?.cast<String>() ?? [],
            distractionHours: (onboardingData['distraction_hours'] as num?)?.toDouble() ?? 0,
            focusDurationMinutes: (onboardingData['focus_duration_minutes'] as num?)?.toDouble() ?? 0,
            goalClarity: (onboardingData['goal_clarity'] as num?)?.toInt() ?? 5,
            productiveTime: onboardingData['productive_time'] as String? ?? 'Morning',
            checkInFrequency: onboardingData['check_in_frequency'] as String? ?? 'Daily',
          );
        }
        
        if (!mounted) return;
        // Go directly to Goal Discovery to ask for actual primary goals
        Navigator.of(context).pushReplacementNamed(
          AppRoutes.goalDiscovery,
          arguments: {'fromOnboarding': true, 'onboarding_data': data['onboarding_data']},
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSavingData = false;
          _hasSaveError = true;
        });
      }
    } else {
      // Standard flow - no onboarding data passed
      Navigator.of(context).pushReplacementNamed(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state.status == AuthStatus.authenticated) {
            _handleAuthenticated(state);
          }
        },
        builder: (context, state) {
          // If we are authenticated and have data, we are either saving or failed to save.
          // We should not show the login form.
          if (state.status == AuthStatus.authenticated && _onboardingData != null) {
            if (_hasSaveError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('Failed to save your goals.'),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        setState(() => _hasSaveError = false);
                        _handleAuthenticated(state);
                      },
                      child: const Text('Retry'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                         // Skip saving and go to dashboard/discovery
                         Navigator.of(context).pushReplacementNamed(
                            AppRoutes.dashboard,
                         );
                      },
                      child: const Text('Skip & Continue'),
                    ),
                  ],
                ),
              );
            }

            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Setting up your profile...'),
                ],
              ),
            );
          }

          if (_isSavingData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo or Title
                      Image.asset(
                        'assets/images/Hawk_logo.png',
                        height: 120,
                        width: 120,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isSignIn ? 'Welcome Back!' : 'Create Account',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSignIn
                            ? 'Sign in to continue tracking your goals'
                            : 'Join us to start your journey',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),

                      // Name Field (Sign Up only)
                      if (!_isSignIn) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      FilledButton(
                        onPressed: state.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: state.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isSignIn ? 'Sign In' : 'Sign Up'),
                      ),

                      const SizedBox(height: 24),

                      // Divider
                      Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Google Sign In
                      OutlinedButton.icon(
                        onPressed: state.isLoading
                            ? null
                            : () => context.read<AuthCubit>().signInWithGoogle(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.login), // Placeholder for Google Logo
                        label: const Text('Continue with Google'),
                      ),

                      const SizedBox(height: 24),

                      // Toggle Mode
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignIn
                                ? "Don't have an account?"
                                : 'Already have an account?',
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isSignIn = !_isSignIn;
                                _formKey.currentState?.reset();
                              });
                            },
                            child: Text(_isSignIn ? 'Sign Up' : 'Sign In'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
