import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onBackHome;

  LoginPage({super.key, required this.onLogin, required this.onBackHome});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String error = "";

  void _handleSubmit() {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username == "admin" && password == "pass") {
      widget.onLogin();
    } else {
      setState(() {
        error = "Username atau password salah";
      });
      Future.delayed(const Duration(seconds: 3), () {
        setState(() {
          error = "";
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header
                Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(Icons.shield, size: 32, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    Text("Admin Login",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 8),
                    Text(
                      "Masuk untuk mengakses dashboard admin",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form Card
                Card(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: "Username",
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Password",
                            filled: true,
                            fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Error message
                        if (error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.red[900]?.withOpacity(0.7) : Colors.red[100],
                              border: Border.all(color: isDark ? Colors.red[800]! : Colors.red[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              error,
                              style: TextStyle(color: isDark ? Colors.red[300] : Colors.red[600]),
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text("Masuk"),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: isDark ? Colors.white : Colors.black87,
                              foregroundColor: isDark ? Colors.black87 : Colors.white,
                            ),
                            onPressed: _handleSubmit,
                          ),
                        ),

                        const SizedBox(height: 16),
                        Text(
                          "Sistem Pengaduan Mahasiswa Satgas PPKPT\nPoliteknik Negeri Lhokseumawe",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Kembali ke Beranda
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: widget.onBackHome,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: isDark ? Colors.grey[400]! : Colors.black87),
                    ),
                    child: Text(
                      "← Kembali ke Beranda",
                      style: TextStyle(color: isDark ? Colors.grey[400] : Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
