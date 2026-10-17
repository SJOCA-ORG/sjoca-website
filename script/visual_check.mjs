#!/usr/bin/env node
// Looks at a page the way a person would: at a phone width and a desktop one.
//
// Drives Chrome over CDP with no dependencies -- the same approach as
// reference/current-site/capture.mjs. There is no ChromeDriver and no Selenium;
// all that is needed is the browser binary, which is why this runs unchanged on
// a laptop and in a container. Set CHROME to point at it.
//
//   node script/visual_check.mjs http://localhost:3000/donate
//
// Prints JSON: findings, and a screenshot path per width when --shots is given.
import { spawn } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const URL_ARG = process.argv[2];
const SHOTS = process.argv.includes("--shots");
// Something to click before looking -- a menu button, an accordion, a "read
// more". Without this the check only ever sees a page in its resting state,
// and the worst bug on this site was one that only appeared after a tap.
const CLICK = (process.argv.find((a) => a.startsWith("--click=")) || "").slice(8);
// Standing promises to evaluate, as JSON on stdin: [{id, summary, script}].
// Every promise for a page is checked in ONE page load.
const PROMISES = (process.argv.find((a) => a.startsWith("--promises=")) || "").slice(11);
const OUT = process.env.SHOT_DIR || "/tmp/sjoca-shots";

if (!URL_ARG) { console.error("usage: visual_check.mjs <url> [--shots]"); process.exit(1); }

const CHROME = process.env.CHROME || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  // This Mac's Chrome.app contains a binary named "Google Chrome Beta".
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome",
].find(existsSync);

if (!CHROME) {
  console.log(JSON.stringify({ error: "no Chrome found; set CHROME=/path/to/chrome" }));
  process.exit(0);
}

const WIDTHS = [{ name: "phone", width: 390, height: 844 },
                { name: "desktop", width: 1280, height: 900 }];
