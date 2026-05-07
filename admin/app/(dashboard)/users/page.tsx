import { Card, Badge, Table, TableBody, TableCell, TableHead, TableHeaderCell, TableRow } from "@tremor/react";
import { supabaseAdmin } from "@/lib/supabase";

export const dynamic = "force-dynamic";
export const revalidate = 0;

interface UserRow {
  id: string;
  username: string;
  name: string;
  email: string;
  is_premium: boolean;
  tier: string;
  points: number;
  total_workouts: number;
  total_scans: number;
  current_streak: number;
  latest_score: number | null;
  has_completed_onboarding: boolean;
  created_at: string;
}

async function fetchUsers(): Promise<UserRow[]> {
  const { data } = await supabaseAdmin
    .from("user_profiles")
    .select(
      "id, username, name, email, is_premium, tier, points, total_workouts, total_scans, current_streak, latest_score, has_completed_onboarding, created_at"
    )
    .order("created_at", { ascending: false })
    .limit(200);
  return (data ?? []) as UserRow[];
}

function tierColor(tier: string) {
  switch (tier?.toLowerCase()) {
    case "diamond": return "cyan";
    case "platinum": return "indigo";
    case "gold": return "amber";
    case "silver": return "slate";
    default: return "stone";
  }
}

function fmtDate(iso: string) {
  return new Date(iso).toLocaleDateString();
}

export default async function UsersPage() {
  const users = await fetchUsers();

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Users</h1>
        <p className="text-sm text-slate-500 mt-1">
          Latest 200 users by signup date.
        </p>
      </div>

      <Card>
        {users.length === 0 ? (
          <div className="text-sm text-slate-500 py-12 text-center">
            No users yet.
          </div>
        ) : (
          <Table>
            <TableHead>
              <TableRow>
                <TableHeaderCell>User</TableHeaderCell>
                <TableHeaderCell>Email</TableHeaderCell>
                <TableHeaderCell>Premium</TableHeaderCell>
                <TableHeaderCell>Tier</TableHeaderCell>
                <TableHeaderCell>Points</TableHeaderCell>
                <TableHeaderCell>Workouts</TableHeaderCell>
                <TableHeaderCell>Scans</TableHeaderCell>
                <TableHeaderCell>Streak</TableHeaderCell>
                <TableHeaderCell>Onboarded</TableHeaderCell>
                <TableHeaderCell>Joined</TableHeaderCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {users.map((u) => (
                <TableRow key={u.id}>
                  <TableCell>
                    <div className="text-sm">
                      <div className="font-medium">
                        {u.username ? `@${u.username}` : "—"}
                      </div>
                      <div className="text-xs text-slate-500">
                        {u.name || <span className="text-slate-400">(no name)</span>}
                      </div>
                    </div>
                  </TableCell>
                  <TableCell className="text-xs text-slate-600">
                    {u.email || <span className="text-slate-400">—</span>}
                  </TableCell>
                  <TableCell>
                    {u.is_premium ? (
                      <Badge color="emerald">Pro</Badge>
                    ) : (
                      <span className="text-slate-400 text-xs">Free</span>
                    )}
                  </TableCell>
                  <TableCell>
                    <Badge color={tierColor(u.tier)}>{u.tier || "Bronze"}</Badge>
                  </TableCell>
                  <TableCell className="text-sm tabular-nums">
                    {u.points.toLocaleString()}
                  </TableCell>
                  <TableCell className="text-sm tabular-nums">
                    {u.total_workouts}
                  </TableCell>
                  <TableCell className="text-sm tabular-nums">
                    {u.total_scans}
                  </TableCell>
                  <TableCell className="text-sm tabular-nums">
                    {u.current_streak}
                  </TableCell>
                  <TableCell className="text-xs">
                    {u.has_completed_onboarding ? "✅" : "—"}
                  </TableCell>
                  <TableCell className="text-xs text-slate-600 whitespace-nowrap">
                    {fmtDate(u.created_at)}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        )}
      </Card>
    </div>
  );
}
