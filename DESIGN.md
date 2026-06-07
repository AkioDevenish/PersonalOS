# Personal OS — Design System
## Command Center for Life, Work & Health

---

## 1. Philosophy

**Bento Intelligence.** A warm, breathable interface that surfaces signal without noise. Every pixel earns its place. Data is ambient, actionable, and alive. The UI feels like a premium financial dashboard crossed with a personal command center.

**Core Principles:**
- **Clarity over decoration** — Every element communicates state or action
- **Density with breath** — Information-rich but never cramped
- **Motion with purpose** — Transitions guide attention, never distract
- **Color as information** — Accents encode meaning; neutrals recede

---

## 2. Color System

### 2.1 Neutral Palette (Warm Light Mode)

| Token | Hex | Usage |
|-------|-----|-------|
| `bg-base` | `#F0EFEA` | Page background — warm parchment tone |
| `bg-elevated` | `#FFFFFF` | Cards, modals, popovers |
| `bg-hover` | `#F5F4F0` | Hover states on elevated surfaces |
| `bg-active` | `#EDECE8` | Active/selected states |
| `bg-sunken` | `#E8E7E3` | Input fields, nested containers |
| `border-subtle` | `#E2E4EA` | Card borders, dividers |
| `border-strong` | `#D1D5DB` | Focus rings, active borders |
| `border-hover` | `#C4C8D0` | Hover borders |

### 2.2 Text Palette

| Token | Hex | Contrast | Usage |
|-------|-----|----------|-------|
| `text-primary` | `#1A1A1A` | AAA | Headings, primary data, labels |
| `text-secondary` | `#5E5E5E` | AA | Body text, descriptions |
| `text-muted` | `#8B8B8B` | AA Large | Timestamps, placeholders, disabled |
| `text-inverse` | `#FFFFFF` | — | Text on accent backgrounds |

### 2.3 Semantic Accents

| Token | Hex | RGB | Usage | WCAG on White |
|-------|-----|-----|-------|---------------|
| `accent-coral` | `#E8553D` | `232, 85, 61` | Primary CTA, progress, active states | ✅ AA |
| `accent-coral-light` | `#FEF2F0` | — | Coral tint backgrounds | — |
| `accent-coral-dark` | `#C43A24` | — | Hover/pressed coral | — |
| `accent-ds` | `#6366F1` | `99, 102, 241` | Data Science spoke | ✅ AA |
| `accent-health` | `#06B6D4` | `6, 182, 212` | Well-Being spoke | ✅ AA |
| `accent-biz` | `#F59E0B` | `245, 158, 11` | Business spoke | ✅ AA Large |
| `accent-mkt` | `#EC4899` | `236, 72, 153` | Marketing spoke | ✅ AA |
| `accent-success` | `#22C55E` | `34, 197, 94` | Positive states, online | ✅ AA |
| `accent-warning` | `#EAB308` | `234, 179, 8` | Caution, pending | ✅ AA Large |
| `accent-danger` | `#EF4444` | `239, 68, 68` | Errors, lost deals | ✅ AA |

### 2.4 Spoke Color Families (Data Viz)

Each spoke has a **primary**, **light tint**, and **dark variant** for chart gradients:

```
Data Science:    Primary #6366F1  Light #E0E7FF  Dark #4338CA
Well-Being:      Primary #06B6D4  Light #CFFAFE  Dark #0891B2
Business:        Primary #F59E0B  Light #FEF3C7  Dark #D97706
Marketing:       Primary #EC4899  Light #FCE7F3  Dark #BE185D
```

### 2.5 Chart Sequential Palettes

For single-spoke charts requiring gradient scales:

**Coral Sequential (Primary metric gradients):**
`#FEF2F0 → #FBCFC8 → #F7ADA1 → #F38A7B → #E8553D → #D14A32 → #B93F28 → #A1341E`

**Indigo Sequential (Data Science):**
`#E0E7FF → #C7D2FE → #A5B4FC → #818CF8 → #6366F1 → #4F46E5 → #4338CA → #3730A3`

