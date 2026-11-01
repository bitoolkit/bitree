import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

String errorMessage(Object error) => switch (error) {
  SocketException() => '无法连接网络，请检查网络后重试。',
  TimeoutException() => '网络请求超时，请稍后重试。',
  HandshakeException() => '无法验证网站证书，请检查系统时间和网络。',
  FormatException() => '数据格式不正确：${error.message}',
  FileSystemException() => '无法读写本地文件：${error.message}',
  PlatformException() => '无法调用系统服务：${error.message ?? error.code}',
  _ => '操作失败，请重试。详细信息可在设置中查看日志。',
};
