// Captures everything we need from the current Google Sites site, in ONE pass:
//
//   dom/<slug>.html        rendered DOM        — what the content is
//   geometry.json          bounding boxes      — where it sits
//   images/<slug>-NN.jpeg  the photos          — the bytes themselves
//   images/manifest.tsv    url -> file
//   shots-desktop/, shots-mobile/   visual reference to build against
//
// One pass is not a convenience, it is a correctness requirement. Google serves
// images from signed URLs that rotate between browser sessions and expire in
// roughly twenty minutes. Capture the DOM in one run and measure in another and
// you get two disjoint sets of URLs with nothing to join them on. So each page
// is navigated once and the DOM, geometry and bytes are taken together.
//
// Why geometry at all: Sites places grid cells explicitly, so document order is
// not visual order. The home page reads as two rows of two in the DOM and
// renders as two columns of stacked items.
//
// Zero dependencies — Node 22+ has a global WebSocket, which is all CDP needs.
//
//   node reference/current-site/capture.mjs
import { spawn } from "node:child_process";
import { writeFileSync, mkdirSync, appendFileSync, rmSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const PAGES = [
  "home", "about-us", "about-us/our-story", "about-us/leadership", "about-us/choir",
  "events-services", "events-services/weekly-bulletin", "events-services/miter-ceremony",
  "donate", "community-outreach", "contact",
];

const CHROME = process.env.CHROME || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
].find(existsSync);

if (!CHROME) {
  console.error("No Chrome found. Set CHROME=/path/to/chrome");
  process.exit(1);
}

const PORT = 9333;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

for (const d of ["dom", "images", "shots-desktop", "shots-mobile"]) {
  mkdirSync(join(HERE, d), { recursive: true });
}
rmSync(join(HERE, "images/manifest.tsv"), { force: true });
rmSync(join(HERE, "images/failed.txt"), { force: true });

const chrome = spawn(CHROME, [
  "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
  `--remote-debugging-port=${PORT}`, "--window-size=1440,2400",
  "--user-data-dir=/tmp/sjoca-capture-profile", "about:blank",
], { stdio: "ignore" });

async function endpoint() {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      return (await r.json()).webSocketDebuggerUrl;
    } catch { await sleep(250); }
  }
  throw new Error("Chrome did not expose a debugging port");
}

function client(ws) {
  let id = 0;
  const pending = new Map();
  ws.addEventListener("message", (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  });
  return (method, params = {}, sessionId) => new Promise((res) => {
    const n = ++id;
    pending.set(n, res);
    ws.send(JSON.stringify({ id: n, method, params, sessionId }));
  });
}

// Walk the page so lazy-loaded images get laid out, then wait for them.
const SETTLE = `(async () => {
  const step = Math.floor(window.innerHeight * 0.8);
  for (let y = 0; y < document.body.scrollHeight; y += step) {
    window.scrollTo(0, y); await new Promise(r => setTimeout(r, 160));
  }
  window.scrollTo(0, 0); await new Promise(r => setTimeout(r, 500));
  await Promise.all([...document.images].map(i => i.complete ? null :
    new Promise(r => { i.addEventListener('load', r); i.addEventListener('error', r); })));
  return document.body.scrollHeight;
})()`;

const MEASURE = `(() => {
  const main = document.querySelector('div[jsname=ZBtY8b]');
  if (!main) return [];
  return [...main.children].filter(e => e.tagName === 'SECTION').map((sec, si) => {
    const sr = sec.getBoundingClientRect();
    const items = [], seen = new Set();
    sec.querySelectorAll('img.CENy8b, div.w536ob[data-url], h1, h2, h3, h4, p').forEach(el => {
      // An embed wrapper legitimately contains a <p>, so it must not be
      // dismissed by the container check the text blocks need.
      const isEmbed = el.matches('div.w536ob[data-url]');
      if (!isEmbed && el.querySelector('h1,h2,h3,h4,p,img.CENy8b')) return;
      const r = el.getBoundingClientRect();
      if (!isEmbed && (r.width < 2 || r.height < 2)) return;
      const text = (el.innerText || '').replace(/\\s+/g, ' ').trim();
      const src  = el.getAttribute('src') || el.getAttribute('data-url') || null;
      if (!src && !text) return;
      const key = (src || text).slice(0, 200);
      if (seen.has(key)) return; seen.add(key);
      items.push({ tag: el.tagName.toLowerCase(), src, text: text.slice(0, 160),
        x: Math.round(r.left - sr.left), y: Math.round(r.top - sr.top),
        w: Math.round(r.width), h: Math.round(r.height) });
    });
    return { index: si, width: Math.round(sr.width), height: Math.round(sr.height), items };
  });
})()`;

