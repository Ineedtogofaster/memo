-- Supabase 대시보드 → SQL Editor 에 통째로 붙여넣고 Run (한 번만)

create table if not exists folders (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null default '새 폴더',
  updated_at timestamptz not null default now()
);

-- folder_id 에 외래키를 일부러 안 건다: 다른 기기에서 지운 폴더의 메모를
-- 오프라인 기기가 저장할 때 막히면 저장 대기열이 멈추기 때문 (없는 폴더 = 기본 '메모')
create table if not exists notes (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  folder_id uuid,
  html text not null default '',
  pinned boolean not null default false,
  deleted_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table folders enable row level security;
alter table notes enable row level security;

drop policy if exists own on folders;
drop policy if exists own on notes;
create policy own on folders for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy own on notes   for all using (user_id = auth.uid()) with check (user_id = auth.uid());

alter publication supabase_realtime add table folders, notes;
