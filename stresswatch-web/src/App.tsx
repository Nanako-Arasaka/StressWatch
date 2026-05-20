import { useState, type ReactNode } from "react";

type Language = "en" | "zh";

const copy = {
  en: {
    languageLabel: "Language",
    heroTitle: "StressWatch",
    heroLead: "Understand your wellness trends from Apple Watch data.",
    heroSub:
      "Track stress, recovery, HRV, sleep, and activity trends with a privacy-first HealthKit experience.",
    primaryCta: "View dashboard",
    secondaryCta: "Privacy first",
    healthKit: "HealthKit",
    search: "Search wellness trends",
    connected: "Apple Health Connected",
    localFirst: "Demo / Local-first",
    nav: ["Dashboard", "Trends", "Metrics", "Privacy", "Settings"],
    metrics: [
      { label: "Stress Score", value: "68", detail: "steady", tone: "bg-sun/25 text-ink" },
      { label: "Recovery", value: "74", detail: "good", tone: "bg-mint/35 text-ink" },
      { label: "HRV", value: "52 ms", detail: "+4%", tone: "bg-aqua/30 text-ink" },
      { label: "Sleep", value: "7h 32m", detail: "restful", tone: "bg-white/70 text-ink" },
      { label: "Steps", value: "8,420", detail: "active", tone: "bg-teal/10 text-ink" }
    ],
    panels: {
      stressTrend: "7-day Stress Trend",
      balanced: "balanced",
      hrv: "HRV",
      sleepTimeline: "Sleep Timeline",
      activityContext: "Activity context",
      stepsValue: "8,420 steps"
    },
    appleHealthBody: "Heart rate, HRV, resting heart rate, sleep, and step trends.",
    insightTitle: "Today's insight",
    insightBody:
      "Your wellness trend looks balanced. Use this as personal reference, not medical advice.",
    insightRows: [
      ["Stress", "68"],
      ["Recovery", "74"],
      ["Sleep", "7h 32m"]
    ],
    localTitle: "Local-first",
    localBody: "No backend, no login, and no account-based data collection.",
    features: [
      [
        "Apple Health integration",
        "Read Apple Watch wellness signals through a HealthKit-first experience."
      ],
      ["HRV trend insights", "See HRV movement in context without turning it into clinical guidance."],
      ["Recovery score", "A simple daily reference for rest, balance, and recent activity load."],
      ["Sleep context", "Connect sleep duration with stress and recovery trend changes."],
      ["Local-first privacy", "Designed around on-device data and no server-side collection."],
      ["No account required", "Open the app, connect HealthKit, and keep your data personal."]
    ],
    disclaimer:
      "This app is for personal wellness trend reference only. It does not provide medical diagnosis, treatment advice, or emergency services. Please consult a qualified professional for health concerns."
  },
  zh: {
    languageLabel: "语言",
    heroTitle: "StressWatch",
    heroLead: "从 Apple Watch 数据理解你的身心趋势。",
    heroSub: "以隐私优先的 HealthKit 体验追踪压力、恢复、HRV、睡眠和活动趋势。",
    primaryCta: "查看仪表盘",
    secondaryCta: "隐私优先",
    healthKit: "HealthKit",
    search: "搜索健康趋势",
    connected: "Apple Health 已连接",
    localFirst: "演示数据 / 本地优先",
    nav: ["仪表盘", "趋势", "指标", "隐私", "设置"],
    metrics: [
      { label: "压力分数", value: "68", detail: "平稳", tone: "bg-sun/25 text-ink" },
      { label: "恢复", value: "74", detail: "良好", tone: "bg-mint/35 text-ink" },
      { label: "HRV", value: "52 ms", detail: "+4%", tone: "bg-aqua/30 text-ink" },
      { label: "睡眠", value: "7h 32m", detail: "充分", tone: "bg-white/70 text-ink" },
      { label: "步数", value: "8,420", detail: "活跃", tone: "bg-teal/10 text-ink" }
    ],
    panels: {
      stressTrend: "7 天压力趋势",
      balanced: "较为平衡",
      hrv: "HRV",
      sleepTimeline: "睡眠时间线",
      activityContext: "活动参考",
      stepsValue: "8,420 步"
    },
    appleHealthBody: "心率、HRV、静息心率、睡眠和步数趋势参考。",
    insightTitle: "今日解读",
    insightBody: "你的健康趋势看起来较为平衡。请将它作为个人参考，而不是医疗建议。",
    insightRows: [
      ["压力", "68"],
      ["恢复", "74"],
      ["睡眠", "7h 32m"]
    ],
    localTitle: "本地优先",
    localBody: "不接后端、不需要登录，也不做账号级数据收集。",
    features: [
      ["Apple Health 集成", "通过 HealthKit 优先的体验读取 Apple Watch 健康趋势信号。"],
      ["HRV 趋势洞察", "把 HRV 变化放在上下文里观察，不输出临床建议。"],
      ["恢复分数", "为休息、平衡和近期活动负荷提供简单的每日参考。"],
      ["睡眠背景", "把睡眠时长与压力、恢复趋势变化联系起来观察。"],
      ["本地优先隐私", "围绕本机数据设计，不进行服务器端收集。"],
      ["无需账号", "打开 App、连接 HealthKit，并把数据留在自己手里。"]
    ],
    disclaimer:
      "本应用仅用于个人健康趋势参考，不提供医疗诊断、治疗建议或紧急服务。如有健康问题，请咨询具备资质的专业人士。"
  }
} satisfies Record<
  Language,
  {
    languageLabel: string;
    heroTitle: string;
    heroLead: string;
    heroSub: string;
    primaryCta: string;
    secondaryCta: string;
    healthKit: string;
    search: string;
    connected: string;
    localFirst: string;
    nav: string[];
    metrics: Array<{ label: string; value: string; detail: string; tone: string }>;
    panels: {
      stressTrend: string;
      balanced: string;
      hrv: string;
      sleepTimeline: string;
      activityContext: string;
      stepsValue: string;
    };
    appleHealthBody: string;
    insightTitle: string;
    insightBody: string;
    insightRows: string[][];
    localTitle: string;
    localBody: string;
    features: string[][];
    disclaimer: string;
  }
