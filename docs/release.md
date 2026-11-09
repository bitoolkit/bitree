# 发布与错误堆栈

Dev Build 和 Release 工作流只负责编译、打包和上传产物。静态检查与测试位于
`.github/workflows/checks.yml`，产物检查位于
`.github/workflows/verify-packages.yml`，都不参与发布构建。分支保护应要求
`Checks` 通过后再合并或发布。

发布包不包含 Dart 调试信息。CI 会把符号文件保存为 `debug-symbols-平台-构建机架构-版本`，保留 90 天，可在对应的 Actions 构建页面下载。Android 的 APK 和 AAB 符号分别位于 `apk/`、`appbundle/` 目录。

还原错误堆栈时，先下载与日志版本、平台和架构一致的符号文件，再把堆栈保存为 `stacktrace.txt`。以下以 Android arm64 为例：

```sh
flutter symbolize --debug-info=app.android-arm64.symbols --input=stacktrace.txt
```
