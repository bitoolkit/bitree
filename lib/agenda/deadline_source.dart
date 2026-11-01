enum DeadlineSource {
  lexue('乐学', 'lexue.bit.edu.cn', '/login/index.php'),
  eclass('新延河课堂', 'zy-eclass.bit.edu.cn', '/user/courses'),
  mooc('中国大学MOOC', 'www.icourse163.org', '/member/login.htm');

  const DeadlineSource(this.label, this.host, this._loginPath);

  final String label;
  final String host;
  final String _loginPath;

  Uri get origin => Uri.https(host);
  Uri get loginPage => origin.resolve(_loginPath);
}
