-- 017_data_persistence.sql
--
-- Closes the gap where per-set exercise data, body measurements, routines,
-- custom exercises, and several profile fields lived only in iOS UserDefaults
-- — losing them on every logout/reinstall. Each new table mirrors the iOS
-- Codable model; complex nested structures (sets, routine sections) are
-- stored as jsonb.
--
-- Idempotent: every CREATE TABLE / ALTER TABLE uses IF NOT EXISTS, and
-- policies use DROP POLICY IF EXISTS before CREATE POLICY (Postgres has
-- no IF NOT EXISTS for policies). Safe to re-run on partial failure.

-- =============================================================
-- exercise_logs — per-set workout detail (PRs, reps, weight)
-- =============================================================

create table if not exists exercise_logs (
    id              text primary key,
    user_id         uuid not null references auth.users(id) on delete cascade,
    exercise_name   text not null,
    muscle_group    text not null default '',
    date            timestamptz not null,
    sets            jsonb not null default '[]'::jsonb,
    total_volume    double precision not null default 0,
    created_at      timestamptz not null default now()
);

alter table exercise_logs enable row level security;

drop policy if exists "Users can read own exercise logs" on exercise_logs;
create policy "Users can read own exercise logs"
    on exercise_logs for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own exercise logs" on exercise_logs;
create policy "Users can insert own exercise logs"
    on exercise_logs for insert
    with check (auth.uid() = user_id);

drop policy if exists "Users can update own exercise logs" on exercise_logs;
create policy "Users can update own exercise logs"
    on exercise_logs for update
    using (auth.uid() = user_id);

drop policy if exists "Users can delete own exercise logs" on exercise_logs;
create policy "Users can delete own exercise logs"
    on exercise_logs for delete
    using (auth.uid() = user_id);

create index if not exists idx_exercise_logs_user_date
    on exercise_logs(user_id, date desc);

create index if not exists idx_exercise_logs_user_name
    on exercise_logs(user_id, exercise_name);

-- =============================================================
-- body_measurements — Hevy/Strong-style measurement snapshots
-- =============================================================

create table if not exists body_measurements (
    id                text primary key,
    user_id           uuid not null references auth.users(id) on delete cascade,
    date              timestamptz not null,
    weight_kg         double precision,
    chest_cm          double precision,
    waist_cm          double precision,
    hips_cm           double precision,
    left_arm_cm       double precision,
    right_arm_cm      double precision,
    left_thigh_cm     double precision,
    right_thigh_cm    double precision,
    left_calf_cm      double precision,
    right_calf_cm     double precision,
    neck_cm           double precision,
    shoulders_cm      double precision,
    notes             text not null default '',
    created_at        timestamptz not null default now()
);

alter table body_measurements enable row level security;

drop policy if exists "Users can read own body measurements" on body_measurements;
create policy "Users can read own body measurements"
    on body_measurements for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own body measurements" on body_measurements;
create policy "Users can insert own body measurements"
    on body_measurements for insert
    with check (auth.uid() = user_id);

drop policy if exists "Users can update own body measurements" on body_measurements;
create policy "Users can update own body measurements"
    on body_measurements for update
    using (auth.uid() = user_id);

drop policy if exists "Users can delete own body measurements" on body_measurements;
create policy "Users can delete own body measurements"
    on body_measurements for delete
    using (auth.uid() = user_id);

create index if not exists idx_body_measurements_user_date
    on body_measurements(user_id, date desc);

-- =============================================================
-- user_routines — custom user-built workout routines
-- =============================================================
-- Stored as a jsonb blob (the entire Routine object) so the schema
-- doesn't need to track every nested model change. Server treats it
-- as opaque; iOS encodes/decodes via JSONEncoder.

create table if not exists user_routines (
    id          text primary key,
    user_id     uuid not null references auth.users(id) on delete cascade,
    payload     jsonb not null,
    updated_at  timestamptz not null default now(),
    created_at  timestamptz not null default now()
);

alter table user_routines enable row level security;

drop policy if exists "Users can read own routines" on user_routines;
create policy "Users can read own routines"
    on user_routines for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own routines" on user_routines;
create policy "Users can insert own routines"
    on user_routines for insert
    with check (auth.uid() = user_id);

drop policy if exists "Users can update own routines" on user_routines;
create policy "Users can update own routines"
    on user_routines for update
    using (auth.uid() = user_id);

drop policy if exists "Users can delete own routines" on user_routines;
create policy "Users can delete own routines"
    on user_routines for delete
    using (auth.uid() = user_id);

create index if not exists idx_user_routines_user
    on user_routines(user_id, updated_at desc);

-- =============================================================
-- custom_exercises — user-defined exercises not in bundled catalog
-- =============================================================

create table if not exists custom_exercises (
    id                 text primary key,
    user_id            uuid not null references auth.users(id) on delete cascade,
    name               text not null,
    primary_muscle     text not null default '',
    secondary_muscles  text[] not null default '{}',
    notes              text not null default '',
    created_at         timestamptz not null default now()
);

alter table custom_exercises enable row level security;

drop policy if exists "Users can read own custom exercises" on custom_exercises;
create policy "Users can read own custom exercises"
    on custom_exercises for select
    using (auth.uid() = user_id);

drop policy if exists "Users can insert own custom exercises" on custom_exercises;
create policy "Users can insert own custom exercises"
    on custom_exercises for insert
    with check (auth.uid() = user_id);

drop policy if exists "Users can update own custom exercises" on custom_exercises;
create policy "Users can update own custom exercises"
    on custom_exercises for update
    using (auth.uid() = user_id);

drop policy if exists "Users can delete own custom exercises" on custom_exercises;
create policy "Users can delete own custom exercises"
    on custom_exercises for delete
    using (auth.uid() = user_id);

create index if not exists idx_custom_exercises_user
    on custom_exercises(user_id, created_at desc);

-- =============================================================
-- user_profiles — additional columns previously dropped on sync
-- =============================================================

alter table user_profiles
    add column if not exists photo_consent_version    int     not null default 0;
alter table user_profiles
    add column if not exists photo_consent_granted_at timestamptz;
alter table user_profiles
    add column if not exists available_equipment      text[]  not null default '{}';
alter table user_profiles
    add column if not exists ai_chat_messages_used    int     not null default 0;
alter table user_profiles
    add column if not exists photo_improvement_opt_in boolean not null default false;

-- Notification preferences (jsonb so we can evolve the shape without
-- migrations). Persisting on the profile so prefs follow the user across
-- devices instead of resetting every reinstall.
alter table user_profiles
    add column if not exists notification_prefs jsonb;

-- Profile avatar — URL into a public Supabase Storage bucket. Set to NULL
-- when the user uses an SF Symbol avatar instead of a custom photo.
alter table user_profiles
    add column if not exists profile_photo_url text;
