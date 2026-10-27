// Check a page that is behind the login: sign in in the browser, then look.
import { spawn } from "node:child_process";
import { readFileSync } from "node:fs";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome Beta";
const [URL_ARG, EMAIL, PASSWORD, CHECKS_FILE] = process.argv.slice(2);
const checks = JSON.parse(readFileSync(CHECKS_FILE, "utf8"));
const PORT = 9333;

const chrome = spawn(CHROME, ["--headless", "--disable-gpu", "--no-sandbox",
  `--remote-debugging-port=${PORT}`, "--user-data-dir=/tmp/sjoca-admin-profile", "about:blank"],
  { stdio: "ignore" });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const endpoint = async () => {
  for (let i = 0; i < 40; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      return (await r.json()).webSocketDebuggerUrl;
    } catch { await sleep(250); }
  }
  throw new Error("chrome never answered");
};

let id = 0;
const pending = new Map();
const ws = new WebSocket(await endpoint());
await new Promise((r) => (ws.onopen = r));
ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); }
};
const send = (method, params = {}, sessionId) => new Promise((resolve) => {
  const n = ++id;
  pending.set(n, (m) => resolve(m.result || {}));
  ws.send(JSON.stringify({ id: n, method, params, sessionId }));
});

const { targetInfos } = await send("Target.getTargets");
const page = targetInfos.find((t) => t.type === "page");
const { sessionId } = await send("Target.attachToTarget", { targetId: page.targetId, flatten: true });
await send("Page.enable", {}, sessionId);
await send("Runtime.enable", {}, sessionId);

const go = async (url, wait = 1200) => { await send("Page.navigate", { url }, sessionId); await sleep(wait); };
const run = async (expr) => (await send("Runtime.evaluate",
  { expression: expr, returnByValue: true, awaitPromise: true }, sessionId)).result;

const base = new URL(URL_ARG).origin;
await go(`${base}/admin/login`);
await run(`(() => {
  document.querySelector('#session_email').value = ${JSON.stringify(EMAIL)};
  document.querySelector('#session_password').value = ${JSON.stringify(PASSWORD)};
  document.querySelector('form').submit();
  return true;
})()`);
await sleep(1500);
await go(URL_ARG, 1800);

const where = await run("location.pathname");
if (String(where.value).includes("login")) {
  console.log(JSON.stringify([{ pass: false, summary: "signing in", message: "still on the login page" }]));
  ws.close(); chrome.kill(); process.exit(0);
}

const results = [];
for (const c of checks) {
  const out = await run(`(() => { try { ${c.script} } catch (e) { return {pass:false, message:'threw: '+e.message}; } })()`);
  results.push({ summary: c.summary, ...(out.value || { pass: false, message: "no result" }) });
}
console.log(JSON.stringify(results));
ws.close(); chrome.kill();
