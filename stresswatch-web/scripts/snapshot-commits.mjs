#!/usr/bin/env node
/**
 * snapshot-commits.mjs
 *
 * Pulls the most recent commits (and releases, if any) for the
 * `Nanako-Arasaka/StressWatch` repo and writes a JSON snapshot that
 * the changelog subpage reads at build / fetch time.
 *
 * Why a snapshot and not a live fetch?
 *   - Public commits support CORS, but anonymous GitHub API requests
 *     are limited to 60/hr per IP. Many visitors hitting the page
 *     could trip the limit.
 *   - GitHub Actions triggers the script on a schedule; the
 *     resulting JSON is committed back to master and shipped via
 *     the same Pages deploy pipeline.
 *
 * Usage:
 *   node scripts/snapshot-commits.mjs [--repo=owner/name] [--out=path] [--commits=N]
 *
 * Env:
 *   GITHUB_REPO         override repo (default: Nanako-Arasaka/StressWatch)
 *   GITHUB_TOKEN        optional PAT to lift rate limits (5,000/hr)
 */
import { writeFile, mkdir } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const m = a.match(/^--([^=]+)=(.*)$/);
    return m ? [m[1], m[2]] : [a.replace(/^--/, ""), true];
  }),
);

const REPO = args.repo ?? process.env.GITHUB_REPO ?? "Nanako-Arasaka/StressWatch";
const OUT = resolve(
  __dirname,
  "..",
  args.out ?? "public/changelog.json",
);
const COMMITS = Number(args.commits ?? process.env.COMMITS ?? 30);
const HEADERS = {
  Accept: "application/vnd.github+json",
  "X-GitHub-Api-Version": "2022-11-28",
  "User-Agent": "stresswatch-changelog-snapshot",
};
if (process.env.GITHUB_TOKEN) {
  HEADERS.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
}

async function fetchAll(url) {
  const out = [];
  let next = url;
  while (next) {
    const r = await fetch(next, { headers: HEADERS });
    if (!r.ok) {
      throw new Error(`GET ${next} -> ${r.status} ${r.statusText}`);
    }
    out.push(...(await r.json()));
    const link = r.headers.get("link") ?? "";
    const m = link.match(/<([^>]+)>;\s*rel="next"/);
    next = m ? m[1] : null;
  }
  return out;
}

function shortSha(s) {
  return s ? s.slice(0, 7) : "";
}

function monthLabel(dateIso) {
  const d = new Date(dateIso);
  return d.toLocaleString("en-US", { month: "long", year: "numeric", timeZone: "UTC" });
}

function dateLabel(dateIso, locale = "en-US") {
  const d = new Date(dateIso);
  return d.toLocaleDateString(locale, {
    month: "short",
    day: "numeric",
    timeZone: "UTC",
  });
}

const TAG_RULES = [
  { match: /^merge|^pull request/i, tag: "Routing" },
  { match: /\bfix|bug|hotfix|patch/i, tag: "Fix" },
  { match: /\bdocs?(\b|:)|readme|handoff|comment/i, tag: "Docs" },
  { match: /\bci\b|deploy|workflow|github actions|pages/i, tag: "CI" },
  { match: /\bmotion|animation|reveal|particle|transition/i, tag: "Motion" },
  { match: /\bpolish|refactor|style|naming|tidy/i, tag: "Polish" },
  { match: /\bfeat|^add|new feature|introduce|implement/i, tag: "Feature" },
  { match: /link|href|url|redirect|navigate/i, tag: "Link" },
  { match: /\bai\b|model|coreml|ml|training|classifier/i, tag: "AI" },
];

function tagsFor(subject) {
  const tags = [];
  for (const r of TAG_RULES) {
    if (r.match.test(subject) && !tags.includes(r.tag)) tags.push(r.tag);
  }
  if (tags.length === 0) tags.push("Polish");
  return tags.slice(0, 3);
}

async function main() {
  console.log(`[snapshot] repo=${REPO} commits=${COMMITS} out=${OUT}`);
  const base = `https://api.github.com/repos/${REPO}`;

  // Pull releases (rare for this repo, but useful if/when they exist)
  let releases = [];
  try {
    const data = await fetchAll(`${base}/releases?per_page=10`);
    releases = data.map((r) => ({
      tag: r.tag_name,
      name: r.name ?? r.tag_name,
      date: r.published_at ?? r.created_at,
      body: r.body ?? "",
      sha: shortSha(r.target_commitish),
      assetCount: Array.isArray(r.assets) ? r.assets.length : 0,
      url: r.html_url,
      isPrerelease: !!r.prerelease,
      isDraft: !!r.draft,
    }));
  } catch (e) {
    console.warn(`[snapshot] releases fetch failed: ${e.message}`);
  }

  // Pull recent commits
  const commitData = await fetchAll(`${base}/commits?sha=master&per_page=${COMMITS}`);
  const commits = commitData.map((c) => ({
    sha: shortSha(c.sha),
    fullSha: c.sha,
    date: c.commit?.author?.date ?? c.commit?.committer?.date,
    subject: c.commit?.message?.split("\n", 1)[0] ?? "(no subject)",
    author: c.commit?.author?.name ?? c.author?.login ?? "unknown",
    url: c.html_url,
  }));

  // Group commits by month
  const buckets = new Map();
  for (const c of commits) {
    const key = monthLabel(c.date);
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(c);
  }
  const commitsByMonth = [...buckets.entries()].map(([label, list]) => ({
    label,
    summary: `${list.length} commit${list.length === 1 ? "" : "s"}`,
    entries: list.map((c) => ({
      date: dateLabel(c.date),
      sha: c.sha,
      title: c.subject,
      tags: tagsFor(c.subject),
      url: c.url,
      author: c.author,
    })),
  }));

  const snapshot = {
    syncedAt: new Date().toISOString(),
    repo: REPO,
    commitsTotal: commits.length,
    releasesCount: releases.length,
    releases,
    commitsByMonth,
  };

  await mkdir(dirname(OUT), { recursive: true });
  await writeFile(OUT, JSON.stringify(snapshot, null, 2));
  console.log(
    `[snapshot] wrote ${OUT} (${commits.length} commits, ${releases.length} releases)`,
  );
}

main().catch((e) => {
  console.error("[snapshot] failed:", e.message);
  process.exit(1);
});