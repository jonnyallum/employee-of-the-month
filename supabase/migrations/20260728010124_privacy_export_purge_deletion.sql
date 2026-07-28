-- PRV-004, PRV-005 and PRV-006: retention purge, subject export and account
-- deletion.
--
-- These three are where the product's privacy promises stop being copy. Each
-- one has a rule that is easy to get subtly wrong in a way nobody notices until
-- it matters, so each is written to fail closed and tested for what it refuses.

-- ---------------------------------------------------------------------------
-- PRV-005: export_my_data
-- ---------------------------------------------------------------------------
--
-- FR-PRIV-02 is asymmetric, and the asymmetry is the whole point:
--
--   * what the subject WROTE  -> returned with the nominee, because they chose
--     that person and already know it;
--   * what was written ABOUT the subject -> the text is returned, the author
--     never is.
--
-- A subject access request cannot become a way to learn who nominated you.
-- Reasons about the subject are also limited to cycles that have closed:
-- returning them while voting is open would let somebody watch nominations
-- arrive in real time, which is the live-standings leak by another route.

create or replace function public.export_my_data()
returns jsonb
language plpgsql
-- Volatile, not stable. It records that an export happened, because a subject
-- access request is exactly the kind of thing that should be traceable
-- afterwards, and Postgres refuses a write inside a non-volatile function.
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  result jsonb;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select jsonb_build_object(
    'generated_at', now(),
    'account', (
      select jsonb_build_object(
        'email', u.email,
        'display_name', p.display_name,
        'created_at', u.created_at
      )
      from auth.users u
      left join public.profiles p on p.user_id = u.id
      where u.id = caller
    ),
    'memberships', coalesce((
      select jsonb_agg(jsonb_build_object(
        'organisation', o.name,
        'role', m.role,
        'status', m.status,
        'joined_at', m.joined_at
      ) order by m.joined_at)
      from public.organisation_members m
      join public.organisations o on o.id = m.organisation_id
      where m.user_id = caller
    ), '[]'::jsonb),

    -- What the subject wrote. The nominee is included because the subject
    -- chose them.
    'nominations_i_made', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month', c.period_month,
        'organisation', o.name,
        'nominee', p.display_name,
        'reason', n.reason,
        'status', n.status
      ) order by c.period_month)
      from public.recognition_nominations n
      join public.recognition_cycles c on c.id = n.cycle_id
      join public.organisations o on o.id = n.organisation_id
      join public.participants p on p.id = n.nominee_participant_id
      where n.nominator_user_id = caller
    ), '[]'::jsonb),

    -- What was written about the subject. No author, by construction: the
    -- select list simply has nowhere to put one.
    'reasons_written_about_me', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month', c.period_month,
        'organisation', o.name,
        'reason', n.reason
      ) order by c.period_month)
      from public.recognition_nominations n
      join public.participants me
        on me.id = n.nominee_participant_id
       and me.user_id = caller
      join public.recognition_cycles c on c.id = n.cycle_id
      join public.organisations o on o.id = n.organisation_id
      where n.status = 'active'
        and n.reason is not null
        -- Only once voting has closed. Otherwise this becomes a live feed of
        -- nominations arriving, which is the standings leak by another route.
        and c.status in ('closed', 'revealed')
    ), '[]'::jsonb),

    'awards_i_won', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month', c.period_month,
        'organisation', o.name,
        'nominations', c.winner_nominations
      ) order by c.period_month)
      from public.recognition_cycles c
      join public.organisations o on o.id = c.organisation_id
      join public.participants p
        on p.id = c.winner_participant_id and p.user_id = caller
      where c.status = 'revealed'
    ), '[]'::jsonb)
  ) into result;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  select m.organisation_id, caller, 'data_exported', 'user', caller::text
  from public.organisation_members m
  where m.user_id = caller;

  return result;
end;
$$;

comment on function public.export_my_data() is
  'FR-PRIV-02 subject export. Returns what the caller wrote with the nominee '
  'named, and what was written about them with no author. A subject access '
  'request must not become a way to learn who nominated you.';

revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- ---------------------------------------------------------------------------
-- PRV-006: request_account_deletion
-- ---------------------------------------------------------------------------
--
-- FR-PRIV-03 and journey D. The sole-owner block exists because deleting the
-- only owner of an organisation would strand every colleague in a programme
-- nobody can administer or close.

