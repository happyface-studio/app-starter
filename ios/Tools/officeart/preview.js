// Browser preview of the office. Mirrors render.py and the Swift OfficeScene:
// same manifest, same depth rule (sort by bottom edge), same character layers.
(async () => {
  const M = OFFICE;
  const S = M.sprites;
  const C = M.characters;
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const images = {};
  await Promise.all(Object.entries(IMAGES).map(([name, uri]) => new Promise((resolve) => {
    const im = new Image();
    im.onload = () => resolve();
    im.onerror = () => resolve();
    im.src = uri;
    images[name] = im;
  })));

  // ---------- desks (example data) ----------
  const desks = DESKS;
  const activity = desks.map(() => "idle");
  let selected = null;
  let live = null;

  // ---------- characters ----------
  const pick = (options, i) => options[Math.abs(i | 0) % options.length];
  function layersFor(look) {
    const names = [
      pick(C.bodies, look.skin), pick(C.eyes, look.eyes),
      pick(pick(C.outfits, look.shirt), look.shirt_color),
      pick(pick(C.hairs, look.hair), look.hair_color),
    ];
    if (look.accessory > 0 && C.accessories.length) names.push(pick(C.accessories, look.accessory - 1).file);
    return names;
  }
  const stripFrames = Math.max(...Object.values(C.anims).map((a) => a.start + (a.perDir ? a.perDir * a.dirs.length : a.count)));
  const stripCache = new Map();
  function strip(look) {
    const key = JSON.stringify(look);
    if (!stripCache.has(key)) {
      const cv = document.createElement("canvas");
      cv.width = stripFrames * C.frameW; cv.height = C.frameH;
      const c = cv.getContext("2d");
      for (const name of layersFor(look)) if (images[name]) c.drawImage(images[name], 0, 0);
      stripCache.set(key, cv);
    }
    return stripCache.get(key);
  }
  function frameIndex(anim, face, i) {
    const a = C.anims[anim];
    return a.perDir ? a.start + Math.max(0, a.dirs.indexOf(face)) * a.perDir + (i % a.perDir) : a.start + (i % a.count);
  }

  // ---------- drawing ----------
  const canvas = document.getElementById("office");
  canvas.width = M.scene.w; canvas.height = M.scene.h;
  const ctx = canvas.getContext("2d");
  ctx.imageSmoothingEnabled = false;
  const atlas = images[M.atlas];

  function spriteAt(name, t, frame) {
    const s = S[name];
    const n = s.frames.length;
    const i = frame != null ? frame % n : (s.fps ? Math.floor(t * s.fps) % n : 0);
    return { s, f: s.frames[i] || s.frames[0] };
  }
  function drawSprite(c, name, x, y, t, frame) {
    const { s, f } = spriteAt(name, t, frame);
    c.drawImage(atlas, f[0], f[1], s.w, s.h, Math.round(x + s.dx), Math.round(y + s.dy), s.w, s.h);
  }

  const plateCache = new Map();
  function plate(text, dim) {
    const key = text + dim;
    if (plateCache.has(key)) return plateCache.get(key);
    let t = [...text.toUpperCase()].map((ch) => M.fold[ch] || ch).filter((ch) => M.font[ch]).join("").trim().slice(0, 8) || "?";
    const tw = t.length * 4 - 1, w = Math.max(17, tw + 6);
    const cv = document.createElement("canvas"); cv.width = w; cv.height = 9;
    const c = cv.getContext("2d");
    c.fillStyle = "#3A3A50"; c.fillRect(0, 0, w, 9);
    c.fillStyle = dim ? "#A88536" : "#E0BC62"; c.fillRect(1, 1, w - 2, 7);
    if (!dim) { c.fillStyle = "#F2D98C"; c.fillRect(1, 1, w - 2, 1); }
    c.fillStyle = dim ? "#6E521C" : "#4A3518";
    const ox = Math.floor((w - tw) / 2);
    [...t].forEach((ch, i) => M.font[ch].forEach((row, gy) => [...row].forEach((p, gx) => { if (p === "#") c.fillRect(ox + i * 4 + gx, 2 + gy, 1, 1); })));
    plateCache.set(key, cv);
    return cv;
  }

  // ---------- people walking around ----------
  // Deskmates take breaks at the staff places; visitors check in at reception and wait on the couch.
  // Each place takes one person at a time.
  const taken = new Set();
  const staffPlaces = Object.keys(M.pois).filter((k) => M.pois[k].who === "staff");
  const free = (names) => names.filter((n) => !taken.has(n));
  const pickFree = (names) => { const f = free(names); return f.length ? f[Math.floor(Math.random() * f.length)] : null; };

  const agents = desks.map((d, seat) => {
    const st = M.stations[seat];
    return { seat, x: st.feet.x, y: st.feet.y, face: "down", mode: "seated", path: null, seg: 0, place: null,
      wait: 4 + seat * 3 + Math.random() * 8, walkT: 0, phoneSince: null };
  });
  const busy = (a) => activity[a.seat] !== "idle";

  function startPath(w, path, mode) { w.path = path; w.seg = 1; w.mode = mode; }
  /** Moves along the path; returns true once at the end. */
  function walk(w, dt, speed) {
    let step = speed * dt;
    while (step > 0 && w.seg < w.path.length) {
      const [tx, ty] = w.path[w.seg];
      const dx = tx - w.x, dy = ty - w.y, d = Math.hypot(dx, dy);
      if (d > 0.01) w.face = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "down" : "up");
      if (d <= step) { w.x = tx; w.y = ty; w.seg++; step -= d; } else { w.x += dx / d * step; w.y += dy / d * step; step = 0; }
    }
    w.walkT += dt * (speed / 30);
    return w.seg >= w.path.length;
  }
  function sendOnBreak(a) {
    const place = pickFree(staffPlaces);
    if (!desks[a.seat] || a.mode !== "seated" || busy(a) || !place) return false;
    a.place = place; taken.add(place);
    startPath(a, M.stations[a.seat].paths[place], "walking");
    return true;
  }
  function backToDesk(a) {
    startPath(a, a.mode === "walking" ? [[a.x, a.y], ...a.path.slice(0, a.seg).reverse()] : [...a.path].reverse(), "returning");
  }
  function updateAgent(a, dt) {
    if (!desks[a.seat]) return;
    if (a.mode === "seated") {
      if (!busy(a) && !reduceMotion) {
        a.wait -= dt;
        if (a.wait <= 0) sendOnBreak(a) || (a.wait = 5);
      }
      return;
    }
    if (a.mode === "atPlace") {
      a.wait -= dt;
      if (a.wait <= 0 || busy(a)) backToDesk(a);
      return;
    }
    if (a.mode === "walking" && busy(a)) backToDesk(a);
    if (!walk(a, dt, a.mode === "returning" && busy(a) ? 64 : 30)) return;
    if (a.mode === "walking") {
      a.mode = "atPlace"; a.face = M.pois[a.place].face;
      a.wait = (M.pois[a.place].pose ? 8 : 3) + Math.random() * 4;
    } else {
      taken.delete(a.place); a.place = null;
      a.mode = "seated"; a.face = "down"; a.wait = 10 + Math.random() * 14;
    }
  }
  const seated = (seat) => agents[seat].mode === "seated";

  const G = M.guests;
  const guests = [];
  let nextGuest = 6;
  function spawnGuest() {
    const seat = pickFree(G.seats);
    const deskBusy = guests.some((g) => g.mode === "arriving" || g.mode === "atDesk");
    if (!seat || guests.length >= 2 || deskBusy) return false;
    taken.add(seat);
    const look = GUEST_LOOKS[Math.floor(Math.random() * GUEST_LOOKS.length)];
    const [x, y] = G.arrive[0];
    guests.push({ look, x, y, face: "up", mode: "arriving", path: G.arrive, seg: 1, place: seat, wait: 0, walkT: 0 });
    return true;
  }
  function updateGuests(dt) {
    if (reduceMotion) return;
    nextGuest -= dt;
    if (nextGuest <= 0) { spawnGuest(); nextGuest = 22 + Math.random() * 25; }
    for (const g of guests) {
      if (g.mode === "atDesk" || g.mode === "waiting") {
        g.wait -= dt;
        if (g.wait > 0) continue;
        if (g.mode === "atDesk") startPath(g, G.toSeat[g.place], "toSeat");
        else startPath(g, G.leave[g.place], "leaving");
        continue;
      }
      if (!walk(g, dt, 26)) continue;
      if (g.mode === "arriving") { g.mode = "atDesk"; g.face = G.desk.face; g.wait = 2.5; }
      else if (g.mode === "toSeat") { g.mode = "waiting"; g.face = M.pois[g.place].face; g.wait = 10 + Math.random() * 8; }
      else { g.mode = "gone"; taken.delete(g.place); }
    }
    for (let i = guests.length - 1; i >= 0; i--) if (guests[i].mode === "gone") guests.splice(i, 1);
  }

  /** Draw order for someone at (x, y): a seat's own z while they're in it or stepping into it. */
  function depth(w) {
    const poi = w.place && M.pois[w.place];
    if (poi && poi.approach && Math.abs(w.x - poi.x) < 0.5 && w.y < poi.approach[1] - 0.01) return Math.max(poi.z, w.y);
    return w.y;
  }
  /** Frame for someone who isn't at their desk. */
  function awayFrame(w, t, arrived) {
    if (!arrived) return frameIndex("walk", w.face, Math.floor(w.walkT * 10));
    const pose = (w.place && M.pois[w.place].pose) || "idle";
    if (pose === "read") return frameIndex("read", null, Math.floor(t * 3));
    return frameIndex(pose, w.face, Math.floor(t * 5));
  }

  // ---------- one frame ----------
  const EMOTE = { ringing: "emote_ring", thinking: "emote_think", speaking: "emote_speak", human: "emote_boss" };
  function drawOffice(t) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(images[M.background], 0, 0);
    const items = [];
    const add = (z, fn) => items.push([z, fn]);
    for (const p of M.props) add(p.z, () => drawSprite(ctx, p.sprite, p.x, p.y, t));

    const desk = S[M.desk];
    M.stations.forEach((st, seat) => {
      const d = desks[seat], act = activity[seat], a = agents[seat];
      const base = st.desk.y + desk.h;
      add(base, () => drawSprite(ctx, M.desk, st.desk.x, st.desk.y, t));
      add(st.feet.y - 2, () => drawSprite(ctx, "chair", st.chair.x, st.chair.y, t));
      if (!d) {
        add(base + 1, () => drawSprite(ctx, "plant_small", st.desk.x + 12, st.desk.y - 8, t));
        const pl = plate("VACANT", true);
        add(base + 3, () => ctx.drawImage(pl, st.plate.cx - (pl.width >> 1), st.plate.y));
        return;
      }
      add(base + 1, () => drawSprite(ctx, "monitor_back", st.monitor.x, st.monitor.y, t));
      if (st.item) add(base + 1, () => drawSprite(ctx, st.item.name, st.item.x, st.item.y, t));
      if (d.line) {
        const ringOn = act === "ringing" && Math.floor(t * 10) % 10 < 6;
        const jig = ringOn ? (Math.floor(t * 12) % 2 ? 1 : -1) : 0;
        add(base + 2, () => {
          drawSprite(ctx, "phone_rotary", st.phone.x + jig, st.phone.y, t);
          if (ringOn) {
            ctx.fillStyle = "#F4B23E";
            for (const [rx, ry] of [[-3, 2], [-2, 3], [-3, 4], [18, 2], [17, 3], [18, 4]]) ctx.fillRect(st.phone.x + rx, st.phone.y + ry, 1, 1);
          }
        });
      }
      const pl = plate(d.name, false);
      add(base + 3, () => ctx.drawImage(pl, st.plate.cx - (pl.width >> 1), st.plate.y));

      const sh = strip(d.look);
      const cx = Math.round(a.x) - 8, cy = Math.round(a.y) - 31;
      if (a.mode === "seated") {
        let idx, idle = 0;
        if (act === "dialing") {
          a.phoneSince ??= t;
          const k = Math.floor((t - a.phoneSince) * 8);
          idx = frameIndex("phone", "down", k < 3 ? k : 3 + (k - 3) % 6);
        } else {
          a.phoneSince = null;
          idle = Math.floor(t * 5) % 6;
          idx = frameIndex("idle", "down", idle);
        }
        add(a.y, () => {
          ctx.drawImage(sh, idx * 16, 0, 16, 32, cx, cy, 16, 32);
          if (d.line && act !== "dialing") drawSprite(ctx, ["listening", "thinking", "speaking", "human"].includes(act) ? "headset_live" : "headset", cx, cy, t, idle);
        });
      } else {
        const idx = awayFrame(a, t, a.mode === "atPlace");
        add(depth(a), () => ctx.drawImage(sh, idx * 16, 0, 16, 32, cx, cy, 16, 32));
      }
      const emote = EMOTE[act];
      if (emote) {
        const s = S[emote];
        const bx = a.mode === "seated" ? st.bubble.x : cx + 14, by = a.mode === "seated" ? st.bubble.y : cy + 20;
        add(10000, () => drawSprite(ctx, emote, bx - s.dx, by - s.h - s.dy, t));
      }
    });
    for (const g of guests) {
      const idx = g.mode === "atDesk" ? frameIndex("idle", g.face, Math.floor(t * 5)) : awayFrame(g, t, g.mode === "waiting");
      const gx = Math.round(g.x) - 8, gy = Math.round(g.y) - 31;
      add(depth(g), () => ctx.drawImage(strip(g.look), idx * 16, 0, 16, 32, gx, gy, 16, 32));
    }
    items.sort((p, q) => p[0] - q[0]);
    for (const [, fn] of items) fn();
  }

  function drawPortrait(cv, seat, t) {
    const c = cv.getContext("2d");
    c.imageSmoothingEnabled = false;
    c.clearRect(0, 0, 20, 20);
    const d = desks[seat], act = activity[seat];
    const i = Math.floor(t * 5) % 6;
    const idx = act === "dialing" ? frameIndex("phone", "down", 3 + i) : frameIndex("idle", "down", i);
    c.drawImage(strip(d.look), idx * 16, 0, 16, 32, 2, -6, 16, 32);
    if (d.line && act !== "dialing") drawSprite(c, act === "idle" || act === "ringing" ? "headset" : "headset_live", 2, -6, t, i);
  }

  // ---------- seats (tap targets) ----------
  const W = M.scene.w, H = M.scene.h;
  const sceneEl = document.getElementById("scene");
  const seatButtons = M.stations.map((st, s) => {
    const btn = document.createElement("button");
    btn.type = "button"; btn.className = "seat";
    Object.assign(btn.style, {
      left: (st.tap.x / W * 100) + "%", top: (st.tap.y / H * 100) + "%",
      width: (st.tap.w / W * 100) + "%", height: (st.tap.h / H * 100) + "%",
    });
    btn.setAttribute("aria-label", desks[s] ? `${desks[s].name}'s desk` : "Empty desk");
    btn.setAttribute("aria-pressed", "false");
    btn.addEventListener("click", () => { lastSeatButton = btn; selected = s; renderNotes(); });
    sceneEl.appendChild(btn);
    return btn;
  });

  // ---------- hint, live call dock, desk sheet ----------
  const notes = document.getElementById("notes");
  const dock = document.getElementById("dock");
  const sheet = document.getElementById("sheet"), sheetBody = document.getElementById("sheet-body");
  const portraits = [];
  let lastSeatButton = null;
  document.getElementById("sheet-done").addEventListener("click", () => closeSheet());
  sheet.addEventListener("click", (e) => { if (e.target === sheet) closeSheet(); });
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !sheet.hidden) closeSheet(); });
  function closeSheet() { selected = null; renderNotes(); if (lastSeatButton) lastSeatButton.focus(); }
  function el(tag, cls, text) { const e = document.createElement(tag); if (cls) e.className = cls; if (text != null) e.textContent = text; return e; }

  function renderNotes() {
    seatButtons.forEach((b, i) => b.setAttribute("aria-pressed", String(selected === i)));
    notes.textContent = ""; dock.textContent = ""; portraits.length = 0;
    if (!live) notes.append(el("p", "hint", "Quiet for now. When someone calls one of your numbers, you'll see the phone ring. Tap a desk to see who sits there."));
    if (live) {
      const row = el("div", "callrow");
      const cv = el("canvas"); cv.width = 20; cv.height = 20; portraits.push({ cv, seat: live.seat });
      const mid = el("div"); mid.style.minWidth = "0";
      mid.append(el("div", "who", live.headline), el("div", "last", live.last || "Connecting…"));
      const btn = el("button", "pill", live.human ? "On the line" : "Jump in");
      btn.type = "button"; btn.disabled = !!live.human || !live.connected;
      btn.addEventListener("click", () => jumpIn());
      row.append(cv, mid, btn); dock.append(row);
    }
    sheet.hidden = selected === null;
    sheetBody.textContent = "";
    if (selected !== null) {
      const d = desks[selected];
      const card = el("article", "deskcard");
      if (!d) {
        card.append(el("h3", null, "Empty desk"), el("p", "brief", "In the app, tapping here hires a new deskmate. You pick a name, a voice and a look, then write their job in plain words."));
        card.firstChild.id = "sheet-title";
      } else {
        const head = el("header");
        const cv = el("canvas"); cv.width = 20; cv.height = 20; portraits.push({ cv, seat: selected });
        const names = el("div"); const h = el("h3", null, d.name); h.id = "sheet-title";
        names.append(h, el("p", "role", d.role));
        head.append(cv, names);
        card.append(head, el("div", "number", d.lineLabel || "No number"), el("p", "meta", d.lineNote), el("p", "brief", d.brief));
      }
      sheetBody.append(card);
      document.getElementById("sheet-done").focus();
    }
  }

  // ---------- scripted calls ----------
  const log = document.getElementById("log");
  const playIn = document.getElementById("play-in"), playOut = document.getElementById("play-out");
  const jump = document.getElementById("jump"), wander = document.getElementById("wander");
  let timers = [];
  const later = (ms, fn) => timers.push(setTimeout(fn, reduceMotion ? Math.min(ms, 400) : ms));
  function clearTimers() { timers.forEach((id) => { clearTimeout(id); clearInterval(id); }); timers = []; }

  function addLine(cls, who, text) {
    const b = el("div", "bubble " + cls);
    if (who) b.append(el("b", null, who));
    b.append(document.createTextNode(text));
    log.append(b); log.scrollTop = log.scrollHeight;
    if (live && cls !== "sys") { live.last = cls === "agent" ? text : `“${text}”`; renderNotes(); }
  }

  // The phone rings (or Paula dials) until the deskmate is back in their chair, then the script plays.
  function run(seat, startAct, headline, steps) {
    clearTimers();
    activity.fill("idle"); log.textContent = "";
    live = { seat, headline, last: "", human: false, connected: false };
    selected = null;
    playIn.disabled = playOut.disabled = true; jump.disabled = true;
    activity[seat] = startAct; renderNotes();
    if (!seated(seat)) addLine("sys", null, `${desks[seat].name} is away from the desk and hurries back.`);
    const poll = setInterval(() => {
      if (!seated(seat)) return;
      clearInterval(poll);
      let at = 0;
      for (const [delay, fn] of steps) { at += delay; later(at, fn); }
    }, 100);
    timers.push(poll);
  }
  const connected = () => { live.connected = true; jump.disabled = false; renderNotes(); };
  function say(seat, who, text, ms) {
    return [[0, () => { activity[seat] = "thinking"; }], [700, () => { activity[seat] = "speaking"; addLine("agent", who, text); }], [ms, () => { activity[seat] = "listening"; }]];
  }
  function hear(seat, who, text, ms) {
    return [[0, () => { activity[seat] = "listening"; addLine("them", who, text); }], [ms, () => {}]];
  }
  function finish(seat, sys) {
    return [[600, () => { addLine("sys", null, sys); activity[seat] = "idle"; live = null; playIn.disabled = playOut.disabled = false; jump.disabled = true; renderNotes(); }]];
  }

  playIn.addEventListener("click", () => {
    run(1, "ringing", "Otto's phone is ringing", [
      [1400, () => { addLine("sys", null, "Otto picked up"); live.headline = "Otto is talking to +49 151 2234 8810"; connected(); }],
      ...say(1, "Otto", "Kiez Bikes, this is Otto. How can I help?", 1600),
      ...hear(1, "Caller", "Hi, I dropped off a blue city bike on Tuesday. Is it ready?", 1500),
      ...say(1, "Otto", "I can't see repair status, but I'll get a message to the team. Can I have your name?", 2400),
      ...hear(1, "Caller", "Jana Weber. Same number I'm calling from.", 1400),
      ...say(1, "Otto", "Thanks Jana. Message for the team: blue city bike from Tuesday, please call back. Anything else?", 2600),
      ...hear(1, "Caller", "No, that's it. Thanks!", 1100),
      ...say(1, "Otto", "Have a good day. Bye!", 1300),
      ...finish(1, "Call ended. Message saved and sent to your phone."),
    ]);
  });

  playOut.addEventListener("click", () => {
    run(0, "dialing", "Paula is dialing +49 69 9130 4471", [
      [2400, () => { addLine("sys", null, "Trattoria Rosa answered"); live.headline = "Paula called +49 69 9130 4471"; activity[0] = "listening"; connected(); }],
      ...hear(0, "Restaurant", "Trattoria Rosa, buonasera!", 1200),
      ...say(0, "Paula", "Hi, this is Paula calling for Simon. Could I book a table for four this Friday at 8pm?", 2600),
      ...hear(0, "Restaurant", "Friday at eight… yes, we have a table inside. The terrace is closed in October.", 1900),
      ...say(0, "Paula", "Inside is perfect. The name is Weber. Friday, eight o'clock, four people.", 2400),
      ...hear(0, "Restaurant", "Perfect, see you Friday.", 1100),
      ...say(0, "Paula", "Thank you, bye!", 1100),
      ...finish(0, "Call ended. Booked: Friday 8pm, 4 people, name Weber."),
    ]);
  });

  wander.addEventListener("click", () => {
    agents.forEach((a, i) => { if (a.mode === "seated") { a.wait = 0.2 + i * 0.5; } });
  });
  document.getElementById("visitor").addEventListener("click", () => { spawnGuest(); });

  function jumpIn() {
    if (!live || live.human || !live.connected) return;
    const seat = live.seat, d = desks[seat];
    clearTimers();
    activity[seat] = "speaking";
    addLine("agent", d.name, "One moment, I'm putting you through now.");
    later(1400, () => {
      activity[seat] = "human"; live.human = true; live.headline = "You're on the line"; jump.disabled = true;
      addLine("sys", null, `You jumped in. ${d.name} went quiet.`);
      renderNotes();
    });
    later(3200, () => addLine("you", "You", "Hi, it's Simon. I'll take it from here."));
    later(5600, () => { addLine("sys", null, `You left. ${d.name} picks the call back up.`); activity[seat] = "speaking"; live.human = false; live.headline = `${d.name} is back on the call`; renderNotes(); });
    later(6400, () => addLine("agent", d.name, "I'm back. Is there anything else I can help with?"));
    later(8400, () => { addLine("sys", null, "Call ended."); activity[seat] = "idle"; live = null; playIn.disabled = playOut.disabled = false; renderNotes(); });
    renderNotes();
  }
  jump.addEventListener("click", jumpIn);

  // ---------- loop ----------
  let last = performance.now(), clock = 0;
  function tick(now) {
    const dt = Math.min(0.1, (now - last) / 1000);
    last = now;
    if (!reduceMotion) clock += dt;
    agents.forEach((a) => updateAgent(a, dt));
    updateGuests(dt);
    drawOffice(clock);
    portraits.forEach(({ cv, seat }) => drawPortrait(cv, seat, clock));
    requestAnimationFrame(tick);
  }
  renderNotes();
  requestAnimationFrame(tick);
})();
