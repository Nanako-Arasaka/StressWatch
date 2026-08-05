import { useEffect, useRef, useState, type ReactNode } from "react";

type Lang = "en" | "zh";

/* ───────────────────────── Data (universal, not copy) ───────────────────────── */
const stressTrendData = [
  { day: "Mon", date: "5/15", score: 42, label: "一" },
  { day: "Tue", date: "5/16", score: 58, label: "二" },
  { day: "Wed", date: "5/17", score: 51, label: "三" },
  { day: "Thu", date: "5/18", score: 64, label: "四" },
  { day: "Fri", date: "5/19", score: 72, label: "五" },
  { day: "Sat", date: "5/20", score: 60, label: "六" },
  { day: "Sun", date: "5/21", score: 68, label: "日" }
];

const monthlyStress = [55, 62, 48, 70, 58, 44, 66, 52, 60, 49, 57, 63, 46, 54];

const heatmapValues = Array.from({ length: 70 }, (_, i) => {
  const r = Math.floor(i / 10);
  const c = i % 10;
  return (Math.sin((r + 1) * 0.7) * Math.cos((c + 1) * 0.5) + 1) / 2;
});

// Recovery heatmap color scale: low recovery reads warm (red/orange),
// high recovery reads cool (green/blue). A multi-hue ramp gives clear
// contrast where a single blue could not. Shared by cells + legend.
const HEAT_STOPS: { p: number; c: string }[] = [
  { p: 0.0, c: "#FF453A" }, // red    — low recovery
  { p: 0.28, c: "#FF9F0A" }, // orange
  { p: 0.52, c: "#FFD60A" }, // yellow
  { p: 0.76, c: "#30D158" }, // green
  { p: 1.0, c: "#2997FF" } // blue   — high recovery (Action Blue)
];

const heatGradientCss = `linear-gradient(90deg, ${HEAT_STOPS.map((s) => `${s.c} ${(s.p * 100).toFixed(0)}%`).join(", ")})`;

function heatmapColor(v: number): string {
  const t = Math.max(0, Math.min(1, v));
  const toRgb = (h: string) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
  for (let i = 0; i < HEAT_STOPS.length - 1; i++) {
    const s = HEAT_STOPS[i];
    const e = HEAT_STOPS[i + 1];
    if (t >= s.p && t <= e.p) {
      const k = (t - s.p) / (e.p - s.p);
      const a = toRgb(s.c);
      const b = toRgb(e.c);
      const ch = (x: number, y: number) => Math.round(x + (y - x) * k);
      return `rgb(${ch(a[0], b[0])}, ${ch(a[1], b[1])}, ${ch(a[2], b[2])})`;
    }
  }
  return HEAT_STOPS[HEAT_STOPS.length - 1].c;
}

const sleepColors: Record<string, string> = {
  awake: "#FF9F0A",
  rem: "#BF5AF2",
  core: "#5AC8FA",
  deep: "#0A84FF"
};

const liveState = { value: 42, bpm: 72, confidence: 0.92 };

/* ───────────────────────── Copy (bilingual) ───────────────────────── */
type Copy = {
  nav: { dashboard: string; features: string; how: string; privacy: string; download: string; languageLabel: string };
  hero: { badge: string; title: string; subtitle: string; primaryCta: string; secondaryCta: string; trust: string };
  dashboard: {
    title: string;
    subtitle: string;
    connected: string;
    metrics: { label: string; value: string; detail: string }[];
    panelTitle: string;
    panelStatus: string;
  };
  liveStress: { eyebrow: string; title: string; tagline: string; cta: string; live: string; bpmLabel: string; level: string };
  aiAnalysis: {
    eyebrow: string;
    title: string;
    tagline: string;
    cta: string;
    predictedState: string;
    confidence: string;
    assessments: { label: string; value: number; level: string }[];
    ringNote: string;
  };
  trends: { eyebrow: string; title: string; tagline: string; cta: string; monthlyLabel: string; daysLabel: string; heatmapLabel: string; monthlyNote: string; heatmapNote: string; heatmapLow: string; heatmapHigh: string };
  sleep: { eyebrow: string; title: string; tagline: string; cta: string; legendTitle: string; note: string; stages: { key: string; label: string; minutes: number }[] };
  checkIn: { eyebrow: string; title: string; tagline: string; cta: string; items: { title: string; detail: string }[]; addHint: string };
  privacy: {
    eyebrow: string;
    title: string;
    subtitle: string;
    items: { title: string; desc: string }[];
    cardTitle: string;
    cardDesc: string;
    chips: string[];
    cta: string;
  };
  footer: { tagline: string; columns: { title: string; links: string[] }[]; copyright: string; disclaimer: string };
};

