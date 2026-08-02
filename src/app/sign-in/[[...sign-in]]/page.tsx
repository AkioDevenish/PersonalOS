import type { Metadata } from "next"
import { SignIn } from "@clerk/nextjs"
import AuthShell from "@/components/auth/auth-shell"

export const metadata: Metadata = {
  title: "Sign in | Personal OS",
  description: "Sign in to Personal OS.",
  robots: { index: false },
}

export default function SignInPage() {
  return (
    <AuthShell
      title={
        <>
          Welcome <em>back.</em>
        </>
      }
      tagline="Time well spent"
    >
      <SignIn />
    </AuthShell>
  )
}
