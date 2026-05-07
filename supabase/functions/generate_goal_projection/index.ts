// Supabase Edge Function: generate_goal_projection
// ────────────────────────────────────────────────────────────────────
// Calls Gemini 2.5 Flash Image (a.k.a. "Nano Banana") with the user's
// most recent body scan photo + a goal-conditional prompt, uploads the
// result to the `goal_projections` Storage bucket, and patches
// user_profiles.goal_projection_url so every iOS surface picks it up.
//
// Auth: requires a valid Supabase user JWT (sent via Authorization header).
// Cooldown: 90 days between regenerations enforced server-side.
//
// Request body:
//   { source_image_url: string }   — public URL of the source scan photo
//
// Response:
//   200 { ok: true, url: string }
//   200 { ok: false, reason: "cooldown" | "no_scan" | "..." , days_left?: number }
//   401 if auth missing / invalid
//   500 if Gemini / Storage fails
//
// Required Supabase secrets:
//   SUPABASE_URL                — auto-provided
//   SUPABASE_SERVICE_ROLE_KEY   — auto-provided
//   GEMINI_API_KEY              — paste from Google AI Studio
//
// deno-lint-ignore-file no-explicit-any

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const SUPABASE_URL              = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GEMINI_API_KEY            = Deno.env.get("GEMINI_API_KEY") ?? "";

const COOLDOWN_DAYS = 90;
const BUCKET = "goal_projections";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
});

// ─── Goal-conditional prompts ────────────────────────────────────────
function goalToPrompt(primaryGoal: string): string {
    const base =
        "Generate a photorealistic image of the same person in the input photo, but with their target physique. " +
        "Keep the same face, hair, skin tone, height, and overall proportions. Same lighting, same camera angle, " +
        "same clothing style. Only the body composition changes. Tasteful and aspirational, not exaggerated.";

    switch (primaryGoal) {
        case "Build Muscle":
            return `${base} Show them with significantly more lean muscle mass — fuller shoulders, chest, arms, ` +
                "and back, with clean separation. Athletic intermediate-bodybuilder physique, ~12% body fat. " +
                "The result of about 12 weeks of consistent strength training and proper nutrition.";
        case "Lose Fat":
            return `${base} Show them after losing 5–10 kg of body fat — visibly leaner, with muscle definition ` +
                "where it was previously hidden. Same height and frame, just less fat. Around 12–15% body fat. " +
                "The result of about 12 weeks of consistent fat loss with strength preservation.";
        case "Recomp":
            return `${base} Show a clear body recomposition — slightly more muscle mass with noticeably less ` +
                "body fat. Athletic, lean, defined. Around 13% body fat with visible muscle definition. " +
                "The result of about 16 weeks of structured body recomposition training.";
        default:
            return `${base} Show them with an athletic, fit, healthy physique — lean, defined, well-proportioned. ` +
                "Around 13% body fat. The result of about 12 weeks of consistent training.";
    }
}

