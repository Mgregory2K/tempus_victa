# Tempus Victa Hard Stabilization - PASS 1
# Deletes legacy duplicate room implementations under lib/ui/
# Safe: does NOT touch lib/ui/rooms/ (canonical)

$ErrorActionPreference = 'Stop'

$root = Get-Location

$targets = @(
  'lib/ui/bridge_room.dart',
  'lib/ui/corkboard_room.dart',
  'lib/ui/signal_bay_room.dart'
)

Write-Host "PASS 1: Deleting legacy duplicate rooms..." -ForegroundColor Cyan
foreach ($t in $targets) {
  $p = Join-Path $root $t
  if (Test-Path $p) {
    Remove-Item -Force $p
    Write-Host "Deleted: $t" -ForegroundColor Green
  } else {
    Write-Host "Not found (ok): $t" -ForegroundColor Yellow
  }
}

Write-Host "PASS 1 complete. Next: flutter clean && flutter pub get && build/run." -ForegroundColor Cyan
