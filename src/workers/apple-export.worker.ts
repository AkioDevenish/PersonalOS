/// <reference lib="webworker" />
import { unzip } from "fflate"
import {
  scanRecords,
  toCanonical,
  dayKeyLocal,
  foldDaily,
  type DailyBucket,
} from "@/lib/health/apple-export"

/**
 * Parses an Apple Health export entirely inside the browser.
 *
 * The raw file never leaves the machine — only the rolled-up measurements are
 * posted. That is both the privacy story and a practical necessity: these
 * exports run to hundreds of megabytes and a serverless request body caps out
 * around 4.5MB.
 *
 * Runs in a worker so a multi-hundred-megabyte parse doesn't freeze the tab.
 */

type InMessage = { file: File; timeZone: string }
type OutMessage =
  | { kind: "progress"; phase: string; recordsSeen: number; pct: number | null }
  | { kind: "done"; samples: { metric: string; value: number; unit: string; recorded_at: number }[]; recordsSeen: number; skipped: number }
  | { kind: "error"; message: string }

const post = (m: OutMessage) => (self as unknown as Worker).postMessage(m)

async function readXmlFromZip(file: File): Promise<Uint8Array> {
  const buf = new Uint8Array(await file.arrayBuffer())
  return await new Promise((resolve, reject) => {
    unzip(buf, (err, files) => {
      if (err) return reject(err)
      // export.xml sits under a folder, and export_cda.xml is a different,
      // much smaller clinical format we don't want
      const key = Object.keys(files).find(
        (k) => k.endsWith("export.xml") && !k.includes("cda"),
      )
      if (!key) return reject(new Error("No export.xml inside the zip"))
      resolve(files[key])
    })
  })
}

self.onmessage = async (event: MessageEvent<InMessage>) => {
  const { file, timeZone } = event.data

  try {
    let bytes: Uint8Array
    let total: number

    if (file.name.toLowerCase().endsWith(".zip")) {
      post({ kind: "progress", phase: "Unzipping export…", recordsSeen: 0, pct: null })
      bytes = await readXmlFromZip(file)
      total = bytes.byteLength
    } else {
      bytes = new Uint8Array(await file.arrayBuffer())
      total = bytes.byteLength
    }

    post({ kind: "progress", phase: "Reading records…", recordsSeen: 0, pct: 0 })

    const decoder = new TextDecoder("utf-8")
    const buckets = new Map<string, DailyBucket>()
    let recordsSeen = 0
    let skipped = 0
    let rest = ""

    // 4MB slices: large enough to be fast, small enough to report progress
    const CHUNK = 4 * 1024 * 1024

    for (let offset = 0; offset < total; offset += CHUNK) {
      const slice = bytes.subarray(offset, Math.min(offset + CHUNK, total))
      // stream:true so a multi-byte character split across chunks survives
      const text = rest + decoder.decode(slice, { stream: true })
      const { records, rest: leftover } = scanRecords(text)
      rest = leftover

      for (const record of records) {
        recordsSeen++
        const point = toCanonical(record)
        if (!point) {
          skipped++
          continue
        }
        const day = dayKeyLocal(point.recorded_at, timeZone)
        const key = `${point.metric}|${day}`
        const existing = buckets.get(key)
        if (existing) existing.values.push(point.value)
        else buckets.set(key, { metric: point.metric, unit: point.unit, day, values: [point.value] })
      }

      post({
        kind: "progress",
        phase: "Reading records…",
        recordsSeen,
        pct: Math.min(99, Math.round(((offset + CHUNK) / total) * 100)),
      })
    }

    post({ kind: "progress", phase: "Summarising by day…", recordsSeen, pct: 100 })
    const samples = foldDaily(buckets)
    post({ kind: "done", samples, recordsSeen, skipped })
  } catch (error) {
    post({
      kind: "error",
      message: error instanceof Error ? error.message : "Could not read that file",
    })
  }
}
