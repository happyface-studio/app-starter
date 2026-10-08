"""Turns a desk row into the agent's instructions, voice and speech models."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any, Literal

from livekit.agents import inference

Direction = Literal["inbound", "outbound", "web"]

LLM_MODEL = os.getenv("DESKMATES_LLM", "openai/gpt-4.1-mini")
STT_MODEL = os.getenv("DESKMATES_STT", "deepgram/nova-3")
DEFAULT_TTS = os.getenv("DESKMATES_TTS", "cartesia/sonic-3")

DEFAULT_JOB = (
    "Answer calls warmly, find out who is calling and what they need, and take a message "
    "for the owner. You don't have access to the owner's calendar or account systems yet."
)

LANGUAGE_RULES = {
    "en": "Speak English.",
    "de": "Speak German. Use the formal 'Sie' unless the caller switches to 'du' first.",
    "multi": "Reply in whatever language the caller speaks. Start in English unless your greeting says otherwise.",
}

HANDOFF_LINES = {
    "en": "One moment, I'm putting you through now.",
    "de": "Einen Moment, ich verbinde Sie jetzt.",
    "multi": "One moment, I'm putting you through now.",
}

HANDBACK_INSTRUCTIONS = (
    "The owner just stepped off the call and handed it back to you. Let the caller know you're "
    "back in one short sentence and ask if there's anything else you can help with."
)

UNASSIGNED_LINES = {
    "en": "Sorry, nobody is sitting at this desk right now. Please try again later. Goodbye!",
    "de": "Entschuldigung, an diesem Platz sitzt gerade niemand. Bitte versuchen Sie es später noch einmal. Auf Wiederhören!",
}


@dataclass
class CallInfo:
    direction: Direction
    line_number: str | None = None
    remote_number: str | None = None
    brief: str | None = None


def language_of(desk: dict[str, Any]) -> str:
    lang = desk.get("language") or "en"
    return lang if lang in LANGUAGE_RULES else "en"


def instructions_for(desk: dict[str, Any], call: CallInfo) -> str:
    name = desk.get("name") or "Deskmate"
    role = desk.get("role") or "receptionist"
    job = (desk.get("instructions") or "").strip() or DEFAULT_JOB
    caller = call.remote_number or "unknown"

    if call.direction == "inbound":
        situation = (
            f"Someone just called your desk number ({call.line_number}). "
            f"Their number is {caller}."
        )
    elif call.direction == "outbound":
        situation = (
            f"You are placing a call to {caller} on the owner's behalf. Let them say hello first, "
            "then introduce yourself by name, say who you're calling for and why, and get to the point. "
            "If you reach a voicemail box, leave one short message with the reason for the call and "
            "end the call."
        )
        if call.brief:
            situation += f'\n\nWhat this call is about, in the owner\'s words:\n"""\n{call.brief}\n"""'
    else:
        situation = (
            "This is the owner test-calling you from the Deskmates app. Treat it like a real call so "
            "they can hear how you'd handle one, but if they ask about your setup, talk about it openly."
        )

    return f"""You are {name}, a {role}. You handle phone calls for the person who set up your desk; refer to them as "the owner" unless the job description below names them.

You are speaking on the phone:
- Keep every reply to one or two short sentences, like a real person on a call.
- Everything you write is spoken aloud, so never use lists, markdown, emoji or symbols.
- Say phone numbers digit by digit and times the way people say them out loud.
- Never invent facts about the owner or their business. If you don't know, offer to pass the question on.
- {LANGUAGE_RULES[language_of(desk)]}

Your job, in the owner's words:
\"\"\"
{job}
\"\"\"

When the caller wants the owner, asks something you can't answer, or wants a callback: get their name, a callback number (offer the number they're calling from), and the message; read it back in one sentence; then use take_message.
When the conversation is clearly finished, say a short goodbye and use end_call.

{situation}"""


def speech_models(desk: dict[str, Any]) -> dict[str, Any]:
    lang = language_of(desk)
    voice_model = (desk.get("voice") or DEFAULT_TTS).strip()
    tts_kwargs: dict[str, Any] = {}
    if lang != "multi":
        tts_kwargs["language"] = lang
    return {
        "stt": inference.STT(model=STT_MODEL, language=lang),
        "llm": inference.LLM(model=LLM_MODEL),
        "tts": inference.TTS(model=voice_model, **tts_kwargs),
    }