create or replace function public.request_account_deletion()
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  stranded text;
  request_id uuid;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Any organisation where the caller is the last active owner.
  select string_agg(o.name, ', ') into stranded
  from public.organisation_members m
  join public.organisations o on o.id = m.organisation_id
  where m.user_id = caller
    and m.role = 'owner'
    and m.status = 'active'
    and not exists (
      select 1 from public.organisation_members other
      where other.organisation_id = m.organisation_id
        and other.user_id <> caller
        and other.role = 'owner'
        and other.status = 'active'
    );

  if stranded is not null then
    raise exception
      'transfer ownership of % first, or delete the organisation', stranded
      using errcode = '22023', hint = 'sole_owner';
  end if;

  -- Idempotent: asking twice returns the request already in flight rather than
  -- queueing a second one, because a person pressing a delete button twice
  -- means one deletion.
  select id into request_id
  from public.privacy_requests
  where user_id = caller
    and request_type = 'deletion'
    and state in ('received', 'in_progress');

  if request_id is not null then
    return request_id;
  end if;

  insert into public.privacy_requests
    (user_id, request_type, state, due_at)
  values (caller, 'deletion', 'received', now() + interval '30 days')
  returning id into request_id;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  select m.organisation_id, caller, 'deletion_requested', 'user', caller::text
  from public.organisation_members m
  where m.user_id = caller;

  return request_id;
end;
$$;

revoke all on function public.request_account_deletion() from public, anon;
grant execute on function public.request_account_deletion() to authenticated;

-- The caller may see the state of their own requests and nobody else's.
create or replace function public.get_my_privacy_requests()
returns table (
  id uuid,
  request_type text,
  state text,
  received_at timestamptz,
  due_at timestamptz,
  completed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.request_type, r.state, r.received_at, r.due_at, r.completed_at
  from public.privacy_requests r
  where r.user_id = (select auth.uid())
  order by r.received_at desc;
$$;

revoke all on function public.get_my_privacy_requests() from public, anon;
grant execute on function public.get_my_privacy_requests() to authenticated;

-- ---------------------------------------------------------------------------
-- PRV-004: retention purge
-- ---------------------------------------------------------------------------
--
-- FR-PRIV-01. What gets purged is deliberately narrow:
--
--   * ONLY revealed cycles, and only once the organisation's retention period
--     has passed since the reveal. Draft, open and closed cycles are never
--     touched, because purging work in progress destroys a live programme.
--   * The winner snapshot survives. It lives on the cycle as plain columns with
--     no foreign key, so deleting ballots cannot cascade into it. That is why
--     it was designed that way in DB-003.
--   * A null retention_months means indefinite, which D-012 permits as an
--     explicit choice, so those organisations are skipped entirely rather than
--     defaulted to something.
--
-- It is SECURITY DEFINER and granted to service_role, so the scheduled job can
-- run it WITHOUT service_role holding delete rights on the ballot table. That
-- keeps the trusted role's reach as narrow as DB-005 left it: a compromised
-- server function can call this and nothing else.
--
-- dry_run defaults to true. A purge that deletes by default is one keystroke
-- from an accident.

create or replace function public.purge_expired_nominations(
  dry_run boolean default true
)
returns table (
  organisation_id uuid,
  cycle_id uuid,
  period_month date,
  nominations_affected integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  affected integer;
  target record;
begin
  for target in
    select c.id, c.organisation_id, c.period_month
    from public.recognition_cycles c
    join public.recognition_settings s
      on s.organisation_id = c.organisation_id
    where c.status = 'revealed'
      and c.revealed_at is not null
      and s.retention_months is not null
      and c.revealed_at < now() - (s.retention_months * interval '1 month')
      -- Already purged cycles have no reasons left to remove. Skipping them
      -- is what makes repeated runs idempotent and the counts honest.
      and exists (
        select 1 from public.recognition_nominations n
        where n.cycle_id = c.id and n.reason is not null
      )
  loop
    select count(*) into affected
    from public.recognition_nominations n
    where n.cycle_id = target.id and n.reason is not null;

    if not dry_run then
      -- The reason is the personal data. The row itself stays, because the
      -- count of ballots is what makes a past result verifiable, and because
      -- deleting rows would let somebody re-cast into a revealed cycle.
      update public.recognition_nominations n
      set reason = null
      where n.cycle_id = target.id and n.reason is not null;

      insert into public.audit_events
        (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
      values (target.organisation_id, null, 'retention_purge', 'cycle',
              target.id::text,
              jsonb_build_object('nominations_affected', affected));
    end if;

    organisation_id := target.organisation_id;
    cycle_id := target.id;
    period_month := target.period_month;
    nominations_affected := affected;
    return next;
  end loop;
end;
$$;

comment on function public.purge_expired_nominations(boolean) is
  'FR-PRIV-01 retention sweep. Clears reason text from revealed cycles past '
  'their retention period, never from draft, open or closed ones. Winner '
  'snapshots survive because they are plain columns with no foreign key. '
  'Defaults to a dry run.';

-- Not callable by any client. The scheduled job runs as the trusted role, and
-- granting execute here is what avoids granting it delete on the ballot table.
revoke all on function public.purge_expired_nominations(boolean)
  from public, anon, authenticated;
grant execute on function public.purge_expired_nominations(boolean) to service_role;
