-- The privacy notice has to be able to say how long the residual ballot record
-- is kept, now that D-036 gave it an end date.
--
-- This is a deliberate exposure decision rather than a follow-up chore. The
-- column was added by D-036 with no client grant, because every table in this
-- schema starts closed and is opened a column at a time. That worked: the
-- notice could not read it, which is how the gap was noticed rather than
-- silently shipped.
--
-- Granting it is right. Articles 13 and 14 require the retention period to be
-- disclosed to the data subject, and a notice that states one of the two
-- retention periods and stays quiet about the other is the kind of half-truth
-- D-031 was written to remove. The value is a per-organisation setting, not
-- personal data, and it tells a member nothing about any colleague.

grant select (residual_retention_months) on public.recognition_settings
  to authenticated;

comment on column public.recognition_settings.residual_retention_months is
  'How long the purged ballot row survives after its reason and nominee link '
  'were removed. Null means indefinite, which is the controller''s call to '
  'defend under Article 5(1)(e). Readable by members because the privacy '
  'notice must state it (Articles 13 and 14).';
