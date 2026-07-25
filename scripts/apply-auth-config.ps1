# apply-auth-config.ps1 - bring the linked Supabase project's Auth settings to
# the baseline this product requires, instead of leaving them at Supabase
# defaults. Idempotent: it reports the before and after value of each field and
# is safe to re-run.
#
#   .\scripts\with-vault.ps1 -- powershell -NoProfile -File .\scripts\apply-auth-config.ps1
#   add -WhatIf to see the diff without changing anything
#
# Why each value:
#   password_min_length            Supabase ships 6, which is below any current
#                                  guidance. 12 with mixed classes is a
#                                  reasonable mobile baseline.
#   password_required_characters   Lower, upper and digits. Symbols are left out
#                                  deliberately: on a phone keyboard they cost
#                                  more in abandoned sign-ups than they add in
#                                  entropy at this length.
#   password_hibp_enabled          Rejects passwords in the HaveIBeenPwned
#                                  corpus. This is the project's only open
#                                  security advisor.
#   site_url / uri_allow_list      Default is http://localhost:3000, which suits
#                                  a web app and not this one. Auth redirects
#                                  must reach the app's own scheme, otherwise
#                                  invitation and recovery links cannot open the
#                                  app. Anything not on this list is refused,
#                                  which is what stops an open redirect.

param([switch]$WhatIf)

$ErrorActionPreference = "Stop"

$ref = $env:SUPABASE_PROJECT_REF
$token = $env:SUPABASE_ACCESS_TOKEN
if (-not $ref -or -not $token) {
  Write-Host "Run this through scripts\with-vault.ps1 so the credentials are present."
  exit 1
}

$scheme = "uk.co.jonnyai.employeeofthemonth"

# Local web dev server is allowed so recovery links can be exercised in a
# browser during development. Expo Go's exp:// URLs are deliberately NOT
# allowed: that pattern has to be a wildcard over a host we do not control.
# This product needs a native dev build for FCM anyway, and the custom scheme
# works there.
$desired = [ordered]@{
  password_min_length          = 12
  password_required_characters = "abcdefghijklmnopqrstuvwxyz:ABCDEFGHIJKLMNOPQRSTUVWXYZ:0123456789"
  password_hibp_enabled        = $true
  site_url                     = "${scheme}://"
  uri_allow_list               = "${scheme}://**,http://localhost:8081/**"
}

# Fields Supabase gates behind a paid plan. The management API rejects the whole
# PATCH if one of these is included on a Free project, so they are attempted
# separately and reported rather than allowed to block the rest.
$planGated = @("password_hibp_enabled")

$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$uri = "https://api.supabase.com/v1/projects/$ref/config/auth"

$before = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 20

$changes = @()
foreach ($name in $desired.Keys) {
  $current = $before.$name
  if ("$current" -ne "$($desired[$name])") {
    $changes += $name
    Write-Host ("CHANGE {0}`n   from: {1}`n     to: {2}" -f $name, $current, $desired[$name])
  }
  else {
    Write-Host ("OK     {0} = {1}" -f $name, $current)
  }
}

if (-not $changes) { Write-Host "`nAlready at the baseline. Nothing to do."; exit 0 }

if ($WhatIf) { Write-Host "`n-WhatIf set, no change made."; exit 0 }

Write-Host ""

function Patch($fields) {
  $body = @{}
  foreach ($name in $fields) { $body[$name] = $desired[$name] }
  Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch `
    -Body ($body | ConvertTo-Json -Compress) -TimeoutSec 30 | Out-Null
}

$gatedMessages = @{}

$plain = @($changes | Where-Object { $planGated -notcontains $_ })
if ($plain) { Patch $plain }

foreach ($name in @($changes | Where-Object { $planGated -contains $_ })) {
  try { Patch @($name) }
  catch {
    $body = ""
    if ($_.Exception.Response) {
      $body = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd()
    }
    $gatedMessages[$name] = if ($body) { $body } else { $_.Exception.Message }
  }
}

# Read it back rather than trusting the write.
$after = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 20
$failed = @()
foreach ($name in $desired.Keys) {
  if ("$($after.$name)" -eq "$($desired[$name])") {
    Write-Host ("[PASS] {0} = {1}" -f $name, $after.$name)
  }
  elseif ($gatedMessages.ContainsKey($name)) {
    Write-Host ("[SKIP] {0} still {1} - {2}" -f $name, $after.$name, ($gatedMessages[$name] -replace '\s+', ' '))
  }
  else {
    Write-Host ("[FAIL] {0} = {1}" -f $name, $after.$name)
    $failed += $name
  }
}

if ($failed) { Write-Host "`nNot applied: $($failed -join ', ')"; exit 1 }
if ($gatedMessages.Count) {
  Write-Host "`nAuth baseline applied except $($gatedMessages.Keys -join ', '), which the current plan does not allow."
  exit 0
}
Write-Host "`nAuth baseline applied and read back."
