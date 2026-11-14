import 'package:flutter/material.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/app_notice.dart';
import '../controller.dart';
import 'school_screen.dart';
import 'school_verification_dialog.dart';

class SchoolAccount extends StatefulWidget {
  const SchoolAccount({super.key, required this.controller});

  final SchoolController controller;

  @override
  State<SchoolAccount> createState() => _SchoolAccountState();
}

class _SchoolAccountState extends State<SchoolAccount> {
  bool _handlingAction = false;

  Future<void> _perform(Future<void> Function() action) async {
    if (_handlingAction) return;
    setState(() => _handlingAction = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _handlingAction = false);
    }
  }

  Future<void> _login() async {
    await openSchoolLogin(context, widget.controller);
  }

  Future<void> _verify() async {
    final success = await widget.controller.restoreAccount(
      verify: (request) => verifySchoolLogin(context, request),
    );
    if (success && mounted) showAppNotice(context, context.l10n.schoolVerified);
  }

  Future<void> _signOut() async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.schoolSignOutQuestion,
      body: l10n.schoolSignOutBody,
      confirmLabel: l10n.schoolSignOutAction,
    );
    if (confirmed) await widget.controller.signOut();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final controller = widget.controller;
    final hasAccount = controller.username != null;
    final needsVerification = controller.verificationRequired;
    final needsLogin = !hasAccount || controller.loginExpired;
    final enabled = !_handlingAction;
    final canLogin = enabled && !controller.busy;
    final onTap = needsLogin
        ? _login
        : needsVerification
        ? _verify
        : _signOut;
    final canTap = needsLogin || needsVerification ? canLogin : false;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Icon(
        Icons.account_circle_outlined,
        size: 36,
        color: hasAccount ? scheme.primary : null,
      ),
      title: Text(controller.username ?? l10n.schoolLogin),
      subtitle: hasAccount || needsVerification
          ? Text(controller.accountStatus.localizedLabel(l10n))
          : null,
      trailing: hasAccount
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (needsVerification || controller.loginExpired)
                  TextButton(
                    onPressed: canLogin
                        ? () => _perform(needsVerification ? _verify : _login)
                        : null,
                    child: Text(
                      needsVerification ? l10n.verifyAction : l10n.schoolLogin,
                    ),
                  ),
                IconButton(
                  tooltip: l10n.schoolSignOutAction,
                  onPressed: enabled ? () => _perform(_signOut) : null,
                  icon: const Icon(Icons.logout_rounded, size: 20),
                ),
              ],
            )
          : const SizedBox.square(
              dimension: 48,
              child: Center(child: Icon(Icons.chevron_right_rounded, size: 20)),
            ),
      onTap: canTap ? () => _perform(onTap) : null,
    );
  }
}
