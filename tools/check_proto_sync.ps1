[CmdletBinding()]
param(
    [string] $GodotExecutable = $env:GODOT_BIN,
    [string] $PythonExecutable = "python"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "sync_proto.ps1") -GodotExecutable $GodotExecutable -PythonExecutable $PythonExecutable
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Push-Location $repoRoot
try {
    $changed = git diff --name-only -- protocol server/proto/generated client/Scirpt/proto/game_proto.gd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($changed) {
        Write-Error "Generated protobuf files are stale or were edited manually:`n$changed"
        exit 1
    }
    Write-Host "Protocol generated files are synchronized."
}
finally {
    Pop-Location
}
