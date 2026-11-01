enum DeadlineSource {
  lexue('lexue.bit.edu.cn', '/login/index.php'),
  eclass('zy-eclass.bit.edu.cn', '/user/courses'),
  mooc('www.icourse163.org', '/member/login.htm');

  const DeadlineSource(this.host, this._loginPath);

  final String host;
  final String _loginPath;

  Uri get origin => Uri.https(host);
  Uri get loginPage => origin.resolve(_loginPath);
}