const copy: Record<Lang, Copy> = {
  en: {
    nav: { dashboard: "Dashboard", features: "Features", how: "How it works", privacy: "Privacy", download: "Download App", languageLabel: "Language" },
    hero: {
      badge: "Apple Health · Local-first",
      title: "Read every signal your body sends",
      subtitle:
        "Track stress, recovery, HRV, sleep, and activity from your Apple Watch. Private by design — your data never leaves your device.",
      primaryCta: "View dashboard",
      secondaryCta: "Privacy first",
      trust: "No account · No server upload · Native HealthKit"
    },
    dashboard: {
      title: "Today",
      subtitle: "Personal wellness trend reference",
      connected: "Connected",
      metrics: [
        { label: "Stress", value: "68", detail: "Balanced" },
        { label: "Recovery", value: "74", detail: "Good" },
        { label: "HRV", value: "52 ms", detail: "+4%" }
      ],
      panelTitle: "7-day stress trend",
      panelStatus: "Balanced"
    },
    liveStress: {
      eyebrow: "Live Stress",
      title: "Feel your stress, in real time",
      tagline: "A live ring reads your heart rate and HRV the moment they change — so you notice tension before it builds.",
      cta: "See live stress",
      live: "LIVE",
      bpmLabel: "BPM",
      level: "Balanced"
    },
    aiAnalysis: {
      eyebrow: "AI Analysis",
      title: "Know your state, with confidence",
      tagline: "On-device models predict your current state and score four dimensions — stress, sleep, recovery, and HRV.",
      cta: "Explore analysis",
      predictedState: "Balanced",
      confidence: "confidence",
      assessments: [
        { label: "Stress", value: 68, level: "Balanced" },
        { label: "Sleep", value: 74, level: "Good" },
        { label: "Recovery", value: 71, level: "Good" },
        { label: "HRV", value: 52, level: "Steady" }
      ],
      ringNote: "The ring shows how confident the on-device model is in its state prediction."
    },
    trends: {
      eyebrow: "Trends",
      title: "See the long arc of your wellbeing",
      tagline: "Monthly stress, distribution, and recovery heatmaps turn daily numbers into patterns you can act on.",
      cta: "View trends",
      monthlyLabel: "Monthly stress",
      daysLabel: "days",
      heatmapLabel: "Recovery heatmap",
      monthlyNote: "Bar height shows that day's stress score — taller and deeper blue means higher stress.",
      heatmapNote: "Each cell is one time block across the last 7 days. Color runs from red (low recovery) to blue (high recovery).",
      heatmapLow: "Low recovery",
      heatmapHigh: "High recovery"
    },
    sleep: {
      eyebrow: "Sleep",
      title: "Understand every stage of rest",
      tagline: "REM, Core, Deep, and Awake are broken out automatically — see what kind of night your body actually had.",
      cta: "Sleep insights",
      legendTitle: "Last night",
      stages: [
        { key: "awake", label: "Awake", minutes: 18 },
        { key: "rem", label: "REM", minutes: 102 },
        { key: "core", label: "Core", minutes: 268 },
        { key: "deep", label: "Deep", minutes: 84 }
      ],
      note: "The bar is split into sleep stages; each color maps to a stage shown below."
    },
    checkIn: {
      eyebrow: "Daily Check-in",
      title: "A minute a day, for you",
      tagline: "Log mood, rate energy, and note what shaped your day. Check-ins sharpen every prediction.",
      cta: "Start check-in",
      items: [
        { title: "Mood logged", detail: "Calm · 4:20 PM" },
        { title: "Energy rated", detail: "7 / 10" },
        { title: "Factor added", detail: "Evening run · 5 km" }
      ],
      addHint: "Tap to add a note, a factor, or how you feel…"
    },
    privacy: {
      eyebrow: "Privacy & Local-first",
      title: "Your health data belongs to you only",
      subtitle:
        "StressWatch is designed local-first from day one: no account, no cloud upload, all analysis happens on your device.",
      items: [
        { title: "No account required", desc: "Open and use. No registration or login." },
        { title: "No cloud upload", desc: "Health data never leaves your device. No remote server." },
        { title: "On-device AI", desc: "Trend analysis is completed locally and works offline." }
      ],
      cardTitle: "Data stays on device",
      cardDesc: "All health data is stored only on your iPhone / Apple Watch.",
      chips: ["HealthKit", "Local storage", "Offline"],
      cta: "Read the privacy note"
    },
    footer: {
      tagline: "Read every signal your body sends.",
      columns: [
        { title: "Product", links: ["Dashboard", "Live Stress", "AI Analysis", "Trends", "Sleep"] },
        { title: "Resources", links: ["Privacy whitepaper", "Support", "Changelog"] },
        { title: "Company", links: ["About", "Contact"] },
        { title: "Privacy", links: ["Local-first", "HealthKit", "Data security"] }
      ],
      copyright: "Copyright 2026 · StressWatch. All rights reserved.",
      disclaimer: "This app is for personal wellness trend reference only and does not constitute medical advice."
    }
  },
  zh: {
    nav: { dashboard: "仪表盘", features: "功能", how: "工作原理", privacy: "隐私", download: "下载 App", languageLabel: "语言" },
    hero: {
      badge: "Apple Health 集成 · 本地优先",
      title: "读懂身体发出的每一个信号",
      subtitle: "基于 Apple Watch，追踪压力、恢复、HRV、睡眠与活动趋势。隐私优先——数据从不离开你的设备。",
      primaryCta: "查看仪表盘",
      secondaryCta: "了解隐私",
      trust: "无需账号 · 不上传服务器 · HealthKit 原生集成"
    },
    dashboard: {
      title: "今日状态",
      subtitle: "个人健康趋势参考",
      connected: "已连接",
      metrics: [
        { label: "压力", value: "68", detail: "较为平衡" },
        { label: "恢复", value: "74", detail: "良好" },
        { label: "HRV", value: "52 ms", detail: "+4%" }
      ],
      panelTitle: "7天压力趋势",
      panelStatus: "较为平衡"
    },
    liveStress: {
      eyebrow: "实时压力",
      title: "实时感知你的压力",
      tagline: "当心率与 HRV 变化的瞬间，实时环即刻读出——让你在紧张累积前就察觉。",
      cta: "查看实时压力",
      live: "实时",
      bpmLabel: "心率",
      level: "较为平衡"
    },
    aiAnalysis: {
      eyebrow: "AI 分析",
      title: "读懂状态，更有把握",
      tagline: "本机模型预测你当前的状态，并为四个维度打分——压力、睡眠、恢复与 HRV。",
      cta: "探索分析",
      predictedState: "较为平衡",
      confidence: "置信度",
      assessments: [
        { label: "压力", value: 68, level: "较为平衡" },
        { label: "睡眠", value: 74, level: "良好" },
        { label: "恢复", value: 71, level: "良好" },
        { label: "HRV", value: 52, level: "平稳" }
      ],
      ringNote: "圆环表示本机模型对当前状态判断的把握程度。"
    },
    trends: {
      eyebrow: "趋势",
      title: "看见身心状态的长期走向",
      tagline: "月度压力、分布与恢复热力图，把每日数字变成可执行的规律。",
      cta: "查看趋势",
      monthlyLabel: "月度压力",
      daysLabel: "天",
      heatmapLabel: "恢复热力图",
      monthlyNote: "柱高表示当天的压力评分，越高、颜色越深代表压力越大。",
      heatmapNote: "每个格子是过去 7 天里的一个时段。颜色由红（恢复低）到蓝（恢复高）依次过渡。",
      heatmapLow: "恢复低",
      heatmapHigh: "恢复高"
    },
    sleep: {
      eyebrow: "睡眠",
      title: "读懂每一段休息",
      tagline: "REM、Core、Deep 与 Awake 自动拆分——看清你的身体究竟度过了怎样的夜晚。",
      cta: "睡眠洞察",
      legendTitle: "昨夜",
      stages: [
        { key: "awake", label: "清醒", minutes: 18 },
        { key: "rem", label: "REM", minutes: 102 },
        { key: "core", label: "核心", minutes: 268 },
        { key: "deep", label: "深睡", minutes: 84 }
      ],
      note: "条带按睡眠阶段拆分，每一种颜色对应下方的一个阶段。"
    },
    checkIn: {
      eyebrow: "每日打卡",
      title: "每天一分钟，为你自己",
      tagline: "记录心情、为精力打分、记下塑造这一天的关键。打卡让每一次预测更精准。",
      cta: "开始打卡",
      items: [
        { title: "已记录心情", detail: "平静 · 16:20" },
        { title: "精力评分", detail: "7 / 10" },
        { title: "已添加因素", detail: "晚间跑步 · 5 公里" }
      ],
      addHint: "点击添加一条笔记、一个因素，或此刻的感受…"
    },
    privacy: {
      eyebrow: "隐私 & 本地优先",
      title: "你的健康数据，只属于你",
      subtitle: "StressWatch 从设计之初就选择本地优先：不建账号、不上传云端，所有分析在本机完成。",
      items: [
        { title: "无账号设计", desc: "打开即用，无需注册或登录。" },
        { title: "不上传云端", desc: "健康数据绝不出本机，没有远程服务器。" },
        { title: "本机 AI 计算", desc: "趋势分析在设备本地完成，离线可用。" }
      ],
      cardTitle: "数据留在本机",
      cardDesc: "所有健康数据仅存储于你的 iPhone / Apple Watch。",
      chips: ["HealthKit", "本机存储", "离线可用"],
      cta: "阅读隐私说明"
    },
    footer: {
      tagline: "读懂身体的每一次信号。",
      columns: [
        { title: "产品", links: ["仪表盘", "实时压力", "AI 分析", "趋势", "睡眠"] },
        { title: "资源", links: ["隐私白皮书", "支持中心", "更新日志"] },
        { title: "公司", links: ["关于我们", "联系我们"] },
        { title: "隐私", links: ["本地优先", "HealthKit", "数据安全"] }
      ],
      copyright: "Copyright 2026 · StressWatch. 保留所有权利。",
      disclaimer: "本应用仅提供健康趋势参考，不构成医疗建议。"
    }
  }
};

