import React from 'react'

interface LogoProps {
  size?: number
  className?: string
  showText?: boolean
}

export function Logo({ size = 40, className = '', showText = false }: LogoProps) {
  return (
    <div className={`flex items-center gap-3 ${className}`}>
      <svg 
        width={size} 
        height={size} 
        viewBox="0 0 200 200" 
        fill="none" 
        xmlns="http://www.w3.org/2000/svg"
        aria-label="Personal OS Logo"
      >
        <defs>
          <linearGradient id="watchGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style={{ stopColor: 'var(--amber)', stopOpacity: 1 }} />
            <stop offset="50%" style={{ stopColor: '#E8C474', stopOpacity: 1 }} />
            <stop offset="100%" style={{ stopColor: '#B8944D', stopOpacity: 1 }} />
          </linearGradient>
          
          <radialGradient id="shadowGradient" cx="50%" cy="50%" r="50%">
            <stop offset="0%" style={{ stopColor: '#000', stopOpacity: 0.3 }} />
            <stop offset="100%" style={{ stopColor: '#000', stopOpacity: 0 }} />
          </radialGradient>
          
          <linearGradient id="skinGradient" x1="0%" y1="0%" x2="0%" y2="100%">
            <stop offset="0%" style={{ stopColor: '#D4A574', stopOpacity: 1 }} />
            <stop offset="100%" style={{ stopColor: '#B8865F', stopOpacity: 1 }} />
          </linearGradient>
        </defs>
        
        {/* Shadow */}
        <ellipse cx="100" cy="170" rx="60" ry="15" fill="url(#shadowGradient)" opacity="0.4"/>
        
        {/* Hand */}
        <g id="hand">
          <path d="M 70 130 Q 65 115 70 100 L 75 85 Q 80 70 90 75 L 95 80 Q 100 75 105 80 L 110 75 Q 115 70 120 75 L 125 85 L 130 100 Q 135 115 130 130 L 125 145 Q 120 155 100 160 Q 80 155 75 145 Z" 
                fill="url(#skinGradient)" 
                stroke="#9D7456" 
                strokeWidth="1.5"/>
          
          <path d="M 70 110 Q 55 105 50 95 Q 48 85 55 80 Q 65 78 70 85 L 72 95 Z" 
                fill="url(#skinGradient)" 
                stroke="#9D7456" 
                strokeWidth="1.5"/>
          
          <path d="M 90 75 Q 88 60 90 50 Q 92 45 95 45 Q 98 45 100 50 Q 102 60 100 75 Z" 
                fill="url(#skinGradient)" 
                stroke="#9D7456" 
                strokeWidth="1.5"/>
          
          <path d="M 105 75 Q 103 55 105 42 Q 107 35 110 35 Q 113 35 115 42 Q 117 55 115 75 Z" 
                fill="url(#skinGradient)" 
                stroke="#9D7456" 
                strokeWidth="1.5"/>
          
          <path d="M 120 75 Q 118 60 120 48 Q 122 43 125 43 Q 128 43 130 48 Q 132 60 130 75 Z" 
                fill="url(#skinGradient)" 
                stroke="#9D7456" 
                strokeWidth="1.5"/>
          
          <path d="M 75 145 Q 70 165 75 180 L 125 180 Q 130 165 125 145 Z" 
                fill="url(#skinGradient)" 
                stroke="#9D7456" 
                strokeWidth="1.5"/>
        </g>
        
        {/* Pocket watch */}
        <g id="pocketWatch">
          <path d="M 100 30 Q 102 40 100 50" 
                stroke="url(#watchGradient)" 
                strokeWidth="2" 
                fill="none" 
                strokeLinecap="round"/>
          
          <circle cx="100" cy="28" r="4" 
                  fill="none" 
                  stroke="url(#watchGradient)" 
                  strokeWidth="1.5"/>
          
          <circle cx="100" cy="100" r="35" 
                  fill="url(#watchGradient)" 
                  stroke="#9D7F3E" 
                  strokeWidth="2"/>
          
          <circle cx="100" cy="100" r="32" 
                  fill="none" 
                  stroke="#9D7F3E" 
                  strokeWidth="1"/>
          
          <circle cx="100" cy="100" r="28" 
                  fill="#F5F0E8" 
                  stroke="#8B7355" 
                  strokeWidth="0.5"/>
          
          <circle cx="100" cy="75" r="1.5" fill="#5C4A3A"/>
          <circle cx="125" cy="100" r="1.5" fill="#5C4A3A"/>
          <circle cx="100" cy="125" r="1.5" fill="#5C4A3A"/>
          <circle cx="75" cy="100" r="1.5" fill="#5C4A3A"/>
          
          <circle cx="112" cy="78" r="1" fill="#8B7355"/>
          <circle cx="122" cy="88" r="1" fill="#8B7355"/>
          <circle cx="122" cy="112" r="1" fill="#8B7355"/>
          <circle cx="112" cy="122" r="1" fill="#8B7355"/>
          <circle cx="88" cy="122" r="1" fill="#8B7355"/>
          <circle cx="78" cy="112" r="1" fill="#8B7355"/>
          <circle cx="78" cy="88" r="1" fill="#8B7355"/>
          <circle cx="88" cy="78" r="1" fill="#8B7355"/>
          
          <line x1="100" y1="100" x2="90" y2="90" 
                stroke="#3C2F28" 
                strokeWidth="2.5" 
                strokeLinecap="round"/>
          
          <line x1="100" y1="100" x2="115" y2="85" 
                stroke="#3C2F28" 
                strokeWidth="1.5" 
                strokeLinecap="round"/>
          
          <circle cx="100" cy="100" r="2.5" fill="#3C2F28"/>
          
          <rect x="133" y="97" width="5" height="6" 
                rx="1" 
                fill="url(#watchGradient)" 
                stroke="#9D7F3E" 
                strokeWidth="0.5"/>
          
          <circle cx="100" cy="100" r="24" 
                  fill="none" 
                  stroke="#D4B887" 
                  strokeWidth="0.3" 
                  opacity="0.5"/>
        </g>
      </svg>
      
      {showText && (
        <div className="flex flex-col">
          <span 
            className="text-lg font-light text-[var(--deep-brown)] leading-none"
            style={{ fontFamily: 'var(--font-display)' }}
          >
            Personal OS
          </span>
          <span className="text-[9px] uppercase tracking-[0.12em] text-[var(--dust)] mt-0.5">
            Time Well Spent
          </span>
        </div>
      )}
    </div>
  )
}

