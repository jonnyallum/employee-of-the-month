# with-vault.ps1 - run a command with the jvault project's secrets in the
# environment. Secret VALUES are never printed; only key names.
#
# The passphrase comes from $env:JVAULT_PASSPHRASE if set, otherwise from
# %USERPROFILE%\.jvault\passphrase.dpapi, which is DPAPI-encrypted to the jonny
# Windows account. Delete that file to revoke non-interactive access.
#
# Usage from a PowerShell prompt, where PowerShell itself parses the "--":
#   .\scripts\with-vault.ps1 -- .\node_modules\.bin\supabase.cmd projects list
#   .\scripts\with-vault.ps1 -Project employee-of-the-month-dev -- npm start
#
# Usage through `powershell -File`, as the npm scripts do. Omit the "--", because
# powershell.exe forwards it as a literal argument and an advanced script then
# rejects it as an ambiguous parameter name:
#   powershell -NoProfile -File .\scripts\with-vault.ps1 npm start

# No CmdletBinding here on purpose. With it, a bare "--" separator arriving
# through `powershell -File` is treated as an ambiguous parameter name and the
# script refuses to start.
param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$Command,
  [string]$Project = "employee-of-the-month-dev"
)

$ErrorActionPreference = "Stop"

$Command = @($Command | Where-Object { $_ -ne "--" })
if (-not $Command) { Write-Host "Nothing to run. Pass a command after --."; exit 2 }

$ownsPassphrase = $false
if (-not $env:JVAULT_PASSPHRASE) {
  $dpapi = "$env:USERPROFILE\.jvault\passphrase.dpapi"
  if (-not (Test-Path $dpapi)) {
    Write-Host "No JVAULT_PASSPHRASE and no $dpapi. Unlock the vault first."
    exit 1
  }
  $sec = Get-Content $dpapi | ConvertTo-SecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
  $env:JVAULT_PASSPHRASE = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  $ownsPassphrase = $true
}

$tmp = Join-Path $env:TEMP ("vault-" + [guid]::NewGuid().ToString("N") + ".env")
$injected = @()
try {
  & jvault export-env --project $Project --out $tmp | Out-Null
  if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -eq 0) {
    Write-Host "jvault export produced nothing for project '$Project'."
    exit 1
  }

  foreach ($line in (Get-Content $tmp)) {
    if ($line -notmatch "^[A-Za-z_][A-Za-z0-9_]*=") { continue }
    $parts = $line -split "=", 2
    Set-Item -Path ("env:" + $parts[0]) -Value $parts[1]
    $injected += $parts[0]
  }
  Remove-Item $tmp -Force

  Write-Host ("Injected from {0}: {1}" -f $Project, ($injected -join ", "))
  Write-Host ("Running: {0}" -f ($Command -join " "))
  Write-Host ""

  & $Command[0] @($Command[1..($Command.Count - 1)])
  $code = $LASTEXITCODE
}
finally {
  if (Test-Path $tmp) { Remove-Item $tmp -Force }
  foreach ($name in $injected) { Remove-Item ("env:" + $name) -ErrorAction SilentlyContinue }
  if ($ownsPassphrase) { $env:JVAULT_PASSPHRASE = $null }
}
exit $code