>;

function App() {
  const [language, setLanguage] = useState<Language>("en");
  const t = copy[language];

  return (
    <main
      className="min-h-screen overflow-hidden bg-[radial-gradient(circle_at_14%_10%,rgba(158,232,203,0.72),transparent_28%),linear-gradient(135deg,#f6fbf6_0%,#dff7ef_46%,#eefcfa_100%)] text-ink"
      lang={language === "zh" ? "zh-CN" : "en"}
    >
      <section className="relative mx-auto flex min-h-screen w-full max-w-[1440px] flex-col px-5 py-8 sm:px-8 lg:px-12">
        <div className="absolute -left-24 top-28 h-72 w-72 rounded-full bg-mint/45 blur-3xl" />
        <div className="absolute right-[-120px] top-16 h-80 w-80 rounded-full bg-aqua/30 blur-3xl" />

        <LanguageSwitch language={language} setLanguage={setLanguage} label={t.languageLabel} />

        <div className="relative z-10 grid flex-1 items-center gap-10 lg:grid-cols-[0.76fr_1.24fr]">
          <HeroCopy t={t} />
          <DashboardMockup t={t} />
        </div>

        <FeatureStrip features={t.features} />
        <Disclaimer text={t.disclaimer} />
      </section>
    </main>
  );
}

function LanguageSwitch({
  language,
  setLanguage,
  label
}: {
  language: Language;
  setLanguage: (language: Language) => void;
  label: string;
}) {
  return (
    <div className="relative z-20 mb-6 flex justify-end">
      <div
        aria-label={label}
        className="liquid-glass liquid-glass-soft flex items-center rounded-full border border-pine/10 bg-white/54 p-1 text-xs font-black text-pine shadow-soft"
      >
        {(["en", "zh"] as const).map((item) => (
          <button
            key={item}
            aria-pressed={language === item}
            className={`rounded-full px-4 py-2 transition ${
              language === item ? "bg-pine text-white shadow-soft" : "text-pine/58 hover:text-pine"
            }`}
            onClick={() => setLanguage(item)}
            type="button"
          >
            {item === "en" ? "EN" : "中文"}
          </button>
        ))}
      </div>
    </div>
  );
}

