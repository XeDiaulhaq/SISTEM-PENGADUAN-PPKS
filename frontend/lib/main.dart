import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/custom_app_bar.dart';
import 'widgets/app_state_scope.dart';
import 'pages/home_page.dart';
import 'pages/recorder_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'services/auth_storage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;
  final AuthStorage _authStorage = AuthStorage();

  void toggleTheme() {
    setState(() => isDark = !isDark);
  }

  Future<void> _handleLogout(BuildContext context) async {
    await _authStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      ModalRoute.withName('/home'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPM Satgas PPKPT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/home',
      routes: {
        '/home': (context) => MainScaffold(
              page: const HomePage(),
              isDark: isDark,
              toggleTheme: toggleTheme,
            ),
        '/recorder': (context) => MainScaffold(
              page: RecorderPage(), // jangan const
              isDark: isDark,
              toggleTheme: toggleTheme,
            ),
        '/login': (context) => MainScaffold(
              page: LoginPage(
                onLogin: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                onBackHome: () {
                  Navigator.popUntil(context, ModalRoute.withName('/home'));
                },
              ),
              isDark: isDark,
              toggleTheme: toggleTheme,
            ),
        '/dashboard': (context) => MainScaffold(
              page: const DashboardPage(),
              isDark: isDark,
              toggleTheme: toggleTheme,
              isAdmin: true,
              onLogout: () {
                _handleLogout(context);
              },
            ),
      },
    );
  }
}

/// Scaffold utama yang menampilkan AppBar + body halaman
class MainScaffold extends StatelessWidget {
  final Widget page;
  final bool isDark;
  final VoidCallback toggleTheme;
  final bool isAdmin;
  final VoidCallback? onLogout;

  const MainScaffold({
    super.key,
    required this.page,
    required this.isDark,
    required this.toggleTheme,
    this.isAdmin = false,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        isDarkMode: isDark,
        onToggleTheme: toggleTheme,
        onLogin: () => Navigator.pushNamed(context, '/login'),
        onRecorder: () => Navigator.pushReplacementNamed(context, '/recorder'),
        isAdmin: isAdmin,
        onLogout: onLogout,
      ),
      body: AppStateScope(
        isDark: isDark,
        toggleTheme: toggleTheme,
        child: page,
      ),
    );
  }
}
