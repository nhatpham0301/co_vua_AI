import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../model/app_model.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/shared/app_dialog.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  bool _isRegister = false;
  bool _obscurePassword = true;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AppModel model, AppLocalizations l) async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty) {
      _showError('Email is required.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showError('Email format is invalid.');
      return;
    }
    if (password.isEmpty) {
      _showError('Password is required.');
      return;
    }
    if (password.length < 8) {
      _showError('Password must be at least 8 characters.');
      return;
    }

    if (_isRegister) {
      final username = _usernameCtrl.text.trim();
      if (username.isEmpty) {
        _showError('Username is required.');
        return;
      }
      final ok = await model.authService.register(
        email: email,
        password: password,
        username: username,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        _showError(_mapError(model.authService.lastError, l));
      }
    } else {
      final ok = await model.authService.login(
        email: email,
        password: password,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        _showError(_mapError(model.authService.lastError, l));
      }
    }
  }

  String _mapError(String? raw, AppLocalizations l) {
    if (raw == null) return l.authErrorUnknown;
    if (raw.contains('INVALID_CREDENTIALS'))
      return l.authErrorInvalidCredentials;
    if (raw.contains('EMAIL_TAKEN')) return l.authErrorEmailTaken;
    if (raw.contains('USERNAME_TAKEN')) return l.authErrorUsernameTaken;
    if (raw.contains('VALIDATION_ERROR')) return l.authErrorValidation;
    return raw;
  }

  void _showError(String message) {
    showAppDialog<void>(
      context: context,
      title: _isRegister ? 'Register' : 'Login',
      message: message,
      actions: [
        AppDialogAction(label: 'OK', isPrimary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [bgMid, bgDark],
              ),
            ),
          ),
          const BoardBackground(),
          const CornerKnots(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Icon(
                          CupertinoIcons.back,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRegister ? l.registerTitle : l.loginTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Jura',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: bgCard.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        CupertinoSlidingSegmentedControl<bool>(
                          groupValue: _isRegister,
                          children: {
                            false: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              child: Text(
                                l.loginTitle,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            true: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              child: Text(
                                l.registerTitle,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          },
                          onValueChanged: (value) {
                            if (value != null) {
                              setState(() => _isRegister = value);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _InputField(
                          controller: _emailCtrl,
                          placeholder: l.email,
                          icon: CupertinoIcons.mail,
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          controller: _passwordCtrl,
                          placeholder: l.password,
                          icon: CupertinoIcons.lock,
                          obscureText: _obscurePassword,
                          suffix: GestureDetector(
                            onTap: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: Icon(
                                _obscurePassword
                                    ? CupertinoIcons.eye
                                    : CupertinoIcons.eye_slash,
                                color: Colors.white60,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                        if (_isRegister) ...[
                          const SizedBox(height: 12),
                          _InputField(
                            controller: _usernameCtrl,
                            placeholder: l.username,
                            icon: CupertinoIcons.person,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Consumer<AppModel>(
                          builder: (ctx, model, _) {
                            final busy = model.authService.busy;
                            return SizedBox(
                              width: double.infinity,
                              child: CupertinoButton(
                                color: primary,
                                borderRadius: BorderRadius.circular(14),
                                onPressed:
                                    busy ? null : () => _submit(model, l),
                                child: busy
                                    ? const CupertinoActivityIndicator(
                                        color: Colors.white)
                                    : Text(
                                        _isRegister
                                            ? l.registerButton
                                            : l.loginButton,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        if (!_isRegister)
                          Align(
                            alignment: Alignment.centerRight,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () {},
                              child: Text(
                                l.forgotPassword,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l.continueGuest,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: CupertinoTextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        placeholder: placeholder,
        placeholderStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
        ),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Icon(icon, color: Colors.white60, size: 18),
        ),
        suffix: suffix,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: const BoxDecoration(),
      ),
    );
  }
}