function HeroCopy({ t }: { t: (typeof copy)[Language] }) {
  return (
    <div className="max-w-xl animate-rise">
      <div className="mb-7 flex h-14 w-14 items-center justify-center rounded-3xl bg-pine text-2xl font-black text-mint shadow-soft">
        S
      </div>
      <h1 className="max-w-[10ch] text-6xl font-black leading-[0.92] tracking-normal text-ink sm:text-7xl lg:text-8xl">
        {t.heroTitle}
      </h1>
      <p className="mt-7 max-w-xl text-2xl font-semibold leading-tight text-pine sm:text-3xl">
        {t.heroLead}
      </p>
      <p className="mt-5 max-w-lg text-base leading-8 text-ink/68 sm:text-lg">{t.heroSub}</p>
      <div className="mt-9 flex flex-wrap gap-3">
        <a
          className="rounded-full bg-pine px-6 py-3 text-sm font-bold text-white shadow-soft transition hover:-translate-y-0.5 hover:bg-ink"
          href="#dashboard"
        >
          {t.primaryCta}
        </a>
        <a
          className="rounded-full border border-pine/15 bg-white/55 px-6 py-3 text-sm font-bold text-pine backdrop-blur transition hover:-translate-y-0.5 hover:bg-white"
          href="#privacy"
        >
          {t.secondaryCta}
        </a>
      </div>
    </div>
  );
}

function DashboardMockup({ t }: { t: (typeof copy)[Language] }) {
  return (
    <section
      id="dashboard"
      className="dashboard-shell liquid-glass liquid-glass-strong relative z-10 animate-float rounded-[2.35rem] border border-white/70 bg-white/58 p-3 shadow-glass sm:p-4"
      aria-label="StressWatch dashboard mockup"
    >
      <div className="grid min-h-[620px] overflow-hidden rounded-[1.8rem] bg-[#f8fcf8]/88 shadow-[inset_0_1px_0_rgba(255,255,255,0.82)] lg:grid-cols-[184px_minmax(0,1fr)_250px]">
        <Sidebar t={t} />
        <DashboardCenter t={t} />
        <InsightPanel t={t} />
      </div>
    </section>
  );
}

function Sidebar({ t }: { t: (typeof copy)[Language] }) {
  return (
    <aside className="flex flex-col bg-pine px-5 py-6 text-white lg:rounded-l-[1.8rem]">
      <div className="flex items-center gap-3">
        <div className="grid h-11 w-11 place-items-center rounded-2xl bg-mint text-lg font-black text-pine">
          S
        </div>
        <div>
          <p className="text-sm font-black">StressWatch</p>
          <p className="text-xs text-white/50">{t.healthKit}</p>
        </div>
      </div>

      <nav className="mt-10 space-y-2">
        {t.nav.map((item, index) => (
          <button
            className={`flex w-full items-center gap-3 rounded-2xl px-3 py-3 text-left text-sm font-bold transition hover:bg-white/12 ${
              index === 0 ? "bg-white text-pine shadow-soft" : "text-white/72"
            }`}
            key={item}
            type="button"
          >
            <span
              className={`h-2.5 w-2.5 rounded-full ${index === 0 ? "bg-sun" : "bg-white/28"}`}
            />
            {item}
          </button>
        ))}
      </nav>

      <div className="mt-auto rounded-3xl bg-white/10 p-4 text-xs leading-5 text-white/62">
        {t.localFirst}
        <div className="mt-4 h-20 rounded-2xl bg-[radial-gradient(circle_at_50%_35%,rgba(242,204,77,0.45),transparent_34%),linear-gradient(140deg,rgba(158,232,203,0.32),rgba(139,228,232,0.18))]" />
      </div>
    </aside>
  );
}

