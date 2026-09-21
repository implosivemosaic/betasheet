// Bakes the climber's motion. A small 3D rig is posed with keyframed hand,
// foot and hip tracks (arcs via Catmull-Rom curves, eased with a little
// anticipation and settle), limbs are solved with two-bone IK, and every
// joint's position is sampled per frame and flattened to the side view.
// Output: ../js/climber-clips.json, played back by ../js/climber.js.
//
// Space: y up, the rock face is the plane x = WALL in front of the climber,
// z is toward the viewer (the climber's left side is nearest). Every clip
// starts from the same resting pose and ends in it (plus its `rise`), so
// playback can chain clips in any order without a visible seam.

import * as THREE from "three"
import {writeFileSync} from "node:fs"

const V = (x, y, z = 0) => new THREE.Vector3(x, y, z)
const FPS = 30
const PX = 18 // screen pixels per rig unit at 1x

// Cute proportions: big head, short torso, short round limbs.
const RIG = {
  spine: 0.3, chest: 0.26, neck: 0.1, head: 0.24, headR: 0.24,
  shoulderZ: 0.14, upperArm: 0.4, foreArm: 0.38,
  hipZ: 0.1, thigh: 0.4, shin: 0.38,
}
const WALL = 0.55
const HZ = RIG.shoulderZ, FZ = RIG.hipZ
// Resting holds, relative to the hips.
const REST = {lh: V(WALL, 0.78, HZ), rh: V(WALL, 0.6, -HZ), lf: V(WALL, -0.42, FZ), rf: V(WALL, -0.56, -FZ)}
const hold = (base, dy) => V(WALL, base.y + dy, base.z)

// ── Easing and tracks ─────────────────────────────────────────────────────
const ease = {
  linear: t => t,
  inOut: t => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  out: t => 1 - Math.pow(1 - t, 3),
  outBack: t => 1 + 2.2 * Math.pow(t - 1, 3) + 1.2 * Math.pow(t - 1, 2),
  in: t => t * t * t,
}

// Piecewise track: keys of {t, v} with an easing for the segment ending at that
// key. Keys with `via` travel along a Catmull-Rom curve through those points.
function track(keys) {
  const at = t => {
    if (t <= keys[0].t) return keys[0].v.clone()
    for (let i = 1; i < keys.length; i++) {
      const a = keys[i - 1], b = keys[i]
      if (t <= b.t) {
        const p = (b.ease || ease.inOut)((t - a.t) / (b.t - a.t))
        if (b.via) {
          const curve = new THREE.CatmullRomCurve3([a.v, ...b.via, b.v], false, "centripetal")
          return curve.getPoint(Math.min(1, Math.max(0, p)))
        }
        return a.v.clone().lerp(b.v, p)
      }
    }
    return keys[keys.length - 1].v.clone()
  }
  // Holding: not travelling between keys, and on the rock.
  at.holding = t => {
    for (let i = 1; i < keys.length; i++) if (t > keys[i - 1].t && t < keys[i].t && !keys[i - 1].v.equals(keys[i].v)) return false
    return Math.abs(at(t).x - WALL) < 0.01
  }
  return at
}

// An effector track from a list of [t0, t1, target, opts] moves; it stays put between them.
// Moves to the rock arc out and back in with a soft landing; free moves go straight.
function moves(start, steps) {
  const keys = [{t: 0, v: start}]
  let cur = start
  for (const [t0, t1, to, opts = {}] of steps) {
    keys.push({t: t0, v: cur})
    const onRock = Math.abs(to.x - WALL) < 0.01 && Math.abs(cur.x - WALL) < 0.01
    keys.push({
      t: t1, v: to,
      ease: opts.ease || (onRock ? ease.outBack : ease.inOut),
      via: onRock ? [V(cur.x - (opts.out ?? 0.16), (cur.y + to.y) / 2, (cur.z + to.z) / 2)] : opts.via,
    })
    cur = to
  }
  return track(keys)
}

// ── Two-bone IK ───────────────────────────────────────────────────────────
function solve(root, target, a, b, pole) {
  const axis = target.clone().sub(root)
  let d = axis.length()
  const max = (a + b) * 0.995
  if (d > max) { axis.multiplyScalar(max / d); d = max }
  const end = root.clone().add(axis)
  axis.normalize()
  const pp = pole.clone().sub(axis.clone().multiplyScalar(pole.dot(axis))).normalize()
  const cosA = Math.max(-1, Math.min(1, (a * a + d * d - b * b) / (2 * a * d)))
  const sinA = Math.sqrt(1 - cosA * cosA)
  const joint = root.clone().add(axis.multiplyScalar(a * cosA)).add(pp.multiplyScalar(a * sinA))
  return [joint, end]
}

