import React from 'react'
import { LogoMark } from './logo'

interface LoadingProps {
  message?: string
  size?: 'sm' | 'md' | 'lg'
}

export function Loading({ message = 'Loading...', size = 'md' }: LoadingProps) {
  const sizes = {
    sm: 24,
    md: 40,
    lg: 64,
  }

  return (
    <div className="flex flex-col items-center justify-center gap-4 p-8">
      <div className="relative">
        {/* Rotating pocket watch logo */}
        <div className="animate-spin-slow">
          <LogoMark size={sizes[size]} />
        </div>
        
        {/* Pulsing glow effect */}
        <div 
          className="absolute inset-0 rounded-full blur-xl opacity-30 animate-pulse"
          style={{ backgroundColor: 'var(--amber)' }}
        />
      </div>
      
      {message && (
        <p className="text-sm text-[var(--dust)] animate-pulse">
          {message}
        </p>
      )}
    </div>
  )
}

export function LoadingSpinner({ size = 'md' }: { size?: 'sm' | 'md' | 'lg' }) {
  const sizeClasses = {
    sm: 'w-4 h-4 border-2',
    md: 'w-8 h-8 border-2',
    lg: 'w-12 h-12 border-3',
  }

  return (
    <div
      className={`${sizeClasses[size]} border-[var(--amber)] border-t-transparent rounded-full animate-spin`}
      role="status"
      aria-label="Loading"
    />
  )
}