/* ───────────────────────── Hooks & helpers ───────────────────────── */
/* Position-adaptive activation. A section is "active" once its top rises
   above 82% of the viewport height:
   - scroll DOWN into it  -> top crosses the line -> activates (load in)
   - keep scrolling DOWN  -> top goes negative (above viewport) -> STAYS
     active, never disappears (already-loaded upper parts persist)
   - scroll back UP       -> top drops below the line again -> deactivates
     (reverse / retreat), so it re-animates next time you pass it.
   Reduced-motion users get a static, always-active state. */
function useRevealOnView<T extends Element>() {
  const ref = useRef<T | null>(null);
  const [active, setActive] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      setActive(true);
      return;
    }

    let ticking = false;
    const compute = () => {
      ticking = false;
      const rect = element.getBoundingClientRect();
      const vh = window.innerHeight || document.documentElement.clientHeight;
      setActive(rect.top < vh * 0.82);
    };
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(compute);
    };

    compute();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, []);

  return { active, ref };
}

function buildSmoothPath(points: Array<{ x: number; y: number }>) {
  if (points.length === 0) return "";
  return points.reduce((path, point, index) => {
    if (index === 0) return `M ${point.x} ${point.y}`;
    const previous = points[index - 1];
    const controlX = (previous.x + point.x) / 2;
    return `${path} C ${controlX} ${previous.y}, ${controlX} ${point.y}, ${point.x} ${point.y}`;
  }, "");
}

/* ───────────────────────── App shell ───────────────────────── */
function App() {
  const [language, setLanguage] = useState<Lang>("zh");
  const t = copy[language];

  // Light cross-fade when switching language: bump a key so the main
  // element remounts with the lang-fade-in animation (CSS, ~250ms).
  // Keeps scroll position intact (window scrollY isn't reset by a
  // key change on the same node tree) and avoids resetting the chart
  // animations because the user is at the same spot.
  const [langTick, setLangTick] = useState(0);
  const switchLanguage = (l: Lang) => {
    if (l === language) return;
    setLangTick((n) => n + 1);
    setLanguage(l);
  };

  return (
    <>
      <main
        key={langTick}
        className="lang-fade font-apple min-h-screen overflow-x-hidden bg-white text-ink antialiased"
        lang={language === "zh" ? "zh-CN" : "en"}
      >
        <NavBar language={language} setLanguage={switchLanguage} t={t} />
        <HeroSection language={language} t={t} />
        <LiveStressTile t={t} />
        <AIAnalysisTile t={t} />
        <TrendsTile t={t} />
        <SleepTile t={t} />
        <CheckInTile t={t} />
        <PrivacyTile t={t} />
        <Footer t={t} />
      </main>
      <CursorParticles />
    </>
  );
}

