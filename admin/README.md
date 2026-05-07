# FitAI Admin

Internal-only admin dashboard for FitAI. Single user. Read-only v1.

Pages:
- **Overview** — KPIs (users, signups, premium count, subs, feedback / reports counts) + recent activity
- **Reports** — every UGC report joined with reporter + reported profiles
- **Feedback** — every in-app feedback submission with device metadata
- **Users** — latest 200 users with stats
- **Revenue** — premium count from DB + active subscribers from RevenueCat + link to full RevenueCat dashboard

## Stack

- Next.js 15 (App Router) + React 19 + TypeScript
- Tailwind CSS + Tremor (charts/tables)
- Supabase JS (server-side, service role key — bypasses RLS)
- RevenueCat REST v2 (optional; degrades gracefully if not configured)
- Auth: signed cookie (HMAC-SHA256), single hardcoded admin

## Local setup

```sh
cd admin
cp .env.example .env.local
# Fill in env vars (see below)
npm install
npm run dev
# Open http://localhost:3000 → /login
```

## Required env vars

| Var | Purpose |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service-role secret. Never commit. Never expose to browser. Read from Supabase Studio → Project Settings → API → `service_role`. |
| `ADMIN_EMAIL` | Login email |
| `ADMIN_PASSWORD` | Login password |
| `SESSION_SECRET` | 32-byte random hex. Generate with `openssl rand -hex 32`. |

## Optional env vars (for `/revenue`)

| Var | Purpose |
|---|---|
| `REVENUECAT_SECRET_KEY` | RevenueCat → Project settings → API keys → "Secret API key (v2)" |
| `REVENUECAT_PROJECT_ID` | RevenueCat → Project settings → general |

If unset, `/revenue` shows the DB-only premium count and a link to RevenueCat.

## Default credentials (local-only — change before deploy)

```
email:    team@fitai.health
password: FitAI-Admin-2026!
```

These are placeholders in `.env.example`. **Override on Vercel before going live.**

## Deploy to Vercel

1. Push `admin/` to a GitHub repo (separate repo recommended; can also use a monorepo with project root set to `admin/`).
2. Import the repo on Vercel.
3. **Set Root Directory to `admin`** if you kept it in this monorepo.
4. Add all env vars from above (Settings → Environment Variables → Production + Preview).
5. Deploy. Default URL like `fitai-admin.vercel.app`.
6. Optional: add custom domain `admin.fitai.app` — point a CNAME at `cname.vercel-dns.com`.

## Database access

The dashboard uses the Supabase **service role key**, which bypasses RLS. This is intentional — admins need to read `reports` (which is `for select using (false)` to clients) and `user_feedback` (same).

If the service role key ever leaks, **rotate it immediately** in Supabase Studio → Project Settings → API.

## Read-only by design (v1)

No destructive actions in the UI. Username forces, account suspensions, marking reports resolved, etc., still go through Supabase Studio SQL Editor. This is deliberate — it's safer to nuke prod data via a deliberate paste than via a button click. Once the dashboard has been used for a few weeks and the admin trusts the workflows, action buttons can be added with confirmation modals.

The moderation playbook lives in `../supabase/MODERATION.md`.

## Security notes

- Service role key is server-only. Never exposed to the browser. Don't import `lib/supabase.ts` from a Client Component.
- Session cookie is HTTP-only, `Secure` in production, `SameSite=Lax`, signed with `SESSION_SECRET`. Forging or extending the expiry is impossible without the secret.
- Login endpoint does not log credentials. Failed logins return generic "Invalid email or password" — no enumeration.
- No rate limiting on `/api/login`. If you start getting brute-force attempts, add Vercel Edge Middleware rate limit or move to Vercel Pro for built-in protection. Not a v1 concern for an unindexed admin URL.

## Known limits / v2 ideas

- No write actions (force-rename, mark resolved, suspend) — punted to Supabase Studio.
- No drilldown user profile pages — click → expand inline only.
- No charts beyond KPI cards — Tremor `LineChart` / `BarChart` for signups-over-time, MRR-over-time would be a nice add.
- No real-time push — pages re-fetch on navigation. Add `revalidate: 30` or polling if needed.
- No 2FA. Single user, single password, signed cookie. Fine for an unlinked admin URL; would need 2FA before adding more team members.
