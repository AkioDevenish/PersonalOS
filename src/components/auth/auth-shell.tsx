import Link from "next/link"
import a from "./auth.module.css"

/**
 * Framing for the auth routes: the engraved mark, an editorial title, and a
 * way back to the site. The Clerk component is rendered as the child.
 */
export default function AuthShell({
  title,
  tagline,
  children,
}: {
  title: React.ReactNode
  tagline: string
  children: React.ReactNode
}) {
  return (
    <div className={a.shell}>
      <div className={a.brand}>
        <Link href="/" aria-label="Personal OS — Home">
          <span className={a.disc}>
            <img className={a.mark} src="/story/time.jpg" alt="" />
          </span>
        </Link>
        <h1 className={a.title}>{title}</h1>
        <p className={a.tagline}>{tagline}</p>
        <div className={a.ornament} aria-hidden="true">
          <i /><b>❧</b><i />
        </div>
      </div>

      {children}

      <Link href="/" className={a.back}>
        ← Back to Personal OS
      </Link>
    </div>
  )
}
