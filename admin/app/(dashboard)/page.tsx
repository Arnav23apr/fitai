import { Card, Metric, Text, Badge } from "@tremor/react";
import { supabaseAdmin } from "@/lib/supabase";
import { getOverviewMetrics } from "@/lib/revenuecat";
import Link from "next/link";

export const dynamic = "force-dynamic";
export const revalidate = 0;

async function fetchKPIs() {
  const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

  const [
    totalUsersRes,
    signups7dRes,
    premiumUsersRes,
    feedbackNewRes,
    feedback24hRes,
    reports7dRes,
    reportsTotalRes,
  ] = await Promise.all([
    supabaseAdmin.from("user_profiles").select("id", { count: "exact", head: true }),
    supabaseAdmin
      .from("user_profiles")
      .select("id", { count: "exact", head: true })
      .gte("created_at", sevenDaysAgo),
    supabaseAdmin
      .from("user_profiles")
      .select("id", { count: "exact", head: true })
      .eq("is_premium", true),
    supabaseAdmin
      .from("user_feedback")
      .select("id", { count: "exact", head: true })
      .eq("status", "new"),
    supabaseAdmin
      .from("user_feedback")
      .select("id", { count: "exact", head: true })
      .gte("created_at", oneDayAgo),
    supabaseAdmin
      .from("reports")
      .select("id", { count: "exact", head: true })
      .gte("created_at", sevenDaysAgo),
    supabaseAdmin.from("reports").select("id", { count: "exact", head: true }),
  ]);

  return {
    totalUsers: totalUsersRes.count ?? 0,
    signups7d: signups7dRes.count ?? 0,
    premiumUsers: premiumUsersRes.count ?? 0,
    feedbackNew: feedbackNewRes.count ?? 0,
    feedback24h: feedback24hRes.count ?? 0,
    reports7d: reports7dRes.count ?? 0,
    reportsTotal: reportsTotalRes.count ?? 0,
  };
}

async function fetchRecentFeedback(limit = 8) {
  const { data } = await supabaseAdmin
    .from("user_feedback")
    .select("id, kind, status, message, created_at, user_id")
    .order("created_at", { ascending: false })
    .limit(limit);
  return data ?? [];
}

async function fetchRecentReports(limit = 8) {
  const { data } = await supabaseAdmin
    .from("reports")
    .select("id, reason, details, created_at, reporter_id, reported_user_id")
    .order("created_at", { ascending: false })
    .limit(limit);
  return data ?? [];
}

export default async function OverviewPage() {
  const [kpis, recentFeedback, recentReports, rcMetrics] = await Promise.all([
    fetchKPIs(),
    fetchRecentFeedback(),
    fetchRecentReports(),
    getOverviewMetrics(),
  ]);

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Overview</h1>
        <p className="text-sm text-slate-500 mt-1">
          What's happening across FitAI right now.
        </p>
      </div>

      {/* KPI grid */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <Text>Total users</Text>
          <Metric>{kpis.totalUsers.toLocaleString()}</Metric>
        </Card>
        <Card>
          <Text>Signups (7d)</Text>
          <Metric>{kpis.signups7d.toLocaleString()}</Metric>
        </Card>
        <Card>
          <Text>Premium users (DB)</Text>
          <Metric>{kpis.premiumUsers.toLocaleString()}</Metric>
        </Card>
        <Card>
          <Text>Active subs (RC)</Text>
          <Metric>
            {rcMetrics.active_subscribers === null
              ? "—"
              : rcMetrics.active_subscribers.toLocaleString()}
          </Metric>
        </Card>
        <Card>
          <Text>New feedback</Text>
          <Metric>{kpis.feedbackNew.toLocaleString()}</Metric>
        </Card>
        <Card>
          <Text>Feedback (24h)</Text>
          <Metric>{kpis.feedback24h.toLocaleString()}</Metric>
        </Card>
        <Card>
          <Text>Reports (7d)</Text>
          <Metric>{kpis.reports7d.toLocaleString()}</Metric>
        </Card>
        <Card>
          <Text>Reports (total)</Text>
          <Metric>{kpis.reportsTotal.toLocaleString()}</Metric>
        </Card>
      </div>

      {/* Recent activity columns */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card>
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-slate-900">Recent feedback</h2>
            <Link
              href="/feedback"
              className="text-xs text-blue-600 font-medium hover:underline"
            >
              View all →
            </Link>
          </div>
          {recentFeedback.length === 0 ? (
            <div className="text-sm text-slate-500 py-8 text-center">
              Nothing yet.
            </div>
          ) : (
            <ul className="divide-y divide-slate-100">
              {recentFeedback.map((f) => (
                <li key={f.id} className="py-3">
                  <div className="flex items-center gap-2 mb-1">
                    <Badge color={kindColor(f.kind)}>{f.kind}</Badge>
                    <Badge color={statusColor(f.status)}>{f.status}</Badge>
                    <span className="text-xs text-slate-500 ml-auto">
                      {timeAgo(f.created_at)}
                    </span>
                  </div>
                  <p className="text-sm text-slate-700 line-clamp-2">
                    {f.message}
                  </p>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card>
          <div className="flex items-center justify-between mb-4">
            <h2 className="font-semibold text-slate-900">Recent reports</h2>
            <Link
              href="/reports"
              className="text-xs text-blue-600 font-medium hover:underline"
            >
              View all →
            </Link>
          </div>
          {recentReports.length === 0 ? (
            <div className="text-sm text-slate-500 py-8 text-center">
              Nothing yet.
            </div>
          ) : (
            <ul className="divide-y divide-slate-100">
              {recentReports.map((r) => (
                <li key={r.id} className="py-3">
                  <div className="flex items-center gap-2 mb-1">
                    <Badge color="red">{r.reason}</Badge>
                    <span className="text-xs text-slate-500 ml-auto">
                      {timeAgo(r.created_at)}
                    </span>
                  </div>
                  {r.details && (
                    <p className="text-sm text-slate-700 line-clamp-2">
                      {r.details}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
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

function timeAgo(iso: string): string {
  const ms = Date.now() - new Date(iso).getTime();
  const m = Math.floor(ms / 60000);
  if (m < 1) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  const d = Math.floor(h / 24);
  return `${d}d ago`;
}
