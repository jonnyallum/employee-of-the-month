-- DB-019: deterministic synthetic seed.
--
-- Runs on `supabase db reset`. Everything here is invented. There is no real
-- employee, no real email address and no real nomination text in this file, and
-- there must never be: seeded ballots are readable by anyone with the local
-- database, which is the opposite of the guarantee the product makes.
--
-- The shape is fixed rather than the dates. Months are relative to the current
-- one, so the fixture stays useful in any year instead of quietly becoming four
-- historic cycles and nothing open. What is deterministic is the structure: the
-- same organisations, people, roles and cycle states every time.
--
-- Sign in locally with any seeded address and the password Recognition2026,
-- which satisfies the 12-character mixed-class policy so it can be retyped in
-- the app.

-- ---------------------------------------------------------------------------
-- Refuse to run anywhere but a local stack
-- ---------------------------------------------------------------------------
--
-- `supabase db reset --linked` resets a REMOTE database and then runs this file.
-- The reset itself is the greater danger, but a seed that would happily write
-- invented employees into a real project should not rely on the operator
-- noticing. The local stack ships a well-known demo JWT secret; a hosted project
-- has a real one, so this cannot pass there.

do $$
begin
  if coalesce(current_setting('app.settings.jwt_secret', true), '')
     <> 'super-secret-jwt-token-with-at-least-32-characters-long' then
    raise exception
      'seed.sql refused to run: this does not look like a local Supabase stack';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- People
-- ---------------------------------------------------------------------------
--
-- auth.identities is populated alongside auth.users because GoTrue looks there
-- for the email provider. Without it these accounts exist but cannot sign in,
-- which is a confusing half-state to hand a developer.

with seeded (id, email, display_name) as (
  values
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'ana@alpha.example',   'Ana Okafor'),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'ben@alpha.example',   'Ben Ridley'),
    ('a0000000-0000-4000-8000-000000000003'::uuid, 'cara@alpha.example',  'Cara Duffy'),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'dee@alpha.example',   'Dee Mensah'),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'eli@alpha.example',   'Eli Novak'),
    ('b0000000-0000-4000-8000-000000000001'::uuid, 'gus@beta.example',    'Gus Whelan'),
    ('b0000000-0000-4000-8000-000000000002'::uuid, 'hana@beta.example',   'Hana Reyes')
),
inserted_users as (
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  )
  select '00000000-0000-0000-0000-000000000000',
         s.id, 'authenticated', 'authenticated', s.email,
         extensions.crypt('Recognition2026', extensions.gen_salt('bf')),
         now() - interval '90 days',
         '{"provider":"email","providers":["email"]}'::jsonb,
         jsonb_build_object('display_name', s.display_name),
         now() - interval '90 days', now() - interval '90 days'
  from seeded s
  returning id, email
)
insert into auth.identities (
  provider_id, user_id, identity_data, provider, last_sign_in_at,
  created_at, updated_at
)
select u.email, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       'email', now() - interval '90 days',
       now() - interval '90 days', now() - interval '90 days'
from inserted_users u;

-- ---------------------------------------------------------------------------
-- Alpha Ltd: the organisation with enough people to demonstrate everything
-- ---------------------------------------------------------------------------

insert into public.organisations (id, name, timezone, created_by) values
  ('a1000000-0000-4000-8000-00000000000a', 'Alpha Facilities Ltd', 'Europe/London',
   'a0000000-0000-4000-8000-000000000001');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('a1000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000001', 'owner',  'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000002', 'admin',  'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000003', 'member', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000004', 'member', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000005', 'member', 'active');

-- Dee can be nominated but cannot vote, and Frank is on the roster without an
-- account. Both exist so that screens are built against a roster that is not
-- uniform, because a uniform one hides most of the eligibility rules.
insert into public.participants
  (id, organisation_id, user_id, display_name, team, active, can_vote, can_receive) values
  ('a2000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-00000000000a',
   'a0000000-0000-4000-8000-000000000001', 'Ana Okafor',  'Operations', true, true,  true),
  ('a2000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-00000000000a',
   'a0000000-0000-4000-8000-000000000002', 'Ben Ridley',  'Operations', true, true,  true),
  ('a2000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-00000000000a',
   'a0000000-0000-4000-8000-000000000003', 'Cara Duffy',  'Front of house', true, true, true),
  ('a2000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-00000000000a',
   'a0000000-0000-4000-8000-000000000004', 'Dee Mensah',  'Front of house', true, false, true),
  ('a2000000-0000-4000-8000-000000000005', 'a1000000-0000-4000-8000-00000000000a',
   'a0000000-0000-4000-8000-000000000005', 'Eli Novak',   'Maintenance', true, true,  true),
  ('a2000000-0000-4000-8000-000000000006', 'a1000000-0000-4000-8000-00000000000a',
   null,                                   'Frank Iqbal', 'Maintenance', true, true,  true);

