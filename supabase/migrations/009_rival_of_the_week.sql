-- Rival of the Week — picks the friend whose latest_score is closest to
-- the user's, fires a weekly push suggesting they challenge them.
--
-- The "closest score" heuristic solves Duolingo-leagues-for-1v1: it gives
-- everyone a winnable, motivating opponent each week (research finding —
-- decision paralysis on "who do I challenge" kills engagement).
--
-- Notification payload includes rival_user_id so the deep-link handler can
-- offer a one-tap challenge to that friend.

create or replace function notify_rivals_of_the_week()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_count int := 0;
    v_user record;
    v_rival record;
begin
    for v_user in
        select id, latest_score
          from user_profiles
         where latest_score is not null
    loop
        -- Pull this user's friends + scores. friendships is symmetric in
        -- canonical (user_a < user_b) form, so we union both sides.
        select fr.id, fr.username, fr.latest_score, abs(fr.latest_score - v_user.latest_score) as score_diff
          into v_rival
          from (
                select up.id, up.username, up.latest_score
                  from friendships f
                  join user_profiles up on up.id = f.user_b
                 where f.user_a = v_user.id and up.latest_score is not null
                 union all
                select up.id, up.username, up.latest_score
                  from friendships f
                  join user_profiles up on up.id = f.user_a
                 where f.user_b = v_user.id and up.latest_score is not null
          ) fr
         order by abs(fr.latest_score - v_user.latest_score) asc, fr.id
         limit 1;

        if v_rival.id is not null then
            perform _enqueue_notification(v_user.id, 'rival_of_the_week',
                jsonb_build_object(
                    'rival_user_id',  v_rival.id,
                    'rival_username', v_rival.username,
                    'rival_score',    v_rival.latest_score,
                    'score_diff',     v_rival.score_diff
                ));
            v_count := v_count + 1;
        end if;
    end loop;

    return jsonb_build_object('ok', true, 'sent', v_count);
end;
$$;

grant execute on function notify_rivals_of_the_week() to service_role;

do $$
begin
    if exists (select 1 from cron.job where jobname = 'notify_rivals_of_the_week') then
        perform cron.unschedule('notify_rivals_of_the_week');
    end if;
end $$;

-- Sunday 6pm UTC — same slot as weekly_digest. Sets up the week's narrative.
select cron.schedule(
    'notify_rivals_of_the_week',
    '0 18 * * 0',
    $cron$ select notify_rivals_of_the_week(); $cron$
);
