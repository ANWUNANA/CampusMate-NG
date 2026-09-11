-- CampusMate NG Supabase schema
create extension if not exists "pgcrypto";

create table if not exists universities (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  short_name text,
  country text not null default 'Nigeria',
  created_at timestamptz default now()
);

create table if not exists faculties (
  id uuid primary key default gen_random_uuid(),
  university_id uuid not null references universities(id) on delete cascade,
  name text not null,
  unique(university_id,name)
);

create table if not exists departments (
  id uuid primary key default gen_random_uuid(),
  faculty_id uuid not null references faculties(id) on delete cascade,
  name text not null,
  unique(faculty_id,name)
);

create table if not exists programmes (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references departments(id) on delete cascade,
  name text not null,
  short_name text,
  unique(department_id,name)
);

create table if not exists levels (
  id uuid primary key default gen_random_uuid(),
  programme_id uuid not null references programmes(id) on delete cascade,
  name text not null,
  level_number int not null,
  unique(programme_id,level_number)
);

create table if not exists semesters (
  id uuid primary key default gen_random_uuid(),
  programme_id uuid not null references programmes(id) on delete cascade,
  name text not null,
  academic_session text,
  is_current boolean default false
);

create table if not exists courses (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  credit_units numeric(4,1) default 0 check(credit_units >= 0)
);

create table if not exists programme_courses (
  id uuid primary key default gen_random_uuid(),
  programme_id uuid not null references programmes(id) on delete cascade,
  level_id uuid references levels(id) on delete set null,
  semester_id uuid references semesters(id) on delete set null,
  course_id uuid not null references courses(id) on delete cascade,
  is_core boolean default true
);

create type user_role as enum ('student','admin','tutor','course_rep');

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role user_role not null default 'student',
  university_id uuid references universities(id) on delete set null,
  faculty_id uuid references faculties(id) on delete set null,
  department_id uuid references departments(id) on delete set null,
  programme_id uuid references programmes(id) on delete set null,
  level_id uuid references levels(id) on delete set null,
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists topics (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  title text not null,
  description text,
  sort_order int default 0,
  status text default 'draft'
);

create table if not exists learning_materials (
  id uuid primary key default gen_random_uuid(),
  topic_id uuid not null references topics(id) on delete cascade,
  title text not null,
  content text,
  material_type text default 'note',
  external_url text,
  status text default 'draft',
  author_id uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);

create table if not exists quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references courses(id) on delete cascade,
  title text not null,
  description text,
  time_limit_minutes int,
  status text default 'draft'
);

create table if not exists quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  question_text text not null,
  options jsonb not null,
  correct_option smallint not null,
  explanation text,
  marks numeric(5,2) default 1
);

create table if not exists quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references quizzes(id) on delete cascade,
  student_id uuid not null references profiles(id) on delete cascade,
  score numeric(8,2) default 0,
  total_marks numeric(8,2) default 0,
  started_at timestamptz default now(),
  submitted_at timestamptz
);

create table if not exists quiz_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references quiz_attempts(id) on delete cascade,
  question_id uuid not null references quiz_questions(id) on delete cascade,
  selected_option smallint,
  is_correct boolean default false,
  unique(attempt_id,question_id)
);

create table if not exists student_course_grades (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  programme_course_id uuid not null references programme_courses(id) on delete cascade,
  grade text,
  grade_point numeric(4,2),
  unique(student_id,programme_course_id)
);

create table if not exists study_tasks (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text,
  due_at timestamptz,
  completed boolean default false
);

create table if not exists bookmarks (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references profiles(id) on delete cascade,
  material_id uuid not null references learning_materials(id) on delete cascade,
  unique(student_id,material_id)
);

create table if not exists announcements (
  id uuid primary key default gen_random_uuid(),
  university_id uuid references universities(id) on delete cascade,
  title text not null,
  body text not null,
  audience text default 'all',
  published boolean default false,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);

-- RLS
alter table profiles enable row level security;
alter table quiz_attempts enable row level security;
alter table quiz_answers enable row level security;
alter table study_tasks enable row level security;
alter table bookmarks enable row level security;
alter table student_course_grades enable row level security;

create policy "own profile" on profiles for select
to authenticated using (id = auth.uid());

create policy "update own profile" on profiles for update
to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "own attempts" on quiz_attempts for all
to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy "own answers" on quiz_answers for all
to authenticated using (
  exists(select 1 from quiz_attempts a where a.id=attempt_id and a.student_id=auth.uid())
) with check (
  exists(select 1 from quiz_attempts a where a.id=attempt_id and a.student_id=auth.uid())
);

create policy "own tasks" on study_tasks for all
to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy "own bookmarks" on bookmarks for all
to authenticated using (student_id = auth.uid()) with check (student_id = auth.uid());

create policy "own grades" on student_course_grades for select
to authenticated using (student_id = auth.uid());

insert into universities(name,short_name)
values('Taraba State University','TSU')
on conflict(name) do nothing;
