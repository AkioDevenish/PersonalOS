/**
 * Migration Script: SQLite → Convex
 * 
 * Migrates data from your existing SQLite databases to Convex
 * 
 * Usage:
 *   npx ts-node scripts/migrate-sqlite-to-convex.ts
 */

import Database from 'better-sqlite3'
import { ConvexHttpClient } from "convex/browser"
import { api } from "../convex/_generated/api"
import * as path from 'path'
import * as os from 'os'

const CONVEX_URL = process.env.NEXT_PUBLIC_CONVEX_URL || 'http://127.0.0.1:3210'
const client = new ConvexHttpClient(CONVEX_URL)

const HOME = os.homedir()
const CRM_DB = path.join(HOME, 'personal_os/Business/data/crm.db')
const MARKETING_DB = path.join(HOME, 'personal_os/Market/data/marketing.db')
const HEALTH_DB = path.join(HOME, 'personal_os/Well Being/data/health.db')

async function migrateContacts() {
  console.log('\n📋 Migrating Business Contacts...')
  
  try {
    const db = new Database(CRM_DB, { readonly: true })
    const contacts = db.prepare('SELECT * FROM contacts').all() as any[]
    db.close()

    console.log(`Found ${contacts.length} contacts`)
    
    let migrated = 0
    for (const contact of contacts) {
      try {
        await client.mutation(api.business.addContact, {
          name: contact.name,
          email: contact.email || undefined,
          phone: contact.phone || undefined,
          company: contact.company || undefined,
          status: contact.status || 'prospect',
          notes: contact.notes || undefined,
        })
        migrated++
        process.stdout.write(`\r  Migrated: ${migrated}/${contacts.length}`)
      } catch (error) {
        console.error(`\n  Failed to migrate contact ${contact.name}:`, error)
      }
    }
    
    console.log(`\n✅ Migrated ${migrated} contacts`)
  } catch (error) {
    console.error('❌ Failed to migrate contacts:', error)
  }
}

async function migrateInteractions() {
  console.log('\n📋 Migrating Business Interactions...')
  
  try {
    const db = new Database(CRM_DB, { readonly: true })
    const interactions = db.prepare('SELECT * FROM interactions').all() as any[]
    db.close()

    console.log(`Found ${interactions.length} interactions`)
    console.log('⚠️  Skipping interactions (need to map contact IDs from old to new)')
    // To properly migrate, we'd need to maintain a mapping of old SQLite IDs to new Convex IDs
  } catch (error) {
    console.error('❌ Failed to check interactions:', error)
  }
}

async function migratePosts() {
  console.log('\n📝 Migrating Marketing Posts...')
  
  try {
    const db = new Database(MARKETING_DB, { readonly: true })
    const posts = db.prepare('SELECT * FROM posts').all() as any[]
    db.close()

    console.log(`Found ${posts.length} posts`)
    
    let migrated = 0
    for (const post of posts) {
      try {
        await client.mutation(api.marketing.addPost, {
          content: post.content,
          platform: post.platform || 'linkedin',
          topic: post.topic || undefined,
          mood: post.mood || undefined,
          bullets: post.bullets || undefined,
          published: Boolean(post.published),
        })
        migrated++
        process.stdout.write(`\r  Migrated: ${migrated}/${posts.length}`)
      } catch (error) {
        console.error(`\n  Failed to migrate post:`, error)
      }
    }
    
    console.log(`\n✅ Migrated ${migrated} posts`)
  } catch (error) {
    console.error('❌ Failed to migrate posts:', error)
  }
}

