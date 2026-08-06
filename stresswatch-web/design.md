# StressWatch Web — Design System

This document is the source of truth for the landing-page design language.
It is **extracted from the code, not invented** — every rule below maps to
a concrete class, color token, or file you can grep for. When you change
something visual, change it here **and** in code, in the same commit.

The goal is **Apple design language**: a single neutral canvas, one ink,
one accent, one shadow, one set of curves, and motion that lasts longer
than the industry default.

> 📖 **How to use this doc.** Read §1 once before you write a single
> pixel. Skim §2–§5 the first time, refer back when you need a value.
> §6 (motion) and §7 (components) are the rules you'll violate by
> accident — re-read them before any non-trivial change. §11 is the
> playbook for adding a new subpage.

---

## Table of contents

1. [Brand pillars](#1-brand-pillars-read-these-before-you-write-any-pixel)
2. [Color tokens](#2-color-tokens)
3. [Typography](#3-typography)
4. [Spacing & layout](#4-spacing--layout)
5. [Shadow language](#5-shadow-language)
6. [Motion system](#6-motion-system)
7. [Components](#7-components)
8. [Layout patterns](#8-layout-patterns)
9. [Accessibility](#9-accessibility)
10. [File map](#10-file-map-where-things-live)
11. [`App.tsx` house rules](#11-apptsx-house-rules)
12. [Adding a new color](#12-adding-a-new-color)
13. [Adding a new component class](#13-adding-a-new-component-class)
14. [PR checklist](#14-pr-checklist-visual-changes)
15. [What "good" looks like](#15-what-good-looks-like)

---

## 1. Brand pillars (read these before you write any pixel)

1. **One accent, never two.** `#0066cc` / `#0071e3` / `#2997ff` are the
   same blue at three roles (text, hover, focus). Don't introduce teal,
   purple, or chart-palette accents outside the heatmap scale.
2. **One shadow, never a stack.** `product-shadow` /
   `product-shadow-dark` is the only shadow in the system. Never
   compose two `box-shadow`s on the same element.
3. **One font.** `font-apple` / `font-sans` is a single stack. No
   display vs body split, no weight ramp beyond 400 / 500 / 600.
4. **One motion curve family.** `--ease-out` /
   `cubic-bezier(0.16, 1, 0.3, 1)`. No bounces, no overshoot, no
   `ease-in-out`.
5. **Long, never snappy.** Entrance 700ms, exit 480ms, scroll reveal
   900ms. We are not a 200ms dashboard. Animation that ends faster than
   400ms reads as cheap.
6. **Bilingual parity.** Every visible string lives in `Copy` with
   matching `en` and `zh` entries. If a language ships a key the other
   doesn't, the build is broken.

If you ever find yourself reaching for a second accent, a heavier
weight, a stack of two shadows, or a 200ms transition — **stop**. The
right answer is to use what's here.

---

## 2. Color tokens

All defined in `stresswatch-web/tailwind.config.ts` under
`theme.extend.colors`. Never use raw hex in JSX — reach for the token.

| Token         | Hex       | Role                                            | Where you'll see it                          |
| ------------- | --------- | ----------------------------------------------- | -------------------------------------------- |
| `ink`         | `#1d1d1f` | Primary text on light surfaces                  | `text-ink`, headings, primary copy           |
| `ink-2`       | `#6e6e73` | Secondary text on light surfaces                | `text-ink-2`, subtitles, supporting copy     |
| `ink-3`       | `#86868b` | Tertiary text, placeholders, captions           | `text-ink-3`, footnote lines                 |
| `blue`        | `#0066cc` | Action Blue — primary buttons, links, accents   | `text-blue`, `bg-blue`, primary CTAs          |
| `blue-focus`  | `#0071e3` | Hover state for blue buttons                    | Only inside `.apple-cta-primary:hover`       |
| `blue-sky`    | `#2997ff` | Focus ring, info badges, dark-tile highlights   | Focus outlines, eyebrow on dark tiles        |
| `parchment`   | `#f5f5f7` | Section background, alternating rhythm          | `bg-parchment`                               |
| `tile`        | `#272729` | Dark tile base (Trends, Networking)             | `bg-tile`                                    |
| `tile-alt`    | `#2a2a2c` | Dark tile variant                               | Sub-cards inside dark tiles                  |
| `tile-deep`   | `#252527` | Dark tile deeper variant                        | Deeper nesting                               |
| `green`       | `#34c759` | "Local-first" chip, recovery heatmap high end   | Pill chips, success states                   |
| `sleep-deep`  | `#0A84FF` | Sleep stage — Deep                              | Sleep stage chart only                       |
| `sleep-core`  | `#5AC8FA` | Sleep stage — Core                              | Sleep stage chart only                       |
| `sleep-rem`   | `#BF5AF2` | Sleep stage — REM                               | Sleep stage chart only                       |
| `sleep-awake` | `#FF9F0A` | Sleep stage — Awake                             | Sleep stage chart only                       |

### The heatmap scale (used only for the recovery heatmap)

A multi-hue ramp from low recovery (warm) to high recovery (cool). Keep
this scale locked to this single component — don't reuse the stops on
charts that have a different semantic.

```ts
// Defined inline in App.tsx
const HEAT_STOPS: { p: number; c: string }[] = [
  { p: 0.00, c: "#FF453A" }, // red    — low recovery
  { p: 0.28, c: "#FF9F0A" }, // orange
  { p: 0.52, c: "#FFD60A" }, // yellow
  { p: 0.76, c: "#30D158" }, // green
  { p: 1.00, c: "#2997FF" }  // blue   — high recovery (Action Blue)
];

// Usage:
background: heatmapColor(value),  // returns the interpolated hex
background: heatGradientCss,      // returns the linear-gradient CSS
```

### Tag / pill palette (used for change-tags and status chips)

Six semantic categories. Always pair them as written — the colors are
calibrated to read correctly together at the same text size.

```tsx
const TAG_STYLE: Record<string, { bg: string; text: string }> = {
  Feature:  { bg: "#E6F0FF", text: "#0066CC" },  // blue tint
  Fix:      { bg: "#FFEEEE", text: "#A32D2D" },  // red tint
  Polish:   { bg: "#FFF1E0", text: "#A35A0B" },  // amber tint
  Docs:     { bg: "#EAF7E8", text: "#187A2F" },  // green tint
  CI:       { bg: "#EAF7E8", text: "#187A2F" },
  Motion:   { bg: "#FFF1E0", text: "#A35A0B" },
  Link:     { bg: "#EAF7E8", text: "#187A2F" },
  Routing:  { bg: "#EAF7E8", text: "#187A2F" },
  AI:       { bg: "#EAF7E8", text: "#187A2F" }
};
```

In JSX:

```tsx
<span
  className="inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
  style={{ backgroundColor: TAG_STYLE[tag].bg, color: TAG_STYLE[tag].text }}
>
  {tag}
</span>
```

---

## 3. Typography

Single stack, defined once in `tailwind.config.ts` and re-exposed as
`font-apple` in `typography.css`:

```css
font-family: "Noto Sans SC", -apple-system, BlinkMacSystemFont,
             "SF Pro Display", "Segoe UI", sans-serif;
```

Weights: **400 / 500 / 600**. No 700, no 800, no 900. If a heading
feels weak, increase the size first, then the line-height, then the
tracking — not the weight.

### Type scale (the `.type-*` classes used in JSX)

| Class          | Size / line-height        | Use                                        |
| -------------- | ------------------------- | ------------------------------------------ |
| `type-eyebrow` | 13, weight 600, tracking 0.12em, uppercase | Small uppercase label above every section  |
| `type-hero`    | 56 / 64, weight 600       | Hero h1 on every subpage and home          |
| `type-lead`    | 21 / 30, weight 400       | Hero subtitle                              |
| `type-tagline` | 28 / 36, weight 600       | Product card title (mockup-card heading)   |
| `type-body`    | 17 / 26, weight 400       | Product card body                          |

### Per-context sizing rules

| Context                                | Element         | Class                       |
| -------------------------------------- | --------------- | --------------------------- |
| Section eyebrow (above h2)             | `<span>`        | `type-eyebrow text-blue` (or `text-blue-sky` on dark tiles) |
| Tile heading h2 (light)                | `<h2>`          | `text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]` |
| Tile heading h2 (dark)                 | `<h2>`          | same, but `text-white` instead of `text-ink` |
| Hero on subpage                        | `<h1>`          | `type-hero mt-3 text-ink`   |
| Hero on home                           | `<h1>`          | `text-[44px] sm:text-[56px] font-semibold leading-[1.08] tracking-[-0.02em]` |
| Card title (mockup-card)               | `<h3>`          | `type-tagline mt-6 text-ink` (or `text-white` on dark) |
| Card body                              | `<p>`           | `type-body mt-3 text-ink-2` |
| Caption / footnote                     | `<p>`           | `text-[12px] leading-snug text-white/45` (dark) / `text-ink-3` (light) |
| Numeric in cards (e.g. stress score)   | `<span>`        | add `tabular-nums`          |

### Rules

- Always lowercase the word `StressWatch` in the lockup.
- Numerals in cards and charts are **tabular**: `tabular-nums`.
- Hero titles use `<br />` between two short lines, never wrap three.
- Don't center-align long body copy — keep it left-aligned, max
  `max-w-[680px]`, and indent center only for hero.

### The body type recipe

```tsx
<p className="text-[16px] leading-relaxed text-ink-2 sm:text-[18px]">
  {body}
</p>
```

For 14px caption / footnote lines:

```tsx
<p className="text-[12px] leading-snug text-ink-3">
  {caption}
</p>
```

---

## 4. Spacing & layout

### Container widths (these are the only four you should ever use)

| Class                  | When                                       |
| ---------------------- | ------------------------------------------ |
| `max-w-[640px]`        | Narrow copy blocks (rare)                  |
| `max-w-[680px]`        | Section body, hero lead, single-column mockups |
| `max-w-[760px]`        | Product mockups (Trends, Sleep)            |
| `max-w-[820px]`        | Hero CTAs, dark-tile body, About profile    |
| `max-w-[1040px]`       | Two-column feature sections                |
| `max-w-apple` (= 980)  | (Legacy, prefer the explicit values above) |

**Never** invent a `max-w-[900px]` or anything not in this list.

### Section rhythm

```tsx
<section className="px-5 py-20 sm:py-28 {bg}">
```

Every full-bleed section uses this — it gives the page its long, calm
vertical breathing room.

### Tile alternation

For sections rendered inside `<Tile>`: light → parchment → dark →
light → parchment → dark → light. Never two lights in a row, never
two darks in a row.

### Card radius (the only three)

| Radius        | Use                                   |
| ------------- | ------------------------------------- |
| `rounded-[18px]` | Inline cards, list rows             |
| `rounded-[24px]` | Feature cards (Privacy pillars)     |
| `rounded-[28px]` | Mockup cards (Trends, Sleep)        |

Never `rounded-lg`, `rounded-2xl`, or any other value.

### Vertical rhythm inside a section

| Between                | Use       |
| ---------------------- | --------- |
| Heading → content      | `mt-12`   |
| Heading → subtitle     | `mt-3`    |
| Subtitle → body        | `mt-5`    |
| Body → CTA             | `mt-7`    |
| Card top → card title  | `mt-6`    |
| Card title → body      | `mt-3`    |
| Stack of two cards     | `gap-5`   |
| Stack of three cards   | `gap-6`   |

`mt-16` looks empty, `mt-8` looks crowded. Don't pick from outside
this list.

---

## 5. Shadow language

Two and only two shadows, both defined in `src/styles.css`:

```css
.product-shadow       /* rgba(0,0,0,0.22) 3px 5px 30px */
.product-shadow-dark  /* rgba(0,0,0,0.55) 3px 5px 30px */
```

Use on:

- `<Tile>` content cards and `mockup-card`s.
- Hover lift target only (`mockup-card:hover { translateY(-5px) }`).

**Do not** add `box-shadow` on buttons, inputs, or the nav. Buttons get
their affordance from color and transform, not shadow.

**Do not** compose: an element has either `product-shadow` or
`product-shadow-dark`, never both. An element has at most one
`box-shadow` declaration in its entire rule set.

---

## 6. Motion system

### The two CSS variables

```css
/* src/styles.css :root */
--ease-out:  cubic-bezier(0.22, 1, 0.36, 1);  /* scroll reveal, lang fade */
--ease-soft: cubic-bezier(0.32, 0.72, 0, 1);  /* mockup-card hover lift */
```

### The inline curve (Apple spring-decel)

For component-level motion that needs the "Apple" feel (card zooms,
preview popovers, modal entrances), use the curve literally — there's
no token, you type it:

```
cubic-bezier(0.16, 1, 0.3, 1)
```

This curve already gives the spring-decel feel by spending most of its
duration near the rest position. **Do not** use
`cubic-bezier(0.34, 1.56, 0.64, 1)` — the overshoot looks mechanical on
any scale > 1.5×.

### Durations

| Use case                          | Duration |
| --------------------------------- | -------- |
| Language cross-fade (`.lang-fade`)| 320ms    |
| Mockup-card hover lift            | 500ms    |
| Mockup-card hover return          | 500ms    |
| Scroll reveal (`.reveal-item`)    | 900ms    |
| Apple card-zoom entrance          | 700ms    |
| Apple card-zoom exit              | 480ms    |
| Heatmap preview badge             | 600ms    |
| Heatmap preview pill              | 600ms    |
| Nav bar tint change on scroll     | 400ms    |
| Primary button hover              | 200ms    |

Anything shorter than 320ms feels like a status update, not motion.
Don't write a `transition: 100ms` ever.

### Reveal mechanism

The reveal system has two pieces: a hook that toggles a class, and a
class pair that styles the children.

```tsx
// The hook — drop into any tile
const { active, ref } = useRevealOnView<HTMLDivElement>();

return (
  <Tile theme="dark" id="trends">
    <div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
      <TileHeading eyebrow={tr.eyebrow} title={tr.title} tagline={tr.tagline} cta={tr.cta} ctaHref="#trends" />
      <div className="reveal-item mx-auto mt-12 max-w-[760px]" style={{ transitionDelay: "0.12s" }}>
        <TrendsMockup t={t} active={active} />
      </div>
    </div>
  </Tile>
);
```

`useRevealOnView` activates when the section's top crosses 82% of
viewport height. Once active, the section stays shown — scrolling back
above the threshold reverses it (so it replays on re-entry). Stagger
timing is supplied per-element via inline `transitionDelay`.

### Spring-decel without overshoot

The Apple card-zoom pattern, used for the heatmap preview and any
"open a focused detail" affordance:

```tsx
const [closing, setClosing] = useState(false);

<div
  style={{
    transform: closing
      ? `scale(0.85)`
      : `scale(2.6) rotateY(${tilt.x * 12}deg) rotateX(${-tilt.y * 8}deg)`,
    opacity: closing ? 0 : 1,
    filter: closing ? "blur(10px)" : "blur(0px)",
    transition: closing
      ? "transform 480ms cubic-bezier(0.16, 1, 0.3, 1), opacity 360ms cubic-bezier(0.16, 1, 0.3, 1), filter 480ms cubic-bezier(0.16, 1, 0.3, 1)"
      : "transform 700ms cubic-bezier(0.16, 1, 0.3, 1), opacity 520ms cubic-bezier(0.16, 1, 0.3, 1), filter 560ms cubic-bezier(0.16, 1, 0.3, 1)"
  }}
>
```

Key rules:
- Always use `cubic-bezier(0.16, 1, 0.3, 1)`. No other curve.
- Always pair a longer entrance with a shorter exit (700/480, 600/360).
- Always layer blur with opacity. The eye reads blur as "depth".

### Two-phase exit (preview cards, modals, anything that unmounts)

Never unmount mid-animation. Use a `closing` flag and a timeout:

```tsx
const [closing, setClosing] = useState(false);

const dismiss = useCallback(() => {
  setClosing(true);
  const id = window.setTimeout(() => {
    setPicked(null);
    setClosing(false);
  }, 480); // matches your exit duration exactly
  return () => window.clearTimeout(id);
}, []);
```

Inside `style.transition`, branch on `closing ? exitProps : enterProps`
so the same node plays both halves of the gesture. Layer with sub-DOM
delays for cards-with-badges-with-pills:

```tsx
// card: 700ms / badge: 600ms delay 180ms / pill: 600ms delay 320ms
// The eye reads "card → badge → caption" as one continuous gesture.
```

### The rAF throttle (preview card tilt)

When a transform depends on mousemove, throttle to one update per frame
with `requestAnimationFrame` — otherwise `mousemove` can fire 200+ Hz
and jank the animation.

```tsx
let rafId: number | null = null;
const onMove = (e: MouseEvent) => {
  if (rafId !== null) return;
  rafId = requestAnimationFrame(() => {
    rafId = null;
    // …compute and setTilt…
  });
};
window.addEventListener("mousemove", onMove);
return () => {
  window.removeEventListener("mousemove", onMove);
  if (rafId !== null) cancelAnimationFrame(rafId);
};
```

### Reduced-motion

Already wired in `src/styles.css` via
`@media (prefers-reduced-motion: reduce)`. Any new animation must
behave correctly under it. Test by enabling the OS reduce-motion
preference and reloading.

---

## 7. Components

### 7.1 Primary button — `.apple-cta-primary`

Pill, Action Blue background, white text. Hover lifts and glows, active
scales down, focus-visible gets a sky-blue ring.

```tsx
<a
  href="https://github.com/Nanako-Arasaka/StressWatch"
  target="_blank"
  rel="noopener noreferrer"
  className="apple-cta-primary"
>
  View on GitHub ›
</a>
```

Or as a button:

```tsx
<button type="button" className="apple-cta-primary" onClick={onClick}>
  View on GitHub ›
</button>
```

**Behavior contract** (CSS-handled, no JS needed):

| State          | Change                                       |
| -------------- | -------------------------------------------- |
| Hover          | `bg #0071e3`, `translateY(-1px)`, soft blue glow |
| Active         | `scale(0.96)`                                |
| Focus-visible  | 2px `#2997ff` ring, 3px offset              |
| Disabled       | (not implemented — see §13)                  |

Always pairs with `.apple-cta-link` for a second action on the same
surface.

### 7.2 Text link — `.apple-cta-link`

For secondary / tertiary actions on the same landing surface. Hover
dims, focus-visible gets a sky-blue ring.

```tsx
<a href="../how/" className="apple-cta-link text-blue">
  How it works ›
</a>
```

### 7.3 Global nav — `.apple-nav`

`rgba(29, 29, 31, 0.72)` with `backdrop-filter: saturate(180%)
blur(20px)`. 44px tall, fixed top. On scroll it deepens to `0.9` and
gains a `rgba(255,255,255,0.12)` hairline. Used inside the shared
`<NavBar>` component.

```tsx
<header className={`apple-nav fixed inset-x-0 top-0 z-50 h-11 ${scrolled ? "scrolled" : ""}`}>
```

NavBar `variant: "home" | "subpage" | "changelog"`. The
currently-active item gets `font-semibold text-white`.

### 7.4 Footer link — `.footer-link`

`text-ink-2` (`#6e6e73`), 12px, `line-height: 2.41`. Hover → `ink`.
Single line per row, no borders between rows.

```tsx
<a className="footer-link" href={linkHref(link)}>
  {link}
</a>
```

### 7.5 Mockup card — `.mockup-card`

Rounded `[28px]`, padded `p-6 sm:p-8`. Hover lift `translateY(-5px)`
via `--ease-out`, 500ms. On touch (`@media (hover: none)`) the lift is
suppressed automatically.

```tsx
<div className="mockup-card product-shadow-dark mx-auto w-full max-w-[760px] rounded-[28px] border border-white/10 bg-black/40 p-6 sm:p-8">
  …
</div>
```

The two variants are:
- `mockup-card product-shadow` for light surfaces
- `mockup-card product-shadow-dark` for dark surfaces

### 7.6 Tag / chip pill

For change-tags, status, and short labels:

```tsx
<span
  className="inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold"
  style={{ backgroundColor: "#E6F0FF", color: "#0066CC" }}
>
  Feature
</span>
```

For "Local-first / No cloud upload / …" style chips on hero
introductions, use the heavier weight (text-[12px], py-1, px-3):

```tsx
<span className="inline-flex items-center rounded-full bg-white px-3 py-1 text-[12px] font-semibold text-ink-2 shadow-product">
  Local-first
</span>
```

### 7.7 Section eyebrow + heading pair

```tsx
<div className="mx-auto max-w-[820px] text-center">
  <span className="type-eyebrow text-blue">{eyebrow}</span>
  <h2 className="mt-3 text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
    {title}
  </h2>
  <p className="mx-auto mt-5 max-w-[680px] text-[16px] leading-relaxed text-ink-2 sm:text-[18px]">
    {subtitle}
  </p>
</div>
```

On dark tiles, swap `text-ink` → `text-white`, `text-ink-2` →
`text-white/65`, and `text-blue` → `text-blue-sky`.

### 7.8 Focus ring — `.focus-ring`

Drop on any interactive element that should get a keyboard focus ring
without changing the resting visual.

```tsx
<a className="focus-ring …" href="…">…</a>
```

Renders as a 2px `#2997ff` outline at 2px offset, only on
`:focus-visible`.

---

## 8. Layout patterns

### 8.1 Hero (used on every subpage)

```tsx
<section className="bg-parchment px-5 pb-20 pt-28 sm:pb-24 sm:pt-36">
  <div className="mx-auto max-w-[820px] text-center">
    <span className="type-eyebrow text-blue">{c.eyebrow}</span>
    <h1 className="type-hero mt-3 text-ink">
      {c.title1}
      <br />
      {c.title2}
    </h1>
    <p className="type-lead mx-auto mt-5 max-w-[680px] text-ink-2">{c.subtitle}</p>

    {/* optional chip row */}
    <div className="mt-7 flex flex-wrap items-center justify-center gap-2">
      {c.introChips.map((chip) => (
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
```

Spacing: `pt-28 sm:pt-36` (clear under fixed nav). `pb-20 sm:pb-24`.
Eyebrow → h1: `mt-3`. h1 → lead: `mt-5`. lead → chips: `mt-7`.

### 8.2 Section (the standard tile)

```tsx
<section className="px-5 py-20 sm:py-28">
  <div className="mx-auto max-w-[820px] text-center">
    <span className="type-eyebrow text-blue">{eyebrow}</span>
    <h2 className="mt-3 text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
      {title}
    </h2>
    <p className="mx-auto mt-5 max-w-[680px] text-[16px] leading-relaxed text-ink-2 sm:text-[18px]">
      {subtitle}
    </p>
  </div>

  {/* content block — center, 12 below the heading */}
  <div className="mx-auto mt-12 max-w-[760px]">
    {content}
  </div>
</section>
```

The `mt-12` is the single rule. `mt-16` looks empty, `mt-8` looks
crowded.

### 8.3 Two-column feature

```tsx
<section className="bg-parchment px-5 py-20">
  <div className="mx-auto flex max-w-[1040px] flex-col gap-10 sm:flex-row sm:gap-14">
    {/* visual on the left */}
    <div className="flex flex-1 flex-col gap-6">
      <span className="type-eyebrow text-blue">{eyebrow}</span>
      <h3 className="text-[28px] font-semibold leading-tight tracking-tight text-ink sm:text-[34px]">
        {heading}
      </h3>
      <p className="text-[17px] leading-relaxed text-ink-2">{body}</p>
    </div>

    {/* visual or card on the right */}
    <aside className="flex flex-1 flex-col items-center gap-5 rounded-[24px] border border-black/10 bg-white p-8 shadow-product">
      {visual}
    </aside>
  </div>
</section>
```

### 8.4 Dark tile

Replace all `text-ink` → `text-white`, `text-ink-2` → `text-white/65`,
`text-ink-3` → `text-white/45`. Use `bg-tile` as the base. Use
`product-shadow-dark`, not `product-shadow`.

```tsx
<section className="bg-tile px-5 py-20 sm:py-28 text-white">
  <div className="mx-auto flex max-w-[1040px] flex-col gap-12">
    <div className="text-center">
      <span className="type-eyebrow text-blue-sky">{eyebrow}</span>
      <h2 className="mt-3 text-[34px] font-semibold leading-tight tracking-tight sm:text-[40px]">
        {title}
      </h2>
      <p className="mx-auto mt-4 max-w-[680px] text-[18px] leading-relaxed text-white/65">
        {subtitle}
      </p>
    </div>
    {/* dark-tile content */}
  </div>
</section>
```

### 8.5 CTA section

```tsx
<section className="bg-white px-5 py-20">
  <div className="mx-auto flex max-w-[820px] flex-col items-center gap-6 text-center">
    <h2 className="text-[34px] font-semibold leading-tight tracking-tight text-ink sm:text-[40px]">
      {title}
    </h2>
    <p className="max-w-[680px] text-[18px] text-ink-2">{subtitle}</p>
    <a href="…" target="_blank" rel="noopener noreferrer" className="apple-cta-primary">
      Primary action ›
    </a>
    <a href="…" className="apple-cta-link text-blue">
      Secondary action ›
    </a>
    <a href="…" className="apple-cta-link text-blue">
      Tertiary action ›
    </a>
  </div>
</section>
```

Stack rules for CTAs: one primary, up to two text-link secondaries, all
stacked, all centered, all `gap-6`.

---

## 9. Accessibility

- Every visible string must be in both `en` and `zh` (`Copy` type).
- Every interactive element gets `focus-ring` or its own
  `focus-visible` rule.
- Reduce-motion users get a global media query that disables
  animations (`@media (prefers-reduced-motion: reduce)` already wired
  in `src/styles.css`).
- Tap targets ≥ 44×44. On touch-only devices, hover transforms are
  suppressed automatically.
- Icons must have `aria-hidden="true"`; meaningful SVGs need
  `role="img"` and an `aria-label`.
- All chart `<svg>` blocks have `role="img"` and a descriptive
  `aria-label`.
- The Apple-Health-style recovery heatmap grid is `role="grid"` and
  each cell is a `<button aria-label="Recovery N%">`.

---

## 10. File map (where things live)

```
stresswatch-web/
├── index.html              # home entry
├── how/index.html          # /how/  entry
├── changelog/index.html    # /changelog/ entry
├── privacy/index.html      # /privacy/ entry
├── about/index.html        # /about/ entry
├── design.md               # this file
├── src/
│   ├── main.tsx            # mounts <App /> for /
│   ├── how-main.tsx        # mounts <App variant="how" />
│   ├── changelog-main.tsx  # mounts <App variant="changelog" />
│   ├── privacy-main.tsx    # mounts <App variant="privacy" />
│   ├── about-main.tsx      # mounts <App variant="about" />
│   ├── App.tsx             # ALL page logic — see §11
│   ├── typography.css      # @font-face + .font-apple
│   └── styles.css          # design tokens + motion utilities
├── tailwind.config.ts      # color tokens, font stack, shadows
├── vite.config.ts          # multi-entry build (one HTML per page)
└── public/
    ├── changelog.json      # GitHub snapshot, refreshed by Actions
    └── stresswatch-logo.svg
```

### Where to add a new component class

The decision tree, in order:

1. **One-off visual rule** (a specific card or hero pattern used in
   one place only): put it as inline `style={{ ... }}` in `App.tsx`. If
   it's truly one place, an inline style is honest about it being a
   one-off.
2. **System rule used twice**: lift it into `src/styles.css` as a
   `.foo` class, and reference it from `App.tsx` via `className`.
3. **Token** (a color, a duration, a curve): into `tailwind.config.ts`
   (color) or `:root` in `styles.css` (`--ease-out` / `--ease-soft`).
4. **Never** add a new hex value inline in JSX. Even one-offs go
   through the token system so a future palette swap is a single file
   edit.

---

## 11. `App.tsx` house rules

`App.tsx` is large by design — every page shares the same `NavBar`,
`Footer`, `CursorParticles`, and `usePersistedLang`. New pages are
**routed by `variant`**, not by adding new top-level files.

### 11.1 The `Copy` type is the contract

Every visible string lives in `Copy`. The shape is fixed:

```ts
type Copy = {
  nav: { dashboard: string; features: string; how: string;
          privacy: string; download: string; languageLabel: string;
          changelog: string };
  hero: { badge: string; title: string; /* … */ };
  // …
  footer: { /* … */ columns: { title: string; links: string[] }[] };
  // …
  // Optional subpage sections:
  changelog?: { /* … */ };
  privacyPage?: { /* … */ };
  about?: { /* … */ };
};
```

If you add a field to one language, the build breaks — that's a
feature. Don't bypass with `?.` and `??`.

### 11.2 Adding a new subpage `/foo/`

Follow this exact 8-step recipe. Skip one and you'll break cross-page
links or the deploy.

1. **Copy** — add `foo: { eyebrow, title1, title2, subtitle, … }` to
   `Copy` (both `en` and `zh`). Mirror all existing fields.
2. **Page component** — define `<FooPage />` in `App.tsx`, mirroring
   the shape of `HowPage` / `PrivacyPage`. Use `usePersistedLang()`.
3. **Variant type** — extend the `App` prop type:
   `variant?: "home" | "how" | "foo"`.
4. **Route branch** — add `if (variant === "foo") return <FooPage />;`
   in the default export.
5. **Vite entry** — add `foo: resolve(__dirname, "foo/index.html")` to
   `vite.config.ts` `input`.
6. **HTML** — create `foo/index.html` with a `#root` div and a
   `<script type="module" src="/src/foo-main.tsx">` tag.
7. **Mount** — create `src/foo-main.tsx` that imports `./App` and
   renders `<App variant="foo" />` into `#root`.
8. **Wiring** — wire cross-page links in `NavBar` (using the
   `homeHref` / `howHref` / `changelogHref` / `privacyHref` pattern —
   see §11.3) and add any footer columns via the `linkHref` switch.

After the build, take screenshots at the four breakpoints in §14.

### 11.3 The five cross-page href rules

Don't reinvent these. The pattern is `${prefix}${page}/`:

```ts
const homeHref       = variant === "home" ? "./" : "../";
const howHref        = variant === "subpage" ? "./" :
                       variant === "home"    ? "./how/"     : "../how/";
const changelogHref  = variant === "changelog" ? "./" :
                       variant === "home"     ? "./changelog/" : "../changelog/";
const privacyHref    = variant === "home" ? "./privacy/" : "../privacy/";
```

Same rule for any new subpage: `./<page>/` on home, `../<page>/` from
any other subpage, `./` on the same page.

### 11.4 The NavBar pattern

```tsx
// desktop nav
<a
  key={item.id}
  href={howHref}
  className={`focus-ring rounded-md text-[12px] transition hover:text-white ${
    isActive ? "font-semibold text-white" : "font-normal text-white/80"
  }`}
>
  {item.label}
</a>

// mobile sheet — same href, larger typography, full-width tap target
<a
  href={howHref}
  onClick={() => setMobileOpen(false)}
  className="focus-ring flex w-full items-center justify-between border-b border-white/10 py-4 text-left text-[15px] font-medium text-white/90 transition hover:text-white"
>
  {item.label}
  <span className="text-white/40" aria-hidden="true">›</span>
</a>
```

### 11.5 Language persistence

`usePersistedLang()` reads / writes `localStorage["stresswatch.lang"]`.
Every page-level component **must** use it; do not introduce a new
`useState<Lang>("zh")`.

```tsx
function usePersistedLang(): [Lang, (l: Lang) => void] {
  const [language, setLanguage] = useState<Lang>(() => {
    try {
      const v = window.localStorage.getItem("stresswatch.lang");
      return v === "en" || v === "zh" ? v : "zh";
    } catch { return "zh"; }
  });
  const update = (l: Lang) => {
    setLanguage(l);
    try { window.localStorage.setItem("stresswatch.lang", l); } catch {}
  };
  return [language, update];
}
```

The `try/catch` matters — Safari private mode and some embedded
WebViews throw on `localStorage` access.

---

## 12. Adding a new color

If you genuinely need a new color (rare — check tokens first):

1. Add it to `tailwind.config.ts` with a semantic name (`tile-mid`,
   never `gray-3`).
2. Update this doc's color table.
3. If it's part of a semantic system (e.g. a new chart scale), put
   the stops next to the existing `HEAT_STOPS` in `App.tsx`.
4. Never use it in more than one component without the doc explaining
   the system.

If you're tempted to add a "warm accent" or "success green" — first
check if `green`, `blue-sky`, or the existing palette already covers
the semantic. We have one accent. Keep it that way.

---

## 13. Adding a new component class

If a new visual pattern will appear in ≥ 2 places:

1. Add a class to `src/styles.css` under the matching section.
2. Follow the existing naming: `apple-cta-*`, `product-shadow*`,
   `mockup-card`, `reveal-item`. Lowercase, hyphenated.
3. If it has hover / focus / active states, write all four. Test
   keyboard navigation, mouse hover, mouse-down, and touch tap.
4. If it has motion, declare the curve in `transition` literally —
   don't reference a CSS var you didn't add to `:root`.
5. Document it here. Link to the section that introduces it.

If a pattern appears in ≥ 4 places, consider hoisting it to a real
`<Component>` in `App.tsx` instead of a class. A class is a rule; a
component is a contract.

---

## 14. PR checklist (visual changes)

Before opening a PR that touches a page, screenshot at:

- 375×812 (iPhone) — hamburger sheet, font scales, single-column
  collapse.
- 768×1024 (iPad portrait) — two-column collapse point.
- 1280×800 (laptop) — full grid.
- 1920×1080 (desktop) — wide-screen centering.

For each: home + every subpage touched. The Pages deploy URL is
generated automatically once the PR merges.

Before merging, confirm:

- [ ] All four breakpoints look intentional — no accidental overflow.
- [ ] No raw hex values in JSX — every color is a token.
- [ ] No new `box-shadow` outside `product-shadow*`.
- [ ] No font-weight ≥ 700.
- [ ] No transition < 320ms.
- [ ] No new ease curve outside `--ease-out`, `--ease-soft`, or
      `cubic-bezier(0.16, 1, 0.3, 1)`.
- [ ] Both `en` and `zh` carry the same new keys.
- [ ] Focus rings visible on every interactive element via Tab.
- [ ] Reduced-motion users see a static version.
- [ ] No console errors in any of the 5 page contexts.

---

## 15. What "good" looks like

If your change requires an explanation to defend, it's probably not
this design system. The point of these rules is that any new section
should feel like it was always there. The cost of consistency is
patience; the cost of novelty is that nothing matches anymore.

When in doubt: re-read the apple.com homepage. That's the spec.