-- User profiles table: stores all onboarding + training data tied to auth.users
create table if not exists user_profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    name text not null default '',
    username text not null default '',
    email text not null default '',
    bio text not null default '',
    avatar_system_name text not null default 'person.crop.circle.fill',
    gender text not null default '',
    date_of_birth timestamptz,
    height_cm double precision not null default 175,
    weight_kg double precision not null default 75,
    uses_metric boolean not null default false,
    selected_language text not null default 'English',
    force_dark_mode boolean not null default false,
    workouts_per_week int not null default 3,
    training_experience text not null default '',
    training_location text not null default '',
    training_confidence int not null default 5,
    primary_goal text not null default '',
    holding_back text[] not null default '{}',
    goals text[] not null default '{}',
    referral_code text not null default '',
    is_premium boolean not null default false,
    spin_discount int,
    free_scans_earned int not null default 0,
    total_scans int not null default 0,
    total_workouts int not null default 0,
    current_streak int not null default 0,
    points int not null default 0,
    tier text not null default 'Bronze',
    latest_score double precision,
    last_scan_date timestamptz,
    weak_points text[] not null default '{}',
    strong_points text[] not null default '{}',
    completed_days_this_week text[] not null default '{}',
    week_start_date timestamptz,
    has_completed_onboarding boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Row Level Security: users can only read/write their own profile
alter table user_profiles enable row level security;

create policy "Users can read own profile"
    on user_profiles for select
    using (auth.uid() = id);

create policy "Users can insert own profile"
    on user_profiles for insert
    with check (auth.uid() = id);

create policy "Users can update own profile"
    on user_profiles for update
    using (auth.uid() = id);

-- Scan history table
create table if not exists scan_history (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    date timestamptz not null,
    overall_score double precision not null,
    potential_rating double precision not null,
    muscle_mass_rating text not null default '',
    strong_points text[] not null default '{}',
    weak_points text[] not null default '{}',
    summary text not null default '',
    recommendations text[] not null default '{}',
    muscle_scores jsonb not null default '{}',
    created_at timestamptz not null default now()
);

alter table scan_history enable row level security;

create policy "Users can read own scans"
    on scan_history for select
    using (auth.uid() = user_id);

create policy "Users can insert own scans"
    on scan_history for insert
    with check (auth.uid() = user_id);

-- Workout logs table
create table if not exists workout_logs (
    id text primary key,
    user_id uuid not null references auth.users(id) on delete cascade,
    date timestamptz not null,
    day_name text not null default '',
    exercises_completed int not null default 0,
    total_exercises int not null default 0,
    duration_minutes int not null default 0,
    completed_exercise_names text[] not null default '{}',
    created_at timestamptz not null default now()
);

alter table workout_logs enable row level security;

create policy "Users can read own workouts"
    on workout_logs for select
    using (auth.uid() = user_id);

create policy "Users can insert own workouts"
    on workout_logs for insert
    with check (auth.uid() = user_id);

-- Index for fast lookups
create index if not exists idx_scan_history_user on scan_history(user_id, date desc);
create index if not exists idx_workout_logs_user on workout_logs(user_id, date desc);

-- Auto-update updated_at on user_profiles
create or replace function update_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger user_profiles_updated_at
    before update on user_profiles
    for each row execute function update_updated_at();
