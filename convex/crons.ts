import { cronJobs } from "convex/server"
import { internal } from "./_generated/api"

const crons = cronJobs()

// Subscriptions end on their own clock, not when somebody next opens the app.
crons.interval("expire lapsed subscriptions", { minutes: 15 }, internal.billing.entitlements.expireLapsed, {})

// Call signalling is only needed while two phones are connecting.
crons.interval("sweep old call signalling", { hours: 6 }, internal.health.signal.sweep, {})

export default crons