// ── Sampling ──────────────────────────────────────────────────────────────
const JOINTS = ["hips", "spine", "chest", "neck", "head", "lsh", "lel", "lha", "rsh", "rel", "rha", "lhp", "lkn", "lft", "rhp", "rkn", "rft"]

function bake({T, rise = 0, tracks, sweat}) {
  const frames = [], contact = []
  for (let f = 0; f < Math.round(T * FPS); f++) {
    const t = f / FPS
    const hips = tracks.hips(t)
    const [lean, lift] = [tracks.lean(t).x, tracks.lean(t).y]
    const dir = a => V(Math.sin(a), Math.cos(a), 0)
    const spine = hips.clone().add(dir(lean).multiplyScalar(RIG.spine))
    const chest = spine.clone().add(dir(lean * 1.6).multiplyScalar(RIG.chest))
    const neck = chest.clone().add(dir(lean * 1.6 + lift * 0.5).multiplyScalar(RIG.neck))
    const head = neck.clone().add(dir(lean + lift).multiplyScalar(RIG.head))
    const lsh = chest.clone().add(V(0, 0, HZ)), rsh = chest.clone().add(V(0, 0, -HZ))
    const lhp = hips.clone().add(V(0, 0, FZ)), rhp = hips.clone().add(V(0, 0, -FZ))
    const e = {lh: tracks.lh(t), rh: tracks.rh(t), lf: tracks.lf(t), rf: tracks.rf(t)}
    const [lel, lha] = solve(lsh, e.lh, RIG.upperArm, RIG.foreArm, V(-1, -0.4, 0.6))
    const [rel, rha] = solve(rsh, e.rh, RIG.upperArm, RIG.foreArm, V(-1, -0.4, -0.6))
    const [lkn, lft] = solve(lhp, e.lf, RIG.thigh, RIG.shin, V(1, 0.5, 0.7))
    const [rkn, rft] = solve(rhp, e.rf, RIG.thigh, RIG.shin, V(1, 0.5, -0.7))
    const pos = {hips, spine, chest, neck, head, lsh, lel, lha, rsh, rel, rha, lhp, lkn, lft, rhp, rkn, rft}
    frames.push(JOINTS.flatMap(j => [+(pos[j].x * PX).toFixed(2), +(-pos[j].y * PX).toFixed(2)]))
    contact.push(["lh", "rh", "lf", "rf"].map(k => Number(tracks[k].holding(t))))
  }
  const clip = {frames, contact, rise: +(rise * PX).toFixed(2)}
  if (sweat) clip.sweat = sweat.map(s => Math.round(s * FPS))
  return clip
}

const restLean = track([{t: 0, v: V(-0.12, 0)}])
const stillHips = track([{t: 0, v: V(0, 0, 0)}])

// ── Clips ─────────────────────────────────────────────────────────────────
const clips = {}

// Climb: hands up, feet up, then stand. Loops; hips gain `rise` per cycle.
{
  const T = 2.6, RISE = 0.26
  clips.climb = bake({T, rise: RISE, tracks: {
    lh: moves(REST.lh, [[0.05, 0.45, hold(REST.lh, RISE)]]),
    rh: moves(REST.rh, [[0.35, 0.75, hold(REST.rh, RISE)]]),
    lf: moves(REST.lf, [[0.7, 1.05, hold(REST.lf, RISE)]]),
    rf: moves(REST.rf, [[1.0, 1.35, hold(REST.rf, RISE)]]),
    hips: track([
      {t: 0, v: V(0, 0, 0)},
      {t: 0.45, v: V(0.04, 0.01, 0.05)},
      {t: 0.75, v: V(0.04, 0.0, -0.05)},
      {t: 1.35, v: V(0.0, -0.03, 0)},
      {t: 1.9, v: V(0.06, RISE + 0.02, 0)},
      {t: 2.1, v: V(0.04, RISE, 0), ease: ease.out},
      {t: T, v: V(0, RISE, 0)},
    ]),
    lean: track([
      {t: 0, v: V(-0.12, 0)}, {t: 0.25, v: V(0.05, 0.35)}, {t: 0.75, v: V(0.05, 0.3)},
      {t: 1.35, v: V(-0.22, 0.05)}, {t: 1.95, v: V(0.06, -0.1)}, {t: T, v: V(-0.12, 0)},
    ]),
  }})
}

