import type { Metadata } from "next";
import "./globals.css";

/**
 * The bare document. The web app lives in the (app) route group, which brings its own Convex
 * provider, fonts and sidebar; /privacy and /terms sit outside it as plain text.
 */
export const metadata: Metadata = {
  title: "Forklore",
  description: "What to eat next, with Pitchfork and real nutritionists.",
  robots: { index: false },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
