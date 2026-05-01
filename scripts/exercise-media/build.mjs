#!/usr/bin/env node
// Build pipeline for exercise demo videos.
// See README.md for prereqs and configuration.

import 'dotenv/config';
import { S3Client, PutObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile, stat } from 'node:fs/promises';
import { existsSync, createWriteStream } from 'node:fs';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const WORK_DIR = path.join(__dirname, 'work');
const DB_REPO_DIR = path.join(__dirname, 'free-exercise-db');
const MANIFEST_OUT = path.join(REPO_ROOT, 'ios', 'FitAIPremiumFitnessApp', 'exercise_media.json');
const EXERCISE_DB_SWIFT = path.join(REPO_ROOT, 'ios', 'FitAIPremiumFitnessApp', 'Services', 'ExerciseDatabase.swift');

const FREE_EXERCISE_DB_TARBALL = 'https://codeload.github.com/yuhonas/free-exercise-db/tar.gz/refs/heads/main';

// ---------- Config ----------

const required = ['S3_ENDPOINT', 'S3_BUCKET', 'S3_ACCESS_KEY_ID', 'S3_SECRET_ACCESS_KEY', 'PUBLIC_BASE_URL'];
for (const k of required) {
  if (!process.env[k]) {
    console.error(`Missing env var: ${k}. Copy .env.example to .env and fill it in.`);
    process.exit(1);
  }
}

const s3 = new S3Client({
  endpoint: process.env.S3_ENDPOINT,
  region: process.env.S3_REGION ?? 'auto',
  credentials: {
    accessKeyId: process.env.S3_ACCESS_KEY_ID,
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
  },
});

const BUCKET = process.env.S3_BUCKET;
const PUBLIC_BASE = process.env.PUBLIC_BASE_URL.replace(/\/$/, '');

// ---------- Helpers ----------

function slugify(name) {
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function normalize(name) {
  // Aggressive normalization for matching: strip punctuation, lowercase, drop noise words.
  const noise = new Set(['the', 'a', 'an', 'with', 'and']);
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean)
    .filter((w) => !noise.has(w))
    .sort()
    .join(' ');
}

async function run(cmd, args) {
  return new Promise((resolve, reject) => {
    const p = spawn(cmd, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stderr = '';
    p.stderr.on('data', (d) => (stderr += d.toString()));
    p.on('close', (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} ${args.join(' ')} failed (${code}): ${stderr}`));
    });
  });
}

async function downloadTo(url, dest) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GET ${url} -> ${res.status}`);
  await pipeline(Readable.fromWeb(res.body), createWriteStream(dest));
}

async function s3HasObject(key) {
  try {
    await s3.send(new HeadObjectCommand({ Bucket: BUCKET, Key: key }));
    return true;
  } catch (e) {
    if (e.$metadata?.httpStatusCode === 404 || e.name === 'NotFound') return false;
    throw e;
  }
}

async function s3Upload(key, body, contentType) {
  await s3.send(
    new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      Body: body,
      ContentType: contentType,
      CacheControl: 'public, max-age=31536000, immutable',
    }),
  );
}

// ---------- Step 1: get our exercise names from the Swift source ----------

async function readOurExerciseNames() {
  const src = await readFile(EXERCISE_DB_SWIFT, 'utf8');
  const re = /db\["([^"]+)"\]\s*=\s*ExerciseDemoInfo\(/g;
  const names = new Set();
  for (const m of src.matchAll(re)) names.add(m[1]);
  return [...names];
}

// ---------- Step 2: get free-exercise-db catalog ----------

async function ensureFreeDb() {
  if (existsSync(DB_REPO_DIR)) return;
  console.log('Downloading free-exercise-db...');
  await mkdir(WORK_DIR, { recursive: true });
  const tarPath = path.join(WORK_DIR, 'free-exercise-db.tar.gz');
  await downloadTo(FREE_EXERCISE_DB_TARBALL, tarPath);
  await mkdir(DB_REPO_DIR, { recursive: true });
  await run('tar', ['-xzf', tarPath, '-C', DB_REPO_DIR, '--strip-components=1']);
}

async function loadCatalog() {
  const json = await readFile(path.join(DB_REPO_DIR, 'dist', 'exercises.json'), 'utf8');
  return JSON.parse(json);
}