// ─── Main handler ────────────────────────────────────────────────────
Deno.serve(async (req) => {
    if (req.method !== "POST") {
        return new Response("Method Not Allowed", { status: 405 });
    }

    if (!GEMINI_API_KEY) {
        return new Response(
            JSON.stringify({ ok: false, reason: "gemini_not_configured" }),
            { status: 500, headers: { "Content-Type": "application/json" } },
        );
    }

    // ─── Auth ────────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response("Unauthorized", { status: 401 });
    const jwt = authHeader.replace(/^Bearer\s+/i, "");

    const { data: userData, error: userErr } = await supabase.auth.getUser(jwt);
    if (userErr || !userData?.user) {
        return new Response("Unauthorized", { status: 401 });
    }
    const userId = userData.user.id;

    // ─── Input ───────────────────────────────────────────────────────
    let body: { source_image_url?: string };
    try { body = await req.json(); }
    catch { return new Response("Bad JSON", { status: 400 }); }

    if (!body.source_image_url) {
        return new Response(
            JSON.stringify({ ok: false, reason: "missing_source_image_url" }),
            { status: 400, headers: { "Content-Type": "application/json" } },
        );
    }

    // ─── Profile lookup + cooldown ───────────────────────────────────
    const { data: profile } = await supabase
        .from("user_profiles")
        .select("primary_goal, goal_projection_generated_at")
        .eq("id", userId)
        .single();

    if (!profile) {
        return new Response(
            JSON.stringify({ ok: false, reason: "profile_not_found" }),
            { status: 404, headers: { "Content-Type": "application/json" } },
        );
    }

    if (profile.goal_projection_generated_at) {
        const lastGen = new Date(profile.goal_projection_generated_at).getTime();
        const daysSince = (Date.now() - lastGen) / (1000 * 60 * 60 * 24);
        if (daysSince < COOLDOWN_DAYS) {
            return new Response(
                JSON.stringify({
                    ok: false,
                    reason: "cooldown",
                    days_left: Math.ceil(COOLDOWN_DAYS - daysSince),
                }),
                { status: 200, headers: { "Content-Type": "application/json" } },
            );
        }
    }

    // ─── Fetch source image, base64-encode for inline data ───────────
    const sourceRes = await fetch(body.source_image_url);
    if (!sourceRes.ok) {
        return new Response(
            JSON.stringify({ ok: false, reason: "couldnt_fetch_source" }),
            { status: 200, headers: { "Content-Type": "application/json" } },
        );
    }
    const sourceBytes = new Uint8Array(await sourceRes.arrayBuffer());
    const sourceB64 = bytesToBase64(sourceBytes);
    const sourceMime = sourceRes.headers.get("content-type") ?? "image/jpeg";

    // ─── Gemini 2.5 Flash Image call ─────────────────────────────────
    const geminiRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent?key=${GEMINI_API_KEY}`,
        {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                contents: [{
                    parts: [
                        { text: goalToPrompt(profile.primary_goal ?? "") },
                        { inline_data: { mime_type: sourceMime, data: sourceB64 } },
                    ],
                }],
                generationConfig: { responseModalities: ["IMAGE"] },
            }),
        },
    );

    if (!geminiRes.ok) {
        const errText = await geminiRes.text().catch(() => "");
        return new Response(
            JSON.stringify({ ok: false, reason: "gemini_error", detail: errText.slice(0, 500) }),
            { status: 502, headers: { "Content-Type": "application/json" } },
        );
    }

    const geminiData = await geminiRes.json();
    const imageData = geminiData?.candidates?.[0]?.content?.parts
        ?.find((p: any) => p.inline_data ?? p.inlineData)
        ?.inline_data?.data
        ?? geminiData?.candidates?.[0]?.content?.parts
            ?.find((p: any) => p.inlineData)
            ?.inlineData?.data;

    if (!imageData) {
        return new Response(
            JSON.stringify({ ok: false, reason: "no_image_in_response" }),
            { status: 502, headers: { "Content-Type": "application/json" } },
        );
    }

    // ─── Upload to Storage ───────────────────────────────────────────
    const imageBytes = base64ToBytes(imageData);
    const fileName = `${userId}/${Date.now()}.jpg`;
    const { error: uploadErr } = await supabase.storage
        .from(BUCKET)
        .upload(fileName, imageBytes, { contentType: "image/jpeg", upsert: true });

    if (uploadErr) {
        return new Response(
            JSON.stringify({ ok: false, reason: "upload_failed", detail: uploadErr.message }),
            { status: 500, headers: { "Content-Type": "application/json" } },
        );
    }

    const { data: urlData } = supabase.storage.from(BUCKET).getPublicUrl(fileName);
    const publicUrl = urlData.publicUrl;

    // ─── Patch profile ───────────────────────────────────────────────
    const { error: updateErr } = await supabase
        .from("user_profiles")
        .update({
            goal_projection_url: publicUrl,
            goal_projection_generated_at: new Date().toISOString(),
        })
        .eq("id", userId);

    if (updateErr) {
        return new Response(
            JSON.stringify({ ok: false, reason: "profile_update_failed", detail: updateErr.message }),
            { status: 500, headers: { "Content-Type": "application/json" } },
        );
    }

    return new Response(
        JSON.stringify({ ok: true, url: publicUrl }),
        { status: 200, headers: { "Content-Type": "application/json" } },
    );
});

// ─── Base64 helpers (Deno-friendly, no Node Buffer) ──────────────────
function bytesToBase64(bytes: Uint8Array): string {
    let bin = "";
    for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin);
}

function base64ToBytes(b64: string): Uint8Array {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
}
