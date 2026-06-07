import { NextResponse } from 'next/server'
import { exec } from 'child_process'
import { promisify } from 'util'

const execAsync = promisify(exec)

const ACTIVITY_SCRIPT = '/Users/akio/personal_os/Well Being/health/activity_sync.py'
const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://127.0.0.1:3000'

export async function POST() {
  try {
    // 1. Sync local Mac ActivityWatch data
    await execAsync(`python3 "${ACTIVITY_SCRIPT}"`, { timeout: 30000 }).catch(e => console.error(e))
    
    // 2. Trigger all due Signal Intelligence reports in the background.
    // We do NOT await this because running local LLMs can take a while and we don't want to freeze the UI.
    fetch(`${APP_URL}/api/well-being/analyze`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ auto: true, background: true }),
    }).catch(e => console.error('Background AI sync failed:', e))

    return NextResponse.json({
      success: true,
      message: 'Activity sync complete. Due signal reports started in background.',
      timestamp: new Date().toISOString(),
    })
  } catch (error: any) {
    console.error('Health sync failed:', error)
    return NextResponse.json({
      success: false,
      error: error.message || 'Failed to sync health data',
      stderr: error.stderr || null,
    }, { status: 500 })
  }
}
