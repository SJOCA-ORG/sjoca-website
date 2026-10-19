#!/usr/bin/env node
// Prints a bulletin to PDF, over the same CDP connection that already drives
// the layout checks. No wkhtmltopdf, no Prawn, no new dependency -- the
// browser that renders the page is the one that prints it, so what comes out
// is what was on screen.
//
//   node script/bulletin_pdf.mjs <url> <out.pdf>
//
// 5.5 x 8.5 pages in reading order, no margins. The printer imposes them.
import { spawn } from "node:child_process";
import { existsSync, writeFileSync } from "node:fs";

const URL_ARG = process.argv[2];
const OUT = process.argv[3];
if (!URL_ARG || !OUT) { console.error("usage: bulletin_pdf.mjs <url> <out.pdf>"); process.exit(1); }

const CHROME = process.env.CHROME || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/usr/bin/chromium", "/usr/bin/chromium-browser", "/usr/bin/google-chrome",
].find(existsSync);

if (!CHROME) {
  console.log(JSON.stringify({ error: "no Chrome found; set CHROME=/path/to/chrome" }));
  process.exit(0);
}

const PORT = 9446;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const chrome = spawn(CHROME, [
  "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
  `--remote-debugging-port=${PORT}`, "--user-data-dir=/tmp/sjoca-pdf-profile", "about:blank",
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

const result = { url: URL_ARG, out: OUT };
try {
  const ws = new WebSocket(await endpoint());
  await new Promise((r) => ws.addEventListener("open", r));
  let id = 0;
  const pending = new Map();
  ws.addEventListener("message", (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  });
  const send = (method, params = {}, sessionId) => new Promise((res, rej) => {
    const mid = ++id;
    pending.set(mid, (m) => (m.error ? rej(new Error(m.error.message)) : res(m.result)));
    ws.send(JSON.stringify({ id: mid, method, params, sessionId }));
  });

  const target = (await send("Target.getTargets")).targetInfos.find((t) => t.type === "page");
  const { sessionId } = await send("Target.attachToTarget", { targetId: target.targetId, flatten: true });
  await send("Page.enable", {}, sessionId);
  await send("Runtime.enable", {}, sessionId);

  await send("Page.navigate", { url: URL_ARG }, sessionId);
  await sleep(1200);

  // Photographs have to have arrived, or the PDF prints the gaps where they
  // were going to be.
  const { result: ready } = await send("Runtime.evaluate", {
    expression: `(async () => {
      await Promise.all([...document.images]
        .filter(i => !i.complete)
        .map(i => new Promise(r => { i.onload = i.onerror = r; })));
      return document.querySelectorAll(".sheet").length;
    })()`,
    awaitPromise: true, returnByValue: true,
  }, sessionId);
  result.sheets = ready.value;

  const pdf = await send("Page.printToPDF", {
    paperWidth: 5.5, paperHeight: 8.5,
    marginTop: 0, marginBottom: 0, marginLeft: 0, marginRight: 0,
    printBackground: true, preferCSSPageSize: true,
  }, sessionId);

  writeFileSync(OUT, Buffer.from(pdf.data, "base64"));
  ws.close();
} catch (e) {
  result.error = e.message;
} finally {
  chrome.kill();
}

console.log(JSON.stringify(result));
