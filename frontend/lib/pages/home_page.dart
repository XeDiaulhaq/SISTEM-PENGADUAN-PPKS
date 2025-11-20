import 'package:flutter/material.dart';
import '../widgets/stats_widget.dart'; // opsional kalau mau tambahkan statistik nanti
import '../widgets/footer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    children: [
                      // (Theme toggle is provided by the AppBar; no in-page toggle here)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 800;
                          return Flex(
                            direction: isWide ? Axis.horizontal : Axis.vertical,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Bagian kiri: teks
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Sistem Pengaduan Mahasiswa",
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Satgas PPKPT PNL",
                                      style: Theme.of(context)
                                          .textTheme
                                          .displaySmall
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Satuan Tugas Pencegahan dan Penanganan Kekerasan "
                                      "Perguruan Tinggi Politeknik Negeri Lhokseumawe (Satgas PPKPT PNL) "
                                      "merupakan inisiatif untuk melindungi seluruh civitas akademika dari "
                                      "berbagai bentuk kekerasan di lingkungan kampus. Sistem ini menyediakan "
                                      "fasilitas pelaporan secara anonim dengan dukungan teknologi anonimisasi "
                                      "wajah guna menjaga kerahasiaan dan keamanan identitas pelapor.",
                                      textAlign: TextAlign.justify,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontSize: 15,
                                            height: 1.5,
                                          ),
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/recorder');
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.primary,
                                        foregroundColor:
                                            Theme.of(context).colorScheme.onPrimary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                      label: const Text(
                                        "Mulai Merekam",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (isWide) const SizedBox(width: 32) else const SizedBox(height: 24),

                              // Bagian kanan: gambar hero
                              Expanded(
                                flex: isWide ? 1 : 0,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Efek blur belakang
                                    Container(
                                      width: double.infinity,
                                      height: isWide ? 320 : 220,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onBackground
                                            .withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Theme.of(context)
                                              .shadowColor
                                              .withOpacity(0.06),
                                            blurRadius: 18,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Gambar utama
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.asset(
                                        'assets/images/hero_banner.png',
                                        width: double.infinity,
                                        height: isWide ? 300 : 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // Label “Merekam”
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surface
                                              .withOpacity(0.95),
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: [
                                            BoxShadow(
                                                  color: Theme.of(context)
                                                    .shadowColor
                                                    .withOpacity(0.08),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: const BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              "Merekam",
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      const Footer(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
