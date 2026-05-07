// RevenueCat REST v2. Optional — page degrades gracefully if not configured.
// Docs: https://www.revenuecat.com/reference/api-v2

const BASE = "https://api.revenuecat.com/v2";

function configured(): boolean {
  return Boolean(
    process.env.REVENUECAT_SECRET_KEY && process.env.REVENUECAT_PROJECT_ID
  );
}

async function rcGet<T>(path: string): Promise<T | null> {
  if (!configured()) return null;
  try {
    const res = await fetch(`${BASE}${path}`, {
      headers: {
        Authorization: `Bearer ${process.env.REVENUECAT_SECRET_KEY}`,
        "Content-Type": "application/json",
      },
      // Avoid stale cache during a session — short revalidation is fine.
      next: { revalidate: 60 },
    });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

export interface OverviewMetrics {
  active_subscribers: number | null;
  active_trials: number | null;
  mrr_usd: number | null;
  configured: boolean;
}

export async function getOverviewMetrics(): Promise<OverviewMetrics> {
  if (!configured()) {
    return {
      active_subscribers: null,
      active_trials: null,
      mrr_usd: null,
      configured: false,
    };
  }
  const projectId = process.env.REVENUECAT_PROJECT_ID;
  // Customers list (capped count for the overview tile only — full revenue
  // analytics live on the RevenueCat dashboard, linked from /revenue).
  const customers = await rcGet<{
    items?: Array<{
      active_entitlements?: { items?: Array<{ identifier?: string }> };
      most_recent_transaction?: { is_in_introductory_period?: boolean };
    }>;
  }>(`/projects/${projectId}/customers?limit=200`);

  if (!customers?.items) {
    return {
      active_subscribers: null,
      active_trials: null,
      mrr_usd: null,
      configured: true,
    };
  }
  const active = customers.items.filter(
    (c) => (c.active_entitlements?.items?.length ?? 0) > 0
  );
  const trials = active.filter(
    (c) => c.most_recent_transaction?.is_in_introductory_period === true
  );
  return {
    active_subscribers: active.length,
    active_trials: trials.length,
    mrr_usd: null, // Full MRR requires the analytics endpoint; punt to dashboard.
    configured: true,
  };
}