insert into public.recognition_settings (organisation_id, criteria_template) values
  ('a1000000-0000-4000-8000-00000000000a',
   'Someone who went out of their way for a colleague or a customer this month.');

-- A live invitation for the person with no account, so the acceptance screen has
-- something real to work against. The token hash is a fixed placeholder: the
-- plaintext is not recoverable, which is the point, so acceptance is exercised
-- through create_invitation rather than this row.
insert into public.organisation_invitations
  (id, organisation_id, participant_id, email_normalised, token_hash, expires_at, created_by)
values
  ('a3000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-00000000000a',
   'a2000000-0000-4000-8000-000000000006', 'frank@alpha.example',
   repeat('f', 64), now() + interval '5 days',
   'a0000000-0000-4000-8000-000000000001');

-- ---------------------------------------------------------------------------
-- Four cycles, one in each state worth building a screen for
-- ---------------------------------------------------------------------------

insert into public.recognition_cycles
  (id, organisation_id, period_month, status, criteria, version,
   opens_at, closes_at, winner_participant_id, winner_name, winner_nominations,
   tie_decision_note, revealed_at, revealed_by)
values
  -- Three months ago: revealed with a clear winner.
  ('a4000000-0000-4000-8000-000000000001', 'a1000000-0000-4000-8000-00000000000a',
   (date_trunc('month', now()) - interval '3 months')::date, 'revealed',
   'Someone who went out of their way for a colleague this month.', 4,
   date_trunc('month', now()) - interval '3 months',
   date_trunc('month', now()) - interval '2 months' - interval '1 day',
   'a2000000-0000-4000-8000-000000000003', 'Cara Duffy', 3,
   null,
   date_trunc('month', now()) - interval '2 months', 'a0000000-0000-4000-8000-000000000001'),

  -- Two months ago: revealed after a tie, with the decision recorded. This is
  -- the case most likely to be got wrong in a UI, so it exists by default.
  ('a4000000-0000-4000-8000-000000000002', 'a1000000-0000-4000-8000-00000000000a',
   (date_trunc('month', now()) - interval '2 months')::date, 'revealed',
   'Someone who made a difficult month easier for the rest of us.', 4,
   date_trunc('month', now()) - interval '2 months',
   date_trunc('month', now()) - interval '1 month' - interval '1 day',
   'a2000000-0000-4000-8000-000000000002', 'Ben Ridley', 2,
   'Ben and Eli tied on two nominations each. Ben was chosen because rebuilding '
     || 'the rota after the storm week affected the whole site, and the team '
     || 'agreed on the day.',
   date_trunc('month', now()) - interval '1 month', 'a0000000-0000-4000-8000-000000000001'),

  -- Last month: closed and waiting to be revealed, so the reveal flow has a
  -- starting point that does not require running a whole cycle first.
  ('a4000000-0000-4000-8000-000000000003', 'a1000000-0000-4000-8000-00000000000a',
   (date_trunc('month', now()) - interval '1 month')::date, 'closed',
   'Someone whose work this month deserves saying out loud.', 3,
   date_trunc('month', now()) - interval '1 month',
   date_trunc('month', now()) - interval '1 day',
   null, null, null, null, null, null),

  -- This month: open and partially voted.
  ('a4000000-0000-4000-8000-000000000004', 'a1000000-0000-4000-8000-00000000000a',
   date_trunc('month', now())::date, 'open',
   'Someone who went out of their way for a colleague or a customer this month.', 2,
   date_trunc('month', now()),
   date_trunc('month', now()) + interval '1 month' - interval '1 day',
   null, null, null, null, null, null);

-- ---------------------------------------------------------------------------
-- Ballots
-- ---------------------------------------------------------------------------
--
-- nominator_participant_id must belong to nominator_user_id or the trigger
-- rejects the row, so these pairs are written out rather than generated.

insert into public.recognition_nominations
  (organisation_id, cycle_id, nominator_user_id, nominator_participant_id,
   nominee_participant_id, reason, status)
