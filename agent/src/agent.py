"""Deskmates voice agent.

One worker serves every desk. Each job is a single call:

- inbound   a phone call to one of the owner's numbers. The shared `deskmates-inbound` dispatch
            rule drops it into a `call-…` room; we look up which desk owns the dialed number.
- outbound  dispatched by the `place-call` edge function with {call_id, desk_id, to, from,
            trunk_id}; the agent dials out itself so it is ready the moment someone answers.
- web       the owner test-calling a desk from the app (token-embedded dispatch).

The agent keeps `public.calls` up to date (status, live agent state, transcript, messages), which
is what animates the pixel office in the app through Supabase Realtime.
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any

import aiohttp
from dotenv import load_dotenv
from livekit import api, rtc
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    JobContext,
    RunContext,
    cli,
    function_tool,
    inference,
    room_io,
)
from livekit.agents.beta.tools import EndCallTool

from notify import push
from persona import (
    HANDOFF_LINES,
    UNASSIGNED_LINES,
    CallInfo,
    instructions_for,
    language_of,
    speech_models,
)
from store import Store, now_iso

load_dotenv(".env.local")
load_dotenv()

logger = logging.getLogger("deskmates")

AGENT_NAME = "deskmates"
OWNER_IDENTITY_PREFIX = "owner-"
CALLEE_IDENTITY = "callee"

try:
    from livekit.plugins import noise_cancellation
except ImportError:  # optional: only available with LiveKit Cloud
    noise_cancellation = None


class CallLog:
    """Writes call progress to Supabase without ever blocking the conversation."""

    def __init__(self, store: Store, call_id: str) -> None:
        self.store = store
        self.call_id = call_id
        self.transcript: list[dict[str, str]] = []
        self._tasks: set[asyncio.Task[Any]] = set()
        self._dirty = asyncio.Event()
        self._writer = asyncio.create_task(self._flush_transcript())
        self.finished = False

    def update(self, **fields: Any) -> None:
        task = asyncio.create_task(self._safe_update(fields))
        self._tasks.add(task)
        task.add_done_callback(self._tasks.discard)

    def add_line(self, role: str, text: str) -> None:
        if text.strip():
            self.transcript.append({"role": role, "text": text.strip(), "at": now_iso()})
            self._dirty.set()

    async def finish(self, status: str = "ended", error: str | None = None) -> None:
        if self.finished:
            return
        self.finished = True
        self._writer.cancel()
        if self._tasks:
            await asyncio.gather(*self._tasks, return_exceptions=True)
        fields: dict[str, Any] = {
            "status": status,
            "agent_state": None,
            "transcript": self.transcript,
            "ended_at": now_iso(),
        }
        if error:
            fields["error"] = error
        await self._safe_update(fields)

    async def _flush_transcript(self) -> None:
        while True:
            await self._dirty.wait()
            self._dirty.clear()
            await self._safe_update({"transcript": list(self.transcript)})
            await asyncio.sleep(0.5)

    async def _safe_update(self, fields: dict[str, Any]) -> None:
        try:
            await self.store.update_call(self.call_id, **fields)
        except Exception:
            logger.exception("failed to update call %s", self.call_id)


class DeskAgent(Agent):
    def __init__(
        self,
        desk: dict[str, Any],
        call: CallInfo,
        log: CallLog,
        http: aiohttp.ClientSession,
        owner_id: str,
    ) -> None:
        super().__init__(
            instructions=instructions_for(desk, call),
            tools=[EndCallTool(delete_room=True, ignore_on_enter=True)],
        )
        self._desk = desk
        self._call = call
        self._log = log
        self._http = http
        self._owner_id = owner_id

    @function_tool()
    async def take_message(
        self,
        context: RunContext,
        caller_name: str,
        message: str,
        callback_number: str = "",
    ) -> str:
        """Save a message for the owner. Use after you've read the message back to the caller.

        Args:
            caller_name: Who is calling, as they introduced themselves.
            message: What they want the owner to know, in one or two sentences.
            callback_number: Where the owner can call them back. Use the caller's number if they agreed to it.
        """
        callback = callback_number or self._call.remote_number or ""
        self._log.update(
            message={"caller_name": caller_name, "callback_number": callback, "text": message}
        )
        await push(
            self._http,
            user_id=self._owner_id,
            title=f"{self._desk['name']} took a message",
            body=f"{caller_name}: {message}",
            call_id=self._log.call_id,
            symbol="envelope.fill",
        )
        return "Saved. Tell the caller the owner will get the message right away."


server = AgentServer()


@server.rtc_session(agent_name=AGENT_NAME)
async def entrypoint(ctx: JobContext) -> None:
    meta: dict[str, Any] = {}
    if ctx.job.metadata:
        try:
            meta = json.loads(ctx.job.metadata)
        except json.JSONDecodeError:
            logger.warning("ignoring non-JSON job metadata: %s", ctx.job.metadata)
    direction = meta.get("direction") or ("inbound" if ctx.room.name.startswith("call-") else "web")

    http = aiohttp.ClientSession()
    store = Store(http)
    active_log: list[CallLog] = []

    # Shutdown callbacks run concurrently, so finish the log before closing its HTTP session.
    async def cleanup() -> None:
        for log in active_log:
            await log.finish()
        await http.close()

    ctx.add_shutdown_callback(cleanup)
    await ctx.connect()

    if direction == "outbound":
        started = await start_outbound(ctx, store, meta)
    elif direction == "inbound":
        started = await start_inbound(ctx, store, http)
    else:
        started = await start_web(ctx, store, meta)
    if started is None:
        return
    desk, call, log, participant, owner_id = started
    active_log.append(log)

    session = AgentSession(
        **speech_models(desk),
        turn_handling={"turn_detection": inference.TurnDetector()},
    )

    @session.on("agent_state_changed")
    def _on_agent_state(ev: Any) -> None:
        if ev.new_state in ("listening", "thinking", "speaking"):
            log.update(agent_state=ev.new_state)

    @session.on("conversation_item_added")
    def _on_item(ev: Any) -> None:
        item = ev.item
        role = getattr(item, "role", None)
        if role in ("user", "assistant"):
            log.add_line(role, item.text_content or "")

    @ctx.room.local_participant.register_rpc_method("deskmates.handoff")
    async def _handoff(data: rtc.RpcInvocationData) -> str:
        """The owner jumped in from the app: say a quick line, then go quiet."""
        if not data.caller_identity.startswith(OWNER_IDENTITY_PREFIX):
            raise rtc.RpcError(rtc.RpcError.ErrorCode.APPLICATION_ERROR, "owner only")

        async def go_quiet() -> None:
            await session.interrupt()
            handle = session.say(HANDOFF_LINES[language_of(desk)], allow_interruptions=False)
            await handle
            session.input.set_audio_enabled(False)
            session.output.set_audio_enabled(False)
            log.update(status="human", agent_state=None)

        asyncio.create_task(go_quiet())
        return "ok"

    audio_input = room_io.AudioInputOptions()
    if noise_cancellation is not None:
        audio_input = room_io.AudioInputOptions(
            noise_cancellation=noise_cancellation.BVCTelephony()
            if direction != "web"
            else noise_cancellation.BVC()
        )

    await session.start(
        room=ctx.room,
        agent=DeskAgent(desk, call, log, http, owner_id),
        room_options=room_io.RoomOptions(
            participant_identity=participant.identity,
            audio_input=audio_input,
            delete_room_on_close=True,
        ),
    )

    if direction != "outbound":
        greeting = (desk.get("greeting") or "").strip()
        if greeting:
            session.say(greeting)
        else:
            session.generate_reply(instructions="Greet the caller briefly and ask how you can help.")


async def start_inbound(ctx: JobContext, store: Store, http: aiohttp.ClientSession):
    participant = await ctx.wait_for_participant(kind=rtc.ParticipantKind.PARTICIPANT_KIND_SIP)
    dialed = participant.attributes.get("sip.trunkPhoneNumber", "")
    caller = participant.attributes.get("sip.phoneNumber") or None

    line = await store.line_by_number(dialed) if dialed else None
    desk = await store.desk(line["desk_id"]) if line and line.get("desk_id") else None

    if line is None or desk is None:
        logger.info("call to %s has no desk, turning it away", dialed)
        if line is not None:
            await store.insert_call(
                {
                    "user_id": line["user_id"],
                    "line_id": line["id"],
                    "direction": "inbound",
                    "remote_number": caller,
                    "room_name": ctx.room.name,
                    "status": "missed",
                    "ended_at": now_iso(),
                }
            )
        await say_and_hang_up(ctx, participant, UNASSIGNED_LINES["en"])
        return None

    row = await store.insert_call(
        {
            "user_id": line["user_id"],
            "desk_id": desk["id"],
            "line_id": line["id"],
            "direction": "inbound",
            "remote_number": caller,
            "room_name": ctx.room.name,
            "status": "active",
            "answered_at": now_iso(),
        }
    )
    await push(
        http,
        user_id=line["user_id"],
        title=f"{desk['name']} picked up a call",
        body=f"From {caller or 'a hidden number'} — tap to listen in.",
        call_id=row["id"],
    )
    call = CallInfo("inbound", line_number=dialed, remote_number=caller)
    return desk, call, CallLog(store, row["id"]), participant, line["user_id"]


async def start_outbound(ctx: JobContext, store: Store, meta: dict[str, Any]):
    call_id, desk_id = meta["call_id"], meta["desk_id"]
    desk = await store.desk(desk_id)
    row = await store.call(call_id)
    if desk is None or row is None:
        logger.error("outbound job for unknown desk/call %s/%s", desk_id, call_id)
        ctx.shutdown()
        return None
    log = CallLog(store, call_id)

    try:
        await ctx.api.sip.create_sip_participant(
            api.CreateSIPParticipantRequest(
                room_name=ctx.room.name,
                sip_trunk_id=meta["trunk_id"],
                sip_call_to=meta["to"],
                sip_number=meta.get("from") or "",
                participant_identity=CALLEE_IDENTITY,
                participant_name=meta["to"],
                krisp_enabled=True,
                wait_until_answered=True,
            )
        )
    except api.SipCallError as e:
        no_answer = e.sip_status_code in (408, 480, 486, 487, 603)
        await log.finish(
            "missed" if no_answer else "failed",
            error=f"{e.sip_status_code} {e.sip_status}".strip(),
        )
        ctx.shutdown()
        return None
    except Exception as e:
        await log.finish("failed", error=str(e))
        ctx.shutdown()
        return None

    log.update(status="active", answered_at=now_iso())
    participant = await ctx.wait_for_participant(identity=CALLEE_IDENTITY)
    call = CallInfo(
        "outbound", line_number=meta.get("from"), remote_number=meta["to"], brief=meta.get("brief")
    )
    return desk, call, log, participant, row["user_id"]


async def start_web(ctx: JobContext, store: Store, meta: dict[str, Any]):
    call_id, desk_id = meta.get("call_id"), meta.get("desk_id")
    desk = await store.desk(desk_id) if desk_id else None
    row = await store.call(call_id) if call_id else None
    if desk is None or row is None:
        logger.error("web job for unknown desk/call %s/%s", desk_id, call_id)
        ctx.shutdown()
        return None
    participant = await ctx.wait_for_participant(kind=rtc.ParticipantKind.PARTICIPANT_KIND_STANDARD)
    log = CallLog(store, row["id"])
    log.update(status="active", answered_at=now_iso())
    return desk, CallInfo("web"), log, participant, row["user_id"]


async def say_and_hang_up(ctx: JobContext, participant: rtc.RemoteParticipant, text: str) -> None:
    session = AgentSession(tts=inference.TTS(model="cartesia/sonic-3"))
    await session.start(
        room=ctx.room,
        agent=Agent(instructions=""),
        room_options=room_io.RoomOptions(participant_identity=participant.identity, audio_input=False),
    )
    await session.say(text, allow_interruptions=False)
    await ctx.delete_room()
    ctx.shutdown()


if __name__ == "__main__":
    cli.run_app(server)
