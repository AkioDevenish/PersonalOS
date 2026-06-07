import { ImageResponse } from 'next/og'
 
export const runtime = 'edge'
export const size = { width: 32, height: 32 }
export const contentType = 'image/png'
 
export default function Icon() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: '#FAF6EF',
        }}
      >
        <svg width="32" height="32" viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient id="watchGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#C9A961" stopOpacity="1" />
              <stop offset="100%" stopColor="#B8944D" stopOpacity="1" />
            </linearGradient>
          </defs>
          
          {/* Simplified hand */}
          <path d="M 10 22 Q 8 18 10 14 L 11 10 Q 12 8 14 10 L 15 11 Q 16 10 17 11 L 18 10 Q 19 8 20 10 L 21 14 Q 23 18 22 22 L 20 26 Q 18 28 16 28 Q 14 28 12 26 Z" 
                fill="#D4A574" 
                stroke="#9D7456" 
                strokeWidth="0.5"/>
          
          {/* Pocket watch */}
          <circle cx="16" cy="16" r="9" 
                  fill="url(#watchGrad)" 
                  stroke="#9D7F3E" 
                  strokeWidth="1"/>
          
          <circle cx="16" cy="16" r="7" 
                  fill="#F5F0E8"/>
          
          {/* Watch hands */}
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
      </div>
    ),
    size
  )
}
