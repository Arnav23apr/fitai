// Supabase Edge Function: send_push
// ────────────────────────────────────────────────────────────────────
// Receives notification rows from the `_dispatch_push` trigger, looks up
// active iOS device tokens for the user, signs an APNs ES256 JWT, and
// POSTs the alert payload to the APNs HTTP/2 endpoint.
//
// Required Supabase secrets (set via `supabase secrets set ...`):
//   APNS_TEAM_ID         — 10-char Apple Developer Team ID
//   APNS_KEY_ID          — 10-char APNs Auth Key ID (from .p8 download)
//   APNS_PRIVATE_KEY     — full contents of the .p8 file (PEM, including BEGIN/END)
//   APNS_BUNDLE_ID       — your iOS app's bundle identifier (e.g. com.fitai.app)
//   APNS_USE_SANDBOX     — "true" while still developing, "false" for App Store / TestFlight prod
//   SUPABASE_SERVICE_ROLE_KEY — already provided by Supabase runtime
//
// Body shape from the trigger:
//   { user_id, kind, payload, notification_id }
//
// Copy table for each notification kind is defined in NOTIFICATION_COPY
// below — extend it when you add new kinds (must match SQL inserts).

// deno-lint-ignore-file no-explicit-any

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL                = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY   = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_TEAM_ID                = Deno.env.get("APNS_TEAM_ID")!;
const APNS_KEY_ID                 = Deno.env.get("APNS_KEY_ID")!;
const APNS_PRIVATE_KEY            = Deno.env.get("APNS_PRIVATE_KEY")!;
const APNS_BUNDLE_ID              = Deno.env.get("APNS_BUNDLE_ID")!;
const APNS_USE_SANDBOX            = (Deno.env.get("APNS_USE_SANDBOX") ?? "true") === "true";

const APNS_HOST = APNS_USE_SANDBOX
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

// JWT cache — APNs keys are valid for up to 1h, refresh every 50min.
let cachedJwt: { token: string; expiresAt: number } | null = null;

// ─── Notification copy (server-side; matches the 5 trigger kinds) ─────
type Copy = { title: string; body: (p: any) => string };
const NOTIFICATION_COPY: Record<string, Copy> = {
    challenge_sent: {
        title: "New 1v1 challenge",
        body: (p) => `${p.from ?? "Someone"} challenged you to a battle. 24h to respond.`,
    },
    challenge_completed: {
        title: "Battle results are in",
        body: (p) => p.you_won ? "You won!" : "You lost — rematch?",
    },
    challenge_won_forfeit: {
        title: "Win by forfeit",
        body: () => "Your opponent didn't respond — score stands.",
    },
    challenge_lost_forfeit: {
        title: "Battle expired",
        body: () => "Your battle window closed.",
    },
    challenge_expired: {
        title: "Battle expired",
        body: () => "Neither side submitted. Challenge closed.",
    },
    streak_expiring: {
        title: "Streak about to end",
        body: (p) => `Your ${p.streak}-day streak ends soon. Show up today.`,
    },
    pending_response: {
        title: "Your move",
        body: () => "An opponent's waiting on your photo.",
    },
    weekly_digest: {
        title: "Your week in FitAI",
        body: (p) => `${p.battles} battle${p.battles === 1 ? "" : "s"}, ${p.wins} win${p.wins === 1 ? "" : "s"}.`,
    },
    rival_of_the_week: {
        title: "This week's rival",
        body: (p) => `@${p.rival_username ?? "your closest friend"} is closest to your score. Challenge them?`,
    },
    friend_workout_nudge: {
        title: "Don't fall behind",
        body: (p) =>
            `@${p.actor_username ?? "Someone"} just finished ${
                p.workout_name ?? "a workout"
            }. Skip today and they're +${p.xp ?? 50} XP ahead.`,
    },
};

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
});