const PORT = 9444;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const chrome = spawn(CHROME, [
  "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
  `--remote-debugging-port=${PORT}`,
  "--user-data-dir=/tmp/sjoca-visual-profile", "about:blank",
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
  // Page-domain commands need a session attached to a page target; the browser
  // endpoint alone only speaks the browser domains.
  return (method, params = {}, sessionId) => new Promise((resolve, reject) => {
    const mid = ++id;
    pending.set(mid, (m) => (m.error ? reject(new Error(m.error.message)) : resolve(m.result)));
    ws.send(JSON.stringify({ id: mid, method, params, sessionId }));
  });
}

// Runs INSIDE the page. These are the checks a person makes by looking, and
// between them they would have caught the two bugs that reached the real site:
// a menu taller than the screen with no way to scroll, and an element pushed
// off the side.
const INSPECT = `(() => {
  const findings = [];
  const d = document.documentElement;

  if (d.scrollWidth > d.clientWidth + 1) {
    const guilty = [...document.querySelectorAll("*")]
      .filter(el => el.getBoundingClientRect().right > d.clientWidth + 1)
      .slice(0, 3)
      .map(el => el.tagName.toLowerCase() + (el.className ? "." + String(el.className).split(" ")[0] : ""));
    findings.push({ severity: "broken", what: "the page scrolls sideways",
      detail: d.scrollWidth + "px of content in " + d.clientWidth + "px. Widest: " + guilty.join(", ") });
  }

  const nav = document.querySelector(".site-nav");
  if (nav) {
    const items = [...nav.querySelectorAll("a")];
    const open = getComputedStyle(nav).display !== "none" && nav.getBoundingClientRect().height > 0;
    if (open) {
      const offscreen = items.filter(a => {
        const r = a.getBoundingClientRect();
        return r.bottom > innerHeight + 1 || r.top < -1;
      });
      if (offscreen.length) {
        findings.push({ severity: "broken", what: offscreen.length + " menu items cannot be reached",
          detail: "the menu is " + Math.round(nav.getBoundingClientRect().height) + "px in a " +
                  innerHeight + "px window, and it does not scroll. Unreachable: " +
                  offscreen.slice(0, 4).map(a => a.textContent.trim()).join(", ") });
      }
    }
  }

  const tiny = [...document.querySelectorAll("p, li, span, a")]
    .filter(el => el.textContent.trim() && parseFloat(getComputedStyle(el).fontSize) < 12);
  if (tiny.length) {
    findings.push({ severity: "suggestion", what: tiny.length + " pieces of text are under 12px",
      detail: "hard to read on a phone" });
  }

  const overlapping = [];
  const blocks = [...document.querySelectorAll(".b")];
  for (let i = 0; i < blocks.length - 1; i++) {
    const a = blocks[i].getBoundingClientRect(), b = blocks[i + 1].getBoundingClientRect();
    if (a.height && b.height && a.bottom > b.top + 4 && a.left < b.right && b.left < a.right) {
      overlapping.push(blocks[i].className.split(" ").slice(0, 2).join("."));
    }
  }
  if (overlapping.length) {
    findings.push({ severity: "broken", what: "content overlaps",
      detail: overlapping.slice(0, 3).join(", ") });
  }

  return { findings,
           height: d.scrollHeight,
           blocks: document.querySelectorAll(".b").length,
           text: document.body.innerText.trim().length };
})()`;

const clickExpr = (sel) => `(() => {
  const el = document.querySelector(${JSON.stringify(sel)});
  if (!el || getComputedStyle(el).display === "none") return false;
  el.click();
  return true;
})()`;

// Promises are JavaScript returning { pass, message }. They run inside the page,
// so the browser is the sandbox: they cannot reach the server, the database or
// the filesystem. Each gets a time budget of its own so one bad loop cannot hang
// the rest.
const promiseExpr = (list) => `(() => {
  const results = [];
  for (const p of ${JSON.stringify(list)}) {
    const started = Date.now();
    try {
      const fn = new Function(p.script);
      const out = fn();
      results.push({
        id: p.id, summary: p.summary,
        pass: !!(out && out.pass),
        message: (out && out.message) || "",
        ms: Date.now() - started,
      });
    } catch (e) {
      results.push({ id: p.id, summary: p.summary, pass: false,
                     message: "the check itself failed: " + e.message, broken: true });
    }
  }
  return results;
})()`;

const result = { url: URL_ARG, widths: {} };

try {
  const ws = new WebSocket(await endpoint());
  await new Promise((r) => ws.addEventListener("open", r));
  const send = client(ws);

  const targets = (await send("Target.getTargets")).targetInfos;
  const page = targets.find((t) => t.type === "page");
  const { sessionId } = await send("Target.attachToTarget", { targetId: page.targetId, flatten: true });
  await send("Page.enable", {}, sessionId);
  await send("Runtime.enable", {}, sessionId);
  if (SHOTS) mkdirSync(OUT, { recursive: true });

  for (const w of WIDTHS) {
    await send("Emulation.setDeviceMetricsOverride", {
      width: w.width, height: w.height, deviceScaleFactor: 1,
      mobile: w.name === "phone",
    }, sessionId);
    await send("Page.navigate", { url: URL_ARG }, sessionId);
    await sleep(900);

    const { result: r } = await send("Runtime.evaluate",
      { expression: INSPECT, returnByValue: true }, sessionId);
    result.widths[w.name] = r.value;

    // A closed menu hides its own bugs. The original fault on this site -- 790px
    // of menu in a 611px window with no way to scroll -- only appeared once you
    // TAPPED the button, so a page-load check (or a screenshot) would have
    // missed it entirely. Open it and look again, as a person would.
    const selector = CLICK || (w.name === "phone" ? ".site-header__toggle" : null);
    if (selector) {
      const { result: opened } = await send("Runtime.evaluate",
        { expression: clickExpr(selector), returnByValue: true }, sessionId);
      if (opened.value) {
        await sleep(400);
        const { result: after } = await send("Runtime.evaluate",
          { expression: INSPECT, returnByValue: true }, sessionId);
        const label = CLICK ? ` (after clicking ${CLICK})` : " (with the menu open)";
        const extra = (after.value.findings || []).map(f => ({ ...f, what: f.what + label }));
        result.widths[w.name].findings.push(...extra);
        result.widths[w.name].clicked = selector;
      }
    }

    // Promises are evaluated at desktop width unless they say otherwise; a
    // promise about a phone can measure innerWidth for itself.
    if (PROMISES && w.name === "desktop") {
      const list = JSON.parse(PROMISES);
      if (list.length) {
        const { result: pr } = await send("Runtime.evaluate",
          { expression: promiseExpr(list), returnByValue: true, timeout: 10000 }, sessionId);
        result.promises = pr.value || [];
      }
    }

    if (SHOTS) {
      const shot = await send("Page.captureScreenshot",
        { format: "png", captureBeyondViewport: true }, sessionId);
      const path = join(OUT, `${w.name}.png`);
      writeFileSync(path, Buffer.from(shot.data, "base64"));
      result.widths[w.name].screenshot = path;
    }
  }
  ws.close();
} catch (e) {
  result.error = e.message;
} finally {
  chrome.kill();
}

console.log(JSON.stringify(result, null, 2));
