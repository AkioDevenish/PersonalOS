import type { Metadata, Viewport } from "next";
import { Cormorant_Garamond, Jost } from "next/font/google";
import "./globals.css";
import { ConvexClientProvider } from "@/providers/ConvexClientProvider";
import { ClerkProvider } from '@clerk/nextjs';
import { clerkAppearance, clerkLocalization } from '@/components/auth/clerk-appearance';

const cormorant = Cormorant_Garamond({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
  style: ["normal", "italic"],
});

const jost = Jost({
  variable: "--font-sans",
  subsets: ["latin"],
  weight: ["300", "400", "500", "600"],
});

export const metadata: Metadata = {
  title: "Personal OS | Time Well Spent",
  description: "A calm, grounded space for your day - manage your business, health, and creative work in one place",
  keywords: ["personal os", "productivity", "time management", "health tracking", "business management"],
  authors: [{ name: "Akio" }],
  creator: "Akio",
  publisher: "Personal OS",
  applicationName: "Personal OS",
  appleWebApp: {
    capable: true,
    title: "Personal OS",
    statusBarStyle: "black-translucent",
  },
  openGraph: {
    type: "website",
    title: "Personal OS | Time Well Spent",
    description: "A calm, grounded space for your day",
    siteName: "Personal OS",
    images: [
      {
        url: "/logo.svg",
        width: 200,
        height: 200,
        alt: "Personal OS Logo - Hand holding pocket watch",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "Personal OS | Time Well Spent",
    description: "A calm, grounded space for your day",
    images: ["/logo.svg"],
  },
  icons: {
    icon: [
      { url: "/story/icon.png", type: "image/png" },
    ],
    apple: [
      { url: "/story/icon.png", type: "image/png" },
    ],
    shortcut: ["/story/icon.png"],
  },
  manifest: "/site.webmanifest",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <ClerkProvider
      appearance={clerkAppearance}
      localization={clerkLocalization}
    >
      <html
        lang="en"
        className={`${cormorant.variable} ${jost.variable} h-full antialiased`}
        suppressHydrationWarning
      >
        <body className="min-h-full flex flex-col" suppressHydrationWarning>
          <ConvexClientProvider>
            {children}
          </ConvexClientProvider>
        </body>
      </html>
    </ClerkProvider>
  );
}
