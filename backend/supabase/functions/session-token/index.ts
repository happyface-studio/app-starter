// Mints a LiveKit token so the app can join a call room.
//
//   { mode: "talk", desk_id }   → new in-app call with the desk's agent (no phone number needed)
//   { mode: "listen", call_id } → join a live phone call to listen in or take over
//
// Responds in LiveKit's token-endpoint shape so the Swift SDK's TokenSourceResponse decodes it.

import { HttpError, readJson, requireString, serve, json } from "../_shared/http.ts";
import { participantToken } from "../_shared/livekit.ts";
import { admin, ownedCall, ownedDesk, requireUser } from "../_shared/supabase.ts";

type Body = { mode?: "talk" | "listen"; desk_id?: string; call_id?: string };

serve(async (req) => {
  const user = await requireUser(req);
  const body = await readJson<Body>(req);
  const identity = `owner-${user.id}`;

  if (body.mode === "listen") {
    const call = await ownedCall(user.id, requireString(body.call_id, "call_id"));
    if (!["ringing", "dialing", "active", "human"].includes(call.status)) {
      throw new HttpError(409, "That call has already ended");
    }
    const token = await participantToken({
      room: call.room_name,
      identity,
      name: "Owner",
      attributes: { "deskmates.role": "owner" },
    });
    return json({ ...token, call_id: call.id });
  }

  const desk = await ownedDesk(user.id, requireString(body.desk_id, "desk_id"));
  const room = `web-${crypto.randomUUID()}`;

  const { data: call, error } = await admin
    .from("calls")
    .insert({
      user_id: user.id,
      desk_id: desk.id,
      direction: "web",
      room_name: room,
      status: "ringing",
    })
    .select("id")
    .single();
  if (error) throw error;

  const token = await participantToken({
    room,
    identity,
    name: "Owner",
    attributes: { "deskmates.role": "owner" },
    dispatch: { direction: "web", call_id: call.id, desk_id: desk.id },
  });
  return json({ ...token, call_id: call.id });
});
