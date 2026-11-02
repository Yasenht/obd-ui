import 'package:flutter/material.dart';

import 'app_controller.dart';

/// مزوّد حالة التطبيق فوق الشجرة — تغليف بسيط حول InheritedNotifier
/// (بدون حزم خارجية) بحيث يعيد البناء عند أي تغيير في [AppController].
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope غير موجود في الشجرة فوق هذا السياق.');
    return scope!.notifier!;
  }
}

extension AppContextX on BuildContext {
  /// وصول مختصر: `context.controller.someState`.
  AppController get controller => AppScope.of(this);
}
