
<#
.DESCRIPTION
    Make a separate .zip archive from every folder at a given path.
    Also adds files at the said path to their own archive.
#>

function Zip-All-Rootfiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Path = '.',

        # Optional regex. If omitted/empty, everything is included.
        [Parameter(Position = 1)]
        [string] $Match = $null,

        # Where to put the zip files. Default: <Path>\.archives
        [string] $OutDir = $null,

        # If set, match against FullName instead of Name
        [switch] $MatchFullPath,

        # Overwrite existing zips
        [switch] $Force
    )

    # Normalize root path (trim trailing slashes that can confuse leaf logic)
    $root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')

    if ([string]::IsNullOrWhiteSpace($OutDir)) {
        $OutDir = Join-Path $root ".archives"
    }

    # Make OutDir absolute and normalized
    $OutDir = (Resolve-Path -LiteralPath (New-Item -ItemType Directory -Force -Path $OutDir).FullName).Path.TrimEnd('\', '/')

    $hasFilter = -not [string]::IsNullOrWhiteSpace($Match)

    $testMatch = {
        param($item)
        if (-not $hasFilter) { return $true }
        $target = if ($MatchFullPath) { $item.FullName } else { $item.Name }
        return $target -match $Match
    }

    # Helper: sanitize zip file name
    function Get-SafeName([string]$name) {
        return ($name -replace '[<>:"/\\|?*\x00-\x1F]', '_')
    }

    # 1) Zip each immediate subdirectory (excluding OutDir if it is inside root)
    $dirs = @(
        Get-ChildItem -LiteralPath $root -Directory -Force |
        Where-Object {
            $_.FullName -ne $OutDir -and (& $testMatch $_)
        }
    )

    foreach ($d in $dirs) {
        $safeName = Get-SafeName $d.Name
        $zipPath = Join-Path $OutDir "$safeName.zip"

        if (Test-Path -LiteralPath $zipPath) {
            if ($Force) { Remove-Item -LiteralPath $zipPath -Force }
            else { throw "Zip already exists: $zipPath (use -Force to overwrite)" }
        }

        # Zip folder contents
        Compress-Archive -Path (Join-Path $d.FullName '*') -DestinationPath $zipPath -Force:$Force
    }

    # 2) Zip immediate root files into one archive
    $files = @(
        Get-ChildItem -LiteralPath $root -File -Force |
        Where-Object { & $testMatch $_ }
    )

    # Name root-files zip after the root folder name
    $rootLeaf = Split-Path -Leaf $root
    if ([string]::IsNullOrWhiteSpace($rootLeaf)) {
        # Fallback, e.g. if root is a drive like D:
        $rootLeaf = ($root -replace '[:\\\/]+', '_')
    }

    $filesZip = Join-Path $OutDir ("{0}.zip" -f (Get-SafeName $rootLeaf))

    if (Test-Path -LiteralPath $filesZip) {
        if ($Force) { Remove-Item -LiteralPath $filesZip -Force }
        else { throw "Zip already exists: $filesZip (use -Force to overwrite)" }
    }

    if ($files.Count -gt 0) {
        Compress-Archive -LiteralPath $files.FullName -DestinationPath $filesZip -Force:$Force
    }
    else {
        Write-Verbose "No root files to zip in: $root"
        $filesZip = $null
    }

    [pscustomobject]@{
        Root         = $root
        OutDir       = $OutDir
        DirZipsMade  = $dirs.Count
        RootFiles    = $files.Count
        RootFilesZip = $filesZip
    }
}

Export-ModuleMember -Function Zip-All-Rootfiles;