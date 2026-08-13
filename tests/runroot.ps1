# Run root OUTSIDE the tree under test. Dot-sourced.
#
# By default a build script writes next to itself, and a test run then changes
# the very tree it is checking. Measured on 2026-08-11 in the release
# candidate: 779 binary files, 47 of them executable, had settled inside the
# published tree because the gates compiled into it.
#
# A twin of runroot.sh, not a translation: Resolve-Path normalises .. but does
# NOT resolve links, while pwd -P resolves both. Directory junctions are more
# common than symbolic links on Windows and take the same detour - the name
# looks external, the path leads inside.

function Resolve-Physical {
    param([Parameter(Mandatory = $true)][string] $Path)

    $full = [System.IO.Path]::GetFullPath($Path)

    # Links are resolved LINK BY LINK: what leads inside the tree may be any
    # ancestor rather than the root itself. The step limit guards against a
    # cycle, so a loop refuses instead of hanging.
    for ($step = 0; $step -lt 64; $step++) {
        $target = $null
        try {
            $target = [System.IO.Directory]::ResolveLinkTarget($full, $true)
        } catch {
            $target = $null
        }
        if ($null -eq $target) { break }
        $next = [System.IO.Path]::GetFullPath($target.FullName)
        if ($next -eq $full) { break }
        $full = $next
    }
    return $full.TrimEnd('\', '/')
}

function Initialize-RunRoot {
    param([Parameter(Mandatory = $true)][string] $TreeRoot)

    if (-not (Test-Path -LiteralPath $TreeRoot -PathType Container)) {
        # Write-Host, not Write-Output: in PowerShell the success stream IS the
        # return value, so a message written there would be handed back to the
        # caller together with the path.
        Write-Host "REFUSED: tree root does not exist: $TreeRoot"
        return $null
    }
    $tree = Resolve-Physical $TreeRoot

    $runRoot = $env:RUNROOT
    if ([string]::IsNullOrWhiteSpace($runRoot)) {
        $runRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    }
    try {
        $null = New-Item -ItemType Directory -Force -Path $runRoot -ErrorAction Stop
    } catch {
        Write-Host "REFUSED: run root not created: $runRoot"
        return $null
    }
    $runRoot = Resolve-Physical $runRoot

    # Compared ON THE SEPARATOR BOUNDARY rather than by prefix: otherwise a
    # directory named tests-old would count as living inside tests. Case is not
    # significant on Windows, and treating it as significant would refuse a
    # root that is in fact the same place.
    $sep = [System.IO.Path]::DirectorySeparatorChar
    if ($runRoot.Equals($tree, [System.StringComparison]::OrdinalIgnoreCase) -or
        $runRoot.StartsWith($tree + $sep, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Host "REFUSED: run root is physically INSIDE the tree under test"
        Write-Host "  tree: $tree"
        Write-Host "  root: $runRoot"
        return $null
    }

    Write-Host "run root: $runRoot"
    return $runRoot
}
