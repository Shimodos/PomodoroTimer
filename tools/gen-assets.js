// Generates built-in notification sounds (WAV) and the app icon (ICO) for Pomodoro.
// Usage: node tools/gen-assets.js <projectDir>
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const projectDir = process.argv[2] || path.join(__dirname, '..');
const soundsDir = path.join(projectDir, 'Sounds');
const assetsDir = path.join(projectDir, 'Assets');
fs.mkdirSync(soundsDir, { recursive: true });
fs.mkdirSync(assetsDir, { recursive: true });

// ---------------------------------------------------------------- audio
const SR = 44100;
const TAU = Math.PI * 2;

function render(duration, fn) {
  const n = Math.floor(duration * SR);
  const out = new Float64Array(n);
  for (let i = 0; i < n; i++) out[i] = fn(i / SR);
  return out;
}

// Attack/decay envelope: linear attack, exponential decay, optional hard end fade.
function env(t, attack, decay, end) {
  const a = attack > 0 && t < attack ? t / attack : 1;
  let v = a * Math.exp(-decay * t);
  if (end && t > end - 0.02) v *= Math.max(0, (end - t) / 0.02);
  return v;
}

function mix(parts) {
  let len = 0;
  for (const p of parts) len = Math.max(len, Math.floor(p.at * SR) + p.data.length);
  const out = new Float64Array(len);
  for (const p of parts) {
    const off = Math.floor(p.at * SR);
    for (let i = 0; i < p.data.length; i++) out[off + i] += p.data[i];
  }
  return out;
}

