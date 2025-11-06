import { Video, Twitter, Github, Linkedin, Mail } from "lucide-react";

export function Footer() {
  return (
    <footer className="bg-neutral-900 dark:bg-black text-neutral-300 py-8 md:py-12 px-4">
      <div className="container mx-auto max-w-7xl">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-6 md:gap-8 mb-6 md:mb-8">
          <div className="col-span-2 md:col-span-1">
            <div className="flex items-center gap-2 mb-3 md:mb-4">
              <div className="w-8 h-8 bg-white dark:bg-neutral-100 rounded-lg flex items-center justify-center">
                <Video className="w-4 h-4 text-neutral-900" />
              </div>
              <span className="text-white text-sm md:text-base">SPM Satgas PPKPT</span>
            </div>
            <p className="text-xs md:text-sm">
              Sistem Pengaduan Mahasiswa Satgas PPKPT - Politeknik Negeri Lhokseumawe
            </p>
          </div>
          
          <div>
            <h4 className="text-white mb-3 md:mb-4 text-sm md:text-base">Produk</h4>
            <ul className="space-y-2 text-xs md:text-sm">
              <li><a href="#" className="hover:text-white transition-colors">Fitur</a></li>
              <li><a href="#" className="hover:text-white transition-colors">FAQ</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Changelog</a></li>
            </ul>
          </div>
          
          <div>
            <h4 className="text-white mb-3 md:mb-4 text-sm md:text-base">Perusahaan</h4>
            <ul className="space-y-2 text-xs md:text-sm">
              <li><a href="#" className="hover:text-white transition-colors">Tentang</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Blog</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Karir</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Kontak</a></li>
            </ul>
          </div>
          
          <div>
            <h4 className="text-white mb-3 md:mb-4 text-sm md:text-base">Legal</h4>
            <ul className="space-y-2 text-xs md:text-sm">
              <li><a href="#" className="hover:text-white transition-colors">Kebijakan Privasi</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Syarat Layanan</a></li>
              <li><a href="#" className="hover:text-white transition-colors">Kebijakan Cookie</a></li>
              <li><a href="#login" className="hover:text-white transition-colors">Admin Login</a></li>
            </ul>
          </div>
        </div>
        
        <div className="pt-6 md:pt-8 border-t border-neutral-800 flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-xs md:text-sm text-center md:text-left">
            © 2025 SPM Satgas PPKPT - Politeknik Negeri Lhokseumawe. Semua hak dilindungi.
          </p>
          
          <div className="flex items-center gap-4">
            <a href="#" className="hover:text-white transition-colors">
              <Twitter className="w-4 h-4 md:w-5 md:h-5" />
            </a>
            <a href="#" className="hover:text-white transition-colors">
              <Github className="w-4 h-4 md:w-5 md:h-5" />
            </a>
            <a href="#" className="hover:text-white transition-colors">
              <Linkedin className="w-4 h-4 md:w-5 md:h-5" />
            </a>
            <a href="#" className="hover:text-white transition-colors">
              <Mail className="w-4 h-4 md:w-5 md:h-5" />
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}