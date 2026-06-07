"use client"

export function HeroBackground() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden>
      {/* Ambient glow orbs */}
      <div
        className="absolute top-[20%] left-[15%] w-[32rem] h-[32rem] rounded-full opacity-15 animate-pulse"
        style={{ backgroundColor: "var(--amber-low)", filter: "blur(120px)", animationDuration: "8s" }}
      />
      <div
        className="absolute bottom-[15%] right-[10%] w-[28rem] h-[28rem] rounded-full opacity-10 animate-pulse"
        style={{ backgroundColor: "var(--sage-low)", filter: "blur(100px)", animationDuration: "10s", animationDelay: "1s" }}
      />

      {/* 3D Watch + Orbits Container */}
      <div
        className="absolute inset-0 flex items-center justify-center"
        style={{ perspective: "1200px" }}
      >
        <div className="relative w-[600px] h-[600px]" style={{ transformStyle: "preserve-3d" }}>

          {/* ── Pocket Watch (center) ── */}
          <div
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              transformStyle: "preserve-3d",
              animation: "watch-float 6s ease-in-out infinite",
            }}
          >
            <svg
              width="140"
              height="140"
              viewBox="0 0 200 200"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              style={{
                filter: "drop-shadow(0 20px 40px rgba(40,32,15,0.15))",
                animation: "watch-rotate 20s linear infinite",
              }}
            >
              <defs>
                <linearGradient id="heroWatchGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" style={{ stopColor: "#B8845A", stopOpacity: 1 }} />
                  <stop offset="50%" style={{ stopColor: "#E8C474", stopOpacity: 1 }} />
                  <stop offset="100%" style={{ stopColor: "#B8944D", stopOpacity: 1 }} />
                </linearGradient>
                <linearGradient id="heroSkinGrad" x1="0%" y1="0%" x2="0%" y2="100%">
                  <stop offset="0%" style={{ stopColor: "#D4A574", stopOpacity: 1 }} />
                  <stop offset="100%" style={{ stopColor: "#B8865F", stopOpacity: 1 }} />
                </linearGradient>
              </defs>

              {/* Shadow */}
              <ellipse cx="100" cy="170" rx="55" ry="12" fill="rgba(40,32,15,0.08)" />

              {/* Hand */}
              <path
                d="M 70 130 Q 65 115 70 100 L 75 85 Q 80 70 90 75 L 95 80 Q 100 75 105 80 L 110 75 Q 115 70 120 75 L 125 85 L 130 100 Q 135 115 130 130 L 125 145 Q 120 155 100 160 Q 80 155 75 145 Z"
                fill="url(#heroSkinGrad)"
                stroke="#9D7456"
                strokeWidth="1.5"
              />
              {/* Thumb */}
              <path
                d="M 70 110 Q 55 105 50 95 Q 48 85 55 80 Q 65 78 70 85 L 72 95 Z"
                fill="url(#heroSkinGrad)"
                stroke="#9D7456"
                strokeWidth="1.5"
              />
              {/* Fingers */}
              <path d="M 90 75 Q 88 60 90 50 Q 92 45 95 45 Q 98 45 100 50 Q 102 60 100 75 Z" fill="url(#heroSkinGrad)" stroke="#9D7456" strokeWidth="1.5" />
              <path d="M 105 75 Q 103 55 105 42 Q 107 35 110 35 Q 113 35 115 42 Q 117 55 115 75 Z" fill="url(#heroSkinGrad)" stroke="#9D7456" strokeWidth="1.5" />
              <path d="M 120 75 Q 118 60 120 48 Q 122 43 125 43 Q 128 43 130 48 Q 132 60 130 75 Z" fill="url(#heroSkinGrad)" stroke="#9D7456" strokeWidth="1.5" />
              {/* Palm */}
              <path d="M 75 145 Q 70 165 75 180 L 125 180 Q 130 165 125 145 Z" fill="url(#heroSkinGrad)" stroke="#9D7456" strokeWidth="1.5" />

              {/* Watch body */}
              <circle cx="100" cy="100" r="35" fill="url(#heroWatchGrad)" stroke="#9D7F3E" strokeWidth="2" />
              <circle cx="100" cy="100" r="32" fill="none" stroke="#9D7F3E" strokeWidth="1" />
              <circle cx="100" cy="100" r="28" fill="#F5F0E8" stroke="#8B7355" strokeWidth="0.5" />

              {/* Hour markers */}
              <circle cx="100" cy="75" r="1.5" fill="#5C4A3A" />
              <circle cx="125" cy="100" r="1.5" fill="#5C4A3A" />
              <circle cx="100" cy="125" r="1.5" fill="#5C4A3A" />
              <circle cx="75" cy="100" r="1.5" fill="#5C4A3A" />

              {/* Minute markers */}
              <circle cx="112" cy="78" r="1" fill="#8B7355" />
              <circle cx="122" cy="88" r="1" fill="#8B7355" />
              <circle cx="122" cy="112" r="1" fill="#8B7355" />
              <circle cx="112" cy="122" r="1" fill="#8B7355" />
              <circle cx="88" cy="122" r="1" fill="#8B7355" />
              <circle cx="78" cy="112" r="1" fill="#8B7355" />
              <circle cx="78" cy="88" r="1" fill="#8B7355" />
              <circle cx="88" cy="78" r="1" fill="#8B7355" />

              {/* Hands */}
              <line x1="100" y1="100" x2="90" y2="88" stroke="#3C2F28" strokeWidth="2.5" strokeLinecap="round">
                <animateTransform
                  attributeName="transform"
                  type="rotate"
                  from="0 100 100"
                  to="360 100 100"
                  dur="43200s"
                  repeatCount="indefinite"
                />
              </line>
              <line x1="100" y1="100" x2="115" y2="85" stroke="#3C2F28" strokeWidth="1.5" strokeLinecap="round">
                <animateTransform
                  attributeName="transform"
                  type="rotate"
                  from="0 100 100"
                  to="360 100 100"
                  dur="3600s"
                  repeatCount="indefinite"
                />
              </line>

              <circle cx="100" cy="100" r="2.5" fill="#3C2F28" />

              {/* Crown */}
              <rect x="133" y="97" width="5" height="6" rx="1" fill="url(#heroWatchGrad)" stroke="#9D7F3E" strokeWidth="0.5" />

              {/* Inner ring detail */}
              <circle cx="100" cy="100" r="24" fill="none" stroke="#D4B887" strokeWidth="0.3" opacity="0.5" />
            </svg>
          </div>

          {/* ── Orbiting Rings ── */}
          {/* Ring 1 — wide, slow */}
          <div
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              width: "480px",
              height: "480px",
              borderRadius: "50%",
              border: "1px solid rgba(184,132,90,0.12)",
              transformStyle: "preserve-3d",
              animation: "orbit-1 25s linear infinite",
            }}
          >
            <div
              className="absolute w-2.5 h-2.5 rounded-full"
              style={{
                background: "radial-gradient(circle, var(--amber) 0%, transparent 70%)",
                top: "-5px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 12px rgba(184,132,90,0.4)",
              }}
            />
          </div>

          {/* Ring 2 — medium, medium speed */}
          <div
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              width: "380px",
              height: "380px",
              borderRadius: "50%",
              border: "1px solid rgba(125,147,122,0.12)",
              transformStyle: "preserve-3d",
              animation: "orbit-2 18s linear infinite",
            }}
          >
            <div
              className="absolute w-2 h-2 rounded-full"
              style={{
                background: "radial-gradient(circle, var(--sage) 0%, transparent 70%)",
                top: "-4px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 10px rgba(125,147,122,0.4)",
              }}
            />
          </div>

          {/* Ring 3 — tight, fast */}
          <div
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              width: "280px",
              height: "280px",
              borderRadius: "50%",
              border: "1px solid rgba(184,132,90,0.1)",
              transformStyle: "preserve-3d",
              animation: "orbit-3 12s linear infinite",
            }}
          >
            <div
              className="absolute w-1.5 h-1.5 rounded-full"
              style={{
                background: "radial-gradient(circle, #E8C474 0%, transparent 70%)",
                top: "-3px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 8px rgba(232,196,116,0.4)",
              }}
            />
          </div>

          {/* Ring 4 — extra wide, very slow */}
          <div
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              width: "560px",
              height: "560px",
              borderRadius: "50%",
              border: "1px solid rgba(168,149,126,0.08)",
              transformStyle: "preserve-3d",
              animation: "orbit-4 35s linear infinite",
            }}
          >
            <div
              className="absolute w-2 h-2 rounded-full"
              style={{
                background: "radial-gradient(circle, var(--dust) 0%, transparent 70%)",
                top: "-4px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 10px rgba(168,149,126,0.3)",
              }}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
