// Sends a desk's agent out to call someone: { desk_id, to, brief? }.
// `brief` is what the call is about ("book a table for 4 on Friday at 8pm").
//
// We create the room and dispatch the agent with the dial instructions; the agent places the
// SIP call itself (CreateSIPParticipant, wait_until_answered) so it is listening the moment the
// other side picks up. Requires a line from the studio SIP trunk — LiveKit numbers are
// inbound-only for now.

import { E164, HttpError, json, readJson, requireString, serve } from "../_shared/http.ts";
import { AGENT_NAME, clients, type JobMetadata } from "../_shared/livekit.ts";
import { admin, lineForDesk, ownedDesk, requireUser } from "../_shared/supabase.ts";

type Body = { desk_id?: string; to?: string; brief?: string };

const OUTBOUND_TRUNK = Deno.env.get("LIVEKIT_SIP_OUTBOUND_TRUNK_ID") ?? "";
const MAX_PER_DAY = Number(Deno.env.get("MAX_OUTBOUND_CALLS_PER_DAY") ?? "20");
// Toll-fraud guard: only dial these country prefixes unless configured otherwise.
const ALLOWED_PREFIXES = (Deno.env.get("ALLOWED_DIAL_PREFIXES") ?? "+1,+49,+43,+41,+44")
  .split(",")
  .map((p) => p.trim())
  .filter(Boolean);

serve(async (req) => {
  const user = await requireUser(req);
  const body = await readJson<Body>(req);

  const to = requireString(body.to, "to").replace(/[\s()-]/g, "");
  if (!E164.test(to)) throw new HttpError(400, "Use the full number, like +4915112345678");
  if (!ALLOWED_PREFIXES.some((p) => to.startsWith(p))) {
    throw new HttpError(403, "Calls to that country aren't enabled in this prototype");
  }

  const desk = await ownedDesk(user.id, requireString(body.desk_id, "desk_id"));
  const line = await lineForDesk(desk.id);
  if (!line) throw new HttpError(409, `${desk.name} doesn't have a phone yet`);
  if (!line.can_outbound || !OUTBOUND_TRUNK) {
    throw new HttpError(409, `${desk.name}'s number can only take calls, not make them`);
  }

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count, error: countError } = await admin
    .from("calls")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .eq("direction", "outbound")
    .gte("started_at", since);
  if (countError) throw countError;
  if ((count ?? 0) >= MAX_PER_DAY) {
    throw new HttpError(429, `Prototype limit: ${MAX_PER_DAY} outbound calls per day`);
  }

  const room = `out-${crypto.randomUUID()}`;
  const { data: call, error } = await admin
    .from("calls")
    .insert({
      user_id: user.id,
      desk_id: desk.id,
      line_id: line.id,
      direction: "outbound",
      remote_number: to,
      room_name: room,
      status: "dialing",
    })
    .select("id")
    .single();
  if (error) throw error;

  const metadata: JobMetadata = {
    direction: "outbound",
    call_id: call.id,
    desk_id: desk.id,
    to,
    from: line.e164,
    trunk_id: OUTBOUND_TRUNK,
    brief: typeof body.brief === "string" ? body.brief.trim().slice(0, 1000) : undefined,
  };

  try {
    const { rooms, dispatch } = clients();
    await rooms.createRoom({ name: room, emptyTimeout: 60, departureTimeout: 10 });
    await dispatch.createDispatch(room, AGENT_NAME, { metadata: JSON.stringify(metadata) });
  } catch (err) {
    await admin
      .from("calls")
      .update({ status: "failed", error: "Couldn't reach the voice server", ended_at: new Date().toISOString() })
      .eq("id", call.id);
    throw err;
  }

  return json({ call_id: call.id, room_name: room });
});
