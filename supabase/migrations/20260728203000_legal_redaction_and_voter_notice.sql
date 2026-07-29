-- Legal determinations, `docs/LEGAL_ANSWERS.md` v0.2. Implements D-028, D-030
-- and D-035.
--
-- Three changes, each closing a gap where the product's paperwork promised
-- something the schema did not deliver:
--
--   1. Moderation could hide but never delete. Article 9 data becomes unlawful
--      the moment it is written, and hiding is a display control. Worse, all
--      moderation was refused once a cycle was revealed, so the one category of
--      content that must always be removable was the one category that became
--      permanent. `redact` fixes both.
--   2. A winner snapshot survived erasure with no way for the customer to undo
--      it. Retention after an Article 21 objection is the controller's call,
--      not ours, and a processor that cannot carry out the controller's
--      decision is the actual exposure. `redact_winner_snapshot` gives them
--      three outcomes instead of two.
--   3. `assessConfidentiality` warned the administrator that ballots may be
--      inferable in a small team. It never warned the voter, who is the person
--      it happens to. `get_cycle_confidentiality` lets the nomination screen
--      say so, without handing a member the roster's eligibility flags.

-- ---------------------------------------------------------------------------
-- D-030: destructive moderation
-- ---------------------------------------------------------------------------

alter table public.recognition_ballot_events
  drop constraint recognition_ballot_events_type;

alter table public.recognition_ballot_events
  add constraint recognition_ballot_events_type
  check (event_type in
    ('cast', 'recast', 'withdrawn', 'hidden', 'restored', 'redacted'));

