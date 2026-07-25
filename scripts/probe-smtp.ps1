# probe-smtp.ps1 - diagnose the mail path without sending anything.
#
#   .\scripts\with-vault.ps1 -- powershell -NoProfile -File .\scripts\probe-smtp.ps1 -To someone@example.com
#
# Walks the SMTP conversation up to the point just before the message body:
# greeting, EHLO, STARTTLS, AUTH, MAIL FROM, RCPT TO, then QUIT. DATA is never
# issued, so no message is transmitted.
#
# This separates three failures that all look identical from the outside:
#   * credentials rejected            -> AUTH fails
#   * sender address not permitted    -> MAIL FROM fails
#   * recipient refused               -> RCPT TO fails
# If all four succeed, the provider is accepting the message and the problem is
# after handoff: filtering, bouncing or spam placement, none of which are
# visible from the sending side.

param(
  [Parameter(Mandatory = $true)][string]$To,
  [string]$SmtpHost = "smtp.resend.com",
  [int]$Port = 587
)

$ErrorActionPreference = "Stop"

$user = if ($env:SMTP_USER) { $env:SMTP_USER } else { "resend" }
$pass = $env:RESEND_API_KEY
$from = "recognition@jonnyai.co.uk"
if (-not $pass) { Write-Host "No RESEND_API_KEY in the environment."; exit 1 }

$client = New-Object Net.Sockets.TcpClient
$client.Connect($SmtpHost, $Port)
$stream = $client.GetStream()
$reader = New-Object IO.StreamReader($stream)
$writer = New-Object IO.StreamWriter($stream)
$writer.AutoFlush = $true

function Recv($reader) {
  $lines = @()
  do {
    $line = $reader.ReadLine()
    if ($null -eq $line) { break }
    $lines += $line
    # A multi-line reply uses "250-"; the final line uses "250 ".
  } while ($line.Length -ge 4 -and $line[3] -eq '-')
  return ($lines -join ' | ')
}

function Step($label, $expected, $reply) {
  $code = if ($reply.Length -ge 3) { $reply.Substring(0, 3) } else { '???' }
  $ok = $expected -contains $code
  Write-Host ("[{0}] {1,-12} {2}" -f $(if ($ok) { "PASS" } else { "FAIL" }), $label, $reply)
  return $ok
}

$failed = $false
try {
  if (-not (Step "greeting" @('220') (Recv $reader))) { $failed = $true }

  $writer.WriteLine("EHLO employee-of-the-month.local")
  if (-not (Step "EHLO" @('250') (Recv $reader))) { $failed = $true }

  $writer.WriteLine("STARTTLS")
  if (-not (Step "STARTTLS" @('220') (Recv $reader))) { $failed = $true; throw "no TLS" }

  $ssl = New-Object Net.Security.SslStream($stream, $false)
  $ssl.AuthenticateAsClient($SmtpHost)
  $reader = New-Object IO.StreamReader($ssl)
  $writer = New-Object IO.StreamWriter($ssl)
  $writer.AutoFlush = $true
  Write-Host ("[PASS] TLS          {0}" -f $ssl.SslProtocol)

  $writer.WriteLine("EHLO employee-of-the-month.local")
  if (-not (Step "EHLO (tls)" @('250') (Recv $reader))) { $failed = $true }

  # AUTH LOGIN sends the credential base64-encoded, which is encoding not
  # encryption. It is safe here only because TLS is already established.
  $writer.WriteLine("AUTH LOGIN")
  if (-not (Step "AUTH LOGIN" @('334') (Recv $reader))) { $failed = $true }

  $writer.WriteLine([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($user)))
  if (-not (Step "username" @('334') (Recv $reader))) { $failed = $true }

  $writer.WriteLine([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pass)))
  if (-not (Step "password" @('235') (Recv $reader))) { $failed = $true }

  $writer.WriteLine("MAIL FROM:<$from>")
  if (-not (Step "MAIL FROM" @('250') (Recv $reader))) { $failed = $true }

  $writer.WriteLine("RCPT TO:<$To>")
  if (-not (Step "RCPT TO" @('250', '251') (Recv $reader))) { $failed = $true }

  # Deliberately no DATA. Nothing is sent.
  $writer.WriteLine("QUIT")
  Recv $reader | Out-Null
}
catch {
  Write-Host "[FAIL] $($_.Exception.Message)"
  $failed = $true
}
finally {
  $client.Close()
}

Write-Host ""
if ($failed) {
  Write-Host "The mail path is broken before the message body. The first FAIL above"
  Write-Host "says which of credentials, sender or recipient the provider rejected."
  exit 1
}
Write-Host "Envelope accepted through RCPT TO. Credentials, sender and recipient are"
Write-Host "all fine, so anything missing from the inbox happened after handoff."
