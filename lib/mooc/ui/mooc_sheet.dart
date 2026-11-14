import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/formats.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_dialog.dart';
import '../../ui/editor_sheet.dart';
import '../../ui/sheet_layout.dart';
import '../controller.dart';
import '../credentials.dart';
import '../errors.dart';
import '../login_client.dart';
import 'captcha_dialog.dart';
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

enum _MoocSurface { menu, password, sms, cookie }

class _MoocSheet extends StatefulWidget {
  const _MoocSheet({required this.controller});
  final MoocController controller;

  @override
  State<_MoocSheet> createState() => _MoocSheetState();
}

class _MoocSheetState extends State<_MoocSheet> {
  _MoocSurface _surface = _MoocSurface.menu;
  String? _error;
  bool _webLoginOpen = false;

  void _open(_MoocSurface surface) {
    setState(() {
      _surface = surface;
      _error = null;
    });
  }

  Future<void> _connect(MoocAccount account) async {
    await widget.controller.connect(account);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _webLogin() async {
    if (_webLoginOpen) return;
    setState(() {
      _surface = _MoocSurface.menu;
      _webLoginOpen = true;
      _error = null;
    });
    try {
      final success = await loginToMooc(context, widget.controller);
      if (success && mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _webLoginOpen = false);
    }
  }

  Future<MoocCaptchaSolution?> _verify(
    MoocLoginClient client,
    MoocLoginChallenge challenge,
  ) async {
    if (_webLoginOpen) return null;
    setState(() => _webLoginOpen = true);
    try {
      final cookies = await client.exportCookies();
      if (!mounted) return null;
      return await showMoocCaptchaDialog(
        context,
        challenge: challenge,
        userAgent: client.userAgent,
        cookies: cookies,
      );
    } finally {
      if (mounted) setState(() => _webLoginOpen = false);
    }
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
      if (mounted) setState(() => _error = _loginError(context, error));
    }
  }

