$ErrorActionPreference = 'Stop'

$pinnedCommit = 'bdedd245800484688913d6e8fd200c227a20acbf'
$taskRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'yahagi-poi-battle-corpus'
$repository = Join-Path $taskRoot 'lib-battle'

if (-not (Test-Path -LiteralPath (Join-Path $repository '.git'))) {
    New-Item -ItemType Directory -Path $taskRoot -Force | Out-Null
    git clone https://github.com/poooi/lib-battle.git $repository
}

git -C $repository fetch --depth 1 origin $pinnedCommit
git -C $repository checkout --detach $pinnedCommit

Push-Location $repository
try {
    npm ci
    npm run build
}
finally {
    Pop-Location
}

$env:YAHAGI_POI_BATTLE_FIXTURES = Join-Path $repository 'tests\fixtures\battle-detail'
flutter test test\battle_poi_corpus_test.dart
