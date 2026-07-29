-- D-032: a required tag and a short optional note, instead of an essay box.
--
-- Every other mitigation for the Article 9 problem is a remedy after the fact:
-- moderation hides it, redaction removes it, retention eventually purges it.
-- This is the only change that reduces how often somebody types health,
-- religion or sex life into a recognition app in the first place, because
-- people write essays in essay boxes and write a sentence next to a checkbox.
--
-- It was left unscheduled because it changes how the product feels, which is
-- not a decision to take on legal advice alone. Jonny has now taken it.
--
-- Two choices worth defending:
--
--   * The vocabulary is behaviour only. No tag invites a comment about who a
--     person is, what they have been through, or how they have been. That is
--     the whole point; a tag called "overcame adversity" would make the problem
--     worse rather than better.
--
--   * Existing rows get `unspecified` rather than a guess. There is no honest
--     mapping from free text to a tag, and back-filling them as
--     `helped_colleague` would be inventing data about real people. The value
--     is accepted by the constraint and refused by `cast_nomination`, so it can
--     only ever mean "written before tags existed".

-- The default is the legacy value, not a real tag. Clients have no INSERT grant
-- on this table at all - `cast_nomination` is the only way a ballot is ever
-- created, and it requires a real tag and refuses `unspecified`. So the default
-- cannot weaken the requirement; it only decides what an insert from a fixture
-- or a future admin tool becomes if it says nothing, and "untagged" is the
-- honest answer to that.
alter table public.recognition_nominations
  add column if not exists tag text default 'unspecified';

update public.recognition_nominations set tag = 'unspecified' where tag is null;

alter table public.recognition_nominations
  alter column tag set not null;

alter table public.recognition_nominations
  drop constraint if exists recognition_nominations_tag;

alter table public.recognition_nominations
  add constraint recognition_nominations_tag
  check (tag in ('helped_colleague',
                 'helped_customer',
                 'improved_how_we_work',
                 'shared_knowledge',
                 'steady_under_pressure',
                 'unspecified'));

comment on column public.recognition_nominations.tag is
  'D-032. Required on new nominations. Behaviour only, deliberately: a '
  'vocabulary that invited comment on who somebody is would make the Article 9 '
  'problem worse. unspecified is legacy-only and is refused by cast_nomination.';

-- The tag survives the retention purge even though the reason does not. Once
-- the nominee link is severed, "somebody was thanked for looking after a
-- customer" identifies nobody, and it lets an organisation see what its people
-- actually value over years without keeping anything about a named person.

-- ---------------------------------------------------------------------------
-- The note gets shorter
-- ---------------------------------------------------------------------------
--
-- 500 characters is a paragraph, and a paragraph is where the disclosures live.
-- 250 is enough for "covered my shift at two hours' notice and never mentioned
-- it again" and not enough to drift into somebody's medical history.

alter table public.recognition_nominations
  drop constraint if exists recognition_nominations_reason_length;

alter table public.recognition_nominations
  add constraint recognition_nominations_reason_length
  check (reason is null or char_length(reason) <= 250);

-- ---------------------------------------------------------------------------
-- cast_nomination requires a tag
-- ---------------------------------------------------------------------------
--
-- Signature change, so drop and recreate. The tag sits before the note because
-- that is the order the screen asks for them, and an RPC whose argument order
-- contradicts the form it backs is a bug waiting for a careless caller.

drop function if exists public.cast_nomination(uuid, uuid, text, text);

