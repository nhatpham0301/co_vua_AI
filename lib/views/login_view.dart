import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/shared/app_dialog.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  bool _isRegister = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
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
                          obscureText: true,
                        ),
                        if (_isRegister) ...[
                          const SizedBox(height: 12),
                          _InputField(
                            controller: _confirmCtrl,
                            placeholder: l.confirmPassword,
                            icon: CupertinoIcons.lock_shield,
                            obscureText: true,
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: primary,
                            borderRadius: BorderRadius.circular(14),
                            onPressed: () {
                              showAppDialog<void>(
                                context: context,
                                title: _isRegister
                                    ? l.registerTitle
                                    : l.loginTitle,
                                message: l.loginComingSoon,
                                actions: [
                                  AppDialogAction(
                                    label: l.ok,
                                    isPrimary: true,
                                  ),
                                ],
                              );
                            },
                            child: Text(
                              _isRegister ? l.registerButton : l.loginButton,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
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

  const _InputField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: const BoxDecoration(),
      ),
    );
  }
}