values
  -- Three months ago: Cara wins with three.
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000003', 'Covered the front desk for a week at no notice.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000003', 'Kept everyone calm during the lift failure.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000001',
   'a0000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000005',
   'a2000000-0000-4000-8000-000000000003', 'Trained two new starters without being asked.', 'active'),

  -- Two months ago: a genuine 2-2 tie between Ben and Eli.
  --
  -- The arrangement is constrained. Four people can vote, nobody may vote for
  -- themselves, so a 2-2 tie between Ben and Eli requires Ben's two votes to
  -- come from Ana and Eli, and Eli's from Cara and Ben. Any other pairing
  -- produces a clear leader. Worth stating, because an earlier version of this
  -- seed carried a tie decision note on a cycle that was not tied.
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000002', 'Rebuilt the rota after the storm week.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000005',
   'a2000000-0000-4000-8000-000000000002', 'Stayed late twice to finish a handover properly.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000003',
   'a2000000-0000-4000-8000-000000000005', 'Fixed the boiler before anyone noticed it had gone.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000002',
   'a0000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000005', 'Kept the whole site running through the shutdown.', 'active'),

  -- Last month, closed: includes a hidden ballot so moderation views have
  -- something to show, and a withdrawn one so the slot rule is visible.
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000001', 'a2000000-0000-4000-8000-000000000001',
   'a2000000-0000-4000-8000-000000000005', 'Took on the whole maintenance backlog.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000002', 'a2000000-0000-4000-8000-000000000002',
   'a2000000-0000-4000-8000-000000000005', 'Never once left a job half finished.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000003',
   'a0000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000003',
   'a2000000-0000-4000-8000-000000000001', 'Sorted the invoicing mess out.', 'withdrawn'),

  -- This month, open: two of four eligible voters have cast so far, so turnout
  -- shows a partial figure rather than 0 or 100.
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000004',
   'a0000000-0000-4000-8000-000000000003', 'a2000000-0000-4000-8000-000000000003',
   'a2000000-0000-4000-8000-000000000002', 'Talked a furious customer round with real patience.', 'active'),
  ('a1000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000004',
   'a0000000-0000-4000-8000-000000000005', 'a2000000-0000-4000-8000-000000000005',
   'a2000000-0000-4000-8000-000000000001', 'Picked up the on-call twice so others could rest.', 'active');

-- The hidden ballot needs its moderation fields, which the table constraint
-- requires, so it is updated rather than inserted as hidden.
update public.recognition_nominations
set status = 'hidden',
    moderated_by = 'a0000000-0000-4000-8000-000000000002',
    moderated_at = now() - interval '20 days',
    moderation_reason = 'Named a customer and described a health matter.'
where cycle_id = 'a4000000-0000-4000-8000-000000000003'
  and nominee_participant_id = 'a2000000-0000-4000-8000-000000000005'
  and nominator_user_id = 'a0000000-0000-4000-8000-000000000002';

-- ---------------------------------------------------------------------------
-- Beta Ltd: deliberately too small for confidentiality to hold
-- ---------------------------------------------------------------------------
--
-- Two eligible voters, which assessConfidentiality grades 'determined': an
-- administrator who voted can work out the other person's ballot by subtraction.
-- It exists so the FR-CYCLE-04 warning is visible during development rather than
-- being something only the tests ever see, and so tenant isolation is exercised
-- against a real second organisation.

insert into public.organisations (id, name, timezone, created_by) values
  ('b1000000-0000-4000-8000-00000000000b', 'Beta Studio', 'Europe/Dublin',
   'b0000000-0000-4000-8000-000000000001');

insert into public.organisation_members (organisation_id, user_id, role, status) values
  ('b1000000-0000-4000-8000-00000000000b', 'b0000000-0000-4000-8000-000000000001', 'owner',  'active'),
  ('b1000000-0000-4000-8000-00000000000b', 'b0000000-0000-4000-8000-000000000002', 'member', 'active');

insert into public.participants
  (id, organisation_id, user_id, display_name, active, can_vote, can_receive) values
  ('b2000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-00000000000b',
   'b0000000-0000-4000-8000-000000000001', 'Gus Whelan', true, true, true),
  ('b2000000-0000-4000-8000-000000000002', 'b1000000-0000-4000-8000-00000000000b',
   'b0000000-0000-4000-8000-000000000002', 'Hana Reyes', true, true, true);

insert into public.recognition_settings (organisation_id, retention_months) values
  ('b1000000-0000-4000-8000-00000000000b', 3);

insert into public.recognition_cycles
  (id, organisation_id, period_month, status, criteria, version, opens_at, closes_at)
values
  ('b4000000-0000-4000-8000-000000000001', 'b1000000-0000-4000-8000-00000000000b',
   date_trunc('month', now())::date, 'open',
   'Someone who made this month better.', 2,
   date_trunc('month', now()),
   date_trunc('month', now()) + interval '1 month' - interval '1 day');