Deno.serve(async (req) => {
    if (req.method !== "POST") return new Response("Method Not Allowed", { status: 405 });

    let body: { user_id: string; kind: string; payload?: any; notification_id?: string };
    try { body = await req.json(); }
    catch { return new Response("Bad JSON", { status: 400 }); }

    const copy = NOTIFICATION_COPY[body.kind];
    if (!copy) {
        // Unknown kind — log and 200 so trigger doesn't retry forever.
        console.warn(`[send_push] Unknown kind: ${body.kind}`);
        return new Response(JSON.stringify({ ok: true, skipped: true }), { status: 200 });
    }

    // Personalize the payload from the recipient's perspective. The DB
    // trigger fires the same payload to both participants in a challenge,
    // so the "you won / you lost" decision has to be made here based on
    // recipient user_id vs payload.winner_id.
    const personalized = {
        ...(body.payload ?? {}),
        you_won: body.payload?.winner_id != null
              && body.payload.winner_id === body.user_id,
    };

    // 1. Pull active tokens for this user
    const { data: tokens, error } = await supabase
        .from("push_tokens")
        .select("token, platform, environment")
        .eq("user_id", body.user_id)
        .eq("platform", "ios");
    if (error) {
        console.error("[send_push] token lookup failed:", error);
        return new Response("token lookup failed", { status: 500 });
    }
    if (!tokens || tokens.length === 0) {
        return new Response(JSON.stringify({ ok: true, sent: 0 }), { status: 200 });
    }

    // 2. Sign APNs JWT (cached for ~50min)
    let jwt: string;
    try { jwt = await getApnsJwt(); }
    catch (e) {
        console.error("[send_push] JWT sign failed:", e);
        return new Response("jwt sign failed", { status: 500 });
    }

    // 3. Build APNs payload
    const payload = {
        aps: {
            alert: { title: copy.title, body: copy.body(personalized) },
            sound: "default",
            "thread-id": body.kind,
        },
        kind: body.kind,
        notification_id: body.notification_id,
        ...personalized,
    };

    // 4. Fan-out — send to every device token in parallel
    const results = await Promise.all(tokens.map(async (row) => {
        const url = `${APNS_HOST}/3/device/${row.token}`;
        try {
            const resp = await fetch(url, {
                method: "POST",
                headers: {
                    "authorization":     `bearer ${jwt}`,
                    "apns-topic":        APNS_BUNDLE_ID,
                    "apns-push-type":    "alert",
                    "apns-priority":     "10",
                    "content-type":      "application/json",
                },
                body: JSON.stringify(payload),
            });
            if (!resp.ok) {
                const text = await resp.text();
                // Bad token → drop it so we don't keep trying
                if (resp.status === 410 || resp.status === 400) {
                    await supabase.from("push_tokens").delete().eq("token", row.token);
                }
                return { token: row.token, ok: false, status: resp.status, body: text };
            }
            return { token: row.token, ok: true };
        } catch (e) {
            return { token: row.token, ok: false, error: String(e) };
        }
    }));

    return new Response(JSON.stringify({
        ok: true,
        sent: results.filter(r => r.ok).length,
        failed: results.filter(r => !r.ok).length,
        results,
    }), { status: 200, headers: { "content-type": "application/json" } });
});

// ─── APNs JWT (ES256 over P-256) ────────────────────────────────────
async function getApnsJwt(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    if (cachedJwt && cachedJwt.expiresAt > now + 60) return cachedJwt.token;

    const header  = base64UrlEncode(new TextEncoder().encode(
        JSON.stringify({ alg: "ES256", kid: APNS_KEY_ID, typ: "JWT" })
    ));
    const claims  = base64UrlEncode(new TextEncoder().encode(
        JSON.stringify({ iss: APNS_TEAM_ID, iat: now })
    ));
    const signingInput = `${header}.${claims}`;

    const key = await importPrivateKey(APNS_PRIVATE_KEY);
    const sig = await crypto.subtle.sign(
        { name: "ECDSA", hash: "SHA-256" },
        key,
        new TextEncoder().encode(signingInput)
    );
    const sigEncoded = base64UrlEncode(new Uint8Array(sig));
    const token = `${signingInput}.${sigEncoded}`;

    cachedJwt = { token, expiresAt: now + 50 * 60 };   // 50min cache (APNs allows up to 60min)
    return token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
    const cleaned = pem
        .replace("-----BEGIN PRIVATE KEY-----", "")
        .replace("-----END PRIVATE KEY-----", "")
        .replace(/\s/g, "");
    const der = Uint8Array.from(atob(cleaned), c => c.charCodeAt(0));
    return await crypto.subtle.importKey(
        "pkcs8",
        der,
        { name: "ECDSA", namedCurve: "P-256" },
        false,
        ["sign"]
    );
}

function base64UrlEncode(bytes: Uint8Array): string {
    let str = "";
    for (let i = 0; i < bytes.length; i++) str += String.fromCharCode(bytes[i]);
    return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
