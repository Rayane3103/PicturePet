-- Credit system updates for AI job flow (credits + refunds)
-- Adds tracking columns, atomic deduct/refund helpers, and combined enqueue RPC.

-- Allow explicit refund transaction entries
do $$
begin
  alter type transaction_type add value 'refund';
exception
  when duplicate_object then null;
end$$;

-- Track credit metadata on ai_jobs
alter table public.ai_jobs
  add column if not exists credit_cost integer not null default 0,
  add column if not exists credit_transaction_id uuid,
  add column if not exists refunded_at timestamptz;

do $$
begin
  alter table public.ai_jobs
    add constraint ai_jobs_credit_transaction_id_fkey
      foreign key (credit_transaction_id) references public.credit_transactions(id);
exception
  when duplicate_object then null;
end$$;

-- Atomic credit deduction helper
create or replace function public.deduct_credits(
  user_uuid uuid,
  amount integer,
  description_text text default null,
  reference_id_param uuid default null,
  reference_type_param character varying default null
) returns boolean
language plpgsql
security definer
set search_path to 'public','auth','extensions'
as $$
declare
  new_balance integer;
  balance_before integer;
begin
  if amount is null or amount <= 0 then
    return true;
  end if;

  update profiles
     set credits = credits - amount
   where id = user_uuid
     and credits >= amount
   returning credits into new_balance;

  if not found then
    return false;
  end if;

  balance_before := new_balance + amount;

  insert into credit_transactions (
    user_id,
    type,
    amount,
    balance_before,
    balance_after,
    description,
    reference_id,
    reference_type
  ) values (
    user_uuid,
    'spend',
    amount,
    balance_before,
    new_balance,
    description_text,
    reference_id_param,
    reference_type_param
  );

  return true;
end;
$$;

-- RPC used by the app: enqueue job + charge credits in one transaction
create or replace function public.enqueue_ai_job_with_credits(
  user_uuid uuid,
  project_id_param uuid,
  tool_name_param text,
  payload_json jsonb default '{}'::jsonb,
  input_image_url_param text default null
)
returns table (
  success boolean,
  code text,
  message text,
  job jsonb,
  remaining_credits integer,
  charged_credits integer
)
language plpgsql
security definer
set search_path to 'public','auth','extensions'
as $$
declare
  tool_record record;
  new_job record;
  new_balance integer;
  balance_before integer;
  txn_id uuid;
  payload_value jsonb := '{}'::jsonb;
begin
  if user_uuid is null then
    return query select false, 'UNAUTHENTICATED', 'You must be signed in to run tools', null, null, null;
    return;
  end if;

  if project_id_param is null then
    return query select false, 'INVALID_PROJECT', 'A project id is required', null, null, null;
    return;
  end if;

  if tool_name_param is null or length(trim(tool_name_param)) = 0 then
    return query select false, 'INVALID_TOOL', 'A tool name is required', null, null, null;
    return;
  end if;

  select id, credit_cost, display_name
    into tool_record
    from tools
   where name = tool_name_param
     and coalesce(is_active, true) = true;

  if not found then
    return query select false, 'TOOL_NOT_FOUND', 'Tool is not configured or inactive', null, null, null;
    return;
  end if;

  payload_value := coalesce(payload_json, '{}'::jsonb);

  if coalesce(tool_record.credit_cost, 0) > 0 then
    update profiles
       set credits = credits - tool_record.credit_cost
     where id = user_uuid
       and credits >= tool_record.credit_cost
     returning credits into new_balance;

    if not found then
      return query select false, 'INSUFFICIENT_CREDITS', 'You do not have enough credits for this tool', null, null, tool_record.credit_cost as charged_credits;
      return;
    end if;

    balance_before := new_balance + tool_record.credit_cost;

    insert into credit_transactions (
      user_id,
      type,
      amount,
      balance_before,
      balance_after,
      description,
      reference_id,
      reference_type
    ) values (
      user_uuid,
      'spend',
      tool_record.credit_cost,
      balance_before,
      new_balance,
      'Ran ' || tool_record.display_name,
      project_id_param,
      'ai_job'
    ) returning id into txn_id;
  else
    select credits into new_balance from profiles where id = user_uuid;
    if not found then
      return query select false, 'PROFILE_NOT_FOUND', 'Profile not found', null, null, null;
      return;
    end if;
    txn_id := null;
  end if;

  insert into ai_jobs (
    user_id,
    project_id,
    tool_name,
    payload,
    input_image_url,
    status,
    credit_cost,
    credit_transaction_id
  ) values (
    user_uuid,
    project_id_param,
    tool_name_param,
    payload_value,
    input_image_url_param,
    'queued',
    coalesce(tool_record.credit_cost, 0),
    txn_id
  )
  returning * into new_job;

  return query select
    true,
    'OK',
    'Job queued',
    to_jsonb(new_job),
    new_balance,
    coalesce(tool_record.credit_cost, 0) as charged_credits;
end;
$$;

-- Manual + automatic refund helpers
create or replace function public.refund_ai_job_credits(job_id_param uuid)
returns boolean
language plpgsql
security definer
set search_path to 'public','auth','extensions'
as $$
declare
  job_record record;
  balance_after integer;
  balance_before integer;
begin
  if job_id_param is null then
    return false;
  end if;

  select id, user_id, credit_cost, refunded_at, tool_name
    into job_record
    from ai_jobs
   where id = job_id_param;

  if not found then
    return false;
  end if;

  if job_record.credit_cost <= 0 or job_record.refunded_at is not null then
    return false;
  end if;

  update profiles
     set credits = credits + job_record.credit_cost
   where id = job_record.user_id
   returning credits into balance_after;

  if not found then
    return false;
  end if;

  balance_before := balance_after - job_record.credit_cost;

  insert into credit_transactions (
    user_id,
    type,
    amount,
    balance_before,
    balance_after,
    description,
    reference_id,
    reference_type
  ) values (
    job_record.user_id,
    'refund',
    job_record.credit_cost,
    balance_before,
    balance_after,
    'Refund for ' || job_record.tool_name || ' job',
    job_id_param,
    'ai_job_refund'
  );

  update ai_jobs
     set refunded_at = now()
   where id = job_id_param;

  return true;
end;
$$;

create or replace function public.auto_refund_failed_ai_job()
returns trigger
language plpgsql
security definer
set search_path to 'public','auth','extensions'
as $$
begin
  perform refund_ai_job_credits(new.id);
  return new;
end;
$$;

drop trigger if exists trg_ai_jobs_auto_refund on public.ai_jobs;
create trigger trg_ai_jobs_auto_refund
after update on public.ai_jobs
for each row
when (new.status in ('failed','cancelled') and coalesce(new.credit_cost, 0) > 0 and new.refunded_at is null)
execute function public.auto_refund_failed_ai_job();

