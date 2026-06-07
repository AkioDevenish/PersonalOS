"use client"

export function HeroBackground() {
  return (
    <div className="absolute inset-0 overflow-hidden pointer-events-none" aria-hidden>
      {/* Ambient glow orbs */}
      <div
        className="absolute top-[20%] left-[15%] w-[32rem] h-[32rem] rounded-full opacity-10 animate-pulse"
        style={{ backgroundColor: "var(--amber-low)", filter: "blur(120px)", animationDuration: "8s" }}
      />
      <div
        className="absolute bottom-[15%] right-[10%] w-[28rem] h-[28rem] rounded-full opacity-8 animate-pulse"
        style={{ backgroundColor: "var(--sage-low)", filter: "blur(100px)", animationDuration: "10s", animationDelay: "1s" }}
      />

      {/* 3D Watch + Orbits Container */}
      <div
        className="absolute inset-0 flex items-center justify-center"
        style={{ perspective: "1200px" }}
      >
        <div className="relative w-[600px] h-[600px]" style={{ transformStyle: "preserve-3d" }}>

          {/* ── Wireframe Pocket Watch ── */}
          <div
            className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2"
            style={{
              transformStyle: "preserve-3d",
              animation: "watch-float 6s ease-in-out infinite",
            }}
          >
            <svg
              width="180"
              height="200"
              viewBox="0 0 200 220"
              fill="none"
              xmlns="http://www.w3.org/2000/svg"
              style={{
                animation: "watch-rotate 20s linear infinite",
              }}
            >
              <defs>
                <linearGradient id="wireStroke" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" style={{ stopColor: "#A8957E", stopOpacity: 0.6 }} />
                  <stop offset="100%" style={{ stopColor: "#6E5D45", stopOpacity: 0.4 }} />
                </linearGradient>
              </defs>

              {/* ── Chain / Ring at top ── */}
              <circle cx="100" cy="18" r="8" stroke="url(#wireStroke)" strokeWidth="0.8" fill="none" />
              <circle cx="100" cy="18" r="4" stroke="url(#wireStroke)" strokeWidth="0.5" fill="none" strokeDasharray="2 2" />
              <line x1="100" y1="26" x2="100" y2="38" stroke="url(#wireStroke)" strokeWidth="0.8" />

              {/* ── Crown (winding knob) ── */}
              <rect x="94" y="32" width="12" height="8" rx="2" stroke="url(#wireStroke)" strokeWidth="0.8" fill="none" />
              <line x1="97" y1="34" x2="97" y2="38" stroke="url(#wireStroke)" strokeWidth="0.4" />
              <line x1="100" y1="34" x2="100" y2="38" stroke="url(#wireStroke)" strokeWidth="0.4" />
              <line x1="103" y1="34" x2="103" y2="38" stroke="url(#wireStroke)" strokeWidth="0.4" />

              {/* ── Outer case ── */}
              <circle cx="100" cy="110" r="52" stroke="url(#wireStroke)" strokeWidth="1" fill="none" />
              <circle cx="100" cy="110" r="50" stroke="url(#wireStroke)" strokeWidth="0.5" fill="none" strokeDasharray="4 3" />

              {/* ── Inner bezel ── */}
              <circle cx="100" cy="110" r="44" stroke="url(#wireStroke)" strokeWidth="0.6" fill="none" />

              {/* ── Dial face ── */}
              <circle cx="100" cy="110" r="40" stroke="url(#wireStroke)" strokeWidth="0.8" fill="none" />

              {/* ── Hour markers (lines, not dots) ── */}
              {/* 12 */}
              <line x1="100" y1="72" x2="100" y2="78" stroke="url(#wireStroke)" strokeWidth="1.2" />
              {/* 3 */}
              <line x1="138" y1="110" x2="132" y2="110" stroke="url(#wireStroke)" strokeWidth="1.2" />
              {/* 6 */}
              <line x1="100" y1="148" x2="100" y2="142" stroke="url(#wireStroke)" strokeWidth="1.2" />
              {/* 9 */}
              <line x1="62" y1="110" x2="68" y2="110" stroke="url(#wireStroke)" strokeWidth="1.2" />

              {/* ── Minute markers (tiny ticks) ── */}
              {[...Array(60)].map((_, i) => {
                if (i % 5 === 0) return null
                const angle = (i * 6 - 90) * (Math.PI / 180)
                const x1 = 100 + 40 * Math.cos(angle)
                const y1 = 110 + 40 * Math.sin(angle)
                const x2 = 100 + 38 * Math.cos(angle)
                const y2 = 110 + 38 * Math.sin(angle)
                return (
                  <line
                    key={i}
                    x1={x1} y1={y1} x2={x2} y2={y2}
                    stroke="url(#wireStroke)"
                    strokeWidth="0.3"
                  />
                )
              })}

              {/* ── Cross-hair guides (construction lines) ── */}
              <line x1="100" y1="72" x2="100" y2="148" stroke="url(#wireStroke)" strokeWidth="0.2" strokeDasharray="1 3" />
              <line x1="62" y1="110" x2="138" y2="110" stroke="url(#wireStroke)" strokeWidth="0.2" strokeDasharray="1 3" />

              {/* ── Diagonal construction lines ── */}
              <line x1="73" y1="83" x2="127" y2="137" stroke="url(#wireStroke)" strokeWidth="0.15" strokeDasharray="1 4" />
              <line x1="127" y1="83" x2="73" y2="137" stroke="url(#wireStroke)" strokeWidth="0.15" strokeDasharray="1 4" />

              {/* ── Inner decorative circles ── */}
              <circle cx="100" cy="110" r="30" stroke="url(#wireStroke)" strokeWidth="0.2" fill="none" strokeDasharray="2 4" />
              <circle cx="100" cy="110" r="20" stroke="url(#wireStroke)" strokeWidth="0.15" fill="none" strokeDasharray="1 3" />

              {/* ── Hour hand (animated) ── */}
              <g>
                <animateTransform
                  attributeName="transform"
                  type="rotate"
                  from="0 100 110"
                  to="360 100 110"
                  dur="43200s"
                  repeatCount="indefinite"
                />
                <line x1="100" y1="110" x2="100" y2="82" stroke="url(#wireStroke)" strokeWidth="1.5" strokeLinecap="round" />
                <line x1="100" y1="110" x2="100" y2="118" stroke="url(#wireStroke)" strokeWidth="0.8" strokeLinecap="round" />
              </g>

              {/* ── Minute hand (animated) ── */}
              <g>
                <animateTransform
                  attributeName="transform"
                  type="rotate"
                  from="0 100 110"
                  to="360 100 110"
                  dur="3600s"
                  repeatCount="indefinite"
                />
                <line x1="100" y1="110" x2="100" y2="76" stroke="url(#wireStroke)" strokeWidth="1" strokeLinecap="round" />
                <line x1="100" y1="110" x2="100" y2="120" stroke="url(#wireStroke)" strokeWidth="0.6" strokeLinecap="round" />
              </g>

              {/* ── Center pivot ── */}
              <circle cx="100" cy="110" r="2" stroke="url(#wireStroke)" strokeWidth="0.8" fill="none" />
              <circle cx="100" cy="110" r="0.8" fill="url(#wireStroke)" />

              {/* ── Sub-dial (seconds) ── */}
              <circle cx="100" cy="130" r="10" stroke="url(#wireStroke)" strokeWidth="0.3" fill="none" strokeDasharray="2 2" />
              <g>
                <animateTransform
                  attributeName="transform"
                  type="rotate"
                  from="0 100 130"
                  to="360 100 130"
                  dur="60s"
                  repeatCount="indefinite"
                />
                <line x1="100" y1="130" x2="100" y2="122" stroke="url(#wireStroke)" strokeWidth="0.4" strokeLinecap="round" />
              </g>

              {/* ── Lug details (wireframe) ── */}
              <path d="M 80 58 Q 78 52 80 46" stroke="url(#wireStroke)" strokeWidth="0.5" fill="none" />
              <path d="M 120 58 Q 122 52 120 46" stroke="url(#wireStroke)" strokeWidth="0.5" fill="none" />

              {/* ── Measurement annotations ── */}
              <text x="155" y="110" fill="url(#wireStroke)" fontSize="4" fontFamily="monospace" textAnchor="middle" opacity="0.4">
                40mm
              </text>
              <line x1="142" y1="106" x2="142" y2="114" stroke="url(#wireStroke)" strokeWidth="0.3" opacity="0.4" />
              <line x1="142" y1="110" x2="158" y2="110" stroke="url(#wireStroke)" strokeWidth="0.2" strokeDasharray="1 2" opacity="0.4" />
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
              border: "1px solid rgba(168,149,126,0.1)",
              transformStyle: "preserve-3d",
              animation: "orbit-1 25s linear infinite",
            }}
          >
            <div
              className="absolute w-2 h-2 rounded-full"
              style={{
                background: "radial-gradient(circle, var(--amber) 0%, transparent 70%)",
                top: "-4px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 10px rgba(184,132,90,0.3)",
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
              border: "1px solid rgba(125,147,122,0.08)",
              transformStyle: "preserve-3d",
              animation: "orbit-2 18s linear infinite",
            }}
          >
            <div
              className="absolute w-1.5 h-1.5 rounded-full"
              style={{
                background: "radial-gradient(circle, var(--sage) 0%, transparent 70%)",
                top: "-3px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 8px rgba(125,147,122,0.3)",
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
              border: "1px solid rgba(184,132,90,0.07)",
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
                boxShadow: "0 0 6px rgba(232,196,116,0.3)",
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
              border: "1px solid rgba(168,149,126,0.06)",
              transformStyle: "preserve-3d",
              animation: "orbit-4 35s linear infinite",
            }}
          >
            <div
              className="absolute w-1.5 h-1.5 rounded-full"
              style={{
                background: "radial-gradient(circle, var(--dust) 0%, transparent 70%)",
                top: "-3px",
                left: "50%",
                transform: "translateX(-50%)",
                boxShadow: "0 0 8px rgba(168,149,126,0.25)",
              }}
            />
          </div>
        </div>
      </div>
    </div>
  )
}
