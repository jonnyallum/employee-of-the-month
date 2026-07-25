-- DB-008: invitation create, reissue, revoke and accept.
--
-- Invitations are the only way into an organisation, which makes them the most
-- attractive thing in the schema to attack: a working token is an identity.
-- FR-AUTH-02 and threat T6 drive the shape.
--
-- Four properties, each enforced here rather than assumed:
--
--   1. Only a hash is stored. A read of organisation_invitations, by anyone
--      including a database operator, yields nothing usable.
--   2. The token is bound to an intended email. A leaked token is useless to
--      anyone who does not control that mailbox, which is what keeps the
--      admin-visible token in create_invitation from being an escalation path.
--   3. Acceptance is one transaction. Consuming the token, linking the
--      participant and creating the membership happen together or not at all,
--      so a replay finds the token already consumed.
--   4. The organisation is derived from the participant row, never accepted as
--      an argument, so a caller cannot assert a tenant they do not administer.

-- ---------------------------------------------------------------------------
-- create_invitation
-- ---------------------------------------------------------------------------
--
-- Returns the raw token. It is the only moment it exists in readable form: only
-- its hash is stored, so it cannot be recovered later and a lost invitation must
-- be reissued rather than looked up.
--
-- The intended consumer is the trusted mail function of COM-001, not an admin
-- screen. Rendering this token in a UI would put a working invitation on screen
-- and in logs. It is safe for an admin to hold only because property 2 above
-- means they cannot redeem it without controlling the invited mailbox.

