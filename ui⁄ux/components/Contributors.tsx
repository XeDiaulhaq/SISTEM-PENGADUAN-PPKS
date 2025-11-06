import { Card } from "./ui/card";
import { Github, Linkedin, Mail, Globe } from "lucide-react";
import { Button } from "./ui/button";

const contributors = [
  {
    name: "Muhammad Dhia Ulhaq",
    role: "Program PCD",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=Dhia",
    bio: "Computer Vision & Deep Learning specialist, mengimplementasikan deteksi wajah dan anonimisasi real-time",
    github: "https://github.com",
    linkedin: "https://linkedin.com",
    email: "dhia@pnl.ac.id"
  },
  {
    name: "Wildanul Hakim",
    role: "Backend Developer",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=Wildan",
    bio: "Backend engineer dengan fokus pada Flask, WebSocket, dan arsitektur server-side real-time",
    github: "https://github.com",
    linkedin: "https://linkedin.com",
    email: "wildan@pnl.ac.id"
  },
  {
    name: "M. Akmal",
    role: "Frontend Developer",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=Akmal",
    bio: "Frontend developer menggunakan Flutter Web untuk membangun antarmuka klien yang responsif",
    github: "https://github.com",
    linkedin: "https://linkedin.com",
    email: "akmal@pnl.ac.id"
  },
  {
    name: "Fauzi Syahril Harahap",
    role: "UI/UX Designer",
    avatar: "https://api.dicebear.com/7.x/avataaars/svg?seed=Fauzi",
    bio: "UI/UX designer yang merancang pengalaman pengguna yang aman dan intuitif untuk sistem pelaporan",
    github: "https://github.com",
    linkedin: "https://linkedin.com",
    email: "fauzi@pnl.ac.id"
  }
];

export function Contributors() {
  return (
    <section id="contributors" className="py-20 px-4 dark:bg-neutral-950">
      <div className="container mx-auto max-w-6xl">
        <div className="text-center mb-16">
          <h2 className="mb-4 dark:text-white">Tim Pengembang</h2>
          <p className="text-xl text-neutral-600 dark:text-neutral-400 max-w-2xl mx-auto">
            Tim dari Politeknik Negeri Lhokseumawe yang mengembangkan Sistem Pengaduan Mahasiswa Satgas PPKPT
          </p>
        </div>

        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8 mb-16">
          {contributors.map((contributor, index) => (
            <Card key={index} className="p-6 hover:shadow-lg transition-shadow dark:bg-neutral-900 dark:border-neutral-800">
              <div className="text-center mb-4">
                <img
                  src={contributor.avatar}
                  alt={contributor.name}
                  className="w-24 h-24 rounded-full mx-auto mb-4 bg-neutral-100 dark:bg-neutral-800"
                />
                <h3 className="mb-1 dark:text-white">{contributor.name}</h3>
                <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-3">
                  {contributor.role}
                </p>
                <p className="text-sm text-neutral-600 dark:text-neutral-400 mb-4">
                  {contributor.bio}
                </p>
              </div>

              <div className="flex justify-center gap-2">
                <Button
                  variant="ghost"
                  size="icon"
                  className="dark:text-neutral-400 dark:hover:text-white"
                  asChild
                >
                  <a href={contributor.github} target="_blank" rel="noopener noreferrer">
                    <Github className="w-4 h-4" />
                  </a>
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="dark:text-neutral-400 dark:hover:text-white"
                  asChild
                >
                  <a href={contributor.linkedin} target="_blank" rel="noopener noreferrer">
                    <Linkedin className="w-4 h-4" />
                  </a>
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="dark:text-neutral-400 dark:hover:text-white"
                  asChild
                >
                  <a href={`mailto:${contributor.email}`}>
                    <Mail className="w-4 h-4" />
                  </a>
                </Button>
              </div>
            </Card>
          ))}
        </div>

        <Card className="p-8 text-center dark:bg-neutral-900 dark:border-neutral-800">
          <h2 className="mb-4 dark:text-white">Politeknik Negeri Lhokseumawe</h2>
          <p className="text-neutral-600 dark:text-neutral-400 mb-6 max-w-2xl mx-auto">
            Sistem ini dikembangkan sebagai bagian dari upaya Satuan Tugas Pencegahan dan Penanganan Kekerasan Perguruan Tinggi 
            (Satgas PPKPT) di Politeknik Negeri Lhokseumawe untuk menyediakan platform pelaporan yang aman dan menjamin anonimitas pelapor.
          </p>
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Button className="gap-2 bg-neutral-900 dark:bg-white dark:text-neutral-900">
              <Mail className="w-4 h-4" />
              Hubungi Satgas PPKPT
            </Button>
            <Button variant="outline" className="gap-2 dark:border-neutral-700 dark:text-white">
              <Globe className="w-4 h-4" />
              Website PNL
            </Button>
          </div>
        </Card>
      </div>
    </section>
  );
}
