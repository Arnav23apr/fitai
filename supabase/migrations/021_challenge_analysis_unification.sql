-- ============================================================================
-- Migration 021 — challenge analysis persistence + verdict
--
-- The friends 1v1 challenge flow now reuses `BattleResultView` and
-- `BattleShareCardView` from the local 1v1 battle, which require a full
-- per-side breakdown (overall, muscle scores, potential, visible groups,
-- strong/weak points). The original schema only stored each side's
-- overall score, so reconstructing a PhysiqueBattle from a completed
-- challenge was impossible.
--
-- This migration:
--   1. Adds two jsonb columns to `challenges` for the full AnalysisResult
--      per side, plus a `verdict` text column for the AI commentary.
--   2. Updates `submit_challenge_score` to accept a `p_analysis jsonb`
--      param and write it into the side that's submitting.
--   3. Adds a new `set_challenge_verdict` RPC so the second submitter can
--      compute the verdict via the iOS AI service and persist it once.
--
-- Existing in-flight challenges keep working — analyses are nullable, so
-- pre-021 completed challenges that lack analyses get a graceful
-- fallback in the iOS client (the old simple result card).
-- ============================================================================

alter table challenges
    add column if not exists challenger_analysis jsonb,
    add column if not exists opponent_analysis jsonb,
    add column if not exists verdict text;

-- ----------------------------------------------------------------------------
-- submit_challenge_score (replaces 003_social.sql version)
--   New 4th param: p_analysis jsonb (nullable for forward-compat with
--   any client that hasn't shipped the analysis-capture change yet).
-- ----------------------------------------------------------------------------
create or replace function submit_challenge_score(
    p_challenge_id uuid,
    p_score double precision,
    p_photo_url text,
    p_analysis jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_row record;
    v_winner uuid;
    v_status text;
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select * into v_row from challenges where id = p_challenge_id;
    if v_row is null then
        return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    if v_me <> v_row.challenger_id and v_me <> v_row.opponent_id then
        return jsonb_build_object('ok', false, 'reason', 'not_participant');
    end if;

    if v_row.status = 'completed' then
        return jsonb_build_object('ok', false, 'reason', 'already_completed');
    end if;

    if v_me = v_row.challenger_id then
        update challenges set
            challenger_score      = p_score,
            challenger_photo_url  = coalesce(p_photo_url, challenger_photo_url),
            challenger_analysis   = coalesce(p_analysis, challenger_analysis)
         where id = p_challenge_id;
    else
        update challenges set
            opponent_score        = p_score,
            opponent_photo_url    = coalesce(p_photo_url, opponent_photo_url),
            opponent_analysis     = coalesce(p_analysis, opponent_analysis)
         where id = p_challenge_id;
    end if;

    -- Re-read so we evaluate the both-submitted condition with fresh values.
    select * into v_row from challenges where id = p_challenge_id;

    if v_row.challenger_score is not null and v_row.opponent_score is not null then
        if v_row.challenger_score > v_row.opponent_score then
            v_winner := v_row.challenger_id;
        elsif v_row.opponent_score > v_row.challenger_score then
            v_winner := v_row.opponent_id;
        else
            v_winner := null;  -- tie
        end if;
        v_status := 'completed';
        update challenges set
            status = v_status,
            winner_user_id = v_winner,
            completed_at = now()
         where id = p_challenge_id;

        -- Notify both sides that the challenge resolved so their apps
        -- refresh and surface BattleResultView.
        perform _enqueue_notification(
            v_row.challenger_id,
            'challenge_completed',
            jsonb_build_object('challenge_id', p_challenge_id, 'winner_user_id', v_winner)
        );
        perform _enqueue_notification(
            v_row.opponent_id,
            'challenge_completed',
            jsonb_build_object('challenge_id', p_challenge_id, 'winner_user_id', v_winner)
        );
    else
        v_status := 'in_progress';
        update challenges set status = v_status where id = p_challenge_id;
    end if;

    return jsonb_build_object('ok', true, 'status', v_status, 'winner_user_id', v_winner);
end;
$$;

grant execute on function submit_challenge_score(uuid, double precision, text, jsonb) to authenticated;

-- ----------------------------------------------------------------------------
-- set_challenge_verdict: stores the AI verdict text on a completed
-- challenge. Idempotent — if a verdict already exists, the call is a
-- no-op so concurrent "both submitters compute it" doesn't double-write
-- racing strings.
-- ----------------------------------------------------------------------------
create or replace function set_challenge_verdict(
    p_challenge_id uuid,
    p_verdict text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_me uuid := auth.uid();
    v_row record;
begin
    if v_me is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select * into v_row from challenges where id = p_challenge_id;
    if v_row is null then
        return jsonb_build_object('ok', false, 'reason', 'not_found');
    end if;

    if v_me <> v_row.challenger_id and v_me <> v_row.opponent_id then
        return jsonb_build_object('ok', false, 'reason', 'not_participant');
    end if;

    if v_row.status <> 'completed' then
        return jsonb_build_object('ok', false, 'reason', 'not_completed');
    end if;

    -- Idempotent: first writer wins.
    if v_row.verdict is not null and length(trim(v_row.verdict)) > 0 then
        return jsonb_build_object('ok', true, 'noop', true);
    end if;

    update challenges set verdict = p_verdict where id = p_challenge_id;
    return jsonb_build_object('ok', true);
end;
$$;

grant execute on function set_challenge_verdict(uuid, text) to authenticated;
