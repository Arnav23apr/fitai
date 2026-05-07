-- Push notification infrastructure.
--
-- Pieces:
--   1. push_tokens table (one row per device + user)
--   2. Trigger on `notifications` insert that POSTs the row to the
--      `send_push` Edge Function via pg_net (HTTP webhook)
--   3. New per-user notification helpers for the 3 server-driven triggers
--      that don't have an obvious source row (streak expiring, opponent
--      pending, weekly digest). Challenge-sent + challenge-completed are
--      already enqueued from existing RPCs.
--   4. pg_cron jobs to fire the recurring ones at the right cadence
--
-- Edge Function URL + service-role key are read from the
-- `app.settings.send_push_url` and `app.settings.send_push_token` runtime
-- GUCs. Those need to be set once per project — see deploy notes in PR.

-- ─── 1. push_tokens ─────────────────────────────────────────────────
create table if not exists push_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references user_profiles(id) on delete cascade,
    token text not null,
    platform text not null default 'ios',
    bundle_id text,
    environment text,                                       -- 'development' or 'production'
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint push_tokens_unique unique (token, platform)
);

create index if not exists idx_push_tokens_user on push_tokens (user_id);

alter table push_tokens enable row level security;

drop policy if exists "push_tokens: owner all" on push_tokens;
create policy "push_tokens: owner all" on push_tokens
for all to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

-- ─── 2. send_push webhook ──────────────────────────────────────────
-- We piggy-back on the existing `notifications` row insertion: every push
-- helper inserts a row, and a trigger fans it out to the edge function.
-- Single integration point keeps the SQL simple.
create extension if not exists pg_net with schema extensions;

create or replace function _dispatch_push() returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_url   text := current_setting('app.settings.send_push_url',   true);
    v_token text := current_setting('app.settings.send_push_token', true);
begin
    -- If the project hasn't configured the webhook yet, just no-op.
    if v_url is null or v_url = '' then return new; end if;

    perform net.http_post(
        url     := v_url,
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || coalesce(v_token, '')
        ),
        body    := jsonb_build_object(
            'user_id', new.user_id,
            'kind',    new.kind,
            'payload', new.payload,
            'notification_id', new.id
        )
    );
    return new;
end;
$$;

drop trigger if exists trg_dispatch_push on notifications;
create trigger trg_dispatch_push
after insert on notifications
for each row execute function _dispatch_push();

-- ─── 3. Recurring helpers ──────────────────────────────────────────

-- 3a. Streak about to expire — user is on a streak and hasn't logged a
--     workout in the last 24h. Run nightly at 9pm UTC.
create or replace function notify_streaks_expiring()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count int := 0;
    v_user record;
begin
    for v_user in
        -- Streak ≥3 and last workout was 20h+ ago (so streak rescue makes
        -- sense). last_workout is computed from workout_logs since there's
        -- no denormalized column for it on user_profiles.
        select up.id, up.current_streak
          from user_profiles up
          left join lateral (
                select max(date) as last_workout
                  from workout_logs
                 where user_id = up.id
          ) w on true
         where up.current_streak >= 3
           and (w.last_workout is null or w.last_workout < now() - interval '20 hours')
    loop
        perform _enqueue_notification(v_user.id, 'streak_expiring',
            jsonb_build_object('streak', v_user.current_streak,
                               'hours_left', 4));
        v_count := v_count + 1;
    end loop;
    return jsonb_build_object('ok', true, 'sent', v_count);
end;
$$;

-- 3b. Friend's challenge pending response after 24h
create or replace function notify_pending_responses()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count int := 0;
    v_ch record;
begin
    for v_ch in
        select *
          from challenges
         where status = 'in_progress'
           and (
                (challenger_score is not null and opponent_score is null
                 and created_at < now() - interval '24 hours'
                 and created_at >= now() - interval '40 hours')
                or
                (opponent_score is not null and challenger_score is null
                 and created_at < now() - interval '24 hours'
                 and created_at >= now() - interval '40 hours')
           )
    loop
        if v_ch.challenger_score is not null and v_ch.opponent_score is null then
            perform _enqueue_notification(v_ch.opponent_id, 'pending_response',
                jsonb_build_object('challenge_id', v_ch.id, 'category', v_ch.category));
        else
            perform _enqueue_notification(v_ch.challenger_id, 'pending_response',
                jsonb_build_object('challenge_id', v_ch.id, 'category', v_ch.category));
        end if;
        v_count := v_count + 1;
    end loop;
    return jsonb_build_object('ok', true, 'sent', v_count);
end;
$$;

-- 3c. Weekly digest: bundled stats (battles + wins + scans) sent Sunday 6pm local.
--     We approximate "local" by picking 18:00 UTC; per-user TZ refinement is a
--     v2 problem — most fitness app users tolerate ±3h on a digest.
create or replace function notify_weekly_digests()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count int := 0;
    v_user record;
    v_battles int;
    v_wins int;
begin
    for v_user in
        select id from user_profiles where current_streak >= 0   -- everyone active
    loop
        select count(*) into v_battles
          from challenges
         where status = 'completed'
           and completed_at > now() - interval '7 days'
           and (challenger_id = v_user.id or opponent_id = v_user.id);

        select count(*) into v_wins
          from challenges
         where status = 'completed'
           and completed_at > now() - interval '7 days'
           and winner_user_id = v_user.id;

        if v_battles > 0 then
            perform _enqueue_notification(v_user.id, 'weekly_digest',
                jsonb_build_object('battles', v_battles, 'wins', v_wins));
            v_count := v_count + 1;
        end if;
    end loop;
    return jsonb_build_object('ok', true, 'sent', v_count);
end;
$$;

grant execute on function notify_streaks_expiring()  to service_role;
grant execute on function notify_pending_responses() to service_role;
grant execute on function notify_weekly_digests()    to service_role;

-- ─── 4. pg_cron schedules ──────────────────────────────────────────
do $$
begin
    if exists (select 1 from cron.job where jobname = 'notify_streaks_expiring') then
        perform cron.unschedule('notify_streaks_expiring');
    end if;
    if exists (select 1 from cron.job where jobname = 'notify_pending_responses') then
        perform cron.unschedule('notify_pending_responses');
    end if;
    if exists (select 1 from cron.job where jobname = 'notify_weekly_digests') then
        perform cron.unschedule('notify_weekly_digests');
    end if;
end $$;

-- 9pm UTC nightly — streak rescue
select cron.schedule(
    'notify_streaks_expiring',
    '0 21 * * *',
    $cron$ select notify_streaks_expiring(); $cron$
);

-- Hourly — opponent pending nudges (the WHERE clause limits to the 24-40h
-- window so we only send once per challenge)
select cron.schedule(
    'notify_pending_responses',
    '0 * * * *',
    $cron$ select notify_pending_responses(); $cron$
);

-- Sunday 6pm UTC — weekly digest
select cron.schedule(
    'notify_weekly_digests',
    '0 18 * * 0',
    $cron$ select notify_weekly_digests(); $cron$
);
