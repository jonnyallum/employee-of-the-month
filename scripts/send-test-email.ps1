# send-test-email.ps1 - INF-003 evidence. Sends ONE real auth email through the
# configured SMTP provider and reports what the server said.
#
#   .\scripts\with-vault.ps1 -- powershell -NoProfile -File .\scripts\send-test-email.ps1 -To someone@example.com
#
# This SENDS A REAL MESSAGE to a real person. It takes the recipient as a
# required argument with no default, so it cannot be run absent-mindedly.
#
# It deliberately uses the magic-link endpoint rather than sign-up: it exercises
# the same Auth mailer without inventing a password that would then need storing
# or discarding. It also uses the publishable key over HTTPS, which is exactly
# the path the Android app will take, so a pass here means the app's own
# verification mail works rather than merely that the SMTP settings parse.
#
# A 200 means Supabase accepted the request AND handed the message to the SMTP
# provider. A misconfigured mailer fails here rather than succeeding quietly,
# which is what makes this worth running. Delivery to the inbox still has to be
# confirmed by a human looking at it: spam placement and DMARC alignment are not
# visible from this side.

param(
  [Parameter(Mandatory = $true)][string]$To,
  # Default false so an existing account is not silently created by a test.
  [switch]$CreateUser
)

$ErrorActionPreference = "Stop"

$url = $env:EXPO_PUBLIC_SUPABASE_URL
$key = $env:EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY
if (-not $url -or -not $key) { Write-Host "Run through scripts\with-vault.ps1."; exit 1 }

$body = @{ email = $To; create_user = [bool]$CreateUser } | ConvertTo-Json -Compress

Write-Host "Sending one magic-link email to $To via $($url.TrimEnd('/'))/auth/v1/otp"
Write-Host "create_user = $([bool]$CreateUser)"
Write-Host ""

$started = Get-Date
try {
  $r = Invoke-WebRequest -Uri "$($url.TrimEnd('/'))/auth/v1/otp" -Method Post `
    -Headers @{ apikey = $key; "Content-Type" = "application/json" } `
    -Body $body -UseBasicParsing -TimeoutSec 45
  $elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
  Write-Host "[PASS] HTTP $($r.StatusCode) after ${elapsed}s"
  Write-Host "       Supabase accepted the request and handed it to the SMTP provider."
  Write-Host "       $($r.Content)"
  Write-Host ""
  Write-Host "Now confirm by hand: did it arrive, which folder, and is the sender"
  Write-Host "shown as expected? Inbox placement cannot be checked from here."
}
catch {
  $elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
  $resp = $_.Exception.Response
  if ($resp) {
    $status = [int]$resp.StatusCode
    $detail = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
    Write-Host "[FAIL] HTTP $status after ${elapsed}s"
    Write-Host "       $detail"
    Write-Host ""
    if ($status -eq 429) {
      Write-Host "Rate limited. smtp_max_frequency allows one message per address"
      Write-Host "per 60 seconds, and rate_limit_email_sent caps the project at 100"
      Write-Host "per hour. Wait and retry rather than raising the limits."
    }
    elseif ($status -ge 500) {
      Write-Host "A 5xx here usually means the SMTP credentials or sender address"
      Write-Host "were rejected by the provider. Re-run scripts\apply-smtp-config.ps1"
      Write-Host "and check the sender domain is verified for sending."
    }
  }
  else { Write-Host "[FAIL] $($_.Exception.Message)" }
  exit 1
}