function writeWav(file, data) {
  let peak = 0;
  for (const v of data) peak = Math.max(peak, Math.abs(v));
  const gain = peak > 0 ? 0.85 / peak : 1;
  const buf = Buffer.alloc(44 + data.length * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + data.length * 2, 4); buf.write('WAVE', 8);
  buf.write('fmt ', 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(SR, 24); buf.writeUInt32LE(SR * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(data.length * 2, 40);
  for (let i = 0; i < data.length; i++) {
    const s = Math.max(-1, Math.min(1, data[i] * gain));
    buf.writeInt16LE(Math.round(s * 32767), 44 + i * 2);
  }
  fs.writeFileSync(file, buf);
  console.log('wrote', path.basename(file), (data.length / SR).toFixed(2) + 's');
}

// Bell: two strikes, inharmonic partials with different decay rates.
function bellStrike(f) {
  return render(2.2, t =>
    Math.sin(TAU * f * t) * env(t, 0.002, 2.2) +
    0.55 * Math.sin(TAU * f * 2.0 * t) * env(t, 0.002, 3.5) +
    0.35 * Math.sin(TAU * f * 2.76 * t) * env(t, 0.002, 5) +
    0.2 * Math.sin(TAU * f * 4.07 * t) * env(t, 0.002, 7));
}
writeWav(path.join(soundsDir, 'bell.wav'), mix([
  { at: 0, data: bellStrike(880) },
  { at: 0.55, data: bellStrike(880) },
]));

// Chime: ascending C-E-G-C arpeggio, warm partials.
function chimeNote(f) {
  return render(1.6, t =>
    Math.sin(TAU * f * t) * env(t, 0.005, 2.4) +
    0.4 * Math.sin(TAU * f * 2 * t) * env(t, 0.005, 3.5) +
    0.15 * Math.sin(TAU * f * 3 * t) * env(t, 0.005, 5));
}
writeWav(path.join(soundsDir, 'chime.wav'), mix([
  { at: 0.00, data: chimeNote(523.25) },
  { at: 0.22, data: chimeNote(659.25) },
  { at: 0.44, data: chimeNote(783.99) },
  { at: 0.66, data: chimeNote(1046.5) },
]));

// Ding: single bright hit.
writeWav(path.join(soundsDir, 'ding.wav'), render(1.4, t =>
  Math.sin(TAU * 1318.5 * t) * env(t, 0.002, 3.2) +
  0.3 * Math.sin(TAU * 2637 * t) * env(t, 0.002, 6)));

// Soft: slow G-major pad with gentle vibrato.
writeWav(path.join(soundsDir, 'soft.wav'), render(2.6, t => {
  const vib = 1 + 0.004 * Math.sin(TAU * 5 * t);
  const e = env(t, 0.35, 1.1, 2.6);
  return e * (
    Math.sin(TAU * 392.0 * vib * t) +
    0.8 * Math.sin(TAU * 493.88 * vib * t) +
    0.7 * Math.sin(TAU * 587.33 * vib * t) +
    0.4 * Math.sin(TAU * 783.99 * vib * t));
}));

// Marimba: short descending four-note phrase with woody attack.
function marimbaNote(f) {
  return render(0.6, t =>
    Math.sin(TAU * f * t) * env(t, 0.001, 7) +
    0.5 * Math.sin(TAU * f * 4 * t) * env(t, 0.001, 30) +
    0.25 * Math.sin(TAU * f * 10 * t) * env(t, 0.001, 60));
}
writeWav(path.join(soundsDir, 'marimba.wav'), mix([
  { at: 0.00, data: marimbaNote(880) },
  { at: 0.17, data: marimbaNote(783.99) },
  { at: 0.34, data: marimbaNote(659.25) },
  { at: 0.51, data: marimbaNote(523.25) },
  { at: 0.80, data: marimbaNote(659.25) },
]));

// Beep: three classic beeps.
function beep(f, dur) {
  return render(dur, t => {
    const fade = Math.min(1, t / 0.008, (dur - t) / 0.008);
    return fade * (Math.sin(TAU * f * t) + 0.3 * Math.sin(TAU * f * 3 * t));
  });
}
writeWav(path.join(soundsDir, 'beep.wav'), mix([
  { at: 0.00, data: beep(880, 0.14) },
  { at: 0.24, data: beep(880, 0.14) },
  { at: 0.48, data: beep(880, 0.14) },
]));

// Digital: three quick double-beeps, like a wristwatch.
const dparts = [];
for (let p = 0; p < 3; p++) {
  dparts.push({ at: p * 0.36, data: beep(2093, 0.06) });
  dparts.push({ at: p * 0.36 + 0.10, data: beep(2093, 0.06) });
}
writeWav(path.join(soundsDir, 'digital.wav'), mix(dparts));

// Alarm: alternating two-tone ring.
const aparts = [];
for (let i = 0; i < 10; i++) {
  aparts.push({ at: i * 0.16, data: beep(i % 2 ? 1000 : 800, 0.15) });
}
writeWav(path.join(soundsDir, 'alarm.wav'), mix(aparts));

// ---------------------------------------------------------------- icon
const crcTable = new Int32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  crcTable[n] = c;
}
function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// Draws a tomato-red disc with a white progress arc and a small green leaf.
function drawIcon(size) {
  const ss = 4; // supersampling
  const rgba = Buffer.alloc(size * size * 4);
  const cx = size / 2, cy = size / 2;
  const R = size * 0.47;
  const ringR = size * 0.30, ringW = size * 0.075;
  const colors = {
    disc: [255, 107, 107], discEdge: [226, 84, 84], ring: [255, 255, 255], track: [255, 180, 180],
    leaf: [78, 203, 113],
  };
  function sample(x, y) {
    const dx = x - cx, dy = y - cy;
    const d = Math.sqrt(dx * dx + dy * dy);
    let col = null;
    if (d <= R) {
      col = d > R - size * 0.03 ? colors.discEdge : colors.disc;
      if (Math.abs(d - ringR) <= ringW / 2) {
        let ang = Math.atan2(dx, -dy); // 0 at top, clockwise positive
        if (ang < 0) ang += TAU;
        col = ang <= TAU * 0.75 ? colors.ring : colors.track;
      }
      const capA = { x: cx, y: cy - ringR };
      const endAng = TAU * 0.75;
      const capB = { x: cx + ringR * Math.sin(endAng), y: cy - ringR * Math.cos(endAng) };
      for (const cap of [capA, capB]) {
        const ex = x - cap.x, ey = y - cap.y;
        if (ex * ex + ey * ey <= (ringW / 2) * (ringW / 2)) col = colors.ring;
      }
    }
    const lx = x - (cx + size * 0.22), ly = y - (cy - size * 0.40);
    const a = -0.6;
    const rx = lx * Math.cos(a) - ly * Math.sin(a), ry = lx * Math.sin(a) + ly * Math.cos(a);
    if ((rx * rx) / (size * 0.16 * size * 0.16) + (ry * ry) / (size * 0.07 * size * 0.07) <= 1) col = colors.leaf;
    return col;
  }
  for (let py = 0; py < size; py++) {
    for (let px = 0; px < size; px++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
        const c = sample(px + (sx + 0.5) / ss, py + (sy + 0.5) / ss);
        if (c) { r += c[0]; g += c[1]; b += c[2]; a += 1; }
      }
      const n = ss * ss;
      const i = (py * size + px) * 4;
      if (a > 0) { rgba[i] = r / a; rgba[i + 1] = g / a; rgba[i + 2] = b / a; rgba[i + 3] = 255 * a / n; }
    }
  }
  return png(size, size, rgba);
}

const sizes = [256, 64, 48, 32, 24, 16];
const images = sizes.map(s => ({ size: s, data: drawIcon(s) }));
const header = Buffer.alloc(6);
header.writeUInt16LE(0, 0); header.writeUInt16LE(1, 2); header.writeUInt16LE(images.length, 4);
const entries = [];
let offset = 6 + 16 * images.length;
for (const img of images) {
  const e = Buffer.alloc(16);
  e[0] = img.size >= 256 ? 0 : img.size;
  e[1] = img.size >= 256 ? 0 : img.size;
  e[2] = 0; e[3] = 0;
  e.writeUInt16LE(1, 4); e.writeUInt16LE(32, 6);
  e.writeUInt32LE(img.data.length, 8); e.writeUInt32LE(offset, 12);
  offset += img.data.length;
  entries.push(e);
}
fs.writeFileSync(path.join(assetsDir, 'app.ico'), Buffer.concat([header, ...entries, ...images.map(i => i.data)]));
fs.writeFileSync(path.join(assetsDir, 'app-256.png'), images[0].data);
console.log('wrote app.ico and app-256.png');
