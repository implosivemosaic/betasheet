// A small chalk-line climber on a rock edge fixed to the right of the viewport.
// Decorative only: aria-hidden, no pointer events, frozen in a resting pose
// when the visitor prefers reduced motion.
//
// The motion is baked offline (assets/bake) into joint positions per frame;
// this file only draws them and keeps hands and feet on the rock line.

import CLIP from "./climber-clips.json"

const NS = "http://www.w3.org/2000/svg"

// Strip geometry: a small edge on phones, a roomier one where the margins allow.
// S scales the baked 1x pixels; EDGE is the base x of the rock line inside the
// strip; the hips sit the clip's wall distance to the left of it.
const SIZES = {
  small: {S: 1.0, W: 40, EDGE: 34},
  large: {S: 1.6, W: 96, EDGE: 90},
}

const rand = (a, b) => a + Math.random() * (b - a)
// Small seeded generator so the rock line is the same shape on every page.
const seeded = seed => () => {
  seed = (seed + 0x6d2b79f5) | 0
  let t = Math.imul(seed ^ (seed >>> 15), 1 | seed)
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}

// A chalk line tracing the rock edge: a gentle waver a few pixels off the
// viewport edge, drawn as a Catmull-Rom spline so it never looks jagged.
const WALL_LENGTH = 4000

