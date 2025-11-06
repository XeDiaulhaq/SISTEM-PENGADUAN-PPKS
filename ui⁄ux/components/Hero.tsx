import { Button } from "./ui/button";
import { Play } from "lucide-react";
import { ImageWithFallback } from "./figma/ImageWithFallback";

interface HeroProps {
  isAdmin?: boolean;
  onLogout?: () => void;
}

export function Hero({ isAdmin = false, onLogout }: HeroProps) {
  return (
    <section
      id="home"
      className="pt-24 pb-16 md:pt-32 md:pb-20 px-4 dark:bg-neutral-950 relative"
    >
      <div className="container mx-auto max-w-7xl">
        <div className="grid lg:grid-cols-2 gap-8 lg:gap-12 items-center">
          <div className="order-2 lg:order-1">
            <h1 className="mb-6 dark:text-white text-3xl md:text-4xl lg:text-5xl">
              Sistem Pengaduan Mahasiswa
              <span className="block text-neutral-900 dark:text-neutral-100">
                Satgas PPKPT PNL
              </span>
            </h1>

            <p className="text-lg md:text-xl text-neutral-600 dark:text-neutral-400 mb-8 max-w-xl text-justify">
              Satuan Tugas Pencegahan dan Penanganan Kekerasan Perguruan Tinggi 
              Politeknik Negeri Lhokseumawe (Satgas PPKPT PNL) merupakan inisiatif untuk 
              melindungi seluruh civitas akademika dari berbagai bentuk kekerasan 
              di lingkungan kampus. Sistem ini menyediakan fasilitas pelaporan secara 
              anonim dengan dukungan teknologi anonimisasi wajah guna menjaga kerahasiaan 
              dan keamanan identitas pelapor.
            </p>

            <div className="flex flex-col sm:flex-row gap-4">
              <Button
                size="lg"
                className="gap-2 bg-neutral-900 dark:bg-white dark:text-neutral-900 hover:bg-neutral-800 dark:hover:bg-neutral-100 w-full sm:w-auto"
                asChild
              >
                <a href="#recorder">
                  <Play className="w-5 h-5" />
                  Mulai Merekam
                </a>
              </Button>
            </div>
          </div>

          <div className="relative order-1 lg:order-2">
            <div className="absolute inset-0 bg-neutral-900 dark:bg-neutral-100 rounded-3xl blur-3xl opacity-10" />
            <div className="relative rounded-2xl overflow-hidden shadow-2xl border-4 md:border-8 border-white dark:border-neutral-900">
              <ImageWithFallback
                src="https://images.unsplash.com/photo-1586739050530-2fddeb1770d4?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxjYW1wdXMlMjBzYWZldHklMjBzdXBwb3J0fGVufDF8fHx8MTc2MTc1MDU5MHww&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
                alt="Sistem Pengaduan Mahasiswa PPKPT"
                className="w-full h-auto"
              />
              <div className="absolute top-2 right-2 md:top-4 md:right-4 px-2 py-1 md:px-3 md:py-2 bg-white/90 dark:bg-neutral-900/90 backdrop-blur-sm rounded-lg shadow-lg">
                <div className="flex items-center gap-2">
                  <div className="w-2 h-2 bg-red-500 rounded-full animate-pulse" />
                  <span className="text-xs md:text-sm dark:text-white">
                    Merekam
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}