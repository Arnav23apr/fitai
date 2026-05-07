import { NextResponse } from "next/server";
import { setSessionCookie } from "@/lib/session";

export async function POST(req: Request) {
  const { email, password } = (await req.json()) as {
    email?: string;
    password?: string;
  };

  const expectedEmail = process.env.ADMIN_EMAIL;
  const expectedPassword = process.env.ADMIN_PASSWORD;

  if (!expectedEmail || !expectedPassword) {
    return NextResponse.json(
      { ok: false, error: "Admin credentials not configured." },
      { status: 500 }
    );
  }

  // Constant-ish time string compare.
  const emailMatch =
    typeof email === "string" &&
    email.length === expectedEmail.length &&
    email === expectedEmail;
  const passwordMatch =
    typeof password === "string" &&
    password.length === expectedPassword.length &&
    password === expectedPassword;

  if (!emailMatch || !passwordMatch) {
    return NextResponse.json(
      { ok: false, error: "Invalid email or password." },
      { status: 401 }
    );
  }

  await setSessionCookie();
  return NextResponse.json({ ok: true });
}
