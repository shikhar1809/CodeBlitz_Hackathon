<#
  Run or build RapidRX with the local keys passed as --dart-define.

    .\tools\run.ps1                    flutter run on the default device
    .\tools\run.ps1 -Device chrome     flutter run in Chrome
    .\tools\run.ps1 -Build apk         flutter build apk --release
    .\tools\run.ps1 -Build apk -Debug  flutter build apk --debug

  A key passed by --dart-define is still embedded in the APK and can be pulled
  out of it. Treat it as a key you are willing to rotate after the event.
#>
param(
  [string]$Device,
  [ValidateSet('', 'apk', 'appbundle', 'web', 'windows')]
  [string]$Build = '',
  [switch]$Debug
)

# Not 'Stop': in Windows PowerShell 5.1 every line a native tool writes to
# stderr — including Gradle's harmless warnings — becomes a terminating error.
# Native commands are judged by $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

. (Join-Path $PSScriptRoot 'common.ps1')

$flutter = Get-Flutter
$defines = Get-DartDefines

if ($Build) {
  $mode = if ($Debug) { '--debug' } else { '--release' }
  $extra = @()
  if ($Build -eq 'web') { $extra += '--pwa-strategy=none' }
  & $flutter build $Build $mode @extra @defines
} else {
  $target = @()
  if ($Device) { $target = @('-d', $Device) }
  & $flutter run @target @defines
}
exit $LASTEXITCODE
