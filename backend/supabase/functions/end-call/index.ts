// Hangs up a call from the app: { call_id }. Deleting the room disconnects the phone side too.

import { json, readJson, requireString, serve } from "../_shared/http.ts";
import { clients } from "../_shared/livekit.ts";
import { admin, ownedCall, requireUser } from "../_shared/supabase.ts";

serve(async (req) => {
  const user = await requireUser(req);
  const body = await readJson<{ call_id?: string }>(req);
  const call = await ownedCall(user.id, requireString(body.call_id, "call_id"));

  try {
    await clients().rooms.deleteRoom(call.room_name);
  } catch (err) {
    // Room already gone (call ended on its own) — nothing to hang up.
    console.warn("deleteRoom", call.room_name, err);
  }

  if (!["ended", "missed", "failed"].includes(call.status)) {
    const { error } = await admin
      .from("calls")
      .update({ status: "ended", ended_at: new Date().toISOString(), agent_state: null })
      .eq("id", call.id);
    if (error) throw error;
  }
  return json({ ok: true });
});
