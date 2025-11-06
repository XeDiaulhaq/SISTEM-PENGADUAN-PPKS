import { Eye, Zap, Lock, Download, Settings, Users } from "lucide-react";
import { Card } from "./ui/card";

const features = [
  {
    icon: Eye,
    title: "Akses Kamera Real-time",
    description: "Sistem meminta dan menginisiasi akses kamera pada perangkat klien untuk perekaman langsung.",
  },
  {
    icon: Lock,
    title: "Deteksi Wajah Otomatis",
    description: "Server mengidentifikasi wajah dari stream video secara real-time menggunakan OpenCV DNN.",
  },
  {
    icon: Zap,
    title: "Aplikasi Blur Otomatis",
    description: "Server menerapkan efek blur pada region wajah yang terdeteksi secara otomatis dan real-time.",
  },
  {
    icon: Settings,
    title: "Preview Umpan Balik",
    description: "Sistem mengirimkan stream video ter-anonimisasi kembali ke klien untuk verifikasi keamanan.",
  },
  {
    icon: Download,
    title: "Perekaman Sisi Server",
    description: "Stream video yang telah diburamkan disimpan ke file video persisten di server menggunakan OpenCV.",
  },
  {
    icon: Users,
    title: "Dashboard Admin Terproteksi",
    description: "Antarmuka terautentikasi bagi Satgas PPKPT untuk mengakses dan meninjau daftar laporan video.",
  }
];

export function Features() {
  return (
    <section id="features" className="py-20 px-4 bg-neutral-50 dark:bg-neutral-900">
      <div className="container mx-auto">
        <div className="text-center mb-16">
          <h2 className="mb-4 dark:text-white">
            Kebutuhan Fungsional Sistem
            <span className="block">Pengaduan PPKPT</span>
          </h2>
          <p className="text-xl text-neutral-600 dark:text-neutral-400 max-w-2xl mx-auto">
            Sistem dirancang untuk memberikan jaminan anonimitas visual sejak proses perekaman dimulai.
          </p>
        </div>
        
        <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature, index) => (
            <Card key={index} className="p-6 hover:shadow-lg transition-shadow dark:bg-neutral-800 dark:border-neutral-700">
              <div className="w-12 h-12 rounded-xl bg-neutral-900 dark:bg-neutral-100 flex items-center justify-center mb-4">
                <feature.icon className="w-6 h-6 text-white dark:text-neutral-900" />
              </div>
              <h3 className="mb-2 dark:text-white">{feature.title}</h3>
              <p className="text-neutral-600 dark:text-neutral-400">{feature.description}</p>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}