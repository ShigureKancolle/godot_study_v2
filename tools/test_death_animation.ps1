# 在隔离项目中测试真实死亡动画，不启动游戏的网络入口。
param(
    [string]$GodotExecutable = 'C:\work\godot\Godot_v4.6.3-stable_win64_console.exe'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$validationRoot = Join-Path $repositoryRoot '.tmp\death_animation_validation'
New-Item -ItemType Directory -Path $validationRoot -Force | Out-Null
Set-Content -LiteralPath (Join-Path $validationRoot '.gitignore') -Value '*' -Encoding utf8

foreach ($fixture in @('project.godot', 'EntityView.gd', 'test_death_animation.gd')) {
    Copy-Item -LiteralPath (Join-Path $repositoryRoot "tests\godot\death_animation\$fixture") -Destination (Join-Path $validationRoot $fixture) -Force
}

$requiredFiles = @(
    'Scirpt/game/view/PlayerVisual.gd',
    'Scirpt/game/view/presenter/Presenter.gd',
    'Scirpt/game/view/presenter/AnimationPresenter.gd',
    'Prefab/Role/PlayerVisual.tscn',
    'Prefab/Role/anim/player_anim.tres',
    'Prefab/CommonTexture/arrowBeige_right.png',
    'Prefab/Role/anim/player/Player_Attack.png',
    'Prefab/Role/anim/player/Player_Die.png',
    'Prefab/Role/anim/player/Player_Hurt.png',
    'Prefab/Role/anim/player/Player_Idle.png',
    'Prefab/Role/anim/player/Player_Run.png'
)
foreach ($relativeFile in $requiredFiles) {
    $sourceFile = Join-Path (Join-Path $repositoryRoot 'client') $relativeFile
    $destinationFile = Join-Path $validationRoot $relativeFile
    New-Item -ItemType Directory -Path (Split-Path -Parent $destinationFile) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile -Destination $destinationFile -Force
    foreach ($suffix in @('.uid', '.import')) {
        if (Test-Path -LiteralPath ($sourceFile + $suffix)) {
            Copy-Item -LiteralPath ($sourceFile + $suffix) -Destination ($destinationFile + $suffix) -Force
        }
    }
}

& $GodotExecutable --headless --path $validationRoot --log-file (Join-Path $validationRoot 'import.log') --import
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& $GodotExecutable --headless --path $validationRoot --log-file (Join-Path $validationRoot 'validation.log') --script res://test_death_animation.gd
exit $LASTEXITCODE
