import { Button } from "./ui/button";
import { Badge } from "./ui/badge";
import { Moon, Sun, LogOut } from "lucide-react";
import { useTheme } from "./ThemeProvider";
import logoImage from "figma:asset/880b02f74a30c5a3f5e447a6b548a666f5dc9e48.png";

interface HeaderProps {
  show?: boolean;
  isAdmin?: boolean;
  onLogout?: () => void;
  currentPage?: string;
}

export function Header({ show = true, isAdmin = false, onLogout, currentPage = "home" }: HeaderProps) {
  const { theme, toggleTheme } = useTheme();
  
  if (!show) return null;
  
  return (
    <header className="fixed top-0 left-0 right-0 z-50 bg-white/95 dark:bg-neutral-900/95 backdrop-blur-md border-b dark:border-neutral-800 shadow-sm">
      <div className="container mx-auto px-4 py-3 md:py-4 max-w-7xl">
        <div className="flex items-center justify-between gap-4">
          <a href={isAdmin ? "#dashboard" : "#home"} className="flex items-center gap-2 flex-shrink-0">
            <img 
              src={logoImage} 
              alt="Logo Satgas PPKPT PNL" 
              className="w-8 h-8 md:w-10 md:h-10 object-contain"
            />
            <span className="text-base md:text-xl dark:text-white whitespace-nowrap">SPM Satgas PPKPT</span>
            {isAdmin && (
              <Badge variant="default" className="ml-1 md:ml-2 bg-neutral-900 dark:bg-white dark:text-neutral-900 text-xs">
                Admin
              </Badge>
            )}
          </a>
          
          {!isAdmin && (
            <nav className="hidden md:flex items-center gap-2">
              <a href="#home" className="px-3 md:px-4 py-2 rounded-lg text-sm md:text-base text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-white transition-all hover:bg-neutral-100 dark:hover:bg-neutral-800">
                Home
              </a>
              <a href="#recorder" className="px-3 md:px-4 py-2 rounded-lg text-sm md:text-base text-neutral-600 dark:text-neutral-400 hover:text-neutral-900 dark:hover:text-white transition-all hover:bg-neutral-100 dark:hover:bg-neutral-800">
                Recorder
              </a>
            </nav>
          )}
          
          <div className="flex items-center gap-2 md:gap-3">
            <Button 
              variant="ghost" 
              size="icon"
              onClick={toggleTheme}
              className="dark:text-white h-8 w-8 md:h-10 md:w-10"
            >
              {theme === "light" ? <Moon className="w-4 h-4 md:w-5 md:h-5" /> : <Sun className="w-4 h-4 md:w-5 md:h-5" />}
            </Button>
            {isAdmin ? (
              <Button 
                variant="ghost" 
                className="gap-2 dark:text-white text-sm md:text-base"
                onClick={onLogout}
              >
                <LogOut className="w-3 h-3 md:w-4 md:h-4" />
                <span className="hidden sm:inline">Logout</span>
              </Button>
            ) : (
              <>
                <Button 
                  variant="ghost" 
                  className="dark:text-white text-sm md:text-base hidden sm:inline-flex"
                  onClick={() => window.location.hash = "#login"}
                >
                  Masuk
                </Button>
                <Button 
                  className="bg-neutral-900 dark:bg-white dark:text-neutral-900 hover:bg-neutral-800 dark:hover:bg-neutral-100 text-sm md:text-base h-8 md:h-10 px-3 md:px-4"
                  onClick={() => window.location.hash = "#recorder"}
                >
                  Mulai
                </Button>
              </>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}