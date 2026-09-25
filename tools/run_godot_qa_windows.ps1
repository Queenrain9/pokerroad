param([string]$GodotExe = "")
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$gameDir = Join-Path $repoRoot "game"
$logDir = Join-Path $repoRoot "qa_logs\local"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (-not $GodotExe) {
  foreach ($candidate in @("godot4.exe","godot.exe","Godot_v4.5-stable_win64.exe","Godot_v4.4-stable_win64.exe","Godot_v4.3-stable_win64.exe")) {
    $cmd=Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $GodotExe=$cmd.Source; break }
  }
}
if (-not $GodotExe -or -not (Test-Path $GodotExe)) { throw "Godot 4 executable not found. Pass -GodotExe 'C:\path\to\Godot.exe'." }
$stamp=Get-Date -Format "yyyyMMdd_HHmmss"; $log=Join-Path $logDir "godot_qa_$stamp.log"
function Run-GodotTest([string]$script) {
  "=== $script ===" | Tee-Object -FilePath $log -Append
  & $GodotExe --headless --path $gameDir --script $script 2>&1 | Tee-Object -FilePath $log -Append
  if ($LASTEXITCODE -ne 0) { throw "Godot test failed: $script (exit $LASTEXITCODE)" }
}
& $GodotExe --headless --editor --path $gameDir --quit 2>&1 | Tee-Object -FilePath $log -Append
if ($LASTEXITCODE -ne 0) { throw "Godot project import/parser check failed (exit $LASTEXITCODE)" }
"=== production main boot ===" | Tee-Object -FilePath $log -Append
& $GodotExe --headless --path $gameDir --quit-after 1 2>&1 | Tee-Object -FilePath $log -Append
if ($LASTEXITCODE -ne 0) { throw "Godot production main boot failed (exit $LASTEXITCODE)" }
Run-GodotTest "res://tests_headless.gd"
Run-GodotTest "res://tests_p1_headless.gd"
Run-GodotTest "res://tests_system_contracts.gd"
Run-GodotTest "res://tests_world_runtime.gd"
Run-GodotTest "res://tests_region_scenes.gd"
Run-GodotTest "res://tests_spatial_runtime.gd"
Run-GodotTest "res://tests_world_interactions.gd"
Run-GodotTest "res://tests_route_geometry.gd"
Run-GodotTest "res://tests_physics_routes.gd"
Run-GodotTest "res://tests_first_eight_e2e.gd"
Run-GodotTest "res://tests_first_eight_poker.gd"
Run-GodotTest "res://tests_main_09_16_e2e.gd"
Run-GodotTest "res://tests_main_09_16_poker.gd"
Run-GodotTest "res://tests_main_17_24_e2e.gd"
Run-GodotTest "res://tests_main_17_24_poker.gd"
Write-Host "Godot native QA passed. Log: $log"
