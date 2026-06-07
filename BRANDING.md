# Personal OS Branding Guide

## Logo & Visual Identity

### Concept
The Personal OS logo features a **hand holding a vintage pocket watch** - symbolizing:
- ⏱️ **Time Management** - Making every moment count
- ✋ **Personal Control** - You're in charge of your time
- 🕰️ **Timeless Values** - Slow, intentional living
- 🎯 **Focus** - Time well spent, not time wasted

The hand-drawn aesthetic reinforces the calm, grounded, human-centered philosophy of the product.

---

## Logo Variations

### 1. Full Logo (`/public/logo.svg`)
**Use for:** Landing pages, marketing materials, documentation headers

**Dimensions:** 200x200px SVG (scales infinitely)

**Features:**
- Full hand illustration with fingers
- Detailed pocket watch face
- Watch chain
- Hour markers (showing 10:10 - the classic watch marketing time)
- Metallic gradient on watch body
- Warm skin tones

### 2. Logo Mark (`/public/icon.svg` + `LogoMark` component)
**Use for:** Favicons, app icons, navigation bars, buttons

**Dimensions:** 32x32px (optimized for small sizes)

**Features:**
- Simplified hand silhouette
- Clean pocket watch design
- Maintains recognizability at small sizes

### 3. Logo with Text (`Logo` component with `showText={true}`)
**Use for:** App headers, sidebars, email signatures

**Layout:** Logo mark + "Personal OS" + "Time Well Spent" tagline

---

## Color Palette

### Primary Colors

**Amber/Gold (Watch)**
```css
--amber: #C9A961        /* Main accent */
--amber-light: #E8C474  /* Highlights */
--amber-dark: #B8944D   /* Shadows */
```

**Warm Browns (Skin/Earth)**
```css
--deep-brown: #28200F   /* Text, UI elements */
--mid-brown: #6E5D45    /* Secondary text */
--dust: #A8957E         /* Muted text */
```

**Warm Neutrals (Backgrounds)**
```css
--linen: #F2EDE3        /* Base background */
--warm-white: #F9F6F0   /* Elevated surfaces */
--soft-warm: #F5EFE4    /* Hover states */
```

**Sage Green (Accent)**
```css
--sage: #7D937A         /* Secondary accent */
--sage-low: #C4D1BF     /* Subtle highlights */
```

### Color Usage

- **Primary Actions:** Amber (`--amber`)
- **Text:** Deep Brown (`--deep-brown`)
- **Backgrounds:** Linen shades
- **Success/Health:** Sage green
- **Watch Details:** Mix of amber and brown tones

---

## Typography

### Display Font
**Cormorant Garamond** (Serif, Italic for emphasis)
- Headers
- Brand name
- Feature titles
- Quotes

### Body Font
**Jost** (Sans-serif)
- Body text
- UI labels
- Buttons
- Forms

---

## Logo Components (React)

### Basic Usage

```tsx
import { Logo, LogoMark } from '@/components/ui/logo'

// Full logo with text
<Logo size={40} showText={true} />

// Icon only
<LogoMark size={32} />

// Large hero logo
<Logo size={80} showText={true} />
```

### Props

```typescript
interface LogoProps {
  size?: number          // Logo size in pixels
  className?: string     // Additional CSS classes
  showText?: boolean     // Show "Personal OS" text
}
```

---

## Icon Sizes & Formats

### Favicon
- **32x32** - Browser tab (`/icon`)
- **SVG** - Scalable vector (`/icon.svg`)

### Apple Touch Icon
- **180x180** - iOS home screen (`/apple-icon`)

### Open Graph
- **1200x630** - Social media previews (`/opengraph-image`)

### Manifest
- **Multiple sizes** - PWA installation (`/site.webmanifest`)

---

## Loading States

### Logo Animation
```tsx
import { Loading } from '@/components/ui/loading'

<Loading message="Loading your day..." size="lg" />
```

The logo rotates slowly (3s per rotation) with a subtle amber glow - reinforcing the "time" metaphor.

---

## Design Principles

### 1. **Warm & Grounded**
Use earth tones, natural textures, and organic shapes. Avoid harsh blacks and pure whites.

### 2. **Timeless Over Trendy**
The pocket watch represents enduring values. Avoid flashy effects or overly modern aesthetics.

### 3. **Human-Centered**
The hand in the logo reminds users this is a tool made by humans, for humans. Maintain warmth in all interactions.

### 4. **Calm & Intentional**
Slow animations (3s rotation, not 1s). Gentle transitions. Nothing jarring.

### 5. **Functional Beauty**
Like a well-crafted watch, every element should serve a purpose while being aesthetically pleasing.

---

## Usage Examples

### Navigation Header
```tsx
<header className="flex items-center gap-3 p-4">
  <LogoMark size={28} />
  <span className="font-display text-lg italic">Personal OS</span>
</header>
```

### Loading Screen
```tsx
<div className="flex items-center justify-center min-h-screen">
  <Loading message="Preparing your dashboard..." size="lg" />
</div>
```

### Brand Lockup
```tsx
<div className="text-center">
  <Logo size={60} showText={false} />
  <h1 className="font-display text-4xl mt-4">Personal OS</h1>
  <p className="text-sm uppercase tracking-wider text-dust mt-2">
    Time Well Spent
  </p>
</div>
```

---

## Don'ts

❌ Don't use the logo on busy backgrounds
❌ Don't change the logo colors (use provided gradients)
❌ Don't distort or stretch the logo
❌ Don't add drop shadows or effects
❌ Don't use the logo smaller than 16x16px
❌ Don't place text too close to the logo
❌ Don't use low-contrast color combinations

---

## File Structure

```
/public/
  ├── logo.svg              # Full detailed logo
  ├── icon.svg              # Simplified icon
  └── site.webmanifest      # PWA manifest

/src/app/
  ├── icon.tsx              # 32x32 favicon generator
  ├── apple-icon.tsx        # 180x180 Apple icon
  └── opengraph-image.tsx   # 1200x630 OG image

/src/components/ui/
  ├── logo.tsx              # Logo & LogoMark components
  └── loading.tsx           # Loading animation with logo
```

---

## Tagline

**"Time Well Spent"**

Use this tagline consistently across:
- Landing pages
- Email signatures
- Social media bios
- App descriptions
- Loading screens

---

## Voice & Tone

When describing the brand:
- ✅ "Calm, grounded space for your day"
- ✅ "Make every moment count"
- ✅ "Your personal operating system"
- ✅ "Slow, intentional living"
- ❌ "Maximize productivity" (too corporate)
- ❌ "Hustle harder" (antithetical to values)
- ❌ "Optimize everything" (too sterile)

---

## Implementation Checklist

- [x] Create full logo SVG
- [x] Create simplified icon SVG
- [x] Generate favicon (icon.tsx)
- [x] Generate Apple touch icon (apple-icon.tsx)
- [x] Generate OG image (opengraph-image.tsx)
- [x] Create Logo React components
- [x] Create Loading animation component
- [x] Update site metadata
- [x] Create web manifest
- [x] Add logo to sidebar
- [x] Add logo to landing page
- [x] Add spin-slow animation

---

## Next Steps

1. **Deploy to production** - Logo will appear in browser tabs, share previews
2. **Test PWA installation** - Verify app icon looks good on mobile
3. **Create marketing assets** - Use logo in social media headers, email templates
4. **Print collateral** - Business cards, stickers (logo works well in print)

---

**Questions?** The logo embodies the core philosophy: taking control of your time, one moment at a time. Like a pocket watch, it's personal, intentional, and timeless.
