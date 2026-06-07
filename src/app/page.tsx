"use client"

import { useEffect, useRef } from "react"
import Link from "next/link"
import { BarChart3, HeartPulse, Workflow, Sparkles } from "lucide-react"
import { LogoMark } from "@/components/ui/logo"
import { useAuth } from '@clerk/nextjs'
import { useRouter } from 'next/navigation'

export default function SaaSLandingPage() {
  const headerRef = useRef<HTMLElement>(null);
  const revealsRef = useRef<HTMLDivElement[]>([]);
  const { isSignedIn, isLoaded } = useAuth()
  const router = useRouter()

  // Redirect authenticated users to hub
  useEffect(() => {
    if (isLoaded && isSignedIn) {
      router.push('/hub')
    }
  }, [isLoaded, isSignedIn, router])

  useEffect(() => {
    // Fallback for browsers that do not support scroll-driven animations natively (Firefox)
    if (typeof CSS !== 'undefined' && !CSS.supports('(animation-timeline: scroll()) and (animation-range: 0% 100%)')) {
      const handleScroll = () => {
        const scrollY = window.scrollY;
        
        // Shrinking header fallback
        if (headerRef.current) {
          const scrollDistance = 150;
          const scrollPercent = Math.min(1, scrollY / scrollDistance);
          const initialPadding = 24; // 1.5rem (space-5 equivalent)
          const finalPadding = 12; // 0.75rem (space-3 equivalent)
          const newPadding = initialPadding - (initialPadding - finalPadding) * scrollPercent;
          
          headerRef.current.style.paddingTop = `${newPadding}px`;
          headerRef.current.style.paddingBottom = `${newPadding}px`;
          headerRef.current.style.backgroundColor = `rgba(249, 246, 240, ${0.9 * scrollPercent})`;
          headerRef.current.style.backdropFilter = `blur(${16 * scrollPercent}px)`;
          if (scrollPercent > 0) {
            headerRef.current.style.boxShadow = "0 1px 3px rgba(40,32,15,0.04)";
            headerRef.current.style.borderBottom = "1px solid rgba(40,32,15,0.10)";
          } else {
            headerRef.current.style.boxShadow = "none";
            headerRef.current.style.borderBottom = "none";
          }
        }
      };

      window.addEventListener('scroll', handleScroll);
      
      // Reveal fallback using IntersectionObserver
      const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
          if (entry.isIntersecting) {
            (entry.target as HTMLElement).style.opacity = '1';
            (entry.target as HTMLElement).style.transform = 'translateY(0) scale(1)';
            observer.unobserve(entry.target);
          }
        });
      }, { threshold: 0.1 });

      revealsRef.current.forEach(el => {
        if (el) {
          el.style.opacity = '0';
          el.style.transform = 'translateY(40px) scale(0.98)';
          el.style.transition = 'opacity 0.6s cubic-bezier(0.2, 0, 0, 1), transform 0.6s cubic-bezier(0.2, 0, 0, 1)';
          observer.observe(el);
        }
      });

      return () => {
        window.removeEventListener('scroll', handleScroll);
        observer.disconnect();
      };
    }
  }, []);

  const addToReveals = (el: HTMLDivElement | null) => {
    if (el && !revealsRef.current.includes(el)) {
      revealsRef.current.push(el);
    }
  };

  return (
    <div className="min-h-screen bg-base text-text-primary overflow-x-hidden selection:bg-amber-low">
      {/* Fixed Header */}
      <header 
        ref={headerRef}
        className="fixed top-0 left-0 right-0 z-50 px-6 py-6 saas-header flex items-center justify-between transition-colors duration-200"
      >
        <div className="flex items-center gap-2">
          <LogoMark size={32} />
          <span className="font-display text-xl font-bold tracking-tight">Personal OS</span>
        </div>
        <nav className="flex items-center gap-6">
          <Link href="#features" className="text-text-secondary hover:text-text-primary text-sm font-medium transition-colors">Features</Link>
          {isLoaded && (
            isSignedIn ? (
              <Link href="/hub" className="bg-text-primary text-elevated px-4 py-2 rounded-md text-sm font-medium hover:bg-mid-brown transition-transform hover:scale-[1.02] active:scale-[0.98] shadow-md text-white">
                Go to Hub
              </Link>
            ) : (
              <Link href="/sign-in" className="bg-text-primary text-elevated px-4 py-2 rounded-md text-sm font-medium hover:bg-mid-brown transition-transform hover:scale-[1.02] active:scale-[0.98] shadow-md text-white">
                Sign In
              </Link>
            )
          )}
        </nav>
      </header>

      <main className="pt-32 pb-24">
        {/* Hero Section */}
        <section className="px-6 max-w-5xl mx-auto text-center mt-12 mb-32 animate-fade-in">
          <h1 className="font-display text-5xl md:text-7xl font-bold tracking-tight leading-[1.1] mb-6 text-deep-brown">
            The Operating System <br />
            <span className="text-accent-amber">for Your Life.</span>
          </h1>
          <p className="text-lg md:text-xl text-text-secondary max-w-2xl mx-auto mb-10 leading-relaxed">
            Consolidate your well-being, business CRM, marketing content, and daily metrics into one unified, intelligent workspace powered by local AI.
          </p>
          <div className="flex items-center justify-center gap-4 flex-wrap">
            {isLoaded && !isSignedIn && (
              <>
                <Link href="/sign-up" className="bg-[#E8553D] text-white px-8 py-3 rounded-md font-medium text-lg hover:opacity-90 transition-transform hover:scale-[1.02] active:scale-[0.98] shadow-md">
                  Start Free Trial
                </Link>
                <Link href="#features" className="bg-elevated border border-border-mid text-text-primary px-8 py-3 rounded-md font-medium text-lg hover:bg-hover transition-colors shadow-sm">
                  See How It Works
                </Link>
              </>
            )}
            {isLoaded && isSignedIn && (
              <Link href="/hub" className="bg-[#E8553D] text-white px-8 py-3 rounded-md font-medium text-lg hover:opacity-90 transition-transform hover:scale-[1.02] active:scale-[0.98] shadow-md">
                Go to Your Dashboard
              </Link>
            )}
          </div>
        </section>

        {/* Feature Bento Grid */}
        <section id="features" className="px-6 max-w-5xl mx-auto scroll-mt-32">
          <div className="text-center mb-16">
            <h2 className="font-display text-3xl md:text-4xl font-bold mb-4 text-deep-brown">Everything in its right place.</h2>
            <p className="text-text-secondary text-lg">Stop context-switching. Run your life from a single dashboard.</p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {/* Bento Box 1 */}
            <div ref={addToReveals} className="saas-scroll-reveal col-span-1 lg:col-span-2 bg-elevated rounded-xl p-8 border border-border-subtle shadow-sm relative overflow-hidden group">
              <div className="absolute top-0 right-0 p-8 opacity-10 transform translate-x-4 -translate-y-4 group-hover:scale-110 transition-transform duration-500">
                <HeartPulse className="w-32 h-32 text-accent-sage" />
              </div>
              <div className="relative z-10">
                <div className="w-12 h-12 rounded-lg bg-sage-low/30 text-accent-sage flex items-center justify-center mb-6">
                  <HeartPulse className="w-6 h-6" />
                </div>
                <h3 className="font-display text-2xl font-bold mb-3 text-deep-brown">Health & Well-being</h3>
                <p className="text-text-secondary max-w-md leading-relaxed">
                  Sync automatically with Apple Health, track your metabolic events, and get personalized, AI-driven nutrition and recovery recommendations daily.
                </p>
              </div>
            </div>

            {/* Bento Box 2 */}
            <div ref={addToReveals} className="saas-scroll-reveal col-span-1 bg-elevated rounded-xl p-8 border border-border-subtle shadow-sm relative overflow-hidden group">
              <div className="relative z-10">
                <div className="w-12 h-12 rounded-lg bg-amber-low/30 text-accent-amber flex items-center justify-center mb-6">
                  <Workflow className="w-6 h-6" />
                </div>
                <h3 className="font-display text-2xl font-bold mb-3 text-deep-brown">Business CRM</h3>
                <p className="text-text-secondary leading-relaxed">
                  Manage deals, track follow-ups, and log communications. Never let an opportunity slip through the cracks again.
                </p>
              </div>
            </div>

            {/* Bento Box 3 */}
            <div ref={addToReveals} className="saas-scroll-reveal col-span-1 bg-elevated rounded-xl p-8 border border-border-subtle shadow-sm relative overflow-hidden group">
              <div className="relative z-10">
                <div className="w-12 h-12 rounded-lg bg-[#C75B5B]/10 text-[#C75B5B] flex items-center justify-center mb-6">
                  <Sparkles className="w-6 h-6" />
                </div>
                <h3 className="font-display text-2xl font-bold mb-3 text-deep-brown">Content Marketing</h3>
                <p className="text-text-secondary leading-relaxed">
                  Schedule posts, track compounding social media metrics, and maintain a sustainable content pipeline.
                </p>
              </div>
            </div>

            {/* Bento Box 4 */}
            <div ref={addToReveals} className="saas-scroll-reveal col-span-1 lg:col-span-2 bg-elevated rounded-xl p-8 border border-border-subtle shadow-sm relative overflow-hidden group">
               <div className="absolute bottom-0 right-8 transform translate-y-1/4 group-hover:-translate-y-2 transition-transform duration-500">
                <BarChart3 className="w-48 h-48 text-border-subtle opacity-50" />
              </div>
              <div className="relative z-10">
                <div className="w-12 h-12 rounded-lg bg-dust/20 text-text-primary flex items-center justify-center mb-6">
                  <BarChart3 className="w-6 h-6" />
                </div>
                <h3 className="font-display text-2xl font-bold mb-3 text-deep-brown">Local AI Analytics</h3>
                <p className="text-text-secondary max-w-md leading-relaxed">
                  Your data stays on your machine. Powerful local models analyze your activity and habits without sending anything to the cloud.
                </p>
              </div>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-border-subtle py-12 px-6 mt-12 bg-elevated/50">
        <div className="max-w-5xl mx-auto flex flex-col md:flex-row items-center justify-between text-text-muted text-sm gap-4">
          <p>© {new Date().getFullYear()} Personal OS. All rights reserved.</p>
          <div className="flex gap-6">
            <Link href="/privacy" className="hover:text-text-primary transition-colors">Privacy Policy</Link>
            <Link href="/terms" className="hover:text-text-primary transition-colors">Terms of Service</Link>
          </div>
        </div>
      </footer>
    </div>
  )
}
