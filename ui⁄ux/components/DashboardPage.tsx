import { Card } from "./ui/card";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import { 
  Video, 
  Download, 
  Calendar, 
  Clock, 
  Eye,
  FileVideo,
  TrendingUp,
  CheckCircle2,
  Loader2,
  Circle as CircleIcon,
  MapPin,
  FileText,
  Mail,
  Phone
} from "lucide-react";
import { useState, useEffect } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "./ui/dialog";
import { toast } from "sonner@2.0.3";

interface UploadedVideo {
  id: string;
  filename: string;
  uploadDate: string;
  uploadTime: string;
  size: string;
  status: "new" | "processing" | "completed";
  blurType?: string;
  location?: string;
  description?: string;
  email?: string;
  phone?: string;
  videoUrl?: string;
}

export function DashboardPage() {
  const [uploadedVideos, setUploadedVideos] = useState<UploadedVideo[]>([]);
  const [filter, setFilter] = useState<"all" | "today" | "processing" | "completed">("all");
  const [selectedVideo, setSelectedVideo] = useState<UploadedVideo | null>(null);
  const [showVideoDialog, setShowVideoDialog] = useState(false);

  const loadVideos = () => {
    const savedVideos = localStorage.getItem("uploadedVideos");
    if (savedVideos) {
      const videos = JSON.parse(savedVideos);
      // Convert old status to new format
      const updatedVideos = videos.map((v: any) => ({
        ...v,
        status: v.status === "pending" ? "new" : v.status === "processed" ? "completed" : v.status
      }));
      setUploadedVideos(updatedVideos);
    } else {
      // Add sample data if no data exists
      const sampleData: UploadedVideo[] = [
        {
          id: "1",
          filename: "Laporan_Pelecehan_Verbal_Kampus.webm",
          uploadDate: new Date().toLocaleDateString('id-ID'),
          uploadTime: "09:15:30",
          size: "12.5 MB",
          status: "new",
          blurType: "gaussian",
          location: "Gedung Teknik Elektro, Lantai 2",
          description: "Terjadi pelecehan verbal oleh mahasiswa senior kepada mahasiswa junior di area koridor. Pelaku menggunakan kata-kata kasar dan merendahkan.",
          email: "mahasiswa@gmail.com",
          phone: "081234567890"
        },
        {
          id: "2",
          filename: "Laporan_Intimidasi_Ruang_Kelas.webm",
          uploadDate: new Date().toLocaleDateString('id-ID'),
          uploadTime: "10:45:12",
          size: "8.3 MB",
          status: "processing",
          blurType: "pixelation",
          location: "Ruang Kelas A-301",
          description: "Mahasiswa mengalami intimidasi dan ancaman dari sekelompok mahasiswa lain di dalam kelas.",
          email: "reporter@student.pnl.ac.id"
        },
        {
          id: "3",
          filename: "Laporan_Kekerasan_Area_Parkir.webm",
          uploadDate: new Date(Date.now() - 86400000).toLocaleDateString('id-ID'), // Yesterday
          uploadTime: "14:20:45",
          size: "15.7 MB",
          status: "completed",
          blurType: "gaussian",
          location: "Area Parkir Motor Gedung Utama",
          description: "Terjadi perkelahian dan kekerasan fisik antara dua kelompok mahasiswa. Beberapa orang mengalami luka ringan.",
          phone: "082233445566"
        }
      ];
      setUploadedVideos(sampleData);
      localStorage.setItem("uploadedVideos", JSON.stringify(sampleData));
    }
  };

  useEffect(() => {
    loadVideos();
    
    // Auto-refresh setiap 3 detik untuk mendeteksi laporan baru
    const interval = setInterval(() => {
      loadVideos();
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  const updateVideoStatus = (id: string, newStatus: "new" | "processing" | "completed") => {
    const updatedVideos = uploadedVideos.map(video => 
      video.id === id ? { ...video, status: newStatus } : video
    );
    setUploadedVideos(updatedVideos);
    localStorage.setItem("uploadedVideos", JSON.stringify(updatedVideos));
    
    // Show toast notification
    const statusText = newStatus === "processing" ? "Sedang Diproses" : "Selesai";
    toast.success(`Status laporan diubah menjadi "${statusText}"`, {
      description: `Laporan telah berhasil diperbarui.`
    });
  };

  const handleViewVideo = (video: UploadedVideo) => {
    setSelectedVideo(video);
    setShowVideoDialog(true);
  };

  const handleDownloadVideo = (video: UploadedVideo) => {
    // In real implementation, this would download the actual video
    // For now, we'll create a mock download
    if (video.videoUrl) {
      const link = document.createElement('a');
      link.href = video.videoUrl;
      link.download = video.filename;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      toast.success("Video berhasil diunduh", {
        description: video.filename
      });
    } else {
      toast.info("Download video", {
        description: `Video ${video.filename} akan diunduh dari server. Fitur ini akan aktif pada implementasi produksi.`
      });
    }
  };

  const getFilteredVideos = () => {
    const today = new Date().toLocaleDateString('id-ID');
    switch (filter) {
      case "today":
        return uploadedVideos.filter(v => v.uploadDate === today);
      case "processing":
        return uploadedVideos.filter(v => v.status === "processing");
      case "completed":
        return uploadedVideos.filter(v => v.status === "completed");
      default:
        return uploadedVideos;
    }
  };

  const filteredVideos = getFilteredVideos();

  const stats = [
    {
      title: "Total Laporan",
      value: uploadedVideos.length.toString(),
      icon: FileVideo,
      color: "bg-blue-500",
      filterKey: "all" as const
    },
    {
      title: "Laporan Hari Ini",
      value: uploadedVideos.filter(v => v.uploadDate === new Date().toLocaleDateString('id-ID')).length.toString(),
      icon: TrendingUp,
      color: "bg-green-500",
      filterKey: "today" as const
    },
    {
      title: "Sedang Diproses",
      value: uploadedVideos.filter(v => v.status === "processing").length.toString(),
      icon: Clock,
      color: "bg-yellow-500",
      filterKey: "processing" as const
    },
    {
      title: "Selesai Diproses",
      value: uploadedVideos.filter(v => v.status === "completed").length.toString(),
      icon: Eye,
      color: "bg-purple-500",
      filterKey: "completed" as const
    }
  ];

  return (
    <section className="pt-32 pb-20 px-4 min-h-screen dark:bg-neutral-950">
      <div className="container mx-auto max-w-7xl">
        <div className="mb-8">
          <h1 className="mb-2 dark:text-white">Dashboard</h1>
          <p className="text-xl text-neutral-600 dark:text-neutral-400">
            Monitor dan kelola laporan yang masuk dari mahasiswa
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          {stats.map((stat, index) => (
            <Card 
              key={index} 
              className={`p-6 dark:bg-neutral-900 dark:border-neutral-800 cursor-pointer transition-all hover:shadow-lg ${
                filter === stat.filterKey ? 'ring-2 ring-blue-500 dark:ring-blue-400' : ''
              }`}
              onClick={() => setFilter(stat.filterKey)}
            >
              <div className="flex items-start justify-between">
                <div>
                  <h3 className="text-sm mb-1 dark:text-white">
                    {stat.title}
                  </h3>
                  <p className="text-3xl dark:text-white">{stat.value}</p>
                </div>
                <div className={`p-3 rounded-lg ${stat.color}`}>
                  <stat.icon className="w-6 h-6 text-white" />
                </div>
              </div>
            </Card>
          ))}
        </div>

        {/* Video List */}
        <Card className="p-6 dark:bg-neutral-900 dark:border-neutral-800">
          <div className="mb-6 flex items-center justify-between">
            <div>
              <h2 className="dark:text-white">
                Daftar Laporan Video
                {filter !== "all" && (
                  <span className="ml-3 text-blue-500 dark:text-blue-400">
                    ({
                      filter === "today" ? "Hari Ini" :
                      filter === "processing" ? "Sedang Diproses" :
                      "Selesai Diproses"
                    })
                  </span>
                )}
              </h2>
            </div>
            {filter !== "all" && (
              <Button 
                variant="outline" 
                size="sm"
                onClick={() => setFilter("all")}
                className="dark:border-neutral-600 dark:text-neutral-300"
              >
                Reset Filter
              </Button>
            )}
          </div>

          {filteredVideos.length === 0 ? (
            <div className="text-center py-12">
              <Video className="w-16 h-16 mx-auto mb-4 text-neutral-400" />
              <p className="text-neutral-600 dark:text-neutral-400">
                {filter === "all" 
                  ? "Belum ada laporan video yang diunggah"
                  : "Tidak ada laporan dengan filter ini"}
              </p>
              <p className="text-sm text-neutral-500 dark:text-neutral-500 mt-2">
                {filter === "all"
                  ? "Video yang diunggah melalui halaman Recorder akan muncul di sini"
                  : "Coba pilih filter lain atau reset filter"}
              </p>
            </div>
          ) : (
            <div className="space-y-4">
              {filteredVideos.map((video) => (
                <Card
                  key={video.id}
                  className="p-4 md:p-5 dark:bg-neutral-800 dark:border-neutral-700 hover:shadow-lg transition-all duration-200"
                >
                  <div className="flex flex-col md:flex-row md:items-center gap-4">
                    {/* Video Info Section */}
                    <div className="flex items-start md:items-center gap-3 md:gap-4 flex-1 min-w-0">
                      <div className="p-2.5 md:p-3 rounded-lg bg-neutral-100 dark:bg-neutral-700 flex-shrink-0">
                        <Video className="w-5 h-5 md:w-6 md:h-6 text-neutral-600 dark:text-neutral-300" />
                      </div>
                      
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-2 mb-1.5">
                          <h3 className="dark:text-white truncate flex-1 text-sm md:text-base">{video.filename}</h3>
                          {/* Status Badge - Mobile */}
                          <div className="md:hidden flex-shrink-0">
                            {video.status === "completed" ? (
                              <Badge className="bg-green-500 text-white flex items-center gap-1 px-2 py-0.5 text-xs">
                                <CheckCircle2 className="w-3 h-3" />
                                Selesai
                              </Badge>
                            ) : video.status === "processing" ? (
                              <Badge className="bg-yellow-500 text-white flex items-center gap-1 px-2 py-0.5 text-xs">
                                <Loader2 className="w-3 h-3 animate-spin" />
                                Diproses
                              </Badge>
                            ) : (
                              <Badge className="bg-blue-500 text-white flex items-center gap-1 px-2 py-0.5 text-xs">
                                <CircleIcon className="w-3 h-3 fill-current" />
                                Baru
                              </Badge>
                            )}
                          </div>
                        </div>
                        <div className="flex flex-wrap items-center gap-2 md:gap-3 text-xs md:text-sm text-neutral-600 dark:text-neutral-400">
                          <span className="flex items-center gap-1">
                            <Calendar className="w-3.5 h-3.5 md:w-4 md:h-4" />
                            {video.uploadDate}
                          </span>
                          <span className="flex items-center gap-1">
                            <Clock className="w-3.5 h-3.5 md:w-4 md:h-4" />
                            {video.uploadTime}
                          </span>
                          <span className="hidden sm:inline">{video.size}</span>
                          {video.blurType && (
                            <Badge variant="outline" className="dark:border-neutral-600 text-xs">
                              {video.blurType === "gaussian" ? "Gaussian" : "Pixelation"}
                            </Badge>
                          )}
                        </div>
                      </div>
                    </div>

                    {/* Actions Section */}
                    <div className="flex items-center gap-2 md:gap-2.5 flex-wrap md:flex-nowrap">
                      {/* Status Badge - Desktop */}
                      <div className="hidden md:block flex-shrink-0">
                        {video.status === "completed" ? (
                          <Badge className="bg-green-500 hover:bg-green-600 text-white flex items-center gap-1.5 px-3 py-1.5 transition-all">
                            <CheckCircle2 className="w-4 h-4" />
                            Selesai
                          </Badge>
                        ) : video.status === "processing" ? (
                          <Badge className="bg-yellow-500 hover:bg-yellow-600 text-white flex items-center gap-1.5 px-3 py-1.5 transition-all">
                            <Loader2 className="w-4 h-4 animate-spin" />
                            Diproses
                          </Badge>
                        ) : (
                          <Badge className="bg-blue-500 hover:bg-blue-600 text-white flex items-center gap-1.5 px-3 py-1.5 transition-all">
                            <CircleIcon className="w-4 h-4 fill-current" />
                            Baru
                          </Badge>
                        )}
                      </div>

                      {/* Action Buttons */}
                      <div className="flex items-center gap-2 flex-1 md:flex-initial">
                        <Button
                          variant="outline"
                          size="sm"
                          className="gap-1.5 dark:border-neutral-600 dark:text-neutral-300 text-xs md:text-sm flex-1 md:flex-initial"
                          onClick={() => handleViewVideo(video)}
                        >
                          <Eye className="w-3.5 h-3.5 md:w-4 md:h-4" />
                          <span className="hidden sm:inline">Lihat</span>
                        </Button>
                        
                        <Button
                          variant="outline"
                          size="sm"
                          className="gap-1.5 dark:border-neutral-600 dark:text-neutral-300 text-xs md:text-sm flex-1 md:flex-initial"
                          onClick={() => handleDownloadVideo(video)}
                        >
                          <Download className="w-3.5 h-3.5 md:w-4 md:h-4" />
                          <span className="hidden sm:inline">Unduh</span>
                        </Button>

                        {video.status === "new" && (
                          <Button
                            size="sm"
                            className="gap-1.5 bg-blue-600 hover:bg-blue-700 text-white text-xs md:text-sm flex-1 md:flex-initial"
                            onClick={() => updateVideoStatus(video.id, "processing")}
                          >
                            <Clock className="w-3.5 h-3.5 md:w-4 md:h-4" />
                            Proses
                          </Button>
                        )}

                        {video.status === "processing" && (
                          <Button
                            size="sm"
                            className="gap-1.5 bg-green-600 hover:bg-green-700 text-white text-xs md:text-sm flex-1 md:flex-initial"
                            onClick={() => updateVideoStatus(video.id, "completed")}
                          >
                            <CheckCircle2 className="w-3.5 h-3.5 md:w-4 md:h-4" />
                            Selesai
                          </Button>
                        )}
                      </div>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </Card>

      </div>

      {/* Video Detail Dialog */}
      <Dialog open={showVideoDialog} onOpenChange={setShowVideoDialog}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto dark:bg-neutral-900 dark:border-neutral-800">
          <DialogHeader>
            <DialogTitle className="dark:text-white text-lg md:text-xl">
              Detail Laporan
            </DialogTitle>
            <DialogDescription className="text-sm text-neutral-600 dark:text-neutral-400">
              Informasi lengkap mengenai laporan yang diterima
            </DialogDescription>
          </DialogHeader>

          {selectedVideo && (
            <div className="space-y-6 mt-4">
              {/* Status Badge */}
              <div className="flex items-center gap-3">
                <span className="text-sm text-neutral-600 dark:text-neutral-400">Status:</span>
                {selectedVideo.status === "completed" ? (
                  <Badge className="bg-green-500 text-white flex items-center gap-1.5 px-3 py-1.5">
                    <CheckCircle2 className="w-4 h-4" />
                    Selesai
                  </Badge>
                ) : selectedVideo.status === "processing" ? (
                  <Badge className="bg-yellow-500 text-white flex items-center gap-1.5 px-3 py-1.5">
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Sedang Diproses
                  </Badge>
                ) : (
                  <Badge className="bg-blue-500 text-white flex items-center gap-1.5 px-3 py-1.5">
                    <CircleIcon className="w-4 h-4 fill-current" />
                    Baru
                  </Badge>
                )}
              </div>

              {/* Video Preview */}
              <Card className="p-4 dark:bg-neutral-800 dark:border-neutral-700">
                <div className="aspect-video bg-neutral-100 dark:bg-neutral-950 rounded-lg flex items-center justify-center">
                  {selectedVideo.videoUrl ? (
                    <video
                      src={selectedVideo.videoUrl}
                      controls
                      className="w-full h-full rounded-lg"
                    />
                  ) : (
                    <div className="text-center">
                      <Video className="w-16 h-16 mx-auto mb-4 text-neutral-400" />
                      <p className="text-neutral-500 dark:text-neutral-400">
                        Preview video tidak tersedia
                      </p>
                      <p className="text-xs text-neutral-400 dark:text-neutral-500 mt-2">
                        Video dapat diunduh untuk dilihat
                      </p>
                    </div>
                  )}
                </div>
                <div className="mt-4 space-y-2">
                  <div className="flex items-center gap-2 text-sm">
                    <FileVideo className="w-4 h-4 text-neutral-500" />
                    <span className="text-neutral-600 dark:text-neutral-400">{selectedVideo.filename}</span>
                  </div>
                  <div className="flex items-center gap-4 text-sm text-neutral-600 dark:text-neutral-400">
                    <span className="flex items-center gap-1">
                      <Calendar className="w-4 h-4" />
                      {selectedVideo.uploadDate}
                    </span>
                    <span className="flex items-center gap-1">
                      <Clock className="w-4 h-4" />
                      {selectedVideo.uploadTime}
                    </span>
                    <span>{selectedVideo.size}</span>
                  </div>
                  {selectedVideo.blurType && (
                    <div className="flex items-center gap-2">
                      <Badge variant="outline" className="dark:border-neutral-600">
                        Blur: {selectedVideo.blurType === "gaussian" ? "Gaussian" : "Pixelation"}
                      </Badge>
                    </div>
                  )}
                </div>
              </Card>

              {/* Location */}
              {selectedVideo.location && (
                <Card className="p-4 dark:bg-neutral-800 dark:border-neutral-700">
                  <div className="flex items-start gap-3">
                    <div className="p-2 rounded-lg bg-red-100 dark:bg-red-900/20 flex-shrink-0">
                      <MapPin className="w-5 h-5 text-red-600 dark:text-red-400" />
                    </div>
                    <div className="flex-1">
                      <h3 className="text-sm mb-1 dark:text-white">Lokasi Kejadian</h3>
                      <p className="text-neutral-600 dark:text-neutral-400">{selectedVideo.location}</p>
                    </div>
                  </div>
                </Card>
              )}

              {/* Description */}
              {selectedVideo.description && (
                <Card className="p-4 dark:bg-neutral-800 dark:border-neutral-700">
                  <div className="flex items-start gap-3">
                    <div className="p-2 rounded-lg bg-blue-100 dark:bg-blue-900/20 flex-shrink-0">
                      <FileText className="w-5 h-5 text-blue-600 dark:text-blue-400" />
                    </div>
                    <div className="flex-1">
                      <h3 className="text-sm mb-1 dark:text-white">Deskripsi Kejadian</h3>
                      <p className="text-neutral-600 dark:text-neutral-400 whitespace-pre-wrap">{selectedVideo.description}</p>
                    </div>
                  </div>
                </Card>
              )}

              {/* Contact Info */}
              {(selectedVideo.email || selectedVideo.phone) && (
                <Card className="p-4 dark:bg-neutral-800 dark:border-neutral-700">
                  <h3 className="text-sm mb-3 dark:text-white">Informasi Kontak Pelapor (Opsional)</h3>
                  <div className="space-y-3">
                    {selectedVideo.email && (
                      <div className="flex items-center gap-3">
                        <div className="p-2 rounded-lg bg-green-100 dark:bg-green-900/20 flex-shrink-0">
                          <Mail className="w-4 h-4 text-green-600 dark:text-green-400" />
                        </div>
                        <div>
                          <p className="text-xs text-neutral-500 dark:text-neutral-400">Email</p>
                          <p className="text-sm text-neutral-600 dark:text-neutral-300">{selectedVideo.email}</p>
                        </div>
                      </div>
                    )}
                    {selectedVideo.phone && (
                      <div className="flex items-center gap-3">
                        <div className="p-2 rounded-lg bg-purple-100 dark:bg-purple-900/20 flex-shrink-0">
                          <Phone className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                        </div>
                        <div>
                          <p className="text-xs text-neutral-500 dark:text-neutral-400">Telepon</p>
                          <p className="text-sm text-neutral-600 dark:text-neutral-300">{selectedVideo.phone}</p>
                        </div>
                      </div>
                    )}
                  </div>
                </Card>
              )}

              {/* Action Buttons */}
              <div className="flex flex-col sm:flex-row gap-3 pt-4 border-t dark:border-neutral-700">
                {selectedVideo.status === "new" && (
                  <Button
                    className="gap-2 bg-blue-600 hover:bg-blue-700 text-white flex-1"
                    onClick={() => {
                      updateVideoStatus(selectedVideo.id, "processing");
                      setShowVideoDialog(false);
                    }}
                  >
                    <Clock className="w-4 h-4" />
                    Mulai Proses Laporan
                  </Button>
                )}
                {selectedVideo.status === "processing" && (
                  <Button
                    className="gap-2 bg-green-600 hover:bg-green-700 text-white flex-1"
                    onClick={() => {
                      updateVideoStatus(selectedVideo.id, "completed");
                      setShowVideoDialog(false);
                    }}
                  >
                    <CheckCircle2 className="w-4 h-4" />
                    Selesaikan Laporan
                  </Button>
                )}
                <Button
                  variant="outline"
                  className="gap-2 dark:border-neutral-600 dark:text-neutral-300 flex-1"
                  onClick={() => handleDownloadVideo(selectedVideo)}
                >
                  <Download className="w-4 h-4" />
                  Unduh Video
                </Button>
              </div>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </section>
  );
}
