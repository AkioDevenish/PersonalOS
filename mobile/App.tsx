import { useEffect, useState } from "react"
import { StatusBar } from "expo-status-bar"
import { ActivityIndicator, StyleSheet, Text, View } from "react-native"
import { apiBaseUrl } from "./src/api/client"
import { METRIC_UNITS } from "./src/health/metrics"

/**
 * First screen — a build and connectivity check, not the product.
 *
 * It answers the two questions worth answering before any real UI exists: does
 * the app build and run on a device, and can it reach the backend it depends
 * on. A pretty screen that couldn't talk to the server would prove less.
 */

type Reachability =
  | { state: "checking" }
  | { state: "ok"; detail: string }
  | { state: "failed"; detail: string }

const INK = "#28200F"
const LINEN = "#F2EDE3"
const MID = "#6E5D45"
const DUST = "#A8957E"
const AMBER = "#B8845A"

export default function App() {
  const [api, setApi] = useState<Reachability>({ state: "checking" })

  useEffect(() => {
    let cancelled = false

    // Ingest requires auth, so a 401 is the *correct* answer here — and proves
    // more than a 200 would: the route exists, middleware ran, and it replied
    // as JSON rather than an HTML error page.
    fetch(`${apiBaseUrl}/api/health/ingest`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ provider: "apple_health", samples: [] }),
    })
      .then(async (res) => {
        if (cancelled) return
        const body = (await res.json().catch(() => null)) as { error?: string } | null
        setApi({
          state: "ok",
          detail:
            res.status === 401
              ? "Backend reachable · awaiting sign-in"
              : `Backend reachable · ${res.status}${body?.error ? ` ${body.error}` : ""}`,
        })
      })
      .catch((err) => {
        if (!cancelled) setApi({ state: "failed", detail: String(err?.message ?? err) })
      })

    return () => {
      cancelled = true
    }
  }, [])

  return (
    <View style={styles.container}>
      <View style={styles.disc}>
        <Text style={styles.discMark}>❧</Text>
      </View>

      <Text style={styles.title}>Personal OS</Text>
      <Text style={styles.tagline}>TIME WELL SPENT</Text>

      <View style={styles.rule} />

      <View style={styles.status}>
        {api.state === "checking" && (
          <>
            <ActivityIndicator color={AMBER} />
            <Text style={styles.statusText}>Checking the server…</Text>
          </>
        )}
        {api.state === "ok" && (
          <Text style={[styles.statusText, { color: MID }]}>{api.detail}</Text>
        )}
        {api.state === "failed" && (
          <Text style={[styles.statusText, { color: "#8C3B3B" }]}>
            Can’t reach the server{"\n"}
            {api.detail}
          </Text>
        )}
      </View>

      <Text style={styles.footnote}>
        {Object.keys(METRIC_UNITS).length} metrics · {apiBaseUrl.replace(/^https?:\/\//, "")}
      </Text>

      <StatusBar style="dark" />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: LINEN,
    alignItems: "center",
    justifyContent: "center",
    padding: 32,
  },
  disc: {
    width: 64,
    height: 64,
    borderRadius: 32,
    borderWidth: 1,
    borderColor: "rgba(40,32,15,0.18)",
    alignItems: "center",
    justifyContent: "center",
    marginBottom: 24,
  },
  discMark: { fontSize: 22, color: AMBER },
  title: { fontSize: 34, color: INK, fontWeight: "500" },
  tagline: { fontSize: 10, letterSpacing: 3, color: DUST, marginTop: 8 },
  rule: {
    height: 1,
    width: 120,
    backgroundColor: "rgba(40,32,15,0.18)",
    marginVertical: 28,
  },
  status: { alignItems: "center", gap: 10, minHeight: 52 },
  statusText: { fontSize: 13, color: DUST, textAlign: "center", lineHeight: 19 },
  footnote: {
    position: "absolute",
    bottom: 48,
    fontSize: 10,
    letterSpacing: 1.5,
    color: DUST,
  },
})
