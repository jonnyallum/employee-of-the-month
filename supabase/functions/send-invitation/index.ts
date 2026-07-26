/**
 * COM-001: create an invitation and email it.
 *
 * This exists because the token cannot travel through the browser. The client
 * asks for an invitation to be sent; the token is created, used and discarded
 * entirely server-side, and the caller learns only that a message went out and
 * when it expires.
 *
 * Authorisation is not re-implemented here. The function calls
 * `create_invitation` with the CALLER's own JWT, so the database applies the
 * same owner-or-admin check it applies to everything else. A bug in this file
 * cannot grant anybody more than they already had, which is the reason to do it
 * this way rather than validating a role in TypeScript.
 *
 * The service role is used for exactly one thing: writing the delivery record,
 * which has no client grant. Per D-025 that is acceptable in development and
 * becomes a purpose-made role before production.
 */

import { createClient } from 'jsr:@supabase/supabase-js@2';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/**
 * Nothing in this function logs an email address, a token or a participant
 * name. An invitation log that names people rebuilds the employee list in
 * whatever aggregates the logs, which is precisely the data the schema refuses
 * to expose.
 */
function log(event: string, detail: Record<string, unknown> = {}) {
  console.log(JSON.stringify({ event, ...detail }));
}

/**
 * An SMTP failure has to be diagnosable, and its message often quotes the
 * envelope, which means the recipient. Logging the message raw would put
 * employee addresses in whatever aggregates the logs, so addresses are removed
 * before anything is written.
 *
 * The first version of this logged only `error.name`, which for almost every
 * failure is the word "Error" and diagnosed nothing.
 */
function redact(value: unknown): string {
  const text =
    value instanceof Error ? `${value.name}: ${value.message}` : String(value);
  return text.replace(/[\w.+-]+@[\w.-]+/g, '[address]');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS')
    return new Response('ok', { headers: CORS });
  if (request.method !== 'POST') return json({ error: 'method' }, 405);

  const authorization = request.headers.get('Authorization') ?? '';
  if (!authorization) return json({ error: 'unauthorised' }, 401);

  let participantId: string;
  let email: string;
  try {
    const body = await request.json();
    participantId = String(body.participantId ?? '');
    email = String(body.email ?? '')
      .trim()
      .toLowerCase();
  } catch {
    return json({ error: 'bad_request' }, 400);
  }
  if (!participantId || !email.includes('@')) {
    return json({ error: 'bad_request' }, 400);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';

  // Acting as the caller. The database decides whether they may invite.
  const asCaller = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    { global: { headers: { Authorization: authorization } } },
  );

  const { data, error } = await asCaller.rpc('create_invitation', {
    target_participant_id: participantId,
    invited_email: email,
  });

  if (error) {
    log('invitation.refused', { hint: error.hint ?? null, code: error.code });
    // The database's own product code is passed back so the client can show the
    // same wording it would for a direct call. No message text is forwarded,
    // because that can carry row detail.
    return json({ error: 'refused', hint: error.hint ?? null }, 403);
  }

  const issued = (data ?? [])[0];
  if (!issued) return json({ error: 'refused' }, 403);

  const service = createClient(
    supabaseUrl,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  // Idempotency. The key is the invitation id, so a retried request that
  // produced a new invitation sends again, which is correct: reissuing revokes
  // the previous token. What it prevents is the same invitation being emailed
  // twice because a caller retried after a timeout that had in fact succeeded.
  const idempotencyKey = `invitation:${issued.invitation_id}`;
  const { error: claimError } = await service
    .from('notification_deliveries')
    .insert({
      idempotency_key: idempotencyKey,
      event_type: 'invitation',
      channel: 'email',
      result: 'sending',
    });

  if (claimError) {
    // Only a unique violation means "already sent". Treating every insert
    // failure that way, which this did at first, turns a broken delivery record
    // into a silent success: the caller is told the invitation went out and
    // nothing was ever emailed. Anything other than 23505 is a real fault and
    // must say so.
    if (claimError.code === '23505') {
      log('invitation.already_sent', { invitation: issued.invitation_id });
      return json({
        ok: true,
        alreadySent: true,
        expiresAt: issued.expires_at,
      });
    }
    log('invitation.claim_failed', {
      invitation: issued.invitation_id,
      code: claimError.code,
      message: claimError.message,
    });
    return json({ error: 'delivery_record_failed' }, 500);
  }

  const inviteUrl = `${Deno.env.get('APP_INVITE_URL') ?? 'https://employee-of-the-month.invalid/invite'}?token=${issued.token}`;

  const from =
    Deno.env.get('MAIL_FROM') ??
    'Employee of the Month <recognition@jonnyai.co.uk>';
  const subject = 'You have been invited to Employee of the Month';
  const expires = new Date(issued.expires_at).toDateString();
  const text =
    `You have been invited to take part in your team's Employee of the Month.

` +
    `Open this link to accept:
${inviteUrl}

` +
    `The link works once and expires on ${expires}.

` +
    `Nominations are confidential. Administrators see the result and how many ` +
    `people voted, never who voted for whom.
`;
  const html =
    `<p>You have been invited to take part in your team's Employee of the Month.</p>` +
    `<p><a href="${inviteUrl}">Accept your invitation</a></p>` +
    `<p>The link works once and expires on ${expires}.</p>` +
    `<p>Nominations are confidential. Administrators see the result and how many ` +
    `people voted, never who voted for whom.</p>`;

  try {
    await deliver({ from, to: email, subject, text, html });

    await service
      .from('notification_deliveries')
      .update({ result: 'sent' })
      .eq('idempotency_key', idempotencyKey);

    log('invitation.sent', { invitation: issued.invitation_id });
    return json({ ok: true, expiresAt: issued.expires_at });
  } catch (caught) {
    await service
      .from('notification_deliveries')
      .update({
        result: 'failed',
        error_code: caught instanceof Error ? caught.name : 'unknown',
      })
      .eq('idempotency_key', idempotencyKey);

    log('invitation.send_failed', {
      invitation: issued.invitation_id,
      transport: Deno.env.get('MAIL_TRANSPORT') ?? 'resend',
      error: redact(caught),
    });
    return json({ error: 'send_failed' }, 502);
  }
});

