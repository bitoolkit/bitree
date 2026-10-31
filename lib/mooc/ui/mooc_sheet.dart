import 'package:flutter/material.dart';

import '../../core/async/cancelable_request.dart';
import '../../core/error_message.dart';
import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/external_link.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../credentials.dart';
import 'login.dart';

Future<bool> showMoocAccount(
  BuildContext context,
  MoocController controller,
) async =>
    await showAppSheet<bool>(
      context: context,
      builder: (_) => _MoocSheet(controller: controller),
    ) ==
    true;

class MoocAccountTile extends StatelessWidget {
  const MoocAccountTile({super.key, required this.controller});
  final MoocController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: const Icon(Icons.school_outlined, size: 36),
      title: Text(context.l10n.moocName),
      subtitle: Text(
        [
          controller.account?.name,
          if (controller.needsLogin)
            controller.status.localizedLabel(context.l10n),
        ].whereType<String>().join(' · '),
      ),
      trailing: const SizedBox.square(
        dimension: 48,
        child: Center(child: Icon(Icons.chevron_right_rounded, size: 20)),
      ),
      onTap: () => showMoocAccount(context, controller),
    ),
  );
}

class _MoocSheet extends StatefulWidget {
  const _MoocSheet({required this.controller});
  final MoocController controller;
  @override
  State<_MoocSheet> createState() => _MoocSheetState();
}

class _MoocSheetState extends State<_MoocSheet> {
  String? _error;
  bool _loginOpen = false;

  Future<void> _login() async {
    if (_loginOpen) return;
    setState(() {
      _loginOpen = true;
      _error = null;
    });
    try {
      final success = await loginToMooc(context, widget.controller);
      if (success && mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _loginOpen = false);
    }
  }

  Future<void> _cookie() async {
    final success = await showAppSheet<bool>(
      context: context,
      builder: (_) => _CookieSheet(controller: widget.controller),
    );
    if (success == true && mounted) Navigator.pop(context, true);
  }

  Future<void> _disconnect() async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.moocSignOutQuestion,
      body: l10n.moocSignOutBody,
      confirmLabel: l10n.exitAction,
    );
    if (!confirmed) return;
    try {
      await widget.controller.disconnect();
      if (mounted) setState(() => _error = null);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = errorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final model = widget.controller;
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final enabled = !model.busy && !_loginOpen;
      final l10n = context.l10n;
      return SheetLayout(
        header: SheetHeader(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.moocName),
              if (model.account case final account?) ...[
                const SizedBox(height: 6),
                Text(
                  account.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (model.needsLogin)
                  Text(
                    model.status.localizedLabel(l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
              ],
            ],
          ),
          actions: const [SheetCloseButton()],
        ),
        content: ListTileTheme(
          data: theme.listTileTheme.copyWith(
            contentPadding: EdgeInsets.zero,
            minTileHeight: 48,
            minVerticalPadding: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: Text(model.needsLogin ? l10n.webLogin : l10n.relogin),
                subtitle: model.needsLogin ? Text(l10n.moocLoginMethods) : null,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                enabled: enabled,
                onTap: enabled ? _login : null,
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(l10n.useCookie),
                subtitle: model.needsLogin ? Text(l10n.backupLogin) : null,
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                enabled: enabled,
                onTap: enabled ? _cookie : null,
              ),
              if (model.account != null) ...[
                const Divider(height: 24),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: scheme.error),
                  title: Text(
                    l10n.moocSignOutAccount,
                    style: TextStyle(color: scheme.error),
                  ),
                  enabled: enabled,
                  onTap: enabled ? _disconnect : null,
                ),
              ],
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _CookieSheet extends StatefulWidget {
  const _CookieSheet({required this.controller});
  final MoocController controller;
  @override
  State<_CookieSheet> createState() => _CookieSheetState();
}

class _CookieSheetState extends State<_CookieSheet> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cookies = MoocCredentials.cookiesFromHeader(_text.text);
      final success = await loginToMooc(
        context,
        widget.controller,
        initialCookies: cookies,
      );
      if (success && mounted) Navigator.pop(context, true);
    } on RequestCancelled {
      if (mounted) {
        setState(() => _error = context.l10n.moocConnectionCancelled);
      }
    } on Exception catch (error) {
      if (mounted) {
        final raw = error is FormatException
            ? error.message
            : widget.controller.error ?? errorMessage(error);
        setState(() => _error = localizedKnownError(context.l10n, raw) ?? raw);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EditorSheet(
      title: l10n.useCookie,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      saveLabel: Text(_saving ? l10n.moocConnecting : l10n.connect),
      error: _error,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.moocCookieInstructions),
          const SizedBox(height: 16),
          TextFormField(
            controller: _text,
            enabled: !_saving,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Cookie',
              alignLabelWithHint: true,
            ),
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            validator: (value) => value == null || value.trim().isEmpty
                ? l10n.moocPasteCookie
                : null,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => openExternalLink(
              context,
              MoocCredentials.origin.resolve('/member/login.htm'),
              failureTitle: l10n.openMoocFailed,
            ),
            child: Text(l10n.openOfficialLogin),
          ),
        ],
      ),
    );
  }
}
