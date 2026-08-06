# StressWatch Web — Design System

This document is the source of truth for the landing-page design language.
It is **extracted from the code, not invented** — every rule below maps to
a concrete class, color token, or file you can grep for. When you change
something visual, change it here **and** in code, in the same commit.

The goal is **Apple design language**: a single neutral canvas, one ink,
one accent, one shadow, one set of curves, and motion that lasts longer
than the industry default.

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

---

## 2. Color tokens

All defined in `stresswatch-web/tailwind.config.ts` under
`theme.extend.colors`. Never use raw hex in JSX — reach for the token.

| Token         | Hex       | Role                                            |
| ------------- | --------- | ----------------------------------------------- |
| `ink`         | `#1d1d1f` | Primary text on light surfaces                  |
| `ink-2`       | `#6e6e73` | Secondary text on light surfaces                |
| `ink-3`       | `#86868b` | Tertiary text, placeholders, captions           |
| `blue`        | `#0066cc` | Action Blue — primary buttons, links, accents   |
| `blue-focus`  | `#0071e3` | Hover state for blue buttons                    |
| `blue-sky`    | `#2997ff` | Focus ring, info badges, dark-tile highlights   |
| `parchment`   | `#f5f5f7` | Section background, alternating rhythm          |
| `tile`        | `#272729` | Dark tile base (Trends, Networking)             |
| `tile-alt`    | `#2a2a2c` | Dark tile variant                               |
| `tile-deep`   | `#252527` | Dark tile deeper variant                        |
| `green`       | `#34c759` | "Local-first" chip, recovery heatmap high end   |
| `sleep-deep`  | `#0A84FF` | Sleep stage — Deep                              |
| `sleep-core`  | `#5AC8FA` | Sleep stage — Core                              |
| `sleep-rem`   | `#BF5AF2` | Sleep stage — REM                               |
| `sleep-awake` | `#FF9F0A` | Sleep stage — Awake                             |

### The heatmap scale (used only for the recovery heatmap)

A multi-hue ramp from low recovery (warm) to high recovery (cool). Keep
this scale locked to this single component — don't reuse the stops on
charts that have a different semantic.

```ts
HEAT_STOPS = [
  { p: 0.00, c: "#FF453A" }, // red    — low recovery
  { p: 0.28, c: "#FF9F0A" }, // orange
  { p: 0.52, c: "#FFD60A" }, // yellow
  { p: 0.76, c: "#30D158" }, // green
  { p: 1.00, c: "#2997FF" }  // blue   — high recovery
];
```

---

## 3. Typography

Single stack, defined once in `tailwind.config.ts` and re-exposed as
`font-apple` in `typography.css`. Weights: 400 / 500 / 600. **No 700,
no 800, no 900.** If a heading feels weak, increase the size first.

### Type scale (`App.tsx` `.type-*` classes)

| Class          | Size / line-height        | Use                                        |
| -------------- | ------------------------- | ------------------------------------------ |
| `type-hero`    | 56 / 64, weight 600       | Hero h1 on every subpage and home          |
| `type-lead`    | 21 / 30, weight 400       | Hero subtitle                              |
| `type-tagline` | 28 / 36, weight 600       | Product card title (mockup-card heading)   |
| `type-body`    | 17 / 26, weight 400       | Product card body                          |
| `type-eyebrow` | 13, weight 600, tracking  | Small uppercase label above every section  |

### Rules

- Always lowercase the word `StressWatch` in the lockup.
- Numerals in cards and charts are **tabular**: `tabular-nums`.
- Hero titles use `<br />` between two short lines, never wrap three.

---

## 4. Spacing & layout

- Container widths: `max-w-[680px]` for narrow copy, `max-w-[760px]`
  for product mockups, `max-w-[820px]` for hero CTAs, `max-w-[1040px]`
  for two-column sections. Never invent a new width.
- Section rhythm: `px-5 py-20 sm:py-28`. Every full-bleed section uses
  this — it gives the page its long, calm vertical breathing room.
- Tile alternation rule: light → parchment → dark → light → parchment →
  dark → light. Never two lights in a row, never two darks in a row.
- Card radius: `rounded-[18px]` for inline cards, `rounded-[24px]` for
  feature cards, `rounded-[28px]` for mockup cards. No other radius.

---

## 5. The shadow language

Two and only two shadows:

```css
.product-shadow       /* rgba(0,0,0,0.22) 3px 5px 30px — light surfaces */
.product-shadow-dark  /* rgba(0,0,0,0.55) 3px 5px 30px — dark surfaces */
```

Use on:

- `<Tile>` content cards and `mockup-card`s.
- Hover lift target only (`mockup-card:hover { translateY(-5px) }`).