function DashboardCenter({ t }: { t: (typeof copy)[Language] }) {
  return (
    <div className="min-w-0 px-4 py-5 sm:px-6">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="liquid-glass liquid-glass-soft rounded-full border border-pine/10 bg-white/70 px-4 py-3 text-sm font-semibold text-ink/55 shadow-[0_10px_30px_rgba(20,53,46,0.07)]">
          {t.search}
        </div>
        <div className="flex flex-wrap gap-2">
          <StatusPill label={t.connected} />
          <StatusPill label={t.localFirst} muted />
        </div>
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        {t.metrics.map((metric, index) => (
          <MetricCard key={metric.label} metric={metric} index={index} />
        ))}
      </div>

      <div className="mt-5 grid gap-4 xl:grid-cols-[1.35fr_0.85fr]">
        <GlassPanel className="min-h-[246px]">
          <PanelHeader title={t.panels.stressTrend} value={t.panels.balanced} />
          <StressLineChart />
        </GlassPanel>

        <GlassPanel className="min-h-[246px]">
          <PanelHeader title={t.panels.hrv} value="52 ms" />
          <BarChart />
        </GlassPanel>
      </div>

      <div className="mt-4 grid gap-4 xl:grid-cols-[0.9fr_1.1fr]">
        <GlassPanel className="min-h-[176px]">
          <PanelHeader title={t.panels.sleepTimeline} value="7h 32m" />
          <SleepTimeline />
        </GlassPanel>

        <GlassPanel className="min-h-[176px]">
          <PanelHeader title={t.panels.activityContext} value={t.panels.stepsValue} />
          <div className="mt-5 grid grid-cols-7 gap-2">
            {[34, 48, 42, 68, 58, 76, 62].map((height, index) => (
              <div className="flex h-24 items-end rounded-full bg-pine/5 p-1" key={index}>
                <div
                  className="w-full rounded-full bg-gradient-to-t from-teal to-mint"
                  style={{ height: `${height}%` }}
                />
              </div>
            ))}
          </div>
        </GlassPanel>
      </div>
    </div>
  );
}

function InsightPanel({ t }: { t: (typeof copy)[Language] }) {
  return (
    <aside className="border-t border-pine/8 bg-white/52 p-5 lg:border-l lg:border-t-0">
      <div className="rounded-[1.7rem] bg-pine p-5 text-white shadow-soft">
        <div className="flex items-center justify-between">
          <p className="text-sm font-black">Apple Health</p>
          <span className="h-3 w-3 rounded-full bg-mint shadow-[0_0_0_6px_rgba(158,232,203,0.16)]" />
        </div>
        <p className="mt-2 text-xs leading-5 text-white/58">{t.appleHealthBody}</p>
      </div>

      <div className="liquid-glass liquid-glass-soft mt-4 rounded-[1.7rem] border border-white/70 bg-white/72 p-5 shadow-soft">
        <p className="text-sm font-black text-pine">{t.insightTitle}</p>
        <p className="mt-3 text-sm leading-6 text-ink/62">{t.insightBody}</p>
        <div className="mt-5 space-y-3">
          {t.insightRows.map(([label, value]) => (
            <InsightRow key={label} label={label} value={value} />
          ))}
        </div>
      </div>

      <div className="liquid-glass liquid-glass-soft mt-4 rounded-[1.7rem] bg-mint/26 p-5">
        <p className="text-sm font-black text-pine">{t.localTitle}</p>
        <p className="mt-2 text-xs leading-5 text-ink/55">{t.localBody}</p>
      </div>
    </aside>
  );
}

function StatusPill({ label, muted = false }: { label: string; muted?: boolean }) {
  return (
    <span
      className={`rounded-full px-4 py-2 text-xs font-black ${
        muted ? "bg-pine/8 text-pine/60" : "bg-mint/45 text-pine"
      }`}
    >
      {label}
    </span>
  );
}

function MetricCard({
  metric,
  index
}: {
  metric: { label: string; value: string; tone: string; detail: string };
  index: number;
}) {
  return (
    <article
      className={`liquid-glass liquid-glass-soft rounded-[1.35rem] border border-white/75 p-4 shadow-soft transition hover:-translate-y-1 ${metric.tone}`}
      style={{ animation: `rise 620ms ease-out ${index * 80}ms both` }}
    >
      <p className="text-[11px] font-black uppercase text-ink/45">{metric.label}</p>
      <p className="mt-3 text-2xl font-black leading-none">{metric.value}</p>
      <p className="mt-2 text-xs font-bold text-ink/48">{metric.detail}</p>
    </article>
  );
}

function GlassPanel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return (
    <article
      className={`liquid-glass liquid-glass-soft rounded-[1.6rem] border border-white/75 bg-white/70 p-5 shadow-soft transition hover:-translate-y-1 ${className}`}
    >
      {children}
    </article>
  );
}

function PanelHeader({ title, value }: { title: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <h2 className="text-sm font-black text-pine">{title}</h2>
      <span className="rounded-full bg-pine/7 px-3 py-1 text-xs font-black text-pine/62">{value}</span>
    </div>
  );
}