// Hang: let go with the right hand and foot, dangle and sway, then regrab.
{
  const T = 3.0
  const dangleHand = V(WALL - 0.32, 0.05, -HZ - 0.05)
  const dangleFoot = V(WALL - 0.18, -0.68, -FZ - 0.04)
  clips.hang = bake({T, tracks: {
    lh: moves(REST.lh, []),
    rh: moves(REST.rh, [[0.1, 0.45, dangleHand], [2.2, 2.6, REST.rh, {ease: ease.outBack}]]),
    lf: moves(REST.lf, []),
    rf: moves(REST.rf, [[0.3, 0.6, dangleFoot], [2.35, 2.75, REST.rf, {ease: ease.outBack}]]),
    hips: track([
      {t: 0, v: V(0, 0, 0)},
      {t: 0.5, v: V(-0.06, -0.06, 0.03), ease: ease.out},
      {t: 1.1, v: V(-0.09, -0.07, 0.03)},
      {t: 1.7, v: V(-0.04, -0.06, 0.02)},
      {t: 2.2, v: V(-0.08, -0.07, 0.02)},
      {t: 2.75, v: V(0, 0, 0)},
      {t: T, v: V(0, 0, 0)},
    ]),
    lean: track([
      {t: 0, v: V(-0.12, 0)}, {t: 0.5, v: V(-0.3, 0.15)}, {t: 1.1, v: V(-0.36, 0.2)},
      {t: 1.7, v: V(-0.28, 0.25)}, {t: 2.2, v: V(-0.34, 0.15)}, {t: 2.75, v: V(-0.12, 0)}, {t: T, v: V(-0.12, 0)},
    ]),
  }})
}

// Dyno: sink into a crouch, spring up, catch a high hold with both hands, feet find the rock.
{
  const T = 2.1, RISE = 0.62
  clips.dyno = bake({T, rise: RISE, tracks: {
    lh: moves(REST.lh, [[0.62, 0.86, hold(REST.lh, RISE), {out: 0.05}]]),
    rh: moves(REST.rh, [[0.66, 0.9, hold(REST.rh, RISE), {out: 0.05}]]),
    lf: moves(REST.lf, [[0.6, 0.75, V(WALL - 0.12, -0.5, FZ)], [1.15, 1.4, hold(REST.lf, RISE)]]),
    rf: moves(REST.rf, [[0.62, 0.77, V(WALL - 0.14, -0.62, -FZ)], [1.25, 1.5, hold(REST.rf, RISE)]]),
    hips: track([
      {t: 0, v: V(0, 0, 0)},
      {t: 0.45, v: V(-0.04, -0.14, 0)},                    // sink
      {t: 0.58, v: V(-0.04, -0.14, 0)},                    // beat
      {t: 0.86, v: V(0.05, RISE + 0.08, 0), ease: ease.out}, // spring
      {t: 1.0, v: V(0.02, RISE - 0.03, 0), ease: ease.inOut}, // catch and sag
      {t: 1.2, v: V(0.03, RISE + 0.01, 0)},
      {t: 1.5, v: V(0.0, RISE, 0)},
      {t: T, v: V(0, RISE, 0)},
    ]),
    lean: track([
      {t: 0, v: V(-0.12, 0)}, {t: 0.45, v: V(-0.3, 0.3)}, {t: 0.58, v: V(-0.3, 0.35)},
      {t: 0.86, v: V(0.12, 0.2)}, {t: 1.05, v: V(-0.05, 0)}, {t: 1.5, v: V(-0.12, 0)}, {t: T, v: V(-0.12, 0)},
    ]),
  }})
}

// Phew: a hand comes off to wipe the brow, and sweat flies. `sweat` marks the frame window.
{
  const T = 2.2
  const brow = V(0.02, 0.9, -HZ + 0.02)
  clips.phew = bake({T, sweat: [0.55, 1.15], tracks: {
    lh: moves(REST.lh, []),
    rh: moves(REST.rh, [[0.1, 0.5, brow], [0.65, 0.8, V(0.12, 0.9, -HZ + 0.04)], [0.95, 1.1, brow], [1.4, 1.8, REST.rh, {ease: ease.outBack}]]),
    lf: moves(REST.lf, []),
    rf: moves(REST.rf, []),
    hips: track([{t: 0, v: V(0, 0, 0)}, {t: 0.5, v: V(-0.05, -0.02, 0)}, {t: 1.4, v: V(-0.05, -0.02, 0)}, {t: 1.9, v: V(0, 0, 0)}]),
    lean: track([{t: 0, v: V(-0.12, 0)}, {t: 0.5, v: V(-0.28, 0.35)}, {t: 0.7, v: V(-0.34, 0.5)}, {t: 1.0, v: V(-0.28, 0.35)}, {t: 1.9, v: V(-0.12, 0)}]),
  }})
}

const out = {fps: FPS, px: PX, headR: +(RIG.headR * PX).toFixed(2), wall: +(WALL * PX).toFixed(2), joints: JOINTS, clips}
writeFileSync(new URL("../js/climber-clips.json", import.meta.url), JSON.stringify(out))
console.log(Object.entries(clips).map(([k, c]) => `${k}: ${c.frames.length} frames, rise ${c.rise}`).join("; "), `— ${JSON.stringify(out).length} bytes`)
