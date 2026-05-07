# FitAI Moderation Workflow

This document is the source of truth for how user reports are reviewed and acted on. It covers App Store **Guideline 1.2 (User-Generated Content)** — Apple expects every UGC app to have a documented review process and a 24-hour response SLA.

If App Review asks how moderation works, point them here.

## What gets reported

Users can report another account from the friend list or anywhere a profile is visible (`ReportUserSheet`). Reports land in the `public.reports` table with:

- `reporter_id`
- `reported_user_id`
- `reason` — one of: `harassment`, `inappropriate_photo`, `fake_account`, `spam`, `underage`, `other`
- `details` — free-text (optional)
- `created_at`

The table has RLS that **forbids client reads** (`reports_read_none`). Reports are only readable via the Supabase service role key (i.e., from this dashboard / SQL Editor — never from the app).

## Review SLA

- **Triage within 24h** of report submission (Apple Guideline 1.2 expectation)
- **Action within 48h** for reports labelled `harassment`, `inappropriate_photo`, or `underage`
- **Action within 7 days** for `spam`, `fake_account`, `other`

Owner: **George** (primary), **Arnav** (backup if George is unavailable).

## Review cadence

Run the queries below at minimum **once every 24 hours**. Pin a recurring calendar reminder.

### 1. Pull all unhandled reports from the last 7 days

```sql
select
    r.id,
    r.created_at,
    r.reason,
    r.details,
    reporter.username  as reporter_username,
    reported.username  as reported_username,
    reported.id        as reported_user_id
from public.reports r
join public.user_profiles reporter on reporter.id = r.reporter_id
join public.user_profiles reported on reported.id = r.reported_user_id
where r.created_at > now() - interval '7 days'
order by r.created_at desc;
```

### 2. Decide an outcome for each report

For each row, choose one:

#### a) No action — reporter being abusive or report unfounded
Just leave the row. Optionally add a `reviewed_at` column if we want to mark it (future migration).

#### b) Warn the user (light touch — first offence, ambiguous)
Send an email manually, no in-app action.

#### c) Force username change (offensive username)
```sql
update public.user_profiles
set username = '',
    username_changed_at = now()
where id = '<reported_user_id>';
```

The user will be prompted to pick a new username on next launch (handled by the existing onboarding flow — empty username triggers selection).

#### d) Suspend the account (repeat offender or severe violation)
There's no first-class suspension flag yet. Workaround: add a row to `blocks` from a marker UUID, OR delete the user via Supabase Auth dashboard (Auth → Users → Delete). The `on delete cascade` in `user_profiles` cleans up everything else.

#### e) Permanent ban
Same as suspension. Note the email + `auth.users` UUID in a private spreadsheet so the same email can't re-register. (Future: add a `banned_emails` table.)

### 3. Notify the reporter (optional but increases trust)

For `harassment` / `inappropriate_photo` / `underage` reports, email the reporter once you've actioned the report. Template:

> Hi @{username},
>
> Thanks for reporting @{reported}. We reviewed and took action. Your safety is the priority — keep flagging anything that crosses the line.
>
> — FitAI

## What to tell App Review

If a reviewer asks about UGC moderation, paste this in the App Review notes field:

> User-generated content in FitAI is limited to: chosen username, display name, optional short bio, and avatar (system icon or photo).
>
> All usernames go through a **server-side trigger** (`enforce_username_policy`, `004_moderation.sql`) that rejects reserved names, slurs, sexual terms, and impersonation patterns. Profanity is enforced at the database layer so client-side bypass is impossible.
>
> Users can **report** any other user (`ReportUserSheet`) and **block** them (`BlockListSheet`). Reports go to a server-only `reports` table. We review reports within 24h and take action within 48h for harassment / explicit / underage flags. Workflow is documented at `supabase/MODERATION.md`.
>
> Friend request volume is rate-limited at 50 / hour / user (`send_friend_request` RPC) to prevent harassment via spam.
>
> Privacy controls let any user set their account to **private** (no leaderboard, no activity feed) or disable username search.

## Future improvements

- Add `reviewed_at` + `reviewed_by` + `outcome` columns to `reports` so we have an audit trail
- Slack / email webhook on every new report (Supabase database webhook → Slack channel)
- `banned_emails` table to prevent re-registration after permanent ban
- Self-serve account suspension flag with auto-restore after 30 days for first offences
- Image moderation (when avatar uploads include arbitrary photos) — currently bypassed because we ship system SF Symbol avatars + PhotosPicker uploads. Run uploaded photos through Apple's `Vision` `VNClassifyImageRequest` or AWS Rekognition Moderation if explicit-imagery reports increase.
