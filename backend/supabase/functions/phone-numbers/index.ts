// Phone lines for desks.
//
//   { action: "search", country_code?: "US", area_code? }  → LiveKit numbers you can rent
//   { action: "rent", e164, desk_id? }                     → rent a LiveKit number (inbound)
//   { action: "pool" }                                      → unclaimed numbers on the studio's own SIP trunk
//   { action: "claim", e164, desk_id? }                     → claim a trunk number (inbound + outbound)
//   { action: "release", line_id }                          → give a line back
//
// LiveKit Phone Numbers are US-only and inbound-only today. Outbound calling and non-US
// numbers (e.g. +49) come from a SIP trunk (Twilio, Telnyx, …) that the studio connects
// once; its numbers are listed in SIP_TRUNK_NUMBERS and users claim them from the pool.

import { E164, HttpError, json, readJson, requireString, serve } from "../_shared/http.ts";
import { ensureInboundDispatchRule, phoneNumberApi, pick } from "../_shared/livekit.ts";
import { admin, ownedDesk, requireUser, type PhoneLine } from "../_shared/supabase.ts";

type Body = {
  action?: "search" | "rent" | "pool" | "claim" | "release";
  country_code?: string;
  area_code?: string;
  e164?: string;
  desk_id?: string;
  line_id?: string;
};

type AvailableNumber = {
  e164: string;
  locality: string | null;
  region: string | null;
  provider: "livekit" | "sip_trunk";
  can_outbound: boolean;
};

const MAX_LINES = Number(Deno.env.get("MAX_LINES_PER_USER") ?? "2");
const OUTBOUND_TRUNK = Deno.env.get("LIVEKIT_SIP_OUTBOUND_TRUNK_ID") ?? "";
const TRUNK_NUMBERS = (Deno.env.get("SIP_TRUNK_NUMBERS") ?? "")
  .split(",")
  .map((n) => n.trim())
  .filter((n) => E164.test(n));

serve(async (req) => {
  const user = await requireUser(req);
  const body = await readJson<Body>(req);

  switch (body.action) {
    case "search":
      return json({ numbers: await searchLiveKit(body.country_code ?? "US", body.area_code) });

    case "pool":
      return json({ numbers: await unclaimedPoolNumbers() });

    case "rent": {
      const e164 = validE164(body.e164);
      await assertLineQuota(user.id);
      const deskId = body.desk_id ? (await ownedDesk(user.id, body.desk_id)).id : null;
      const ruleId = await ensureInboundDispatchRule();

      const purchased = await phoneNumberApi("PurchasePhoneNumber", {
        phone_numbers: [e164],
        sip_dispatch_rule_id: ruleId,
      });
      const numbers = pick<Record<string, unknown>[]>(purchased, "phone_numbers", "phoneNumbers") ??
        [];
      const ref = numbers[0] ? pick<string>(numbers[0], "id") : undefined;

      const line = await insertLine({
        user_id: user.id,
        e164,
        provider: "livekit",
        provider_ref: ref ?? null,
        can_inbound: true,
        can_outbound: false,
      });
      if (deskId) await plug(line.id, deskId);
      return json({ line: { ...line, desk_id: deskId } });
    }

    case "claim": {
      const e164 = validE164(body.e164);
      if (!TRUNK_NUMBERS.includes(e164)) throw new HttpError(404, "That number isn't in the pool");
      await assertLineQuota(user.id);
      const deskId = body.desk_id ? (await ownedDesk(user.id, body.desk_id)).id : null;
      await ensureInboundDispatchRule();

      const line = await insertLine({
        user_id: user.id,
        e164,
        provider: "sip_trunk",
        provider_ref: OUTBOUND_TRUNK || null,
        can_inbound: true,
        can_outbound: OUTBOUND_TRUNK !== "",
      });
      if (deskId) await plug(line.id, deskId);
      return json({ line: { ...line, desk_id: deskId } });
    }

    case "release": {
      const lineId = requireString(body.line_id, "line_id");
      const { data: line, error } = await admin
        .from("phone_lines")
        .select("*")
        .eq("id", lineId)
        .eq("user_id", user.id)
        .maybeSingle();
      if (error) throw error;
      if (!line) throw new HttpError(404, "Line not found");

      if (line.provider === "livekit") {
        await phoneNumberApi("ReleasePhoneNumbers", { phone_numbers: [line.e164] });
      }
      const { error: delError } = await admin.from("phone_lines").delete().eq("id", line.id);
      if (delError) throw delError;
      return json({ ok: true });
    }

    default:
      throw new HttpError(400, "Unknown action");
  }
});

function validE164(value: unknown): string {
  const e164 = requireString(value, "e164").replace(/[\s()-]/g, "");
  if (!E164.test(e164)) throw new HttpError(400, "Phone numbers look like +14155550123");
  return e164;
}

async function assertLineQuota(userId: string) {
  const { count, error } = await admin
    .from("phone_lines")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId);
  if (error) throw error;
  if ((count ?? 0) >= MAX_LINES) {
    throw new HttpError(403, `Prototype limit: ${MAX_LINES} phone lines per account`);
  }
}

async function searchLiveKit(countryCode: string, areaCode?: string): Promise<AvailableNumber[]> {
  const res = await phoneNumberApi("SearchPhoneNumbers", {
    country_code: countryCode.toUpperCase(),
    ...(areaCode ? { area_code: areaCode } : {}),
    limit: 12,
  });
  const items = pick<Record<string, unknown>[]>(res, "items") ?? [];
  return items
    .map((item) => ({
      e164: pick<string>(item, "e164_format", "e164Format") ?? "",
      locality: pick<string>(item, "locality") ?? null,
      region: pick<string>(item, "region") ?? null,
      provider: "livekit" as const,
      can_outbound: false,
    }))
    .filter((n) => E164.test(n.e164));
}

async function unclaimedPoolNumbers(): Promise<AvailableNumber[]> {
  if (TRUNK_NUMBERS.length === 0) return [];
  const { data, error } = await admin.from("phone_lines").select("e164").in("e164", TRUNK_NUMBERS);
  if (error) throw error;
  const taken = new Set((data ?? []).map((row) => row.e164));
  return TRUNK_NUMBERS.filter((n) => !taken.has(n)).map((e164) => ({
    e164,
    locality: null,
    region: null,
    provider: "sip_trunk" as const,
    can_outbound: OUTBOUND_TRUNK !== "",
  }));
}

async function insertLine(row: Omit<PhoneLine, "id" | "desk_id">): Promise<PhoneLine> {
  const { data, error } = await admin.from("phone_lines").insert(row).select("*").single();
  if (error) {
    if (error.code === "23505") throw new HttpError(409, "Someone already has that number");
    throw error;
  }
  return data as PhoneLine;
}

/** One phone per desk: unplug whatever line the desk had, then plug this one in. */
async function plug(lineId: string, deskId: string) {
  const { error: unplugError } = await admin
    .from("phone_lines")
    .update({ desk_id: null })
    .eq("desk_id", deskId)
    .neq("id", lineId);
  if (unplugError) throw unplugError;
  const { error } = await admin.from("phone_lines").update({ desk_id: deskId }).eq("id", lineId);
  if (error) throw error;
}
