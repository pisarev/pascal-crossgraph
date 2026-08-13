# Building the computing part on FPC (x86_64-win64): the engine must not need
# any display. Paths are overridden with FPC_EXE and LAZARUS_DIR, and the
# library folders with PARSER_SRC, PARSER_JIT and GRAPH_SRC.
$ErrorActionPreference = 'Continue'

$Fpc = if ($env:FPC_EXE) { $env:FPC_EXE } else { 'fpc.exe' }
$LazDir = if ($env:LAZARUS_DIR) { $env:LAZARUS_DIR } else { 'C:\lazarus' }
$Lcl = Join-Path $LazDir 'lcl\units\x86_64-win64'
$LazUtils = Join-Path $LazDir 'components\lazutils\lib\x86_64-win64'

$Here = $PSScriptRoot
$Root = Split-Path $Here -Parent

# Build output goes OUTSIDE the tree, one rule for every script - see
# runroot.ps1. A test run must not change the tree it is checking.
$RunRootRule = Join-Path $Here 'runroot.ps1'
if (-not (Test-Path -LiteralPath $RunRootRule -PathType Leaf)) {
    Write-Host "REFUSED: run root rule not found: $RunRootRule"
    exit 1
}
. $RunRootRule
$RunRoot = Initialize-RunRoot $Root
if ($null -eq $RunRoot) { exit 1 }

$Graph = if ($env:GRAPH_SRC) { $env:GRAPH_SRC } else { (Resolve-Path (Join-Path $Root 'src')).Path }
$Src = if ($env:PARSER_SRC) { $env:PARSER_SRC }
       else { (Resolve-Path (Join-Path $Root '..\pascal-mathparser\src')).Path }
$Jit = if ($env:PARSER_JIT) { $env:PARSER_JIT }
       else { (Resolve-Path (Join-Path $Root '..\pascal-mathparser\jit')).Path }

$Out = Join-Path $RunRoot 'fpc'

# A step that could not run must not report success. This used to exit 0 when
# FPC was absent, so the matrix printed "ok" for a configuration nobody had
# built - green meant "not checked" and no one could tell. Exit code 3 says
# "toolchain absent"; the matrix reports that as SKIPPED, never as ok.
if (-not (Get-Command $Fpc -ErrorAction SilentlyContinue) -and -not (Test-Path $Fpc)) {
    # Plain output, not Write-Host: Write-Host bypasses the output stream, and
    # the caller that filters this run would lose the reason for the skip.
    "FPC not found: $Fpc"
    'Set FPC_EXE to the compiler if it lives elsewhere.'
    exit 3
}

# The target compiler version. The OPM directory builds on 3.2.2, and the
# rejected acceptance came from exactly there: the script picked the compiler
# from PATH or from a hardcoded path, where trunk was installed. The build was
# green on our side and red on theirs.
$Want = if ($env:FPC_VERSION_WANT) { $env:FPC_VERSION_WANT } else { '3.2.2' }
$Have = (& $Fpc -iV 2>$null | Select-Object -First 1).ToString().Trim()
if ($Have -ne $Want) {
    Write-Host "FPC version mismatch: $Fpc reports $Have, target is $Want"
    Write-Host "Set FPC_EXE to the target compiler, or FPC_VERSION_WANT to override."
    exit 1
}
New-Item -ItemType Directory -Force $Out | Out-Null

# NOFORMS and NOGRAPHICS keep the display out of it: without them the base
# Thread pulls in Forms and BlobManager pulls in Graphics, and with them the
# whole LCL. The engine needs neither.
$Options = @(
    '-Mdelphi', '-Sh', '-O2', '-B', '-vewn', '-dNOFORMS', '-dNOGRAPHICS',
    "-Fu$Src\compat", "-Fu$Src", "-Fu$Jit", "-Fu$Graph",
    "-Fi$Src", "-FU$Out", "-FE$Out"
)
if (Test-Path $LazUtils) { $Options += "-Fu$LazUtils" }

$Failed = 0
foreach ($Test in @('EngineTests', 'EngineStress')) {
    Write-Host "=== FPC BUILD $Test ==="
    & $Fpc @Options (Join-Path $Here "$Test.dpr")
    if ($LASTEXITCODE -ne 0) { $Failed++; continue }
    Write-Host "=== FPC RUN $Test ==="
    & (Join-Path $Out "$Test.exe")
    $Code = $LASTEXITCODE
    $Log = Join-Path $Out "$Test.log"
    if (Test-Path $Log) {
        $Text = Get-Content $Log -Raw -Encoding UTF8
        $M = [regex]::Match($Text, 'TOTAL: checks (\d+), failures (\d+)')
        if ($M.Success) {
            Write-Host ("    checks {0}, failures {1}" -f $M.Groups[1].Value, $M.Groups[2].Value)
        }
    }
    if ($Code -ne 0) { $Failed++ }
}

Write-Host "=== FPC DONE: failed: $Failed ==="
exit $Failed
