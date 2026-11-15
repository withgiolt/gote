// Headless Chrome check of every page.
//   BASE=http://127.0.0.1:8000 RUNTIME=beam node test/browser.mjs
//   BASE=http://127.0.0.1:3000 RUNTIME=afterglow node test/browser.mjs
// CHROME points at the browser (default /usr/bin/google-chrome).
//
// Hydration: the bundle request is held back, every server-rendered node in
// the hydrated roots is tagged, then the bundle is let through. After
// hydration every tagged node must still be in the page and no node may have
// been added or removed.
import puppeteer from "puppeteer-core";

const BASE = process.env.BASE ?? "http://127.0.0.1:8000";
const RUNTIME = process.env.RUNTIME ?? "beam";
const results = [];
const record = (name, ok, detail = "") => {
  results.push({ name, ok, detail });
  console.log(`${ok ? "PASS" : "FAIL"} ${name}${detail ? ` (${detail})` : ""}`);
};

const browser = await puppeteer.launch({
  executablePath: process.env.CHROME ?? "/usr/bin/google-chrome",
  args: ["--no-sandbox"],
});

async function open(path, { holdBundle = false } = {}) {
  const page = await browser.newPage();
  const problems = [];
  page.on("console", (m) => { if (m.type() === "error" || m.type() === "warn") problems.push(`${m.type()}: ${m.text()}`); });
  page.on("pageerror", (e) => problems.push(`pageerror: ${e.message}`));
  page.on("requestfailed", (r) => { if (!r.url().includes("/assets/client.") || !holdBundle) problems.push(`failed: ${r.url()}`); });
  page.on("response", (r) => { if (r.status() >= 400) problems.push(`${r.status()}: ${r.url()}`); });
  let release = null;
  if (holdBundle) {
    await page.setRequestInterception(true);
    const held = [];
    page.on("request", (r) => (r.url().includes("/assets/client.") && !release ? held.push(r) : r.continue()));
    release = async () => { for (const r of held) await r.continue(); };
  }
  await page.goto(BASE + path, { waitUntil: holdBundle ? "domcontentloaded" : "load" });
  return { page, problems, release };
}

async function hydrationCheck(path, roots) {
  const { page, problems, release } = await open(path, { holdBundle: true });
  const tagged = await page.evaluate((roots) => {
    window.__mutations = [];
    let n = 0;
    for (const sel of roots) {
      const root = document.querySelector(sel);
      if (!root) throw new Error(`no ${sel}`);
      for (const node of [root, ...root.querySelectorAll("*")]) { node.__ssr = true; n++; }
      new MutationObserver((list) => {
        for (const m of list) if (m.type === "childList" && (m.addedNodes.length || m.removedNodes.length)) {
          window.__mutations.push(`${m.target.nodeName}: +${m.addedNodes.length} -${m.removedNodes.length}`);
        }
      }).observe(root, { childList: true, subtree: true });
    }
    window.__tagged = roots.flatMap((sel) => { const r = document.querySelector(sel); return [r, ...r.querySelectorAll("*")]; });
    return n;
  }, roots);
  await release();
  await page.waitForFunction(
    (count) => document.querySelectorAll('[data-hydrated="yes"]').length >= count,
    { timeout: 10000 },
    roots.length,
  ).catch(() => {});
  const hydrated = await page.evaluate(() => document.querySelectorAll('[data-hydrated="yes"]').length);
  const after = await page.evaluate((roots) => {
    const gone = window.__tagged.filter((n) => !n.isConnected).length;
    const fresh = roots.flatMap((sel) => { const r = document.querySelector(sel); return [r, ...r.querySelectorAll("*")]; }).filter((n) => !n.__ssr).length;
    return { gone, fresh, mutations: window.__mutations };
  }, roots);
  record(`${path}: ${roots.length} root(s) hydrated`, hydrated >= roots.length, `${hydrated} badge(s) say hydrated`);
  record(
    `${path}: hydration reused all ${tagged} server nodes`,
    after.gone === 0 && after.fresh === 0 && after.mutations.length === 0,
    `replaced ${after.gone}, new ${after.fresh}, child-list mutations ${after.mutations.length}${after.mutations.length ? ": " + after.mutations.slice(0, 3).join("; ") : ""}`,
  );
  return { page, problems };
}

