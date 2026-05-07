import { Card, Badge, Table, TableBody, TableCell, TableHead, TableHeaderCell, TableRow } from "@tremor/react";
import { supabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const revalidate = 0;

interface ReportRow {
  id: string;
  reason: string;
  details: string | null;
  created_at: string;
  reporter_id: string;
  reported_user_id: string;
}

interface ProfileLite {
  id: string;
  username: string;
  name: string;
}

async function fetchReports(): Promise<{
  reports: ReportRow[];
  profiles: Map<string, ProfileLite>;
}> {
  const { data: reports } = await supabaseAdmin
    .from("reports")
    .select("id, reason, details, created_at, reporter_id, reported_user_id")
    .order("created_at", { ascending: false })
    .limit(500);

  const ids = new Set<string>();
  (reports ?? []).forEach((r) => {
    ids.add(r.reporter_id);
    ids.add(r.reported_user_id);
  });

  let profiles: ProfileLite[] = [];
  if (ids.size > 0) {
    const { data } = await supabaseAdmin
      .from("user_profiles")
      .select("id, username, name")
      .in("id", Array.from(ids));
    profiles = data ?? [];
  }

  const profileMap = new Map<string, ProfileLite>();
  profiles.forEach((p) => profileMap.set(p.id, p));

  return { reports: reports ?? [], profiles: profileMap };
}

function reasonColor(reason: string) {
  switch (reason) {
    case "harassment": return "red";
    case "inappropriate_photo": return "rose";
    case "underage": return "purple";
    case "spam": return "amber";
    case "fake_account": return "blue";
    default: return "slate";
  }
}

function fmt(iso: string) {
  const d = new Date(iso);
  return d.toLocaleString();
}

export default async function ReportsPage() {
  const { reports, profiles } = await fetchReports();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Reports</h1>
        <p className="text-sm text-slate-500 mt-1">
          User-submitted reports of other users. Read-only — actions still go
          through Supabase Studio for safety.
        </p>
      </div>

      <Card>
        {reports.length === 0 ? (
          <div className="text-sm text-slate-500 py-12 text-center">
            No reports yet.
          </div>
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeaderCell>When</TableHeaderCell>
                <TableHeaderCell>Reason</TableHeaderCell>
                <TableHeaderCell>Reporter</TableHeaderCell>
                <TableHeaderCell>Reported</TableHeaderCell>
                <TableHeaderCell>Details</TableHeaderCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {reports.map((r) => {
                const reporter = profiles.get(r.reporter_id);
                const reported = profiles.get(r.reported_user_id);
                return (
                  <TableRow key={r.id}>
                    <TableCell className="text-xs whitespace-nowrap">
                      {fmt(r.created_at)}
                    </TableCell>
                    <TableCell>
                      <Badge color={reasonColor(r.reason)}>{r.reason}</Badge>
                    </TableCell>
                    <TableCell className="text-sm">
                      {reporter ? (
                        <div>
                          <div className="font-medium">@{reporter.username}</div>
                          <div className="text-xs text-slate-500">
                            {reporter.name}
                          </div>
                        </div>
                      ) : (
                        <span className="text-slate-400">{r.reporter_id.slice(0, 8)}…</span>
                      )}
                    </TableCell>
                    <TableCell className="text-sm">
                      {reported ? (
                        <div>
                          <div className="font-medium">@{reported.username}</div>
                          <div className="text-xs text-slate-500">
                            {reported.name}
                          </div>
                        </div>
                      ) : (
                        <span className="text-slate-400">{r.reported_user_id.slice(0, 8)}…</span>
                      )}
                    </TableCell>
                    <TableCell className="text-xs text-slate-700 max-w-md">
                      {r.details || <span className="text-slate-400">—</span>}
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
