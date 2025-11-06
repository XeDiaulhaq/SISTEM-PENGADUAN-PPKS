import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/custom_app_bar.dart';
import 'pages/home_page.dart';
import 'pages/recorder_page.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';

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

  void toggleTheme() {
    setState(() => isDark = !isDark);
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
              page: const RecorderPage(),
              isDark: isDark,
              toggleTheme: toggleTheme,
            ),

        // ✅ FIX di sini
        '/login': (context) => MainScaffold(
              page: LoginPage(
                onLogin: () {
                  // Arahkan ke dashboard setelah login berhasil
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                onBackHome: () {
                  // Kembali ke halaman beranda
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

  const MainScaffold({
    super.key,
    required this.page,
    required this.isDark,
    required this.toggleTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        isDarkMode: isDark,
        onToggleTheme: toggleTheme,
        onLogin: () => Navigator.pushNamed(context, '/login'),
        onRecorder: () => Navigator.pushNamed(context, '/recorder'),
      ),
      body: page,
    );
  }
}
