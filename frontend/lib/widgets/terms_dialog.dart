import 'package:flutter/material.dart';

class TermsDialog extends StatelessWidget {
  final VoidCallback onAccept;

  const TermsDialog({
    super.key,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text(
        'Persetujuan Perekaman',
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dengan melanjutkan perekaman, Anda menyetujui:',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          _buildTermsItem(
            '1. ',
            'Perekaman akan menggunakan kamera dan mikrofon perangkat Anda.',
          ),
          _buildTermsItem(
            '2. ',
            'Video yang direkam akan diproses untuk mengaburkan wajah dan objek sensitif.',
          ),
          _buildTermsItem(
            '3. ',
            'Data yang dikirim akan ditangani secara rahasia sesuai kebijakan privasi.',
          ),
          _buildTermsItem(
            '4. ',
            'Laporan yang dikirim akan ditindaklanjuti oleh pihak berwenang.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Batal',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.white : Colors.black,
            foregroundColor: isDark ? Colors.black : Colors.white,
          ),
          child: const Text('Saya Setuju dan Lanjutkan'),
        ),
      ],
    );
  }

  Widget _buildTermsItem(String number, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(content),
          ),
        ],
      ),
    );
  }
}