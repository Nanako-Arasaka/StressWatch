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
  nav: { dashboard: string; features: string; how: string; privacy: string; download: string; languageLabel: string; changelog: string };
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
  privacyPage: {
    eyebrow: string;
    title1: string;
    title2: string;
    subtitle: string;
    introEyebrow: string;
    introTitle: string;
    introBody: string;
    introChips: string[];
    pillars: { title: string; desc: string; tag: string }[];
    pillarsHeading: string;
    pillarsSub: string;
    hkBadge: string;
    hkHeading: string;
    hkSub: string;
    hkNote: string;
    hkReads: string[];
    hkWritesLabel: string;
    hkWritesValue: string;
    analyticsBadge: string;
    analyticsTitle: string;
    analyticsBody: string;
    analyticsRows: { label: string; value: string; tone: "ok" | "warn" | "info" }[];
    sourceBadge: string;
    sourceTitle: string;
    sourceBody: string;
    ctaTitle: string;
    ctaSub: string;
    ctaPrimary: string;
    ctaSecondary: string;
    backHome: string;
  };
  how: {
    badge: string;
    eyebrow: string;
    title: string;
    subtitle: string;
    primaryCta: string;
    secondaryCta: string;
    pipelineEyebrow: string;
    pipelineTitle: string;
    pipelineSubtitle: string;
    steps: { num: string; key: string; title: string; tag: string; body: string; chips: string[] }[];
    pipelineNote: string;
    signalsEyebrow: string;
    signalsTitle: string;
    signalsSubtitle: string;
    signals: { key: string; label: string; source: string; what: string; unit: string }[];
    privacyEyebrow: string;
    privacyTitle: string;
    privacySubtitle: string;
    privacyPoints: { title: string; desc: string }[];
    privacyNote: string;
    surfaceEyebrow: string;
    surfaceTitle: string;
    surfaceSubtitle: string;
    surfaces: { key: string; title: string; desc: string }[];
    ctaTitle: string;
    ctaSubtitle: string;
    ctaPrimary: string;
    ctaSecondary: string;
  };
  footer: { tagline: string; columns: { title: string; links: string[] }[]; copyright: string; disclaimer: string };
  changelog: {
    eyebrow: string;
    title1: string;
    title2: string;
    subtitle: string;
    repo: string;
    countLabel: string;
    sourceTitle: string;
    sourceBody: string;
    tagLegend: string;
    ctaTitle: string;
    ctaSub: string;
    ctaPrimary: string;
    backHome: string;
    groups: { label: string; summary: string; entries: { date: string; sha: string; title: string; tags: string[] }[] }[];
  };
};

// Shape of stresswatch-web/public/changelog.json (produced by
// scripts/snapshot-commits.mjs on a schedule). Loose shape — extras
// ignored — so older snapshots still parse.
type ChangelogSnapshot = {
  syncedAt?: string;
  repo?: string;
  commitsTotal?: number;
  releases?: { tag: string; name: string; date: string; body: string; sha: string; assetCount: number; url: string }[];
  commitsByMonth?: { label: string; summary: string; entries: { date: string; sha: string; title: string; tags: string[]; url?: string; author?: string }[] }[];
};

