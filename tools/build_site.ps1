# Builds everything Firebase Hosting serves into public/:
#   /                 the landing page (site/)
#   /app/             the Winger web demo (Flutter, base href /app/)
#   /t/<id>           the guardian tracking page
#   /downloads/       Winger Hub for Windows (zip)
#
#   powershell -File tools/build_site.ps1            # everything
#   powershell -File tools/build_site.ps1 -SkipApp   # reuse the last app build
#   powershell -File tools/build_site.ps1 -SkipHub   # reuse the last Hub build
param([switch]$SkipApp, [switch]$SkipHub)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' } else { 'C:\flutter\bin\flutter.bat' }
$public = Join-Path $root 'public'

if (-not $SkipApp) {
  Push-Location (Join-Path $root 'app')
  $defines = @('--dart-define=WINGER_DEMO=true')
  $envFile = Join-Path $root 'agents.env'
  if (Test-Path $envFile) { $defines += "--dart-define-from-file=$envFile" }
  & $flutter build web --release --base-href /app/ @defines
  if ($LASTEXITCODE -ne 0) { throw 'app web build failed' }
  Pop-Location
}

if (-not $SkipHub) {
  Copy-Item (Join-Path $root 'app\web\track.html') (Join-Path $root 'hub\assets\web\track.html') -Force
  Push-Location (Join-Path $root 'hub')
  & $flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'hub windows build failed' }
  Pop-Location
}

if (Test-Path $public) { Remove-Item $public -Recurse -Force }
New-Item -ItemType Directory -Force $public, "$public\app", "$public\brand", "$public\downloads" | Out-Null

Copy-Item (Join-Path $root 'site\*') $public -Recurse
Copy-Item (Join-Path $root 'brand\winger-mark.svg') "$public\brand\"
Copy-Item (Join-Path $root 'app\build\web\*') "$public\app" -Recurse
Copy-Item (Join-Path $root 'app\web\track.html') "$public\track.html"

$release = Join-Path $root 'hub\build\windows\x64\runner\Release'
$staging = Join-Path $env:TEMP 'WingerHub'
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
Copy-Item $release $staging -Recurse
Copy-Item (Join-Path $root 'hub\README.md') "$staging\README.md"
Compress-Archive -Path $staging -DestinationPath "$public\downloads\WingerHub-windows-x64.zip" -CompressionLevel Optimal
Remove-Item $staging -Recurse -Force

$zip = Get-Item "$public\downloads\WingerHub-windows-x64.zip"
Write-Host ("Built public/  (Hub zip {0:N1} MB)" -f ($zip.Length / 1MB))
