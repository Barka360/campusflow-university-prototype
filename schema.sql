-- CampusFlow starting data model (PostgreSQL).
-- Not applied to a database. Apply only after university privacy and security review.
-- Production access decisions must be enforced server-side; do not trust browser role values.

create extension if not exists pgcrypto;

create type public.clearance_status as enum ('in_progress','action_needed','complete','withdrawn');
create type public.review_status as enum ('not_started','in_review','approved','needs_correction');
create type public.card_status as enum ('blocked','eligible','printing','ready_for_pickup','collected');
create type public.office_role as enum ('university_admin','dean','hod','documentation_officer','clinic_officer','student_affairs','id_card_officer','student','auditor');

create table public.faculties (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  faculty_id uuid not null references public.faculties(id),
  name text not null,
  active boolean not null default true,
  unique (faculty_id, name),
  unique (id, faculty_id)
);

create table public.staff_profiles (
  user_id uuid primary key, -- references the identity provider's subject
  display_name text not null,
  email text not null,
  role public.office_role not null,
  faculty_id uuid references public.faculties(id),
  department_id uuid,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  foreign key (department_id, faculty_id) references public.departments(id, faculty_id),
  check (role <> 'hod' or department_id is not null),
  check (role <> 'dean' or faculty_id is not null)
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  clearance_id text not null unique,
  matric_number text unique,
  admission_reference text,
  full_name text not null,
  email text,
  phone text,
  faculty_id uuid not null references public.faculties(id),
  department_id uuid not null,
  level smallint,
  expected_graduation_year smallint,
  clearance_status public.clearance_status not null default 'in_progress',
  created_by uuid not null references public.staff_profiles(user_id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (department_id, faculty_id) references public.departments(id, faculty_id),
  check (matric_number is null or length(trim(matric_number)) > 0),
  check (level is null or level between 100 and 900)
);

create index students_faculty_department_status_idx on public.students(faculty_id, department_id, clearance_status);
create index students_matric_idx on public.students(matric_number) where matric_number is not null;

create table public.workflow_stages (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  display_name text not null,
  sequence integer not null unique,
  owning_role public.office_role not null,
  required boolean not null default true,
  active boolean not null default true,
  configuration jsonb not null default '{}'::jsonb
);

create table public.student_reviews (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  stage_id uuid not null references public.workflow_stages(id),
  status public.review_status not null default 'not_started',
  assigned_to uuid references public.staff_profiles(user_id),
  decision_note text,
  decided_by uuid references public.staff_profiles(user_id),
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(student_id, stage_id)
);

create table public.student_documents (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  document_type text not null,
  storage_key text not null unique, -- private object key only; never a public URL
  original_filename text not null,
  mime_type text not null,
  file_size_bytes bigint not null check(file_size_bytes between 1 and 25000000),
  checksum_sha256 text,
  received_by uuid not null references public.staff_profiles(user_id),
  received_at timestamptz not null default now(),
  verification_status text not null default 'received' check(verification_status in ('received','verified','rejected','replaced')),
  verified_by uuid references public.staff_profiles(user_id),
  verified_at timestamptz,
  replaced_by uuid references public.student_documents(id)
);

create table public.clinic_records (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id),
  review_status public.review_status not null default 'not_started',
  medical_card_reference text unique,
  blood_group text,
  visit_at timestamptz,
  recorded_by uuid references public.staff_profiles(user_id),
  -- Keep diagnosis/treatment details in an approved clinical system, not the general clearance record.
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.id_cards (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null unique references public.students(id),
  status public.card_status not null default 'blocked',
  eligible_at timestamptz,
  printed_at timestamptz,
  ready_at timestamptz,
  collected_at timestamptz,
  updated_by uuid references public.staff_profiles(user_id),
  collection_acknowledgement text,
  updated_at timestamptz not null default now()
);

create table public.notification_events (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id),
  channel text not null check(channel in ('email','sms')),
  template_code text not null,
  provider_message_id text,
  delivery_status text not null default 'queued',
  requested_by uuid not null references public.staff_profiles(user_id),
  requested_at timestamptz not null default now(),
  delivered_at timestamptz,
  error_code text
);

create table public.audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.staff_profiles(user_id),
  student_id uuid references public.students(id),
  action text not null,
  object_type text not null,
  object_id text,
  occurred_at timestamptz not null default now(),
  request_id text,
  metadata jsonb not null default '{}'::jsonb,
  -- Never store passwords, access tokens, raw biometrics, document contents, or clinical notes here.
  immutable boolean not null default true
);

-- Recommended RLS direction once application roles and auth claims are agreed:
-- * deny access by default, then grant explicit server/API access.
-- * HOD/documentation role: only student rows where department_id equals the verified staff scope.
-- * Dean role: only student rows where faculty_id equals the verified staff scope.
-- * clinic role: minimum identifying details and clinic workflow only; credentials hidden by default.
-- * student role: only the authenticated student's own record and safe status fields.
-- * audit events: append-only for application identities; no update/delete from ordinary roles.
-- Do not paste client-controlled faculty/department identifiers into a policy as proof of scope.