function buildWall(height, seed, EDGE) {
  const next = seeded(seed)
  const r = (a, b) => a + next() * (b - a)
  // Laid from the top down to a fixed length, so the visible stretch is the
  // same whatever the viewport height (phones resize it as the address bar
  // shows and hides); the lookup below expects the points bottom-first.
  const pts = []
  for (let y = -40; y < Math.max(height, WALL_LENGTH) + 40; y += r(50, 110)) pts.push([EDGE + r(-7, 3), y])
  pts.reverse()
  const at = i => pts[Math.max(0, Math.min(pts.length - 1, i))]
  const catmull = (i, t) => {
    const [p0, p1, p2, p3] = [at(i - 1), at(i), at(i + 1), at(i + 2)]
    const t2 = t * t, t3 = t2 * t
    const c = (a, b, cc, d) => 0.5 * (2 * b + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
    return c(p0[0], p1[0], p2[0], p3[0])
  }
  let d = `M${pts[0][0].toFixed(1)} ${pts[0][1].toFixed(1)}`
  for (let i = 0; i < pts.length - 1; i++) {
    const [p0, p1, p2, p3] = [at(i - 1), at(i), at(i + 1), at(i + 2)]
    const c1 = [p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6]
    const c2 = [p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6]
    d += ` C${c1[0].toFixed(1)} ${c1[1].toFixed(1)} ${c2[0].toFixed(1)} ${c2[1].toFixed(1)} ${p2[0].toFixed(1)} ${p2[1].toFixed(1)}`
  }
  const surface = ay => {
    for (let i = 1; i < pts.length; i++) {
      const [, y0] = pts[i - 1], [, y1] = pts[i]
      if (ay <= y0 && ay >= y1) return catmull(i - 1, y0 === y1 ? 0 : (y0 - ay) / (y0 - y1))
    }
    return EDGE
  }
  return {d, surface}
}

// `hero` mounts a large, self-contained climber in a fixed box (error pages):
// no climbing progress, no memory across pages, just hanging about.
export function mountClimber(root, {hero = false} = {}) {
  if (!root || root.dataset.mounted) return
  root.dataset.mounted = "1"
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches
  let S, W, EDGE // per instance: the edge strip and the hero box differ in scale
  const hipX = () => EDGE - CLIP.wall * S

  // The climber carries on across page loads: the rock seed and where he was
  // are kept for the tab, so clicking through to an event doesn't reset him.
  const KEY = "climber"
  let saved = null
  if (!hero) try { saved = JSON.parse(sessionStorage.getItem(KEY) || "null") } catch (_) {}
  const seed = saved?.seed ?? Math.floor(Math.random() * 2 ** 31)

  const el = (name, cls) => {
    const node = document.createElementNS(NS, name)
    if (cls) node.setAttribute("class", cls)
    return node
  }
  const svg = el("svg")
  const wall = el("path", "climber-wall")
  const fig = el("g", "climber-figure")
  const far = el("g", "climber-far")
  const body = el("path")
  const head = el("circle")
  const limbs = {larm: el("path"), rarm: el("path"), lleg: el("path"), rleg: el("path")}
  far.append(limbs.rleg, limbs.rarm)
  fig.append(far, limbs.lleg, body, limbs.larm, head)
  svg.append(wall, fig)
  root.append(svg)

  let height = 0, surface = () => EDGE
  const layout = () => {
    ;({S, W, EDGE} = hero ? {S: 3.2, W: 160, EDGE: 140} : matchMedia("(min-width: 1024px)").matches ? SIZES.large : SIZES.small)
    head.setAttribute("r", String(CLIP.headR * S))
    fig.style.strokeWidth = `${2.8 * S}px`
    height = hero ? 260 : innerHeight
    svg.setAttribute("viewBox", `0 0 ${W} ${height}`)
    svg.setAttribute("width", W)
    svg.setAttribute("height", height)
    const built = buildWall(height, seed, EDGE)
    wall.setAttribute("d", built.d)
    surface = built.surface
  }
  layout()
  if (!hero) addEventListener("resize", layout)

  const IDX = Object.fromEntries(CLIP.joints.map((j, i) => [j, i]))
  const CONTACT = {lha: 0, rha: 1, lft: 2, rft: 3}
  const CLIPS = CLIP.clips
  let baseY = saved?.baseY ?? height * (still || hero ? 0.55 : rand(0.6, 0.9)) // where the current clip's hip origin sits

  // Joint positions for a clip frame in strip coordinates. Hands and feet that
  // the clip marks as holding are snapped onto the rock line; in flight they
  // drift toward it as they close in, so landings never jump.
  const joints = (clip, f) => {
    const frame = clip.frames[f]
    const out = {}
    for (const [name, i] of Object.entries(IDX)) {
      let x = hipX() + frame[2 * i] * S
      const y = baseY + frame[2 * i + 1] * S
      if (name in CONTACT) {
        const gap = surface(y) - 1 - (hipX() + CLIP.wall * S)
        const closeness = clip.contact[f][CONTACT[name]] ? 1 : Math.max(0, 1 - (EDGE - x) / (10 * S))
        x += gap * closeness
      }
      out[name] = [x, y]
    }
    return out
  }

  const fmt = ([x, y]) => `${x.toFixed(1)} ${y.toFixed(1)}`
  // A limb drawn as a curve through its joint, so it bends rather than hinges.
  const limbPath = (P, J, Q) => `M${fmt(P)} Q${fmt([2 * J[0] - (P[0] + Q[0]) / 2, 2 * J[1] - (P[1] + Q[1]) / 2])} ${fmt(Q)}`
  let headAt = [0, 0]
  const draw = (clip, f, bob = 0) => {
    const j = joints(clip, f)
    const neck = [j.neck[0], j.neck[1] + bob], hc = [j.head[0], j.head[1] + bob]
    const dir = [hc[0] - neck[0], hc[1] - neck[1]], nd = Math.hypot(dir[0], dir[1]) || 1
    const neckEnd = [hc[0] - (dir[0] / nd) * CLIP.headR * S, hc[1] - (dir[1] / nd) * CLIP.headR * S]
    body.setAttribute("d", `M${fmt(j.hips)} Q${fmt(j.spine)} ${fmt(j.chest)} L${fmt(neck)} L${fmt(neckEnd)}`)
    head.setAttribute("cx", hc[0]); head.setAttribute("cy", hc[1])
    headAt = hc
    limbs.larm.setAttribute("d", limbPath(j.lsh, j.lel, j.lha))
    limbs.rarm.setAttribute("d", limbPath(j.rsh, j.rel, j.rha))
    limbs.lleg.setAttribute("d", limbPath(j.lhp, j.lkn, j.lft))
    limbs.rleg.setAttribute("d", limbPath(j.rhp, j.rkn, j.rft))
  }
  draw(CLIPS.climb, 0)
  if (still) return

  // Sweat: little drops flicked off the brow, away from the rock and up, then falling.
  const drops = []
  const sweat = now => {
    for (let n = 0; n < 2; n++) {
      const speed = rand(55, 90) * S
      const angle = rand(-3.0, -2.2) // left and up
      const d = {
        x: headAt[0] + CLIP.headR * S * 0.3, y: headAt[1] - CLIP.headR * S * 0.7,
        vx: Math.cos(angle) * speed, vy: Math.sin(angle) * speed, born: now, el: el("circle", "climber-sweat"),
      }
      d.el.setAttribute("r", String(rand(0.9, 1.4) * S))
      svg.append(d.el)
      drops.push(d)
    }
  }
  const stepDrops = (now, dt) => {
    for (const d of drops) {
      d.vy += 220 * S * dt
      d.x += d.vx * dt; d.y += d.vy * dt
      const age = (now - d.born) / 550
      d.el.setAttribute("cx", d.x.toFixed(1)); d.el.setAttribute("cy", d.y.toFixed(1))
      d.el.setAttribute("opacity", String(Math.max(0, 1 - age)))
      if (age >= 1) { d.el.remove(); d.dead = true }
    }
    for (let i = drops.length - 1; i >= 0; i--) if (drops[i].dead) drops.splice(i, 1)
  }

  // Playback: mostly climbing, with the occasional hang, dyno or brow wipe,
  // and a breathing rest between clips. Topping out puts the climber straight
  // back at the bottom, no fuss.
  const WEIGHTS = hero ? {hang: 3, phew: 2} : {climb: 6, hang: 2, dyno: 2, phew: 2}
  const pickClip = () => {
    let r = Math.random() * Object.values(WEIGHTS).reduce((a, b) => a + b, 0)
    for (const [k, w] of Object.entries(WEIGHTS)) if ((r -= w) < 0) return k
    return Object.keys(WEIGHTS)[0]
  }
  const frameMs = 1000 / CLIP.fps
  let name = saved?.name in CLIPS ? saved.name : hero ? "hang" : "climb", clip = CLIPS[name], frame = Math.min(saved?.frame ?? 0, clip.frames.length - 1)
  let last = 0, acc = 0, cyclesLeft = Math.round(rand(1, 3)), restUntil = 0, lastSweat = -1
  const remember = () => {
    try { sessionStorage.setItem(KEY, JSON.stringify({seed, baseY, name, frame})) } catch (_) {}
  }
  if (!hero) addEventListener("pagehide", remember)
  const tick = now => {
    const dt = Math.min(0.1, (now - (last || now)) / 1000)
    last = now
    stepDrops(now, dt)
    if (now < restUntil) {
      draw(CLIPS.climb, 0, Math.sin(now / 260) * 0.6 * S)
      return requestAnimationFrame(tick)
    }
    acc += dt * 1000
    while (acc >= frameMs) {
      acc -= frameMs
      frame++
      if (clip.sweat && frame >= clip.sweat[0] && frame <= clip.sweat[1] && frame - lastSweat >= 6) {
        lastSweat = frame
        sweat(now)
      }
      if (frame >= clip.frames.length) {
        frame = 0
        lastSweat = -1
        baseY -= clip.rise * S
        const again = name === "climb" && --cyclesLeft > 0
        if (!again) {
          name = pickClip()
          clip = CLIPS[name]
          if (name === "climb") cyclesLeft = Math.round(rand(1, 3))
          restUntil = now + rand(500, 1600)
        }
        if (baseY < 50 * S) baseY = height - 30 * S
      }
    }
    draw(clip, frame)
    requestAnimationFrame(tick)
  }
  requestAnimationFrame(tick)
}
