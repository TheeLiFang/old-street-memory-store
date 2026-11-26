-- 老街记忆店 · online leaderboard
-- Paste this whole file into Supabase → SQL Editor → Run. Safe to run more than once.

create table if not exists public.scores (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  name        text not null check (char_length(name) between 1 and 12),
  mode        text not null check (mode in ('flip', 'shop')),
  level       int  not null check (level between 1 and 9),
  score       int  not null check (score between 1 and 1000),
  device      text not null check (char_length(device) between 8 and 40)
);

create index if not exists scores_board_idx on public.scores (mode, score desc, created_at);
create index if not exists scores_device_idx on public.scores (device, created_at desc);

-- Anyone may read scores and add a score; nobody may edit or delete through the public key.
alter table public.scores enable row level security;
grant select, insert on public.scores to anon;

drop policy if exists "read scores" on public.scores;
create policy "read scores" on public.scores for select to anon using (true);

drop policy if exists "add a score" on public.scores;
create policy "add a score" on public.scores for insert to anon with check (true);

-- Simple flood guard: one score per device every 5 seconds.
create or replace function public.scores_rate_limit() returns trigger
language plpgsql as $$
begin
  if exists (select 1 from public.scores
             where device = new.device and created_at > now() - interval '5 seconds') then
    raise exception 'too many scores, slow down';
  end if;
  return new;
end $$;

drop trigger if exists scores_rate_limit on public.scores;
create trigger scores_rate_limit before insert on public.scores
  for each row execute function public.scores_rate_limit();
