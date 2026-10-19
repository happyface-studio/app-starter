// Renders the city preview headlessly. Usage: node shoot.js <view> <out.png> [w h]
const { chromium } = require("/opt/npm-tools/node_modules/playwright");
const http = require("http");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "city");
const VENDOR = path.join(__dirname, "vendor/node_modules/three");
const types = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".glb": "model/gltf-binary", ".png": "image/png" };

const server = http.createServer((req, res) => {
  const u = decodeURIComponent(req.url.split("?")[0]);
  const f = path.join(ROOT, u === "/" ? "index.html" : u);
  fs.readFile(f, (e, d) => {
    if (e) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { "content-type": types[path.extname(f)] || "application/octet-stream" });
    res.end(d);
  });
}).listen(0, async () => {
  const port = server.address().port;
  const [view = "roemer", out = "shot.png", extra = "", w = "430", h = "932"] = process.argv.slice(2);
  const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
  const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1.5 });
  page.on("console", (m) => { if (m.type() === "error" || m.type() === "warning") console.log("[page]", m.text()); });
  page.on("pageerror", (e) => console.log("[pageerror]", e.message));
  await page.route("https://cdn.jsdelivr.net/npm/three@0.169.0/**", (route) => {
    const rel = route.request().url().split("three@0.169.0/")[1];
    route.fulfill({ path: path.join(VENDOR, rel), contentType: "text/javascript" });
  });
  await page.route("https://fonts.googleapis.com/**", (r) => r.fulfill({ body: "", contentType: "text/css" }));
  await page.goto(`http://localhost:${port}/?view=${view}&still=1${extra}`);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 180000 });
  await page.waitForFunction(() => window.__done === true, null, { timeout: 240000 });
  if (process.env.DBG) console.log(await page.evaluate(process.env.DBG));
  await page.screenshot({ path: out, timeout: 120000 });
  await browser.close();
  server.close();
  console.log("saved", out);
});
