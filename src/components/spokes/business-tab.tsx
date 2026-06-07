"use client"

import { useEffect, useState } from "react"
import { Card } from "../ui/card"
import { KPIMetric } from "../ui/kpi-metric"
import { Briefcase, Plus, ChevronDown, ChevronUp, Save, MessageSquare, RotateCcw } from "lucide-react"

interface Contact {
  id: number
  name: string
  company: string
  email: string
  industry: string
  status: string
  notes: string
  last_contact: string
  created_at: string
}

const VALID_STATUSES = ['prospect', 'call_booked', 'proposal', 'client', 'lost']
const INTERACTION_TYPES = ['call', 'email', 'meeting', 'note', 'proposal_sent']

export function BusinessTab() {
  const [contacts, setContacts] = useState<Contact[]>([])
  const [pipelineSummary, setPipelineSummary] = useState<Record<string, number>>({})
  const [loading, setLoading] = useState(true)
  const [refreshKey, setRefreshKey] = useState(0)

  // Form states
  const [showAddForm, setShowAddForm] = useState(false)
  const [showLogForm, setShowLogForm] = useState(false)
  const [showUpdateForm, setShowUpdateForm] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const [formSuccess, setFormSuccess] = useState<string | null>(null)

  // Add contact form
  const [newContact, setNewContact] = useState({
    name: '', company: '', email: '', industry: '', status: 'prospect', notes: ''
  })

  // Log interaction form
  const [interaction, setInteraction] = useState({
    contact_id: '', type: 'call', summary: ''
  })

  // Update status form
  const [statusUpdate, setStatusUpdate] = useState({
    contact_id: '', new_status: 'prospect', new_notes: ''
  })

  useEffect(() => {
    async function fetchContacts() {
      try {
        const response = await fetch('/api/business/contacts')
        const data = await response.json()
        setContacts(data.contacts || [])
      } catch (error) {
        console.error('Failed to fetch contacts:', error)
      }
    }
    fetchContacts()
  }, [refreshKey])

  useEffect(() => {
    async function fetchPipelineSummary() {
      try {
        const response = await fetch('/api/business/pipeline-summary')
        const data = await response.json()
        setPipelineSummary(data.summary || {})
      } catch (error) {
        console.error('Failed to fetch pipeline summary:', error)
      } finally {
        setLoading(false)
      }
    }
    fetchPipelineSummary()
  }, [refreshKey])

  const handleAddContact = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)
    if (!newContact.name.trim()) {
      setFormError('Name is required')
      return
    }
    try {
      const res = await fetch('/api/business/contacts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newContact),
      })
      if (!res.ok) throw new Error('Failed to add contact')
      setFormSuccess(`Added contact: ${newContact.name}`)
      setNewContact({ name: '', company: '', email: '', industry: '', status: 'prospect', notes: '' })
      setRefreshKey(k => k + 1)
      setTimeout(() => setFormSuccess(null), 3000)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Error')
    }
  }

  const handleLogInteraction = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)
    if (!interaction.contact_id || !interaction.summary.trim()) {
      setFormError('Contact and summary are required')
      return
    }
    try {
      const res = await fetch('/api/business/interactions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(interaction),
      })
      if (!res.ok) throw new Error('Failed to log interaction')
      setFormSuccess('Interaction logged')
      setInteraction({ contact_id: '', type: 'call', summary: '' })
      setRefreshKey(k => k + 1)
      setTimeout(() => setFormSuccess(null), 3000)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Error')
    }
  }

  const handleUpdateStatus = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)
    if (!statusUpdate.contact_id) {
      setFormError('Select a contact')
      return
    }
    try {
      const body: any = { id: parseInt(statusUpdate.contact_id), status: statusUpdate.new_status }
      if (statusUpdate.new_notes.trim()) body.notes = statusUpdate.new_notes
      const res = await fetch('/api/business/contacts', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (!res.ok) throw new Error('Failed to update')
      setFormSuccess('Contact updated')
      setStatusUpdate({ contact_id: '', new_status: 'prospect', new_notes: '' })
      setRefreshKey(k => k + 1)
      setTimeout(() => setFormSuccess(null), 3000)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Error')
    }
  }

  const totalContacts = contacts.length

  return (
    <div className="space-y-6">
      {/* KPI Strip */}
      <section>
        <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-4">
          <KPIMetric label="Total Contacts" value={totalContacts} />
          <KPIMetric label="Prospects" value={pipelineSummary.prospect || 0} />
          <KPIMetric label="Calls Booked" value={pipelineSummary.call_booked || 0} />
          <KPIMetric label="Proposals Out" value={pipelineSummary.proposal || 0} />
          <KPIMetric label="Active Clients" value={pipelineSummary.client || 0} />
          <KPIMetric label="Lost" value={pipelineSummary.lost || 0} />
        </div>
      </section>

      {/* Pipeline Funnel */}
      <section>
        <h2 className="text-[18px] font-semibold text-[var(--deep-brown)] mb-4" style={{ fontFamily: "var(--font-display)" }}>Pipeline Funnel</h2>
        <Card>
          <div className="space-y-3">
            {['prospect', 'call_booked', 'proposal', 'client'].map((status, index) => (
              <div key={status} className="flex items-center gap-3">
                <div className="w-32 text-[11px] text-[var(--mid-brown)] capitalize">
                  {status.replace('_', ' ')}
                </div>
                <div 
                  className="h-8 rounded flex items-center justify-end pr-3"
                  style={{ 
                    backgroundColor: `rgba(184, 132, 90, ${0.15 + (index + 1) * 0.1})`,
                    width: `${Math.max(40, Math.min((pipelineSummary[status] || 0) * 12, 100))}%`,
                    minWidth: '40px'
                  }}
                >
                  <span className="text-[13px] text-[var(--deep-brown)] font-medium">
                    {pipelineSummary[status] || 0}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </Card>
      </section>

      {/* Action Forms */}
      <section className="space-y-3">
        {/* Add Contact */}
        <Card>
          <button
            onClick={() => setShowAddForm(!showAddForm)}
            className="w-full flex items-center justify-between text-[13px] font-medium text-[var(--deep-brown)]"
          >
            <span className="flex items-center gap-2">
              <Plus className="w-4 h-4 text-[var(--amber)]" />
              Add a new contact
            </span>
            {showAddForm ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
          {showAddForm && (
            <form onSubmit={handleAddContact} className="mt-3 space-y-3 pt-3 border-t border-[var(--border-subtle)]">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <input
                  type="text"
                  placeholder="Name *"
                  value={newContact.name}
                  onChange={e => setNewContact({ ...newContact, name: e.target.value })}
                  className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
                />
                <input
                  type="text"
                  placeholder="Company"
                  value={newContact.company}
                  onChange={e => setNewContact({ ...newContact, company: e.target.value })}
                  className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
                />
                <input
                  type="email"
                  placeholder="Email"
                  value={newContact.email}
                  onChange={e => setNewContact({ ...newContact, email: e.target.value })}
                  className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
                />
                <input
                  type="text"
                  placeholder="Industry"
                  value={newContact.industry}
                  onChange={e => setNewContact({ ...newContact, industry: e.target.value })}
                  className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
                />
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <select
                  value={newContact.status}
                  onChange={e => setNewContact({ ...newContact, status: e.target.value })}
                  className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
                >
                  {VALID_STATUSES.map(s => (
                    <option key={s} value={s}>{s.replace('_', ' ')}</option>
                  ))}
                </select>
                <input
                  type="text"
                  placeholder="Notes"
                  value={newContact.notes}
                  onChange={e => setNewContact({ ...newContact, notes: e.target.value })}
                  className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
                />
              </div>
              <button
                type="submit"
                className="flex items-center gap-2 px-4 py-2 bg-[var(--amber)] text-[#FAF6EF] rounded-[var(--radius-sm)] text-[13px] font-medium hover:opacity-90 transition-all"
              >
                <Save className="w-4 h-4" />
                Add Contact
              </button>
            </form>
          )}
        </Card>

        {/* Log Interaction */}
        {contacts.length > 0 && (
          <Card>
            <button
              onClick={() => setShowLogForm(!showLogForm)}
              className="w-full flex items-center justify-between text-[13px] font-medium text-[var(--deep-brown)]"
            >
              <span className="flex items-center gap-2">
                <MessageSquare className="w-4 h-4 text-[var(--amber)]" />
                Log an interaction
              </span>
              {showLogForm ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
            </button>
            {showLogForm && (
              <form onSubmit={handleLogInteraction} className="mt-3 space-y-3 pt-3 border-t border-[var(--border-subtle)]">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <select
                    value={interaction.contact_id}
                    onChange={e => setInteraction({ ...interaction, contact_id: e.target.value })}
                    className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
                  >
                    <option value="">Select contact</option>
                    {contacts.map(c => (
                      <option key={c.id} value={c.id}>#{c.id} — {c.name} ({c.company || '—'})</option>
                    ))}
                  </select>
                  <select
                    value={interaction.type}
                    onChange={e => setInteraction({ ...interaction, type: e.target.value })}
                    className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
                  >
                    {INTERACTION_TYPES.map(t => (
                      <option key={t} value={t}>{t.replace('_', ' ')}</option>
                    ))}
                  </select>
                </div>
                <textarea
                  placeholder="Summary..."
                  value={interaction.summary}
                  onChange={e => setInteraction({ ...interaction, summary: e.target.value })}
                  className="w-full h-20 bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] p-3 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)] resize-none"
                />
                <button
                  type="submit"
                  className="flex items-center gap-2 px-4 py-2 bg-[var(--amber)] text-[#FAF6EF] rounded-[var(--radius-sm)] text-[13px] font-medium hover:opacity-90 transition-all"
                >
                  <Save className="w-4 h-4" />
                  Log Interaction
                </button>
              </form>
            )}
          </Card>
        )}

        {/* Update Status */}
        {contacts.length > 0 && (
          <Card>
            <button
              onClick={() => setShowUpdateForm(!showUpdateForm)}
              className="w-full flex items-center justify-between text-[13px] font-medium text-[var(--deep-brown)]"
            >
              <span className="flex items-center gap-2">
                <RotateCcw className="w-4 h-4 text-[var(--amber)]" />
                Move a contact through the funnel
              </span>
              {showUpdateForm ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
            </button>
            {showUpdateForm && (
              <form onSubmit={handleUpdateStatus} className="mt-3 space-y-3 pt-3 border-t border-[var(--border-subtle)]">
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <select
                    value={statusUpdate.contact_id}
                    onChange={e => setStatusUpdate({ ...statusUpdate, contact_id: e.target.value })}
                    className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
                  >
                    <option value="">Select contact</option>
                    {contacts.map(c => (
                      <option key={c.id} value={c.id}>#{c.id} — {c.name} [{c.status}]</option>
                    ))}
                  </select>
                  <select
                    value={statusUpdate.new_status}
                    onChange={e => setStatusUpdate({ ...statusUpdate, new_status: e.target.value })}
                    className="bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] focus:outline-none focus:border-[var(--border-mid)]"
                  >
                    {VALID_STATUSES.map(s => (
                      <option key={s} value={s}>{s.replace('_', ' ')}</option>
                    ))}
                  </select>
                </div>
                <input
                  type="text"
                  placeholder="Append note (optional)"
                  value={statusUpdate.new_notes}
                  onChange={e => setStatusUpdate({ ...statusUpdate, new_notes: e.target.value })}
                  className="w-full bg-[var(--linen)] border border-[var(--border-subtle)] rounded-[8px] px-3 py-2 text-[13px] text-[var(--deep-brown)] placeholder:text-[var(--dust)] focus:outline-none focus:border-[var(--border-mid)]"
                />
                <button
                  type="submit"
                  className="flex items-center gap-2 px-4 py-2 bg-[var(--amber)] text-[#FAF6EF] rounded-[var(--radius-sm)] text-[13px] font-medium hover:opacity-90 transition-all"
                >
                  <RotateCcw className="w-4 h-4" />
                  Update Contact
                </button>
              </form>
            )}
          </Card>
        )}

        {/* Feedback */}
        {formError && (
          <div className="px-4 py-2 bg-[rgba(199,91,91,0.08)] border border-[rgba(199,91,91,0.15)] rounded-[8px] text-[13px] text-[var(--accent-danger)]">
            {formError}
          </div>
        )}
        {formSuccess && (
          <div className="px-4 py-2 bg-[var(--sage-low)] border border-[rgba(125,147,122,0.2)] rounded-[8px] text-[13px] text-[var(--sage)]">
            {formSuccess}
          </div>
        )}
      </section>

      {/* Contacts Table */}
      <section>
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-[18px] font-semibold text-[var(--deep-brown)]">All Contacts</h2>
        </div>
        <Card>
          {loading ? (
            <div className="p-4 text-center text-[var(--dust)]">Loading contacts...</div>
          ) : contacts.length === 0 ? (
            <div className="p-4 text-center text-[var(--dust)]">No contacts yet — add one above.</div>
          ) : (
            <div className="overflow-x-auto">
            <div className="space-y-2 min-w-[600px]">
              <div className="grid grid-cols-5 gap-4 px-3 py-2 bg-[var(--soft-warm)] text-[11px] text-[var(--mid-brown)] uppercase">
                <div>Name</div>
                <div>Company</div>
                <div>Status</div>
                <div>Industry</div>
                <div>Last Contact</div>
              </div>
              {contacts.map((contact) => (
                <div key={contact.id} className="grid grid-cols-5 gap-4 px-3 py-3 hover:bg-[var(--soft-warm)] transition-colors">
                  <div className="text-[13px] text-[var(--deep-brown)]">{contact.name}</div>
                  <div className="text-[13px] text-[var(--mid-brown)]">{contact.company || '—'}</div>
                  <div>
                    <span className={`px-2 py-1 rounded-full text-[11px] ${
                      contact.status === 'client'
                        ? 'bg-[var(--sage-low)] text-[var(--sage)]'
                        : contact.status === 'lost'
                        ? 'bg-[rgba(199,91,91,0.15)] text-[var(--accent-danger)]'
                        : 'bg-[var(--amber-low)] text-[var(--amber)]'
                    }`}>
                      {contact.status.replace('_', ' ')}
                    </span>
                  </div>
                  <div className="text-[13px] text-[var(--mid-brown)]">{contact.industry || '—'}</div>
                  <div className="text-[11px] text-[var(--dust)]">
                    {contact.last_contact ? new Date(contact.last_contact).toLocaleDateString() : '—'}
                  </div>
                </div>
              ))}
            </div>
            </div>
          )}
        </Card>
      </section>
    </div>
  )
}