const copy: Record<Lang, Copy> = {
  en: {
    nav: { dashboard: "Dashboard", features: "Features", how: "How it works", privacy: "Privacy", download: "Download App", languageLabel: "Language", changelog: "Changelog" },
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
    privacyPage: {
      eyebrow: "Privacy",
      title1: "Your health data",
      title2: "belongs to you only.",
      subtitle: "StressWatch is local-first by design — no account, no cloud upload, no analytics SDK, no opt-in switch hidden in Settings. Every byte that leaves your device is one you sent on purpose.",
      introEyebrow: "Local-first",
      introTitle: "Read on the device. Decide on the device. Stay on the device.",
      introBody: "Install, grant HealthKit, use it. There is no server-side identity, no signup, no sync, and no opt-in upload. The app does not contain any analytics SDK and never makes a network request for telemetry.",
      introChips: ["No account", "No cloud upload", "No analytics SDK", "Works offline"],
      pillarsHeading: "Four pillars",
      pillarsSub: "Every feature is reviewed against these four commitments. If any of them is violated, it's a bug.",
      pillars: [
        { tag: "01", title: "No account, no login", desc: "There is no server-side identity. Installation + HealthKit permission is the entire onboarding. The Settings screen has no email or sign-in field because there is nothing to sign into." },
        { tag: "02", title: "HealthKit read-only", desc: "The app requests read-only HealthKit scopes. It never writes back to Apple Health and never asks for write authorisation. Closing the app revokes any pending reads immediately." },
        { tag: "03", title: "Local-only storage", desc: "Computed baselines, daily states, the 5-day check-in history, and widget snapshots live in the app's Documents directory as plain JSON. Delete the app and they are gone — there is no copy off-device." },
        { tag: "04", title: "No analytics, no telemetry", desc: "There is no Firebase, no Amplitude, no Mixpanel, no Sentry, and no crash reporter. ARCHITECTURE.md states it explicitly: no network request is allowed for analytics or sync, ever." }
      ],
      hkBadge: "HealthKit",
      hkHeading: "Exactly seven HealthKit signals are read",
      hkSub: "Read-only, on demand, capped to 600 samples per fetch to stay battery-friendly. Nothing else.",
      hkNote: "Reads are issued by HealthKitService.fetchSignals(forRange:) — the same call site the README documents.",
      hkReads: [
        "HKQuantityTypeIdentifier.heartRate",
        "HKQuantityTypeIdentifier.heartRateVariabilitySDNN",
        "HKQuantityTypeIdentifier.restingHeartRate",
        "HKCategoryTypeIdentifier.sleepAnalysis",
        "HKQuantityTypeIdentifier.stepCount",
        "HKQuantityTypeIdentifier.activeEnergyBurned",
        "HKQuantityTypeIdentifier.appleExerciseTime (iOS 18+ also reads appleStandTime)"
      ],
      hkWritesLabel: "HealthKit writes",
      hkWritesValue: "None — never requested, never performed.",
      analyticsBadge: "Networking",
      analyticsTitle: "What crosses the network — and what doesn't",
      analyticsBody: "We treat the network boundary as the privacy boundary. Here is the complete inventory.",
      analyticsRows: [
        { label: "Analytics / telemetry", value: "Not transmitted", tone: "ok" },
        { label: "Crash reporting", value: "Not transmitted", tone: "ok" },
        { label: "Account / login traffic", value: "Not transmitted", tone: "ok" },
        { label: "Health data sync", value: "Not transmitted", tone: "ok" },
        { label: "Optional opt-in upload", value: "Does not exist", tone: "ok" },
        { label: "Outgoing requests (total)", value: "Zero, by policy", tone: "info" }
      ],
      sourceBadge: "Documentation",
      sourceTitle: "Three places this promise is written down",
      sourceBody: "Privacy claims are easy to make and easy to break. So this page links the same three documents the README, the Settings screen, and the architecture diagram all reference. If you ever find a contradiction, the bug is the contradiction, not the page.",
      ctaTitle: "Read the code, not the marketing.",
      ctaSub: "The repo is open-source. HealthKitService, BaselineEngine, FeatureExtractor, and CoreMLWellnessAnalyzer are the four files that touch your data. Open them, audit them, build them yourself.",
      ctaPrimary: "View on GitHub",
      ctaSecondary: "How it works",
      backHome: "Back to home"
    },
    how: {
      badge: "How it works",
      eyebrow: "From signal to insight",
      title: "Every number on the dashboard starts with a single Apple Health reading",
      subtitle: "StressWatch reads seven HealthKit signals on-device, computes a baseline, runs a Core ML classifier (with a rule-based fallback), and surfaces a state, a confidence score, and four dimensions. Nothing leaves your iPhone.",
      primaryCta: "View dashboard",
      secondaryCta: "Read privacy",
      pipelineEyebrow: "Pipeline",
      pipelineTitle: "Five steps from raw signal to a state on the screen",
      pipelineSubtitle: "Each stage runs locally on the device. The Core ML model is optional — if it isn't compiled, the same pipeline degrades to a transparent rule-based analyzer with the same output shape.",
      steps: [
        {
          num: "01",
          key: "collect",
          title: "Collect signals",
          tag: "HealthKit",
          body: "Read heart rate, HRV (SDNN), resting heart rate, sleep analysis stages, steps, active energy, and exercise time. Apple Stand Time is read on iOS 18+. Each fetch is capped to 600 samples to stay battery-friendly.",
          chips: ["7 HK types", "iOS 18+ Stand", "Bounded reads"]
        },
        {
          num: "02",
          key: "baseline",
          title: "Build a baseline",
          tag: "BaselineEngine",
          body: "Once you have at least 3 valid days, the app builds your rolling baseline: average HR, HRV, resting HR, daily steps, and sleep hours. This is the denominator for every later comparison.",
          chips: ["≥ 3 days", "Rolling", "Personal"]
        },
        {
          num: "03",
          key: "features",
          title: "Extract features",
          tag: "FeatureExtractor",
          body: "Compute 7-day rolling means, end-vs-start trend, sleep consistency (SD), and activity level. A separate LiveStress estimator combines HRV deviation, resting HR delta, and last night's sleep ratio for real-time numbers.",
          chips: ["7-day window", "Live estimator", "Sleep SD"]
        },
        {
          num: "04",
          key: "model",
          title: "Classify state",
          tag: "Core ML · fallback",
          body: "The bundled Core ML classifier outputs one of 7 classes (attention stress, high stress, mild stress, normal, recovery good, sleep debt, low activity). When the model can't load — or to keep output explainable — a rule-based WellnessAnalyzer with the same 6-state vocabulary takes over.",
          chips: ["7-class output", "Probability vector", "Rule fallback"]
        },
        {
          num: "05",
          key: "surface",
          title: "Surface the state",
          tag: "Dashboard · Widget",
          body: "You see one of six WellnessStates with a confidence percentage and four dimensions (Stress / Sleep / Recovery / HRV). Daily check-ins and personalized factors are generated locally; a small home-screen widget snapshots the same numbers every 30 minutes.",
          chips: ["6 states", "Confidence %", "Widget snapshot"]
        }
      ],
      pipelineNote: "Five steps run locally. From the seventh day onwards you get personalized baselines; until then the analyzer shows a guided \"getting to know you\" state.",
      signalsEyebrow: "Signals",
      signalsTitle: "What the app actually reads from Apple Health",
      signalsSubtitle: "Seven HealthKit quantity / category identifiers are queried. Missing permissions degrade to a clearly-labeled demo dataset so the rest of the app still works.",
      signals: [
        { key: "hr", label: "Heart rate", source: "HKQuantityTypeIdentifier.heartRate", what: "BPM samples, capped to the latest 600 readings", unit: "bpm" },
        { key: "hrv", label: "HRV (SDNN)", source: "HKQuantityTypeIdentifier.heartRateVariabilitySDNN", what: "Standard deviation of NN intervals from your watch", unit: "ms" },
        { key: "rhr", label: "Resting heart rate", source: "HKQuantityTypeIdentifier.restingHeartRate", what: "Daily resting HR used for trend and recovery", unit: "bpm" },
        { key: "sleep", label: "Sleep analysis", source: "HKCategoryTypeIdentifier.sleepAnalysis", what: "Awake / REM / Core / Deep stages broken out by night", unit: "stage" },
        { key: "steps", label: "Step count", source: "HKQuantityTypeIdentifier.stepCount", what: "Daily totals vs. your baseline for activity context", unit: "steps" },
        { key: "energy", label: "Active energy", source: "HKQuantityTypeIdentifier.activeEnergyBurned", what: "Calories burned through movement, per day", unit: "kcal" },
        { key: "exercise", label: "Exercise time", source: "HKQuantityTypeIdentifier.appleExerciseTime", what: "Minutes of brisk or higher-intensity activity", unit: "min" }
      ],
      privacyEyebrow: "Local-first",
      privacyTitle: "Your data is read on-device, processed on-device, and stored on-device",
      privacySubtitle: "There is no backend, no account, no analytics endpoint, and no opt-in upload. The README, the in-app privacy note, and the architecture document all say the same thing — no network request leaves the app for analytics or sync.",
      privacyPoints: [
        { title: "No account, no login", desc: "The app has no server-side identity. Install, grant HealthKit access, and you're in." },
        { title: "Read-only HealthKit", desc: "Only read permissions are requested. The app never writes back to Apple Health." },
        { title: "Local storage only", desc: "Computed states, baselines, and widget snapshots live in the app's Documents folder as JSON." },
        { title: "No network for analytics", desc: "There is no telemetry, no crash reporting SDK, and no remote model download. Core ML ships inside the bundle." }
      ],
      privacyNote: "ARCHITECTURE.md states explicitly: \"Local-only\" and \"No network requests — including analytics\". The settings screen mirrors this in plain language.",
      surfaceEyebrow: "Surfaces",
      surfaceTitle: "Where you see the state",
      surfaceSubtitle: "The same six-state vocabulary is reused across every surface so the wording never drifts.",
      surfaces: [
        { key: "dashboard", title: "Dashboard", desc: "Stress and Recovery scores (0–100), HR / HRV / Sleep / Steps / Activity cards, a live-stress ring, and a 7-day line." },
        { key: "analysis", title: "Analysis", desc: "Predicted state with confidence, four dimension assessments, today's check-in, contributing factors, and three personalized pieces of advice." },
        { key: "trends", title: "Trends", desc: "Monthly stress bars, a distribution pie, a 7-day recovery heatmap, and a recovery trend that pairs HRV with resting HR." },
        { key: "sleep", title: "Sleep & Check-in", desc: "Stage breakdown with the same color palette the app uses, plus a daily five-option check-in for personalization." },
        { key: "widget", title: "Home Screen widget", desc: "Small and medium widgets mirror the same numbers; the main app pushes a new snapshot whenever the state changes." }
      ],
      ctaTitle: "Ready to see what your body is telling you?",
      ctaSubtitle: "The full source is on GitHub — read the code, build it yourself, or open the repo to see exactly how the pipeline works.",
      ctaPrimary: "View on GitHub",
      ctaSecondary: "Back to home"
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
    },
    changelog: {
      eyebrow: "Changelog",
      title1: "Every build of StressWatch,",
      title2: "straight from GitHub.",
      subtitle: "A chronological log of features, fixes, and polish pulled live from the master branch of the open-source repo. No marketing, no rewrite.",
      repo: "github.com/Nanako-Arasaka/StressWatch",
      countLabel: "30 commits shown",
      sourceTitle: "Source",
      sourceBody: "Every entry above is a direct quote of the commit subject on the master branch of github.com/Nanako-Arasaka/StressWatch. The page does not fetch data live — it's a curated snapshot of the most recent 30 commits as of today, grouped by month with date + short SHA on the left and a tag (Feature / Fix / Polish / Docs / CI / Motion / Link / Routing) on the right.",
      tagLegend: "Tags · Feature · Fix · Polish · Docs · CI · Motion · Link · Routing",
      ctaTitle: "Open the repo to see every diff.",
      ctaSub: "Every commit on this page is a real commit on master. Tap below to jump straight to the source.",
      ctaPrimary: "View the master branch on GitHub",
      backHome: "Back to home",
      groups: [
        {
          label: "August 2026",
          summary: "3 commits · subpages, downloads, responsive polish",
          entries: [
            { date: "Aug 5", sha: "6400220", title: "Add How-it-works subpage and wire navigation across pages", tags: ["Feature", "Routing"] },
            { date: "Aug 5", sha: "0487104", title: "Point Download CTAs to GitHub repo (open in new tab)", tags: ["Link"] },
            { date: "Aug 5", sha: "3cc41a3", title: "Boost responsive design and micro-interactions", tags: ["Feature", "Polish"] }
          ]
        },
        {
          label: "July 2026",
          summary: "5 commits · Apple landing redesign + motion overhaul",
          entries: [
            { date: "Jul 17", sha: "068d20a", title: "Improve recovery heatmap: multi-hue scale + legend", tags: ["Polish"] },
            { date: "Jul 17", sha: "625ce57", title: "Fix scroll-driven reveal + strengthen cursor particles", tags: ["Fix", "Motion"] },
            { date: "Jul 17", sha: "4c7ba60", title: "Add directional reveal, cursor particles, and chart annotations", tags: ["Feature"] },
            { date: "Jul 17", sha: "28d9594", title: "Enhance landing-page motion (Apple-style reveal & data animations)", tags: ["Polish"] },
            { date: "Jul 17", sha: "83c0d88", title: "Redesign landing page in Apple design language (overwrite original site)", tags: ["Feature", "CI"] }
          ]
        },
        {
          label: "June 2026",
          summary: "4 commits · handoff + visual fixes",
          entries: [
            { date: "Jun 26", sha: "d0a75f7", title: "Add project handoff README", tags: ["Docs"] },
            { date: "Jun 16", sha: "7519bd1", title: "修复已知问题", tags: ["Fix"] },
            { date: "Jun 15", sha: "cc2a10f", title: "前端页面和app内容优化", tags: ["Polish"] },
            { date: "Jun 11", sha: "0f20bc3", title: "修复编译错误问题", tags: ["Fix"] }
          ]
        },
        {
          label: "May 2026",
          summary: "9 commits · widget, Live Stress, Core ML, training pipeline",
          entries: [
            { date: "Jun 9", sha: "51e91e2", title: "widget add in.", tags: ["Feature"] },
            { date: "May 30", sha: "f5a9ab1", title: "加入基于个人数据训练模型", tags: ["Feature", "AI"] },
            { date: "May 30", sha: "1e856f8", title: "Live Stress Estimate Upgrade", tags: ["Feature"] },
            { date: "May 24", sha: "4b8a01a", title: "加入基于用户数据学习的 demo 功能，架构大幅优化", tags: ["Feature", "AI"] },
            { date: "May 23", sha: "afddf60", title: "app 视觉结构与前端统一", tags: ["Polish"] },
            { date: "May 23", sha: "14ddd8d", title: "修改 bug：设置页面按钮点击无效", tags: ["Fix"] }
          ]
        }
      ]
    }
  },
  zh: {
    nav: { dashboard: "仪表盘", features: "功能", how: "工作原理", privacy: "隐私", download: "下载 App", languageLabel: "语言", changelog: "更新日志" },
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
    privacyPage: {
      eyebrow: "隐私",
      title1: "你的健康数据",
      title2: "只属于你一个人。",
      subtitle: "StressWatch 从第一天起就是本地优先——没有账号、没有云上传、没有分析 SDK、设置里也没有隐藏的上传开关。任何离开设备的数据，都必须是你主动发出的。",
      introEyebrow: "本地优先",
      introTitle: "在本机读取，在本机决策，留在本机。",
      introBody: "安装、授权 HealthKit、开始使用。没有服务端身份、没有注册流程、没有同步开关，也没有「可选上报」选项。App 不集成任何分析 SDK，也不会因为遥测而发起任何网络请求。",
      introChips: ["无账号", "无云上传", "无分析 SDK", "离线可用"],
      pillarsHeading: "四条底线",
      pillarsSub: "每一项功能都按这四条标准审核。任何一条被破坏，那就是 bug。",
      pillars: [
        { tag: "01", title: "没有账号，无需登录", desc: "服务端不存在身份系统。安装 + 授权 HealthKit 就是完整的入门流程。设置页里没有邮箱框、没有登录框，因为根本没有要登录的地方。" },
        { tag: "02", title: "HealthKit 只读", desc: "App 只请求读取权限，永远不会向 Apple Health 写入，也从未要求过写权限。退出 App 后任何挂起读取立即失效。" },
        { tag: "03", title: "仅本机存储", desc: "基线、每日状态、5 天打卡历史、小组件快照都以 JSON 形式保存在 App 的 Documents 目录。删除 App 即全部销毁，设备外没有任何副本。" },
        { tag: "04", title: "无分析、无埋点", desc: "没有 Firebase / Amplitude / Mixpanel / Sentry，也没有崩溃上报 SDK。ARCHITECTURE.md 明确写了：禁止任何用于分析或同步的网络请求。" }
      ],
      hkBadge: "HealthKit",
      hkHeading: "App 只读取这 7 条 HealthKit 信号",
      hkSub: "全部只读、按需拉取、每次最多 600 条以兼顾续航。除此之外什么都不读。",
      hkNote: "读取由 HealthKitService.fetchSignals(forRange:) 发起——与 README 文档中的调用点一致。",
      hkReads: [
        "HKQuantityTypeIdentifier.heartRate",
        "HKQuantityTypeIdentifier.heartRateVariabilitySDNN",
        "HKQuantityTypeIdentifier.restingHeartRate",
        "HKCategoryTypeIdentifier.sleepAnalysis",
        "HKQuantityTypeIdentifier.stepCount",
        "HKQuantityTypeIdentifier.activeEnergyBurned",
        "HKQuantityTypeIdentifier.appleExerciseTime（iOS 18+ 还读取 appleStandTime）"
      ],
      hkWritesLabel: "HealthKit 写入",
      hkWritesValue: "无——从未请求，也从未执行。",
      analyticsBadge: "网络",
      analyticsTitle: "什么会穿过网络——什么不会",
      analyticsBody: "我们把网络边界当作隐私边界。以下是完整的清单。",
      analyticsRows: [
        { label: "分析 / 遥测", value: "不发送", tone: "ok" },
        { label: "崩溃上报", value: "不发送", tone: "ok" },
        { label: "账号 / 登录流量", value: "不发送", tone: "ok" },
        { label: "健康数据同步", value: "不发送", tone: "ok" },
        { label: "可选上报开关", value: "不存在", tone: "ok" },
        { label: "外发请求（合计）", value: "策略为 0", tone: "info" }
      ],
      sourceBadge: "文档",
      sourceTitle: "这个承诺写在了三个地方",
      sourceBody: "隐私承诺说起来容易，做起来难。所以本页直接链接 README、设置页、架构文档中描述同一件事的三段文字。如果你发现说法不一致，那就是不一致本身是 bug。",
      ctaTitle: "看代码，不看营销。",
      ctaSub: "仓库是开源的。HealthKitService、BaselineEngine、FeatureExtractor、CoreMLWellnessAnalyzer 是接触你数据的四个文件。打开它们、审阅它们、自己构建。",
      ctaPrimary: "前往 GitHub",
      ctaSecondary: "工作原理",
      backHome: "返回首页"
    },
    how: {
      badge: "工作原理",
      eyebrow: "从信号到洞察",
      title: "仪表盘上的每一个数字，都来自一条 Apple Health 读数",
      subtitle: "StressWatch 在本机读取 7 类 HealthKit 信号，构建个人基线，调用 Core ML 分类器（必要时回退规则版），输出状态、可信度与四个维度的评分。一切都在你的 iPhone 上完成。",
      primaryCta: "查看仪表盘",
      secondaryCta: "阅读隐私说明",
      pipelineEyebrow: "流水线",
      pipelineTitle: "从原始信号到屏幕上的状态，五步完成",
      pipelineSubtitle: "每一步都在本机执行。Core ML 模型可选——若未编译，同一条流水线会自动降级到规则版 WellnessAnalyzer，输出形态保持一致。",
      steps: [
        {
          num: "01",
          key: "collect",
          title: "采集信号",
          tag: "HealthKit",
          body: "读取心率、HRV（SDNN）、静息心率、睡眠分析分期、步数、活动能量与锻炼时长。iOS 18+ 额外读取 Apple Stand Time。每次拉取上限 600 条以兼顾续航。",
          chips: ["7 类 HK", "iOS 18+ Stand", "限流拉取"]
        },
        {
          num: "02",
          key: "baseline",
          title: "建立基线",
          tag: "BaselineEngine",
          body: "积累 ≥3 天有效数据后，App 构建滚动基线：平均心率、HRV、静息心率、日均步数、睡眠时长。所有后续比较都以这个基线为分母。",
          chips: ["≥ 3 天", "滚动", "个性化"]
        },
        {
          num: "03",
          key: "features",
          title: "提取特征",
          tag: "FeatureExtractor",
          body: "计算 7 天滚动均值、末-首趋势、睡眠一致性（标准差）与活动等级。独立的 LiveStress 估算器将 HRV 偏离、静息 HR delta 与昨晚睡眠比组合，给出实时数字。",
          chips: ["7 天窗口", "实时估算", "睡眠 SD"]
        },
        {
          num: "04",
          key: "model",
          title: "分类状态",
          tag: "Core ML · 规则兜底",
          body: "内置 Core ML 分类器输出 7 个类别之一（注意力压力、高压力、轻度压力、正常、恢复良好、睡眠负债、活动不足）。当模型无法加载时——或为保证可解释性——使用同一套 6 状态词汇的规则版 WellnessAnalyzer 接管。",
          chips: ["7 类输出", "概率向量", "规则兜底"]
        },
        {
          num: "05",
          key: "surface",
          title: "呈现状态",
          tag: "仪表盘 · 小组件",
          body: "你看到 6 种 WellnessState 之一，附可信度百分比与四个维度（压力 / 睡眠 / 恢复 / HRV）。每日打卡与个性化因素在本机生成；主屏小组件每 30 分钟同步相同数字。",
          chips: ["6 状态", "可信度 %", "小组件快照"]
        }
      ],
      pipelineNote: "五步均在本地执行。从第 7 天起获得个性化基线；之前为引导式的「正在认识你」状态。",
      signalsEyebrow: "信号",
      signalsTitle: "App 真正从 Apple Health 读取了什么",
      signalsSubtitle: "实际查询 7 个 HealthKit 标识符。权限缺失时会降级到明确标注的演示数据，其余功能不受影响。",
      signals: [
        { key: "hr", label: "心率", source: "HKQuantityTypeIdentifier.heartRate", what: "BPM 采样，最多取最近 600 条", unit: "bpm" },
        { key: "hrv", label: "HRV (SDNN)", source: "HKQuantityTypeIdentifier.heartRateVariabilitySDNN", what: "NN 间期的标准差，来自 Apple Watch", unit: "ms" },
        { key: "rhr", label: "静息心率", source: "HKQuantityTypeIdentifier.restingHeartRate", what: "每日静息心率，用于趋势与恢复评估", unit: "bpm" },
        { key: "sleep", label: "睡眠分析", source: "HKCategoryTypeIdentifier.sleepAnalysis", what: "按晚拆解清醒 / REM / Core / 深睡阶段", unit: "stage" },
        { key: "steps", label: "步数", source: "HKQuantityTypeIdentifier.stepCount", what: "日总量，与基线对比得出活动情境", unit: "steps" },
        { key: "energy", label: "活动能量", source: "HKQuantityTypeIdentifier.activeEnergyBurned", what: "每天通过运动消耗的热量", unit: "kcal" },
        { key: "exercise", label: "锻炼时长", source: "HKQuantityTypeIdentifier.appleExerciseTime", what: "快走或更高强度活动的分钟数", unit: "min" }
      ],
      privacyEyebrow: "本地优先",
      privacyTitle: "数据在本机读取、在本机处理、在本机存储",
      privacySubtitle: "没有后端、没有账号、没有分析上报，也没有任何「可选上传」开关。README、应用内隐私说明、架构文档表达一致——没有网络请求用于分析或同步。",
      privacyPoints: [
        { title: "无需账号与登录", desc: "应用没有服务端身份。安装、授予 HealthKit 权限即可使用。" },
        { title: "HealthKit 只读权限", desc: "只请求读取权限，App 不会回写 Apple Health。" },
        { title: "仅本机存储", desc: "计算出的状态、基线与小组件快照保存在 App 文档目录的 JSON 中。" },
        { title: "无分析上报", desc: "没有埋点、没有崩溃 SDK、也不会远程下载模型。Core ML 随包发布。" }
      ],
      privacyNote: "ARCHITECTURE.md 明确声明：「本地 only」与「无网络请求（包括分析）」。设置页以平实语言再次承诺。",
      surfaceEyebrow: "呈现",
      surfaceTitle: "你在哪里看到状态",
      surfaceSubtitle: "同一套 6 状态词汇贯穿所有界面，措辞始终一致。",
      surfaces: [
        { key: "dashboard", title: "仪表盘", desc: "压力与恢复评分（0–100）、HR / HRV / 睡眠 / 步数 / 活动卡片、实时压力环与 7 日折线。" },
        { key: "analysis", title: "分析", desc: "预测状态 + 可信度、四个维度评估、每日打卡、影响因素与三条个性化建议。" },
        { key: "trends", title: "趋势", desc: "月度压力柱、分布饼图、7 天恢复热力图，以及将 HRV 与静息 HR 配对的恢复曲线。" },
        { key: "sleep", title: "睡眠 & 打卡", desc: "睡眠分期使用 App 同一调色板，加每日五选一打卡用于个性化。" },
        { key: "widget", title: "主屏小组件", desc: "小卡与大卡镜像相同数字；主 App 状态变化时即写入新快照。" }
      ],
      ctaTitle: "准备好听听身体的信号了吗？",
      ctaSubtitle: "完整源码在 GitHub——你可以阅读代码、自己构建，或直接打开仓库查看流水线实现。",
      ctaPrimary: "前往 GitHub",
      ctaSecondary: "返回首页"
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
    },
    changelog: {
      eyebrow: "更新日志",
      title1: "StressWatch 的每一次构建，",
      title2: "都来自 GitHub。",
      subtitle: "从开源仓库 master 分支直接抓取的功能、修复与打磨按时间顺序排列。无营销，无润色。",
      repo: "github.com/Nanako-Arasaka/StressWatch",
      countLabel: "展示最近 30 次提交",
      sourceTitle: "数据来源",
      sourceBody: "上方每一条都是 master 分支上提交信息原文。本页不做实时抓取——它是截至今日的最近 30 次提交的精选快照，按月份分组，左侧是日期 + 短 SHA，右侧是标签（Feature / Fix / Polish / Docs / CI / Motion / Link / Routing）。",
      tagLegend: "标签 · Feature · Fix · Polish · Docs · CI · Motion · Link · Routing",
      ctaTitle: "打开仓库查看每一次 diff。",
      ctaSub: "本页的每条提交都是 master 上的真实提交。点击下方按钮直接跳到源码。",
      ctaPrimary: "在 GitHub 上查看 master 分支",
      backHome: "返回首页",
      groups: [
        {
          label: "2026 年 8 月",
          summary: "3 次提交 · 二级页、下载跳转、响应式打磨",
          entries: [
            { date: "8 月 5 日", sha: "6400220", title: "新增「工作原理」二级页并打通跨页导航", tags: ["Feature", "Routing"] },
            { date: "8 月 5 日", sha: "0487104", title: "Download CTA 指向 GitHub 仓库（新标签页打开）", tags: ["Link"] },
            { date: "8 月 5 日", sha: "3cc41a3", title: "强化响应式设计与微交互", tags: ["Feature", "Polish"] }
          ]
        },
        {
          label: "2026 年 7 月",
          summary: "5 次提交 · Apple 风格落地页重做 + 动效升级",
          entries: [
            { date: "7 月 17 日", sha: "068d20a", title: "恢复热力图：多色色阶 + 图例", tags: ["Polish"] },
            { date: "7 月 17 日", sha: "625ce57", title: "修复滚动驱动 reveal 并强化鼠标粒子", tags: ["Fix", "Motion"] },
            { date: "7 月 17 日", sha: "4c7ba60", title: "新增方向感知 reveal、鼠标粒子与图表注释", tags: ["Feature"] },
            { date: "7 月 17 日", sha: "28d9594", title: "落地页动效升级（Apple 式 reveal 与数据动画）", tags: ["Polish"] },
            { date: "7 月 17 日", sha: "83c0d88", title: "按 Apple 设计语言重做落地页（覆盖原始站点）", tags: ["Feature", "CI"] }
          ]
        },
        {
          label: "2026 年 6 月",
          summary: "4 次提交 · 项目交接与视觉修复",
          entries: [
            { date: "6 月 26 日", sha: "d0a75f7", title: "新增项目交接 README", tags: ["Docs"] },
            { date: "6 月 16 日", sha: "7519bd1", title: "修复已知问题", tags: ["Fix"] },
            { date: "6 月 15 日", sha: "cc2a10f", title: "前端页面与 App 内容优化", tags: ["Polish"] },
            { date: "6 月 11 日", sha: "0f20bc3", title: "修复编译错误", tags: ["Fix"] }
          ]
        },
        {
          label: "2026 年 5 月",
          summary: "9 次提交 · 小组件、Live Stress、Core ML、训练流水线",
          entries: [
            { date: "6 月 9 日", sha: "51e91e2", title: "加入主屏小组件", tags: ["Feature"] },
            { date: "5 月 30 日", sha: "f5a9ab1", title: "加入基于个人数据的模型训练", tags: ["Feature", "AI"] },
            { date: "5 月 30 日", sha: "1e856f8", title: "实时压力估算升级", tags: ["Feature"] },
            { date: "5 月 24 日", sha: "4b8a01a", title: "加入基于用户数据学习的 demo，并大幅优化架构", tags: ["Feature", "AI"] },
            { date: "5 月 23 日", sha: "afddf60", title: "App 视觉结构与前端统一", tags: ["Polish"] },
            { date: "5 月 23 日", sha: "14ddd8d", title: "修复 bug：设置页按钮点击无效", tags: ["Fix"] }
          ]
        }
      ]
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

/* ───────────────────────── App shell — Home ───────────────────────── */
function HomePage() {
  const [language, setLanguage] = useState<Lang>("zh");
  const t = copy[language];

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
        <NavBar language={language} setLanguage={switchLanguage} t={t} variant="home" />
        <HeroSection language={language} t={t} />
        <LiveStressTile t={t} />
        <AIAnalysisTile t={t} />
        <TrendsTile t={t} />
        <SleepTile t={t} />
        <CheckInTile t={t} />
        <PrivacyTile t={t} />
        <Footer t={t} variant="subpage" />
      </main>
      <CursorParticles />
    </>
  );
}

/* ───────────────────────── Nav ───────────────────────── */
type NavVariant = "home" | "subpage" | "changelog";

function NavBar({
  language,
  setLanguage,
  t,
  variant = "home"
}: {
  language: Lang;
  setLanguage: (l: Lang) => void;
  t: Copy;
  variant?: NavVariant;
}) {
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
    { label: t.nav.privacy, id: "privacy" },
    { label: t.nav.changelog, id: "changelog" }
  ];

  // "home"  -> page is at the repo root (./)
  // "subpage" / "changelog" -> page is one directory deeper (../)
  const homeHref = variant === "home" ? "./" : "../";
  // Same-page → "./"; cross-page → "./how/" "./changelog/" or "./privacy/"
  const howHref = variant === "subpage" ? "./" : "./how/";
  const changelogHref = variant === "changelog" ? "./" : "./changelog/";
  const privacyHref = "./privacy/";

  return (
    <header className={`apple-nav fixed inset-x-0 top-0 z-50 h-11 ${scrolled ? "scrolled" : ""}`}>
      <nav className="mx-auto flex h-11 max-w-[1024px] items-center justify-between px-4 sm:px-5">
        <a
          className="focus-ring flex items-center gap-2 rounded-md transition hover:opacity-80"
          href={variant === "home" ? "#" : homeHref}
          onClick={(e) => {
            if (variant !== "home") return;
            e.preventDefault();
            window.scrollTo({ top: 0, behavior: "smooth" });
          }}
        >
          <LogoMark className="h-5 w-5" />
          <span className="text-[14px] font-semibold tracking-tight text-white">StressWatch</span>
        </a>

        <div className="hidden items-center gap-8 md:flex">
          {navItems.map((item) => {
            // Cross-page links (subpage routes) for How-it-works and Changelog.
            if (item.label === t.nav.how) {
              const isActive = variant === "subpage";
              return (
                <a
                  key={item.id}
                  href={howHref}
                  className={`focus-ring rounded-md text-[12px] transition hover:text-white ${
                    isActive ? "font-semibold text-white" : "font-normal text-white/80"
                  }`}
                >
                  {item.label}
                </a>
              );
            }
            if (item.label === t.nav.changelog) {
              const isActive = variant === "changelog";
              return (
                <a
                  key={item.id}
                  href={changelogHref}
                  className={`focus-ring rounded-md text-[12px] transition hover:text-white ${
                    isActive ? "font-semibold text-white" : "font-normal text-white/80"
                  }`}
                >
                  {item.label}
                </a>
              );
            }
            if (item.label === t.nav.privacy) {
              return (
                <a
                  key={item.id}
                  href={privacyHref}
                  className="focus-ring rounded-md text-[12px] font-normal text-white/80 transition hover:text-white"
                >
                  {item.label}
                </a>
              );
            }
            // On the subpage / changelog variants, the rest of the
            // anchors point at the home page — render them as
            // cross-page links instead of trying to scrollIntoView.
            if (variant !== "home") {
              return (
                <a
                  key={item.id}
                  href={`${homeHref}#${item.id}`}
                  className="focus-ring rounded-md text-[12px] font-normal text-white/80 transition hover:text-white"
                >
                  {item.label}
                </a>
              );
            }
            return (
              <button
                key={item.id}
                className="focus-ring rounded-md text-[12px] font-normal text-white/80 transition hover:text-white"
                onClick={() => scrollTo(item.id)}
                type="button"
              >
                {item.label}
              </button>
            );
          })}
        </div>

        <div className="flex items-center gap-2 sm:gap-3">
          <LangToggle language={language} setLanguage={setLanguage} />
          <a
            className="focus-ring hidden rounded-full bg-[#2997ff] px-3.5 py-1 text-[12px] font-semibold text-white transition hover:brightness-110 active:scale-95 motion-safe:hover:-translate-y-px sm:inline-flex sm:items-center"
            href="https://github.com/Nanako-Arasaka/StressWatch"
            target="_blank"
            rel="noopener noreferrer"
          >
            {t.nav.download}
          </a>
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
            {navItems.map((item) => {
              const isHow = item.label === t.nav.how;
              const isCl = item.label === t.nav.changelog;
              if (isHow) {
                return (
                  <li key={item.id}>
                    <a
                      href={howHref}
                      onClick={() => setMobileOpen(false)}
                      className={`focus-ring flex w-full items-center justify-between border-b border-white/10 py-4 text-left text-[15px] transition hover:text-white ${
                        variant === "subpage" ? "font-semibold text-white" : "font-medium text-white/90"
                      }`}
                    >
                      {item.label}
                      <span className="text-white/40" aria-hidden="true">›</span>
                    </a>
                  </li>
                );
              }
              if (isCl) {
                return (
                  <li key={item.id}>
                    <a
                      href={changelogHref}
                      onClick={() => setMobileOpen(false)}
                      className={`focus-ring flex w-full items-center justify-between border-b border-white/10 py-4 text-left text-[15px] transition hover:text-white ${
                        variant === "changelog" ? "font-semibold text-white" : "font-medium text-white/90"
                      }`}
                    >
                      {item.label}
                      <span className="text-white/40" aria-hidden="true">›</span>
                    </a>
                  </li>
                );
              }
              if (item.label === t.nav.privacy) {
                return (
                  <li key={item.id}>
                    <a
                      href={privacyHref}
                      onClick={() => setMobileOpen(false)}
                      className="focus-ring flex w-full items-center justify-between border-b border-white/10 py-4 text-left text-[15px] font-medium text-white/90 transition hover:text-white"
                    >
                      {item.label}
                      <span className="text-white/40" aria-hidden="true">›</span>
                    </a>
                  </li>
                );
              }
              if (variant !== "home") {
                return (
                  <li key={item.id}>
                    <a
                      href={`${homeHref}#${item.id}`}
                      onClick={() => setMobileOpen(false)}
                      className="focus-ring flex w-full items-center justify-between border-b border-white/10 py-4 text-left text-[15px] font-medium text-white/90 transition hover:text-white"
                    >
                      {item.label}
                      <span className="text-white/40" aria-hidden="true">›</span>
                    </a>
                  </li>
                );
              }
              return (
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
              );
            })}
            <li className="pt-4">
              <a
                href="https://github.com/Nanako-Arasaka/StressWatch"
                target="_blank"
                rel="noopener noreferrer"
                onClick={() => setMobileOpen(false)}
                className="focus-ring inline-block w-full rounded-full bg-[#2997ff] py-2.5 text-center text-[14px] font-semibold text-white active:scale-95"
              >
                {t.nav.download}
              </a>
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
function Footer({ t, variant = "home" }: { t: Copy; variant?: "home" | "subpage" | "changelog" }) {
  const f = t.footer;
  // Map specific footer link labels to real targets. Anything not listed
  // here still falls back to a harmless "#" so the layout stays consistent.
  // On subpages we are one directory deeper, so paths go up a level first.
  const prefix = variant === "home" ? "./" : "../";
  const linkHref = (label: string): string => {
    if (label === "Changelog") return `${prefix}changelog/`;
    if (
      label === "Privacy" ||
      label === "Privacy whitepaper" ||
      label === "Local-first" ||
      label === "HealthKit" ||
      label === "Data security"
    ) {
      return `${prefix}privacy/`;
    }
    return "#";
  };
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
                    <a className="footer-link" href={linkHref(link)}>
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

/* ───────────────────────── Changelog — subpage ───────────────────────── */
// One entry: date / short SHA / title / pill tags. Visually mirrors the
// Ardot design (left meta column, right title + tag row).
function ChangelogEntry({ entry }: { entry: { date: string; sha: string; title: string; tags: string[] } }) {
  return (
    <article className="flex flex-col gap-3 rounded-[18px] border border-black/10 bg-white px-6 py-4 sm:flex-row sm:items-center sm:gap-6 sm:px-7 sm:py-5">
      <div className="flex w-full shrink-0 items-center justify-between gap-3 text-[12px] text-ink-2 sm:w-[150px] sm:flex-col sm:items-start sm:justify-center sm:text-[13px]">
        <span className="font-medium text-ink-2">{entry.date}</span>
        <span className="font-mono text-ink">{entry.sha}</span>
      </div>
      <div className="flex flex-1 flex-col gap-2">
        <p className="text-[15px] font-semibold tracking-tight text-ink sm:text-[17px]">{entry.title}</p>
        <div className="flex flex-wrap items-center gap-2">
          {entry.tags.map((tag) => (
            <ChangelogTag key={tag} label={tag} />
          ))}
        </div>
      </div>
    </article>
  );
}

// Map tag label to a small colored pill. Keeps the same palette as the
// Ardot design — Feature blue, Fix red, Polish amber, Docs/CI green,
// Motion amber, Link green, Routing green, AI green.
const TAG_STYLE: Record<string, { bg: string; text: string }> = {
  Feature: { bg: "#E6F0FF", text: "#0066CC" },
  Fix: { bg: "#FFEEEE", text: "#A32D2D" },
  Polish: { bg: "#FFF1E0", text: "#A35A0B" },
  Docs: { bg: "#EAF7E8", text: "#187A2F" },
  CI: { bg: "#EAF7E8", text: "#187A2F" },
  Motion: { bg: "#FFF1E0", text: "#A35A0B" },
  Link: { bg: "#EAF7E8", text: "#187A2F" },
  Routing: { bg: "#EAF7E8", text: "#187A2F" },
  AI: { bg: "#EAF7E8", text: "#187A2F" }
};

function ChangelogTag({ label }: { label: string }) {
  const s = TAG_STYLE[label] ?? { bg: "#F1F1F4", text: "#1D1D1F" };
  return (
    <span
      className="inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
      style={{ backgroundColor: s.bg, color: s.text }}
    >
      {label}
    </span>
  );
}

function ChangelogPage() {
  const [language, setLanguage] = useState<Lang>("zh");
  const [langTick, setLangTick] = useState(0);
  const t = copy[language];
  const switchLanguage = (l: Lang) => {
    if (l === language) return;
    setLangTick((n) => n + 1);
    setLanguage(l);
  };

  // Snapshot from GitHub (refreshed by Actions every 6h, committed
  // back to master, served at /changelog.json). If the fetch fails
  // (offline preview, blocked, missing file), we fall back to the
  // curated bilingual static copy so the page is never blank.
  const fallbackGroups = t.changelog.groups;
  const fallbackRepo = t.changelog.repo;
  const fallbackCountLabel = t.changelog.countLabel;
  const [snapshot, setSnapshot] = useState<{
    syncedAt: string | null;
    repo: string;
    countLabel: string;
    groups: typeof t.changelog.groups;
    releaseCount: number;
    loading: boolean;
    error: string | null;
  }>({
    syncedAt: null,
    repo: fallbackRepo,
    countLabel: fallbackCountLabel,
    groups: fallbackGroups,
    releaseCount: 0,
    loading: true,
    error: null,
  });

  useEffect(() => {
    let cancelled = false;
    const load = () =>
      fetch("./changelog.json", { cache: "no-store" })
        .then((r) => {
          if (!r.ok) throw new Error(`HTTP ${r.status}`);
          return r.json();
        })
        .then((data: ChangelogSnapshot) => {
          if (cancelled) return;
          setSnapshot({
            syncedAt: data.syncedAt ?? null,
            repo: data.repo ?? fallbackRepo,
            countLabel:
              typeof data.commitsTotal === "number"
                ? `${data.commitsTotal} ${language === "zh" ? "次提交" : "commits"}`
                : fallbackCountLabel,
            groups: (data.commitsByMonth ?? []).map((g) => ({
              label: g.label,
              summary: g.summary,
              entries: g.entries.map((e) => ({
                date: e.date,
                sha: e.sha,
                title: e.title,
                tags: e.tags,
              })),
            })),
            releaseCount: Array.isArray(data.releases) ? data.releases.length : 0,
            loading: false,
            error: null,
          });
        })
        .catch((e: Error) => {
          if (cancelled) return;
          setSnapshot((s) => ({ ...s, loading: false, error: e.message }));
        });
    load();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const c = t.changelog;
  const syncTime = snapshot.syncedAt
    ? new Date(snapshot.syncedAt).toLocaleString(
        language === "zh" ? "zh-CN" : "en-US",
        {
          year: "numeric",
          month: "short",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
          hour12: false,
        },
      )
    : null;

  return (
    <>
      <main
        key={langTick}
        className="lang-fade font-apple min-h-screen overflow-x-hidden bg-white text-ink antialiased"
        lang={language === "zh" ? "zh-CN" : "en"}
      >
        <NavBar language={language} setLanguage={switchLanguage} t={t} variant="changelog" />

        {/* Hero */}
        <section className="bg-white px-5 pb-20 pt-28 sm:pb-24 sm:pt-36">
          <div className="mx-auto max-w-[820px] text-center">
            <span className="type-eyebrow text-blue">{c.eyebrow}</span>
            <h1 className="type-hero mt-3 text-ink">
              {c.title1}
              <br />
              {c.title2}
            </h1>
            <p className="type-lead mx-auto mt-5 max-w-[680px] text-ink-2">{c.subtitle}</p>
            <div className="mt-7 flex flex-col items-center justify-center gap-3 text-[13px] sm:flex-row sm:gap-5">
              <a
                className="text-blue"
                href={`https://${snapshot.repo}`}
                target="_blank"
                rel="noopener noreferrer"
              >
                {snapshot.repo}
              </a>
              <span className="text-ink-3">·</span>
              <span className="text-ink-2">{snapshot.countLabel}</span>
              {snapshot.loading ? (
                <span className="inline-flex items-center gap-1.5 text-[12px] text-ink-2">
                  <span className="inline-block h-1.5 w-1.5 animate-pulse rounded-full bg-blue" />
                  {language === "zh" ? "从 GitHub 同步中…" : "Syncing from GitHub…"}
                </span>
              ) : syncTime ? (
                <span className="text-[12px] text-ink-2">
                  {language === "zh" ? "同步于 " : "Synced "}
                  {syncTime}
                </span>
              ) : null}
              {snapshot.error ? (
                <span className="text-[12px] text-[#A32D2D]">
                  {language === "zh" ? "已显示静态快照" : "Showing static snapshot"}
                </span>
              ) : null}
            </div>
          </div>
        </section>

        {/* Timeline */}
        <section className="bg-parchment px-5 pb-24 pt-4 sm:pt-8">
          <div className="mx-auto flex max-w-[1040px] gap-8 sm:gap-12">
            <div className="hidden w-1 shrink-0 self-stretch bg-[#D2D2D7] sm:block" aria-hidden="true" />
            <div className="flex flex-1 flex-col gap-10">
              {snapshot.groups.map((g) => (
                <div key={g.label} className="flex flex-col gap-4">
                  <div className="flex flex-col gap-1">
                    <span className="type-eyebrow text-blue">{g.label}</span>
                    <p className="text-[14px] text-ink-2">{g.summary}</p>
                  </div>
                  <div className="flex flex-col gap-3">
                    {g.entries.map((e) => (
                      <ChangelogEntry key={e.sha} entry={e} />
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Source note */}
        <section className="bg-white px-5 py-16">
          <div className="mx-auto flex max-w-[820px] flex-col items-center gap-3 text-center">
            <span className="type-eyebrow text-blue">{c.sourceTitle}</span>
            <p className="max-w-[820px] text-[14px] leading-relaxed text-ink-2">{c.sourceBody}</p>
            <p className="text-[12px] font-medium text-ink">{c.tagLegend}</p>
          </div>
        </section>

        {/* CTA */}
        <section className="bg-parchment px-5 py-20">
          <div className="mx-auto flex max-w-[820px] flex-col items-center gap-6 text-center">
            <h2 className="text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
              {c.ctaTitle}
            </h2>
            <p className="max-w-[680px] text-[18px] text-ink-2">{c.ctaSub}</p>
            <a
              href={`https://${c.repo}`}
              target="_blank"
              rel="noopener noreferrer"
              className="apple-cta-primary"
            >
              {c.ctaPrimary} ›
            </a>
            <a href="../" className="apple-cta-link text-blue">
              {c.backHome} ›
            </a>
          </div>
        </section>

        <Footer t={t} variant="changelog" />
        <CursorParticles />
      </main>
    </>
  );
}

/* ───────────────────────── Privacy — subpage ───────────────────────── */

function PrivacyPage() {
  const [language, setLanguage] = useState<Lang>("zh");
  const [langTick, setLangTick] = useState(0);
  const t = copy[language];
  const switchLanguage = (l: Lang) => {
    if (l === language) return;
    setLangTick((n) => n + 1);
    setLanguage(l);
  };
  const p = t.privacyPage;

  return (
    <>
      <main
        key={langTick}
        className="lang-fade font-apple min-h-screen overflow-x-hidden bg-white text-ink antialiased"
        lang={language === "zh" ? "zh-CN" : "en"}
      >
        <NavBar language={language} setLanguage={switchLanguage} t={t} variant="subpage" />

        {/* Hero — light parchment */}
        <section className="bg-parchment px-5 pb-20 pt-28 sm:pb-24 sm:pt-36">
          <div className="mx-auto max-w-[820px] text-center">
            <span className="type-eyebrow text-blue">{p.eyebrow}</span>
            <h1 className="type-hero mt-3 text-ink">
              {p.title1}
              <br />
              {p.title2}
            </h1>
            <p className="type-lead mx-auto mt-5 max-w-[680px] text-ink-2">{p.subtitle}</p>
            <div className="mt-7 flex flex-wrap items-center justify-center gap-2">
              {p.introChips.map((chip) => (
                <span
                  key={chip}
                  className="inline-flex items-center rounded-full bg-white px-3 py-1 text-[12px] font-semibold text-ink-2 shadow-product"
                >
                  {chip}
                </span>
              ))}
            </div>
          </div>
        </section>

        {/* Intro — light, single product card */}
        <section className="bg-white px-5 py-16">
          <div className="mx-auto max-w-[820px] text-center">
            <span className="type-eyebrow text-blue">{p.introEyebrow}</span>
            <h2 className="mt-3 text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
              {p.introTitle}
            </h2>
            <p className="mx-auto mt-5 max-w-[680px] text-[18px] leading-relaxed text-ink-2">
              {p.introBody}
            </p>
          </div>
        </section>

        {/* Four pillars — parchment, two-column cards */}
        <section className="bg-parchment px-5 py-20">
          <div className="mx-auto flex max-w-[1040px] flex-col items-center gap-12">
            <div className="text-center">
              <span className="type-eyebrow text-blue">{p.pillarsHeading}</span>
              <h2 className="mt-3 text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
                {p.pillarsSub}
              </h2>
            </div>
            <div className="grid w-full grid-cols-1 gap-5 sm:grid-cols-2">
              {p.pillars.map((it) => (
                <article
                  key={it.tag}
                  className="flex flex-col gap-4 rounded-[24px] border border-black/10 bg-white p-7 shadow-product"
                >
                  <span className="inline-flex w-fit items-center rounded-full bg-[#E6F0FF] px-3 py-1 text-[12px] font-semibold tracking-wider text-blue">
                    {it.tag}
                  </span>
                  <h3 className="text-[22px] font-semibold tracking-tight text-ink">{it.title}</h3>
                  <p className="text-[15px] leading-relaxed text-ink-2">{it.desc}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        {/* HealthKit reads — light, two-column: list + reads card */}
        <section className="bg-white px-5 py-20">
          <div className="mx-auto flex max-w-[1040px] flex-col gap-10 sm:flex-row sm:gap-12">
            <div className="flex flex-1 flex-col gap-4">
              <span className="type-eyebrow text-blue">{p.hkBadge}</span>
              <h2 className="text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
                {p.hkHeading}
              </h2>
              <p className="text-[18px] leading-relaxed text-ink-2">{p.hkSub}</p>
              <p className="text-[12px] leading-relaxed text-ink-3">{p.hkNote}</p>
            </div>
            <div className="flex flex-1 flex-col gap-4 rounded-[24px] border border-black/10 bg-parchment p-7 shadow-product">
              <h3 className="text-[13px] font-semibold uppercase tracking-wider text-ink-2">{language === "zh" ? "读取" : "Reads"}</h3>
              <ul className="flex flex-col gap-3">
                {p.hkReads.map((line) => (
                  <li key={line} className="flex items-start gap-3 text-[14px] leading-relaxed text-ink">
                    <span aria-hidden="true" className="mt-1.5 inline-block h-1.5 w-1.5 shrink-0 rounded-full bg-blue" />
                    <code className="font-mono text-[13px]">{line}</code>
                  </li>
                ))}
              </ul>
              <div className="mt-2 border-t border-black/10 pt-4">
                <p className="text-[12px] font-semibold uppercase tracking-wider text-ink-2">{p.hkWritesLabel}</p>
                <p className="mt-1 text-[15px] font-medium text-ink">{p.hkWritesValue}</p>
              </div>
            </div>
          </div>
        </section>

        {/* Networking inventory — dark tile, two-tone row */}
        <section className="bg-[#272729] px-5 py-20 text-white">
          <div className="mx-auto flex max-w-[1040px] flex-col gap-12">
            <div className="text-center">
              <span className="type-eyebrow text-blue-sky">{p.analyticsBadge}</span>
              <h2 className="mt-3 text-[34px] font-semibold leading-tight tracking-tight sm:text-[40px]">
                {p.analyticsTitle}
              </h2>
              <p className="mx-auto mt-4 max-w-[680px] text-[18px] leading-relaxed text-white/65">
                {p.analyticsBody}
              </p>
            </div>
            <div className="grid w-full grid-cols-1 gap-3 sm:grid-cols-2">
              {p.analyticsRows.map((row, i) => (
                <div
                  key={i}
                  className="flex items-center justify-between rounded-[14px] border border-white/10 bg-white/5 px-5 py-4"
                >
                  <span className="text-[14px] text-white/70">{row.label}</span>
                  <span
                    className={`inline-flex items-center gap-2 rounded-full px-3 py-1 text-[12px] font-semibold ${
                      row.tone === "ok"
                        ? "bg-[#30D158]/15 text-[#5BD574]"
                        : row.tone === "warn"
                          ? "bg-[#FFD60A]/15 text-[#FFD60A]"
                          : "bg-[#2997FF]/15 text-[#6FB6FF]"
                    }`}
                  >
                    <span
                      aria-hidden="true"
                      className={`inline-block h-1.5 w-1.5 rounded-full ${
                        row.tone === "ok" ? "bg-[#30D158]" : row.tone === "warn" ? "bg-[#FFD60A]" : "bg-[#2997FF]"
                      }`}
                    />
                    {row.value}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Documentation — parchment */}
        <section className="bg-parchment px-5 py-20">
          <div className="mx-auto flex max-w-[820px] flex-col items-center gap-4 text-center">
            <span className="type-eyebrow text-blue">{p.sourceBadge}</span>
            <h2 className="text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
              {p.sourceTitle}
            </h2>
            <p className="max-w-[680px] text-[16px] leading-relaxed text-ink-2">{p.sourceBody}</p>
            <div className="mt-4 grid w-full grid-cols-1 gap-3 sm:grid-cols-3">
              {[
                { tag: "README.md", desc: language === "zh" ? "隐私段" : "Privacy section" },
                { tag: "ARCHITECTURE.md", desc: language === "zh" ? "本地 only 条款" : "Local-only clause" },
                { tag: "SettingsView.swift", desc: language === "zh" ? "隐私文案" : "Privacy copy" }
              ].map((d) => (
                <div key={d.tag} className="flex flex-col gap-1 rounded-[16px] border border-black/10 bg-white p-5 shadow-product">
                  <code className="font-mono text-[14px] font-semibold text-ink">{d.tag}</code>
                  <p className="text-[12px] text-ink-2">{d.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* CTA — light */}
        <section className="bg-white px-5 py-20">
          <div className="mx-auto flex max-w-[820px] flex-col items-center gap-6 text-center">
            <h2 className="text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
              {p.ctaTitle}
            </h2>
            <p className="max-w-[680px] text-[18px] text-ink-2">{p.ctaSub}</p>
            <a
              href="https://github.com/Nanako-Arasaka/StressWatch"
              target="_blank"
              rel="noopener noreferrer"
              className="apple-cta-primary"
            >
              {p.ctaPrimary} ›
            </a>
            <a href="../how/" className="apple-cta-link text-blue">
              {p.ctaSecondary} ›
            </a>
            <a href="../" className="apple-cta-link text-blue">
              {p.backHome} ›
            </a>
          </div>
        </section>

        <Footer t={t} variant="subpage" />
        <CursorParticles />
      </main>
    </>
  );
}

export default function App({ variant }: { variant?: "home" | "changelog" | "privacy" } = {}) {
  if (variant === "changelog") return <ChangelogPage />;
  if (variant === "privacy") return <PrivacyPage />;
  return <HomePage />;
}

/* ───────────────────────── How it works — subpage ───────────────────────── */
function HowPage() {
  const [language, setLanguage] = useState<Lang>("zh");
  const [langTick, setLangTick] = useState(0);
  const t = copy[language];
  const switchLanguage = (l: Lang) => {
    if (l === language) return;
    setLangTick((n) => n + 1);
    setLanguage(l);
  };
  const h = t.how;

  return (
    <>
      <main
        key={langTick}
        className="lang-fade font-apple min-h-screen overflow-x-hidden bg-white text-ink antialiased"
        lang={language === "zh" ? "zh-CN" : "en"}
      >
        <NavBar language={language} setLanguage={switchLanguage} t={t} variant="subpage" />

        {/* Hero — same visual language as the home hero */}
        <section className="bg-white px-5 pb-20 pt-28 sm:pb-24 sm:pt-36">
          <div className="mx-auto max-w-[820px] text-center">
            <span className="type-eyebrow text-blue">{h.badge}</span>
            <h1 className="type-hero mt-3 text-ink">{h.title}</h1>
            <p className="type-lead mx-auto mt-5 max-w-[680px] text-ink-2">{h.subtitle}</p>
            <div className="mt-7 flex flex-col items-center justify-center gap-4 sm:flex-row sm:gap-6">
              <a
                href="../#hero"
                className="apple-cta-primary"
              >
                {h.primaryCta}
              </a>
              <a href="../#privacy" className="apple-cta-link text-blue">
                {h.secondaryCta} ›
              </a>
            </div>
          </div>
        </section>

        {/* Pipeline — five steps, alternating tile themes, full-bleed */}
        <Tile theme="parchment" id="pipeline">
          <HowPipelineSection h={h} />
        </Tile>

        {/* Signals — list of HK identifiers the app actually queries */}
        <Tile theme="light" id="signals">
          <HowSignalsSection h={h} />
        </Tile>

        {/* Privacy — restate the local-first promise with the actual quotes */}
        <Tile theme="dark" id="how-privacy">
          <HowPrivacySection h={h} />
        </Tile>

        {/* Surfaces — where the state shows up */}
        <Tile theme="parchment" id="surfaces">
          <HowSurfacesSection h={h} />
        </Tile>

        {/* CTA — drive users to the GitHub repo */}
        <HowCtaSection h={h} />

        <Footer t={t} variant="subpage" />
      </main>
      <CursorParticles />
    </>
  );
}

function HowPipelineSection({ h }: { h: Copy["how"] }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
      <div className="reveal-item mx-auto max-w-[720px] text-center">
        <span className="type-eyebrow text-blue">{h.pipelineEyebrow}</span>
        <h2 className="type-display mt-3 text-ink">{h.pipelineTitle}</h2>
        <p className="type-lead mt-4 text-ink-2">{h.pipelineSubtitle}</p>
      </div>

      <ol className="mx-auto mt-14 grid max-w-5xl gap-6 md:grid-cols-2 lg:grid-cols-3">
        {h.steps.map((step, i) => (
          <li
            key={step.key}
            className="reveal-item mockup-card product-shadow flex h-full flex-col rounded-2xl border border-black/10 bg-white p-6"
            style={{ transitionDelay: `${i * 0.08}s` }}
          >
            <div className="flex items-center justify-between">
              <span className="text-[28px] font-semibold leading-none tracking-tight text-blue">{step.num}</span>
              <span className="rounded-full bg-blue/10 px-2.5 py-1 text-[11px] font-semibold text-blue">{step.tag}</span>
            </div>
            <h3 className="type-tagline mt-5 text-ink">{step.title}</h3>
            <p className="type-body mt-3 text-[14px] text-ink-2">{step.body}</p>
            <div className="mt-5 flex flex-wrap gap-2">
              {step.chips.map((chip) => (
                <span key={chip} className="rounded-full bg-parchment px-3 py-1 text-[12px] font-semibold text-ink">
                  {chip}
                </span>
              ))}
            </div>
          </li>
        ))}
      </ol>

      <p className="reveal-item mx-auto mt-12 max-w-[680px] text-center text-[14px] text-ink-2">{h.pipelineNote}</p>
    </div>
  );
}

function HowSignalsSection({ h }: { h: Copy["how"] }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
      <div className="reveal-item mx-auto max-w-[720px] text-center">
        <span className="type-eyebrow text-blue">{h.signalsEyebrow}</span>
        <h2 className="type-display mt-3 text-ink">{h.signalsTitle}</h2>
        <p className="type-lead mt-4 text-ink-2">{h.signalsSubtitle}</p>
      </div>

      <div className="mx-auto mt-14 grid max-w-5xl gap-3">
        {h.signals.map((s, i) => (
          <div
            key={s.key}
            className="reveal-item mockup-card product-shadow flex flex-col gap-3 rounded-2xl border border-black/10 bg-white p-5 sm:flex-row sm:items-center sm:justify-between"
            style={{ transitionDelay: `${i * 0.06}s` }}
          >
            <div className="flex items-start gap-4">
              <div className="grid h-11 w-11 shrink-0 place-items-center rounded-xl bg-blue/10 text-[12px] font-semibold text-blue">
                {s.unit}
              </div>
              <div>
                <p className="text-[16px] font-semibold text-ink">{s.label}</p>
                <p className="mt-1 text-[13px] text-ink-2">{s.source}</p>
              </div>
            </div>
            <p className="max-w-[420px] text-[13px] text-ink-2 sm:text-right">{s.what}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function HowPrivacySection({ h }: { h: Copy["how"] }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  return (
    <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
      <div className="reveal-item mx-auto max-w-[720px] text-center">
        <span className="type-eyebrow text-blue-sky">{h.privacyEyebrow}</span>
        <h2 className="type-display mt-3 text-white">{h.privacyTitle}</h2>
        <p className="type-lead mt-4 text-white/70">{h.privacySubtitle}</p>
      </div>

      <div className="mx-auto mt-14 grid max-w-5xl gap-5 md:grid-cols-2">
        {h.privacyPoints.map((p, i) => (
          <div
            key={p.title}
            className="reveal-item mockup-card flex h-full flex-col rounded-2xl border border-white/10 bg-black/40 p-6"
            style={{ transitionDelay: `${i * 0.08}s` }}
          >
            <h3 className="text-[17px] font-semibold text-white">{p.title}</h3>
            <p className="type-body mt-2 text-[14px] text-white/70">{p.desc}</p>
          </div>
        ))}
      </div>

      <p className="reveal-item mx-auto mt-12 max-w-[720px] text-center text-[13px] text-white/60">{h.privacyNote}</p>
    </div>
  );
}

function HowSurfacesSection({ h }: { h: Copy["how"] }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  const icons: Record<string, ReactNode> = {
    dashboard: (
      <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="3" width="7" height="9" rx="2" />
        <rect x="14" y="3" width="7" height="5" rx="2" />
        <rect x="14" y="12" width="7" height="9" rx="2" />
        <rect x="3" y="16" width="7" height="5" rx="2" />
      </svg>
    ),
    analysis: (
      <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="12" r="8" />
        <path d="M12 7v5l3 2" />
      </svg>
    ),
    trends: (
      <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M3 17l5-6 4 4 8-9" />
        <path d="M14 6h6v6" />
      </svg>
    ),
    sleep: (
      <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M20 14a8 8 0 1 1-9-10 6 6 0 0 0 9 10z" />
      </svg>
    ),
    widget: (
      <svg viewBox="0 0 24 24" className="h-5 w-5" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="4" width="18" height="13" rx="3" />
        <path d="M8 21h8M12 17v4" />
      </svg>
    )
  };
  return (
    <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
      <div className="reveal-item mx-auto max-w-[720px] text-center">
        <span className="type-eyebrow text-blue">{h.surfaceEyebrow}</span>
        <h2 className="type-display mt-3 text-ink">{h.surfaceTitle}</h2>
        <p className="type-lead mt-4 text-ink-2">{h.surfaceSubtitle}</p>
      </div>

      <div className="mx-auto mt-14 grid max-w-5xl gap-5 md:grid-cols-2 lg:grid-cols-3">
        {h.surfaces.map((s, i) => (
          <div
            key={s.key}
            className="reveal-item mockup-card product-shadow flex h-full flex-col rounded-2xl border border-black/10 bg-white p-6"
            style={{ transitionDelay: `${i * 0.07}s` }}
          >
            <div className="grid h-10 w-10 place-items-center rounded-xl bg-blue/10 text-blue">{icons[s.key] ?? null}</div>
            <h3 className="type-tagline mt-5 text-ink">{s.title}</h3>
            <p className="type-body mt-2 text-[14px] text-ink-2">{s.desc}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function HowCtaSection({ h }: { h: Copy["how"] }) {
  const { active, ref } = useRevealOnView<HTMLDivElement>();
  return (
    <section ref={ref} className={`reveal-group bg-white px-5 py-24 ${active ? "is-active" : ""}`}>
      <div className="reveal-item mx-auto max-w-[720px] text-center">
        <h2 className="type-display text-ink">{h.ctaTitle}</h2>
        <p className="type-lead mx-auto mt-4 max-w-[600px] text-ink-2">{h.ctaSubtitle}</p>
        <div className="mt-8 flex flex-col items-center justify-center gap-4 sm:flex-row sm:gap-6">
          <a
            href="https://github.com/Nanako-Arasaka/StressWatch"
            target="_blank"
            rel="noopener noreferrer"
            className="apple-cta-primary"
          >
            {h.ctaPrimary}
          </a>
          <a href="../" className="apple-cta-link text-blue">
            {h.ctaSecondary} ›
          </a>
        </div>
      </div>
    </section>
  );
}

export { HowPage };
