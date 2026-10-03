# Shared by run.ps1 and web.ps1.

function Get-Flutter {
  $onPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  if (Test-Path 'C:\flutter\bin\flutter.bat') { return 'C:\flutter\bin\flutter.bat' }
  throw 'Flutter not found. Put it on PATH or install it at C:\flutter.'
}

# Keys live in tools/keys.local.ps1, which is gitignored. The repository is
# public: no key is ever committed. Copy keys.example.ps1 to start.
#
# They are handed to Flutter as --dart-define-from-file, pointing at a JSON
# file inside build/ (also gitignored). Not as --dart-define=KEY=VALUE: when
# PowerShell calls flutter.bat, cmd splits arguments on "=", and the define
# arrives in three pieces. A file also keeps the key off the command line.
function Get-DartDefines {
  $local = Join-Path $PSScriptRoot 'keys.local.ps1'
  if (Test-Path $local) { . $local }

  $names = @(
    'GEMINI_API_KEY',
    'TWILIO_ACCOUNT_SID',
    'TWILIO_AUTH_TOKEN',
    'TWILIO_WHATSAPP_FROM'
  )
  $values = [ordered]@{}
  foreach ($name in $names) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ($value) { $values[$name] = $value }
  }
  if ($values.Count -eq 0) { return @() }

  $root = Split-Path -Parent $PSScriptRoot
  $dir = Join-Path $root 'build'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $file = Join-Path $dir 'dart_defines.json'
  $values | ConvertTo-Json | Out-File -FilePath $file -Encoding ascii
  return @('--dart-define-from-file', $file)
}
