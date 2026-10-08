import {
  AccessToken,
  AgentDispatchClient,
  RoomAgentDispatch,
  RoomConfiguration,
  RoomServiceClient,
  SipClient,
} from "npm:livekit-server-sdk@2.19.1";
import { HttpError } from "./http.ts";

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new HttpError(500, `Server is missing ${name}`);
  return value;
}

export const AGENT_NAME = Deno.env.get("LIVEKIT_AGENT_NAME") ?? "deskmates";
export const INBOUND_RULE_NAME = "deskmates-inbound";
export const INBOUND_ROOM_PREFIX = "call-";

export function livekitConfig() {
  const wsUrl = env("LIVEKIT_URL");
  return {
    wsUrl,
    httpUrl: wsUrl.replace(/^ws(s?):\/\//, "http$1://"),
    apiKey: env("LIVEKIT_API_KEY"),
    apiSecret: env("LIVEKIT_API_SECRET"),
  };
}

export function clients() {
  const { httpUrl, apiKey, apiSecret } = livekitConfig();
  return {
    rooms: new RoomServiceClient(httpUrl, apiKey, apiSecret),
    sip: new SipClient(httpUrl, apiKey, apiSecret),
    dispatch: new AgentDispatchClient(httpUrl, apiKey, apiSecret),
  };
}

export type JobMetadata = {
  direction: "inbound" | "outbound" | "web";
  call_id?: string;
  desk_id?: string;
  to?: string;
  from?: string;
  trunk_id?: string;
  brief?: string;
};

/** Token the app uses to join a room, in LiveKit's standard token-endpoint JSON shape. */
export async function participantToken(opts: {
  room: string;
  identity: string;
  name: string;
  attributes?: Record<string, string>;
  dispatch?: JobMetadata;
}) {
  const { wsUrl, apiKey, apiSecret } = livekitConfig();
  const at = new AccessToken(apiKey, apiSecret, {
    identity: opts.identity,
    name: opts.name,
    attributes: opts.attributes,
    ttl: "15m",
  });
  at.addGrant({
    room: opts.room,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishData: true,
  });
  if (opts.dispatch) {
    at.roomConfig = new RoomConfiguration({
      agents: [
        new RoomAgentDispatch({ agentName: AGENT_NAME, metadata: JSON.stringify(opts.dispatch) }),
      ],
    });
  }
  return {
    server_url: wsUrl,
    participant_token: await at.toJwt(),
    participant_name: opts.name,
    room_name: opts.room,
  };
}

let cachedRuleId: string | null = null;

/**
 * Every phone line shares one dispatch rule: each inbound call gets its own `call-…` room and
 * the `deskmates` agent. The agent works out which desk answers from the dialed number, so
 * adding a line never needs a new rule (and never risks conflicting rules).
 */
export async function ensureInboundDispatchRule(): Promise<string> {
  if (cachedRuleId) return cachedRuleId;
  const { sip } = clients();
  const existing = (await sip.listSipDispatchRule()).find((r) => r.name === INBOUND_RULE_NAME);
  if (existing) return (cachedRuleId = existing.sipDispatchRuleId);

  const created = await sip.createSipDispatchRule(
    { type: "individual", roomPrefix: INBOUND_ROOM_PREFIX },
    {
      name: INBOUND_RULE_NAME,
      roomConfig: new RoomConfiguration({
        agents: [
          new RoomAgentDispatch({
            agentName: AGENT_NAME,
            metadata: JSON.stringify({ direction: "inbound" } satisfies JobMetadata),
          }),
        ],
      }),
    },
  );
  return (cachedRuleId = created.sipDispatchRuleId);
}

/**
 * LiveKit Phone Numbers isn't wrapped by the Node server SDK yet, so we talk Twirp directly.
 * https://docs.livekit.io/reference/telephony/phone-numbers-api/
 */
export async function phoneNumberApi<T = Record<string, unknown>>(
  method:
    | "SearchPhoneNumbers"
    | "PurchasePhoneNumber"
    | "ListPhoneNumbers"
    | "GetPhoneNumber"
    | "UpdatePhoneNumber"
    | "ReleasePhoneNumbers",
  body: Record<string, unknown>,
): Promise<T> {
  const { httpUrl, apiKey, apiSecret } = livekitConfig();
  const at = new AccessToken(apiKey, apiSecret, { ttl: "5m" });
  at.addSIPGrant({ admin: true, call: true });

  const res = await fetch(`${httpUrl}/twirp/livekit.PhoneNumberService/${method}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${await at.toJwt()}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const text = await res.text();
  if (!res.ok) {
    console.error(`PhoneNumberService.${method} failed`, res.status, text);
    let message = "LiveKit rejected the phone number request";
    try {
      message = JSON.parse(text).msg ?? message;
    } catch { /* not JSON */ }
    throw new HttpError(res.status === 404 ? 404 : 502, message);
  }
  return (text ? JSON.parse(text) : {}) as T;
}

/** Twirp may answer in snake_case or camelCase depending on server options — accept both. */
export function pick<T = string>(obj: Record<string, unknown>, ...keys: string[]): T | undefined {
  for (const key of keys) {
    if (obj[key] !== undefined && obj[key] !== null) return obj[key] as T;
  }
  return undefined;
}
