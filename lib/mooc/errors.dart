enum MoocIssue {
  loginExpired,
  noSession,
  readAccountFailed,
  requestBusy,
  saveResultFailed,
}

class MoocFailure implements Exception {
  const MoocFailure(this.message) : issue = null;

  const MoocFailure.issue(this.issue) : message = null;

  final String? message;
  final MoocIssue? issue;

  @override
  String toString() => message ?? issue?.name ?? 'MOOC request failed';
}

class MoocLoginRequired extends MoocFailure {
  const MoocLoginRequired() : super.issue(MoocIssue.loginExpired);
}
