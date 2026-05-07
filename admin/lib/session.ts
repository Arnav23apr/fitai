// Tiny stateless cookie auth — single admin user, zero external deps.
// Cookie format: `<expiresAtMs>.<base64url(hmac-sha256(expiresAtMs, SESSION_SECRET))>`
// HMAC ensures the client can't forge or extend the expiry.
//
// Uses Web Crypto API so the same module works in both Edge (middleware) and
// Node.js (route handlers) runtimes without conditional imports.

import { cookies } from "next/headers";

const COOKIE_NAME = "fitai_admin_session";
const TWO_WEEKS_MS = 14 * 24 * 60 * 60 * 1000;

function secretBytes(): ArrayBuffer {
  const s = process.env.SESSION_SECRET;
  if (!s || s.length < 16) {
    throw new Error(
      "SESSION_SECRET must be set to a random hex string (>= 32 chars). Generate with: openssl rand -hex 32"
    );
  }
  const arr = new TextEncoder().encode(s);
  // Copy into a plain ArrayBuffer to satisfy strict BufferSource typing
  // (Uint8Array<ArrayBufferLike> isn't assignable to ArrayBuffer in TS 5.6).
  const buf = new ArrayBuffer(arr.byteLength);
  new Uint8Array(buf).set(arr);
  return buf;
}

async function hmacKey(): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    secretBytes(),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"]
  );
}

function toBase64Url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(s: string): ArrayBuffer {
  const padded = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  const bin = atob(padded);
  const buf = new ArrayBuffer(bin.length);
  const view = new Uint8Array(buf);
  for (let i = 0; i < bin.length; i++) view[i] = bin.charCodeAt(i);
  return buf;
}

function asArrayBuffer(s: string): ArrayBuffer {
  const arr = new TextEncoder().encode(s);
  const buf = new ArrayBuffer(arr.byteLength);
  new Uint8Array(buf).set(arr);
  return buf;
}

async function sign(value: string): Promise<string> {
  const key = await hmacKey();
  const sig = await crypto.subtle.sign("HMAC", key, asArrayBuffer(value));
  return toBase64Url(sig);
}

export async function makeSessionToken(expiresAtMs: number): Promise<string> {
  const sig = await sign(String(expiresAtMs));
  return `${expiresAtMs}.${sig}`;
}

export async function verifySessionToken(token: string | undefined): Promise<boolean> {
  if (!token) return false;
  const dot = token.indexOf(".");
  if (dot < 0) return false;
  const expiresAtRaw = token.slice(0, dot);
  const sigRaw = token.slice(dot + 1);
  const expiresAt = Number(expiresAtRaw);
  if (!Number.isFinite(expiresAt) || expiresAt < Date.now()) return false;

  try {
    const key = await hmacKey();
    const sigBytes = fromBase64Url(sigRaw);
    return await crypto.subtle.verify(
      "HMAC",
      key,
      sigBytes,
      asArrayBuffer(expiresAtRaw)
    );
  } catch {
    return false;
  }
}

export async function setSessionCookie() {
  const expiresAtMs = Date.now() + TWO_WEEKS_MS;
  const token = await makeSessionToken(expiresAtMs);
  const jar = await cookies();
  jar.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    expires: new Date(expiresAtMs),
  });
}

export async function clearSessionCookie() {
  const jar = await cookies();
  jar.delete(COOKIE_NAME);
}

export async function isAuthenticated(): Promise<boolean> {
  const jar = await cookies();
  const token = jar.get(COOKIE_NAME)?.value;
  return verifySessionToken(token);
}

export const SESSION_COOKIE_NAME = COOKIE_NAME;
