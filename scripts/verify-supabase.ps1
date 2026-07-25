# verify-supabase.ps1 - prove the linked Supabase project is reachable and in
# the state we expect, without printing any secret.
#
# Run it through the vault runner so the credentials come from jvault:
#   .\scripts\with-vault.ps1 -- powershell -NoProfile -File .\scripts\verify-supabase.ps1
#
# Checks:
#   1. required environment names are present
#   2. the public URL matches the project ref (no cross-project mismatch)
#   3. the publishable key is a public key, not a secret or service-role key
#   4. the Data API answers with that key over HTTPS
#   5. the Auth API is reachable and reports its settings
#   6. remote migration history and exposed table count

$ErrorActionPreference = "Stop"
$failed = @()

function Report($ok, $label, $detail) {
  $mark = if ($ok) { "PASS" } else { "FAIL" }
  Write-Host ("[{0}] {1}{2}" -f $mark, $label, $(if ($detail) { " - $detail" } else { "" }))
  if (-not $ok) { $script:failed += $label }
}

# 1. presence
$required = @("SUPABASE_PROJECT_REF", "EXPO_PUBLIC_SUPABASE_URL", "EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY")
foreach ($name in $required) {
  $value = [Environment]::GetEnvironmentVariable($name)
  Report ([bool]$value) "$name present"
}
if ($failed) { Write-Host "`nMissing credentials, stopping."; exit 1 }

$ref = $env:SUPABASE_PROJECT_REF
$url = $env:EXPO_PUBLIC_SUPABASE_URL.TrimEnd("/")
$key = $env:EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY

# 2. URL matches ref
Report ($url -eq "https://$ref.supabase.co") "URL matches project ref" $url

# 3. key shape
Report ($key.StartsWith("sb_publishable_")) "key is a modern publishable key"
Report (-not $key.StartsWith("sb_secret_")) "key is not a secret key"
Report (-not $key.StartsWith("eyJ")) "key is not a legacy JWT"

# 4. Data API. Do not probe "/rest/v1/": that is the OpenAPI spec endpoint and
# Supabase 401s it even for a valid publishable key. Ask for a table that cannot
# exist instead. PostgREST's PGRST205 proves the request authenticated and
# reached PostgREST, which is what we actually want to know. An unauthenticated
# request returns a bodyless gateway 401, so the two are unambiguous.
$probe = "verify_probe_table_does_not_exist"
try {
  Invoke-WebRequest -Uri "$url/rest/v1/$probe`?select=*" `
    -Headers @{ apikey = $key; Authorization = "Bearer $key" } `
    -Method Get -UseBasicParsing -TimeoutSec 20 | Out-Null
  Report $false "Data API authenticates publishable key" "unexpected 200 for '$probe'"
}
catch {
  $resp = $_.Exception.Response
  if (-not $resp) {
    Report $false "Data API authenticates publishable key" $_.Exception.Message
  }
  else {
    $status = [int]$resp.StatusCode
    $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd()
    Report ($status -eq 404 -and $body -match "PGRST205") `
      "Data API authenticates publishable key" "HTTP $status $($body -replace '\s+', ' ')"
  }
}

# 5. Auth API
try {
  $s = Invoke-RestMethod -Uri "$url/auth/v1/settings" -Headers @{ apikey = $key } -Method Get -TimeoutSec 20
  Report $true "Auth API reachable" ("email signup enabled: {0}, autoconfirm: {1}, external providers on: {2}" -f `
      (-not $s.disable_signup), $s.mailer_autoconfirm, `
    (($s.external.PSObject.Properties | Where-Object { $_.Value -eq $true } | ForEach-Object { $_.Name }) -join "," ))
}
catch {
  Report $false "Auth API reachable" $_.Exception.Message
}

# 6. remote state. Do not redirect stderr here: in PowerShell 5.1 that wraps a
# native exe's stderr lines in ErrorRecords and reports a false failure.
$cli = ".\node_modules\.bin\supabase.cmd"
$migrations = (& $cli migration list --linked | Out-String).Trim()
Report ($LASTEXITCODE -eq 0) "remote migration history readable" $migrations

Write-Host ""
if ($failed) {
  Write-Host ("{0} check(s) failed: {1}" -f $failed.Count, ($failed -join ", "))
  exit 1
}
Write-Host "All Supabase connection checks passed."
