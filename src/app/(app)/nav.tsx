/** The five pages, in the sidebar's order (AppTab.visible in ios/Forklore/RootView.swift). */
export const PAGES = [
  { href: "/meals", title: "Meals", icon: "leaf" },
  { href: "/pitchfork", title: "Pitchfork", icon: "sparkles" },
  { href: "/read", title: "Read", icon: "book" },
  { href: "/experts", title: "Experts", icon: "people" },
  { href: "/profile", title: "Profile", icon: "person" },
] as const

export type IconName = (typeof PAGES)[number]["icon"] | "menu" | "close" | "plus" | "send" | "back" | "history"

/** Thin line icons, drawn rather than fetched. */
export function Icon({ name, size = 18 }: { name: IconName; size?: number }) {
  const paths: Record<IconName, React.ReactNode> = {
    leaf: <path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14H5zm0 0 8-8" />,
    sparkles: (
      <>
        <path d="M12 3v4M12 17v4M3 12h4M17 12h4" />
        <path d="M12 8.5 13.2 11l2.3 1-2.3 1L12 15.5 10.8 13l-2.3-1 2.3-1z" />
      </>
    ),
    book: <path d="M4 5.5C4 4.7 4.7 4 5.5 4H11v15H5.5C4.7 19 4 18.3 4 17.5zM20 5.5c0-.8-.7-1.5-1.5-1.5H13v15h5.5c.8 0 1.5-.7 1.5-1.5z" />,
    people: (
      <>
        <circle cx="9" cy="8.5" r="3" />
        <path d="M3.5 19c.6-3 2.8-4.5 5.5-4.5s4.9 1.5 5.5 4.5" />
        <circle cx="16.5" cy="9.5" r="2.4" />
        <path d="M16 14.6c2.2 0 3.9 1.3 4.5 3.9" />
      </>
    ),
    person: (
      <>
        <circle cx="12" cy="12" r="8.5" />
        <circle cx="12" cy="10" r="2.8" />
        <path d="M6.8 18c1.1-2 3-3 5.2-3s4.1 1 5.2 3" />
      </>
    ),
    menu: <path d="M4 7h16M4 12h11M4 17h14" />,
    close: <path d="M6 6l12 12M18 6 6 18" />,
    plus: <path d="M12 5v14M5 12h14" />,
    send: <path d="M12 19V6M6.5 11.5 12 6l5.5 5.5" />,
    back: <path d="M14.5 5.5 8 12l6.5 6.5" />,
    history: (
      <>
        <path d="M4.5 12a7.5 7.5 0 1 0 2.2-5.3L4.5 9" />
        <path d="M4.5 4.5V9H9M12 8v4l3 2" />
      </>
    ),
  }
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {paths[name]}
    </svg>
  )
}
