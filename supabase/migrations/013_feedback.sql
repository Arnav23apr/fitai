-- ============================================================================
-- 005_feedback.sql
--
-- In-app feedback / bug-report capture.
--   - `user_feedback` table holds every submission.
--   - Clients can INSERT their own rows via the `submit_feedback` RPC; no
--     direct SELECT (admin reads via service role only).
--   - Rate-limited to 20 submissions per user per 24h to prevent spam.
--
-- Safe to re-run.
-- ============================================================================

create table if not exists user_feedback (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references user_profiles(id) on delete cascade,
    kind text not null check (kind in ('bug', 'suggestion', 'question', 'other')),
    message text not null check (length(trim(message)) between 5 and 4000),
    app_version text,
    ios_version text,
    device_model text,
    -- Lifecycle (admin-only writes via service role).
    status text not null default 'new'
        check (status in ('new', 'reviewing', 'resolved', 'wont_fix')),
    reviewed_at timestamptz,
    reviewed_by uuid references user_profiles(id) on delete set null,
    admin_notes text not null default '',
    created_at timestamptz not null default now()
);

create index if not exists user_feedback_user_idx on user_feedback (user_id, created_at desc);
create index if not exists user_feedback_status_idx on user_feedback (status, created_at desc);
create index if not exists user_feedback_kind_idx on user_feedback (kind, created_at desc);

alter table user_feedback enable row level security;

-- Clients cannot read feedback rows directly. Admin pulls via service role.
drop policy if exists user_feedback_no_client_read on user_feedback;
create policy user_feedback_no_client_read on user_feedback
    for select using (false);

-- Inserts go exclusively through the RPC (security definer), so no client
-- INSERT policy is needed — but we lock it down explicitly anyway.
drop policy if exists user_feedback_no_client_insert on user_feedback;
create policy user_feedback_no_client_insert on user_feedback
    for insert with check (false);

-- ----------------------------------------------------------------------------
-- submit_feedback: clients call this RPC to submit a row.
-- Rate-limited at 20 submissions per rolling 24h per user.
-- ----------------------------------------------------------------------------

create or replace function submit_feedback(
    p_kind text,
    p_message text,
    p_app_version text default null,
    p_ios_version text default null,
    p_device_model text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_recent_count int;
    v_message text := trim(coalesce(p_message, ''));
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    if p_kind not in ('bug', 'suggestion', 'question', 'other') then
        return jsonb_build_object('ok', false, 'reason', 'invalid_kind');
    end if;

    if length(v_message) < 5 then
        return jsonb_build_object('ok', false, 'reason', 'message_too_short');
    end if;

    if length(v_message) > 4000 then
        return jsonb_build_object('ok', false, 'reason', 'message_too_long');
    end if;

    -- Rate limit: 20 submissions per rolling 24 hours per user.
    select count(*) into v_recent_count
    from user_feedback
    where user_id = v_me
      and created_at > now() - interval '24 hours';

    if v_recent_count >= 20 then
        return jsonb_build_object('ok', false, 'reason', 'rate_limited');
    end if;

    insert into user_feedback (
        user_id, kind, message, app_version, ios_version, device_model
    ) values (
        v_me,
        p_kind,
        v_message,
        nullif(trim(coalesce(p_app_version, '')), ''),
        nullif(trim(coalesce(p_ios_version, '')), ''),
        nullif(trim(coalesce(p_device_model, '')), '')
    );

    return jsonb_build_object('ok', true);
end;
$$;
