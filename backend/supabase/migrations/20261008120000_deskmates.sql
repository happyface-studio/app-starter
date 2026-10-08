-- Deskmates: pixel call-center desks, their phone lines, and the calls they handle.
--
-- desks        one AI teammate per desk (persona, voice, pixel look)
-- phone_lines  real phone numbers, optionally plugged into a desk
-- calls        every inbound / outbound / in-app call, with live status + transcript
--
-- desks are written directly by the app (RLS: owner only).
-- phone_lines and calls are written by edge functions and the agent worker
-- (service role); the app can only read them, assign a line to a desk, and
-- clear its own call log.

-- ---------------------------------------------------------------------------
-- desks
-- ---------------------------------------------------------------------------
create table if not exists public.desks (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
    seat smallint not null check (seat between 0 and 11),
    name text not null check (char_length(name) between 1 and 40),
    role text not null default 'Receptionist' check (char_length(role) <= 60),
    instructions text not null default '' check (char_length(instructions) <= 4000),
    greeting text not null default '' check (char_length(greeting) <= 400),
    language text not null default 'en' check (language in ('en', 'de', 'multi')),
    voice text not null default 'cartesia/sonic-3',
    look jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (user_id, seat)
);

alter table public.desks enable row level security;

create policy "desks_owner_select" on public.desks
    for select using (auth.uid() = user_id);
create policy "desks_owner_insert" on public.desks
    for insert with check (auth.uid() = user_id);
create policy "desks_owner_update" on public.desks
    for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "desks_owner_delete" on public.desks
    for delete using (auth.uid() = user_id);

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger desks_touch_updated_at
    before update on public.desks
    for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- phone_lines
-- ---------------------------------------------------------------------------
create table if not exists public.phone_lines (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    desk_id uuid references public.desks (id) on delete set null,
    e164 text not null unique check (e164 ~ '^\+[1-9][0-9]{6,14}$'),
    provider text not null check (provider in ('livekit', 'sip_trunk')),
    provider_ref text,
    locality text,
    can_inbound boolean not null default true,
    can_outbound boolean not null default false,
    created_at timestamptz not null default now()
);

create unique index if not exists phone_lines_one_per_desk
    on public.phone_lines (desk_id) where desk_id is not null;

alter table public.phone_lines enable row level security;

create policy "phone_lines_owner_select" on public.phone_lines
    for select using (auth.uid() = user_id);

-- The app may only plug a line into one of its own desks (or unplug it).
create policy "phone_lines_owner_assign" on public.phone_lines
    for update using (auth.uid() = user_id)
    with check (
        auth.uid() = user_id
        and (
            desk_id is null
            or exists (select 1 from public.desks d where d.id = desk_id and d.user_id = auth.uid())
        )
    );

revoke insert, update, delete on public.phone_lines from anon, authenticated;
grant update (desk_id) on public.phone_lines to authenticated;

-- One phone per desk: unplug whatever the desk had, then plug the line in (or unplug it when
-- p_desk is null). Runs as the caller, so the RLS policies above still apply.
create or replace function public.plug_line(p_line uuid, p_desk uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
    if p_desk is not null then
        update public.phone_lines set desk_id = null where desk_id = p_desk and id <> p_line;
    end if;
    update public.phone_lines set desk_id = p_desk where id = p_line;
    if not found then
        raise exception 'line not found';
    end if;
end;
$$;

grant execute on function public.plug_line(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- calls
-- ---------------------------------------------------------------------------
create table if not exists public.calls (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    desk_id uuid references public.desks (id) on delete set null,
    line_id uuid references public.phone_lines (id) on delete set null,
    direction text not null check (direction in ('inbound', 'outbound', 'web')),
    remote_number text,
    room_name text not null,
    status text not null default 'ringing'
        check (status in ('ringing', 'dialing', 'active', 'human', 'ended', 'missed', 'failed')),
    agent_state text,
    transcript jsonb not null default '[]'::jsonb,
    message jsonb,
    error text,
    started_at timestamptz not null default now(),
    answered_at timestamptz,
    ended_at timestamptz
);

create index if not exists calls_user_started_idx on public.calls (user_id, started_at desc);
create index if not exists calls_room_name_idx on public.calls (room_name);

alter table public.calls enable row level security;

create policy "calls_owner_select" on public.calls
    for select using (auth.uid() = user_id);
create policy "calls_owner_delete" on public.calls
    for delete using (auth.uid() = user_id);

revoke insert, update on public.calls from anon, authenticated;

-- ---------------------------------------------------------------------------
-- realtime: the office animates from these
-- ---------------------------------------------------------------------------
alter publication supabase_realtime add table public.calls;
alter publication supabase_realtime add table public.phone_lines;
