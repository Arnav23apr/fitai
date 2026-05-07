// Supabase admin client. ALWAYS server-side. Uses service role key to bypass
// RLS so we can read reports / feedback / users that clients can't.
// NEVER import this in a Client Component.
//
// The client is constructed lazily (on first access) so that Next's
// build-time page-data collection doesn't trip the env-var check before
// real env vars are set in dev / production.

import { createClient, SupabaseClient } from "@supabase/supabase-js";

let client: SupabaseClient | null = null;

function getClient(): SupabaseClient {
  if (client) return client;

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url) throw new Error("NEXT_PUBLIC_SUPABASE_URL is missing.");
  if (!serviceKey) throw new Error("SUPABASE_SERVICE_ROLE_KEY is missing.");

  client = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return client;
}

// Proxy that defers to the lazy client. Lets pages keep using
// `supabaseAdmin.from(...)` syntax without thinking about init order.
export const supabaseAdmin = new Proxy({} as SupabaseClient, {
  get(_target, prop, receiver) {
    const real = getClient();
    const value = Reflect.get(real, prop, receiver);
    return typeof value === "function" ? value.bind(real) : value;
  },
});
