import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";

type Language = "en" | "zh";
type SectionId = "dashboard" | "trends" | "metrics" | "privacy" | "settings";

const sectionIds: SectionId[] = ["dashboard", "trends", "metrics", "privacy", "settings"];

const stressTrendData = [
  { day: "Mon", date: "5/15", score: 42 },
  { day: "Tue", date: "5/16", score: 58 },
  { day: "Wed", date: "5/17", score: 51 },
  { day: "Thu", date: "5/18", score: 64 },
  { day: "Fri", date: "5/19", score: 72 },
  { day: "Sat", date: "5/20", score: 60 },
  { day: "Sun", date: "5/21", score: 68 }
];

const hrvTrendData = [48, 51, 47, 54, 52, 56, 52];
const hrvTrendPoints = [
  { date: "5/15", time: "07:12", value: 48 },
  { date: "5/16", time: "07:04", value: 51 },
  { date: "5/17", time: "06:58", value: 47 },
  { date: "5/18", time: "07:20", value: 54 },
  { date: "5/19", time: "06:49", value: 52 },
  { date: "5/20", time: "07:08", value: 56 },
  { date: "5/21", time: "07:16", value: 52 }
];
const stressSparkData = [38, 44, 51, 57, 62, 60, 68];
const recoverySparkData = [62, 66, 64, 70, 72, 76, 74];
const activityWeekData = [
  { day: "M", date: "5/15", energy: 410, exercise: 28, stand: 10, energyGoal: 500, exerciseGoal: 30, standGoal: 12 },
  { day: "T", date: "5/16", energy: 520, exercise: 36, stand: 12, energyGoal: 500, exerciseGoal: 30, standGoal: 12 },
  { day: "W", date: "5/17", energy: 455, exercise: 24, stand: 11, energyGoal: 500, exerciseGoal: 30, standGoal: 12 },
  { day: "T", date: "5/18", energy: 610, exercise: 42, stand: 13, energyGoal: 500, exerciseGoal: 30, standGoal: 12 },
  { day: "F", date: "5/19", energy: 575, exercise: 34, stand: 12, energyGoal: 500, exerciseGoal: 30, standGoal: 12 },
  { day: "S", date: "5/20", energy: 690, exercise: 48, stand: 14, energyGoal: 500, exerciseGoal: 30, standGoal: 12 },
  { day: "S", date: "5/21", energy: 620, exercise: 39, stand: 13, energyGoal: 500, exerciseGoal: 30, standGoal: 12 }
];

function getStressStatus(score: number, language: Language) {
  if (score <= 35) {
    return language === "zh" ? "状态稳定" : "Stable";
  }
  if (score <= 60) {
    return language === "zh" ? "轻微压力" : "Light stress";
  }
  if (score <= 80) {
    return language === "zh" ? "注意压力" : "Watch stress";
  }
  return language === "zh" ? "压力较高" : "Higher stress";
}