**Do not** add `box-shadow` on buttons, inputs, or the nav. Buttons get
their affordance from color and transform, not shadow.

---

## 6. Motion system

Two curves only, declared as CSS vars and as literal cubic-beziers:

```css
--ease-out:  cubic-bezier(0.22, 1, 0.36, 1);  /* scroll reveal, language fade */
--ease-soft: cubic-bezier(0.32, 0.72, 0, 1);  /* mockup-card hover */
```

For inline component-level motion (Apple card-zoom style), use the
**Apple spring-decel curve** literally:

```
cubic-bezier(0.16, 1, 0.3, 1)
```

### Durations

| Use case                          | Duration |
| --------------------------------- | -------- |
| Language cross-fade               | 320ms    |
| Mockup-card hover lift            | 500ms    |
| Scroll reveal (`.reveal-item`)    | 900ms    |
| Apple card-zoom entrance          | 700ms    |
| Apple card-zoom exit              | 480ms    |
| Heatmap preview badge / pill      | 600ms    |
| Nav bar tint change on scroll     | 400ms    |

Anything shorter than 320ms feels like a status update, not motion.
Don't write a `transition: 100ms` ever.

### Reveal mechanism

```tsx
const { active, ref } = useRevealOnView<HTMLDivElement>();
<div ref={ref} className={`reveal-group ${active ? "is-active" : ""}`}>
  <div className="reveal-item">…</div>
  <div className="reveal-item" style={{ transitionDelay: "0.12s" }}>…</div>
</div>
```

`useRevealOnView` activates when the section's top crosses 82% of
viewport height. Once active, the section stays shown — scrolling back
above the threshold reverses it (so it replays on re-entry).

### Spring-decel (no overshoot)

Apple's actual card-zoom does not overshoot. The curve
`cubic-bezier(0.16, 1, 0.3, 1)` already gives the spring-decel feel by
spending most of its duration near the rest position. **Do not** use
`cubic-bezier(0.34, 1.56, 0.64, 1)` — the overshoot looks mechanical on
any scale > 1.5×.

### Two-phase exit (preview cards)

When dismissing a preview card, never unmount immediately. Use a
`closing` flag:

```tsx
const [closing, setClosing] = useState(false);
const dismiss = () => {
  setClosing(true);
  setTimeout(() => { setPicked(null); setClosing(false); }, 480);
};
```

Inside `style.transition`, branch on `closing ? exitProps : enterProps`
so the same node plays both halves of the gesture.

---

## 7. Components

### Buttons (the signature Apple pair)

- **`.apple-cta-primary`** — pill, `#0066cc`, white text, hover
  `#0071e3` + `translateY(-1px)` + soft blue glow, active `scale(0.96)`,
  focus-visible `#2997ff` ring.
- **`.apple-cta-link`** — text link in blue, hover `opacity: 0.62`,
  focus-visible ring. Use for secondary / tertiary actions on the same
  landing surface.

Use both on the same page; never use a third style.

### Navigation

- **`.apple-nav`** — `rgba(29, 29, 31, 0.72)` with `backdrop-filter:
  saturate(180%) blur(20px)`. 44px tall, fixed top. On scroll it
  deepens to `0.9` and gains a `rgba(255,255,255,0.12)` hairline.
- NavBar `variant: "home" | "subpage" | "changelog"`. The
  currently-active item gets `font-semibold text-white`.

### Footer

- **`.footer-link`** — `text-ink-2` (`#6e6e73`), 12px, `line-height:
  2.41`, hover → `ink`. Single underline / row, no borders between rows.

### Mockup cards (`.mockup-card`)

- Rounded `[28px]`, padded `p-6 sm:p-8`.
- Hover lift `translateY(-5px)` via `--ease-out`, 500ms.
- On touch (`@media (hover: none)`) the lift is suppressed.

### Tag / chip pills

- Recovery tags use semantic colors (`#FFEEEE` bg, `#A32D2D` text for
  Fix; `#E6F0FF` / `#0066CC` for Feature; `#FFF1E0` / `#A35A0B` for
  Polish). Each tag is `rounded-full px-2.5 py-0.5 text-[11px]
  font-semibold`.

---

## 8. Layout patterns

### Hero

```
[eyebrow]                 # type-eyebrow, Action Blue, uppercase
[ h1 line 1 ]
[ h1 line 2 ]
[lead paragraph]          # type-lead, ink-2
[optional chip row]       # rounded-full pill chips
```

- `pt-28 sm:pt-36` (clear under fixed nav).
- `pb-20 sm:pb-24`.
- Eyebrow → h1 lead-time: `mt-3`. h1 → lead: `mt-5`.

