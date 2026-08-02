import Link from "next/link"
import s from "@/components/marketing/marketing.module.css"
import sh from "@/components/shared.module.css"
import { FOOTER_GROUPS } from "./nav"

export default function SiteFooter() {
  return (
    <footer className={s.siteFooter}>
      <div className={s.footerGrid}>
        <div className={s.footerBrand}>
          <Link href="/" aria-label="Personal OS — Home" className={s.footerBrandLine}>
            <span className={sh.logoDisc}>
              <img className={sh.logoMark} src="/story/time.jpg" alt="" />
            </span>
            <span className={sh.logoText}>
              <span className={sh.logoName}>Personal OS</span>
              <span className={sh.logoTag}>Time Well Spent</span>
            </span>
          </Link>
          <p className={s.footerTagline}>
            The four currencies — time, vitality, connection, craft — kept in one place.
          </p>
        </div>

        {FOOTER_GROUPS.map((group) => (
          <div key={group.title}>
            <div className={s.footerColTitle}>{group.title}</div>
            <ul className={s.footerList}>
              {group.links.map((link) => (
                <li key={link.label}>
                  <Link href={link.href} className={s.footerLink}>
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        ))}

        <div>
          <div className={s.footerColTitle}>Social</div>
          <div className={s.footerSocial}>
            <a href="https://x.com" target="_blank" rel="noopener noreferrer" aria-label="X">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M4 4l11.733 16h4.267l-11.733 -16z" />
                <path d="M4 20l6.768 -6.768m2.46 -2.46L20 4" />
              </svg>
            </a>
            <a href="https://youtube.com" target="_blank" rel="noopener noreferrer" aria-label="YouTube">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M2 8a4 4 0 0 1 4 -4h12a4 4 0 0 1 4 4v8a4 4 0 0 1 -4 4H6a4 4 0 0 1 -4 -4V8z" />
                <path d="M10 9l5 3l-5 3V9z" />
              </svg>
            </a>
          </div>
        </div>
      </div>

      <div className={s.footerBottom}>
        <p className={s.footerNote}>
          &copy; {new Date().getFullYear()} Personal OS — all rights reserved
        </p>
        <div className={s.footerLegal}>
          <Link href="/privacy" className={s.footerNote}>Privacy</Link>
          <Link href="/terms" className={s.footerNote}>Terms</Link>
        </div>
      </div>
    </footer>
  )
}
