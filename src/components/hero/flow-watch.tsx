"use client"

import { useEffect, useRef } from "react"
import * as THREE from "three"

const DUST_POOL = 420
const BRONZE = 0x6e5d45
const AMBER = 0xb8845a
const DUST_COLOR = 0xa8957e
const INK = 0x28200f
const IVORY = 0xf9f6f0

type DustParticle = {
  active: boolean
  life: number
  maxLife: number
  vx: number
  vy: number
  vz: number
}

function createHand(length: number, width: number, color: number, z: number) {
  const group = new THREE.Group()
  const body = new THREE.Mesh(
    new THREE.BoxGeometry(width, length, 0.018),
    new THREE.MeshStandardMaterial({
      color,
      metalness: 0.35,
      roughness: 0.45,
    })
  )
  body.position.y = length * 0.42
  const counter = new THREE.Mesh(
    new THREE.BoxGeometry(width * 0.55, length * 0.18, 0.014),
    new THREE.MeshStandardMaterial({ color, metalness: 0.3, roughness: 0.5 })
  )
  counter.position.y = -length * 0.12
  group.add(body, counter)
  group.position.z = z
  return group
}

function addTickMarks(watch: THREE.Group, inner: number, outer: number, count: number, majorEvery: number) {
  for (let i = 0; i < count; i++) {
    const angle = (i / count) * Math.PI * 2
    const isMajor = i % majorEvery === 0
    const len = isMajor ? outer - inner + 0.06 : outer - inner + 0.02
    const tick = new THREE.Mesh(
      new THREE.BoxGeometry(isMajor ? 0.018 : 0.006, len, 0.008),
      new THREE.MeshBasicMaterial({
        color: isMajor ? INK : DUST_COLOR,
        transparent: true,
        opacity: isMajor ? 0.85 : 0.45,
      })
    )
    const r = inner + len * 0.5
    tick.position.set(Math.sin(angle) * r, Math.cos(angle) * r, 0.012)
    tick.rotation.z = -angle
    watch.add(tick)
  }
}

