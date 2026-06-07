import { SignUp } from '@clerk/nextjs'
import { Logo } from '@/components/ui/logo'

export default function SignUpPage() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-[var(--linen)] p-4">
      <div className="mb-8 text-center">
        <Logo size={80} showText={false} />
        <h1 
          className="text-3xl mt-6 text-[var(--deep-brown)]"
          style={{ fontFamily: 'var(--font-display)' }}
        >
          Start Your Journey
        </h1>
        <p className="text-sm text-[var(--dust)] mt-2 uppercase tracking-[0.12em]">
          Time Well Spent
        </p>
      </div>
      
      <SignUp 
        appearance={{
          elements: {
            rootBox: 'mx-auto',
            card: 'shadow-lg border border-[var(--border-subtle)]',
          }
        }}
      />
    </div>
  )
}
