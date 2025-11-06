import { Monitor, Scan, Video, CheckCircle } from "lucide-react";

const steps = [
  {
    icon: Monitor,
    title: "Akses Kamera Klien",
    description: "Pelapor mengakses sistem dan memberikan izin kamera melalui browser.",
    step: 1
  },
  {
    icon: Scan,
    title: "Stream ke Server",
    description: "Video stream dikirim ke server Flask melalui WebSocket secara real-time.",
    step: 2
  },
  {
    icon: Video,
    title: "Deteksi & Blur",
    description: "Server mendeteksi wajah dengan OpenCV DNN dan menerapkan blur otomatis.",
    step: 3
  },
  {
    icon: CheckCircle,
    title: "Simpan & Preview",
    description: "Video ter-anonimisasi disimpan di server dan dikirim kembali sebagai preview.",
    step: 4
  }
];

export function HowItWorks() {
  return (
    <section id="how-it-works" className="py-20 px-4 dark:bg-neutral-950">
      <div className="container mx-auto">
        <div className="text-center mb-16">
          <h2 className="mb-4 dark:text-white">Arsitektur Client-Server</h2>
          <p className="text-xl text-neutral-600 dark:text-neutral-400 max-w-2xl mx-auto">
            Sistem mengadopsi arsitektur real-time untuk pemrosesan dan penyimpanan stream video di sisi server.
          </p>
        </div>
        
        <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-8">
          {steps.map((step, index) => (
            <div key={index} className="relative">
              {index < steps.length - 1 && (
                <div className="hidden lg:block absolute top-16 left-1/2 w-full h-0.5 bg-neutral-200 dark:bg-neutral-800" />
              )}
              
              <div className="relative bg-white dark:bg-neutral-900 rounded-2xl p-6 shadow-sm hover:shadow-md transition-shadow dark:border dark:border-neutral-800">
                <div className="relative w-16 h-16 rounded-xl bg-neutral-900 dark:bg-neutral-100 flex items-center justify-center mb-4 mx-auto">
                  <step.icon className="w-8 h-8 text-white dark:text-neutral-900" />
                  <div className="absolute -top-2 -right-2 w-8 h-8 rounded-full bg-white dark:bg-neutral-900 shadow-md flex items-center justify-center dark:border dark:border-neutral-700">
                    <span className="text-sm dark:text-white">{step.step}</span>
                  </div>
                </div>
                
                <h3 className="mb-2 text-center dark:text-white">{step.title}</h3>
                <p className="text-neutral-600 dark:text-neutral-400 text-center">{step.description}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}