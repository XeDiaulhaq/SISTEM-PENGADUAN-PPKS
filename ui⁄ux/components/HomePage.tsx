import { Hero } from "./Hero";
import { Footer } from "./Footer";

interface HomePageProps {
  isAdmin?: boolean;
  onLogout?: () => void;
}

export function HomePage({ isAdmin = false, onLogout }: HomePageProps) {
  return (
    <>
      <Hero isAdmin={isAdmin} onLogout={onLogout} />
      <Footer />
    </>
  );
}