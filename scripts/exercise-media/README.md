# Exercise media build pipeline

One-shot script that:

1. Pulls exercise GIFs from [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db) (MIT license).
2. Fuzzy-matches them to the names hard-coded in `ios/FitAIPremiumFitnessApp/Services/ExerciseDatabase.swift`.
3. Converts each GIF to a small looping HEVC MP4 + a WebP thumbnail via `ffmpeg`.
4. Uploads both to an S3-compatible bucket (Cloudflare R2 recommended; Supabase Storage also works via its S3 endpoint).
5. Writes `exercise_media.json` into the iOS bundle so the app can resolve a video URL for any exercise name.

## Prereqs

- Node 18+
- `ffmpeg` on PATH (`brew install ffmpeg`)
- An S3-compatible bucket. For **Cloudflare R2**: create a bucket, generate an API token with read/write, enable a public r2.dev URL or attach a custom domain.

## Configure

Copy `.env.example` to `.env` and fill in your bucket details:

```
S3_ENDPOINT=https://<account>.r2.cloudflarestorage.com
S3_REGION=auto
S3_BUCKET=fitai-exercise-media
S3_ACCESS_KEY_ID=...
S3_SECRET_ACCESS_KEY=...
PUBLIC_BASE_URL=https://pub-<hash>.r2.dev      # or your CDN/custom domain
```

## Run

```
npm install
node build.mjs
```

The first run takes ~10 minutes (downloads ~870 GIFs, converts each, uploads). Subsequent runs are incremental — already-uploaded files are skipped.

The script emits a report of unmatched exercise names so you can decide whether to add aliases or accept that those entries will fall back to text-only.

## Output

- `ios/FitAIPremiumFitnessApp/exercise_media.json` — committed to the repo, bundled with the app.
- Files in your S3 bucket under `exercises/<slug>.mp4` and `exercises/<slug>.webp`.

## Re-running

If you change exercises in `ExerciseDatabase.swift`, rerun the script — it diffs against the existing manifest and only processes new/changed entries.