  @override
  Widget build(BuildContext context) => switch (_surface) {
    _MoocSurface.password => _PasswordEditor(
      onBack: () => _open(_MoocSurface.menu),
      onConnected: _connect,
      onVerify: _verify,
    ),
    _MoocSurface.sms => _SmsEditor(
      onBack: () => _open(_MoocSurface.menu),
      onConnected: _connect,
      onVerify: _verify,
    ),
    _MoocSurface.cookie => _CookieEditor(
      onBack: () => _open(_MoocSurface.menu),
      onConnected: _connect,
    ),
    _MoocSurface.menu => _Menu(
      controller: widget.controller,
      error: _error,
      enabled: !_webLoginOpen,
      onPassword: () => _open(_MoocSurface.password),
      onSms: () => _open(_MoocSurface.sms),
      onWebLogin: _webLogin,
      onCookie: () => _open(_MoocSurface.cookie),
      onDisconnect: _disconnect,
    ),
  };
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.controller,
    required this.error,
    required this.enabled,
    required this.onPassword,
    required this.onSms,
    required this.onWebLogin,
    required this.onCookie,
    required this.onDisconnect,
  });

  final MoocController controller;
  final String? error;
  final bool enabled;
  final VoidCallback onPassword;
  final VoidCallback onSms;
  final VoidCallback onWebLogin;
  final VoidCallback onCookie;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;
      final l10n = context.l10n;
      final canLogin = enabled && !controller.busy;
      return SheetLayout(
        header: SheetHeader(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.moocName),
              if (controller.account case final account?) ...[
                const SizedBox(height: 6),
                Text(
                  account.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (controller.needsLogin)
                  Text(
                    controller.status.localizedLabel(l10n),
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
                leading: const Icon(Icons.password_rounded),
                title: Text(l10n.moocPasswordLogin),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                enabled: canLogin,
                onTap: canLogin ? onPassword : null,
              ),
              ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: Text(l10n.moocSmsLogin),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                enabled: canLogin,
                onTap: canLogin ? onSms : null,
              ),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: Text(l10n.webLogin),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                enabled: canLogin,
                onTap: canLogin ? onWebLogin : null,
              ),
              ListTile(
                leading: const Icon(Icons.key_outlined),
                title: Text(l10n.useCookie),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                enabled: canLogin,
                onTap: canLogin ? onCookie : null,
              ),
              if (controller.account != null) ...[
                const Divider(height: 24),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: scheme.error),
                  title: Text(
                    l10n.moocSignOutAccount,
                    style: TextStyle(color: scheme.error),
                  ),
                  enabled: canLogin,
                  onTap: canLogin ? onDisconnect : null,
                ),
              ],
              if (error case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(message, style: TextStyle(color: scheme.error)),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _PasswordEditor extends StatefulWidget {
  const _PasswordEditor({
    required this.onBack,
    required this.onConnected,
    required this.onVerify,
  });

  final VoidCallback onBack;
  final Future<void> Function(MoocAccount account) onConnected;
  final Future<MoocCaptchaSolution?> Function(
    MoocLoginClient client,
    MoocLoginChallenge challenge,
  )
  onVerify;

  @override
  State<_PasswordEditor> createState() => _PasswordEditorState();
}

class _PasswordEditorState extends State<_PasswordEditor> {
  final _form = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _password = TextEditingController();
  final _client = MoocLoginClient();
  bool _saving = false;
  bool _hidePassword = true;
  String? _error;
  MoocLoginChallenge? _challenge;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    await _login();
  }

  Future<void> _login({
    MoocCaptchaSolution? captcha,
    bool allowChallenge = true,
  }) async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _challenge = null;
    });
    MoocCaptchaSolution? retry;
    try {
      final account = await _client.loginWithPassword(
        account: _account.text.trim(),
        password: _password.text,
        captcha: captcha,
      );
      await widget.onConnected(account);
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _error = _loginError(context, error);
          _challenge = error is MoocLoginChallenge ? error : null;
        });
        if (error is MoocLoginChallenge && allowChallenge) {
          retry = await widget.onVerify(_client, error);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (retry != null && mounted) {
      await _login(captcha: retry, allowChallenge: false);
    }
  }

  Future<void> _verifyAndRetry() async {
    final challenge = _challenge;
    if (challenge == null || _saving) return;
    final captcha = await widget.onVerify(_client, challenge);
    if (captcha != null && mounted) {
      await _login(captcha: captcha, allowChallenge: false);
    }
  }

  @override
  void dispose() {
    _client.close();
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EditorSheet(
      title: l10n.moocPasswordLogin,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      saveLabel: Text(_saving ? l10n.moocSigningIn : l10n.moocSignIn),
      error: _error,
      errorAction: _challenge != null
          ? TextButton(
              onPressed: _saving ? null : _verifyAndRetry,
              child: Text(l10n.moocVerifyNow),
            )
          : null,
      onBack: widget.onBack,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _account,
              enabled: !_saving,
              decoration: InputDecoration(labelText: l10n.moocPhoneOrEmail),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.moocEnterAccount
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              enabled: !_saving,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: l10n.moocPassword,
                suffixIcon: IconButton(
                  tooltip: _hidePassword
                      ? l10n.moocShowPassword
                      : l10n.moocHidePassword,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              validator: (value) => value == null || value.isEmpty
                  ? l10n.moocEnterPassword
                  : null,
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}

enum _SmsChallengeAction { sendCode, login }

class _SmsEditor extends StatefulWidget {
  const _SmsEditor({
    required this.onBack,
    required this.onConnected,
    required this.onVerify,
  });

  final VoidCallback onBack;
  final Future<void> Function(MoocAccount account) onConnected;
  final Future<MoocCaptchaSolution?> Function(
    MoocLoginClient client,
    MoocLoginChallenge challenge,
  )
  onVerify;

  @override
  State<_SmsEditor> createState() => _SmsEditorState();
}

class _SmsEditorState extends State<_SmsEditor> {
  final _form = GlobalKey<FormState>(debugLabel: 'mooc-sms-form');
  final _phoneField = GlobalKey<FormFieldState<String>>(
    debugLabel: 'mooc-sms-phone',
  );
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _client = MoocLoginClient();
  Timer? _timer;
  bool _sending = false;
  bool _saving = false;
  int _resendSeconds = 0;
  String? _error;
  MoocLoginChallenge? _challenge;
  _SmsChallengeAction? _challengeAction;

  void _setError(Object error, _SmsChallengeAction action) {
    _error = _loginError(context, error, sms: true);
    _challenge = error is MoocLoginChallenge ? error : null;
    _challengeAction = error is MoocLoginChallenge ? action : null;
  }

  Future<void> _send() async {
    if (_sending || _saving || !_phoneField.currentState!.validate()) return;
    await _requestCode();
  }

  Future<void> _requestCode({
    MoocCaptchaSolution? captcha,
    bool allowChallenge = true,
  }) async {
    if (_sending || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _challenge = null;
      _challengeAction = null;
    });
    MoocCaptchaSolution? retry;
    try {
      final delay = await _client.sendSmsCode(
        _phone.text.trim(),
        captcha: captcha,
      );
      if (!mounted) return;
      _startResendCountdown(delay);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _setError(error, _SmsChallengeAction.sendCode));
        if (error is MoocLoginChallenge && allowChallenge) {
          retry = await widget.onVerify(_client, error);
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (retry != null && mounted) {
      await _requestCode(captcha: retry, allowChallenge: false);
    }
  }

  Future<void> _save() async {
    if (_sending || _saving || !_form.currentState!.validate()) return;
    await _login();
  }

  Future<void> _login({
    MoocCaptchaSolution? captcha,
    bool allowChallenge = true,
  }) async {
    if (_sending || _saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _challenge = null;
      _challengeAction = null;
    });
    MoocCaptchaSolution? retry;
    try {
      final account = await _client.loginWithSmsCode(
        phone: _phone.text.trim(),
        code: _code.text.trim(),
        captcha: captcha,
      );
      await widget.onConnected(account);
    } on Exception catch (error) {
      if (mounted) {
        setState(() => _setError(error, _SmsChallengeAction.login));
        if (error is MoocLoginChallenge && allowChallenge) {
          retry = await widget.onVerify(_client, error);
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (retry != null && mounted) {
      await _login(captcha: retry, allowChallenge: false);
    }
  }

  void _startResendCountdown(Duration delay) {
    final seconds = (delay.inMilliseconds + 999) ~/ 1000;
    _timer?.cancel();
    setState(() => _resendSeconds = seconds);
    if (seconds <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _verifyAndRetry() async {
    final challenge = _challenge;
    final action = _challengeAction;
    if (challenge == null || action == null || _sending || _saving) return;
    final captcha = await widget.onVerify(_client, challenge);
    if (captcha == null || !mounted) return;
    switch (action) {
      case _SmsChallengeAction.sendCode:
        await _requestCode(captcha: captcha, allowChallenge: false);
      case _SmsChallengeAction.login:
        await _login(captcha: captcha, allowChallenge: false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _client.close();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final busy = _sending || _saving;
    return EditorSheet(
      title: l10n.moocSmsLogin,
      formKey: _form,
      saving: _saving,
      onSave: _save,
      saveLabel: Text(_saving ? l10n.moocSigningIn : l10n.moocSignIn),
      error: _error,
      errorAction: _challenge != null
          ? TextButton(
              onPressed: busy ? null : _verifyAndRetry,
              child: Text(l10n.moocVerifyNow),
            )
          : null,
      onBack: widget.onBack,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: _phoneField,
              controller: _phone,
              enabled: !busy,
              decoration: InputDecoration(labelText: l10n.moocPhone),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: (value) => switch (value?.trim()) {
                null || '' => l10n.moocEnterPhone,
                final phone when !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone) =>
                  l10n.moocInvalidPhone,
                _ => null,
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: busy || _resendSeconds > 0 ? null : _send,
                child: Text(
                  _sending
                      ? l10n.moocSendingCode
                      : _resendSeconds > 0
                      ? l10n.moocResendIn(_resendSeconds)
                      : l10n.moocSendCode,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _code,
              enabled: !busy,
              decoration: InputDecoration(labelText: l10n.moocSmsCode),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.moocEnterSmsCode
                  : null,
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CookieEditor extends StatefulWidget {
  const _CookieEditor({required this.onBack, required this.onConnected});

  final VoidCallback onBack;
  final Future<void> Function(MoocAccount account) onConnected;

  @override
  State<_CookieEditor> createState() => _CookieEditorState();
}

class _CookieEditorState extends State<_CookieEditor> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _client = MoocLoginClient();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final cookies = MoocCredentials.cookiesFromHeader(_text.text);
      final account = await _client.verifyCookies(cookies);
      await widget.onConnected(account);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = _loginError(context, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _client.close();
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
      onBack: widget.onBack,
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
        ],
      ),
    );
  }
}

String _loginError(BuildContext context, Object error, {bool sms = false}) {
  final l10n = context.l10n;
  if (error is MoocLoginChallenge) return l10n.moocLoginChallenge;
  if (error is MoocLoginException) {
    return switch (error.kind) {
      MoocLoginError.wrongCredentials =>
        sms ? l10n.moocSmsLoginFailed : l10n.moocWrongCredentials,
      MoocLoginError.invalidPhone => l10n.moocInvalidPhone,
      MoocLoginError.rateLimited => l10n.moocTooFrequent,
      MoocLoginError.smsRequired => l10n.moocGetCodeFirst,
      MoocLoginError.invalidCode => l10n.moocInvalidSmsCode,
      MoocLoginError.network => l10n.moocNetworkFailed,
      MoocLoginError.noSession => l10n.moocNoSession,
      MoocLoginError.unavailable ||
      MoocLoginError.malformedResponse => l10n.moocLoginUnavailable,
    };
  }
  if (error is MoocFailure) return localizedMoocFailure(l10n, error);
  if (error is SocketException) return l10n.moocNetworkFailed;
  return l10n.moocLoginFailed;
}