export function FlowWatch() {
  const mountRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const mount = mountRef.current
    if (!mount) return

    const prefersReduced =
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches

    const scene = new THREE.Scene()
    const camera = new THREE.PerspectiveCamera(38, 1, 0.1, 50)
    camera.position.set(0, 0.15, 4.8)
    camera.lookAt(0, 0, 0)

    const renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: true,
      powerPreference: "high-performance",
    })
    renderer.setClearColor(0x000000, 0)
    renderer.outputColorSpace = THREE.SRGBColorSpace
    mount.appendChild(renderer.domElement)

    const ambient = new THREE.AmbientLight(0xfff8ee, 0.55)
    const key = new THREE.DirectionalLight(0xffe8cc, 0.9)
    key.position.set(2.5, 3, 4)
    const rim = new THREE.DirectionalLight(0xc4d1bf, 0.35)
    rim.position.set(-3, -1, 2)
    scene.add(ambient, key, rim)

    const watch = new THREE.Group()
    scene.add(watch)

    // Outer case — sculpted torus
    const caseMesh = new THREE.Mesh(
      new THREE.TorusGeometry(1.28, 0.09, 24, 96),
      new THREE.MeshStandardMaterial({
        color: BRONZE,
        metalness: 0.72,
        roughness: 0.28,
      })
    )
    watch.add(caseMesh)

    // Inner bezel ring
    const bezel = new THREE.Mesh(
      new THREE.TorusGeometry(1.18, 0.035, 16, 80),
      new THREE.MeshStandardMaterial({
        color: AMBER,
        metalness: 0.65,
        roughness: 0.32,
      })
    )
    bezel.position.z = 0.01
    watch.add(bezel)

    // Dial surface
    const dial = new THREE.Mesh(
      new THREE.CircleGeometry(1.12, 80),
      new THREE.MeshStandardMaterial({
        color: IVORY,
        metalness: 0.05,
        roughness: 0.85,
        transparent: true,
        opacity: 0.92,
      })
    )
    dial.position.z = 0.02
    watch.add(dial)

    // Subtle concentric guides
    for (const r of [0.35, 0.62, 0.88]) {
      const ring = new THREE.Mesh(
        new THREE.RingGeometry(r - 0.004, r, 64),
        new THREE.MeshBasicMaterial({
          color: DUST_COLOR,
          transparent: true,
          opacity: 0.12,
          side: THREE.DoubleSide,
        })
      )
      ring.position.z = 0.025
      watch.add(ring)
    }

    addTickMarks(watch, 0.92, 1.05, 60, 5)

    // Crown at 3 o'clock
    const crown = new THREE.Group()
    const crownBody = new THREE.Mesh(
      new THREE.CylinderGeometry(0.06, 0.07, 0.14, 12),
      new THREE.MeshStandardMaterial({ color: BRONZE, metalness: 0.7, roughness: 0.3 })
    )
    crownBody.rotation.z = Math.PI / 2
    crownBody.position.x = 1.34
    const crownGrooves = new THREE.Mesh(
      new THREE.CylinderGeometry(0.055, 0.055, 0.12, 8),
      new THREE.MeshStandardMaterial({ color: AMBER, metalness: 0.6, roughness: 0.35 })
    )
    crownGrooves.rotation.z = Math.PI / 2
    crownGrooves.position.x = 1.34
    crown.add(crownBody, crownGrooves)
    watch.add(crown)

    // Pendant ring (no hand — floating pocket watch)
    const bail = new THREE.Mesh(
      new THREE.TorusGeometry(0.1, 0.018, 12, 32),
      new THREE.MeshStandardMaterial({ color: BRONZE, metalness: 0.75, roughness: 0.25 })
    )
    bail.position.set(0, 1.42, 0)
    watch.add(bail)

    const hourHand = createHand(0.52, 0.038, INK, 0.04)
    const minuteHand = createHand(0.78, 0.026, BRONZE, 0.05)
    const secondHand = createHand(0.88, 0.012, AMBER, 0.06)
    watch.add(hourHand, minuteHand, secondHand)

    const hub = new THREE.Mesh(
      new THREE.CylinderGeometry(0.045, 0.055, 0.06, 24),
      new THREE.MeshStandardMaterial({ color: INK, metalness: 0.5, roughness: 0.4 })
    )
    hub.rotation.x = Math.PI / 2
    hub.position.z = 0.07
    watch.add(hub)

    // Dust particle field
    const dustPositions = new Float32Array(DUST_POOL * 3)
    const dustAlphas = new Float32Array(DUST_POOL)
    const pool: DustParticle[] = Array.from({ length: DUST_POOL }, () => ({
      active: false,
      life: 0,
      maxLife: 1,
      vx: 0,
      vy: 0,
      vz: 0,
    }))

    const dustGeo = new THREE.BufferGeometry()
    dustGeo.setAttribute("position", new THREE.BufferAttribute(dustPositions, 3))
    const dustMat = new THREE.PointsMaterial({
      color: AMBER,
      size: 0.028,
      transparent: true,
      opacity: 0.65,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      sizeAttenuation: true,
    })
    const dustPoints = new THREE.Points(dustGeo, dustMat)
    dustPoints.position.z = 0.08
    watch.add(dustPoints)

    let poolCursor = 0
    const spawnDust = (x: number, y: number, strength: number) => {
      const p = pool[poolCursor % DUST_POOL]
      poolCursor++
      p.active = true
      p.life = 0
      p.maxLife = 0.6 + Math.random() * 1.4
      p.vx = (Math.random() - 0.5) * 0.012 * strength
      p.vy = (Math.random() - 0.5) * 0.012 * strength
      p.vz = 0.004 + Math.random() * 0.018
      const i = (poolCursor - 1) % DUST_POOL
      dustPositions[i * 3] = x
      dustPositions[i * 3 + 1] = y
      dustPositions[i * 3 + 2] = 0
      dustAlphas[i] = 1
    }

    const handTip = (hand: THREE.Group, length: number) => {
      const angle = hand.rotation.z
      const r = length * 0.84
      return {
        x: Math.sin(angle) * r,
        y: Math.cos(angle) * r,
      }
    }

    const resize = () => {
      const w = mount.clientWidth
      const h = mount.clientHeight
      if (w === 0 || h === 0) return
      camera.aspect = w / h
      camera.updateProjectionMatrix()
      renderer.setSize(w, h, false)
      renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    }

    resize()
    const ro = new ResizeObserver(resize)
    ro.observe(mount)

    let raf = 0
    let lastSpawn = 0
    const start = performance.now()

    const animate = (now: number) => {
      raf = requestAnimationFrame(animate)
      const t = (now - start) / 1000

      // Continuous flow — no discrete ticks
      const ms = Date.now()
      const sec = (ms / 1000) % 60
      const min = (ms / 60000) % 60
      const hr = (ms / 3600000) % 12

      const secAngle = (sec / 60) * Math.PI * 2
      const minAngle = ((min + sec / 60) / 60) * Math.PI * 2
      const hrAngle = ((hr + min / 60 + sec / 3600) / 12) * Math.PI * 2

      secondHand.rotation.z = -secAngle
      minuteHand.rotation.z = -minAngle
      hourHand.rotation.z = -hrAngle

      if (!prefersReduced) {
        watch.rotation.y = Math.sin(t * 0.22) * 0.18
        watch.rotation.x = Math.sin(t * 0.15) * 0.06 + 0.04
        watch.position.y = Math.sin(t * 0.45) * 0.04

        if (now - lastSpawn > 28) {
          lastSpawn = now
          const tips = [
            { ...handTip(secondHand, 0.88), s: 1.4 },
            { ...handTip(minuteHand, 0.78), s: 0.9 },
            { ...handTip(hourHand, 0.52), s: 0.55 },
          ]
          for (const tip of tips) {
            for (let n = 0; n < 2; n++) spawnDust(tip.x, tip.y, tip.s)
          }
        }

        for (let i = 0; i < DUST_POOL; i++) {
          const p = pool[i]
          if (!p.active) {
            dustAlphas[i] = 0
            dustPositions[i * 3 + 2] = -10
            continue
          }
          p.life += 0.016
          dustPositions[i * 3] += p.vx
          dustPositions[i * 3 + 1] += p.vy
          dustPositions[i * 3 + 2] += p.vz
          p.vx *= 0.985
          p.vy *= 0.985
          const fade = 1 - p.life / p.maxLife
          dustAlphas[i] = Math.max(0, fade * fade)
          if (p.life >= p.maxLife) p.active = false
        }
        dustGeo.attributes.position.needsUpdate = true
        dustMat.opacity = 0.55 + Math.sin(t * 1.2) * 0.08
      }

      renderer.render(scene, camera)
    }

    raf = requestAnimationFrame(animate)

    return () => {
      cancelAnimationFrame(raf)
      ro.disconnect()
      renderer.dispose()
      dustGeo.dispose()
      dustMat.dispose()
      if (mount.contains(renderer.domElement)) mount.removeChild(renderer.domElement)
    }
  }, [])

  return (
    <div
      ref={mountRef}
      className="flow-watch-canvas absolute inset-0"
      aria-hidden
    />
  )
}