// ---------- Step 3: match names ----------

const ALIASES = {
  // Hand-curated aliases for names that don't fuzzy-match cleanly.
  'Push-Ups': 'Push-Up',
  'Pull-Ups': 'Pull-Up',
  'Chin-Ups': 'Chin-Up',
  'Lateral Raises': 'Side Lateral Raise',
  'Cable Flyes': 'Cable Crossover',
  'Tricep Pushdowns': 'Triceps Pushdown',
  'Barbell Curls': 'Barbell Curl',
  'Hammer Curls': 'Dumbbell Hammer Curl',
  'Walking Lunges': 'Dumbbell Lunge',
  'Calf Raises': 'Standing Calf Raise',
  'Leg Curl': 'Lying Leg Curl',
  'Bulgarian Split Squats': 'Bulgarian Split Squat',
  'Glute Bridges': 'Glute Bridge',
  'Jump Squats': 'Jump Squat',
  'Leg Extensions': 'Leg Extension',
  'Hanging Leg Raises': 'Hanging Leg Raise',
  'Russian Twists': 'Russian Twist',
  'Mountain Climbers': 'Mountain Climber',
  'Dumbbell Lunges': 'Dumbbell Lunge',
  'Tricep Dips': 'Bench Dip',
  'Leg Raises': 'Lying Leg Raise',
  'Hip Thrusts': 'Barbell Hip Thrust',
  'Front Squats': 'Front Barbell Squat',
  'Inverted Rows': 'Body-up',
  'Dips (Chair)': 'Bench Dip',
};

function buildIndex(catalog) {
  const idx = new Map();
  for (const ex of catalog) {
    idx.set(normalize(ex.name), ex);
  }
  return idx;
}

function matchExercise(ourName, catalog, idx) {
  const candidates = [ourName, ALIASES[ourName]].filter(Boolean);
  for (const c of candidates) {
    const hit = idx.get(normalize(c));
    if (hit) return hit;
  }
  // Fallback: prefix match on normalized form (e.g. "Barbell Bench Press" matches "Bench Press, Barbell")
  const ourTokens = new Set(normalize(ourName).split(' '));
  let best = null;
  let bestScore = 0;
  for (const ex of catalog) {
    const exTokens = new Set(normalize(ex.name).split(' '));
    let overlap = 0;
    for (const t of ourTokens) if (exTokens.has(t)) overlap += 1;
    const score = overlap / Math.max(ourTokens.size, exTokens.size);
    if (score > bestScore) {
      bestScore = score;
      best = ex;
    }
  }
  return bestScore >= 0.6 ? best : null;
}

// ---------- Step 4: download + convert + upload ----------

