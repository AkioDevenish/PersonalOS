export const NAV_ITEMS = [
  { href: "/about", label: "About Us" },
  { href: "/how-it-works", label: "How it works" },
  { href: "/pricing", label: "Pricing" },
  { href: "/news", label: "News" },
]

// Privacy/Terms live only in the footer's bottom bar — not duplicated above it
export const FOOTER_GROUPS = [
  { title: "Product", links: NAV_ITEMS },
  {
    title: "Careers",
    links: [
      { href: "https://x.com", label: "We're Hiring" },
      { href: "mailto:careers@personalos.com", label: "Contact HR" },
    ],
  },
]
