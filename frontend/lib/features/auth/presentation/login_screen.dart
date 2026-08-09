// MAYA — Login Screen
// Clean, minimal, cinematic dark login with the gold MAYA identity.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isLoading = auth is AuthLoading;
    final error = auth is AuthError ? auth.message : null;

    return Scaffold(
      backgroundColor: MayaColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Row(
          children: [
            // Left panel — hidden on small screens
            if (MediaQuery.of(context).size.width > 800)
              Expanded(
                flex: 5,
                child: _buildLeftPanel(),
              ),

            // Right panel — login form
            Expanded(
              flex: 4,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(MayaSpacing.xl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: _buildForm(isLoading, error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: MayaColors.surface,
        border: Border(
          right: BorderSide(color: MayaColors.border),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/maya_logo.jpg',
              width: 140,
              height: 140,
            ),
            const SizedBox(height: MayaSpacing.lg),
            Text('Your private cinema.', style: MayaTextStyles.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading, String? error) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Logo for mobile
          if (MediaQuery.of(context).size.width <= 800)
            Center(
              child: Column(
                children: [
                  Image.asset('assets/images/maya_logo.jpg', width: 80, height: 80),
                  const SizedBox(height: MayaSpacing.md),
                ],
              ),
            ),

          Text('Welcome back', style: MayaTextStyles.displayMedium),
          const SizedBox(height: MayaSpacing.sm),
          Text('Sign in to your MAYA account.', style: MayaTextStyles.bodyMedium),
          const SizedBox(height: MayaSpacing.xl),

          // Username field
          TextFormField(
            controller: _usernameController,
            style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
            decoration: const InputDecoration(labelText: 'Username'),
            textInputAction: TextInputAction.next,
            enabled: !isLoading,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
          ),
          const SizedBox(height: MayaSpacing.md),

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: MayaTextStyles.bodyLarge.copyWith(color: MayaColors.textPrimary),
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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            enabled: !isLoading,
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          const SizedBox(height: MayaSpacing.md),

          // Error message
          if (error != null) ...[
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
                  const SizedBox(width: MayaSpacing.sm),
                  Expanded(
                    child: Text(error,
                        style: MayaTextStyles.bodySmall.copyWith(color: MayaColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MayaSpacing.md),
          ],

          // Login button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _login,
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MayaColors.background,
                      ),
                    )
                  : const Text('Sign In'),
            ),
          ),

          const SizedBox(height: MayaSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ", style: MayaTextStyles.bodySmall),
              GestureDetector(
                onTap: () => context.go(MayaRoutes.register),
                child: Text(
                  'Sign up',
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
            child: Text(
              'MAYA · Private Media Platform',
              style: MayaTextStyles.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}
