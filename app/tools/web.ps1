<#
  Build the web release and serve it on localhost.

    .\tools\web.ps1            build, then serve on :8080
    .\tools\web.ps1 -NoBuild   serve the last build instantly
    .\tools\web.ps1 -Port 9000

  Always builds with --pwa-strategy=none. A release web build otherwise installs
  a service worker that serves the STALE app after a rebuild, and your fix looks
  like it did nothing. When something looks like a no-op, suspect this first.
#>
param(
  [switch]$NoBuild,
  [int]$Port = 8080
)

# Not 'Stop': in Windows PowerShell 5.1 every line a native tool writes to
# stderr — including Gradle's harmless warnings — becomes a terminating error.
# Native commands are judged by $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

. (Join-Path $PSScriptRoot 'common.ps1')

if (-not $NoBuild) {
  $flutter = Get-Flutter
  $defines = Get-DartDefines
  & $flutter build web --release --pwa-strategy=none @defines
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

node (Join-Path $PSScriptRoot 'serve.js') (Join-Path $root 'build/web') $Port