interface Message {
  from: string;
  to: string;
  subject: string;
  text: string;
  html: string;
}

/**
 * Two transports, chosen by environment.
 *
 * Both are a single fetch, which is why there is no mail library here. A
 * dependency inside a function that handles invitation tokens is a dependency
 * with access to invitation tokens, and the first one tried refused to talk to
 * a local mail catcher at all because the catcher advertises AUTH over
 * plaintext.
 *
 * Worth being straight about the trade: the local transport exercises this
 * function, the template and the token flow, but it does not exercise Resend.
 * Only a real send does that, which is what INF-016 covers.
 */
async function deliver(message: Message): Promise<void> {
  const transport = Deno.env.get('MAIL_TRANSPORT') ?? 'resend';

  if (transport === 'mailpit') {
    const base = Deno.env.get('MAILPIT_URL') ?? 'http://127.0.0.1:8025';
    const response = await fetch(`${base}/api/v1/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        From: { Email: message.from.replace(/^.*</, '').replace(/>$/, '') },
        To: [{ Email: message.to }],
        Subject: message.subject,
        Text: message.text,
        HTML: message.html,
      }),
    });
    if (!response.ok) {
      throw new Error(`mailpit responded ${response.status}`);
    }
    return;
  }

  const key = Deno.env.get('RESEND_API_KEY') ?? '';
  if (!key) throw new Error('no RESEND_API_KEY configured');

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${key}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: message.from,
      to: [message.to],
      subject: message.subject,
      text: message.text,
      html: message.html,
    }),
  });
  if (!response.ok) {
    // The body can quote the recipient, so it is redacted before it is raised.
    throw new Error(
      `resend responded ${response.status}: ${redact(await response.text())}`,
    );
  }
}
