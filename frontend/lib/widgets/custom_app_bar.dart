import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogin;
  final VoidCallback onRecorder;
  final bool isAdmin;
  final VoidCallback? onLogout;

  const CustomAppBar({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.onLogin,
    required this.onRecorder,
    this.isAdmin = false,
    this.onLogout,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return AppBar(
      elevation: 2,
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      titleSpacing: 16,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // 🔹 Logo di kiri atas
          Image.asset(
            'assets/images/logo.png',
            height: 36,
          ),
          const SizedBox(width: 8),
          Text(
            "SPM Satgas PPKPT",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Admin",
                style: TextStyle(
                  color: isDarkMode ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),

          // 🔹 Navigasi (Home, Recorder)
          if (!isAdmin) ...[
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              child: Text("Home", style: TextStyle(color: textColor)),
            ),
            TextButton(
              onPressed: onRecorder,
              child: Text("Recorder", style: TextStyle(color: textColor)),
            ),
          ],

          // 🔹 Tombol tema
          IconButton(
            onPressed: onToggleTheme,
            icon: Icon(
              isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              color: textColor,
            ),
          ),

          // 🔹 Tombol login / logout
          isAdmin
              ? TextButton.icon(
                  onPressed: onLogout,
                  icon: Icon(Icons.logout, color: textColor, size: 18),
                  label: Text(
                    "Logout",
                    style: TextStyle(color: textColor),
                  ),
                )
              : Row(
                  children: [
                    TextButton(
                      onPressed: onLogin,
                      child: Text("Masuk", style: TextStyle(color: textColor)),
                    ),
                    ElevatedButton(
                      onPressed: onRecorder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDarkMode ? Colors.white : Colors.black,
                        foregroundColor: isDarkMode ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text("Mulai"),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