const EXT = { "image/jpeg": "jpeg", "image/png": "png", "image/gif": "gif", "image/webp": "webp" };

const ws = new WebSocket(await endpoint());
await new Promise((r) => ws.addEventListener("open", r));
const send = client(ws);

const targets = (await send("Target.getTargets")).result.targetInfos;
const { sessionId } = (await send("Target.attachToTarget",
  { targetId: targets.find((t) => t.type === "page").targetId, flatten: true })).result;
await send("Page.enable", {}, sessionId);
await send("Runtime.enable", {}, sessionId);

const DESKTOP = { width: 1440, height: 2400, deviceScaleFactor: 1, mobile: false };

// Measure and screenshot at an explicit viewport, then put it back. Without the
// reset the mobile screenshot's 390px override leaks into the NEXT page's
// measurement, and every page after the first gets measured as a single
// mobile-width column.
async function viewport(metrics) {
  await send("Emulation.setDeviceMetricsOverride", metrics, sessionId);
  await sleep(400);
}

async function shot(file, width, height) {
  await send("Emulation.setDeviceMetricsOverride",
    { width, height, deviceScaleFactor: 1, mobile: false }, sessionId);
  await sleep(700);
  const r = await send("Page.captureScreenshot",
    { format: "png", captureBeyondViewport: true }, sessionId);
  if (r.result?.data) writeFileSync(file, Buffer.from(r.result.data, "base64"));
}

const geometry = {};
let okTotal = 0, failTotal = 0;

for (const path of PAGES) {
  const slug = path.replaceAll("/", "--");

  // Retry once: the very first navigation can race Chrome's startup and come
  // back with nothing measured.
  let geo = [];
  for (let attempt = 0; attempt < 2 && geo.length === 0; attempt++) {
    await viewport(DESKTOP);          // always measure at desktop width
    await send("Page.navigate", { url: `https://www.sjoca.org/${path}` }, sessionId);
    await sleep(attempt === 0 ? 3200 : 5000);
    await send("Runtime.evaluate",
      { expression: SETTLE, returnByValue: true, awaitPromise: true }, sessionId);
    geo = (await send("Runtime.evaluate",
      { expression: MEASURE, returnByValue: true }, sessionId)).result?.result?.value ?? [];
  }
  geometry[path] = geo;

  const html = (await send("Runtime.evaluate",
    { expression: "document.documentElement.outerHTML", returnByValue: true }, sessionId))
    .result?.result?.value ?? "";
  writeFileSync(join(HERE, "dom", `${slug}.html`), html);

  // Download now, while these URLs are still valid.
  const urls = new Set();
  for (const s of geo) for (const i of s.items) {
    if (i.src?.includes("googleusercontent")) urls.add(i.src);
  }
  // Bare URL match, not url(...): serializing outerHTML escapes the quotes
  // inside a style attribute, so background-image reads url(&quot;https...&quot;)
  // and a url(...) pattern silently misses every hero image.
  for (const m of html.matchAll(/https:\/\/lh\d-us\.googleusercontent\.com[^"'\s)<>\\]+/g)) {
    urls.add(m[0].replaceAll("&amp;", "&").replace(/&quot;.*$/, ""));
  }

  let n = 0, ok = 0, fail = 0;
  for (const url of urls) {
    n++;
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(String(res.status));
      const buf = Buffer.from(await res.arrayBuffer());
      const ext = EXT[res.headers.get("content-type")?.split(";")[0]] ?? "jpeg";
      const rel = `images/${slug}-${String(n).padStart(2, "0")}.${ext}`;
      writeFileSync(join(HERE, rel), buf);
      appendFileSync(join(HERE, "images/manifest.tsv"), `${slug}\t${rel}\t${url}\n`);
      ok++;
    } catch (e) {
      appendFileSync(join(HERE, "images/failed.txt"), `${e.message} ${url}\n`);
      fail++;
    }
  }
  okTotal += ok; failTotal += fail;

  await shot(join(HERE, "shots-desktop", `${slug}.png`), 1440, 2400);
  await shot(join(HERE, "shots-mobile",  `${slug}.png`), 390, 1400);
  await viewport(DESKTOP);            // undo the mobile override before moving on

  const items = geo.reduce((a, s) => a + s.items.length, 0);
  console.error(`${path}: ${geo.length} sections, ${items} items, ${ok} images${fail ? `, ${fail} FAILED` : ""}`);
}

writeFileSync(join(HERE, "geometry.json"), JSON.stringify(geometry, null, 1));
console.error(`\nimages: ${okTotal} ok, ${failTotal} failed`);
ws.close(); chrome.kill(); process.exit(0);
