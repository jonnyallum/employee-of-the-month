# apply-smtp-config.ps1 - point the linked Supabase project's Auth mailer at
# Resend instead of the built-in Supabase mail service.
#
# The built-in mailer allows two messages an hour and only delivers to members
# of the Supabase project, so invitation and verification journeys cannot be
# tested with it, let alone shipped.
#
# Needs credentials from two vault projects at once: the Supabase project
# reference and access token from this product, and the Resend key from jonnyai.
#
#   .\scripts\with-vault.ps1 -Project employee-of-the-month-dev,jonnyai `
#     -- powershell -NoProfile -File .\scripts\apply-smtp-config.ps1
#
#   add -WhatIf to see the diff without changing anything
#
# Sending domain: jonnyai.co.uk on the shared jonnyai Resend account. Its DKIM
# and SPF records are verified. The domain also shows a failed inbound
# "Receiving MX" record, which does not affect sending and which this product
# does not use.
#
# Because the credential is shared, rotating the jonnyai Resend key breaks this
# project's auth mail until this script is re-run. That is the trade accepted in
# exchange for not standing up a second Resend account.

param([switch]$WhatIf)

$ErrorActionPreference = "Stop"

$ref = $env:SUPABASE_PROJECT_REF
$token = $env:SUPABASE_ACCESS_TOKEN
$resend = $env:RESEND_API_KEY

if (-not $ref -or -not $token) { Write-Host "Missing Supabase credentials."; exit 1 }
if (-not $resend) { Write-Host "Missing RESEND_API_KEY. Include the jonnyai vault project."; exit 1 }
if (-not $resend.StartsWith("re_")) { Write-Host "RESEND_API_KEY does not look like a Resend key."; exit 1 }

# Confirm the key still works and the sending domain is present before writing
# it into Supabase, so a dead key cannot be installed silently. The bizos copy
# of this key is already dead (401), which is exactly the failure this catches.
$senderDomain = "jonnyai.co.uk"
try {
  $domains = Invoke-RestMethod -Uri "https://api.resend.com/domains" `
    -Headers @{ Authorization = "Bearer $resend" } -TimeoutSec 20
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

# smtp_pass is never returned by the API, so it cannot be diffed. Always send it
# when anything else changes, and report only whether one is now configured.
Write-Host ("SMTP password currently configured: {0}" -f [bool]$before.smtp_pass)

if (-not $changes) { Write-Host "`nAlready configured. Re-run with -Force behaviour not needed."; exit 0 }
if ($WhatIf) { Write-Host "`n-WhatIf set, no change made."; exit 0 }

$body = @{ smtp_pass = $resend }
foreach ($name in $changes) { $body[$name] = $desired[$name] }
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
