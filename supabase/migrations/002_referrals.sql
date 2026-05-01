-- Referral attribution: each user owns a unique outbound `referral_code`.
-- When a new user signs up with someone else's code in `referred_by_code`,
-- the client calls the `claim_referral` RPC which records the attribution
-- and credits the referrer (1 free scan per 3 successful referrals).

-- 1. New columns on user_profiles
alter table user_profiles
    add column if not exists referred_by_code text not null default '',
    add column if not exists friends_referred_count int not null default 0;

-- 2. Case-insensitive unique constraint on outbound referral codes (skip empty rows)
create unique index if not exists user_profiles_referral_code_unique
    on user_profiles (upper(referral_code))
    where referral_code <> '';

-- 3. Attribution table — primary key on referred_user_id ensures a user can
--    only be attributed once (first code wins). No FK on referred_user_id so
--    the row may be inserted before the user_profiles row is upserted.
--    Named `referral_attributions` to avoid collision with any pre-existing
--    `referrals` table in this project.
create table if not exists referral_attributions (
    referrer_id uuid not null references user_profiles(id) on delete cascade,
    referred_user_id uuid primary key,
    created_at timestamptz not null default now()
);

create index if not exists referral_attributions_referrer_idx
    on referral_attributions (referrer_id);

alter table referral_attributions enable row level security;

drop policy if exists referral_attributions_read_own on referral_attributions;
create policy referral_attributions_read_own on referral_attributions
    for select using (auth.uid() = referrer_id or auth.uid() = referred_user_id);

-- 4. claim_referral RPC: idempotent attribution + credit
create or replace function claim_referral(p_referrer_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
    v_referrer_id uuid;
    v_referred_user_id uuid := auth.uid();
    v_new_count int;
    v_grants_scan boolean;
begin
    if v_referred_user_id is null then
        return jsonb_build_object('ok', false, 'reason', 'unauthenticated');
    end if;

    select id into v_referrer_id
    from user_profiles
    where upper(referral_code) = upper(p_referrer_code)
      and referral_code <> ''
    limit 1;

    if v_referrer_id is null then
        return jsonb_build_object('ok', false, 'reason', 'invalid_code');
    end if;

    if v_referrer_id = v_referred_user_id then
        return jsonb_build_object('ok', false, 'reason', 'self_referral');
    end if;

    -- Idempotent: only the first code a user enters counts.
    insert into referral_attributions (referrer_id, referred_user_id)
    values (v_referrer_id, v_referred_user_id)
    on conflict (referred_user_id) do nothing;

    if not found then
        return jsonb_build_object('ok', false, 'reason', 'already_attributed');
    end if;

    -- Increment referrer count; grant +1 free scan every 3rd referral.
    update user_profiles
       set friends_referred_count = friends_referred_count + 1,
           free_scans_earned = free_scans_earned +
               case when ((friends_referred_count + 1) % 3) = 0 then 1 else 0 end,
           updated_at = now()
     where id = v_referrer_id
    returning friends_referred_count,
              ((friends_referred_count) % 3) = 0
        into v_new_count, v_grants_scan;

    return jsonb_build_object(
        'ok', true,
        'count', v_new_count,
        'granted_free_scan', v_grants_scan
    );
end;
$$;

grant execute on function claim_referral(text) to authenticated;
