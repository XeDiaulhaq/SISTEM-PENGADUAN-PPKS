import { Card } from "./ui/card";
import { Server, Globe, Database, Shield } from "lucide-react";

const techStack = [
  {
    category: "Backend (Server)",
    icon: Server,
    technologies: [
      { name: "Python", description: "Bahasa pemrograman utama backend" },
      { name: "Flask", description: "Framework web untuk server API" },
      { name: "Flask-SocketIO", description: "Manajemen WebSocket real-time" },
      { name: "OpenCV (Python)", description: "Computer Vision & Modul DNN" },
      { name: "NumPy", description: "Manipulasi array untuk pemrosesan gambar" }
    ]
  },
  {
    category: "Frontend (Client)",
    icon: Globe,
    technologies: [
      { name: "Flutter (Web)", description: "Framework untuk antarmuka pengguna" },
      { name: "JavaScript/Dart", description: "Logika klien & akses Web API" },
      { name: "WebSocket", description: "Komunikasi real-time dengan server" }
    ]
  },
  {
    category: "Database & Infrastruktur",
    icon: Database,
    technologies: [
      { name: "PostgreSQL / MySQL", description: "Database relasional untuk manajemen metadata" },
      { name: "Nginx", description: "Reverse proxy & server WebSocket" }
    ]
  },
  {
    category: "Keamanan & Privasi",
    icon: Shield,
    technologies: [
      { name: "Server-Side Processing", description: "Data mentah tidak pernah disimpan" },
      { name: "Autentikasi Admin", description: "Akses dashboard terproteksi" },
      { name: "Anonimisasi Real-time", description: "Blur otomatis sejak perekaman" }
    ]
  }
];

export function TechnologyStack() {
  return (
    <section id="technology" className="py-20 px-4 bg-neutral-50 dark:bg-neutral-900">
      <div className="container mx-auto max-w-6xl">
        <div className="text-center mb-16">
          <h2 className="mb-4 dark:text-white">Teknologi yang Digunakan</h2>
          <p className="text-xl text-neutral-600 dark:text-neutral-400 max-w-2xl mx-auto">
            Stack teknologi modern untuk sistem perekaman real-time yang aman dan efisien
          </p>
        </div>

        <div className="grid md:grid-cols-2 gap-8">
          {techStack.map((stack, index) => (
            <Card key={index} className="p-6 dark:bg-neutral-800 dark:border-neutral-700">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-12 h-12 rounded-xl bg-neutral-900 dark:bg-neutral-100 flex items-center justify-center">
                  <stack.icon className="w-6 h-6 text-white dark:text-neutral-900" />
                </div>
                <h3 className="dark:text-white">{stack.category}</h3>
              </div>
              
              <div className="space-y-3">
                {stack.technologies.map((tech, techIndex) => (
                  <div key={techIndex} className="border-l-2 border-neutral-200 dark:border-neutral-700 pl-4">
                    <div className="text-sm dark:text-white">{tech.name}</div>
                    <div className="text-xs text-neutral-600 dark:text-neutral-400">
                      {tech.description}
                    </div>
                  </div>
                ))}
              </div>
            </Card>
          ))}
        </div>

        <Card className="mt-12 p-8 dark:bg-neutral-800 dark:border-neutral-700">
          <h3 className="mb-4 text-center dark:text-white">Kebutuhan Non-Fungsional</h3>
          <div className="grid md:grid-cols-2 gap-6">
            <div>
              <h4 className="mb-2 dark:text-white">Privasi & Keamanan Data</h4>
              <ul className="space-y-2 text-sm text-neutral-600 dark:text-neutral-400">
                <li>• Data video mentah tidak pernah disimpan di server</li>
                <li>• Akses file video dibatasi hanya untuk admin terautentikasi</li>
                <li>• Rekaman video disimpan permanen sebagai arsip aman</li>
              </ul>
            </div>
            <div>
              <h4 className="mb-2 dark:text-white">Kinerja & Kompatibilitas</h4>
              <ul className="space-y-2 text-sm text-neutral-600 dark:text-neutral-400">
                <li>• Frame rate bergantung pada kualitas jaringan klien</li>
                <li>• Kompatibel dengan browser modern (getUserMedia)</li>
                <li>• Mendukung koneksi WebSocket untuk streaming real-time</li>
              </ul>
            </div>
          </div>
        </Card>
      </div>
    </section>
  );
}