/* ───────────────────────── Nav ───────────────────────── */
function NavBar({ language, setLanguage, t }: { language: Lang; setLanguage: (l: Lang) => void; t: Copy }) {
  const [scrolled, setScrolled] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Lock body scroll while the mobile sheet is open so the page can't
  // drift behind the menu.
  useEffect(() => {
    document.body.style.overflow = mobileOpen ? "hidden" : "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [mobileOpen]);

  const scrollTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth", block: "start" });
    setMobileOpen(false);
  };

  const navItems = [
    { label: t.nav.dashboard, id: "hero" },
    { label: t.nav.features, id: "live" },
    { label: t.nav.how, id: "trends" },
    { label: t.nav.privacy, id: "privacy" }
  ];

  return (
    <header className={`apple-nav fixed inset-x-0 top-0 z-50 h-11 ${scrolled ? "scrolled" : ""}`}>
      <nav className="mx-auto flex h-11 max-w-[1024px] items-center justify-between px-4 sm:px-5">
        <a
          className="focus-ring flex items-center gap-2 rounded-md transition hover:opacity-80"
          href="#"
          onClick={(e) => {
            e.preventDefault();
            window.scrollTo({ top: 0, behavior: "smooth" });
          }}
        >
          <LogoMark className="h-5 w-5" />
          <span className="text-[14px] font-semibold tracking-tight text-white">StressWatch</span>
        </a>

        <div className="hidden items-center gap-8 md:flex">
          {navItems.map((item) => (
            <button
              key={item.id}
              className="focus-ring rounded-md text-[12px] font-normal text-white/80 transition hover:text-white"
              onClick={() => scrollTo(item.id)}
              type="button"
            >
              {item.label}
            </button>
          ))}
        </div>

        <div className="flex items-center gap-2 sm:gap-3">
          <LangToggle language={language} setLanguage={setLanguage} />
          <button
            className="focus-ring hidden rounded-full bg-[#2997ff] px-3.5 py-1 text-[12px] font-semibold text-white transition hover:brightness-110 active:scale-95 motion-safe:hover:-translate-y-px sm:block"
            type="button"
          >
            {t.nav.download}
          </button>
          {/* Hamburger — only on < md where the inline menu is hidden */}
          <button
            type="button"
            aria-label={mobileOpen ? "Close menu" : "Open menu"}
            aria-expanded={mobileOpen}
            aria-controls="mobile-nav"
            onClick={() => setMobileOpen((v) => !v)}
            className="focus-ring flex h-8 w-8 items-center justify-center rounded-md text-white/90 transition hover:text-white md:hidden"
          >
            {mobileOpen ? (
              <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
              </svg>
            ) : (
              <svg viewBox="0 0 24 24" className="h-4 w-4" aria-hidden="true">
                <path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
              </svg>
            )}
          </button>
        </div>
      </nav>

      {/* Mobile sheet — full-bleed, scrim + drawer, scroll-locked body */}
      <div
        id="mobile-nav"
        className={`fixed inset-x-0 top-11 z-40 origin-top transition-[transform,opacity] duration-300 md:hidden ${
          mobileOpen ? "pointer-events-auto opacity-100" : "pointer-events-none opacity-0"
        }`}
        aria-hidden={!mobileOpen}
      >
        <div className="bg-black/85 backdrop-blur-xl">
          <ul className="mx-auto flex max-w-[640px] flex-col px-6 py-3">
            {navItems.map((item) => (
              <li key={item.id}>
                <button
                  type="button"
                  onClick={() => scrollTo(item.id)}
                  className="focus-ring flex w-full items-center justify-between border-b border-white/10 py-4 text-left text-[15px] font-medium text-white/90 transition hover:text-white"
                >
                  {item.label}
                  <span className="text-white/40" aria-hidden="true">›</span>
                </button>
              </li>
            ))}
            <li className="pt-4">
              <button
                type="button"
                onClick={() => setMobileOpen(false)}
                className="focus-ring w-full rounded-full bg-[#2997ff] py-2.5 text-[14px] font-semibold text-white active:scale-95"
              >
                {t.nav.download}
              </button>
            </li>
          </ul>
        </div>
      </div>
    </header>
  );
}

function LangToggle({ language, setLanguage }: { language: Lang; setLanguage: (l: Lang) => void }) {
  return (
    <div className="flex items-center rounded-full bg-white/10 p-0.5 text-[12px] font-semibold" aria-label="Language">
      {(["en", "zh"] as const).map((l) => (
        <button
          key={l}
          onClick={() => setLanguage(l)}
          type="button"
          aria-pressed={language === l}
          className={`focus-ring rounded-full px-2.5 py-1 transition ${
            language === l ? "bg-white text-ink" : "text-white/70 hover:text-white"
          }`}
        >
          {l === "en" ? "EN" : "中"}
        </button>
      ))}
    </div>
  );
}

/* ───────────────────────── Hero ───────────────────────── */
function HeroSection({ language, t }: { language: Lang; t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLElement>();
  const h = t.hero;

  return (
    <section
      id="hero"
      ref={ref}
      className={`bg-white px-5 pb-24 pt-32 reveal-group sm:pb-28 sm:pt-40 ${active ? "is-active" : ""}`}
    >
      <div className="reveal-item mx-auto max-w-[820px] text-center">
        <span className="type-eyebrow text-blue">{h.badge}</span>
        <h1 className="type-hero mt-3 text-ink">{h.title}</h1>
        <p className="type-lead mx-auto mt-5 max-w-[640px] text-ink-2">{h.subtitle}</p>
        <div className="mt-7 flex flex-col items-center justify-center gap-4 sm:flex-row sm:gap-6">
          <a href="#live" className="reveal-item apple-cta-primary" style={{ transitionDelay: "0.3s" }}>
            {h.primaryCta}
          </a>
          <a href="#privacy" className="reveal-item apple-cta-link text-blue" style={{ transitionDelay: "0.45s" }}>
            {h.secondaryCta} ›
          </a>
        </div>
        <p className="reveal-item type-caption mx-auto mt-6 max-w-[520px] text-ink-2" style={{ transitionDelay: "0.6s" }}>
          {h.trust}
        </p>
      </div>

      <div className="reveal-item mx-auto mt-16 max-w-[720px]" style={{ transitionDelay: "0.15s" }}>
        <DashboardMockup language={language} t={t} active={active} />
      </div>
    </section>
  );
}

function DashboardMockup({ language, t, active }: { language: Lang; t: Copy; active: boolean }) {
  const d = t.dashboard;
  return (
    <div className="product-shadow mx-auto w-full max-w-[640px] rounded-[28px] border border-black/10 bg-white p-6">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h2 className="type-tagline text-ink">{d.title}</h2>
          <p className="type-caption text-ink-2">{d.subtitle}</p>
        </div>
        <span className="inline-flex shrink-0 items-center gap-1.5 rounded-full bg-[#e8f7ec] px-3 py-1.5 text-[12px] font-semibold text-[#1d8a3f]">
          <span className="h-1.5 w-1.5 rounded-full bg-[#34c759]" />
          {d.connected}
        </span>
      </div>

      <div className="mt-6 grid grid-cols-3 gap-3">
        {d.metrics.map((m, i) => (
          <div key={m.label} className="reveal-item rounded-2xl bg-parchment p-4" style={{ transitionDelay: `${0.25 + i * 0.09}s` }}>
            <p className="type-caption text-ink-2">{m.label}</p>
            <p className="type-metric mt-2 text-3xl font-semibold text-ink">{m.value}</p>
            <p className="type-caption mt-1 text-[11px] font-semibold text-blue">{m.detail}</p>
          </div>
        ))}
      </div>

      <div className="mt-5 rounded-2xl bg-parchment p-5">
        <div className="flex items-center justify-between gap-4">
          <h3 className="text-[14px] font-semibold text-ink">{d.panelTitle}</h3>
          <span className="rounded-full bg-blue/10 px-3 py-1 text-[11px] font-semibold text-blue">{d.panelStatus}</span>
        </div>
        <div className="relative mt-4 h-36 w-full">
          <StressLineChart active={active} language={language} />
        </div>
      </div>
    </div>
  );
}

function StressLineChart({ active, language }: { active: boolean; language: Lang }) {
  const points = stressTrendData.map((item, index) => ({
    ...item,
    x: 30 + index * 80,
    y: 120 - ((item.score - 35) / 45) * 80
  }));
  const linePath = buildSmoothPath(points);
  const areaPath = `${linePath} L ${points[points.length - 1].x} 130 L ${points[0].x} 130 Z`;
  const labels = language === "zh" ? stressTrendData.map((d) => d.label) : stressTrendData.map((d) => d.day);

  return (
    <svg className="h-full w-full" viewBox="0 0 580 140" role="img" aria-label="7-day stress trend line chart">
      <defs>
        <linearGradient id="stressFill" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0%" stopColor="#0066cc" stopOpacity="0.14" />
          <stop offset="100%" stopColor="#0066cc" stopOpacity="0" />
        </linearGradient>
      </defs>
      {[30, 60, 90, 120].map((y) => (
        <line key={y} x1="0" x2="580" y1={y} y2={y} stroke="#1d1d1f" strokeOpacity="0.06" />
      ))}
      <path d={areaPath} fill="url(#stressFill)" />
      <path
        className={active ? "animate-[draw_1.4s_ease-out_both]" : "chart-line-hidden"}
        d={linePath}
        fill="none"
        stroke="#0066cc"
        strokeDasharray="620"
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth="4"
      />
      {points.map((point, index) => (
        <circle
          key={point.date}
          cx={point.x}
          cy={point.y}
          fill={index === 0 || index === points.length - 1 ? "#0066cc" : "#2997ff"}
          r={index === 4 ? "6" : "5"}
          stroke="white"
          strokeWidth="3"
        />
      ))}
      {points.map((point, index) => (
        <text key={`label-${point.date}`} fill="#86868b" fontFamily="var(--font-apple)" fontSize="10" textAnchor="middle" x={point.x} y="135">
          {labels[index]}
        </text>
      ))}
    </svg>
  );
}

/* ───────────────────────── Tile primitives ───────────────────────── */
type Theme = "light" | "parchment" | "dark";

function Tile({ theme, id, children }: { theme: Theme; id?: string; children: ReactNode }) {
  const bg =
    theme === "dark"
      ? "bg-[#272729] text-white"
      : theme === "parchment"
        ? "bg-parchment text-ink"
        : "bg-white text-ink";
  return (
    <section id={id} className={`px-5 py-20 sm:py-28 ${bg}`}>
      {children}
    </section>
  );
}

function TileHeading({
  theme,
  eyebrow,
  title,
  tagline,
  cta,
  ctaHref
}: {
  theme: Theme;
  eyebrow: string;
  title: string;
  tagline: string;
  cta?: string;
  ctaHref?: string;
}) {
  const isDark = theme === "dark";
  return (
    <div className="reveal-item mx-auto max-w-[680px] text-center">
      <span className={`type-eyebrow ${isDark ? "text-blue-sky" : "text-blue"}`}>{eyebrow}</span>
      <h2 className="type-display mt-3">{title}</h2>
      <p className={`type-lead mt-4 ${isDark ? "text-white/70" : "text-ink-2"}`}>{tagline}</p>
      {cta && (
        <div className="mt-6">
          <a href={ctaHref ?? "#"} className={`apple-cta-link ${isDark ? "text-blue-sky" : "text-blue"}`}>
            {cta} ›
          </a>
        </div>
      )}
    </div>
  );
}

/* ───────────────────────── Tile 1 — Live Stress (dark) ───────────────────────── */
function LiveStressTile({ t }: { t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const s = t.liveStress;
  return (
    <Tile theme="dark" id="live">
      <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
        <TileHeading theme="dark" eyebrow={s.eyebrow} title={s.title} tagline={s.tagline} cta={s.cta} ctaHref="#live" />
        <div className="reveal-item mx-auto mt-12 max-w-[520px]" style={{ transitionDelay: "0.12s" }}>
          <LiveStressMockup t={t} active={active} />
        </div>
      </div>
    </Tile>
  );
}

function LiveStressMockup({ t, active }: { t: Copy; active: boolean }) {
  const v = liveState.value;
  const C = 2 * Math.PI * 80;
  const offset = C * (1 - v / 100);
  const s = t.liveStress;

  return (
    <div className="mockup-card product-shadow-dark mx-auto w-full max-w-[520px] rounded-[28px] border border-white/10 bg-black/40 p-6 sm:p-8">
      <div className="flex items-center justify-between">
        <span className="inline-flex items-center gap-2 text-[12px] font-semibold uppercase tracking-wider text-white/60">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-[#2997ff] opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-[#2997ff]" />
          </span>
          {s.live}
        </span>
        <span className="text-[13px] font-medium text-white/60">
          {liveState.bpm} {s.bpmLabel}
        </span>
      </div>

      <div className="mt-6 flex flex-col items-center">
        <div className="relative aspect-square w-[180px] sm:w-[200px]">
          <div className="ring-breathe h-full w-full">
          <svg viewBox="0 0 200 200" className="h-full w-full -rotate-90">
            <circle cx="100" cy="100" r="80" fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="14" />
            <circle
              cx="100"
              cy="100"
              r="80"
              fill="none"
              stroke="#2997ff"
              strokeWidth="14"
              strokeLinecap="round"
              strokeDasharray={C}
              strokeDashoffset={active ? offset : C}
              style={{ transition: "stroke-dashoffset 1.4s var(--ease-out)" }}
            />
          </svg>
          </div>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="type-metric text-5xl font-semibold text-white">{v}</span>
            <span className="mt-1 text-[15px] font-medium text-white/70">{s.level}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

/* ───────────────────────── Tile 2 — AI Analysis (parchment) ───────────────────────── */
function AIAnalysisTile({ t }: { t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const a = t.aiAnalysis;
  return (
    <Tile theme="parchment" id="analysis">
      <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
        <TileHeading theme="parchment" eyebrow={a.eyebrow} title={a.title} tagline={a.tagline} cta={a.cta} ctaHref="#analysis" />
        <div className="reveal-item mx-auto mt-12 max-w-[680px]" style={{ transitionDelay: "0.12s" }}>
          <AIAnalysisMockup t={t} active={active} />
        </div>
      </div>
    </Tile>
  );
}

function AIAnalysisMockup({ t, active }: { t: Copy; active: boolean }) {
  const a = t.aiAnalysis;
  return (
    <div className="mockup-card product-shadow mx-auto w-full max-w-[680px] rounded-[28px] border border-black/10 bg-white p-6 sm:p-8">
      <div className="flex items-center gap-4 sm:gap-6">
        <div className="relative h-[96px] w-[96px] shrink-0 sm:h-[110px] sm:w-[110px]">
          <svg viewBox="0 0 120 120" className="-rotate-90">
            <circle cx="60" cy="60" r="50" fill="none" stroke="#e8e8ed" strokeWidth="10" />
            <circle
              cx="60"
              cy="60"
              r="50"
              fill="none"
              stroke="#0066cc"
              strokeWidth="10"
              strokeLinecap="round"
              strokeDasharray={2 * Math.PI * 50}
              strokeDashoffset={active ? 2 * Math.PI * 50 * (1 - liveState.confidence) : 2 * Math.PI * 50}
              style={{ transition: "stroke-dashoffset 1.4s var(--ease-out)" }}
            />
          </svg>
          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <span className="type-metric text-2xl font-semibold text-ink">{Math.round(liveState.confidence * 100)}%</span>
          </div>
        </div>
        <div>
          <p className="text-[13px] font-semibold uppercase tracking-wider text-blue">{a.eyebrow}</p>
          <p className="type-display mt-1 text-[28px] text-ink">{a.predictedState}</p>
          <p className="text-[15px] text-ink-2">
            {a.confidence} · {Math.round(liveState.confidence * 100)}%
          </p>
        </div>
      </div>

      <p className="mt-4 text-[12px] leading-snug text-ink-2">{a.ringNote}</p>

      <div className="mt-7 space-y-4">
        {a.assessments.map((item, i) => (
          <div key={item.label}>
            <div className="flex items-baseline justify-between">
              <span className="text-[15px] font-medium text-ink">{item.label}</span>
              <span className="text-[13px] text-ink-2">{item.level}</span>
            </div>
            <div className="mt-2 h-2 w-full overflow-hidden rounded-full bg-[#e8e8ed]">
              <div
                className="h-full rounded-full bg-blue"
                style={{ width: active ? `${item.value}%` : "0%", transition: "width 1s var(--ease-out)", transitionDelay: `${i * 0.12}s` }}
              />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ───────────────────────── Tile 3 — Trends (dark) ───────────────────────── */
function TrendsTile({ t }: { t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const tr = t.trends;
  return (
    <Tile theme="dark" id="trends">
      <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
        <TileHeading theme="dark" eyebrow={tr.eyebrow} title={tr.title} tagline={tr.tagline} cta={tr.cta} ctaHref="#trends" />
        <div className="reveal-item mx-auto mt-12 max-w-[760px]" style={{ transitionDelay: "0.12s" }}>
          <TrendsMockup t={t} active={active} />
        </div>
      </div>
    </Tile>
  );
}

function TrendsMockup({ t, active }: { t: Copy; active: boolean }) {
  const tr = t.trends;
  const bars = monthlyStress;
  const max = Math.max(...bars);
  const w = 600;
  const h = 200;
  const pad = 10;
  const bw = (w - pad * 2) / bars.length - 6;

  return (
    <div className="mockup-card product-shadow-dark mx-auto w-full max-w-[760px] rounded-[28px] border border-white/10 bg-black/40 p-6 sm:p-8">
      <div className="flex items-center justify-between">
        <p className="text-[15px] font-semibold text-white/80">{tr.monthlyLabel}</p>
        <span className="text-[13px] text-white/50">
          {bars.length} {tr.daysLabel}
        </span>
      </div>

      <svg viewBox={`0 0 ${w} ${h}`} className="mt-5 w-full" role="img" aria-label="Monthly stress bar chart">
        {bars.map((b, i) => {
          const bh = (b / max) * (h - 20);
          const x = pad + i * (bw + 6);
          const y = h - bh - 4;
          return (
            <rect
              key={i}
              className={`bar-grow ${active ? "is-on" : ""}`}
              x={x}
              y={y}
              width={bw}
              height={bh}
              rx={4}
              fill="#2997ff"
              opacity={0.55 + (b / max) * 0.45}
              style={{ transitionDelay: `${i * 45}ms` }}
            />
          );
        })}
      </svg>

      <p className="mt-3 text-[12px] leading-snug text-white/45">{tr.monthlyNote}</p>

      <div className="mt-6 border-t border-white/10 pt-5">
        <p className="text-[15px] font-semibold text-white/80">{tr.heatmapLabel}</p>
        <div className="mt-3 grid grid-cols-10 gap-1 sm:gap-1.5">
          {heatmapValues.map((val, i) => (
            <div
              key={i}
              className={`cell-pop aspect-square rounded-[3px] ${active ? "is-on" : ""}`}
              style={{ background: heatmapColor(val), transitionDelay: `${i * 12}ms` }}
            />
          ))}
        </div>

        <div className="mt-4 flex items-center gap-3">
          <span className="text-[12px] text-white/50">{tr.heatmapLow}</span>
          <div className="h-2 flex-1 rounded-full" style={{ background: heatGradientCss }} aria-hidden="true" />
          <span className="text-[12px] text-white/50">{tr.heatmapHigh}</span>
        </div>
        <p className="mt-3 text-[12px] leading-snug text-white/45">{tr.heatmapNote}</p>
      </div>
    </div>
  );
}

/* ───────────────────────── Tile 4 — Sleep (light) ───────────────────────── */
function SleepTile({ t }: { t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const s = t.sleep;
  return (
    <Tile theme="light" id="sleep">
      <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
        <TileHeading theme="light" eyebrow={s.eyebrow} title={s.title} tagline={s.tagline} cta={s.cta} ctaHref="#sleep" />
        <div className="reveal-item mx-auto mt-12 max-w-[680px]" style={{ transitionDelay: "0.12s" }}>
          <SleepMockup t={t} active={active} />
        </div>
      </div>
    </Tile>
  );
}

function SleepMockup({ t, active }: { t: Copy; active: boolean }) {
  const stages = t.sleep.stages;
  const total = stages.reduce((sum, x) => sum + x.minutes, 0);

  return (
    <div className="mockup-card product-shadow mx-auto w-full max-w-[680px] overflow-hidden rounded-[28px] border border-black/10 bg-white p-6 sm:p-8">
      <div className="flex items-center justify-between">
        <p className="text-[15px] font-semibold text-ink">{t.sleep.legendTitle}</p>
        <p className="text-[13px] text-ink-2">
          {Math.floor(total / 60)}h {total % 60}m
        </p>
      </div>

      <div
        className="mt-5 grid h-10 w-full max-w-full overflow-hidden rounded-full"
        style={{
          gridTemplateColumns: stages.map((s) => `${s.minutes}fr`).join(" "),
          transform: active ? "scaleX(1)" : "scaleX(0)",
          transformOrigin: "left",
          transition: "transform 0.9s var(--ease-out)"
        }}
      >
        {stages.map((s) => (
          <div key={s.key} className="h-full" style={{ background: sleepColors[s.key] }} title={s.label} />
        ))}
      </div>

      <p className="mt-3 text-[12px] leading-snug text-ink-2">{t.sleep.note}</p>

      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {stages.map((s) => (
          <div key={s.key} className="rounded-2xl bg-parchment p-4">
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full" style={{ background: sleepColors[s.key] }} />
              <span className="text-[13px] font-medium text-ink">{s.label}</span>
            </div>
            <p className="type-metric mt-2 text-xl font-semibold text-ink">
              {Math.floor(s.minutes / 60)}h {s.minutes % 60}m
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ───────────────────────── Tile 5 — Daily Check-in (dark) ───────────────────────── */
function CheckInTile({ t }: { t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const c = t.checkIn;
  return (
    <Tile theme="dark" id="checkin">
      <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
        <TileHeading theme="dark" eyebrow={c.eyebrow} title={c.title} tagline={c.tagline} cta={c.cta} ctaHref="#checkin" />
        <div className="reveal-item mx-auto mt-12 max-w-[560px]" style={{ transitionDelay: "0.12s" }}>
          <CheckInMockup t={t} active={active} />
        </div>
      </div>
    </Tile>
  );
}

function CheckInMockup({ t, active }: { t: Copy; active: boolean }) {
  const c = t.checkIn;
  return (
    <div className="mockup-card product-shadow-dark mx-auto w-full max-w-[560px] rounded-[28px] border border-white/10 bg-black/40 p-6 sm:p-8">
      <p className="text-[15px] font-semibold text-white/80">{c.title}</p>
      <div className="mt-5 space-y-3">
        {c.items.map((it, i) => (
          <div
            key={it.title}
            className="flex items-center gap-3 rounded-2xl bg-white/5 px-4 py-3"
            style={{
              opacity: active ? 1 : 0,
              transform: active ? "translateX(0)" : "translateX(-16px)",
              transition: "opacity .6s var(--ease-out), transform .6s var(--ease-out)",
              transitionDelay: `${i * 0.1}s`
            }}
          >
            <span className="grid h-7 w-7 shrink-0 place-items-center rounded-full bg-[#2997ff]">
              <svg viewBox="0 0 24 24" className="h-4 w-4" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
                <path d="M5 12l5 5L20 6" />
              </svg>
            </span>
            <div className="flex-1">
              <p className="text-[14px] font-medium text-white">{it.title}</p>
              <p className="text-[12px] text-white/55">{it.detail}</p>
            </div>
          </div>
        ))}
      </div>
      <div className="mt-4 rounded-2xl border border-dashed border-white/20 px-4 py-3 text-[13px] text-white/45">{c.addHint}</div>
    </div>
  );
}

/* ───────────────────────── Tile 6 — Privacy (parchment) ───────────────────────── */
function PrivacyTile({ t }: { t: Copy }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const p = t.privacy;

  return (
    <Tile theme="parchment" id="privacy">
      <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
        <div className="reveal-item mx-auto max-w-[680px] text-center">
          <span className="type-eyebrow text-blue">{p.eyebrow}</span>
          <h2 className="type-display mt-3 text-ink">{p.title}</h2>
          <p className="type-lead mt-4 text-ink-2">{p.subtitle}</p>
        </div>

        <div className="mx-auto mt-14 grid max-w-5xl items-center gap-10 lg:grid-cols-2">
          <div className="flex flex-col gap-4">
            {p.items.map((it, i) => (
              <div key={it.title} className="reveal-item flex items-start gap-4 rounded-2xl border border-black/10 bg-white p-5 shadow-product" style={{ transitionDelay: `${i * 0.1}s` }}>
                <ShieldIcon className="h-7 w-7 shrink-0 text-blue" />
                <div>
                  <h3 className="text-[17px] font-semibold text-ink">{it.title}</h3>
                  <p className="type-body mt-1 text-[14px] text-ink-2">{it.desc}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="reveal-item rounded-[28px] border border-black/10 bg-white p-8 text-center shadow-product" style={{ transitionDelay: "0.3s" }}>
            <div className="mx-auto grid h-20 w-20 place-items-center rounded-3xl bg-blue/10">
              <ShieldIcon className="h-10 w-10 text-blue" />
            </div>
            <h3 className="type-tagline mt-6 text-ink">{p.cardTitle}</h3>
            <p className="type-body mt-3 text-ink-2">{p.cardDesc}</p>
            <div className="mt-6 flex flex-wrap justify-center gap-2">
              {p.chips.map((chip) => (
                <span key={chip} className="rounded-full bg-blue/10 px-3.5 py-1.5 text-[12px] font-semibold text-blue">
                  {chip}
                </span>
              ))}
            </div>
          </div>
        </div>

        <div className="mt-10 text-center">
          <a href="#" className="apple-cta-link text-blue">
            {p.cta} ›
          </a>
        </div>
      </div>
    </Tile>
  );
}

function ShieldIcon({ className = "" }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d="M12 3l7 3v5c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6l7-3z" />
      <path d="M9 12l2 2 4-4" />
    </svg>
  );
}

/* ───────────────────────── Footer (parchment) ───────────────────────── */
function Footer({ t }: { t: Copy }) {
  const f = t.footer;
  return (
    <footer className="bg-parchment px-5 py-14 text-ink">
      <div className="mx-auto max-w-5xl">
        <div className="grid grid-cols-2 gap-x-8 gap-y-10 sm:grid-cols-4">
          {f.columns.map((col) => (
            <div key={col.title}>
              <h4 className="text-[12px] font-semibold uppercase tracking-wider text-ink">{col.title}</h4>
              <ul className="mt-3">
                {col.links.map((link) => (
                  <li key={link}>
                    <a className="footer-link" href="#">
                      {link}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-12 border-t border-black/10 pt-6">
          <div className="flex flex-col gap-2 text-[12px] text-ink-2 sm:flex-row sm:items-center sm:justify-between">
            <span>{f.copyright}</span>
            <span className="sm:text-right">{f.disclaimer}</span>
          </div>
        </div>
      </div>
    </footer>
  );
}

/* ───────────────────────── Logo ───────────────────────── */
function LogoMark({ className = "" }: { className?: string }) {
  return (
    <span className={`grid place-items-center rounded-[7px] bg-blue ${className}`} role="img" aria-label="StressWatch logo">
      <svg viewBox="0 0 48 48" className="h-[58%] w-[58%]" aria-hidden="true">
        <path
          d="M5 25h8l4-12 7 24 6-18 4 8h9"
          fill="none"
          stroke="white"
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeWidth="4"
        />
      </svg>
    </span>
  );
}

/* ───────────────────────── Cursor particles ─────────────────────────
   A fixed, non-interactive canvas that trails the pointer with soft
   Action-Blue particles plus a calm glow that eases toward the cursor.
   Disabled for touch / reduced-motion users. */
function CursorParticles() {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const finePointer = window.matchMedia("(pointer: fine)").matches;
    if (reduced || !finePointer) return;

    const canvas = canvasRef.current;
    const ctx = canvas?.getContext("2d");
    if (!canvas || !ctx) return;

    let dpr = Math.min(window.devicePixelRatio || 1, 2);
    let width = window.innerWidth;
    let height = window.innerHeight;

    const resize = () => {
      dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = window.innerWidth;
      height = window.innerHeight;
      canvas.width = width * dpr;
      canvas.height = height * dpr;
      canvas.style.width = width + "px";
      canvas.style.height = height + "px";
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    };
    resize();
    window.addEventListener("resize", resize);

    const pointer = { x: -200, y: -200, active: false, vx: 0, vy: 0 };
    const follow = { x: -200, y: -200 };
    type Particle = { x: number; y: number; vx: number; vy: number; life: number; max: number; r: number };
    let particles: Particle[] = [];
    let lastX = -200;
    let lastY = -200;

    const onMove = (e: MouseEvent) => {
      pointer.vx = e.clientX - lastX;
      pointer.vy = e.clientY - lastY;
      lastX = e.clientX;
      lastY = e.clientY;
      pointer.x = e.clientX;
      pointer.y = e.clientY;
      pointer.active = true;
    };
    const onLeave = () => {
      pointer.active = false;
    };
    window.addEventListener("mousemove", onMove, { passive: true });
    window.addEventListener("mouseleave", onLeave);
    document.addEventListener("mouseleave", onLeave);

    let raf = 0;
    let prev = performance.now();
    const loop = (now: number) => {
      const dt = Math.min((now - prev) / 1000, 0.05);
      prev = now;
      ctx.clearRect(0, 0, width, height);

      if (pointer.active) {
        // eased glow trailing slightly behind the cursor
        follow.x += (pointer.x - follow.x) * 0.2;
        follow.y += (pointer.y - follow.y) * 0.2;

        // spawn a comet trail of particles along the movement direction
        const speed = Math.hypot(pointer.vx, pointer.vy);
        const spawn = Math.min(4, 1 + Math.floor(speed / 5));
        for (let i = 0; i < spawn; i++) {
          particles.push({
            x: pointer.x - pointer.vx * 0.12,
            y: pointer.y - pointer.vy * 0.12,
            vx: (Math.random() - 0.5) * 0.7 - pointer.vx * 0.02,
            vy: (Math.random() - 0.5) * 0.7 - pointer.vy * 0.02,
            life: 0,
            max: 0.8 + Math.random() * 0.5,
            r: Math.random() * 2.2 + 1.6
          });
        }

        // soft glow halo
        const grd = ctx.createRadialGradient(follow.x, follow.y, 0, follow.x, follow.y, 90);
        grd.addColorStop(0, "rgba(41,151,255,0.16)");
        grd.addColorStop(1, "rgba(41,151,255,0)");
        ctx.fillStyle = grd;
        ctx.beginPath();
        ctx.arc(follow.x, follow.y, 90, 0, Math.PI * 2);
        ctx.fill();
      }

      // trailing particles
      for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.life += dt;
        if (p.life >= p.max) {
          particles.splice(i, 1);
          continue;
        }
        p.x += p.vx;
        p.y += p.vy;
        p.vx *= 0.97;
        p.vy *= 0.97;
        const a = 1 - p.life / p.max;
        ctx.beginPath();
        ctx.fillStyle = `rgba(41,151,255,${a * 0.85})`;
        ctx.arc(p.x, p.y, p.r * a, 0, Math.PI * 2);
        ctx.fill();
      }

      // crisp core dot locked exactly to the pointer so it clearly "follows"
      if (pointer.active) {
        ctx.beginPath();
        ctx.fillStyle = "rgba(41,151,255,0.95)";
        ctx.arc(pointer.x, pointer.y, 4.5, 0, Math.PI * 2);
        ctx.fill();
        ctx.beginPath();
        ctx.fillStyle = "rgba(255,255,255,0.95)";
        ctx.arc(pointer.x, pointer.y, 1.8, 0, Math.PI * 2);
        ctx.fill();
      }

      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);

    return () => {
      cancelAnimationFrame(raf);
      window.removeEventListener("resize", resize);
      window.removeEventListener("mousemove", onMove);
      window.removeEventListener("mouseleave", onLeave);
      document.removeEventListener("mouseleave", onLeave);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      aria-hidden="true"
      style={{ position: "fixed", top: 0, left: 0, width: "100vw", height: "100vh", pointerEvents: "none", zIndex: 45 }}
    />
  );
}

export default App;