**Teal Sequential (Well-Being):**
`#CFFAFE → #A5F3FC → #67E8F9 → #22D3EE → #06B6D4 → #0891B2 → #0E7490 → #155E75`

**Amber Sequential (Business):**
`#FEF3C7 → #FDE68A → #FCD34D → #FBBF24 → #F59E0B → #D97706 → #B45309 → #92400E`

**Pink Sequential (Marketing):**
`#FCE7F3 → #FBCFE8 → #F9A8D4 → #F472B6 → #EC4899 → #DB2777 → #BE185D → #9D174D`

### 2.6 Dark Mode (Future)

| Token | Hex |
|-------|-----|
| `bg-base-dark` | `#0F0F12` |
| `bg-elevated-dark` | `#1A1A1F` |
| `bg-hover-dark` | `#25252C` |
| `border-subtle-dark` | `#2A2A32` |
| `text-primary-dark` | `#F0F0F5` |
| `text-secondary-dark` | `#A0A0B0` |

---

## 3. Typography

### 3.1 Type Scale

| Token | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| `display` | 32px | 700 | 1.1 | -0.02em | Page titles, big numbers |
| `heading-lg` | 24px | 600 | 1.2 | -0.01em | Section headers |
| `heading-md` | 18px | 600 | 1.3 | 0 | Card titles |
| `heading-sm` | 14px | 600 | 1.4 | 0 | Subsection labels |
| `body` | 13px | 400 | 1.5 | 0 | Body text, descriptions |
| `body-sm` | 12px | 400 | 1.5 | 0 | Compact text, metadata |
| `caption` | 11px | 500 | 1.4 | 0.02em | Labels, badges, timestamps |
| `micro` | 10px | 600 | 1.3 | 0.04em | Axis labels, tiny data |

### 3.2 Font Stack

```css
--font-sans: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
--font-mono: "JetBrains Mono", "SF Mono", "Fira Code", monospace;
--font-display: "Inter", sans-serif; /* Future: "Space Grotesk" or "DM Sans" */
```

**Load strategy:** Preload Inter regular (400), medium (500), semibold (600), bold (700).

---

## 4. Spacing System

Base unit: **4px**

| Token | Value | Usage |
|-------|-------|-------|
| `space-1` | 4px | Tight gaps, icon padding |
| `space-2` | 8px | Inline spacing, small gaps |
| `space-3` | 12px | Card internal padding (compact) |
| `space-4` | 16px | Standard card padding |
| `space-5` | 24px | Section gaps |
| `space-6` | 32px | Major section separation |
| `space-8` | 48px | Page-level margins |

### 4.1 Grid

- **Bento grid:** 12-column, gap-4 (16px)
- **Metric cards:** col-span-3 (quarter width)
- **Wide cards:** col-span-6 (half width)
- **Full cards:** col-span-12
- **Content max-width:** None (full fluid bento)
- **Page padding:** 24px horizontal, 24px vertical

---

## 5. Shape & Elevation

### 5.1 Border Radius

| Token | Value | Usage |
|-------|-------|-------|
| `radius-sm` | 8px | Buttons, inputs, small chips |
| `radius-md` | 12px | Navigation items, badges |
| `radius-lg` | 16px | Cards, containers |
| `radius-xl` | 24px | Modals, large panels |
| `radius-full` | 9999px | Pills, avatars, circles |

### 5.2 Shadows

| Token | Value | Usage |
|-------|-------|-------|
| `shadow-sm` | `0 1px 3px rgba(0,0,0,0.04)` | Subtle elevation |
| `shadow-md` | `0 4px 12px rgba(0,0,0,0.06)` | Cards at rest |
| `shadow-lg` | `0 8px 24px rgba(0,0,0,0.08)` | Hover lift, modals |
| `shadow-xl` | `0 12px 40px rgba(0,0,0,0.12)` | Dropdowns, popovers |
| `shadow-glow-coral` | `0 0 20px rgba(232,85,61,0.15)` | Active coral elements |

### 5.3 Elevation States

```
Rest:     shadow-md, translateY(0)
Hover:    shadow-lg, translateY(-1px), border-strong
Active:   shadow-sm, translateY(0), bg-active
Disabled: shadow-none, opacity 0.5, pointer-events none
```