function useRevealOnView<T extends Element>() {
  const ref = useRef<T | null>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element || isVisible) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry?.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: "0px 0px -12% 0px", threshold: 0.22 }
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, [isVisible]);

  return { isVisible, ref };
}

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
  const [activeSection, setActiveSection] = useState<SectionId>("dashboard");
  const t = copy[language];

  useEffect(() => {
    const updateActiveSection = () => {
      const activationLine = window.scrollY + window.innerHeight * 0.22;
      const sections = sectionIds
        .map((id) => {
          const element = document.getElementById(id);
          if (!element) {
            return null;
          }

          return {
            id,
            top: element.getBoundingClientRect().top + window.scrollY
          };
        })
        .filter((section): section is { id: SectionId; top: number } => section !== null)
        .sort((a, b) => a.top - b.top);

      const active = sections.reduce<SectionId>((current, section) => {
        return section.top <= activationLine ? section.id : current;
      }, "dashboard");

      setActiveSection(active);
    };

    updateActiveSection();
    window.addEventListener("scroll", updateActiveSection, { passive: true });
    window.addEventListener("resize", updateActiveSection);

    return () => {
      window.removeEventListener("scroll", updateActiveSection);
      window.removeEventListener("resize", updateActiveSection);
    };
  }, []);

  return (
    <main
      className="font-apple-body min-h-screen overflow-x-hidden bg-[radial-gradient(circle_at_14%_10%,rgba(158,232,203,0.72),transparent_28%),linear-gradient(135deg,#f6fbf6_0%,#dff7ef_46%,#eefcfa_100%)] text-ink"
      lang={language === "zh" ? "zh-CN" : "en"}
    >
      <section className="relative mx-auto flex min-h-screen w-full max-w-[1440px] flex-col px-5 py-8 sm:px-8 lg:px-12">
        <div className="absolute -left-24 top-28 h-72 w-72 rounded-full bg-mint/45 blur-3xl" />
        <div className="absolute right-[-120px] top-16 h-80 w-80 rounded-full bg-aqua/30 blur-3xl" />

        <LanguageSwitch language={language} setLanguage={setLanguage} label={t.languageLabel} />

        <div className="relative z-10 grid flex-1 items-start gap-10">
          <HeroCopy t={t} />
          <DashboardMockup activeSection={activeSection} language={language} setActiveSection={setActiveSection} t={t} />
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
        className="liquid-glass liquid-glass-soft relative flex items-center rounded-full border border-pine/10 bg-white/54 p-1 text-xs font-black text-pine shadow-soft"
      >
        <span
          className={`absolute bottom-1 top-1 w-[52px] rounded-full bg-pine shadow-soft transition-transform duration-300 ease-out ${
            language === "zh" ? "translate-x-[52px]" : "translate-x-0"
          }`}
        />
        {(["en", "zh"] as const).map((item) => (
          <button
            key={item}
            aria-pressed={language === item}
            className={`relative z-10 w-[52px] rounded-full py-2 transition duration-300 ease-out hover:scale-105 ${
              language === item ? "text-white" : "text-pine/58 hover:text-pine"
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
    <div className="max-w-xl animate-rise [@media(min-width:1180px)]:max-w-[320px] min-[1320px]:max-w-md min-[1500px]:max-w-xl">
      <LogoMark className="mb-7 h-16 w-16 shadow-soft" />
      <h1 className="type-hero-title max-w-[10ch] text-6xl leading-[0.92] text-ink sm:text-7xl [@media(min-width:1180px)]:text-5xl min-[1320px]:text-6xl min-[1500px]:text-8xl">
        {t.heroTitle}
      </h1>
      <p className="type-section-title mt-7 max-w-xl text-2xl leading-tight text-pine min-[1500px]:text-3xl">
        {t.heroLead}
      </p>
      <p className="type-body mt-5 max-w-lg text-base leading-8 text-ink/68 min-[1500px]:text-lg">{t.heroSub}</p>
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

function DashboardMockup({
  activeSection,
  language,
  setActiveSection,
  t
}: {
  activeSection: SectionId;
  language: Language;
  setActiveSection: (section: SectionId) => void;
  t: (typeof copy)[Language];
}) {
  return (
    <section
      id="dashboard"
      className="dashboard-shell liquid-glass liquid-glass-strong relative z-10 w-full max-w-[760px] justify-self-start animate-float rounded-[2.35rem] border border-white/70 bg-white/58 p-3 shadow-glass sm:p-4"
      aria-label="StressWatch dashboard mockup"
    >
      <div className="grid min-h-[620px] overflow-visible rounded-[1.8rem] bg-[#f8fcf8]/88 shadow-[inset_0_1px_0_rgba(255,255,255,0.82)]">
        <Sidebar activeSection={activeSection} setActiveSection={setActiveSection} t={t} />
        <DashboardCenter language={language} t={t} />
        <InsightPanel t={t} />
      </div>
    </section>
  );
}

function Sidebar({
  activeSection,
  setActiveSection,
  t
}: {
  activeSection: SectionId;
  setActiveSection: (section: SectionId) => void;
  t: (typeof copy)[Language];
}) {
  const handleNavClick = (section: SectionId) => {
    setActiveSection(section);
    document.getElementById(section)?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  return (
    <aside className="flex flex-col rounded-t-[1.8rem] bg-pine px-5 py-6 text-white">
      <div className="flex items-center gap-3">
        <LogoMark className="h-12 w-12" />
        <div>
          <p className="text-sm font-black">StressWatch</p>
          <p className="text-xs text-white/50">{t.healthKit}</p>
        </div>
      </div>

      <nav className="mt-6 grid grid-cols-2 gap-2 min-[640px]:grid-cols-5">
        {t.nav.map((item, index) => {
          const section = sectionIds[index];
          const isActive = activeSection === section;

          return (
          <button
            className={`group flex w-full items-center justify-center gap-2 rounded-2xl px-3 py-3 text-center text-xs font-bold transition duration-300 hover:scale-[1.02] hover:bg-white/12 min-[640px]:justify-start min-[640px]:text-left ${
              isActive ? "bg-white text-pine shadow-soft" : "text-white/72"
            }`}
            key={item}
            onClick={() => handleNavClick(section)}
            type="button"
          >
            <span
              className={`h-2.5 w-2.5 rounded-full transition duration-300 ${
                isActive
                  ? "bg-sun shadow-[0_0_18px_rgba(242,204,77,0.75)]"
                  : "bg-white/28 group-hover:bg-mint/70"
              }`}
            />
            {item}
          </button>
          );
        })}
      </nav>

      <div className="hidden">
        {t.localFirst}
        <div className="mt-4 h-20 rounded-2xl bg-[radial-gradient(circle_at_50%_35%,rgba(242,204,77,0.45),transparent_34%),linear-gradient(140deg,rgba(158,232,203,0.32),rgba(139,228,232,0.18))]" />
      </div>
    </aside>
  );
}

function LogoMark({ className = "" }: { className?: string }) {
  return (
    <img
      alt="StressWatch logo"
      className={`rounded-[1.15rem] object-cover ${className}`}
      draggable={false}
      src="./stresswatch-logo.svg"
    />
  );
}

function DashboardCenter({ language, t }: { language: Language; t: (typeof copy)[Language] }) {
  return (
    <div className="min-w-0 px-4 py-5 sm:px-6">
      <div className="flex flex-col gap-4 min-[1320px]:flex-row min-[1320px]:items-center min-[1320px]:justify-between">
        <div className="liquid-glass liquid-glass-soft rounded-full border border-pine/10 bg-white/70 px-4 py-3 text-sm font-semibold text-ink/55 shadow-[0_10px_30px_rgba(20,53,46,0.07)]">
          {t.search}
        </div>
        <div className="flex flex-wrap gap-2">
          <StatusPill label={t.connected} />
          <StatusPill label={t.localFirst} muted />
        </div>
      </div>

      <div id="metrics" className="scroll-mt-24 mt-5 grid gap-3 sm:grid-cols-2 [@media(min-width:1180px)]:grid-cols-3 min-[1320px]:grid-cols-5">
        {t.metrics.map((metric, index) => (
          <MetricCard key={metric.label} language={language} metric={metric} index={index} />
        ))}
      </div>

      <div id="trends" className="scroll-mt-24 mt-5 grid gap-4 xl:grid-cols-[1.35fr_0.85fr]">
        <GlassPanel className="min-h-[246px]">
          <PanelHeader title={t.panels.stressTrend} value={t.panels.balanced} />
          <StressLineChart language={language} />
        </GlassPanel>

        <GlassPanel className="min-h-[246px]">
          <PanelHeader title={t.panels.hrv} value="52 ms · +4%" />
          <HRVTrendCard language={language} />
        </GlassPanel>
      </div>

      <div className="mt-4 grid gap-4">
        <GlassPanel className="min-h-[176px]">
          <PanelHeader title={t.panels.sleepTimeline} value="7h 32m" />
          <SleepPanel language={language} />
        </GlassPanel>

        <GlassPanel className="min-h-[236px]">
          <PanelHeader title={t.panels.activityContext} value={t.panels.stepsValue} />
          <ActivityPanel language={language} />
        </GlassPanel>
      </div>
    </div>
  );
}

function InsightPanel({ t }: { t: (typeof copy)[Language] }) {
  return (
    <aside className="border-t border-pine/8 bg-white/52 p-5">
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

      <div id="settings" className="liquid-glass liquid-glass-soft mt-4 scroll-mt-24 rounded-[1.7rem] bg-mint/26 p-5">
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
  language,
  metric,
  index
}: {
  language: Language;
  metric: { label: string; value: string; tone: string; detail: string };
  index: number;
}) {
  const variant = ["stress", "recovery", "hrv", "sleep", "steps"][index] ?? "default";
  const helper =
    language === "zh"
      ? ["趋势上行", "恢复良好", "高于基线", "Sleep Score 84", "活动稳定"][index]
      : ["Trending up", "Good recovery", "Above baseline", "Sleep Score 84", "Steady activity"][index];

  return (
    <article
      className={`liquid-glass liquid-glass-soft group rounded-[1.35rem] border border-white/75 p-4 shadow-soft transition duration-300 hover:-translate-y-1.5 hover:scale-[1.015] ${metric.tone}`}
      style={{ animation: `rise 620ms ease-out ${index * 80}ms both` }}
    >
      <p className="type-caption text-[11px] uppercase text-ink/45">{metric.label}</p>
      <p className="type-metric-number metric-value-pulse mt-3 text-2xl leading-none transition duration-300 group-hover:text-teal">
        {metric.value}
      </p>
      <div className="mt-2 flex items-center justify-between gap-3">
        <p className="type-caption text-xs text-ink/48">{metric.detail}</p>
        <span className="rounded-full bg-white/55 px-2 py-1 text-[10px] font-black text-pine/58">
          {helper}
        </span>
      </div>
      {variant === "stress" ? <MiniSparkline values={stressSparkData} color="#2f7e70" /> : null}
      {variant === "recovery" ? <MiniSparkline values={recoverySparkData} color="#40a884" /> : null}
      {variant === "hrv" ? <MiniSparkline values={hrvTrendData} color="#1d91a6" /> : null}
      {variant === "sleep" ? <SleepMiniRings /> : null}
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
      <h2 className="type-card-title text-sm text-pine">{title}</h2>
      <span className="type-caption rounded-full bg-pine/7 px-3 py-1 text-xs text-pine/62">{value}</span>
    </div>
  );
}

function StressLineChart({ language }: { language: Language }) {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const { isVisible, ref } = useRevealOnView<HTMLDivElement>();
  const points = stressTrendData.map((item, index) => ({
    ...item,
    x: 18 + index * 80,
    y: 152 - ((item.score - 30) / 55) * 112
  }));
  const linePath = buildSmoothPath(points);
  const areaPath = `${linePath} L ${points[points.length - 1].x} 170 L ${points[0].x} 170 Z`;
  const hovered = hoveredIndex === null ? null : points[hoveredIndex];
  const tooltip = hovered
    ? {
        x: Math.min(Math.max(hovered.x - 72, 8), 372),
        y: Math.max(hovered.y - 78, 8),
        status: getStressStatus(hovered.score, language),
        date: language === "zh" ? hovered.date : `${hovered.day} ${hovered.date}`
      }
    : null;

  return (
    <div className="relative mt-5 h-44 w-full" ref={ref}>
      <svg className="h-full w-full" viewBox="0 0 520 180" role="img" aria-label="7-day stress trend line chart">
        <defs>
          <linearGradient id="stressLine" x1="0" x2="1" y1="0" y2="0">
            <stop offset="0%" stopColor="#8be4e8" />
            <stop offset="45%" stopColor="#2f7e70" />
            <stop offset="100%" stopColor="#f2cc4d" />
          </linearGradient>
          <linearGradient id="stressFill" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#9ee8cb" stopOpacity="0.5" />
            <stop offset="100%" stopColor="#9ee8cb" stopOpacity="0" />
          </linearGradient>
          <filter id="tooltipShadow" x="-20%" y="-20%" width="140%" height="150%">
            <feDropShadow dx="0" dy="8" floodColor="#14352e" floodOpacity="0.16" stdDeviation="8" />
          </filter>
        </defs>
        {[34, 68, 102, 136].map((y) => (
          <line key={y} x1="0" x2="520" y1={y} y2={y} stroke="#14352e" strokeOpacity="0.08" />
        ))}
        <path d={areaPath} fill="url(#stressFill)" />
        <path
          className={isVisible ? "animate-draw" : "chart-line-hidden"}
          d={linePath}
          fill="none"
          stroke="url(#stressLine)"
          strokeDasharray="620"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="5"
        />
        {points.map((point, index) => {
          const isHovered = hoveredIndex === index;

          return (
            <g
              className="cursor-pointer transition-transform duration-300"
              key={point.date}
              onMouseEnter={() => setHoveredIndex(index)}
              onMouseLeave={() => setHoveredIndex(null)}
            >
              <circle cx={point.x} cy={point.y} r="16" fill="transparent" />
              <circle
                className="transition-all duration-300"
                cx={point.x}
                cy={point.y}
                fill={isHovered ? "#20493f" : "#f2cc4d"}
                r={isHovered ? "9" : "6"}
                stroke="#fff"
                strokeWidth="4"
              />
            </g>
          );
        })}
        {hovered && tooltip ? (
          <g className="animate-tooltip-svg pointer-events-none" filter="url(#tooltipShadow)">
            <rect
              fill="rgba(255,255,255,0.82)"
              height="58"
              rx="14"
              stroke="rgba(255,255,255,0.78)"
              strokeWidth="1"
              width="140"
              x={tooltip.x}
              y={tooltip.y}
            />
            <text fill="#14352e" fontFamily="Nunito Sans, Noto Sans SC, sans-serif" fontSize="11" fontWeight="800" x={tooltip.x + 14} y={tooltip.y + 18}>
              {tooltip.date}
            </text>
            <text fill="#20493f" fontFamily="Nunito Sans, Noto Sans SC, sans-serif" fontSize="20" fontWeight="900" x={tooltip.x + 14} y={tooltip.y + 41}>
              {hovered.score}
            </text>
            <text fill="#2f7e70" fontFamily="Nunito Sans, Noto Sans SC, sans-serif" fontSize="11" fontWeight="800" x={tooltip.x + 52} y={tooltip.y + 39}>
              {tooltip.status}
            </text>
          </g>
        ) : null}
      </svg>
    </div>
  );
}

function HRVTrendCard({ language }: { language: Language }) {
  return (
    <div className="mt-5">
      <div className="flex items-end justify-between gap-4">
        <div>
          <p className="type-metric-number text-4xl text-pine">52</p>
          <p className="type-caption text-xs text-ink/45">
            ms · {language === "zh" ? "今日 07:16" : "today 07:16"}
          </p>
        </div>
        <div className="rounded-2xl bg-mint/35 px-3 py-2 text-right">
          <p className="type-caption text-xs text-pine">+4%</p>
          <p className="text-[11px] font-bold text-ink/45">
            {language === "zh" ? "高于基线" : "above baseline"}
          </p>
        </div>
      </div>
      <HRVTrendChart language={language} />
    </div>
  );
}

function HRVTrendChart({ language }: { language: Language }) {
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const { isVisible, ref } = useRevealOnView<HTMLDivElement>();
  const baseline = 50;
  const min = 42;
  const max = 58;
  const points = hrvTrendPoints.map((point, index) => ({
    ...point,
    x: 18 + index * 38,
    y: 96 - ((point.value - min) / (max - min)) * 76
  }));
  const path = buildSmoothPath(points);
  const baselineY = 96 - ((baseline - min) / (max - min)) * 76;
  const hovered = hoveredIndex === null ? null : points[hoveredIndex];
  const tooltip = hovered
    ? {
        x: Math.min(Math.max(hovered.x - 68, 8), 374),
        y: Math.max(hovered.y - 76, 6),
        status:
          hovered.value >= baseline
            ? language === "zh"
              ? "高于基线"
              : "above baseline"
            : language === "zh"
              ? "低于基线"
              : "below baseline"
      }
    : null;

  return (
    <div className="mt-6" ref={ref}>
      <svg className="h-36 w-full overflow-visible" viewBox="0 0 280 132" aria-label="HRV seven day trend with baseline">
        <defs>
          <linearGradient id="hrvLine" x1="0" x2="1" y1="0" y2="0">
            <stop offset="0%" stopColor="#8be4e8" />
            <stop offset="100%" stopColor="#20493f" />
          </linearGradient>
          <linearGradient id="hrvGlow" x1="0" x2="0" y1="0" y2="1">
            <stop offset="0%" stopColor="#8be4e8" stopOpacity="0.32" />
            <stop offset="100%" stopColor="#8be4e8" stopOpacity="0" />
          </linearGradient>
          <filter id="hrvTooltipShadow" x="-20%" y="-20%" width="140%" height="150%">
            <feDropShadow dx="0" dy="8" floodColor="#14352e" floodOpacity="0.16" stdDeviation="8" />
          </filter>
        </defs>
        <line
          className="baseline-dash"
          stroke="#20493f"
          strokeDasharray="6 7"
          strokeLinecap="round"
          strokeOpacity="0.28"
          strokeWidth="2"
          x1="10"
          x2="270"
          y1={baselineY}
          y2={baselineY}
        />
        <g className="pointer-events-none">
          <rect
            fill="rgba(255,255,255,0.74)"
            height="20"
            rx="10"
            stroke="rgba(255,255,255,0.78)"
            strokeWidth="1"
            width={language === "zh" ? "76" : "94"}
            x={language === "zh" ? "190" : "172"}
            y={baselineY - 28}
          />
          <text
            fill="#20493f"
            fontFamily="Nunito Sans, Noto Sans SC, sans-serif"
            fontSize="10"
            fontWeight="900"
            opacity="0.68"
            x={language === "zh" ? "202" : "184"}
            y={baselineY - 14}
          >
            {language === "zh" ? "基线 50 ms" : "baseline 50 ms"}
          </text>
        </g>
        <path d={`${path} L ${points[points.length - 1].x} 120 L ${points[0].x} 120 Z`} fill="url(#hrvGlow)" />
        <path
          className={isVisible ? "hrv-line-draw" : "chart-line-hidden"}
          d={path}
          fill="none"
          stroke="url(#hrvLine)"
          strokeDasharray="280"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="5"
        />
        {points.map((point, index) => {
          const isHovered = hoveredIndex === index;

          return (
            <g
              className="cursor-pointer"
              key={point.date}
              onMouseEnter={() => setHoveredIndex(index)}
              onMouseLeave={() => setHoveredIndex(null)}
            >
              <circle cx={point.x} cy={point.y} fill="transparent" r="15" />
              <circle
                className={`${isVisible ? "hrv-point-pop" : "chart-point-hidden"} transition-all duration-300`}
                cx={point.x}
                cy={point.y}
                fill={point.value >= baseline ? "#8be4e8" : "#f2cc4d"}
                r={isHovered ? "7.5" : "4.8"}
                stroke="#fff"
                strokeWidth="3"
                style={{ animationDelay: `${240 + index * 55}ms` }}
              />
            </g>
          );
        })}
        {hovered && tooltip ? (
          <g className="animate-tooltip-svg pointer-events-none" filter="url(#hrvTooltipShadow)">
            <rect
              fill="rgba(255,255,255,0.84)"
              height="58"
              rx="14"
              stroke="rgba(255,255,255,0.78)"
              strokeWidth="1"
              width="132"
              x={tooltip.x}
              y={tooltip.y}
            />
            <text fill="#14352e" fontFamily="Nunito Sans, Noto Sans SC, sans-serif" fontSize="11" fontWeight="800" x={tooltip.x + 12} y={tooltip.y + 18}>
              {hovered.date} · {hovered.time}
            </text>
            <text fill="#20493f" fontFamily="Nunito Sans, Noto Sans SC, sans-serif" fontSize="20" fontWeight="900" x={tooltip.x + 12} y={tooltip.y + 42}>
              {hovered.value}
            </text>
            <text fill="#2f7e70" fontFamily="Nunito Sans, Noto Sans SC, sans-serif" fontSize="11" fontWeight="800" x={tooltip.x + 48} y={tooltip.y + 40}>
              {tooltip.status}
            </text>
          </g>
        ) : null}
      </svg>
    </div>
  );
}

function SleepPanel({ language }: { language: Language }) {
  const { isVisible, ref } = useRevealOnView<HTMLDivElement>();

  return (
    <div className="mt-4 grid gap-5 sm:grid-cols-[128px_minmax(0,1fr)]" ref={ref}>
      <div className="flex justify-center">
        <MultiRing score={84} />
      </div>
      <div className="space-y-2">
        <SleepStage color="bg-sun" delay={0} isVisible={isVisible} label={language === "zh" ? "清醒" : "Awake"} percent={18} value="18m" />
        <SleepStage color="bg-aqua" delay={80} isVisible={isVisible} label="REM" percent={58} value="1h 32m" />
        <SleepStage color="bg-teal" delay={160} isVisible={isVisible} label="Core" percent={86} value="4h 44m" />
        <SleepStage color="bg-pine" delay={240} isVisible={isVisible} label="Deep" percent={42} value="58m" />
        <p className="type-caption pt-1 text-xs text-ink/48">
          {language === "zh" ? "今日睡眠状态：恢复良好" : "Sleep state: restorative"}
        </p>
      </div>
    </div>
  );
}

function MiniSparkline({
  className = "mt-4 h-10",
  color,
  values
}: {
  className?: string;
  color: string;
  values: number[];
}) {
  const min = Math.min(...values);
  const max = Math.max(...values);
  const points = values.map((value, index) => ({
    x: 8 + index * (104 / Math.max(values.length - 1, 1)),
    y: 38 - ((value - min) / Math.max(max - min, 1)) * 28
  }));
  const path = buildSmoothPath(points);

  return (
    <svg className={`w-full ${className}`} viewBox="0 0 120 46" aria-hidden="true">
      <path
        className="animate-draw-fast"
        d={path}
        fill="none"
        stroke={color}
        strokeDasharray="160"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="4"
      />
      <circle cx={points[points.length - 1].x} cy={points[points.length - 1].y} r="4.5" fill={color} />
    </svg>
  );
}

function SleepMiniRings() {
  return (
    <div className="mt-4 flex items-center gap-3">
      <MultiRing compact score={84} />
      <div className="type-caption text-[11px] leading-5 text-ink/50">
        <p>REM 1h 32m</p>
        <p>Deep 58m</p>
      </div>
    </div>
  );
}

function MultiRing({ compact = false, score }: { compact?: boolean; score: number }) {
  const size = compact ? 62 : 118;
  const center = size / 2;
  const rings = [
    { color: "#8be4e8", radius: compact ? 27 : 52, value: 0.78 },
    { color: "#2f7e70", radius: compact ? 21 : 42, value: 0.72 },
    { color: "#20493f", radius: compact ? 15 : 32, value: 0.56 }
  ];

  return (
    <div
      className="group relative shrink-0 transition duration-300 hover:-translate-y-1 hover:scale-[1.03]"
      style={{ height: size, width: size }}
    >
      <svg className="block" height={size} viewBox={`0 0 ${size} ${size}`} width={size}>
        {rings.map((ring, index) => {
          const circumference = 2 * Math.PI * ring.radius;

          return (
            <g key={ring.color} style={{ animationDelay: `${index * 80}ms` }}>
              <circle
                cx={center}
                cy={center}
                fill="none"
                r={ring.radius}
                stroke="rgba(20,53,46,0.08)"
                strokeWidth={compact ? 4 : 7}
              />
              <circle
                className="ring-progress"
                cx={center}
                cy={center}
                fill="none"
                r={ring.radius}
                stroke={ring.color}
                strokeDasharray={circumference}
                strokeDashoffset={circumference * (1 - ring.value)}
                strokeLinecap="round"
                strokeWidth={compact ? 4 : 7}
                transform={`rotate(-90 ${center} ${center})`}
              />
            </g>
          );
        })}
      </svg>
      <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
        <div className="max-w-[54px] text-center leading-none">
          <p className={`type-metric-number text-pine ${compact ? "text-sm" : "text-3xl"}`}>{score}</p>
        </div>
      </div>
      {!compact ? (
        <p className="type-caption absolute left-1/2 top-full mt-2 -translate-x-1/2 whitespace-nowrap text-[10px] text-ink/42">
          Sleep Score
        </p>
      ) : null}
    </div>
  );
}

function SleepStage({
  color,
  delay,
  isVisible,
  label,
  percent,
  value
}: {
  color: string;
  delay: number;
  isVisible: boolean;
  label: string;
  percent: number;
  value: string;
}) {
  return (
    <div
      className={`${isVisible ? "sleep-stage-cell" : "sleep-stage-hidden"} group rounded-2xl bg-pine/5 px-3 py-2 transition duration-300 hover:-translate-y-0.5 hover:bg-white/58 hover:shadow-soft`}
      style={{ animationDelay: `${delay}ms` }}
    >
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-2 text-xs font-bold text-ink/55">
          <span className={`h-2.5 w-2.5 rounded-full ${color} transition duration-300 group-hover:scale-125`} />
          {label}
        </span>
        <span className="type-metric-number text-sm text-pine">{value}</span>
      </div>
      <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-pine/8">
        <div
          className={`${isVisible ? "sleep-stage-fill" : "sleep-stage-fill-hidden"} h-full rounded-full ${color}`}
          style={{ "--stage-width": `${percent}%`, animationDelay: `${delay + 120}ms` } as CSSProperties}
        />
      </div>
    </div>
  );
}

function ActivityPanel({ language }: { language: Language }) {
  const [selectedIndex, setSelectedIndex] = useState(activityWeekData.length - 1);
  const { isVisible, ref } = useRevealOnView<HTMLDivElement>();
  const selectedDay = activityWeekData[selectedIndex];
  const averages = activityWeekData.reduce(
    (total, day) => ({
      energy: total.energy + day.energy,
      exercise: total.exercise + day.exercise,
      stand: total.stand + day.stand
    }),
    { energy: 0, exercise: 0, stand: 0 }
  );
  const weeklyAverage = {
    energy: Math.round(averages.energy / activityWeekData.length),
    exercise: Math.round(averages.exercise / activityWeekData.length),
    stand: Math.round(averages.stand / activityWeekData.length)
  };

  return (
    <div className="mt-5 grid gap-5 min-[700px]:grid-cols-[1.15fr_0.85fr]" ref={ref}>
      <ActivityBars selectedIndex={selectedIndex} setSelectedIndex={setSelectedIndex} />

      <div className="grid gap-3">
        <div
          className={`liquid-glass liquid-glass-soft rounded-[1.2rem] bg-white/58 p-4 ${
            isVisible ? "scroll-reveal" : "opacity-0"
          }`}
        >
          <p className="type-caption text-[11px] uppercase text-ink/42">
            {language === "zh" ? "本周平均" : "Weekly average"}
          </p>
          <div className="mt-3 grid grid-cols-3 gap-2">
            <ActivityStat label={language === "zh" ? "活动千焦" : "kJ"} value={`${weeklyAverage.energy}`} />
            <ActivityStat label={language === "zh" ? "锻炼" : "Exercise"} value={`${weeklyAverage.exercise}m`} />
            <ActivityStat label={language === "zh" ? "站立" : "Stand"} value={`${weeklyAverage.stand}`} />
          </div>
        </div>

        <div
          className={`rounded-[1.2rem] bg-pine/5 p-4 ${isVisible ? "scroll-reveal" : "opacity-0"}`}
          style={{ animationDelay: "120ms" }}
        >
          <div className="flex items-center justify-between gap-3">
            <p className="type-card-title text-sm text-pine">
              {language === "zh" ? `${selectedDay.date} 活动` : `${selectedDay.date} activity`}
            </p>
            <span className="rounded-full bg-mint/45 px-3 py-1 text-[11px] font-black text-pine">
              {selectedDay.day}
            </span>
          </div>
          <div className="mt-3 space-y-2">
            <GoalRow label={language === "zh" ? "活动千焦" : "Active energy"} value={`${selectedDay.energy} kJ`} goal={`${selectedDay.energyGoal} kJ`} ratio={selectedDay.energy / selectedDay.energyGoal} />
            <GoalRow label={language === "zh" ? "锻炼时长" : "Exercise"} value={`${selectedDay.exercise} min`} goal={`${selectedDay.exerciseGoal} min`} ratio={selectedDay.exercise / selectedDay.exerciseGoal} />
            <GoalRow label={language === "zh" ? "站立次数" : "Stand"} value={`${selectedDay.stand} h`} goal={`${selectedDay.standGoal} h`} ratio={selectedDay.stand / selectedDay.standGoal} />
          </div>
        </div>
      </div>
    </div>
  );
}

function ActivityStat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl bg-pine/5 px-3 py-3 text-center">
      <p className="type-metric-number text-lg text-pine">{value}</p>
      <p className="type-caption mt-1 text-[10px] text-ink/42">{label}</p>
    </div>
  );
}

function GoalRow({ goal, label, ratio, value }: { goal: string; label: string; ratio: number; value: string }) {
  return (
    <div>
      <div className="flex items-center justify-between gap-3 text-xs">
        <span className="font-bold text-ink/52">{label}</span>
        <span className="type-metric-number text-pine">
          {value}
          <span className="ml-1 text-[10px] font-bold text-ink/38">/ {goal}</span>
        </span>
      </div>
      <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-pine/8">
        <div className="h-full rounded-full bg-gradient-to-r from-teal to-mint" style={{ width: `${Math.min(ratio, 1) * 100}%` }} />
      </div>
    </div>
  );
}

function ActivityBars({
  selectedIndex,
  setSelectedIndex
}: {
  selectedIndex: number;
  setSelectedIndex: (index: number) => void;
}) {
  const { isVisible, ref } = useRevealOnView<HTMLDivElement>();

  return (
    <div ref={ref}>
      <div className="grid grid-cols-7 gap-2">
        {activityWeekData.map((day, index) => {
          const height = (day.energy / 720) * 100;
          const isSelected = selectedIndex === index;

          return (
            <button
              aria-label={`${day.date} activity ${day.energy} kJ`}
              className={`group flex h-32 items-end rounded-full p-1 transition duration-300 hover:-translate-y-1 hover:bg-white/55 ${
                isSelected ? "bg-mint/35 shadow-soft" : "bg-pine/5"
              }`}
              key={`${day.date}-${index}`}
              onClick={() => setSelectedIndex(index)}
              type="button"
            >
              <div
                className={`${isVisible ? "activity-bar" : "activity-bar-hidden"} w-full rounded-full bg-gradient-to-t from-teal to-mint transition duration-300 group-hover:scale-x-110`}
                style={{ "--bar-height": `${height}%`, animationDelay: `${index * 70}ms` } as CSSProperties}
              />
            </button>
          );
        })}
      </div>
      <div className="mt-2 grid grid-cols-7 gap-2 text-center">
        {activityWeekData.map((day, index) => (
          <button
            className={`type-caption rounded-full py-1 text-[10px] transition duration-300 ${
              selectedIndex === index ? "bg-pine text-white" : "text-ink/42 hover:bg-pine/7"
            }`}
            key={`${day.date}-label`}
            onClick={() => setSelectedIndex(index)}
            type="button"
          >
            {day.day}
          </button>
        ))}
      </div>
    </div>
  );
}

function buildSmoothPath(points: Array<{ x: number; y: number }>) {
  if (points.length === 0) {
    return "";
  }

  return points.reduce((path, point, index) => {
    if (index === 0) {
      return `M ${point.x} ${point.y}`;
    }

    const previous = points[index - 1];
    const controlX = (previous.x + point.x) / 2;
    return `${path} C ${controlX} ${previous.y}, ${controlX} ${point.y}, ${point.x} ${point.y}`;
  }, "");
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
    <section className="scroll-reveal relative z-10 mt-12 grid gap-4 md:grid-cols-2 xl:grid-cols-6" aria-label="StressWatch features">
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
      className="liquid-glass liquid-glass-soft scroll-reveal relative z-10 mt-6 scroll-mt-24 rounded-[1.5rem] border border-pine/8 bg-white/42 p-5 text-sm leading-7 text-ink/64"
    >
      {text}
    </section>
  );
}

export default App;
