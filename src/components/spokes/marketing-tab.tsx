"use client"

import { useEffect, useState } from "react"
import { Card } from "../ui/card"
import { KPIMetric } from "../ui/kpi-metric"
import { Megaphone, Sparkles, Loader2 } from "lucide-react"

interface Post {
  id: number
  created_at: string
  bullets: string
  platform: string
  topic: string
  mood: string
  content: string
  image_path: string
  published: number
  published_at: string
}

interface MarketingStats {
  total_posts: number
  published: number
  drafts: number
  this_week: number
}

export function MarketingTab() {
  const [posts, setPosts] = useState<Post[]>([])
  const [stats, setStats] = useState<MarketingStats>({ total_posts: 0, published: 0, drafts: 0, this_week: 0 })
  const [loading, setLoading] = useState(true)
  const [refreshKey, setRefreshKey] = useState(0)

  // Generate form state
  const [bullets, setBullets] = useState('')
  const [platform, setPlatform] = useState('linkedin')
  const [topic, setTopic] = useState('data science')
  const [mood, setMood] = useState('educational')
  const [generating, setGenerating] = useState(false)
  const [generatedContent, setGeneratedContent] = useState<string | null>(null)
  const [genError, setGenError] = useState<string | null>(null)

  useEffect(() => {
    async function fetchPosts() {
      try {
        const response = await fetch('/api/marketing/posts?limit=20')
        const data = await response.json()
        setPosts(data.posts || [])
      } catch (error) {
        console.error('Failed to fetch posts:', error)
      }
    }
    fetchPosts()
  }, [refreshKey])

  useEffect(() => {
    async function fetchStats() {
      try {
        const response = await fetch('/api/marketing/stats')
        const data = await response.json()
        setStats(data)
      } catch (error) {
        console.error('Failed to fetch marketing stats:', error)
      } finally {
        setLoading(false)
      }
    }
    fetchStats()
  }, [refreshKey])

  const handleGenerate = async (e: React.FormEvent) => {
    e.preventDefault()
    setGenerating(true)
    setGenError(null)
    setGeneratedContent(null)

    const bulletList = bullets.split('\n').filter(b => b.trim()).map(b => b.trim().replace(/^- /, ''))
    if (bulletList.length === 0) {
      setGenError('Enter at least one bullet point')
      setGenerating(false)
      return
    }

    try {
      const res = await fetch('/api/marketing/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ bullets: bulletList, platform, topic, mood }),
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'Failed to generate')
      setGeneratedContent(data.content)
      setRefreshKey(k => k + 1)
    } catch (err) {
      setGenError(err instanceof Error ? err.message : 'Error generating post')
    } finally {
      setGenerating(false)
    }
  }

  const platformCounts = posts.reduce((acc, post) => {
    acc[post.platform] = (acc[post.platform] || 0) + 1
    return acc
  }, {} as Record<string, number>)

  return (
    <div className="space-y-6">
      {/* KPI Strip */}
      <section>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <KPIMetric label="Total Posts" value={stats.total_posts} />
          <KPIMetric label="Published" value={stats.published} />
          <KPIMetric label="This Week" value={stats.this_week} />
          <KPIMetric label="Drafts" value={stats.drafts} />
        </div>
      </section>

      {/* Platform Breakdown */}
      <section>
        <h2 className="text-[18px] font-semibold text-[var(--deep-brown)] mb-4" style={{ fontFamily: "var(--font-display)" }}>Platform Breakdown</h2>
        <Card>
          <div className="space-y-3">
            {['linkedin', 'twitter', 'instagram'].map((platform, index) => (
              <div key={platform} className="flex items-center gap-3">
                <div className="w-24 text-[13px] text-[var(--mid-brown)] capitalize">{platform}</div>
                <div
                  className="flex-1 h-6 rounded flex items-center justify-end pr-3"
                  style={{
                    backgroundColor: `rgba(184, 132, 90, ${0.15 + (index + 1) * 0.08})`,
                    width: `${Math.max(40, Math.min((platformCounts[platform] || 0) * 6, 100))}%`,
                    minWidth: '40px'
                  }}
                >
                  <span className="text-[13px] text-[var(--deep-brown)] font-medium">
                    {platformCounts[platform] || 0}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </section>

      {/* Generate Post */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-[18px] font-semibold text-[var(--deep-brown)]" style={{ fontFamily: "var(--font-display)" }}>Generate Post</h2>
        </div>
        <Card>
          <form onSubmit={handleGenerate} className="space-y-4">
            <textarea
              placeholder="What did you work on today? (3 bullet points)&#10;- Built churn prediction model&#10;- Learned SHAP explainability&#10;- Deployed FastAPI endpoint"
              value={bullets}
              onChange={e => setBullets(e.target.value)}
              className="w-full h-28 bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] p-3 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)] resize-none"
            />
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <select
                value={platform}
                onChange={e => setPlatform(e.target.value)}
                className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
              >
                <option value="linkedin">LinkedIn</option>
                <option value="twitter">Twitter</option>
                <option value="instagram">Instagram</option>
              </select>
              <input
                type="text"
                placeholder="Topic"
                value={topic}
                onChange={e => setTopic(e.target.value)}
                className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
              />
              <select
                value={mood}
                onChange={e => setMood(e.target.value)}
                className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
              >
                <option value="educational">Educational</option>
                <option value="storytelling">Storytelling</option>
                <option value="promotional">Promotional</option>
                <option value="behind_the_scenes">Behind the Scenes</option>
              </select>
            </div>
            <button
              type="submit"
              disabled={generating}
              className="w-full py-2.5 bg-[var(--amber)] text-[#FAF6EF] rounded-[8px] text-[13px] font-light hover:opacity-90 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {generating ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  Generating via Ollama...
                </>
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  Generate Post
                </>
              )}
            </button>
          </form>

          {genError && (
            <div className="mt-3 px-4 py-2 bg-[rgba(199,91,91,0.08)] border border-[rgba(199,91,91,0.15)] rounded-[8px] text-[13px] text-[var(--accent-danger)]">
              {genError}
            </div>
          )}

          {generatedContent && (
            <div className="mt-4 space-y-2">
              <div className="text-[11px] text-[var(--sage)] font-medium">Post generated and saved!</div>
              <div className="p-3 bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] text-[13px] text-[var(--mid-brown)] whitespace-pre-wrap">
                {generatedContent}
              </div>
            </div>
          )}
        </Card>
      </section>

      {/* Recent Posts */}
      <section>
        <h2 className="text-[18px] font-semibold text-[var(--deep-brown)] mb-4" style={{ fontFamily: "var(--font-display)" }}>Recent Posts</h2>
        <Card>
          {loading ? (
            <div className="p-4 text-center text-[var(--dust)]">Loading posts...</div>
          ) : posts.length === 0 ? (
            <div className="p-4 text-center text-[var(--dust)]">No posts yet. Generate your first one above.</div>
          ) : (
            <div className="space-y-3">
              {posts.map((post) => (
                <div key={post.id} className="p-3 border-b border-[var(--border-subtle)] last:border-0 hover:bg-[var(--soft-warm)] transition-colors">
                  <div className="flex items-center justify-between mb-2">
                    <span className="px-2 py-1 rounded-full text-[11px] bg-[var(--amber-low)] text-[var(--amber)] capitalize">
                      {post.platform}
                    </span>
                    <span className="text-[11px] text-[var(--dust)]">
                      {new Date(post.created_at).toLocaleDateString()}
                    </span>
                  </div>
                  <p className="text-[13px] text-[var(--mid-brown)] line-clamp-2">
                    {post.content}
                  </p>
                </div>
              ))}
            </div>
          )}
        </Card>
      </section>
    </div>
  )
}
