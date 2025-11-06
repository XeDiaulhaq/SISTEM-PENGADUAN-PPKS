import { useState, useRef, useEffect } from "react";
import { Button } from "./ui/button";
import { Card } from "./ui/card";
import { Switch } from "./ui/switch";
import { Label } from "./ui/label";
import { Input } from "./ui/input";
import { Textarea } from "./ui/textarea";
import { RadioGroup, RadioGroupItem } from "./ui/radio-group";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "./ui/alert-dialog";
import {
  Video,
  VideoOff,
  Circle,
  Square,
  Upload,
  MapPin,
  FileText,
  Mail,
  Phone,
  AlertTriangle,
} from "lucide-react";
import { toast } from "sonner@2.0.3";

type BlurMethod = "pixelation" | "gaussian";

export function RecorderPage() {
  const [isRecording, setIsRecording] = useState(false);
  const [blurEnabled, setBlurEnabled] = useState(false);
  const [blurMethod, setBlurMethod] =
    useState<BlurMethod>("gaussian");
  const [stream, setStream] = useState<MediaStream | null>(
    null,
  );
  const [uploadedVideo, setUploadedVideo] = useState<
    string | null
  >(null);
  const [showTermsDialog, setShowTermsDialog] = useState(true);
  const [recordedChunks, setRecordedChunks] = useState<Blob[]>([]);

  // Form fields
  const [location, setLocation] = useState("");
  const [description, setDescription] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");

  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animationFrameRef = useRef<number>();
  const fileInputRef = useRef<HTMLInputElement>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);

  useEffect(() => {
    return () => {
      // Cleanup on unmount
      if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
        mediaRecorderRef.current.stop();
      }
      if (stream) {
        stream.getTracks().forEach((track) => track.stop());
      }
      if (animationFrameRef.current) {
        cancelAnimationFrame(animationFrameRef.current);
      }
    };
  }, [stream]);

  const startRecording = async () => {
    try {
      const mediaStream =
        await navigator.mediaDevices.getUserMedia({
          video: { width: 1280, height: 720 },
          audio: true, // Enable audio
        });

      setStream(mediaStream);

      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
        videoRef.current.play();
      }

      // Setup MediaRecorder untuk merekam
      const options = { mimeType: 'video/webm;codecs=vp9' };
      let mediaRecorder: MediaRecorder;
      
      try {
        mediaRecorder = new MediaRecorder(mediaStream, options);
      } catch (e) {
        // Fallback ke default jika codec tidak didukung
        mediaRecorder = new MediaRecorder(mediaStream);
      }
      
      mediaRecorderRef.current = mediaRecorder;
      const chunks: Blob[] = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          chunks.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'video/webm' });
        const videoURL = URL.createObjectURL(blob);
        setUploadedVideo(videoURL);
        setRecordedChunks(chunks);
        
        // Show the recorded video in the preview
        if (videoRef.current) {
          videoRef.current.srcObject = null;
          videoRef.current.src = videoURL;
          videoRef.current.load();
        }
        
        toast.success("Rekaman selesai", {
          description: "Video berhasil direkam dan siap untuk dikirim"
        });
      };

      // Start recording
      mediaRecorder.start(100); // Collect data every 100ms

      setIsRecording(true);
      processVideo();
      
      toast.success("Kamera aktif", {
        description: "Perekaman video dimulai. Tekan 'Hentikan Rekam' untuk mengakhiri."
      });
    } catch (err) {
      console.error("Error accessing camera:", err);
      toast.error("Tidak dapat mengakses kamera", {
        description: "Pastikan Anda memberikan izin akses kamera dan mikrofon pada browser."
      });
    }
  };

  const stopRecording = () => {
    // Stop MediaRecorder
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      mediaRecorderRef.current.stop();
    }

    // Stop camera stream
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
      setStream(null);
    }

    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
    }

    setIsRecording(false);
  };

  const handleFileUpload = (
    event: React.ChangeEvent<HTMLInputElement>,
  ) => {
    const file = event.target.files?.[0];
    if (file && (file.type.startsWith("video/") || file.type.startsWith("image/"))) {
      const fileURL = URL.createObjectURL(file);
      setUploadedVideo(fileURL);

      // Stop any ongoing recording
      if (isRecording) {
        stopRecording();
      }

      // Load the uploaded media
      if (videoRef.current && file.type.startsWith("video/")) {
        videoRef.current.srcObject = null;
        videoRef.current.src = fileURL;
        videoRef.current.load();
      }
      
      toast.success("Berkas berhasil diunggah", {
        description: `${file.name} (${(file.size / 1024 / 1024).toFixed(2)} MB)`
      });
    } else {
      toast.error("Format berkas tidak didukung", {
        description: "Silakan pilih file video (MP4, MOV, WebM, MKV) atau gambar (PNG, JPG)"
      });
    }
  };

  const triggerFileUpload = () => {
    fileInputRef.current?.click();
  };

  const handleSubmitReport = () => {
    if (!location || !description) {
      toast.error("Data tidak lengkap", {
        description: "Lokasi dan deskripsi kejadian wajib diisi"
      });
      return;
    }

    if (!uploadedVideo) {
      toast.error("Video belum tersedia", {
        description: "Silakan rekam video atau upload berkas terlebih dahulu"
      });
      return;
    }

    // Calculate video size if available
    let videoSize = "Unknown";
    if (recordedChunks.length > 0) {
      const totalSize = recordedChunks.reduce((acc, chunk) => acc + chunk.size, 0);
      videoSize = `${(totalSize / 1024 / 1024).toFixed(2)} MB`;
    }

    // Create video record
    const newVideo = {
      id: Date.now().toString(),
      filename: `Laporan_${new Date().toLocaleDateString('id-ID').replace(/\//g, '-')}_${Date.now()}.webm`,
      uploadDate: new Date().toLocaleDateString('id-ID'),
      uploadTime: new Date().toLocaleTimeString('id-ID'),
      size: videoSize,
      status: "new" as const,
      blurType: blurEnabled ? blurMethod : undefined,
      location,
      description,
      email: email || undefined,
      phone: phone || undefined,
      videoUrl: uploadedVideo,
    };

    // Save to localStorage
    const existingVideos = localStorage.getItem("uploadedVideos");
    const videos = existingVideos ? JSON.parse(existingVideos) : [];
    videos.push(newVideo);
    localStorage.setItem("uploadedVideos", JSON.stringify(videos));

    // Trigger storage event untuk update dashboard secara realtime
    window.dispatchEvent(new Event('storage'));

    // Reset form
    setLocation("");
    setDescription("");
    setEmail("");
    setPhone("");
    setUploadedVideo(null);
    setRecordedChunks([]);
    
    // Stop recording if active
    if (isRecording) {
      stopRecording();
    }
    
    toast.success("Laporan berhasil dikirim!", {
      description: "Laporan Anda telah masuk ke dashboard admin dan akan segera diproses. Terima kasih atas laporan Anda.",
      duration: 5000
    });
    
    // Redirect to home after short delay
    setTimeout(() => {
      window.location.hash = "#home";
    }, 1500);
  };

  const processVideo = () => {
    const video = videoRef.current;
    const canvas = canvasRef.current;

    if (!video || !canvas) return;

    const ctx = canvas.getContext("2d", {
      willReadFrequently: true,
    });
    if (!ctx) return;

    const draw = () => {
      if (!video || !canvas || !ctx) return;

      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

      if (blurEnabled) {
        // Simulasi deteksi wajah - dalam implementasi nyata, gunakan library seperti face-api.js
        // Di sini kita akan blur area tengah sebagai contoh
        const faceRegions = [
          {
            x: canvas.width * 0.3,
            y: canvas.height * 0.2,
            width: canvas.width * 0.4,
            height: canvas.height * 0.5,
          },
        ];

        faceRegions.forEach((region) => {
          applyBlur(
            ctx,
            region.x,
            region.y,
            region.width,
            region.height,
          );
        });
      }

      animationFrameRef.current = requestAnimationFrame(draw);
    };

    draw();
  };

  const applyBlur = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
  ) => {
    if (blurMethod === "pixelation") {
      applyPixelation(ctx, x, y, width, height);
    } else {
      applyGaussianBlur(ctx, x, y, width, height);
    }
  };

  const applyPixelation = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
  ) => {
    const pixelSize = 20;

    for (let py = y; py < y + height; py += pixelSize) {
      for (let px = x; px < x + width; px += pixelSize) {
        const imageData = ctx.getImageData(px, py, 1, 1);
        ctx.fillStyle = `rgba(${imageData.data[0]}, ${imageData.data[1]}, ${imageData.data[2]}, ${imageData.data[3] / 255})`;
        ctx.fillRect(px, py, pixelSize, pixelSize);
      }
    }
  };

  const applyGaussianBlur = (
    ctx: CanvasRenderingContext2D,
    x: number,
    y: number,
    width: number,
    height: number,
  ) => {
    const imageData = ctx.getImageData(x, y, width, height);
    const blurred = gaussianBlurImageData(imageData, 10);
    ctx.putImageData(blurred, x, y);
  };

  const gaussianBlurImageData = (
    imageData: ImageData,
    radius: number,
  ): ImageData => {
    const pixels = imageData.data;
    const width = imageData.width;
    const height = imageData.height;
    const output = new ImageData(width, height);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        let r = 0,
          g = 0,
          b = 0,
          a = 0,
          count = 0;

        for (let dy = -radius; dy <= radius; dy++) {
          for (let dx = -radius; dx <= radius; dx++) {
            const nx = x + dx;
            const ny = y + dy;

            if (
              nx >= 0 &&
              nx < width &&
              ny >= 0 &&
              ny < height
            ) {
              const idx = (ny * width + nx) * 4;
              r += pixels[idx];
              g += pixels[idx + 1];
              b += pixels[idx + 2];
              a += pixels[idx + 3];
              count++;
            }
          }
        }

        const idx = (y * width + x) * 4;
        output.data[idx] = r / count;
        output.data[idx + 1] = g / count;
        output.data[idx + 2] = b / count;
        output.data[idx + 3] = a / count;
      }
    }

    return output;
  };

  useEffect(() => {
    if (isRecording) {
      processVideo();
    }
  }, [blurEnabled, blurMethod]);

  return (
    <section className="pt-24 md:pt-32 pb-12 md:pb-20 px-4 min-h-screen dark:bg-neutral-950">
      {/* Terms and Conditions Dialog */}
      <AlertDialog open={showTermsDialog} onOpenChange={setShowTermsDialog}>
        <AlertDialogContent className="max-w-2xl dark:bg-neutral-900 dark:border-neutral-800">
          <AlertDialogHeader>
            <div className="flex items-center gap-3 mb-2">
              <div className="p-3 rounded-lg bg-yellow-100 dark:bg-yellow-900/20">
                <AlertTriangle className="w-6 h-6 text-yellow-600 dark:text-yellow-400" />
              </div>
              <AlertDialogTitle className="dark:text-white">
                Persetujuan Pelapor
              </AlertDialogTitle>
            </div>
            <AlertDialogDescription className="text-left space-y-4 text-sm text-neutral-600 dark:text-neutral-400">
              <p>
                Dengan mengakses sistem perekaman ini, saya menyatakan bahwa:
              </p>
              <ul className="space-y-3 list-disc list-inside ml-2">
                <li>
                  Saya telah membaca dan menyetujui semua persyaratan dalam sistem pelaporan ini.
                </li>
                <li>
                  Laporan yang saya buat adalah <strong className="text-neutral-900 dark:text-white">sebenar-benarnya</strong> berdasarkan fakta yang saya alami atau saksikan.
                </li>
                <li>
                  Saya <strong className="text-neutral-900 dark:text-white">tidak akan membuat laporan palsu</strong> (hoax) atau memberikan keterangan yang menyesatkan.
                </li>
                <li>
                  Saya memahami bahwa laporan palsu dapat dikenakan sanksi sesuai peraturan yang berlaku.
                </li>
                <li>
                  Saya bertanggung jawab penuh atas kebenaran informasi yang saya sampaikan.
                </li>
                <li>
                  Data dan video yang saya unggah akan diproses oleh Satgas PPKPT Politeknik Negeri Lhokseumawe untuk keperluan investigasi.
                </li>
              </ul>
              <div className="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800 mt-4">
                <p className="text-sm text-blue-900 dark:text-blue-300">
                  <strong>Catatan Penting:</strong> Sistem ini dilindungi dengan anonimisasi wajah untuk melindungi privasi Anda. Namun, kami tetap mengharapkan laporan yang jujur dan bertanggung jawab.
                </p>
              </div>
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogAction
              className="bg-neutral-900 dark:bg-white dark:text-neutral-900"
              onClick={() => setShowTermsDialog(false)}
            >
              Saya Setuju dan Bertanggung Jawab
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>

      <div className="container mx-auto max-w-7xl">
        <div className="mb-6 md:mb-8">
          <h1 className="mb-3 md:mb-4 dark:text-white text-2xl md:text-3xl lg:text-4xl">
            Sistem Perekaman Laporan
          </h1>
          <p className="text-base md:text-lg lg:text-xl text-neutral-600 dark:text-neutral-400">
            Rekam kronologi kejadian dengan jaminan anonimitas
            visual sejak proses perekaman dimulai
          </p>
        </div>

        <div className="grid lg:grid-cols-3 gap-4 md:gap-6">
          {/* Video Preview */}
          <div className="lg:col-span-2">
            <Card className="p-6 dark:bg-neutral-900 dark:border-neutral-800">
              <div className="aspect-video bg-neutral-100 dark:bg-neutral-800 rounded-lg overflow-hidden relative">
                {!isRecording && !uploadedVideo ? (
                  <div className="w-full h-full flex items-center justify-center">
                    <div className="text-center px-4">
                      <VideoOff className="w-16 h-16 mx-auto mb-4 text-neutral-400" />
                      <p className="text-neutral-600 dark:text-neutral-400">
                        Klik "Mulai Rekam" untuk merekam video atau
                      </p>
                      <p className="text-neutral-600 dark:text-neutral-400">
                        "Upload Berkas" untuk mengunggah file video/gambar
                      </p>
                      <p className="text-xs text-neutral-500 dark:text-neutral-500 mt-2">
                        Format didukung: MP4, MOV, MKV, WebM, AVI, PNG, JPG
                      </p>
                    </div>
                  </div>
                ) : (
                  <>
                    <video
                      ref={videoRef}
                      className="absolute inset-0 w-full h-full object-cover"
                      style={{
                        display: blurEnabled ? "none" : "block",
                      }}
                      autoPlay
                      muted
                    />
                    <canvas
                      ref={canvasRef}
                      className="absolute inset-0 w-full h-full object-cover"
                      style={{
                        display: blurEnabled ? "block" : "none",
                      }}
                    />
                    {isRecording && (
                      <div className="absolute top-4 right-4 px-3 py-2 bg-red-500 text-white rounded-lg shadow-lg flex items-center gap-2">
                        <Circle className="w-3 h-3 fill-white animate-pulse" />
                        <span className="text-sm">
                          RECORDING
                        </span>
                      </div>
                    )}
                    {blurEnabled && (
                      <div className="absolute bottom-4 left-4 px-3 py-2 bg-neutral-900/80 text-white rounded-lg shadow-lg backdrop-blur-sm">
                        <span className="text-sm">
                          Blur:{" "}
                          {blurMethod === "gaussian"
                            ? "Gaussian"
                            : "Pixelation"}
                        </span>
                      </div>
                    )}
                  </>
                )}
              </div>

              <div className="mt-4 md:mt-6 flex flex-col sm:flex-row gap-3 md:gap-4 justify-center">
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="video/*,image/*,.mp4,.mov,.avi,.mkv,.webm,.flv,.wmv,.m4v,.3gp"
                  onChange={handleFileUpload}
                  className="hidden"
                />
                <Button
                  size="lg"
                  variant="outline"
                  onClick={triggerFileUpload}
                  className="gap-2 dark:border-neutral-700 dark:text-white dark:hover:bg-neutral-800 w-full sm:w-auto"
                  disabled={isRecording}
                >
                  <Upload className="w-5 h-5" />
                  Upload Berkas
                </Button>
                {!isRecording ? (
                  <Button
                    size="lg"
                    onClick={startRecording}
                    className="gap-2 bg-neutral-900 dark:bg-white dark:text-neutral-900 w-full sm:w-auto"
                  >
                    <Video className="w-5 h-5" />
                    Mulai Rekam
                  </Button>
                ) : (
                  <Button
                    size="lg"
                    onClick={stopRecording}
                    variant="destructive"
                    className="gap-2 w-full sm:w-auto"
                  >
                    <Square className="w-5 h-5" />
                    Stop Rekam
                  </Button>
                )}
              </div>
            </Card>
          </div>

          {/* Controls */}
          <div className="space-y-4 md:space-y-6">
            <Card className="p-4 md:p-6 dark:bg-neutral-900 dark:border-neutral-800">
              <h3 className="mb-3 md:mb-4 dark:text-white text-lg md:text-xl">
                Pengaturan Blur
              </h3>

              <div className="space-y-6">
                {/* Blur Toggle */}
                <div className="flex items-center justify-between">
                  <Label
                    htmlFor="blur-toggle"
                    className="dark:text-white"
                  >
                    Aktifkan Blur
                  </Label>
                  <Switch
                    id="blur-toggle"
                    checked={blurEnabled}
                    onCheckedChange={setBlurEnabled}
                  />
                </div>

                {/* Blur Method Selection */}
                {blurEnabled && (
                  <div className="space-y-3 pt-4 border-t dark:border-neutral-800">
                    <Label className="dark:text-white">
                      Metode Blur
                    </Label>
                    <RadioGroup
                      value={blurMethod}
                      onValueChange={(value) =>
                        setBlurMethod(value as BlurMethod)
                      }
                    >
                      <div className="flex items-center space-x-2">
                        <RadioGroupItem
                          value="gaussian"
                          id="gaussian"
                        />
                        <Label
                          htmlFor="gaussian"
                          className="cursor-pointer dark:text-neutral-300"
                        >
                          Gaussian Blur
                        </Label>
                      </div>
                      <div className="flex items-center space-x-2">
                        <RadioGroupItem
                          value="pixelation"
                          id="pixelation"
                        />
                        <Label
                          htmlFor="pixelation"
                          className="cursor-pointer dark:text-neutral-300"
                        >
                          Pixelation
                        </Label>
                      </div>
                    </RadioGroup>
                  </div>
                )}
              </div>
            </Card>
          </div>
        </div>

        {/* Report Details Form */}
        <Card className="p-4 md:p-6 lg:p-8 mt-6 md:mt-8 dark:bg-neutral-900 dark:border-neutral-800">
          <div className="mb-4 md:mb-6">
            <h2 className="mb-2 dark:text-white text-xl md:text-2xl">Detail Laporan</h2>
            <p className="text-sm md:text-base text-neutral-600 dark:text-neutral-400">
              Lengkapi informasi berikut untuk membantu proses investigasi
            </p>
          </div>

          <div className="space-y-6">
            {/* Location */}
            <div className="space-y-2">
              <Label htmlFor="location" className="flex items-center gap-2 dark:text-white">
                <MapPin className="w-4 h-4" />
                Lokasi Kejadian <span className="text-red-500">*</span>
              </Label>
              <Input
                id="location"
                placeholder="Contoh: Gedung A Lantai 2, Ruang Kelas 201"
                value={location}
                onChange={(e) => setLocation(e.target.value)}
                className="dark:bg-neutral-800 dark:border-neutral-700 dark:text-white"
                required
              />
              <p className="text-sm text-neutral-500 dark:text-neutral-500">
                Sebutkan lokasi kejadian secara spesifik
              </p>
            </div>

            {/* Description */}
            <div className="space-y-2">
              <Label htmlFor="description" className="flex items-center gap-2 dark:text-white">
                <FileText className="w-4 h-4" />
                Deskripsi Kejadian <span className="text-red-500">*</span>
              </Label>
              <Textarea
                id="description"
                placeholder="Jelaskan kronologi kejadian secara detail..."
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="min-h-[150px] dark:bg-neutral-800 dark:border-neutral-700 dark:text-white"
                required
              />
              <p className="text-sm text-neutral-500 dark:text-neutral-500">
                Jelaskan apa yang terjadi, kapan, dan siapa yang terlibat
              </p>
            </div>

            {/* Optional Contact Information */}
            <div className="pt-4 border-t dark:border-neutral-800">
              <h3 className="mb-3 md:mb-4 dark:text-white text-lg md:text-xl">
                Informasi Kontak (Opsional)
              </h3>
              <p className="text-xs md:text-sm text-neutral-600 dark:text-neutral-400 mb-4">
                Informasi kontak bersifat opsional dan akan membantu tim investigasi untuk follow-up jika diperlukan
              </p>
              
              <div className="grid md:grid-cols-2 gap-4 md:gap-6">
                {/* Email */}
                <div className="space-y-2">
                  <Label htmlFor="email" className="flex items-center gap-2 dark:text-white">
                    <Mail className="w-4 h-4" />
                    Email
                  </Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="email@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="dark:bg-neutral-800 dark:border-neutral-700 dark:text-white"
                  />
                </div>

                {/* Phone */}
                <div className="space-y-2">
                  <Label htmlFor="phone" className="flex items-center gap-2 dark:text-white">
                    <Phone className="w-4 h-4" />
                    No. Telepon
                  </Label>
                  <Input
                    id="phone"
                    type="tel"
                    placeholder="08xxxxxxxxxx"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="dark:bg-neutral-800 dark:border-neutral-700 dark:text-white"
                  />
                </div>
              </div>
            </div>

            {/* Submit Button */}
            <div className="pt-4 md:pt-6 border-t dark:border-neutral-800">
              <Button
                size="lg"
                className="w-full gap-2 bg-neutral-900 dark:bg-white dark:text-neutral-900"
                disabled={!location || !description}
                onClick={handleSubmitReport}
              >
                <Upload className="w-5 h-5" />
                Kirim Laporan
              </Button>
              {(!location || !description) && (
                <p className="text-xs md:text-sm text-red-500 dark:text-red-400 mt-2 text-center">
                  Lokasi dan deskripsi kejadian wajib diisi
                </p>
              )}
            </div>
          </div>
        </Card>
      </div>
    </section>
  );
}