create or replace function public.create_invitation(
  target_participant_id uuid,
  invited_email text,
  valid_for interval default interval '7 days'
)
returns table (invitation_id uuid, token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  org uuid;
  participant_linked uuid;
  participant_active boolean;
  raw_token text;
  hashed text;
  new_id uuid;
  expiry timestamptz;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  -- Derive the tenant from the row being acted on. Taking it as a parameter
  -- would let a caller name an organisation they administer while pointing at
  -- somebody else's participant.
  select p.organisation_id, p.user_id, p.active
    into org, participant_linked, participant_active
  from public.participants p
  where p.id = target_participant_id;

  if org is null then
    raise exception 'participant not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if not private.has_org_role(org, array['owner', 'admin']) then
    raise exception 'only an owner or admin may invite'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if participant_linked is not null then
    raise exception 'participant already has an account'
      using errcode = '23505', hint = 'already_linked';
  end if;

  if not participant_active then
    raise exception 'participant is not active'
      using errcode = '22023', hint = 'participant_inactive';
  end if;

  invited_email := lower(trim(coalesce(invited_email, '')));
  if position('@' in invited_email) < 2 then
    raise exception 'a valid email address is required'
      using errcode = '22023', hint = 'invalid_email';
  end if;

  if valid_for <= interval '0' then
    raise exception 'expiry must be in the future'
      using errcode = '22023', hint = 'invalid_expiry';
  end if;

  -- Reissue: revoking any live invitation first means a replaced token stops
  -- working immediately. Leaving it live would let an intercepted earlier email
  -- still be redeemed, which is the whole reason reissue exists.
  update public.organisation_invitations
  set revoked_at = now()
  where organisation_id = org
    and participant_id = target_participant_id
    and accepted_at is null
    and revoked_at is null;

  -- 256 bits from a cryptographic source. Guessing is not a threat at this
  -- size, which is what lets the expiry be measured in days rather than minutes.
  raw_token := encode(extensions.gen_random_bytes(32), 'hex');
  hashed := encode(extensions.digest(raw_token, 'sha256'), 'hex');
  expiry := now() + valid_for;

  insert into public.organisation_invitations
    (organisation_id, participant_id, email_normalised, token_hash,
     expires_at, created_by)
  values (org, target_participant_id, invited_email, hashed, expiry, caller)
  returning id into new_id;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  values (org, caller, 'invitation_created', 'invitation', new_id::text);

  return query select new_id, raw_token, expiry;
end;
$$;

comment on function public.create_invitation(uuid, text, interval) is
  'Creates a single-use invitation and returns the only readable copy of its '
  'token. Revokes any live invitation for the same participant first, so a '
  'replaced token stops working immediately.';

revoke all on function public.create_invitation(uuid, text, interval) from public, anon;
grant execute on function public.create_invitation(uuid, text, interval) to authenticated;

-- ---------------------------------------------------------------------------
-- revoke_invitation
-- ---------------------------------------------------------------------------

create or replace function public.revoke_invitation(target_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  org uuid;
  already_accepted timestamptz;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select i.organisation_id, i.accepted_at into org, already_accepted
  from public.organisation_invitations i
  where i.id = target_invitation_id;

  if org is null or not private.has_org_role(org, array['owner', 'admin']) then
    -- Same error whether the invitation is missing or belongs to another
    -- tenant, so this cannot be used to discover that an id exists.
    raise exception 'invitation not found'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  if already_accepted is not null then
    raise exception 'invitation has already been accepted'
      using errcode = '22023', hint = 'invitation_consumed';
  end if;

  update public.organisation_invitations
  set revoked_at = now()
  where id = target_invitation_id and revoked_at is null;

  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  values (org, caller, 'invitation_revoked', 'invitation', target_invitation_id::text);
end;
$$;

revoke all on function public.revoke_invitation(uuid) from public, anon;
grant execute on function public.revoke_invitation(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- accept_invitation
-- ---------------------------------------------------------------------------
--
-- The single most security-sensitive function in the schema. Everything it does
-- happens in one transaction, so there is no state in which a token has been
-- consumed but no membership exists, or a membership exists twice.

create or replace function public.accept_invitation(token text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller uuid := auth.uid();
  caller_email text;
  caller_confirmed timestamptz;
  hashed text;
  inv record;
begin
  if caller is null then
    raise exception 'authentication required'
      using errcode = '42501', hint = 'permission_denied';
  end if;

  select lower(trim(u.email)), u.email_confirmed_at
    into caller_email, caller_confirmed
  from auth.users u where u.id = caller;

  if caller_confirmed is null then
    raise exception 'verify your email address first'
      using errcode = '42501', hint = 'email_not_verified';
  end if;

  hashed := encode(extensions.digest(coalesce(token, ''), 'sha256'), 'hex');

  -- Locked for the rest of the transaction, so two concurrent redemptions of
  -- the same token cannot both pass the checks below.
  select * into inv
  from public.organisation_invitations i
  where i.token_hash = hashed
  for update;

  -- A wrong token and a missing token are indistinguishable to the caller,
  -- which prevents probing for valid tokens.
  if inv.id is null then
    raise exception 'invitation is not valid'
      using errcode = '22023', hint = 'invitation_invalid';
  end if;

  -- The email binding is checked BEFORE any state check, and the order is the
  -- point. Anyone reaching this line already holds the token, which means it
  -- either reached its recipient or was intercepted. Reporting "withdrawn" or
  -- "already used" to the wrong person tells an interceptor about the account
  -- lifecycle of someone else: that an invitation exists, that it was reissued,
  -- that it has been claimed. Checking the binding first means a non-recipient
  -- learns one thing only, which is that the token is not theirs.
  --
  -- Verified against auth.users rather than anything the caller supplied.
  if inv.email_normalised is distinct from caller_email then
    raise exception 'this invitation was sent to a different email address'
      using errcode = '42501', hint = 'invitation_wrong_email';
  end if;

  if inv.revoked_at is not null then
    raise exception 'invitation was withdrawn'
      using errcode = '22023', hint = 'invitation_revoked';
  end if;

  if inv.accepted_at is not null then
    raise exception 'invitation has already been used'
      using errcode = '22023', hint = 'invitation_consumed';
  end if;

  if inv.expires_at <= now() then
    raise exception 'invitation has expired'
      using errcode = '22023', hint = 'invitation_expired';
  end if;

  if exists (
    select 1 from public.organisation_members m
    where m.organisation_id = inv.organisation_id
      and m.user_id = caller
      and m.status = 'active'
  ) then
    raise exception 'you are already a member of this organisation'
      using errcode = '23505', hint = 'already_member';
  end if;

  -- Consume, link and admit, together.
  update public.organisation_invitations
  set accepted_at = now()
  where id = inv.id;

  update public.participants
  set user_id = caller
  where id = inv.participant_id
    and organisation_id = inv.organisation_id
    and user_id is null;

  if not found then
    -- The participant was linked to somebody else between the checks above and
    -- here, or by a concurrent redemption. Raising rolls back the consumption
    -- too, leaving the invitation usable rather than burnt for nothing.
    raise exception 'this roster entry is already linked to another account'
      using errcode = '23505', hint = 'already_linked';
  end if;

  insert into public.organisation_members (organisation_id, user_id, role, status)
  values (inv.organisation_id, caller, 'member', 'active')
  on conflict (organisation_id, user_id)
  do update set status = 'active', updated_at = now();

  -- Records that an invitation was accepted, and for which organisation. The
  -- actor is the person themselves, so this discloses nothing a member does not
  -- already know.
  insert into public.audit_events
    (organisation_id, actor_user_id, action, entity_type, entity_id)
  values (inv.organisation_id, caller, 'invitation_accepted', 'invitation', inv.id::text);

  return inv.organisation_id;
end;
$$;

comment on function public.accept_invitation(text) is
  'Consumes a token, links the participant and creates membership in one '
  'transaction. Verifies the intended email against auth.users, so a leaked '
  'token cannot be redeemed by anyone else.';

revoke all on function public.accept_invitation(text) from public, anon;
grant execute on function public.accept_invitation(text) to authenticated;
