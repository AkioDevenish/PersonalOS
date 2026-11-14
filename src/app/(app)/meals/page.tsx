import type { Metadata } from "next"
import { Meals } from "./meals"

export const metadata: Metadata = { title: "Meals · Forklore" }

export default function MealsPage() {
  return <Meals />
}
