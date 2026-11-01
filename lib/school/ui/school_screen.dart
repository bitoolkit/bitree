import 'package:flutter/material.dart';

import '../../agenda/deadline_source.dart';
import '../../app/controller.dart';
import '../../l10n/l10n.dart';
import '../../ui/app_page.dart';
import '../storage.dart';
import '../verification.dart';
import 'school_verification_sheet.dart';

Future<bool?> openSchoolLogin(
  BuildContext context,
  AppController controller, {
  DeadlineSource? source,
}) async {
  if (controller.timetable.busy || controller.school.busy) return null;
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => _SchoolScreen(controller: controller, source: source),
    ),
  );
}

class _SchoolScreen extends StatefulWidget {
  const _SchoolScreen({required this.controller, this.source});

  final AppController controller;
  final DeadlineSource? source;

  @override
  State<_SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends State<_SchoolScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(
    text: widget.controller.school.username,
  );
  final _password = TextEditingController();
  bool _running = false;
  bool _hidePassword = true;

  Future<void> _run() async {
    if (_running || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _running = true;
    });
    final controller = widget.controller;
    Future<String?> verify(SchoolVerification request) =>
        verifySchoolLogin(context, request);
    try {
      final signedIn = await controller.school.signIn(
        SchoolCredentials(username: _username.text, password: _password.text),
        verify,
        source: widget.source,
      );
      if (!mounted) return;
      if (!signedIn) return;
      _password.clear();
      _running = false;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void dispose() {
    if (_running) widget.controller.school.cancel();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppRoutePage(
    title: context.l10n.schoolLogin,
    maxWidth: 448,
    showProgress: _running,
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: _buildForm(),
        ),
      ),
    ),
  );

  Widget _buildForm() => AutofillGroup(
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _username,
            enabled: !_running,
            readOnly: widget.controller.school.username != null,
            decoration: InputDecoration(
              labelText: context.l10n.schoolStudentId,
            ),
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            enableSuggestions: false,
            validator: (value) => value == null || value.isEmpty
                ? context.l10n.schoolEnterStudentId
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !_running,
            autofocus: widget.controller.school.username != null,
            obscureText: _hidePassword,
            decoration: InputDecoration(
              labelText: context.l10n.schoolPassword,
              suffixIcon: IconButton(
                tooltip: _hidePassword
                    ? context.l10n.schoolShowPassword
                    : context.l10n.schoolHidePassword,
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: _running
                    ? null
                    : () => setState(() => _hidePassword = !_hidePassword),
              ),
            ),
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            validator: (value) => value == null || value.isEmpty
                ? context.l10n.schoolEnterPassword
                : null,
            onFieldSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _running ? null : _run,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_running) ...[
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  _running
                      ? context.l10n.schoolLoggingIn
                      : context.l10n.schoolLogin,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
