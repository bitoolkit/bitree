part of 'login.dart';

class _LoginPage {
  _LoginPage(SchoolResponse response)
    : document = parse(response.text),
      url = response.url;

  final Document document;
  final Uri url;

  bool get requiresSms =>
      field('user-object-id').isNotEmpty &&
      document.querySelector(
            '#secondSmsLoginForm, #second-auth-tip, .cas-gateway, #cas-gateway',
          ) !=
          null;

  String field(String id) {
    final element = document.getElementById(id);
    return (element?.attributes['value'] ?? element?.text ?? '').trim();
  }

  String get execution => _element('login-page-flowkey').text.trim();
  String get cryptoKey => _element('login-croypto').text.trim();
  Uri get action {
    final form = document.querySelector('form');
    if (form == null) {
      throw const FormatException('学校登录页面缺少登录表单');
    }
    final target = form.attributes['action'];
    final action = target == null || target.trim().isEmpty
        ? url
        : url.resolve(target);
    if (action.origin != 'https://sso.bit.edu.cn') {
      throw const SchoolRequestError('学校登录表单的地址异常。');
    }
    return action;
  }

  Element _element(String id) =>
      document.getElementById(id) ?? (throw FormatException('学校登录页面缺少 $id'));
}