---

## 6. Data Visualization

### 6.1 Chart Color Assignments

**Overview Dashboard:**
- Steps: `accent-health` (#06B6D4)
- Projects: `accent-ds` (#6366F1)
- Pipeline: `accent-biz` (#F59E0B)
- Posts: `accent-mkt` (#EC4899)
- Progress ring: `accent-coral` (#E8553D)
- Activity dots: `accent-coral` (active), `border-subtle` (inactive)

**Data Science:**
- Primary: `accent-ds` (#6366F1)
- Secondary: `#818CF8` (lighter indigo)
- Tertiary: `#A5B4FC`
- Positive: `accent-success`
- Negative: `accent-danger`

**Well-Being:**
- Steps: `accent-health` (#06B6D4)
- Distance: `accent-ds` (#6366F1)
- Flights: `accent-biz` (#F59E0B)
- Speed: `accent-mkt` (#EC4899)
- Sleep: `#8B5CF6` (violet)

**Business:**
- Prospect: `#CBD5E1` (slate-300)
- Call Booked: `#94A3B8` (slate-400)
- Proposal: `accent-biz` (#F59E0B)
- Client: `accent-success` (#22C55E)
- Lost: `accent-danger` (#EF4444)

**Marketing:**
- LinkedIn: `#0A66C2` (brand)
- Twitter: `#1DA1F2` (brand)
- Instagram: `#E4405F` (brand)
- Generated: `accent-coral` (#E8553D)

### 6.2 Chart Specifications

**Bar Charts:**
- Bar radius: 4px (top only for vertical)
- Gap between bars: 4px
- Bar hover: opacity 1.0 from 0.7, `shadow-sm`
- Animation: `scaleY` from 0, duration 400ms, easing `cubic-bezier(0.4, 0, 0.2, 1)`
- Max bar width: 48px

**Line Charts:**
- Stroke width: 2.5px
- Line cap: round
- Area fill: gradient to transparent, 15% opacity
- Point radius: 4px rest, 6px hover
- Point fill: white with 2px stroke of line color
- Animation: `stroke-dashoffset`, 800ms

**Pie / Donut Charts:**
- Donut hole: 60% of radius
- Segment gap: 2px
- Hover: segment expands 4px outward
- Label: outside, 12px, `text-secondary`

**Progress Rings:**
- Background track: `border-subtle`, 6px stroke
- Progress: `accent-coral`, 6px stroke, round cap
- Size: 64px default, 96px for featured
- Animation: `stroke-dasharray`, 600ms, ease-out

**Activity Heatmap (Dot Grid):**
- Dot size: 20px × 20px
- Dot radius: 4px
- Active: `accent-coral`
- Inactive: `border-subtle`
- Hover: scale(1.15), tooltip with date
- Gap: 6px

**Funnel Bars:**
- Each step 12px narrower than previous (visual taper)
- Color: sequential from light to dark within spoke palette
- Labels: left-aligned, 12px, `text-secondary`

### 6.3 Tooltip Design

```
Background: bg-elevated
Border: 1px border-subtle
Border-radius: radius-md (12px)
Padding: space-3 (12px) vertical, space-4 (16px) horizontal
Shadow: shadow-lg
Text: caption (11px) for label, body (13px) for value
Arrow: 6px, same background, no border
```

### 6.4 Axis & Grid

- Grid lines: 1px, `#E2E4EA`, dashed or solid (subtle)
- Axis labels: `caption` (11px), `text-muted`
- Axis title: `caption` (11px), uppercase, `text-secondary`
- Tick length: 0 (clean look) or 4px
- Zero line: 1px solid, `border-strong`

---

## 7. Components

### 7.1 Card (Bento)

```
Background: bg-elevated (#FFFFFF)
Border: 1px solid border-subtle (#E2E4EA)
Border-radius: radius-lg (16px)
Padding: space-4 (16px)
Shadow: shadow-sm (rest), shadow-md (hover)
Transition: all 200ms ease
```

**Variants:**
- `default` — standard white card
- `active` — top border 2px with accent color, slight glow
- `alert` — left border 3px danger red
- `bento` — hover lift with shadow-md

### 7.2 Metric Card

```
Layout: vertical stack
Label: caption (11px), uppercase, text-muted, letter-spacing 0.05em
Value: display (32px) or heading-lg (24px), text-primary, font-weight 700
Delta: body-sm (12px), success/danger color, with arrow icon
Icon: 20px, top-right, opacity 0.15 background circle
```

### 7.3 Button

**Primary (Coral):**
```
Background: accent-coral (#E8553D)
Text: text-inverse (#FFFFFF), body (13px), font-weight 500
Padding: 10px 20px
Border-radius: radius-full (pill)
Hover: brightness(1.1), shadow-md
Active: brightness(0.95), translateY(0)
Disabled: opacity 0.4
```

**Secondary:**
```
Background: bg-elevated
Border: 1px border-subtle
Text: text-primary
Hover: bg-hover, border-strong
```

**Ghost:**
```
Background: transparent
Text: text-secondary
Hover: bg-hover
```

### 7.4 Input / Select

```
Background: bg-base (#F0EFEA) or bg-sunken (#E8E7E3)
Border: 1px border-subtle
Border-radius: radius-sm (8px)
Padding: 10px 14px
Text: body (13px), text-primary
Placeholder: text-muted
Focus: border-strong, shadow-glow-coral (0 0 0 3px rgba(232,85,61,0.1))
Transition: border-color 150ms, box-shadow 150ms
```

### 7.5 Badge / Chip

```
Padding: 4px 10px
Border-radius: radius-full
Text: caption (11px), font-weight 500

Status variants:
- success: bg #DCFCE7, text #166534
- warning: bg #FEF9C3, text #854D0E
- danger: bg #FEE2E2, text #991B1B
- info: bg #DBEAFE, text #1E40AF
- coral: bg #FEF2F0, text #C43A24
```

### 7.6 Avatar

```
Sizes: 32px (small), 40px (default), 48px (large)
Border-radius: radius-full
Border: 2px solid bg-elevated (for overlapping)
Fallback: bg-hover, text-secondary, font-weight 600
```

---

## 8. Animation & Motion

### 8.1 Principles
- **Duration:** Fast (150ms) for micro-interactions, medium (300ms) for transitions, slow (600ms) for page loads
- **Easing:** `cubic-bezier(0.4, 0, 0.2, 1)` for enter, `cubic-bezier(0.4, 0, 1, 1)` for exit
- **Stagger:** 50ms between list items, 100ms between grid items
- **Performance:** Only animate `transform` and `opacity`

### 8.2 Specific Patterns

**Card Hover:**
```
Rest:  translateY(0), shadow-sm
Hover: translateY(-2px), shadow-md, 200ms ease
```

**Number Count-Up:**
```
Duration: 800ms
Easing: ease-out
Trigger: On mount or data refresh
```

**Progress Ring Fill:**
```
Duration: 600ms
Easing: cubic-bezier(0.4, 0, 0.2, 1)
Stroke-dasharray animation
```

**Bar Chart Grow:**
```
Duration: 400ms per bar
Stagger: 80ms
Easing: cubic-bezier(0.4, 0, 0.2, 1)
Property: scaleY from 0 to 1, transform-origin: bottom
```

**Page Transition:**
```
Enter: opacity 0 → 1, translateY(8px) → 0, 300ms
Exit: opacity 1 → 0, 150ms
```

**Skeleton Loading:**
```
Background: linear-gradient(90deg, bg-hover 25%, bg-elevated 50%, bg-hover 75%)
Background-size: 200% 100%
Animation: shimmer 1.5s infinite linear
```

### 8.3 Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## 9. Layout Patterns

### 9.1 Shell

```
Sidebar:  200px width, bg-base, border-right border-subtle
Header:   64px height, bg-base, border-bottom border-subtle
Content:  flex-1, overflow-auto, p-6 (24px)
```

### 9.2 Bento Grid Templates

**Overview (12-col):**
```
Row 1: [Date/Greeting - 4col] [empty - 8col]
Row 2: [Metric - 3] [Metric - 3] [Metric - 3] [Metric - 3]
Row 3: [Activity - 4] [Progress - 3] [System - 5]
Row 4: [Rituals - 6] [Recent - 6]
```

**Spoke View:**
```
Row 1: [KPI - 3] [KPI - 3] [KPI - 3] [KPI - 3]
Row 2: [Main Chart - 8] [Side Panel - 4]
Row 3: [Table/Forms - 12]
```

### 9.3 Responsive Breakpoints

| Name | Width | Behavior |
|------|-------|----------|
| `sm` | 640px | Stack bento to single column, sidebar collapses |
| `md` | 768px | 2-column bento, sidebar icons only |
| `lg` | 1024px | Full 12-col bento, full sidebar |
| `xl` | 1280px | Max content width, larger padding |

---

## 10. Accessibility

### 10.1 Contrast Requirements
- All text on white: Minimum AA (4.5:1)
- Large text (18px+): Minimum AA Large (3:1)
- Coral on white: 4.6:1 ✅ AA
- All spoke accents on white: AA or AA Large ✅

### 10.2 Focus States
```
Outline: 2px solid accent-coral
Outline-offset: 2px
Border-radius: matches element
```

### 10.3 Screen Reader
- All charts: `role="img"` with `aria-label` describing the data
- Icons in buttons: `aria-hidden="true"` with button `aria-label`
- Color-only info: Accompanied by text or pattern
- Live regions: For toast notifications and async updates

### 10.4 Keyboard Navigation
- Tab order follows visual order
- Enter/Space activates buttons and cards
- Arrow keys navigate within lists and grids
- Escape closes modals and dropdowns

---

## 11. Iconography

**Library:** Lucide React
**Size scale:** 16px (inline), 20px (buttons), 24px (navigation)
**Stroke width:** 1.5px default, 2px for emphasis
**Color:** Inherit from parent or explicit accent

**Spoke Icons:**
- Overview: `LayoutDashboard`
- Data Science: `BarChart3`
- Well-Being: `HeartPulse`
- Business: `Briefcase`
- Marketing: `Megaphone`

---

## 12. Assets

### 12.1 Logo
- **Primary:** Rocket emoji 🚀 (temporary)
- **Future:** Custom mark — abstract "OS" monogram or orbit rings
- **Size:** 24px in sidebar, 32px standalone

### 12.2 User Avatar
- Default: Initials on `bg-hover` circle
- Upload: 128×128px minimum, JPG/PNG, cropped to circle

---

## 13. Implementation Notes

### 13.1 CSS Custom Properties
All design tokens available as CSS variables:
```css
:root {
  --bg-base: #F0EFEA;
  --bg-elevated: #FFFFFF;
  --accent-coral: #E8553D;
  /* ... etc */
}
```

### 13.2 Tailwind Config
Extend Tailwind with design tokens via `@theme inline` (Tailwind v4) or `theme.extend` (v3).

### 13.3 Component Tokens
Prefer semantic tokens over raw values:
- ✅ `bg-[var(--bg-elevated)]`
- ❌ `bg-white`

This enables instant theme switching (light/dark/future).

---

## 14. Spoke-Specific Patterns

### 14.1 Data Science
- Project cards: Status dot (4px) + name + tech stack badges
- Tracker table: Sortable, striped rows, hover highlight
- Deployed badge: Green dot + external link icon

### 14.2 Well-Being
- Health metrics: Large number + sparkline mini-chart
- AI reports: Sparkle icon + quote-style block
- Charts: 4-up grid, each with colored header bar

### 14.3 Business
- Pipeline funnel: Tapered bars, left labels
- Contact table: Avatar circle (initials) + name + status badge
- Forms: Collapsible cards with chevron toggle
- Status badges: `prospect` (slate), `call_booked` (blue), `proposal` (amber), `client` (green), `lost` (red)

### 14.4 Marketing
- Post generator: Loading spinner + "Generating via Ollama..."
- Post cards: Platform icon + date + content preview
- Stats: Donut chart for platform breakdown

---

*Version 2.0 — Bento Dashboard Redesign*
*Last updated: 2026-05-13*
