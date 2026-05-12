-- ============================================================================
-- 025_user_search.sql
--
-- Instagram-style "search-as-you-type" friend discovery. The previous
-- LeaderboardService.searchUser does an exact `username = eq.X` match,
-- which means a single typo returns nothing — users have to know the
-- handle character-perfect.
--
-- This migration enables pg_trgm and adds a SECURITY DEFINER RPC that
-- ranks candidates by trigram similarity against both `username` and
-- `display_name`, with a hard prefix boost so "alex" still puts
-- @alex_lifts above @felix_climbs. Returns up to N matches above a
-- minimum similarity floor — when the query is one letter off, the
-- closest valid handles still surface so the user can pick the right
-- one instead of getting "not found".
-- ============================================================================

create extension if not exists pg_trgm with schema public;

-- GIN trigram indexes — keep prefix and similarity probes cheap as the
-- leaderboard grows. `gin_trgm_ops` covers both `ILIKE 'x%'` prefix scans
-- and `%`/`similarity()` ranking.
create index if not exists leaderboard_profiles_username_trgm
    on leaderboard_profiles using gin (username gin_trgm_ops);

create index if not exists leaderboard_profiles_display_name_trgm
    on leaderboard_profiles using gin (display_name gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- search_leaderboard_users
--
-- Returns up to `p_limit` profiles ranked by:
--   1. Exact username match  → score 1.0
--   2. Username prefix match → score 0.9 (covers the IG-style "first 3 letters"
--      experience: typing "fri" surfaces every @fri*)
--   3. Trigram similarity on either field, max of the two
--
-- Rows whose best score is below `p_min_score` are dropped so a totally
-- unrelated query doesn't surface random handles. The default floor
-- (0.18) is loose enough to recover a single transposed/dropped letter
-- but tight enough to keep noise out.
-- ----------------------------------------------------------------------------
create or replace function search_leaderboard_users(
    p_query text,
    p_limit int default 8,
    p_min_score real default 0.18
)
returns table (
    id uuid,
    username text,
    display_name text,
    points int,
    tier text,
    streak int,
    total_workouts int,
    updated_at timestamptz,
    score real
)
language sql
security definer
set search_path = public
stable
as $$
    with q as (
        select lower(trim(p_query)) as needle
    ),
    scored as (
        select
            lp.id,
            lp.username,
            lp.display_name,
            lp.points,
            lp.tier,
            lp.streak,
            lp.total_workouts,
            lp.updated_at,
            greatest(
                case when lp.username = q.needle then 1.0::real else 0.0::real end,
                case when lp.username ilike q.needle || '%' then 0.9::real else 0.0::real end,
                case when lp.display_name ilike q.needle || '%' then 0.85::real else 0.0::real end,
                similarity(lp.username, q.needle),
                similarity(coalesce(lp.display_name, ''), q.needle)
            ) as score
        from leaderboard_profiles lp, q
        where coalesce(lp.username, '') <> ''
    )
    select id, username, display_name, points, tier, streak, total_workouts, updated_at, score
    from scored
    where score >= p_min_score
    order by score desc, username asc
    limit greatest(1, least(p_limit, 25));
$$;

-- Grant to both `anon` and `authenticated` because the existing
-- LeaderboardService hits PostgREST with the anon key (no session token).
grant execute on function search_leaderboard_users(text, int, real) to anon, authenticated;
