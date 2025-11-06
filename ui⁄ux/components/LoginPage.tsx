import { useState } from "react";
import { Button } from "./ui/button";
import { Card } from "./ui/card";
import { Input } from "./ui/input";
import { Label } from "./ui/label";
import { LogIn, Shield } from "lucide-react";

interface LoginPageProps {
  onLogin: () => void;
}

export function LoginPage({ onLogin }: LoginPageProps) {
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    if (username === "admin" && password === "pass") {
      onLogin();
    } else {
      setError("Username atau password salah");
      setTimeout(() => setError(""), 3000);
    }
  };

  return (
    <section className="min-h-screen flex items-center justify-center px-4 py-8 dark:bg-neutral-950">
      <div className="w-full max-w-md">
        <div className="text-center mb-6 md:mb-8">
          <div className="inline-flex items-center justify-center w-14 h-14 md:w-16 md:h-16 rounded-full bg-neutral-100 dark:bg-neutral-800 mb-3 md:mb-4">
            <Shield className="w-7 h-7 md:w-8 md:h-8 text-neutral-900 dark:text-white" />
          </div>
          <h1 className="mb-2 dark:text-white text-2xl md:text-3xl">Admin Login</h1>
          <p className="text-sm md:text-base text-neutral-600 dark:text-neutral-400">
            Masuk untuk mengakses dashboard admin
          </p>
        </div>

        <Card className="p-6 md:p-8 dark:bg-neutral-900 dark:border-neutral-800">
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="username" className="dark:text-white">
                Username
              </Label>
              <Input
                id="username"
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="Masukkan username"
                className="dark:bg-neutral-800 dark:border-neutral-700 dark:text-white"
                required
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="password" className="dark:text-white">
                Password
              </Label>
              <Input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Masukkan password"
                className="dark:bg-neutral-800 dark:border-neutral-700 dark:text-white"
                required
              />
            </div>

            {error && (
              <div className="p-3 rounded-lg bg-red-100 dark:bg-red-900/20 border border-red-200 dark:border-red-800">
                <p className="text-sm text-red-600 dark:text-red-400">{error}</p>
              </div>
            )}

            <Button
              type="submit"
              size="lg"
              className="w-full gap-2 bg-neutral-900 dark:bg-white dark:text-neutral-900"
            >
              <LogIn className="w-5 h-5" />
              Masuk
            </Button>
          </form>

          <div className="mt-6 pt-6 border-t dark:border-neutral-800">
            <p className="text-sm text-neutral-600 dark:text-neutral-400 text-center">
              Sistem Pengaduan Mahasiswa Satgas PPKPT
              <br />
              Politeknik Negeri Lhokseumawe
            </p>
          </div>
        </Card>

        <div className="mt-6 text-center">
          <Button
            variant="ghost"
            className="dark:text-neutral-400 dark:hover:text-white"
            onClick={() => window.location.hash = "#home"}
          >
            ← Kembali ke Beranda
          </Button>
        </div>
      </div>
    </section>
  );
}
