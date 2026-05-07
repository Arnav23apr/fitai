import { Card, Badge, Table, TableBody, TableCell, TableHead, TableHeaderCell, TableRow } from "@tremor/react";
import { supabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const revalidate = 0;

interface FeedbackRow {
  id: string;
  kind: string;
  status: string;
  message: string;
  app_version: string | null;
  ios_version: string | null;
  device_model: string | null;
  created_at: string;
  user_id: string;
}

interface ProfileLite {
  id: string;
  username: string;
  name: string;
  email: string | null;
}

async function fetchFeedback() {
  const { data: feedback } = await supabaseAdmin
    .from("user_feedback")
    .select("id, kind, status, message, app_version, ios_version, device_model, created_at, user_id")
    .order("created_at", { ascending: false })
    .limit(500);

  const ids = Array.from(new Set((feedback ?? []).map((f) => f.user_id)));
  let profiles: ProfileLite[] = [];
  if (ids.length > 0) {
    const { data } = await supabaseAdmin
      .from("user_profiles")
      .select("id, username, name, email")
      .in("id", ids);
    profiles = data ?? [];
  }
  const profileMap = new Map<string, ProfileLite>();
  profiles.forEach((p) => profileMap.set(p.id, p));

  return { feedback: feedback ?? [], profiles: profileMap };
}

function kindColor(kind: string) {
  switch (kind) {
    case "bug": return "red";
    case "suggestion": return "amber";
    case "question": return "blue";
    default: return "slate";
  }
}

function statusColor(status: string) {
  switch (status) {
    case "new": return "blue";
    case "reviewing": return "amber";
    case "resolved": return "emerald";
    case "wont_fix": return "slate";
    default: return "slate";
  }
}

function fmt(iso: string) {
  return new Date(iso).toLocaleString();
}

export default async function FeedbackPage() {
  const { feedback, profiles } = await fetchFeedback();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Feedback</h1>
        <p className="text-sm text-slate-500 mt-1">
          In-app feedback submissions. Bugs / suggestions / questions.
        </p>
      </div>

      <Card>
        {feedback.length === 0 ? (
          <div className="text-sm text-slate-500 py-12 text-center">
            No feedback yet.
          </div>
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeaderCell>When</TableHeaderCell>
                <TableHeaderCell>Kind</TableHeaderCell>
                <TableHeaderCell>Status</TableHeaderCell>
                <TableHeaderCell>User</TableHeaderCell>
                <TableHeaderCell>Message</TableHeaderCell>
                <TableHeaderCell>Device</TableHeaderCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {feedback.map((f: FeedbackRow) => {
                const user = profiles.get(f.user_id);
                return (
                  <TableRow key={f.id}>
                    <TableCell className="text-xs whitespace-nowrap">
                      {fmt(f.created_at)}
                    </TableCell>
                    <TableCell>
                      <Badge color={kindColor(f.kind)}>{f.kind}</Badge>
                    </TableCell>
                    <TableCell>
                      <Badge color={statusColor(f.status)}>{f.status}</Badge>
                    </TableCell>
                    <TableCell className="text-sm">
                      {user ? (
                        <div>
                          <div className="font-medium">
                            {user.username ? `@${user.username}` : user.name || "—"}
                          </div>
                          {user.email && (
                            <div className="text-xs text-slate-500">{user.email}</div>
                          )}
                        </div>
                      ) : (
                        <span className="text-slate-400">{f.user_id.slice(0, 8)}…</span>
                      )}
                    </TableCell>
                    <TableCell className="text-sm text-slate-700 max-w-md">
                      <div className="line-clamp-3">{f.message}</div>
                    </TableCell>
                    <TableCell className="text-xs text-slate-500 whitespace-nowrap">
                      {f.app_version && <div>App {f.app_version}</div>}
                      {f.ios_version && <div>iOS {f.ios_version}</div>}
                      {f.device_model && <div>{f.device_model}</div>}
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </Card>
    </div>
  );
}
