#!/usr/bin/env node
// Stopgap manifest generator. Writes exercise_media.json with direct GitHub
// raw URLs from yuhonas/free-exercise-db so the app can show *something*
// without needing R2/ffmpeg/upload set up. Replace by running build.mjs
// once the production pipeline is configured.

import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const EXERCISE_DB_SWIFT = path.join(REPO_ROOT, 'ios', 'FitAIPremiumFitnessApp', 'Services', 'ExerciseDatabase.swift');
const MANIFEST_OUT = path.join(REPO_ROOT, 'ios', 'FitAIPremiumFitnessApp', 'exercise_media.json');
const CATALOG_URL = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json';
const RAW_BASE = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';

function normalize(name) {
  const noise = new Set(['the', 'a', 'an', 'with', 'and', 'on', 'in']);
  return name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean)
    .filter((w) => !noise.has(w))
    .sort()
    .join(' ');
}

const ALIASES = {
  'Push-Ups': 'Pushups',
  'Pull-Ups': 'Pullups',
  'Chin-Ups': 'Chin-Up',
  'Pike Push-Ups': 'Pushups',
  'Diamond Push-Ups': 'Pushups - Close Triceps Position',
  'Decline Push-Ups': 'Decline Pushups',
  'Lateral Raises': 'Side Lateral Raise',
  'Cable Flyes': 'Cable Crossover',
  'Tricep Pushdowns': 'Tricep Side Pushdown',
  'Overhead Tricep Extension': 'Standing Dumbbell Triceps Extension',
  'Barbell Curls': 'Barbell Curl',
  'Hammer Curls': 'Hammer Curls',
  'Incline Curls': 'Incline Inner Biceps Curl',
  'Walking Lunges': 'Bodyweight Walking Lunge',
  'Calf Raises': 'Standing Calf Raises',
  'Leg Curl': 'Lying Leg Curls',
  'Leg Extensions': 'Leg Extensions',
  'Bulgarian Split Squats': 'Bodyweight Squat',
  'Glute Bridges': 'Hip Lift With Band',
  'Jump Squats': 'Squat Jump',
  'Hanging Leg Raises': 'Hanging Leg Raise',
  'Russian Twists': 'Seated Barbell Twist',
  'Mountain Climbers': 'Mountain Climbers',
  'Dumbbell Lunges': 'Dumbbell Lunges',
  'Tricep Dips': 'Bench Dips',
  'Leg Raises': 'Lying Leg Raise (Top, Toes Forward, Bent Knees)',
  'Hip Thrusts': 'Hip Thrust',
  'Front Squats': 'Front Barbell Squat',
  'Inverted Rows': 'Inverted Row',
  'Dips (Chair)': 'Bench Dips',
  'Doorway Curls': 'Hammer Curls',
  'Band Face Pulls': 'Face Pull',
  'Face Pulls': 'Face Pull',
  'Single Leg RDL': 'Single Leg Romanian Deadlift',
  'Pistol Squat Progression': 'Bodyweight Squat',
  'Wall Sit': 'Wall Sit',
  'Superman Hold': 'Superman',
  'Cable Woodchops': 'Cable Crossover',
  'Cable Rows': 'Seated Cable Rows',
  'Seated Cable Row': 'Seated Cable Rows',
  'Lat Pulldown': 'Wide-Grip Lat Pulldown',
  'Barbell Rows': 'Bent Over Barbell Row',
  'Barbell Bench Press': 'Barbell Bench Press - Medium Grip',
  'Incline Dumbbell Press': 'Incline Dumbbell Press',
  'Overhead Press': 'Standing Military Press',
  'Dumbbell Bench Press': 'Dumbbell Bench Press',
  'Dumbbell Shoulder Press': 'Dumbbell Shoulder Press',
  'Arnold Press': 'Seated Dumbbell Press',
  'Barbell Squat': 'Barbell Squat',
  'Romanian Deadlift': 'Romanian Deadlift',
  'Leg Press': 'Leg Press',
  'Deadlift': 'Barbell Deadlift',
  'Plank': 'Plank',
};

async function main() {
  console.log('Fetching catalog...');
  const res = await fetch(CATALOG_URL);
  if (!res.ok) throw new Error(`catalog fetch failed: ${res.status}`);
  const catalog = await res.json();

  // Index by normalized name AND by exact name for direct alias hits.
  const byNormalized = new Map();
  const byExact = new Map();
  for (const ex of catalog) {
    byNormalized.set(normalize(ex.name), ex);
    byExact.set(ex.name, ex);
  }

  const src = await readFile(EXERCISE_DB_SWIFT, 'utf8');
  const ourNames = [...src.matchAll(/db\["([^"]+)"\]\s*=\s*ExerciseDemoInfo\(/g)].map((m) => m[1]);
  console.log(`Our exercises: ${ourNames.length}`);

  const manifest = {};
  const unmatched = [];

  for (const name of ourNames) {
    const candidates = [ALIASES[name], name].filter(Boolean);
    let hit = null;
    for (const c of candidates) {
      hit = byExact.get(c) ?? byNormalized.get(normalize(c));
      if (hit) break;
    }
    if (!hit) {
      // Token-overlap fallback.
      const ourTokens = new Set(normalize(name).split(' '));
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
      if (bestScore >= 0.6) hit = best;
    }
    if (!hit || !hit.images?.length) {
      unmatched.push(name);
      continue;
    }
    const frames = hit.images.map((p) => `${RAW_BASE}/${p}`);
    manifest[name] = {
      video: '',
      thumb: frames[0],
      frames,
    };
  }

  const sorted = Object.fromEntries(Object.entries(manifest).sort(([a], [b]) => a.localeCompare(b)));
  await writeFile(MANIFEST_OUT, JSON.stringify(sorted, null, 2) + '\n');
  console.log(`Matched: ${Object.keys(manifest).length}`);
  console.log(`Unmatched: ${unmatched.length}`);
  if (unmatched.length) console.log('  ' + unmatched.join('\n  '));
  console.log(`Wrote: ${MANIFEST_OUT}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
