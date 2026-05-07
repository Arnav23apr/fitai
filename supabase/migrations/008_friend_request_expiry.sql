-- Friend request 14-day auto-expiry.
--
-- Why: pending requests pile up forever in the inbox. Research finding —
-- one of the top friend-system retention killers. Daily cron deletes any
-- request still in 'pending' state after 14 days.
--
-- We use deletion (rather than a status flip to 'expired') because:
--   - The check constraint doesn't allow 'expired' without a schema change
--   - The recipient never sees the request again — equivalent UX to expired
--   - The unique index on (from_user_id, to_user_id) for active requests
--     gets cleared automatically, so the sender can re-send if they want

create or replace function expire_stale_friend_requests()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_threshold timestamptz := now() - interval '14 days';
    v_deleted   int;
begin
    delete from friend_requests
     where status = 'pending'
       and created_at < v_threshold;
    get diagnostics v_deleted = row_count;
    return jsonb_build_object('ok', true, 'deleted', v_deleted);
end;
$$;

grant execute on function expire_stale_friend_requests() to service_role;

do $$
begin
    if exists (select 1 from cron.job where jobname = 'expire_stale_friend_requests') then
        perform cron.unschedule('expire_stale_friend_requests');
    end if;
end $$;

-- Daily at 3am UTC — middle of the night for most regions, low-traffic
select cron.schedule(
    'expire_stale_friend_requests',
    '0 3 * * *',
    $cron$ select expire_stale_friend_requests(); $cron$
);
