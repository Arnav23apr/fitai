import { Card, Metric, Text } from "@tremor/react";
import { supabaseAdmin } from "@/lib/supabase";
import { getOverviewMetrics } from "@/lib/revenuecat";

export const dynamic = "force-dynamic";
export const revalidate = 0;

async function fetchPremiumCount() {
  const { count } = await supabaseAdmin
    .from("user_profiles")
    .select("id", { count: "exact", head: true })
    .eq("is_premium", true);
  return count ?? 0;
}

export default async function RevenuePage() {
  const [premiumDB, rc] = await Promise.all([
    fetchPremiumCount(),
    getOverviewMetrics(),
  ]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-slate-900">Revenue</h1>
        <p className="text-sm text-slate-500 mt-1">
          Subscription metrics. Full charts and cohorts live on RevenueCat.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <Text>Premium users (FitAI DB)</Text>
          <Metric>{premiumDB.toLocaleString()}</Metric>
          <p className="text-xs text-slate-500 mt-2">
            From <code>user_profiles.is_premium</code>. Updated by app on
            entitlement change.
          </p>
        </Card>
        <Card>
          <Text>Active subscribers (RC)</Text>
          <Metric>
            {rc.active_subscribers === null
              ? "—"
              : rc.active_subscribers.toLocaleString()}
          </Metric>
          <p className="text-xs text-slate-500 mt-2">
            {rc.configured
              ? "From RevenueCat REST API."
              : "RevenueCat API not configured. Set REVENUECAT_SECRET_KEY + REVENUECAT_PROJECT_ID env vars."}
          </p>
        </Card>
        <Card>
          <Text>In trial (RC)</Text>
          <Metric>
            {rc.active_trials === null
              ? "—"
              : rc.active_trials.toLocaleString()}
          </Metric>
          <p className="text-xs text-slate-500 mt-2">
            Active subs currently in introductory period.
          </p>
        </Card>
      </div>

      <Card>
        <h2 className="font-semibold text-slate-900 mb-2">Full revenue dashboard</h2>
        <p className="text-sm text-slate-600 mb-4">
          MRR, churn, cohort retention, trial-to-paid conversion, and refund
          history live on RevenueCat. Don't rebuild what they already do well.
        </p>
        <a
          href="https://app.revenuecat.com/"
          target="_blank"
          rel="noopener noreferrer"
          className="inline-flex items-center gap-2 px-4 py-2 bg-slate-900 hover:bg-slate-800 text-white text-sm font-semibold rounded-lg transition"
        >
          Open RevenueCat dashboard ↗
        </a>
      </Card>
    </div>
  );
}
