import { Button } from "./ui/button";
import { ImageWithFallback } from "./figma/ImageWithFallback";
import { ArrowRight } from "lucide-react";

export function CTA() {
  return (
    <section className="py-20 px-4 dark:bg-neutral-900">
      <div className="container mx-auto">
        <div className="relative rounded-3xl overflow-hidden">
          <div className="absolute inset-0">
            <ImageWithFallback
              src="https://images.unsplash.com/photo-1630283017802-785b7aff9aac?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtb2Rlcm4lMjB3b3Jrc3BhY2UlMjBkZXNrfGVufDF8fHx8MTc2MTIwODUzOXww&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
              alt="Background"
              className="w-full h-full object-cover"
            />
            <div className="absolute inset-0 bg-neutral-900/90 dark:bg-neutral-950/95" />
          </div>
          
          <div className="relative px-8 py-20 text-center text-white">
            <h2 className="mb-6 text-white">
              Laporkan Kejadian dengan Aman dan Anonim
            </h2>
            <p className="text-xl mb-8 max-w-2xl mx-auto opacity-90">
              Sistem ini dirancang untuk memenuhi kebutuhan Satgas PPKPT akan bukti laporan visual, 
              seraya memberikan jaminan anonimitas kepada pelapor dan mengamankan bukti untuk peninjauan di masa depan.
            </p>
            
            <div className="flex flex-col sm:flex-row gap-4 justify-center">
              <Button size="lg" variant="secondary" className="gap-2" asChild>
                <a href="#recorder">
                  Mulai Merekam Laporan
                  <ArrowRight className="w-5 h-5" />
                </a>
              </Button>
              <Button size="lg" variant="outline" className="border-white text-white hover:bg-white hover:text-neutral-900">
                Hubungi Satgas PPKPT
              </Button>
            </div>
            
            <p className="mt-6 text-sm opacity-75">
              Politeknik Negeri Lhokseumawe • Satgas PPKPT
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}