const text = (page, sel) => page.$eval(sel, (el) => el.textContent.trim());
// Lustre renders on the next frame, so wait for the text instead of reading it once.
const waitText = (page, sel, want) =>
  page.waitForFunction((sel, want) => document.querySelector(sel)?.textContent.trim() === want, { timeout: 3000 }, sel, want)
    .then(() => want, () => text(page, sel));
const noProblems = (path, problems) => record(`${path}: no console errors or failed requests`, problems.length === 0, problems.slice(0, 4).join(" | "));

// Plain server pages.
for (const path of ["/", "/ssr", "/prerendered.html"]) {
  const { page, problems } = await open(path);
  const scripts = await page.$$eval("script[src]", (s) => s.length);
  const h1 = await text(page, "h1");
  const sources = await page.$$eval(".sources a", (a) => a.map((x) => x.href));
  record(`${path}: renders "${h1}", loads ${scripts} scripts`, scripts === 0 && h1.length > 0);
  record(`${path}: source links point at main`, sources.length > 0 && sources.every((h) => h.startsWith("https://github.com/withgiolt/gote/blob/main/examples/fullstack/")), `${sources.length} links`);
  if (path === "/ssr") {
    const rows = await page.$$eval(".squares tbody tr", (r) => r.map((x) => x.textContent));
    record("/ssr: 8 squares from 8 spawned processes", rows.length === 8 && rows[7].startsWith("864"), rows[7]);
  }
  noProblems(path, problems);
  await page.close();
}

// Full-page app.
{
  const { page, problems } = await hydrationCheck("/app", ["#app"]);
  const label3 = await text(page, 'label[for="todo-3"]');
  const bold = await page.$$eval("#app b", (b) => b.length);
  record("/app: embedded </script> text survives, no injected <b>", label3.includes("</script><b>this</b>") && bold === 0);
  await page.type('input[name="title"]', "Ship it");
  await page.click(".add button");
  await page.waitForFunction(() => document.querySelectorAll(".todos li").length === 4);
  await page.click("#todo-2");
  await waitText(page, ".left", "2 left");
  await page.click(".todos li:nth-child(1) .remove");
  await page.waitForFunction(() => document.querySelectorAll(".todos li").length === 3, { timeout: 3000 }).catch(() => {});
  const left = await text(page, ".left");
  const items = await page.$$eval(".todos li label", (l) => l.map((x) => x.textContent));
  record("/app: add, check and remove work", left === "2 left" && items.length === 3 && items[2] === "Ship it", `${left}; ${items.join(" / ")}`);
  // Navigation from inside the hydrated app.
  await Promise.all([page.waitForNavigation(), page.click('.site-nav a[href="/islands"]')]);
  await page.waitForFunction(() => document.querySelectorAll('[data-hydrated="yes"]').length === 2, { timeout: 10000 }).catch(() => {});
  const there = await page.evaluate(() => [location.pathname, document.querySelectorAll('[data-hydrated="yes"]').length]);
  record("/app: nav link works after hydration and the next page hydrates", there[0] === "/islands" && there[1] === 2, there.join(" "));
  await Promise.all([page.waitForNavigation(), page.click('.site-nav a[href="/app"]')]);
  await page.waitForSelector('#app [data-hydrated="yes"]', { timeout: 10000 }).catch(() => {});
  record("/islands -> /app back via nav works", (await page.evaluate(() => location.pathname)) === "/app");
  noProblems("/app", problems);
  await page.close();
}

// Islands.
{
  const { page, problems } = await hydrationCheck("/islands", ["#counter-1", "#converter-1"]);
  const before = await text(page, ".fahrenheit");
  record("/islands: float renders the same on Erlang and JS", before === "68.0 °F", before);
  await page.click(".counter .inc");
  await waitText(page, ".count", "4");
  await page.click(".counter .inc");
  await waitText(page, ".count", "5");
  await page.click(".counter .dec");
  const count = await waitText(page, ".count", "4");
  record("/islands: counter island works", count === "4", count);
  const input = await page.$(".converter input");
  await input.click({ clickCount: 3 });
  await input.type("-40");
  const f1 = await waitText(page, ".fahrenheit", "-40.0 °F");
  await input.click({ clickCount: 3 });
  await input.type("36.6");
  const f2 = await waitText(page, ".fahrenheit", "97.9 °F");
  record("/islands: converter island works", f1 === "-40.0 °F" && f2 === "97.9 °F", `${f1}, ${f2}`);
  noProblems("/islands", problems);
  await page.close();
}

