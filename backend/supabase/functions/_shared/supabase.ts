import { createClient, type SupabaseClient, type User } from "npm:@supabase/supabase-js@2";
import { HttpError } from "./http.ts";

export const admin: SupabaseClient = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

export async function requireUser(req: Request): Promise<User> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new HttpError(401, "Sign in first");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Sign in first");
  return data.user;
}

export type Desk = {
  id: string;
  user_id: string;
  name: string;
  seat: number;
};

export type PhoneLine = {
  id: string;
  user_id: string;
  desk_id: string | null;
  e164: string;
  provider: "livekit" | "sip_trunk";
  provider_ref: string | null;
  can_inbound: boolean;
  can_outbound: boolean;
};

export type Call = {
  id: string;
  user_id: string;
  desk_id: string | null;
  room_name: string;
  status: string;
  direction: string;
};

export async function ownedDesk(userId: string, deskId: string): Promise<Desk> {
  const { data, error } = await admin
    .from("desks")
    .select("id, user_id, name, seat")
    .eq("id", deskId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new HttpError(404, "Desk not found");
  return data as Desk;
}

export async function ownedCall(userId: string, callId: string): Promise<Call> {
  const { data, error } = await admin
    .from("calls")
    .select("id, user_id, desk_id, room_name, status, direction")
    .eq("id", callId)
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) throw new HttpError(404, "Call not found");
  return data as Call;
}

export async function lineForDesk(deskId: string): Promise<PhoneLine | null> {
  const { data, error } = await admin
    .from("phone_lines")
    .select("*")
    .eq("desk_id", deskId)
    .maybeSingle();
  if (error) throw error;
  return data as PhoneLine | null;
}
