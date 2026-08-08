<#
  The build matrix of this repository, Windows side.

  What is checked:

    Delphi        win32 and win64: the component, drawing, the engine, the bench
    FPC/Windows   the engine headless: no forms, no graphics, no widgetset

  The repository is not self-contained: it expects a checkout of
  pascal-mathparser next to it. Override with PARSER_SRC and PARSER_JIT if it
  lives elsewhere.

  Environment (all optional):
    BDS_BIN      the Delphi bin folder, if BDS is not set
    FPC_EXE      the FPC compiler
    LAZARUS_DIR  the Lazarus folder

  Run: pwsh -File ci\check-windows.ps1
  The exit code is the number of failed steps.
#>

$ErrorActionPreference = 'Continue'
$Root = Split-Path $PSScriptRoot -Parent
$Report = @()

<#
  Everything this script has to say goes to the output stream.

  It used to print the summary table and every step through Out-Host. Out-Host
  writes straight to the console and bypasses the output stream, so anyone who
  redirected or filtered the run - which is what a build log does - was left
  with the single line "STEPS FAILED: 1" and no way to tell which step broke or
  why. The count alone is useless: it says a failure happened, not what failed.

  So: plain output, the failing step named, and the lines that made it fail
  repeated under it.
#>
function Step([string]$Name, [scriptblock]$Action) {
    ''
    "--- $Name"
    $Started = Get-Date
    $Code = 0
    $Lines = @()
    try {
        $Lines = & $Action 2>&1 | ForEach-Object { "$_" }
        $Code = $LASTEXITCODE
        if ($null -eq $Code) { $Code = 0 }
    }
    catch {
        $Lines += "crashed: $($_.Exception.Message)"
        $Code = 1
    }
    $Lines
    $Spent = [math]::Round(((Get-Date) - $Started).TotalSeconds)
    # Exit code 3 means the step found no toolchain and did not run. That is not
    # a pass: reporting it as ok would make an unchecked configuration look
    # verified, which is the worst thing a build matrix can do.
    $Verdict = switch ($Code) {
        0 { 'ok' }
        3 { 'SKIPPED (no toolchain)' }
        default { "FAILED ($Code)" }
    }
    $script:Report += [PSCustomObject]@{
        Step = $Name
        Result = $Verdict
        Seconds = $Spent
        # Kept for the summary: without it a failed step says nothing.
        Reason = @($Lines | Where-Object { $_ -match 'Error|Fatal|^FAIL|crashed|not found' })
    }
}

'=== Build matrix: Windows ==='

Step 'Delphi: the component and the engine (win32 + win64)' {
    & (Join-Path $Root 'tests\build.ps1') 2>&1 |
        Select-String -Pattern 'checks |=== DONE|Error:|Fatal:|^FAIL '
}

Step 'FPC/Windows: the engine headless' {
    & (Join-Path $Root 'tests\build_fpc.ps1') 2>&1 |
        Select-String -Pattern 'checks |DONE|Error:|Fatal:|^FAIL|not found'
}

''
'=== Summary ==='
$Report | Select-Object Step, Result, Seconds | Format-Table -AutoSize | Out-String -Width 200

$Bad = @($Report | Where-Object { $_.Result -like 'FAILED*' })
$Skipped = @($Report | Where-Object { $_.Result -like 'SKIPPED*' })

foreach ($B in ($Bad + $Skipped)) {
    ''
    "  $($B.Step): $($B.Result)"
    if ($B.Reason.Count -eq 0) {
        '    no diagnostic line matched - see the step output above'
    } else {
        $B.Reason | Select-Object -Last 15 | ForEach-Object { "    $_" }
    }
}

''
if ($Bad.Count -gt 0) {
    "STEPS FAILED: $($Bad.Count)"
} elseif ($Skipped.Count -gt 0) {
    # Deliberately not "GREEN": part of the matrix was never built.
    "MATRIX IS INCOMPLETE: $($Skipped.Count) step(s) skipped, the rest passed"
} else {
    'MATRIX IS GREEN'
}
# A skipped step is not a pass. This used to be exit $Bad.Count, so an
# incomplete matrix handed the shell a zero: the text said INCOMPLETE while the
# exit code said all is well. Skips now count alongside failures.
exit ($Bad.Count + $Skipped.Count)
