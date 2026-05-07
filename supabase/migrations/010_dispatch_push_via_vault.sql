-- Fix-up for migration 007: hosted Supabase blocks `alter database set` for
-- `app.*` GUCs (ERROR 42501), so we can't store the dispatch URL + token
-- that way. Use Supabase Vault — built-in encrypted secret store available
-- on every project — instead.
--
-- Steps:
--   1. URL gets hardcoded in the function (it's the project's own edge
--      function endpoint — not sensitive).
--   2. Service-role token gets stored in Vault and read at trigger time.
--   3. `_dispatch_push` is recreated to read from Vault.
--
-- The user must insert the service-role key into Vault separately (after
-- running this migration) — see the line at the bottom of this file.

-- Recreate _dispatch_push to read from Vault instead of GUCs.
create or replace function _dispatch_push() returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    v_url   text := 'https://vwnlfwdsmhanicjgtfgj.supabase.co/functions/v1/send_push';
    v_token text;
begin
    select decrypted_secret
      into v_token
      from vault.decrypted_secrets
     where name = 'send_push_token'
     limit 1;

    -- If the token isn't configured yet, no-op so the row insert still
    -- succeeds. Calling code (the RPCs that enqueue notifications)
    -- shouldn't fail just because pushes aren't wired up yet.
    if v_token is null or v_token = '' then return new; end if;

    perform net.http_post(
        url     := v_url,
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || v_token
        ),
        body    := jsonb_build_object(
            'user_id',         new.user_id,
            'kind',            new.kind,
            'payload',         new.payload,
            'notification_id', new.id
        )
    );
    return new;
end;
$$;