function StressLineChart() {
  return (
    <svg className="mt-5 h-44 w-full" viewBox="0 0 520 180" role="img" aria-label="7-day stress trend line chart">
      <defs>
        <linearGradient id="stressFill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="#9ee8cb" stopOpacity="0.52" />
          <stop offset="100%" stopColor="#9ee8cb" stopOpacity="0" />
        </linearGradient>
      </defs>
      {[34, 68, 102, 136].map((y) => (
        <line key={y} x1="0" x2="520" y1={y} y2={y} stroke="#14352e" strokeOpacity="0.08" />
      ))}
      <path
        d="M12 136 C 72 118, 82 76, 138 86 S 220 134, 280 92 S 372 48, 430 72 S 486 104, 508 76 L 508 170 L 12 170 Z"
        fill="url(#stressFill)"
      />
      <path
        className="animate-draw"
        d="M12 136 C 72 118, 82 76, 138 86 S 220 134, 280 92 S 372 48, 430 72 S 486 104, 508 76"
        fill="none"
        stroke="#2f7e70"
        strokeDasharray="440"
        strokeLinecap="round"
        strokeWidth="7"
      />
      {[12, 138, 280, 430, 508].map((x, index) => (
        <circle key={x} cx={x} cy={[136, 86, 92, 72, 76][index]} r="6" fill="#f2cc4d" stroke="#fff" strokeWidth="4" />
      ))}
    </svg>
  );
}

function BarChart() {
  const bars = [48, 64, 42, 76, 58, 84, 68];
  return (
    <div className="mt-6 flex h-40 items-end justify-between gap-3">
      {bars.map((height, index) => (
        <div className="flex flex-1 flex-col items-center gap-3" key={index}>
          <div className="flex h-32 w-full items-end rounded-full bg-pine/6 p-1.5">
            <div
              className="w-full rounded-full bg-gradient-to-t from-pine via-teal to-aqua"
              style={{ height: `${height}%` }}
            />
          </div>
          <span className="text-[10px] font-bold text-ink/38">{["M", "T", "W", "T", "F", "S", "S"][index]}</span>
        </div>
      ))}
    </div>
  );
}

function SleepTimeline() {
  return (
    <div className="mt-7 space-y-4">
      <div className="h-6 overflow-hidden rounded-full bg-pine/8">
        <div className="h-full w-[23%] rounded-full bg-aqua" />
      </div>
      <div className="h-6 overflow-hidden rounded-full bg-pine/8">
        <div className="h-full w-[71%] rounded-full bg-pine" />
      </div>
      <div className="flex justify-between text-[11px] font-bold text-ink/40">
        <span>23:10</span>
        <span>06:42</span>
      </div>
    </div>
  );
}

function InsightRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between rounded-2xl bg-pine/5 px-3 py-3">
      <span className="text-xs font-bold text-ink/48">{label}</span>
      <span className="text-sm font-black text-pine">{value}</span>
    </div>
  );
}

function FeatureStrip({ features }: { features: string[][] }) {
  return (
    <section className="relative z-10 mt-12 grid gap-4 md:grid-cols-2 xl:grid-cols-6" aria-label="StressWatch features">
      {features.map(([title, body], index) => (
        <article
          className="liquid-glass liquid-glass-soft rounded-[1.5rem] border border-white/72 bg-white/48 p-5 shadow-soft transition hover:-translate-y-1 hover:bg-white/68"
          key={title}
          style={{ animation: `rise 640ms ease-out ${220 + index * 80}ms both` }}
        >
          <div className="mb-5 h-9 w-9 rounded-2xl bg-gradient-to-br from-mint to-aqua shadow-[0_10px_28px_rgba(47,126,112,0.18)]" />
          <h3 className="text-sm font-black text-pine">{title}</h3>
          <p className="mt-3 text-xs leading-5 text-ink/55">{body}</p>
        </article>
      ))}
    </section>
  );
}

function Disclaimer({ text }: { text: string }) {
  return (
    <section
      id="privacy"
      className="liquid-glass liquid-glass-soft relative z-10 mt-6 rounded-[1.5rem] border border-pine/8 bg-white/42 p-5 text-sm leading-7 text-ink/64"
    >
      {text}
    </section>
  );
}

export default App;
