-- 다시, 책상 · Supabase 스키마
-- Supabase 대시보드 SQL Editor에 그대로 붙여넣어 실행하세요.

create extension if not exists "pgcrypto"; -- gen_random_uuid() 사용을 위해 필요

-- ---------------------------------------------------------------------------
-- 1. tasks: 사용자가 입력한 큰 과제
-- ---------------------------------------------------------------------------
create table if not exists public.tasks (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  title        text not null,
  energy_level text not null check (energy_level in ('tired', 'normal', 'great')),
  status       text not null default 'active' check (status in ('active', 'completed', 'archived')),
  created_at   timestamptz not null default now()
);
create index if not exists tasks_user_id_idx on public.tasks (user_id);

-- ---------------------------------------------------------------------------
-- 2. micro_tasks: AI가 분해한 5~10분 단위 마이크로 과제
-- ---------------------------------------------------------------------------
create table if not exists public.micro_tasks (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.tasks (id) on delete cascade,
  order_index  int  not null,
  title        text not null,
  duration_min int  not null check (duration_min > 0),
  is_done      boolean not null default false
);
create index if not exists micro_tasks_task_id_idx on public.micro_tasks (task_id);

-- ---------------------------------------------------------------------------
-- 3. sessions: 집중 타이머 세션 기록
-- ---------------------------------------------------------------------------
create table if not exists public.sessions (
  id                 uuid primary key default gen_random_uuid(),
  task_id            uuid not null references public.tasks (id) on delete cascade,
  started_at         timestamptz not null default now(),
  ended_at           timestamptz,
  focus_duration_sec int,
  was_interrupted    boolean not null default false
);
create index if not exists sessions_task_id_idx on public.sessions (task_id);

-- ---------------------------------------------------------------------------
-- 4. snapshots: 중단 시점의 맥락(재진입용)
-- ---------------------------------------------------------------------------
create table if not exists public.snapshots (
  id                        uuid primary key default gen_random_uuid(),
  session_id                uuid not null references public.sessions (id) on delete cascade,
  last_active_micro_task_id uuid references public.micro_tasks (id) on delete set null,
  note_text                 text,
  reentry_action            text not null,
  created_at                timestamptz not null default now()
);
create index if not exists snapshots_session_id_idx on public.snapshots (session_id);

-- ---------------------------------------------------------------------------
-- 5. user_stats: 개인화된 집중 시간 추천용 캐시 통계
-- ---------------------------------------------------------------------------
create table if not exists public.user_stats (
  user_id                  uuid primary key references auth.users (id) on delete cascade,
  avg_focus_duration_sec   int,
  recommended_timebox_sec  int,
  updated_at               timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- publishable(anon) 키는 브라우저에 그대로 노출되므로, RLS를 켜지 않으면
-- 그 키를 아는 누구나 모든 사용자의 데이터를 읽고 쓸 수 있습니다. 반드시 켜세요.
-- micro_tasks / sessions / snapshots는 user_id 컬럼이 없으므로
-- 상위 테이블(tasks)까지 join해서 소유자를 확인합니다.
-- ---------------------------------------------------------------------------
alter table public.tasks       enable row level security;
alter table public.micro_tasks enable row level security;
alter table public.sessions    enable row level security;
alter table public.snapshots   enable row level security;
alter table public.user_stats  enable row level security;

create policy "tasks: 본인 것만 조회/수정" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "micro_tasks: 본인 과제에 속한 것만" on public.micro_tasks
  for all using (
    exists (select 1 from public.tasks t where t.id = micro_tasks.task_id and t.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.tasks t where t.id = micro_tasks.task_id and t.user_id = auth.uid())
  );

create policy "sessions: 본인 과제에 속한 것만" on public.sessions
  for all using (
    exists (select 1 from public.tasks t where t.id = sessions.task_id and t.user_id = auth.uid())
  ) with check (
    exists (select 1 from public.tasks t where t.id = sessions.task_id and t.user_id = auth.uid())
  );

create policy "snapshots: 본인 세션에 속한 것만" on public.snapshots
  for all using (
    exists (
      select 1 from public.sessions s
      join public.tasks t on t.id = s.task_id
      where s.id = snapshots.session_id and t.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1 from public.sessions s
      join public.tasks t on t.id = s.task_id
      where s.id = snapshots.session_id and t.user_id = auth.uid()
    )
  );

create policy "user_stats: 본인 것만" on public.user_stats
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
