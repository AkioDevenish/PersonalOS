import type { Metadata, Viewport } from "next";
import { Cormorant_Garamond, Jost } from "next/font/google";
import "./globals.css";
import { ConvexClientProvider } from "@/providers/ConvexClientProvider";
import { ClerkProvider } from '@clerk/nextjs';

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
      { url: "/icon.svg", type: "image/svg+xml" },
      { url: "/icon", type: "image/png", sizes: "32x32" },
    ],
    apple: [
      { url: "/apple-icon", sizes: "180x180", type: "image/png" },
    ],
    shortcut: ["/icon.svg"],
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
      appearance={{
        variables: {
          colorPrimary: '#C9A961',
          colorBackground: '#FAF6EF',
          colorText: '#28200F',
          colorInputBackground: '#FFFFFF',
          colorInputText: '#28200F',
          borderRadius: '12px',
          fontFamily: 'var(--font-sans)',
        },
        elements: {
          formButtonPrimary: 'bg-[var(--amber)] hover:opacity-90',
          card: 'shadow-md',
          headerTitle: 'font-display text-2xl',
          headerSubtitle: 'text-[var(--dust)]',
          socialButtonsBlockButton: 'border-[var(--border-subtle)]',
          formFieldLabel: 'text-[var(--mid-brown)] font-medium',
          footerActionLink: 'text-[var(--amber)] hover:opacity-80',
        },
      }}
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
