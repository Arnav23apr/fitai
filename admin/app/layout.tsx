import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "FitAI Admin",
  description: "Internal admin dashboard",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