async function migrateHealthRecords() {
  console.log('\n💪 Migrating Health Records...')
  
  try {
    const db = new Database(HEALTH_DB, { readonly: true })
    const records = db.prepare('SELECT * FROM health_records').all() as any[]
    db.close()

    console.log(`Found ${records.length} health records`)
    
    if (records.length === 0) {
      console.log('  No records to migrate')
      return
    }

    // Batch insert for efficiency
    const batchSize = 50
    let migrated = 0
    
    for (let i = 0; i < records.length; i += batchSize) {
      const batch = records.slice(i, i + batchSize)
      
      try {
        await client.mutation(api.wellbeing.syncHealthData, {
          records: batch.map(r => ({
            timestamp: new Date(r.date || r.timestamp).getTime(),
            steps: r.steps || undefined,
            distance: r.distance || r.distance_km || undefined,
            flights_climbed: r.flights_climbed || undefined,
            walking_speed: r.walking_speed || undefined,
            walking_steadiness: r.walking_steadiness || undefined,
            source: r.source || r.source_file || undefined,
          }))
        })
        
        migrated += batch.length
        process.stdout.write(`\r  Migrated: ${migrated}/${records.length}`)
      } catch (error) {
        console.error(`\n  Failed to migrate batch:`, error)
      }
    }
    
    console.log(`\n✅ Migrated ${migrated} health records`)
  } catch (error) {
    console.error('❌ Failed to migrate health records:', error)
  }
}

async function migrateActivityTracking() {
  console.log('\n📱 Migrating Activity Tracking...')
  
  try {
    const db = new Database(HEALTH_DB, { readonly: true })
    const activities = db.prepare('SELECT * FROM activity_tracking').all() as any[]
    db.close()

    console.log(`Found ${activities.length} activity records`)
    
    let migrated = 0
    for (const activity of activities) {
      try {
        await client.mutation(api.wellbeing.addActivityTracking, {
          date: activity.date,
          screen_time: activity.screen_time,
          top_app: activity.top_app,
          top_app_time: activity.top_app_time,
          second_app: activity.second_app || undefined,
          second_app_time: activity.second_app_time || undefined,
          third_app: activity.third_app || undefined,
          third_app_time: activity.third_app_time || undefined,
        })
        migrated++
        process.stdout.write(`\r  Migrated: ${migrated}/${activities.length}`)
      } catch (error) {
        console.error(`\n  Failed to migrate activity:`, error)
      }
    }
    
    console.log(`\n✅ Migrated ${migrated} activity records`)
  } catch (error) {
    console.error('❌ Failed to migrate activity tracking:', error)
  }
}

async function migrateAiReports() {
  console.log('\n🤖 Migrating AI Reports...')
  
  try {
    const db = new Database(HEALTH_DB, { readonly: true })
    const reports = db.prepare('SELECT * FROM ai_reports').all() as any[]
    db.close()

    console.log(`Found ${reports.length} AI reports`)
    
    let migrated = 0
    for (const report of reports) {
      try {
        await client.mutation(api.wellbeing.addAiReport, {
          type: report.type,
          content: report.content,
        })
        migrated++
        process.stdout.write(`\r  Migrated: ${migrated}/${reports.length}`)
      } catch (error) {
        console.error(`\n  Failed to migrate report:`, error)
      }
    }
    
    console.log(`\n✅ Migrated ${migrated} AI reports`)
  } catch (error) {
    console.error('❌ Failed to migrate AI reports:', error)
  }
}

async function main() {
  console.log('🚀 Starting SQLite → Convex Migration')
  console.log(`📡 Convex URL: ${CONVEX_URL}`)
  
  // Confirm before proceeding
  console.log('\n⚠️  This will import all your SQLite data into Convex')
  console.log('   Press Ctrl+C to cancel, or wait 3 seconds to continue...\n')
  
  await new Promise(resolve => setTimeout(resolve, 3000))
  
  await migrateContacts()
  await migrateInteractions()
  await migratePosts()
  await migrateHealthRecords()
  await migrateActivityTracking()
  await migrateAiReports()
  
  console.log('\n🎉 Migration Complete!')
  console.log('\nNext steps:')
  console.log('1. Check your data in the Convex dashboard')
  console.log('2. Update remaining API routes to use Convex')
  console.log('3. Deploy to Vercel!')
  
  process.exit(0)
}

main().catch((error) => {
  console.error('\n💥 Migration failed:', error)
  process.exit(1)
})
