-- Auto-forfeit stale 1v1 challenges.
--
-- Why: photo battles where one side submits and the other ghosts kill
-- engagement (research finding). After 48h of inactivity we resolve the
-- challenge so the score timeline doesn't pile up indefinitely.
--
-- Rules (matches the auto-forfeit decision in the friend-system spec):
--   - Both submitted    → already 'completed', skip.
--   - One submitted     → submitter wins; status = 'completed'.
--   - Neither submitted → status = 'expired', no winner, no XP.
-- Threshold counts from the row's created_at because the moment a
-- challenge enters in_progress is when we start the clock for the second
-- submitter; we keep it simple and use the original created_at.

create or replace function auto_forfeit_stale_challenges()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_threshold timestamptz := now() - interval '48 hours';
    v_resolved  int := 0;
    v_expired   int := 0;
    v_ch        record;
begin
    for v_ch in
        select *
          from challenges
         where status in ('accepted', 'in_progress')
           and created_at < v_threshold
    loop
        if v_ch.challenger_score is not null and v_ch.opponent_score is null then
            -- Challenger submitted, opponent ghosted → challenger wins
            update challenges
               set status         = 'completed',
                   winner_user_id = v_ch.challenger_id,
                   completed_at   = now()
             where id = v_ch.id;
            perform _enqueue_notification(v_ch.challenger_id, 'challenge_won_forfeit',
                jsonb_build_object('challenge_id', v_ch.id, 'reason', 'opponent_no_show'));
            perform _enqueue_notification(v_ch.opponent_id, 'challenge_lost_forfeit',
                jsonb_build_object('challenge_id', v_ch.id, 'reason', 'no_response'));
            v_resolved := v_resolved + 1;

        elsif v_ch.opponent_score is not null and v_ch.challenger_score is null then
            -- Opponent submitted, challenger ghosted → opponent wins
            update challenges
               set status         = 'completed',
                   winner_user_id = v_ch.opponent_id,
                   completed_at   = now()
             where id = v_ch.id;
            perform _enqueue_notification(v_ch.opponent_id, 'challenge_won_forfeit',
                jsonb_build_object('challenge_id', v_ch.id, 'reason', 'opponent_no_show'));
            perform _enqueue_notification(v_ch.challenger_id, 'challenge_lost_forfeit',
                jsonb_build_object('challenge_id', v_ch.id, 'reason', 'no_response'));
            v_resolved := v_resolved + 1;

        else
            -- Neither side submitted → expire silently (no winner)
            update challenges
               set status       = 'expired',
                   completed_at = now()
             where id = v_ch.id;
            perform _enqueue_notification(v_ch.challenger_id, 'challenge_expired',
                jsonb_build_object('challenge_id', v_ch.id));
            perform _enqueue_notification(v_ch.opponent_id, 'challenge_expired',
                jsonb_build_object('challenge_id', v_ch.id));
            v_expired := v_expired + 1;
        end if;
    end loop;

    return jsonb_build_object(
        'ok', true,
        'resolved', v_resolved,
        'expired', v_expired
    );
end;
$$;

-- Schedule the cron job to run every 30 minutes. pg_cron is available on
-- all Supabase projects in the cron schema. Idempotent: drop any prior
-- schedule before re-creating so this migration is rerunnable.
create extension if not exists pg_cron with schema extensions;

do $$
begin
    if exists (select 1 from cron.job where jobname = 'auto_forfeit_stale_challenges') then
        perform cron.unschedule('auto_forfeit_stale_challenges');
    end if;
end $$;

select cron.schedule(
    'auto_forfeit_stale_challenges',
    '*/30 * * * *',
    $cron$ select auto_forfeit_stale_challenges(); $cron$
);

grant execute on function auto_forfeit_stale_challenges() to service_role;
