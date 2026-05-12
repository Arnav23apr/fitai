-- ============================================================================
-- 023_exercise_notes.sql
--
-- Per-user pinned exercise notes. Strong-style "use foot plate at hole 4"
-- text strings that surface above the exercise card every session.
-- Previously stored only in UserDefaults on the device, which meant
-- reinstalling or switching devices silently destroyed the user's notes.
--
-- One row per (user_id, exercise_name). `exercise_name` is the
-- lowercased name (matches the client lookup key in ExerciseNoteService).
-- Body is freeform text. `updated_at` lets us pick the freshest version
-- if conflict resolution is ever added.
--
-- RLS: users can only see/write their own notes.
-- Safe to re-run.
-- ============================================================================

create table if not exists public.exercise_notes (
    user_id        uuid not null references public.user_profiles(id) on delete cascade,
    exercise_name  text not null,
    body           text not null,
    updated_at     timestamptz not null default now(),
    primary key (user_id, exercise_name)
);

create index if not exists idx_exercise_notes_user
    on public.exercise_notes (user_id);

alter table public.exercise_notes enable row level security;

drop policy if exists "exercise_notes own select" on public.exercise_notes;
create policy "exercise_notes own select"
    on public.exercise_notes
    for select
    using (auth.uid() = user_id);

drop policy if exists "exercise_notes own insert" on public.exercise_notes;
create policy "exercise_notes own insert"
    on public.exercise_notes
    for insert
    with check (auth.uid() = user_id);

drop policy if exists "exercise_notes own update" on public.exercise_notes;
create policy "exercise_notes own update"
    on public.exercise_notes
    for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

drop policy if exists "exercise_notes own delete" on public.exercise_notes;
create policy "exercise_notes own delete"
    on public.exercise_notes
    for delete
    using (auth.uid() = user_id);

-- Trigger to bump updated_at on every UPDATE so the freshest body wins.
create or replace function public._exercise_notes_touch()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_exercise_notes_touch on public.exercise_notes;
create trigger trg_exercise_notes_touch
    before update on public.exercise_notes
    for each row execute function public._exercise_notes_touch();