export function LogoMark({ size = 32, className = '' }: Omit<LogoProps, 'showText'>) {
  return (
    <svg 
      width={size} 
      height={size} 
      viewBox="0 0 32 32" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      aria-label="Personal OS Icon"
    >
      <defs>
        <linearGradient id="watchGrad" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" style={{ stopColor: 'var(--amber)', stopOpacity: 1 }} />
          <stop offset="100%" style={{ stopColor: '#B8944D', stopOpacity: 1 }} />
        </linearGradient>
      </defs>
      
      <path d="M 10 22 Q 8 18 10 14 L 11 10 Q 12 8 14 10 L 15 11 Q 16 10 17 11 L 18 10 Q 19 8 20 10 L 21 14 Q 23 18 22 22 L 20 26 Q 18 28 16 28 Q 14 28 12 26 Z" 
            fill="#D4A574" 
            stroke="#9D7456" 
            strokeWidth="0.5"/>
      
      <circle cx="16" cy="16" r="9" 
              fill="url(#watchGrad)" 
              stroke="#9D7F3E" 
              strokeWidth="1"/>
      
      <circle cx="16" cy="16" r="7" 
              fill="#F5F0E8"/>
      
      <line x1="16" y1="16" x2="13" y2="13" 
            stroke="#3C2F28" 
            strokeWidth="1.2" 
            strokeLinecap="round"/>
      
      <line x1="16" y1="16" x2="19" y2="12" 
            stroke="#3C2F28" 
            strokeWidth="0.8" 
            strokeLinecap="round"/>
      
      <circle cx="16" cy="16" r="1" fill="#3C2F28"/>
    </svg>
  )
}