create or replace function public.moderate_nomination(
  target_nomination_id uuid,
  action text,
  moderation_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  nom record;
  cyc record;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into nom
  from public.recognition_nominations n
  where n.id = target_nomination_id
  for update;

  if nom.id is null
     or not private.has_org_role(nom.organisation_id, array['owner', 'admin']) then
    raise exception 'nomination not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c where c.id = nom.cycle_id;

  if action not in ('hide', 'restore', 'redact') then
    raise exception 'action must be hide, restore or redact'
      using errcode = '22023', hint = 'invalid_action';
  end if;

  -- A revealed result is a published fact, and changing what counted after the
  -- announcement would make it unverifiable. Redaction is the exception and has
  -- to be: it removes the words, never the ballot, so no count moves and no
  -- result changes. If unlawful content could only be removed before reveal,
  -- the remedy would expire on a schedule, which is not how Article 9 works.
  if cyc.status = 'revealed' and action <> 'redact' then
    raise exception 'this result has been revealed and can no longer be changed'
      using errcode = '22023', hint = 'cycle_revealed';
  end if;

  -- Required by the table constraint for hide as well. Checked here to return a
  -- product error rather than a constraint name, and because a moderation with
  -- no recorded reason is an unexplained disappearance.
  if action in ('hide', 'redact')
     and char_length(trim(coalesce(moderate_nomination.moderation_reason, ''))) = 0 then
    raise exception 'a reason is required when hiding or redacting a nomination'
      using errcode = '22023', hint = 'reason_required';
  end if;

  if action = 'hide' then
    if nom.status <> 'active' then
      raise exception 'only an active nomination can be hidden'
        using errcode = '22023', hint = 'not_active';
    end if;

    update public.recognition_nominations n
    set status = 'hidden',
        moderated_by = caller,
        moderated_at = clock_timestamp(),
        moderation_reason = trim(moderate_nomination.moderation_reason)
    where n.id = target_nomination_id;

  elsif action = 'restore' then
    if nom.status <> 'hidden' then
      raise exception 'only a hidden nomination can be restored'
        using errcode = '22023', hint = 'not_hidden';
    end if;

    update public.recognition_nominations n
    set status = 'active',
        moderated_by = caller,
        moderated_at = clock_timestamp(),
        moderation_reason = trim(moderate_nomination.moderation_reason)
    where n.id = target_nomination_id;

  else
    -- Redaction. The reason text is gone, permanently and from any status. The
    -- ballot stays and keeps counting, because the person did vote and the
    -- tally is a separate fact from the words they used.
    --
    -- Nothing is written back into moderation_reason from the removed text. The
    -- administrator supplies their own reason and the interface warns them not
    -- to quote what they are removing, because an audit field is a poor place
    -- to store the health information you have just decided is unlawful.
    if nom.reason is null then
      raise exception 'there is no text left to redact'
        using errcode = '22023', hint = 'already_redacted';
    end if;

    update public.recognition_nominations n
    set reason = null,
        moderated_by = caller,
        moderated_at = clock_timestamp(),
        moderation_reason = trim(moderate_nomination.moderation_reason)
    where n.id = target_nomination_id;
  end if;

  insert into public.recognition_ballot_events
    (organisation_id, cycle_id, event_type)
  values (nom.organisation_id, nom.cycle_id,
          case action
            when 'hide' then 'hidden'
            when 'restore' then 'restored'
            else 'redacted'
          end);

  -- The audit entry names the cycle and the moderator, never the voter, and
  -- never the text that was removed.
  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (nom.organisation_id, caller, 'nomination_moderated', 'cycle',
          nom.cycle_id::text, jsonb_build_object('action', action));
end;
$$;

comment on function public.moderate_nomination(uuid, text, text) is
  'DB-012 moderation, extended by D-030 with a destructive redact action that '
  'clears the reason text permanently and is permitted after reveal. Hiding is '
  'a display control; unlawful special category content has to be removable '
  'from storage, and has to stay removable after the result is announced.';

revoke all on function public.moderate_nomination(uuid, text, text) from public, anon;
grant execute on function public.moderate_nomination(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- D-028: customer-controlled redaction of a winner snapshot
-- ---------------------------------------------------------------------------
--
-- D-016 and D-023 retain a winner's display name and count after erasure, on
-- the basis that a past award is an organisational fact the employer announced.
-- That holds only while the employer, as controller, can decide otherwise: the
-- Article 21(1) balance is theirs to strike and the burden of demonstrating
-- compelling grounds is theirs to carry. Our job is to make both outcomes
-- available, not to pick one.
--
-- Three modes rather than two, because the middle one is usually what actually
-- satisfies the person and it leaves the record coherent:
--
--   initials  -> 'S.M.'                keeps the shape of a real result
--   anonymise -> 'A former colleague'  keeps the fact, drops the person
--   remove    -> null                  the cycle had a winner, unnamed
--
-- The nomination count and the fact the cycle was revealed survive every mode.
-- Those are what make the historic result add up, and no erasure request
-- reaches them.

create or replace function public.redact_winner_snapshot(
  target_cycle_id uuid,
  mode text,
  redaction_reason text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  replacement text;
  parts text[];
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c
  where c.id = target_cycle_id
  for update;

  if cyc.id is null
     or not private.has_org_role(cyc.organisation_id, array['owner', 'admin']) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if cyc.status <> 'revealed' or cyc.winner_name is null then
    raise exception 'this cycle has no announced winner to redact'
      using errcode = '22023', hint = 'no_winner';
  end if;

  if mode not in ('initials', 'anonymise', 'remove') then
    raise exception 'mode must be initials, anonymise or remove'
      using errcode = '22023', hint = 'invalid_mode';
  end if;

  -- A redaction with no recorded reason is indistinguishable from tampering
  -- with a published result, which is the accusation this function most needs
  -- to be able to answer.
  if char_length(trim(coalesce(redaction_reason, ''))) = 0 then
    raise exception 'a reason is required when redacting a winner'
      using errcode = '22023', hint = 'reason_required';
  end if;

  if mode = 'initials' then
    parts := regexp_split_to_array(trim(cyc.winner_name), '\s+');
    select string_agg(upper(left(part, 1)) || '.', '')
      into replacement
      from unnest(parts) as part
     where length(part) > 0;
    -- A single-word or non-Latin display name can reduce to something useless
    -- or to nothing at all. Falling back is better than storing 'X.' and
    -- calling it a redaction.
    if replacement is null or length(replacement) < 4 then
      replacement := 'A former colleague';
    end if;
  elsif mode = 'anonymise' then
    replacement := 'A former colleague';
  else
    replacement := null;
  end if;

  update public.recognition_cycles c
  set winner_name = replacement,
      -- The link to a roster row goes in every mode. Leaving it would let the
      -- name be recovered by a join, which would make the whole exercise
      -- cosmetic. winner_nominations is untouched: the count is the result.
      winner_participant_id = null,
      updated_at = now()
  where c.id = target_cycle_id;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id, metadata)
  values (cyc.organisation_id, caller, 'winner_redacted', 'cycle',
          target_cycle_id::text,
          jsonb_build_object('mode', mode, 'reason', trim(redaction_reason)));
end;
$$;

comment on function public.redact_winner_snapshot(uuid, text, text) is
  'D-028. Lets the customer, as controller, act on an erasure or objection '
  'affecting a past winner without deleting the cycle. The nomination count '
  'and the fact of a revealed result always survive; the name and the roster '
  'link do not.';

revoke all on function public.redact_winner_snapshot(uuid, text, text)
  from public, anon;
grant execute on function public.redact_winner_snapshot(uuid, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- D-035: tell the voter, not only the administrator
-- ---------------------------------------------------------------------------
--
-- D-022 warns an administrator before opening a cycle in a team small enough
-- that ballots can be deduced. The person that happens to is the voter, and
-- until now the voter was never told. Article 5(1)(a) fairness is judged on
-- what the data subject understood when their data was collected, which is the
-- moment they press submit.
--
-- Returns a level, never a headcount. A member is not entitled to the roster's
-- eligibility flags and does not need them: 'you may be identifiable' is the
-- whole of the information they need in order to decide not to vote. The
-- thresholds mirror CONFIDENTIALITY_WARNING_THRESHOLD in
-- src/domain/recognition/engine.ts, and the test asserts they agree.

create or replace function public.get_cycle_confidentiality(
  target_cycle_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  cyc record;
  eligible integer;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select * into cyc
  from public.recognition_cycles c
  where c.id = target_cycle_id;

  if cyc.id is null
     or not private.is_org_member(cyc.organisation_id) then
    raise exception 'cycle not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Only participants who can actually cast a ballot count. An invited person
  -- who never accepted cannot vote, so counting them would overstate the
  -- protection, which is the failure mode this whole decision exists to avoid.
  select count(*) into eligible
  from public.participants p
  where p.organisation_id = cyc.organisation_id
    and p.can_vote
    and p.active
    and p.user_id is not null;

  if eligible <= 2 then
    return 'determined';
  elsif eligible < 8 then
    return 'weak';
  end if;

  return 'standard';
end;
$$;

comment on function public.get_cycle_confidentiality(uuid) is
  'D-035. Returns determined, weak or standard so the nomination screen can '
  'warn the voter that their ballot may be inferable. Deliberately returns a '
  'level and not a count: a member is not entitled to the roster eligibility '
  'flags and does not need them to decide whether to vote.';

revoke all on function public.get_cycle_confidentiality(uuid) from public, anon;
grant execute on function public.get_cycle_confidentiality(uuid) to authenticated;