create function public.cast_nomination(
  target_cycle_id uuid,
  nominee_participant_id uuid,
  nomination_tag text,
  reason text default null,
  idempotency_key text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  voter_participant uuid;
  voter_can_vote boolean;
  nominee record;
  existing record;
  cleaned_reason text;
  ballot_id uuid;
  was_recast boolean := false;
begin
  if caller is null then
    raise exception 'sign in before making a nomination'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c
  where c.id = target_cycle_id;

  if cyc.id is null or not private.is_org_member(cyc.organisation_id) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status <> 'open' then
    raise exception 'nominations are not open'
      using errcode = '22023', hint = 'cycle_not_open';
  end if;

  -- Checked before the roster lookup so the error a caller gets for a bad tag
  -- does not depend on whether they are eligible to vote.
  if cast_nomination.nomination_tag is null
     or cast_nomination.nomination_tag not in ('helped_colleague',
                                               'helped_customer',
                                               'improved_how_we_work',
                                               'shared_knowledge',
                                               'steady_under_pressure') then
    raise exception 'choose what this person did'
      using errcode = '22023', hint = 'tag_required';
  end if;

  select p.id, p.can_vote into voter_participant, voter_can_vote
  from public.participants p
  where p.organisation_id = cyc.organisation_id
    and p.user_id = caller
    and p.active
    and p.left_at is null;

  if voter_participant is null then
    raise exception 'you are not on this organisation''s roster'
      using errcode = '42501', hint = 'not_on_roster';
  end if;

  if not voter_can_vote then
    raise exception 'you are not eligible to vote in this cycle'
      using errcode = '42501', hint = 'not_eligible_to_vote';
  end if;

  select p.* into nominee
  from public.participants p
  where p.id = cast_nomination.nominee_participant_id
    and p.organisation_id = cyc.organisation_id;

  if nominee.id is null then
    raise exception 'that colleague is not on this organisation''s roster'
      using errcode = '42501', hint = 'nominee_not_found';
  end if;

  if not (nominee.active and nominee.can_receive) then
    raise exception 'that colleague is not eligible to receive nominations'
      using errcode = '22023', hint = 'nominee_not_eligible';
  end if;

  if nominee.id = voter_participant then
    raise exception 'you cannot nominate yourself'
      using errcode = '22023', hint = 'self_nomination';
  end if;

  cleaned_reason := nullif(
    regexp_replace(trim(coalesce(cast_nomination.reason, '')), '\s+', ' ', 'g'), '');
  if cleaned_reason is not null and char_length(cleaned_reason) > 250 then
    raise exception 'keep the note to 250 characters or fewer'
      using errcode = '22023', hint = 'reason_too_long';
  end if;

  select * into existing
  from public.recognition_nominations n
  where n.organisation_id = cyc.organisation_id
    and n.cycle_id = target_cycle_id
    and n.nominator_user_id = caller
  for update;

  if existing.id is not null
     and cast_nomination.idempotency_key is not null
     and existing.idempotency_key is not distinct from cast_nomination.idempotency_key then
    return existing.id;
  end if;

  if existing.id is not null and existing.status = 'active' then
    raise exception 'you have already nominated someone this month'
      using errcode = '23505', hint = 'already_nominated';
  end if;

  if existing.id is null then
    insert into public.recognition_nominations
      (organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
       nominee_participant_id, tag, reason, status, idempotency_key)
    values (cyc.organisation_id, target_cycle_id, caller, voter_participant,
            nominee.id, cast_nomination.nomination_tag, cleaned_reason,
            'active', cast_nomination.idempotency_key)
    returning id into ballot_id;
  else
    update public.recognition_nominations n
    set nominee_participant_id = nominee.id,
        tag = cast_nomination.nomination_tag,
        reason = cleaned_reason,
        status = 'active',
        idempotency_key = coalesce(cast_nomination.idempotency_key, n.idempotency_key),
        moderated_by = null,
        moderated_at = null,
        moderation_reason = null
    where n.id = existing.id
    returning n.id into ballot_id;
    was_recast := true;
  end if;

  insert into public.recognition_ballot_events
    (organisation_id, cycle_id, event_type)
  values (cyc.organisation_id, target_cycle_id,
          case when was_recast then 'recast' else 'cast' end);

  return ballot_id;
end;
$$;

comment on function public.cast_nomination(uuid, uuid, text, text, text) is
  'Casts or recasts the caller''s single ballot. The voter is taken from '
  'auth.uid(), never an argument, so nobody can vote on another person''s '
  'behalf. The tag is required and unspecified is refused: that value exists '
  'only for ballots written before D-032.';

revoke all on function public.cast_nomination(uuid, uuid, text, text, text)
  from public, anon;
grant execute on function public.cast_nomination(uuid, uuid, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- The administrator sees the tag
-- ---------------------------------------------------------------------------
--
-- This changes the shape pinned by the first assertion in
-- 006_admin_turnout_and_reveal.test.sql. That assertion exists to make a change
-- like this deliberate rather than accidental, and it is being updated in the
-- same commit, which is the intended workflow rather than a nuisance.

drop function if exists public.get_admin_nominations(uuid);

create function public.get_admin_nominations(target_cycle_id uuid)
returns table (
  id uuid,
  nominee_participant_id uuid,
  nominee_display_name text,
  tag text,
  reason text,
  status text,
  moderated_at timestamptz,
  moderation_reason text,
  created_date date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  cyc record;
begin
  select * into cyc from public.recognition_cycles c where c.id = target_cycle_id;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status in ('draft', 'open') then
    raise exception 'nomination reasons are available once voting has closed'
      using errcode = '22023', hint = 'cycle_still_open';
  end if;

  return query
    select n.id,
           n.nominee_participant_id,
           p.display_name,
           n.tag,
           n.reason,
           n.status,
           n.moderated_at,
           n.moderation_reason,
           n.created_at::date
    from public.recognition_nominations n
    join public.participants p
      on p.id = n.nominee_participant_id
     and p.organisation_id = n.organisation_id
    where n.cycle_id = target_cycle_id
      and n.status <> 'withdrawn'
      and n.purged_at is null
    order by p.display_name, n.id;
end;
$$;

revoke all on function public.get_admin_nominations(uuid) from public, anon;
grant execute on function public.get_admin_nominations(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The export includes the tag
-- ---------------------------------------------------------------------------
--
-- The tag is data we hold about the subject, so leaving it out of a subject
-- access request would be a gap this migration created. The
-- `reasons_written_about_me` filter also has to change: a nomination can now
-- carry a tag and no note, and under the old `reason is not null` test it would
-- have been silently omitted from the subject's own export.

create or replace function public.export_my_data()
returns jsonb
language plpgsql
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

    'nominations_i_made', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month', c.period_month,
        'organisation', o.name,
        'nominee', p.display_name,
        'tag', n.tag,
        'reason', n.reason,
        'status', n.status
      ) order by c.period_month)
      from public.recognition_nominations n
      join public.recognition_cycles c on c.id = n.cycle_id
      join public.organisations o on o.id = n.organisation_id
      join public.participants p on p.id = n.nominee_participant_id
      where n.nominator_user_id = caller
    ), '[]'::jsonb),

    -- Still no author, by construction: the select list has nowhere to put one.
    'reasons_written_about_me', coalesce((
      select jsonb_agg(jsonb_build_object(
        'month', c.period_month,
        'organisation', o.name,
        'tag', n.tag,
        'reason', n.reason
      ) order by c.period_month)
      from public.recognition_nominations n
      join public.participants me
        on me.id = n.nominee_participant_id
       and me.user_id = caller
      join public.recognition_cycles c on c.id = n.cycle_id
      join public.organisations o on o.id = n.organisation_id
      where n.status = 'active'
        and (n.reason is not null or n.tag <> 'unspecified')
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

revoke all on function public.export_my_data() from public, anon;
grant execute on function public.export_my_data() to authenticated;

-- ---------------------------------------------------------------------------
-- The voter's own ballot carries the tag back
-- ---------------------------------------------------------------------------
--
-- Without this the nomination form cannot pre-fill on a recast, and somebody
-- editing their note would silently have their tag reset to whatever the
-- control happened to default to.

drop function if exists public.get_my_nomination(uuid);

create function public.get_my_nomination(target_cycle_id uuid)
returns table (
  id uuid,
  nominee_participant_id uuid,
  nominee_display_name text,
  tag text,
  reason text,
  status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select n.id,
         n.nominee_participant_id,
         p.display_name,
         n.tag,
         n.reason,
         n.status,
         n.created_at
  from public.recognition_nominations n
  join public.participants p
    on p.id = n.nominee_participant_id
   and p.organisation_id = n.organisation_id
  where n.cycle_id = target_cycle_id
    and n.nominator_user_id = (select auth.uid())
    and n.status <> 'withdrawn';
$$;

comment on function public.get_my_nomination(uuid) is
  'Returns only the caller''s own ballot. Takes no voter argument, so no call '
  'shape exists that could return another person''s.';

revoke all on function public.get_my_nomination(uuid) from public, anon;
grant execute on function public.get_my_nomination(uuid) to authenticated;
