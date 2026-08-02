import s from "./marketing.module.css"
import sh from "../shared.module.css"

/**
 * The opening of every marketing page: kicker, title, optional lede.
 * Title accepts nodes so pages can italicise a clause with <em>.
 */
export default function PageHero({
  kicker,
  title,
  lede,
}: {
  kicker: string
  title: React.ReactNode
  lede?: React.ReactNode
}) {
  return (
    <section className={`${s.pageSection} ${s.pageHero}`}>
      <p className={`${s.sectionKicker} ${sh.reveal}`}>{kicker}</p>
      <h1 className={`${s.sectionTitle} ${sh.reveal}`}>{title}</h1>
      {lede && <p className={`${s.lede} ${sh.reveal}`}>{lede}</p>}
    </section>
  )
}
