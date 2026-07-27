-- What the trusted server may write.
--
-- Found while building the invitation mailer: `service_role` held only
-- REFERENCES, TRIGGER and TRUNCATE on every table, so the first Edge Function
-- to write anything failed with `42501 permission denied`.
--
-- The useful lesson is that `BYPASSRLS` and a table privilege are different
-- things. service_role carries BYPASSRLS, which is why it is easy to assume it
-- can do anything, but that attribute only exempts it from *policies*. Without
-- a GRANT there is nothing for a policy to be exempt from. Every earlier test
-- passed because nothing server-side had tried to write yet.
--
-- The fix is deliberately not `grant all on all tables`. That would hand the
-- trusted role the ballot table, and the whole point of D-025 is to move toward
-- per-function roles rather than away from them. Only the two tables that code
-- actually writes today are granted, and only the verbs that code uses. The
-- next server job adds its own line and has to justify it in review.

-- The invitation mailer claims an idempotency key, then updates the row to
-- record whether the send succeeded. It reads nothing else.
grant select, insert, update on public.notification_deliveries to service_role;

-- Server-side actions are audited the same way user actions are. Append only:
-- no update or delete, because an audit trail a process can rewrite is not one.
grant insert on public.audit_events to service_role;

comment on table public.notification_deliveries is
  'Delivery bookkeeping. Carries no nomination or winner content. The unique '
  'idempotency key is what makes a retried reminder job safe to re-run. '
  'Written by trusted server functions, which hold select, insert and update '
  'here and nothing else.';
