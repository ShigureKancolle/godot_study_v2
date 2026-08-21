[CmdletBinding()]
param(
    [string] $GodotExecutable = $env:GODOT_BIN,
    [string] $PythonExecutable = "python"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$schema = Join-Path $repoRoot "protocol/game.proto"
$pythonCompiler = Join-Path $repoRoot "server/proto/compile_proto.py"
$clientOutput = Join-Path $repoRoot "client/Scirpt/proto/game_proto.gd"
$godotLog = Join-Path ([System.IO.Path]::GetTempPath()) "godot-demo-v2-proto.log"

if (-not (Test-Path -LiteralPath $schema)) {
    throw "Canonical schema not found: $schema"
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable)) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($null -ne $godotCommand) {
        $GodotExecutable = $godotCommand.Source
    }
}

if ([string]::IsNullOrWhiteSpace($GodotExecutable) -or -not (Test-Path -LiteralPath $GodotExecutable)) {
    throw "Godot executable not found. Pass -GodotExecutable <path> or set GODOT_BIN."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $clientOutput) | Out-Null

Write-Host "Generating Python protobuf code..."
& $PythonExecutable $pythonCompiler --input $schema
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Generating Godot protobuf code..."
# Godobuf splits paths on '/', so normalize Windows paths before passing them.
$godobufInput = $schema.Replace("\", "/")
$godobufOutput = $clientOutput.Replace("\", "/")
# Godobuf reads OS.get_cmdline_args(), so its custom arguments must be passed
# directly (not after Godot's `--` user-argument separator).
& $GodotExecutable --headless --path (Join-Path $repoRoot "client") --log-file $godotLog --script res://addons/godobuf/godobuf_cmdln.gd ("--input={0}" -f $godobufInput) ("--output={0}" -f $godobufOutput)
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -LiteralPath $clientOutput)) {
    throw "Godobuf did not create the expected output: $clientOutput"
}

$generatedClientCode = Get-Content -LiteralPath $clientOutput -Raw
if ($generatedClientCode -notmatch "class EnterGameRequest:") {
    throw "Godobuf output does not match the canonical schema; generation did not complete."
}

Write-Host "Protocol generation completed."