### Section

```
<section id="…" className="px-5 py-20 sm:py-28 {bg}">
  <TileHeading eyebrow title tagline cta ctaHref />  {/* optional */}
  <div className="reveal-item mx-auto mt-12 …">
    <Mockup … />
  </div>
</section>
```

`mt-12` between heading and content is the single rule. `mt-16` looks
empty, `mt-8` looks crowded.

### Two-column feature

```
<div className="mx-auto flex max-w-[1040px] flex-col gap-10 sm:flex-row sm:gap-14">
  <aside className="flex flex-1 …">{visual}</aside>
  <div  className="flex flex-1 flex-col gap-6">{copy}</div>
</div>
```

### Dark tile (Networking, Live Stress, Trends)

Add a `text-white` parent so children inherit light. Replace
`text-ink` → `text-white/80` for headings, `text-ink-2` →
`text-white/55–65` for body, `text-ink-3` → `text-white/45`. Use
`product-shadow-dark`, not `product-shadow`.

---

## 9. Accessibility

- Every visible string must be in both `en` and `zh` (`Copy` type).
- Every interactive element gets `focus-ring` or its own
  `focus-visible` rule.
- Reduce-motion users get a global media query that disables
  animations (`@media (prefers-reduced-motion: reduce)` already wired
  in `styles.css`).
- Tap targets ≥ 44×44. On touch-only devices, hover transforms are
  suppressed automatically.

---

## 10. File map (where things live)

```
stresswatch-web/
├── index.html              # home entry
├── how/index.html          # /how/  entry
├── changelog/index.html    # /changelog/ entry
├── privacy/index.html      # /privacy/ entry
├── about/index.html        # /about/ entry
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

- **One-off visual rule** (a specific card or hero pattern): put it as
  inline `style={{ ... }}` in `App.tsx` if it's truly one place. If
  it's used twice, lift it into `styles.css`.
- **System rule** (anything that affects > 1 component): into
  `styles.css` as a `.foo` class, and reference it from `App.tsx` via
  `className`.
- **Token** (a color, a duration, a curve): into `tailwind.config.ts`
  (color) or `:root` (`--ease-out` / `--ease-soft`).

---

## 11. `App.tsx` house rules

`App.tsx` is large by design — every page shares the same `NavBar`,
`Footer`, `CursorParticles`, and `usePersistedLang`. New pages are
**routed by `variant`**, not by adding new top-level files.

To add a new subpage `/foo/`:

1. Add `foo: { eyebrow, … }` to `Copy` (both `en` and `zh`).
2. In `App.tsx`, define `<FooPage />` mirroring the shape of
   `HowPage` / `PrivacyPage`.
3. Extend the `App` prop type: `variant?: "home" | "how" | "foo"`.
4. Add the route branch in the default export.
5. In `vite.config.ts`, add `foo: resolve(__dirname, "foo/index.html")`.
6. Create `foo/index.html` and `src/foo-main.tsx`.
7. Wire cross-page links in `NavBar` (use the existing `homeHref`,
   `howHref`, `changelogHref`, `privacyHref` pattern — relative paths
   are `./` on home, `../` on subpages).
8. If `Foo` is in a new column of the Footer, add it to `linkHref`.

### The five cross-page href rules (don't reinvent these)

```ts
const homeHref       = variant === "home" ? "./" : "../";
const howHref        = variant === "subpage" ? "./" :
                       variant === "home"    ? "./how/"     : "../how/";
const changelogHref  = variant === "changelog" ? "./" :
                       variant === "home"     ? "./changelog/" : "../changelog/";
const privacyHref    = variant === "home" ? "./privacy/" : "../privacy/";
```

Same rule for the new subpage — `./<page>/` on home, `../<page>/`
from any other subpage.

### Language persistence

`usePersistedLang()` reads / writes `localStorage["stresswatch.lang"]`.
Every page-level component must use it; do not introduce a new
`useState<Lang>("zh")`.

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

---

## 13. PR checklist (visual changes)

Before opening a PR that touches a page, screenshot at:

- 375×812 (iPhone) — hamburger sheet, font scales, single-column
  collapse.
- 768×1024 (iPad portrait) — two-column collapse point.
- 1280×800 (laptop) — full grid.
- 1920×1080 (desktop) — wide-screen centering.

For each: home + every subpage touched. The Pages deploy URL is
generated automatically once the PR merges.

---

## 14. What "good" looks like

If your change requires an explanation to defend, it's probably not
this design system. The point of these rules is that any new section
should feel like it was always there. The cost of consistency is
patience; the cost of novelty is that nothing matches anymore.

When in doubt: re-read the apple.com homepage. That's the spec.