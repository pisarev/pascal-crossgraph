<#
  Building and running the plotting component tests on Delphi.

  Written in English at the source: unlike the monorepo scripts this file exists
  only for the published repository, so there is nothing to translate later.

  The component is visual, so both word sizes are built. Where the library lives
  is guessed from the layout and can be overridden with PARSER_SRC, PARSER_JIT
  and GRAPH_SRC; the Delphi folder with BDS_BIN.

  Run: pwsh -File tests\build.ps1
  The exit code is the number of failed runs.
#>

$ErrorActionPreference = 'Stop'

$Bin = if ($env:BDS_BIN) { $env:BDS_BIN }
       elseif ($env:BDS) { Join-Path $env:BDS 'bin' }
       else { 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin' }

$Here = $PSScriptRoot
$Root = Split-Path $Here -Parent

$Graph = if ($env:GRAPH_SRC) { $env:GRAPH_SRC } else { (Resolve-Path (Join-Path $Root 'src')).Path }
$Src = if ($env:PARSER_SRC) { $env:PARSER_SRC }
       else { (Resolve-Path (Join-Path $Root '..\pascal-mathparser\src')).Path }
$Jit = if ($env:PARSER_JIT) { $env:PARSER_JIT }
       else { (Resolve-Path (Join-Path $Root '..\pascal-mathparser\jit')).Path }

$FailedRuns = 0
$Tests = @('GraphTests', 'DrawTests', 'EngineTests', 'EngineBench')

foreach ($Target in @('win32', 'win64')) {
    $Out = Join-Path $Here "out\$Target"
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
    foreach ($Test in $Tests) {
        Write-Host "=== RUN $Test $Target ==="
        & (Join-Path $Here "out\$Target\$Test.exe")
        $Code = $LASTEXITCODE
        # The log is read rather than the console: the console writes in the OEM
        # code page and mangles the text when redirected.
        $Log = Join-Path $Here "out\$Target\$Test.log"
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
