import 'package:flutter/widgets.dart';

class AppStateScope extends InheritedWidget {
  final bool isDark;
  final VoidCallback toggleTheme;

  const AppStateScope({
    super.key,
    required this.isDark,
    required this.toggleTheme,
    required super.child,
  });

  static AppStateScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null) {
      throw FlutterError('AppStateScope not found in context');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(covariant AppStateScope oldWidget) {
    return oldWidget.isDark != isDark;
  }
}
