# push-schema.ps1 - apply local migrations to the linked Supabase project.
#
#   .\scripts\with-vault.ps1 -- powershell -NoProfile -File .\scripts\push-schema.ps1
#   add -DryRun to list what would be applied without applying it
#
# Uses a direct database URL rather than plain `supabase db push`. The CLI's
# login-role provisioning step returns 403 for this account
# (LegacyDbConfigLoginRoleStatusError) even though the access token is valid and
# the management API accepts it. Connecting straight to Postgres skips that step
# and still writes the same migration history, so `migration list` stays
# meaningful afterwards.
#
# The password is URL-encoded and never printed. It reaches the CLI as an
# argument to a single command and nowhere else.

param([switch]$DryRun)

$ErrorActionPreference = "Stop"

$ref = $env:SUPABASE_PROJECT_REF
$password = $env:SUPABASE_DB_PASSWORD
if (-not $ref -or -not $password) {
  Write-Host "Run through scripts\with-vault.ps1."
  exit 1
}

$encoded = [uri]::EscapeDataString($password)

# The pooler, not db.<ref>.supabase.co. Direct connections are IPv6-only, which
# this machine cannot reach, so a direct URL fails with "Failed to connect"
# rather than anything that names the real cause. Port 5432 is session mode,
# which migrations need; 6543 is transaction mode and cannot run them.
$region = if ($env:SUPABASE_DB_REGION) { $env:SUPABASE_DB_REGION } else { "eu-west-1" }
$candidates = @(
  "postgresql://postgres.$($ref):$encoded@aws-0-$region.pooler.supabase.com:5432/postgres",
  "postgresql://postgres.$($ref):$encoded@aws-1-$region.pooler.supabase.com:5432/postgres",
  "postgresql://postgres:$encoded@db.$ref.supabase.co:5432/postgres"
)

$cli = ".\node_modules\.bin\supabase.cmd"

$dbUrl = $null
foreach ($candidate in $candidates) {
  $hostOnly = (($candidate -split '@')[1] -split ':')[0]
  # No 2>&1. Redirecting a native executable's stderr in Windows PowerShell 5.1
  # wraps each line in an ErrorRecord and reports a failure even on exit code 0.
  # This is documented in the build log and was still worth rediscovering.
  & $cli migration list --db-url $candidate | Out-Null
  if ($LASTEXITCODE -eq 0) {
    $dbUrl = $candidate
    Write-Host "Connected via $hostOnly"
    break
  }
  Write-Host "  no route via $hostOnly"
}
if (-not $dbUrl) { Write-Host "Could not reach the database on any known host."; exit 1 }

Write-Host "Local migrations:"
Get-ChildItem supabase\migrations\*.sql | ForEach-Object { "  $($_.Name)" }
Write-Host ""

if ($DryRun) {
  Write-Host "Remote migration history:"
  & $cli migration list --db-url $dbUrl
  Write-Host ""
  Write-Host "-DryRun set, nothing applied."
  exit 0
}

Write-Host "Applying to $ref ..."
& $cli db push --db-url $dbUrl --include-all
if ($LASTEXITCODE -ne 0) { Write-Host "push failed."; exit 1 }

Write-Host ""
Write-Host "Remote migration history now:"
& $cli migration list --db-url $dbUrl
