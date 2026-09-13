import type { Metadata } from "next";
import "./globals.css";

/**
 * There is no website. Personal OS is a phone app; this Next project is its
 * API server plus the two documents the app stores require a public URL for
 * (/privacy and /terms). Hence no providers, no fonts, no chrome — the only
 * pages this layout wraps are legal text.
 */
export const metadata: Metadata = {
  title: "Personal OS",
  description: "Personal OS runs on your phone. This site hosts its legal documents.",
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
