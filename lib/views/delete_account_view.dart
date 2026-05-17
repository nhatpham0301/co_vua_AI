import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/app_model.dart';
import 'components/main_menu_view/mm_background.dart';
import 'components/main_menu_view/mm_palette.dart';
import 'components/shared/adaptive_width.dart';
import 'components/shared/bottom_padding.dart';

class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({super.key});

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  bool _isDeleting = false;
  bool _confirmed = false;

  Future<void> _deleteAccount() async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);

    final appModel = context.read<AppModel>();

    // Fake deletion — simulate server delay then logout
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;
    await appModel.authService.logout();

    if (!mounted) return;
    setState(() {
      _isDeleting = false;
      _confirmed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          AdaptiveWidth(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Back button ──────────────────────────────────────────
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.45),
                          border: Border.all(
                            color:
                                const Color(0xFFF0CA89).withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Icon(
                          CupertinoIcons.back,
                          color: Color(0xFFF4D293),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Body ─────────────────────────────────────────────────
                    Expanded(
                      child: _confirmed
                          ? _SuccessBody(onDone: () {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            })
                          : _ConfirmBody(
                              isDeleting: _isDeleting,
                              onCancel: () => Navigator.pop(context),
                              onDelete: _deleteAccount,
                            ),
                    ),
                    BottomPadding(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Confirm deletion UI ────────────────────────────────────────────────────
class _ConfirmBody extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ConfirmBody({
    required this.isDeleting,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final username = context.watch<AppModel>().authService.user?.username ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Warning icon ─────────────────────────────────────────────────
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.shade900.withValues(alpha: 0.25),
            border: Border.all(
              color: Colors.red.shade400.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.delete_forever_rounded,
            color: Colors.red.shade300,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),

        // ── Title ────────────────────────────────────────────────────────
        const Text(
          'Xóa tài khoản',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (username.isNotEmpty)
          Text(
            '@$username',
            style: TextStyle(
              color: primaryLight.withValues(alpha: 0.85),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 24),

        // ── Warning card ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.red.shade900.withValues(alpha: 0.18),
            border: Border.all(
              color: Colors.red.shade700.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade300, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Hành động không thể hoàn tác',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _WarningItem('Toàn bộ dữ liệu tài khoản sẽ bị xóa vĩnh viễn.'),
              _WarningItem('Lịch sử ván đấu và điểm ELO sẽ mất hoàn toàn.'),
              _WarningItem('Bạn sẽ không thể khôi phục tài khoản này.'),
              _WarningItem('Các ván cờ đang diễn ra sẽ bị tính là thua cuộc.'),
            ],
          ),
        ),
        const Spacer(),

        // ── Action buttons ───────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _OutlineBtn(
                label: 'Huỷ',
                onPressed: isDeleting ? null : onCancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DangerBtn(
                label: 'Xóa tài khoản',
                isLoading: isDeleting,
                onPressed: isDeleting ? null : onDelete,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Success UI ─────────────────────────────────────────────────────────────
class _SuccessBody extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessBody({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.shade900.withValues(alpha: 0.25),
            border: Border.all(
              color: Colors.green.shade400.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.green.shade300,
            size: 44,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tài khoản đã được xóa',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tất cả dữ liệu của bạn đã được xóa thành công.\nCảm ơn bạn đã sử dụng Chess AI.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: _OutlineBtn(label: 'Về trang chủ', onPressed: onDone),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Small helpers ──────────────────────────────────────────────────────────
class _WarningItem extends StatelessWidget {
  final String text;
  const _WarningItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade300,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _OutlineBtn({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.9),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.25),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DangerBtn extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _DangerBtn({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.red.shade900.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
