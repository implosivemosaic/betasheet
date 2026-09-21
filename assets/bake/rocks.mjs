// Bakes the card "hold" shapes. A lumpy low-poly rock is built in three.js
// (icosphere pushed around by seeded noise), lit from the top left, and
// flattened to a flat-shaded SVG. Colour is left to CSS: faces are drawn in
// currentColor with white/black overlays for light and shade, so the same
// SVG takes each kind's colour and survives both themes.
// Output: ../../lib/climb_ontario_web/components/rocks/<kind>.svg
import * as THREE from "three"
import {writeFileSync, mkdirSync} from "node:fs"

const seeded = seed => () => {
  seed = (seed + 0x6d2b79f5) | 0
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

// Smooth-ish noise: a handful of random sine bumps summed.
function bumps(rand, n = 6) {
  const waves = Array.from({length: n}, () => ({
    d: new THREE.Vector3(rand() - 0.5, rand() - 0.5, rand() - 0.5).normalize(),
    f: 0.8 + rand() * 1.3, p: rand() * Math.PI * 2, a: 0.04 + rand() * 0.07,
  }))
  return v => waves.reduce((s, w) => s + Math.sin(v.dot(w.d) * w.f * Math.PI + w.p) * w.a, 0)
}

function rock(seed, {squash, tilt}) {
  const rand = seeded(seed)
  const noise = bumps(rand)
  const geo = new THREE.IcosahedronGeometry(1, DETAIL)
  const pos = geo.attributes.position
  const v = new THREE.Vector3()
  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i)
    const r = 1 + noise(v.clone().normalize())
    v.normalize().multiplyScalar(r)
    v.x *= squash[0]; v.y *= squash[1]; v.z *= squash[2]
    pos.setXYZ(i, v.x, v.y, v.z)
  }
  geo.applyMatrix4(new THREE.Matrix4().makeRotationFromEuler(new THREE.Euler(tilt[0], tilt[1], tilt[2])))
  geo.computeVertexNormals()
  return geo
}

const light = new THREE.Vector3(-0.55, 0.75, 0.6).normalize()
const SIZE = 100
const DETAIL = Number(process.env.DETAIL || 1)
const OUT = process.env.OUT

function toSvg(geo) {
  const pos = geo.attributes.position
  const faces = []
  const a = new THREE.Vector3(), b = new THREE.Vector3(), c = new THREE.Vector3()
  for (let i = 0; i < pos.count; i += 3) {
    a.fromBufferAttribute(pos, i); b.fromBufferAttribute(pos, i + 1); c.fromBufferAttribute(pos, i + 2)
    const n = new THREE.Vector3().subVectors(b, a).cross(new THREE.Vector3().subVectors(c, a)).normalize()
    if (n.z <= 0) continue // back faces
    const depth = (a.z + b.z + c.z) / 3
    const shade = n.dot(light)
    faces.push({pts: [a.clone(), b.clone(), c.clone()], depth, shade})
  }
  faces.sort((p, q) => p.depth - q.depth)
  const P = v => `${((v.x + 1.25) / 2.5 * SIZE).toFixed(1)},${((1.25 - v.y) / 2.5 * SIZE).toFixed(1)}`
  const poly = (f, fill, op) =>
    `<polygon points="${f.pts.map(P).join(" ")}" fill="${fill}"${op !== undefined ? ` fill-opacity="${op.toFixed(2)}"` : ""}/>`
  const base = faces.map(f => poly(f, "currentColor")).join("")
  const overlay = faces.map(f => {
    const s = f.shade
    return s >= 0.35 ? poly(f, "#fff", Math.min(0.55, (s - 0.35) * 0.9)) : poly(f, "#000", Math.min(0.35, (0.35 - s) * 0.5))
  }).join("")
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" aria-hidden="true" shape-rendering="crispEdges"><g>${base}</g><g>${overlay}</g></svg>`
}

const KINDS = {
  competition: {seed: 11, squash: [1.15, 0.95, 1], tilt: [0.3, -0.4, 0.2]},
  social: {seed: 23, squash: [1.05, 1.1, 1], tilt: [-0.2, 0.5, -0.3]},
  class: {seed: 37, squash: [1.2, 0.9, 1], tilt: [0.4, 0.3, 0.6]},
  camp: {seed: 41, squash: [1, 1.05, 1], tilt: [-0.35, -0.3, -0.1]},
}
const dir = OUT ? new URL(OUT.endsWith("/") ? OUT : OUT + "/", "file://") : new URL("../../lib/climb_ontario_web/components/rocks/", import.meta.url)
mkdirSync(dir, {recursive: true})
for (const [kind, opts] of Object.entries(KINDS)) {
  const svg = toSvg(rock(opts.seed, opts))
  writeFileSync(new URL(`${kind}.svg`, dir), svg)
  console.log(kind, svg.length, "bytes")
}
