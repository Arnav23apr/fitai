import Link from "next/link";

const NAV = [
  { href: "/", label: "Overview", icon: "📊" },
  { href: "/reports", label: "Reports", icon: "🚩" },
  { href: "/feedback", label: "Feedback", icon: "💬" },
  { href: "/users", label: "Users", icon: "👥" },
  { href: "/revenue", label: "Revenue", icon: "💰" },
];

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen flex">
      <aside className="w-60 shrink-0 border-r border-slate-200 bg-white flex flex-col">
        <div className="px-5 py-6 border-b border-slate-200">
          <div className="text-lg font-bold text-slate-900">FitAI Admin</div>
          <div className="text-xs text-slate-500 mt-0.5">Internal</div>
        </div>

        <nav className="flex-1 px-3 py-4 space-y-1">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-slate-700 hover:bg-slate-100 transition"
            >
              <span className="text-base">{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>

        <div className="p-3 border-t border-slate-200">
          <form action="/api/logout" method="POST">
            <button
              type="submit"
              className="w-full text-left flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-100 transition"
            >
              <span>↩</span>
              <span>Sign out</span>
            </button>
          </form>
        </div>
      </aside>

      <main className="flex-1 overflow-y-auto">
        <div className="max-w-7xl mx-auto px-8 py-8">{children}</div>
      </main>
    </div>
  );
}
