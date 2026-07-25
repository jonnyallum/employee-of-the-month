# apply-smtp-config.ps1 - point the linked Supabase project's Auth mailer at
# Resend instead of the built-in Supabase mail service.
#
# The built-in mailer allows two messages an hour and only delivers to members
# of the Supabase project, so invitation and verification journeys cannot be
# tested with it, let alone shipped.
#
#   .\scripts\with-vault.ps1 -- powershell -NoProfile -File .\scripts\apply-smtp-config.ps1
#
#   add -WhatIf to see the diff without changing anything
#
# Uses this product's own `RESEND_API_KEY` from jvault project
# `employee-of-the-month-dev`. It is a distinct key rather than a copy of the
# shared one, so rotating another product's Resend key no longer breaks sign-up
# here.
#
# Sending domain: jonnyai.co.uk. Its DKIM and SPF records are verified. The
# domain also shows a failed inbound "Receiving MX" record, which does not affect
# sending and which this product does not use. The Resend *account* is still
# shared, so an account-level suspension would affect several products; only the
# credential is now independent.

# -SetPassword writes the SMTP credential even when every other field already
# matches. Needed because the management API never returns smtp_pass, so a key
# rotation is invisible to a diff and would otherwise be skipped as a no-op.
param([switch]$WhatIf, [switch]$SetPassword)

$ErrorActionPreference = "Stop"

$ref = $env:SUPABASE_PROJECT_REF
$token = $env:SUPABASE_ACCESS_TOKEN
$resend = $env:RESEND_API_KEY

if (-not $ref -or -not $token) { Write-Host "Missing Supabase credentials."; exit 1 }
if (-not $resend) { Write-Host "Missing RESEND_API_KEY in this vault project."; exit 1 }
if (-not $resend.StartsWith("re_")) { Write-Host "RESEND_API_KEY does not look like a Resend key."; exit 1 }

# Confirm the key works and the sending domain exists before writing it into
# Supabase, so a dead credential cannot be installed silently. The copy of the
# shared key in jvault project `bizos` is already dead (401), which is exactly
# the failure this catches.
$senderDomain = "jonnyai.co.uk"
$resendHeaders = @{ Authorization = "Bearer $resend" }
try {
  $domains = Invoke-RestMethod -Uri "https://api.resend.com/domains" `
    -Headers $resendHeaders -TimeoutSec 20
}
catch {
  Write-Host "Resend rejected this key: $($_.Exception.Message)"
  exit 1
}
if (-not ($domains.data | Where-Object { $_.name -eq $senderDomain })) {
  Write-Host "Resend account has no '$senderDomain' domain."
  exit 1
}
Write-Host "Resend key valid and '$senderDomain' present."

# Least privilege. All this credential needs to do is send. If it can also list
# and create API keys, then anything that can read the Supabase auth config can
# mint further credentials on the Resend account. Resend cannot narrow an
# existing key's permission, so this is a warning rather than a failure: the fix
# is to create a replacement key with "Sending access" only.
try {
  Invoke-RestMethod -Uri "https://api.resend.com/api-keys" -Headers $resendHeaders -TimeoutSec 20 | Out-Null
  Write-Host ""
  Write-Host "WARNING: this key has full access, not sending-only. It can list and"
  Write-Host "         create Resend API keys. Replace it with a key restricted to"
  Write-Host "         'Sending access' scoped to $senderDomain, then re-run."
  Write-Host ""
}
catch {
  Write-Host "Key is sending-scoped: it cannot list Resend API keys."
}

$desired = [ordered]@{
  smtp_host             = "smtp.resend.com"
  # A string, not a number: the management API rejects an integer here.
  smtp_port             = "587"
  smtp_user             = "resend"
  smtp_admin_email      = "recognition@$senderDomain"
  smtp_sender_name      = "Employee of the Month"
  # One auth mail per address per 60 seconds. Enough for a real person who
  # mistypes and retries, tight enough that the endpoint is not a mail cannon.
  smtp_max_frequency    = 60
  # Per hour, project wide. The built-in mailer caps this at 2.
  rate_limit_email_sent = 100
}

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$uri = "https://api.supabase.com/v1/projects/$ref/config/auth"
$before = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 20

$changes = @()
foreach ($name in $desired.Keys) {
  if ("$($before.$name)" -ne "$($desired[$name])") {
    $changes += $name
    Write-Host ("CHANGE {0}: {1} -> {2}" -f $name, $before.$name, $desired[$name])
  }
  else { Write-Host ("OK     {0} = {1}" -f $name, $before.$name) }
}

# smtp_pass is never returned by the API, so it cannot be diffed. Only its
# presence can be reported.
Write-Host ("SMTP password currently configured: {0}" -f [bool]$before.smtp_pass)

if (-not $changes -and -not $SetPassword) {
  Write-Host "`nAlready configured. Pass -SetPassword to rotate the credential."
  exit 0
}
if ($WhatIf) {
  if ($SetPassword) { Write-Host "`nWould also write the SMTP password." }
  Write-Host "-WhatIf set, no change made."
  exit 0
}

# Send the WHOLE desired set, not just the changed subset. Supabase treats the
# SMTP block as a unit: a PATCH carrying smtp_pass but omitting smtp_host and
# friends clears them all, silently reverting the project to the built-in mailer
# and its 2-per-hour cap. Found the hard way.
$body = @{ smtp_pass = $resend }
foreach ($name in $desired.Keys) { $body[$name] = $desired[$name] }
Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch `
  -Body ($body | ConvertTo-Json -Compress) -TimeoutSec 30 | Out-Null

$after = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 20
$failed = @()
Write-Host ""
foreach ($name in $desired.Keys) {
  $ok = ("$($after.$name)" -eq "$($desired[$name])")
  Write-Host ("[{0}] {1} = {2}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $name, $after.$name)
  if (-not $ok) { $failed += $name }
}

if ($failed) { Write-Host "`nNot applied: $($failed -join ', ')"; exit 1 }
Write-Host "`nAuth mail now goes through Resend. An end-to-end send has NOT been"
Write-Host "performed: that needs a real recipient address and Jonny's go-ahead."
