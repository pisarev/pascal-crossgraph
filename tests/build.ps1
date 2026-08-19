<#
  Building and running the plotting component tests on Delphi.

  Written in English at the source: unlike the monorepo scripts this file exists
  only for the published repository, so there is nothing to translate later.

  The component is visual, so both word sizes are built. Where the library lives
  is guessed from the layout and can be overridden with PARSER_SRC, PARSER_JIT
  and GRAPH_SRC; the Delphi folder with BDS_BIN.

  Run: powershell -ExecutionPolicy Bypass -File tests\build.ps1
  The exit code is the number of failed runs.
#>

$ErrorActionPreference = 'Stop'

# The bin folder of the studio. Order: the builder's own variable, the one RAD
# Studio sets for its command prompt, then the registry. The registry replaced a
# path written here by hand. That path named a single version - 13 - and on a
# machine with Delphi 12 the build stopped at "dcc64.exe is not recognized",
# which says nothing about the real cause: the studio is installed, just not
# that one.
function Find-BdsBin($Keys = @('HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS',
                               'HKLM:\SOFTWARE\Embarcadero\BDS')) {
    $found = @()
    foreach ($key in $Keys) {
        if (-not (Test-Path $key)) { continue }
        foreach ($item in Get-ChildItem $key) {
            $root = (Get-ItemProperty -Path $item.PSPath -Name RootDir -ErrorAction SilentlyContinue).RootDir
            if (-not $root) { continue }
            $bin = Join-Path $root 'bin'
            if (-not (Test-Path (Join-Path $bin 'dcc64.exe'))) { continue }
            # The key is named after the version: 19.0, 23.0, 37.0. Only the major
            # part is read, and as an integer: [double] would parse 23.0 through the
            # current culture and give nothing on a comma-decimal one.
            $number = 0
            [void][int]::TryParse((($item.PSChildName -split '\.')[0]), [ref]$number)
            $found += [pscustomobject]@{ Version = $number; Bin = $bin }
        }
    }
    if (-not $found) { return '' }
    ($found | Sort-Object Version -Descending)[0].Bin
}

$Bin = if ($env:BDS_BIN) { $env:BDS_BIN }
       elseif ($env:BDS) { Join-Path $env:BDS 'bin' }
       else { Find-BdsBin }
if (-not $Bin -or -not (Test-Path (Join-Path $Bin 'dcc64.exe'))) {
    throw 'Delphi was not found. Set BDS_BIN to the bin folder of the installation, or run this from the RAD Studio command prompt.'
}

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

$FailedRuns = 0
$Tests = @('GraphTests', 'DrawTests', 'EngineTests', 'EngineBench')

foreach ($Target in @('win32', 'win64')) {
    $Out = Join-Path $RunRoot "$Target"
    New-Item -ItemType Directory -Force (Join-Path $Out 'dcu') | Out-Null
    $Dcc = if ($Target -eq 'win32') { Join-Path $Bin 'dcc32.exe' } else { Join-Path $Bin 'dcc64.exe' }
    $Rtl = Join-Path (Split-Path $Bin) "lib\$Target\release"
    foreach ($Test in $Tests) {
        Write-Host "=== BUILD $Test $Target ==="
        $BuildLog = & $Dcc -B -Q ('-U' + $Src + ';' + $Jit + ';' + $Graph + ';' + $Rtl) `
            ('-I' + $Src) ('-E' + $Out) ('-N0' + (Join-Path $Out 'dcu')) `
            '-NSSystem;System.Win;WinApi;Vcl' (Join-Path $Here "$Test.dpr") 2>&1
        if ($LASTEXITCODE -ne 0) {
            $BuildLog | Select-Object -Last 12 | ForEach-Object { Write-Host $_ }
            throw "build failed: $Test $Target"
        }
    }
}

foreach ($Target in @('win32', 'win64')) {
    # Derived from $RunRoot in ONE place: the build loop above writes there,
    # and a second, independent derivation of the same location would drift
    # apart at the first edit.
    $Out = Join-Path $RunRoot "$Target"
    foreach ($Test in $Tests) {
        Write-Host "=== RUN $Test $Target ==="
        & (Join-Path $Out "$Test.exe")
        $Code = $LASTEXITCODE
        # The log is read rather than the console: the console writes in the OEM
        # code page and mangles the text when redirected.
        $Log = Join-Path $Out "$Test.log"
        if (Test-Path $Log) {
            $Text = Get-Content $Log -Raw -Encoding UTF8
            $M = [regex]::Match($Text, 'TOTAL: checks (\d+), failures (\d+)')
            if ($M.Success) {
                Write-Host ("    checks {0}, failures {1}" -f $M.Groups[1].Value, $M.Groups[2].Value)
            }
        }
        if ($Code -ne 0) { $FailedRuns++ }
    }
}

Write-Host "=== DONE: failed runs: $FailedRuns ==="
exit $FailedRuns
