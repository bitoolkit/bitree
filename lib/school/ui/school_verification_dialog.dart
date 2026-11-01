import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/diagnostics.dart';
import '../../core/error_message.dart';
import '../../l10n/l10n.dart';
import '../verification.dart';

Future<String?> verifySchoolLogin(
  BuildContext context,
  SchoolVerification request,
) {
  if (!context.mounted) return Future.value(null);
  return showDialog<String>(
    context: context,
    builder: (_) => _VerificationDialog(request: request),
  );
}

class _VerificationDialog extends StatefulWidget {
  const _VerificationDialog({required this.request});

  final SchoolVerification request;

  @override
  State<_VerificationDialog> createState() => _VerificationDialogState();
}

class _VerificationDialogState extends State<_VerificationDialog> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  Uint8List? _image;
  bool _loading = false;
  bool _submitting = false;
  int _resendSeconds = 0;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.request case SchoolImageVerification(:final image)) {
      _image = image;
    } else {
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.request) {
        case SchoolImageVerification(:final reload):
          final image = await reload();
          if (mounted) setState(() => _image = image);
        case SchoolSmsVerification(:final sendCode):
          final resendAfter = await sendCode();
          if (!mounted) return;
          setState(
            () => _resendSeconds = (resendAfter.inMilliseconds + 999) ~/ 1000,
          );
          _timer?.cancel();
          if (_resendSeconds > 0) {
            _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
              if (_resendSeconds == 1) timer.cancel();
              setState(() => _resendSeconds--);
            });
          }
      }
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('获取登录验证码', failure, stack);
      if (mounted) setState(() => _error = errorMessage(failure));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting || _loading || !_form.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final code = _code.text.trim();
      if (widget.request case SchoolSmsVerification(:final checkCode)) {
        await checkCode(code);
      }
      if (mounted) Navigator.pop(context, code);
    } on Exception catch (failure, stack) {
      AppDiagnostics.instance.error('校验登录验证码', failure, stack);
      if (mounted) setState(() => _error = errorMessage(failure));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sms = widget.request is SchoolSmsVerification;
    final l10n = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(
        sms ? l10n.schoolSmsVerification : l10n.schoolImageVerification,
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.request case SchoolSmsVerification(:final phone))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(l10n.schoolSentToPhone(phone)),
              ),
            if (!sms) ...[
              SizedBox(
                height: 80,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _image == null
                    ? null
                    : Image.memory(_image!, fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _code,
              autofocus: true,
              enabled: !_submitting && !_loading,
              decoration: InputDecoration(
                labelText: l10n.schoolVerificationCode,
              ),
              keyboardType: sms ? TextInputType.number : TextInputType.text,
              textInputAction: TextInputAction.done,
              autofillHints: sms ? const [AutofillHints.oneTimeCode] : null,
              inputFormatters: sms
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              autocorrect: false,
              enableSuggestions: false,
              validator: (value) => value == null || value.trim().isEmpty
                  ? l10n.schoolEnterVerificationCode
                  : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _loading || _submitting || _resendSeconds > 0
                    ? null
                    : _refresh,
                child: Text(
                  !sms
                      ? l10n.schoolRefreshImage
                      : _resendSeconds > 0
                      ? l10n.schoolResendIn(_resendSeconds)
                      : l10n.schoolResend,
                ),
              ),
            ),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _loading || _submitting ? null : _submit,
          child: Text(_submitting ? l10n.schoolVerifying : l10n.confirm),
        ),
      ],
    );
  }
}