async function processExercise(ourName, dbEntry, manifest) {
  const slug = slugify(ourName);
  const videoKey = `exercises/${slug}.mp4`;
  const thumbKey = `exercises/${slug}.webp`;
  const videoURL = `${PUBLIC_BASE}/${videoKey}`;
  const thumbURL = `${PUBLIC_BASE}/${thumbKey}`;

  // Skip if already uploaded.
  const [hasVideo, hasThumb] = await Promise.all([s3HasObject(videoKey), s3HasObject(thumbKey)]);
  if (hasVideo && hasThumb) {
    manifest[ourName] = { video: videoURL, thumb: thumbURL };
    return { status: 'skipped' };
  }

  await mkdir(WORK_DIR, { recursive: true });

  // free-exercise-db ships images as JPGs in dist/exercises/<id>/images/<n>.jpg
  // For animated demos we want the GIFs from the upstream "images" gif source if available.
  // Fallback: stitch the JPG frames into an MP4.
  const id = dbEntry.id;
  const localFrames = [];
  for (let i = 0; i < (dbEntry.images?.length ?? 0); i++) {
    const remote = `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/${dbEntry.images[i]}`;
    const local = path.join(WORK_DIR, `${id}-${i}.jpg`);
    await downloadTo(remote, local);
    localFrames.push(local);
  }
  if (localFrames.length === 0) return { status: 'no-frames' };

  const tmpListing = path.join(WORK_DIR, `${id}-frames.txt`);
  // ffconcat looped: ~0.6s per frame so a 2-frame demo = ~1.2s loop.
  const lines = ['ffconcat version 1.0'];
  for (const f of localFrames) {
    lines.push(`file '${f.replace(/'/g, "'\\''")}'`);
    lines.push('duration 0.6');
  }
  // ffconcat needs the last file repeated to honor its duration.
  lines.push(`file '${localFrames[localFrames.length - 1].replace(/'/g, "'\\''")}'`);
  await writeFile(tmpListing, lines.join('\n'));

  const mp4Path = path.join(WORK_DIR, `${id}.mp4`);
  const webpPath = path.join(WORK_DIR, `${id}.webp`);

  // HEVC MP4, 480x480, 24fps, looping a couple of times so player has frames.
  await run('ffmpeg', [
    '-y',
    '-f', 'concat', '-safe', '0', '-i', tmpListing,
    '-vf', 'scale=480:480:force_original_aspect_ratio=decrease,pad=480:480:(ow-iw)/2:(oh-ih)/2:color=black',
    '-c:v', 'libx265', '-tag:v', 'hvc1',
    '-pix_fmt', 'yuv420p',
    '-r', '24',
    '-crf', '28',
    '-an',
    '-movflags', '+faststart',
    mp4Path,
  ]);

  // WebP thumbnail from first frame.
  await run('ffmpeg', [
    '-y',
    '-i', localFrames[0],
    '-vf', 'scale=480:480:force_original_aspect_ratio=decrease,pad=480:480:(ow-iw)/2:(oh-ih)/2:color=black',
    '-q:v', '70',
    webpPath,
  ]);

  if (!hasVideo) {
    const buf = await readFile(mp4Path);
    await s3Upload(videoKey, buf, 'video/mp4');
  }
  if (!hasThumb) {
    const buf = await readFile(webpPath);
    await s3Upload(thumbKey, buf, 'image/webp');
  }

  manifest[ourName] = { video: videoURL, thumb: thumbURL };
  return { status: 'uploaded' };
}

// ---------- Main ----------

async function main() {
  const ourNames = await readOurExerciseNames();
  console.log(`Found ${ourNames.length} exercises in ExerciseDatabase.swift`);

  await ensureFreeDb();
  const catalog = await loadCatalog();
  const idx = buildIndex(catalog);
  console.log(`Loaded free-exercise-db catalog: ${catalog.length} exercises`);

  // Load existing manifest so we can incrementally extend.
  let manifest = {};
  if (existsSync(MANIFEST_OUT)) {
    try {
      manifest = JSON.parse(await readFile(MANIFEST_OUT, 'utf8'));
    } catch (e) {
      console.warn('Existing manifest is invalid JSON, starting fresh.');
    }
  }

  const unmatched = [];
  let uploaded = 0;
  let skipped = 0;

  for (const name of ourNames) {
    const match = matchExercise(name, catalog, idx);
    if (!match) {
      unmatched.push(name);
      continue;
    }
    process.stdout.write(`  ${name.padEnd(34)} -> ${match.name.padEnd(34)} `);
    try {
      const r = await processExercise(name, match, manifest);
      if (r.status === 'skipped') {
        skipped += 1;
        console.log('(cached)');
      } else if (r.status === 'no-frames') {
        console.log('(no frames in source — skipped)');
        unmatched.push(name);
      } else {
        uploaded += 1;
        console.log('done');
      }
    } catch (e) {
      console.log(`FAILED: ${e.message}`);
      unmatched.push(name);
    }
    // Persist manifest after each entry so partial runs aren't lost.
    const sorted = Object.fromEntries(Object.entries(manifest).sort(([a], [b]) => a.localeCompare(b)));
    await writeFile(MANIFEST_OUT, JSON.stringify(sorted, null, 2) + '\n');
  }

  console.log('\n=== Summary ===');
  console.log(`Uploaded: ${uploaded}`);
  console.log(`Skipped (already in bucket): ${skipped}`);
  console.log(`Unmatched: ${unmatched.length}`);
  if (unmatched.length) {
    console.log('  -- ' + unmatched.join('\n  -- '));
    console.log('\nAdd entries to the ALIASES table in build.mjs to fix matches.');
  }
  console.log(`\nManifest written to: ${MANIFEST_OUT}`);
  console.log('Add this file to your Xcode target so it ships in the bundle.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