// Data page.
{
  const { page, problems } = await hydrationCheck("/data", ["#stats-1"]);
  const pidBefore = await page.$eval(".stats tr:nth-child(5) td:nth-child(2)", (td) => td.textContent);
  await page.click(".refresh");
  await page.waitForFunction(() => document.querySelector(".fetches").textContent === "fetched 1 times", { timeout: 5000 }).catch(() => {});
  const fetches = await text(page, ".fetches");
  const pidAfter = await page.$eval(".stats tr:nth-child(5) td:nth-child(2)", (td) => td.textContent);
  record("/data: refresh fetches /api/stats.json and re-renders", fetches === "fetched 1 times", `${fetches}; pid ${pidBefore} -> ${pidAfter}`);
  noProblems("/data", problems);
  await page.close();
}

// Server component.
{
  const { page, problems } = await open("/live");
  if (RUNTIME === "beam") {
    const sockets = [];
    page.on("framenavigated", () => {});
    const client = await page.createCDPSession();
    await client.send("Network.enable");
    client.on("Network.webSocketCreated", (e) => sockets.push(e.url));
    await page.reload({ waitUntil: "load" });
    const read = (sel) => page.evaluate((sel) => document.querySelector("lustre-server-component")?.shadowRoot?.querySelector(sel)?.textContent ?? null, sel);
    await page.waitForFunction(() => document.querySelector("lustre-server-component")?.shadowRoot?.querySelector(".clock"), { timeout: 10000 }).catch(() => {});
    const clock1 = await read(".clock");
    await new Promise((r) => setTimeout(r, 2200));
    const clock2 = await read(".clock");
    await page.evaluate(() => document.querySelector("lustre-server-component").shadowRoot.querySelector(".inc").click());
    await page.evaluate(() => document.querySelector("lustre-server-component").shadowRoot.querySelector(".inc").click());
    await new Promise((r) => setTimeout(r, 500));
    const clicks = await read(".clicks");
    const pid = await read(".pid");
    record("/live: server component connected over a WebSocket", sockets.some((u) => new URL(u).pathname === "/live/ws") && clock1 !== null, sockets.join(", "));
    record("/live: server clock ticks", clock1 !== clock2, `${clock1} -> ${clock2}`);
    record("/live: clicks handled on the server", clicks === "2", `clicks ${clicks}, component ${pid}`);
  } else {
    const note = await page.$eval(".unsupported", (el) => el.textContent).catch(() => "");
    const element = await page.$("lustre-server-component");
    record("/live: afterglow page explains the server component is unavailable", note.includes("Not available on afterglow") && !element);
    noProblems("/live", problems);
    const ws = await page.evaluate(async () => (await fetch("/live/ws")).status);
    record("/live/ws on afterglow answers 501", ws === 501, String(ws));
  }
  if (RUNTIME === "beam") noProblems("/live", problems);
  await page.close();
}

// A page from another build: the bundle must refuse to hydrate it.
{
  const page = await browser.newPage();
  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.setRequestInterception(true);
  page.on("request", async (r) => {
    if (new URL(r.url()).pathname !== "/islands") return r.continue();
    const res = await fetch(r.url());
    const body = (await res.text()).replace(/data-build="[^"]+"/, 'data-build="000000000000"');
    r.respond({ status: 200, contentType: "text/html; charset=utf-8", body });
  });
  await page.goto(BASE + "/islands", { waitUntil: "load" });
  await new Promise((r) => setTimeout(r, 800));
  const hydrated = await page.evaluate(() => document.querySelectorAll('[data-hydrated="yes"]').length);
  record(
    "mismatched build id: bundle refuses to hydrate and says why",
    hydrated === 0 && errors.some((e) => e.includes("not hydrating")),
    errors.find((e) => e.includes("not hydrating")) ?? errors.join(" | "),
  );
  await page.close();
}

// API and 404.
{
  const { page, problems } = await open("/api/stats.json");
  const body = JSON.parse(await page.evaluate(() => document.body.innerText));
  record("/api/stats.json returns the stats", typeof body.schedulers === "number" && body.worker_sum === 108, JSON.stringify(body));
  noProblems("/api/stats.json", problems);
  await page.close();
  const missing = await browser.newPage();
  const res = await missing.goto(BASE + "/nope");
  record("/nope: 404 page", res.status() === 404);
  await missing.close();
}

await browser.close();
const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} passed on ${RUNTIME} at ${BASE}`);
process.exit(failed.length ? 1 : 0);
