// MAYA — Register Screen
// Lets new users sign up for an account.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await const AuthRepository().register(
        _usernameCtrl.text.trim(),
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
      );
      if (mounted) {
        // Registration successful — go to login
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created! Please sign in.'),
            backgroundColor: MayaColors.success,
          ),
        );
        context.go(MayaRoutes.login);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MayaColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Row(
          children: [
            // Left branding panel — desktop only
            if (MediaQuery.of(context).size.width > 800)
              Expanded(
                flex: 5,
                child: Container(
                  decoration: const BoxDecoration(
                    color: MayaColors.surface,
                    border: Border(right: BorderSide(color: MayaColors.border)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/maya_logo.jpg', width: 120, height: 120),
                        const SizedBox(height: 24),
                        Text('Your private cinema.', style: MayaTextStyles.bodyLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Create your account to start watching.',
                          style: MayaTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Right form panel
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MayaSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _buildForm(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mobile logo
          if (MediaQuery.of(context).size.width <= 800)
            Center(
              child: Column(children: [
                Image.asset('assets/images/maya_logo.jpg', width: 72, height: 72),
                const SizedBox(height: MayaSpacing.md),
              ]),
            ),

          Text('Create account', style: MayaTextStyles.displayMedium),
          const SizedBox(height: MayaSpacing.sm),
          Text('Join MAYA and start your private cinema.', style: MayaTextStyles.bodyMedium),
          const SizedBox(height: MayaSpacing.xl),

          // Username
          TextFormField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(labelText: 'Username'),
            style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
            textInputAction: TextInputAction.next,
            enabled: !_loading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Username is required';
              if (v.trim().length < 3) return 'At least 3 characters';
              if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v.trim())) {
                return 'Letters, numbers and _ only';
              }
              return null;
            },
          ),
          const SizedBox(height: MayaSpacing.md),

          // Email
          TextFormField(
            controller: _emailCtrl,
            decoration: const InputDecoration(labelText: 'Email'),
            style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !_loading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: MayaSpacing.md),

          // Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: MayaColors.textMuted,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
            textInputAction: TextInputAction.next,
            enabled: !_loading,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: MayaSpacing.md),

          // Confirm Password
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(labelText: 'Confirm Password'),
            style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _register(),
            enabled: !_loading,
            validator: (v) {
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: MayaSpacing.md),

          // Error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(MayaSpacing.md),
              decoration: BoxDecoration(
                color: MayaColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(MayaSpacing.buttonRadius),
                border: Border.all(color: MayaColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: MayaColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!,
                      style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.error))),
                ],
              ),
            ),
            const SizedBox(height: MayaSpacing.md),
          ],

          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: MayaColors.background),
                    )
                  : const Text('Create Account'),
            ),
          ),
          const SizedBox(height: MayaSpacing.lg),

          // Back to login
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ', style: MayaTextStyles.bodySmall),
              GestureDetector(
                onTap: () => context.go(MayaRoutes.login),
                child: Text(
                  'Sign in',
                  style: MayaTextStyles.bodySmall.copyWith(
                    color: MayaColors.accent,
                    decoration: TextDecoration.underline,
                    decorationColor: MayaColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MayaSpacing.xl),
          const Divider(color: MayaColors.border),
          const SizedBox(height: MayaSpacing.md),
          Center(
            child: Text('MAYA · Private Media Platform', style: MayaTextStyles.labelSmall),
          ),
        ],
      ),
    );
  }
}
