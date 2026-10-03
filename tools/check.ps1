# One gate: nothing merges red.
#   flutter analyze, flutter test (includes the preset validator over every
#   built-in preset and the bad-preset fixtures), backend load check, and a
#   secret scan of everything git tracks.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fail = $false

function Step($name, [scriptblock]$run) {
  Write-Host "== $name" -ForegroundColor Cyan
  & $run
  if ($LASTEXITCODE -ne 0) { Write-Host "FAIL: $name" -ForegroundColor Red; $script:fail = $true }
}

Push-Location "$root\app"
Step 'flutter analyze' { flutter analyze --no-pub }
Step 'flutter test' { flutter test --no-pub }
Pop-Location

Push-Location "$root\backend\functions"
Step 'backend loads' { node -e "require('./index.js'); console.log('ok')" }
Pop-Location

Push-Location $root
Step 'secret scan' {
  # ElevenLabs keys and agent ids must never be committed (agent ids live in
  # agents.env, which is ignored). Firebase web keys are public by design.
  $hits = git grep -nE "sk_[A-Za-z0-9]{20,}|agent_[a-z0-9]{20,}" -- . ':!tools/check.ps1'
  if ($hits) { $hits; $global:LASTEXITCODE = 1 } else { 'clean'; $global:LASTEXITCODE = 0 }
}
Pop-Location

if ($fail) { Write-Host 'GATE RED' -ForegroundColor Red; exit 1 }
Write-Host 'GATE GREEN' -ForegroundColor Green
