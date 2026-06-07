import { ImageResponse } from 'next/og'
 
export const runtime = 'edge'
export const alt = 'Personal OS - Time Well Spent'
export const size = {
  width: 1200,
  height: 630,
}
export const contentType = 'image/png'
 
export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          height: '100%',
          width: '100%',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          backgroundColor: '#FAF6EF',
          backgroundImage: 'radial-gradient(circle at 25% 25%, #E8C474 0%, transparent 50%), radial-gradient(circle at 75% 75%, #C9A961 0%, transparent 50%)',
        }}
      >
        {/* Logo */}
        <div style={{ display: 'flex', marginBottom: 40 }}>
          <svg width="200" height="200" viewBox="0 0 200 200" fill="none">
            <defs>
              <linearGradient id="watchGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stopColor="#C9A961" />
                <stop offset="50%" stopColor="#E8C474" />
                <stop offset="100%" stopColor="#B8944D" />
              </linearGradient>
              <linearGradient id="skinGradient" x1="0%" y1="0%" x2="0%" y2="100%">
                <stop offset="0%" stopColor="#D4A574" />
                <stop offset="100%" stopColor="#B8865F" />
              </linearGradient>
            </defs>
            
            <path d="M 70 130 Q 65 115 70 100 L 75 85 Q 80 70 90 75 L 95 80 Q 100 75 105 80 L 110 75 Q 115 70 120 75 L 125 85 L 130 100 Q 135 115 130 130 L 125 145 Q 120 155 100 160 Q 80 155 75 145 Z" 
                  fill="url(#skinGradient)" 
                  stroke="#9D7456" 
                  strokeWidth="1.5"/>
            
            <path d="M 70 110 Q 55 105 50 95 Q 48 85 55 80 Q 65 78 70 85 L 72 95 Z" 
                  fill="url(#skinGradient)" 
                  stroke="#9D7456" 
                  strokeWidth="1.5"/>
            
            <circle cx="100" cy="100" r="35" 
                    fill="url(#watchGradient)" 
                    stroke="#9D7F3E" 
                    strokeWidth="2"/>
            
            <circle cx="100" cy="100" r="28" 
                    fill="#F5F0E8" 
                    stroke="#8B7355" 
                    strokeWidth="0.5"/>
            
            <circle cx="100" cy="75" r="1.5" fill="#5C4A3A"/>
            <circle cx="125" cy="100" r="1.5" fill="#5C4A3A"/>
            <circle cx="100" cy="125" r="1.5" fill="#5C4A3A"/>
            <circle cx="75" cy="100" r="1.5" fill="#5C4A3A"/>
            
            <line x1="100" y1="100" x2="90" y2="90" 
                  stroke="#3C2F28" 
                  strokeWidth="2.5" 
                  strokeLinecap="round"/>
            
            <line x1="100" y1="100" x2="115" y2="85" 
                  stroke="#3C2F28" 
                  strokeWidth="1.5" 
                  strokeLinecap="round"/>
            
            <circle cx="100" cy="100" r="2.5" fill="#3C2F28"/>
          </svg>
        </div>

        {/* Title */}
        <div
          style={{
            fontSize: 80,
            fontWeight: 600,
            color: '#28200F',
            textAlign: 'center',
            marginBottom: 20,
            fontFamily: 'serif',
            fontStyle: 'italic',
          }}
        >
          Personal OS
        </div>

        {/* Tagline */}
        <div
          style={{
            fontSize: 32,
            color: '#6B5F4F',
            textAlign: 'center',
            letterSpacing: '0.12em',
            textTransform: 'uppercase',
            fontWeight: 500,
          }}
        >
          Time Well Spent
        </div>

        {/* Features */}
        <div
          style={{
            display: 'flex',
            gap: 40,
            marginTop: 60,
            fontSize: 20,
            color: '#8B7355',
          }}
        >
          <div>💪 Health</div>
          <div>📊 Data Science</div>
          <div>💼 Business</div>
          <div>📢 Marketing</div>
        </div>
      </div>
    ),
    {
      ...size,
    }
  )
}
