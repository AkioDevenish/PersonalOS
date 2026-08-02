import type { Metadata } from "next"
import { SignUp } from "@clerk/nextjs"
import AuthShell from "@/components/auth/auth-shell"

export const metadata: Metadata = {
  title: "Create your account | Personal OS",
  description: "Start free with local models and your own keys.",
  robots: { index: false },
}

export default function SignUpPage() {
  return (
    <AuthShell
      title={
        <>
          Open your <em>ledger.</em>
        </>
      }
      tagline="Time well spent"
    >
      <SignUp />
    </AuthShell>
  )
}
