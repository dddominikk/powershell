Set-StrictMode -Version 5;
<#git autocomplete#>
Import-Module posh-git
<#npm autocomplete#>
Import-Module npm-completion

# GitHub CLI autocomplete
gh completion --shell powershell | Out-String | Invoke-Expression

<# Make sure writing to files from the CLI doesn't malform them. #>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['Get-Content:Encoding'] = 'utf8'

<#
 .NOTES
    See [PowerShell Docs](https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption).
#>
Set-PSReadLineOption -Colors @{
    "Parameter" = "#86BBD8"
    #"Command"="Blue"
    "Error"     = [System.ConsoleColor]::DarkRed 
}

[System.Collections.Stack]$GLOBAL:dirStack = @()
$GLOBAL:oldDir = ''
$GLOBAL:addToStack = $true
function prompt {
    Write-Host "PS $(get-location)>"  -NoNewLine -foregroundcolor "Magenta"
    $GLOBAL:nowPath = (Get-Location).Path
    if (($nowPath -ne $oldDir) -AND $GLOBAL:addToStack) {
        $GLOBAL:dirStack.Push($oldDir)
        $GLOBAL:oldDir = $nowPath
    }
    $GLOBAL:AddToStack = $true
    return ' '
}
function GoBack {
    $lastDir = $GLOBAL:dirStack.Pop()
    $GLOBAL:addToStack = $false
    cd $lastDir
}


function Test-Command {
    param (
        [Parameter(Mandatory = $true)]
        [string]$command
    )

    [bool](Get-Command "$command" -ErrorAction SilentlyContinue)

}

function Invoke-Utility {
    <#
    .SYNOPSIS
    Invokes an external utility and guards against errors.
    
    .DESCRIPTION
    Invokes an external utility (program) and, if the utility indicates failure by 
    way of a nonzero exit code, throws a script-terminating error.
    
    * Pass the command the way you would execute the command directly.
    * Do NOT use & as the first argument if the executable name is not a literal.
    
    .EXAMPLE
    Invoke-Utility git push
    
    Executes `git push` and throws a script-terminating error if the exit code
    is nonzero.
    .NOTES
        Author: [mklement0](https://stackoverflow.com/a/48877892)
    #>
    $exe, $argsForExe = $args
    # Workaround: Prevents 2> redirections applied to calls to this function
    #             from accidentally triggering a terminating error.
    #             See bug report at https://github.com/PowerShell/PowerShell/issues/4002
    $ErrorActionPreference = 'Continue'
    try { & $exe $argsForExe } 
    catch { Throw } # catch is triggered ONLY if $exe can't be found, never for errors reported by $exe itself
    if ($LASTEXITCODE.Equals(0)) { return }
    Else { Throw "$exe indicated failure (exit code $LASTEXITCODE; full command: $Args)." }
    
};


<#
$encodedjson = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json @{
    scripts = @('src/arrayToChunks.ts','src/randomId.ts')
    overwrite= $true
    } -compress)));
#>

<#
    .EXAMPLE
        `nrun dev(toJson64 @{scripts=@('src/arrayToChunks.ts','src/randomId.ts');overwrite=$true})`
#>
function toJson64() {
    param(
        [Parameter(Mandatory = $false)]
        [hashtable]$obj
    )
    $hsh = {}
    if ($obj) { $hsh = $obj }
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $hsh -compress)));
}

New-Alias iu Invoke-Utility;

<#
.DESCRIPTION
`npm run` shorthand.
#>
function nrun {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,

        [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
        [string[]]$ScriptArgs
    )

    # Prepare the command and arguments
    $command = 'npm'
    $arguments = @('run', $ScriptName)

    # Add script arguments if they exist
    if ($ScriptArgs) {
        $arguments += '--'
        $arguments += $ScriptArgs
    }

    # Invoke the command with arguments
    & $command $arguments
}


New-Alias -Name commit -Value Git.commit;

<#
.DESCRIPTION
Commits unstaged changes to tracked files and automatically sets upstream if needed.
#>
function Git.commit {
    Param(
        [Parameter(Mandatory = $false)]
        [string]$message
    )
    
    # If no message is provided, generate one with timestamp
    if (-not $message) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $message = "$timestamp`: semi-automated commit"
    }
    
    # Display the commit message being used
    Write-Host "Committing with message: $message" -ForegroundColor Cyan
    
    # Execute git commands
    git add -u
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to stage changes."
        return
    }
    
    git commit -m $message
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to commit changes."
        return
    }
    
    git fetch
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to fetch updates. Continuing..."
    }
    
    git pull
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Failed to pull updates. You may need to resolve conflicts."
    }
    
    
    # Attempt to push
    git push
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Push failed, checking if upstream branch needs to be set..." -ForegroundColor Yellow
        
        # Get current branch name
        $currentBranch = git rev-parse --abbrev-ref HEAD
        
        if ($LASTEXITCODE -eq 0 -and $currentBranch) {
            Write-Host "Setting upstream for branch '$currentBranch'..." -ForegroundColor Yellow
            
            # Try to set upstream and push
            git push --set-upstream origin "$currentBranch"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Successfully set upstream and pushed changes." -ForegroundColor Green
                return
            }
            else {
                Write-Error "Failed to set upstream branch. You may need to resolve conflicts or check permissions."
                return
            }
        }
        else {
            Write-Error "Failed to determine current branch name. Cannot set upstream automatically."
            return
        }
    }
    
    Write-Host "✅ Successfully committed and pushed changes." -ForegroundColor Green
}

<#
 .DESCRIPTION
 Git Status shortcut; write `gs u` for the equivalent of the `git status --untracked` command.
#>

function gs () {
    
    param ([string]$flag = "");

    if ($flag) { return git status -$flag };

    git status;
};


function gb { git branch $args };

function gbc { git checkout $args };

<# Specific to @airtable/blocks-cli #>
function blr {
    block list-remotes;
};

<#
.DESCRIPTION
Run a process as administratior.
#>
function wtAdmin {
    Start-Process wt -Verb RunAs
};

<#
.DESCRIPTION
Removes all untracked files and syncs your local branch with the remote one, thus squashing local changes
#>
function Git-Reset-Untracked {
    git reset --hard HEAD
    git clean -fxd
    <#
    git rm -r --cached .
    git add .
    git commit - m "auto-recommiting to get rid of node_modules dirs from source control."
    git push
    #>
};


function tsc($flag) {
    
    if ($flag) { return npx tsc -$flag };

    return npx tsc;
};

# Why write ts-note when you can write tsn?
function tsn ($path) {
    ts-node "$path";
}

function IsFile ($path) { Test-Path "$path" -PathType Leaf };
function IsFolder ($path) { Test-Path "$path" -PathType Container };

<#
.DESCRIPTION
List all PowerShell profiles on a given machine.
#>
function listAllProfiles() {
    return $PROFILE | Format-List -Force
};

<#
.DESCRIPTION
Quickly activate Windows 10/11, Office, change Windows Edition, etc.
#>
function microsoftActivationScripts() {
    Invoke-RestMethod 'https://massgrave.dev/get' | Invoke-Expression
};


function Clean-File-Directory-Name ($path) {
    
    return "$path" -replace "^[./\\]+|[./\\]+$"
};


<#
.DESCRIPTION
Recursively removes empty directories from a given folder.
.EXAMPLE
`removeEmptyDirectories` is equivalent to `removeEmptyDirectories .`
.EXAMPLE
Alternatively, and assuming you're located in `C:\Users\$USERNAME\`, `removeEmptyDirectories desktop` (or `removeEmptyDirectories .\desktop\`) will remove all empty folders from `C:\Users\$USERNAME\Desktop.`
.SYNOPSIS
Recursively removes all empty directories in a given folder. Cleans the current directory if not provided with an explicit path.
#>
function removeEmptyDirectories($path) {
    $targetPath = ".".Replace(".", $(If ($path) { $path } Else { "." }));

    gci $targetPath -Directory -Recurse | ? { -Not $_.GetFiles("*", "AllDirectories") } | rm -Recurse;
};

<#
.DESCRIPTION
Copies the contents of a given file to the Clipboard.
.SYNOPSIS
Access the result by writing `Get-Clipboard` or its `gcb` alias.
#>
function toClipboard($path) {
    $targetPath = ".".Replace(".", $(If ($path) { $path } Else { "." }));
    Get-Content $targetPath | clip;
}

<#
.DESCRIPTION
Lists all custom functions in a given PowerShell session.
#>
function Get-All-Custom-Functions {
    return Get-ChildItem function:
}

function gitListCommitIds() {
    return git rev-list --first-parent main;
}

function Count($target) {
    
    $isArray = $target -is [array];
    
    if ($isArray) { return $target.length; };

    return $target | Measure-Object -line;

};

function Git-Tag-Last-Commit ($tag, $message) {
    git tag -a $tag HEAD -m "$message";
};
##gh release create <tagname> --target <branchname>


<#
.DESCRIPTION connects a local git repo with a remote GitHub one.
.EXAMPLE Connect-GitRepo -remoteUrl "https://github.com/yourusername/yourrepository.git" -mainBranchName "main"
#>
function GhInit {
    <#
    .SYNOPSIS
    Initialize/ensure a local git repo and connect/push it to a GitHub repo using gh.

    .DESCRIPTION
    - Works from an existing folder (default: current directory).
    - Creates the GitHub repo if it doesn't exist.
    - Uses HTTPS remote (avoids SSH publickey issues).
    - On push, handles remote-ahead/divergence safely:
        * fetch
        * if behind only -> ff-only merge
        * if ahead only  -> push
        * if diverged    -> try normal merge
            - if normal merge fails, retry with whitespace/EOL-tolerant merge:
                git merge -Xignore-all-space -Xrenormalize
            - if still fails -> abort and push to import/<machine>-<timestamp>
    #>

    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$repoName = (Split-Path (Get-Location) -Leaf),

        # Optional path: ".", existing dir, or new dir
        [Parameter(Mandatory = $false)]
        [string]$path = ".",

        [Parameter(Mandatory = $false)]
        [string]$mainBranch = "main",

        [Parameter(Mandatory = $false)]
        [string]$owner
    )

    # --- Helpers (local scope) ---
    function _Resolve-Dir([string]$p) {
        if ([string]::IsNullOrWhiteSpace($p)) { $p = "." }

        $resolved = Resolve-Path -LiteralPath $p -ErrorAction SilentlyContinue
        if (-not $resolved) {
            New-Item -ItemType Directory -Path $p -Force | Out-Null
            $resolved = Resolve-Path -LiteralPath $p
        }
        return $resolved.Path
    }

    function _EnsureGlobalDefaultBranch([string]$branch) {
        $cur = (git config --global --get init.defaultBranch 2>$null)
        if ($cur -ne $branch) {
            git config --global init.defaultBranch $branch | Out-Null
        }
    }

    function _EnsureLocalAutoCrlfInputIfWindows() {
        if ($env:OS -ne "Windows_NT") { return }
        $local = (git config --local --get core.autocrlf 2>$null)
        if ($local -ne "input") {
            git config --local core.autocrlf input | Out-Null
        }
    }

    function _EnsureBranch([string]$branch) {
        $current = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        if ([string]::IsNullOrWhiteSpace($current) -or $current -eq "HEAD") {
            git checkout -b $branch | Out-Null
            return $branch
        }

        git show-ref --verify --quiet "refs/heads/$branch"
        $exists = ($LASTEXITCODE -eq 0)

        if (-not $exists) {
            git checkout -b $branch | Out-Null
            return $branch
        }

        if ($current -ne $branch) {
            git checkout $branch | Out-Null
        }

        return $branch
    }

    function _EnsureGitignore() {
        if (-not (Test-Path -LiteralPath ".gitignore")) {
            "node_modules`n" | Set-Content -Encoding UTF8 .gitignore
            git add .gitignore | Out-Null
        }
    }

    function _EnsureInitialCommit() {
        git rev-parse --verify HEAD *> $null
        if ($LASTEXITCODE -ne 0) {
            git add . | Out-Null
            git commit -m "Initial commit" | Out-Null
        }
    }

    function _GetHttpsRemote([string]$fullName) {
        $u = $null
        try {
            $u = gh repo view $fullName --json httpsUrl -q .httpsUrl 2>$null
        }
        catch {
            $u = $null
        }

        if ([string]::IsNullOrWhiteSpace($u)) {
            return "https://github.com/$fullName.git"
        }

        $u = $u.Trim()
        if ($u.EndsWith(".git")) { return $u }
        return ($u + ".git")
    }

    function _RemoteBranchExists([string]$branch) {
        git show-ref --verify --quiet "refs/remotes/origin/$branch"
        return ($LASTEXITCODE -eq 0)
    }

    function _PushWithMergeOrImportBranch([string]$branch) {
        git fetch origin 2>$null | Out-Null

        # If remote branch doesn't exist → normal push
        if (-not (_RemoteBranchExists $branch)) {
            git push -u origin $branch
            if ($LASTEXITCODE -ne 0) { throw "Failed to push branch '$branch'." }
            return
        }

        # Compare local vs remote
        $status = git rev-list --left-right --count "$branch...origin/$branch" 2>$null
        if (-not $status) { throw "Failed to compare local and remote branches." }

        $parts = $status -split '\s+'
        $ahead = [int]$parts[0] # local ahead
        $behind = [int]$parts[1] # local behind

        # Local behind only → fast-forward
        if ($ahead -eq 0 -and $behind -gt 0) {
            Write-Host "Local branch is behind remote. Fast-forwarding..." -ForegroundColor Cyan
            git merge --ff-only "origin/$branch"
            if ($LASTEXITCODE -ne 0) { throw "Fast-forward failed unexpectedly." }
            return
        }

        # Local ahead only → push
        if ($ahead -gt 0 -and $behind -eq 0) {
            git push -u origin $branch
            if ($LASTEXITCODE -ne 0) { throw "Failed to push branch '$branch'." }
            return
        }

        # In sync
        if ($ahead -eq 0 -and $behind -eq 0) {
            Write-Host "Local and remote are already in sync." -ForegroundColor Green
            return
        }

        # Diverged → attempt merges
        Write-Host "Branches diverged. Attempting merge..." -ForegroundColor Yellow

        # Attempt 1: normal merge
        git merge --no-edit "origin/$branch" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            git push -u origin $branch
            if ($LASTEXITCODE -ne 0) { throw "Failed to push branch '$branch' after merge." }
            return
        }

        # Abort and attempt 2: whitespace/EOL tolerant merge
        git merge --abort 2>$null | Out-Null

        Write-Host "Normal merge failed. Retrying whitespace/EOL-tolerant merge..." -ForegroundColor Yellow
        git merge --no-edit -Xignore-all-space -Xrenormalize "origin/$branch" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            git push -u origin $branch
            if ($LASTEXITCODE -ne 0) { throw "Failed to push branch '$branch' after tolerant merge." }
            return
        }

        # Still failed → abort and push to import branch
        git merge --abort 2>$null | Out-Null

        $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $machine = ($env:COMPUTERNAME -replace '[^A-Za-z0-9\-]', '')
        if ([string]::IsNullOrWhiteSpace($machine)) { $machine = "local" }

        $importBranch = "import/$machine-$stamp"

        Write-Host "Merge failed. Pushing to '$importBranch' instead." -ForegroundColor Yellow

        git checkout -b $importBranch | Out-Null
        git push -u origin $importBranch
        if ($LASTEXITCODE -ne 0) { throw "Failed to push import branch '$importBranch'." }
    }

    # --- Main flow ---
    _EnsureGlobalDefaultBranch $mainBranch

    if ([string]::IsNullOrWhiteSpace($owner)) {
        $owner = (gh api user -q .login).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($owner)) {
        throw "Could not determine GitHub owner. Ensure GitHub CLI is authenticated (gh auth login)."
    }

    $fullName = "$owner/$repoName"
    $workingDir = _Resolve-Dir $path

    Push-Location $workingDir
    try {
        if (-not (Test-Path -LiteralPath ".git")) {
            git init | Out-Null
        }

        _EnsureLocalAutoCrlfInputIfWindows

        $branch = _EnsureBranch $mainBranch

        _EnsureGitignore
        _EnsureInitialCommit

        # Does repo exist remotely?
        gh repo view $fullName --json name --jq .name *> $null
        $repoExists = ($LASTEXITCODE -eq 0)

        if (-not $repoExists) {
            gh repo create $fullName --private --source=. --push=false | Out-Null
        }

        $remoteUrl = _GetHttpsRemote $fullName

        git remote get-url origin 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            git remote set-url origin $remoteUrl | Out-Null
        }
        else {
            git remote add origin $remoteUrl | Out-Null
        }

        Write-Host "Remote set to: $remoteUrl" -ForegroundColor Cyan

        _PushWithMergeOrImportBranch $branch
    }
    finally {
        Pop-Location
    }
}

# Example usage:
# Connect-GitRepo -remoteUrl "https://github.com/yourusername/yourrepository.git" -mainBranchName "main"

<#
.DESCRIPTION
Delete all remote GitHub repo branches with "import" in their name.
(( gh api repos/dddominikk/dom-server/branches --jq '.[].name' ) -imatch "import") | ForEach-Object { gh api -X DELETE "repos/dddominikk/dom-server/git/refs/heads/$($_.tostring())" }
#>

#[System.Windows.Forms.SendKeys]::SendWait("A");
#[System.Windows.Forms.SendKeys]::SendWait("{ENTER}");




function Git-Force-Push() {
    $push0, $push1 = $null;
    $push0 = git push;
    <#Check if the last command yielded an error.#>
    if (-not $?) {
        $currentBranch = git rev-parse --abbrev-ref HEAD
        echo "First git push failed!"
        git pull origin $currentBranch --allow-unrelated-histories
        $push1 = git push --set-upstream origin main
        if (-not $?) {
            throw "`git push --set-upstream origin main` failed as well!"
        }
        else { echo "Second git push successful!" }
    }
    else { echo "First git push successful!" }        
}


function updateNpm { npm update -g npm; };




function deleteAllFilesByExtension() {
    param(
        [Parameter(
            Mandatory = $True,
            Position = 0
        )]
        [string]
        $firstArg,
     
        [Parameter(
            Mandatory = $True,
            ValueFromRemainingArguments = $true,
            Position = 1
        )][string[]]
        $listArgs
    )

    #'$listArgs[{0}]: {1}' -f $count, $listArg
    foreach ($listArg in $listArgs) {
        del *.$listArg
    }
    #del *.$format;
};

<#
.SYNOPSIS
Deletes all files with arbitrary extensions from the current directory.
.DESCRIPTION
The first argument can be a single string|file format, or an array thereof.
.EXAMPLE
`delete-all html files`
.EXAMPLE
`delete-all js,js.map files`
#>
function Delete-All($format, $cmd) {

    if ($cmd -match "files") {

        $args = If ($format -is [array]) { $format } Else { { $format } }

        foreach ($extension in $format) {
            deleteAllFilesByExtension ($extension -replace "^\.", "");
        };
    };
};


function Force-Delete($path) {
    Get-ChildItem -Path $path -Recurse | Remove-Item -force -recurse;
    Remove-Item $path -Force;
}




<#
.DESCRIPTION
Appends one or more lines to a target file. Creates a new file if one doesn't exist.
.EXAMPLE
`append *.js, .hintrc to .gitignore`
.EXAMPLE
`append "# Hello World!" to HelloWorld.md`
#>
function append($text, $target, $path) {
    if ($target -match "to") {
        
        $args = If ($text -is [array]) { $text } Else { [array]($text) };
        
        $model = If (Test-Path $path) { Get-Content $path } Else { "" };
        
        foreach ($line in $args) { $model += $line; };

        $model > $path;
    }
};


# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

function Go-To-Location ($ofThisFile) {
    If (Test-Path $ofThisFile -Type Leaf) {
        $PROFILE.toString() -replace "\\[^\\/]+$" | cd;
    }
    Else {
        If (Test-Path $ofThisFile) { cd $ofThisFile }
    };
}

function Unzip ($path, $DestinationPath = "$(Get-Location)") {
    Expand-Archive "$path" "$DestinationPath";
}


<#
.SYNOPSIS
    Creates a new PSObject where all properties of the original object that are not able to be
    properly serialized to JSON are converted to a value which can be properly converted to JSON.

    This includes the following types:
    *   DateTime

    This conducts a deep property search
.Example 
    Convert an custom PSObject to have parsable dates in Json

    $customObject = New-Object -TypeName PSobject -Property @{ Date = Get-Date; Number = 23; InnerDate = New-Object -TypeName PSObject -Property @{Date=Get-Date;} }

    ## BAD Json
    PS C:\dev> $customObject | ConvertTo-Json
    {
        "Date":  {
                     "value":  "\/Date(1410372629047)\/",
                     "DisplayHint":  2,
                     "DateTime":  "Wednesday, September 10, 2014 2:10:29 PM"
                 },
        "Number":  23,
        "InnerDate":  {
                          "Date":  {
                                       "value":  "\/Date(1410372629047)\/",
                                       "DisplayHint":  2,
                                       "DateTime":  "Wednesday, September 10, 2014 2:10:29 PM"
                                   }
                      }
    }

    ## Good Json
    PS C:\dev> $customObject | ConvertTo-JsonifiablePSObject | ConvertTo-Json
    {
        "Date":  "2014-09-10T14:10:29.0477785-04:00",
        "Number":  23,
        "InnerDate":  {
                          "Date":  "2014-09-10T14:10:29.0477785-04:00"
                      }
    }

#>
function ConvertTo-JsonifiablePSObject {
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$Object
    )

    $newObjectProperties = @{}

    foreach ($property in $Object.psobject.properties) {
        $value = $property.Value

        if ($property.TypeNameOfValue -eq "System.Management.Automation.PSCustomObject") {
            $value = ConvertTo-JsonifiablePSObject -Object $property.Value
        }
        elseif ($property.TypeNameOfValue -eq "System.DateTime") {
            $value = $property.Value.ToString("yyyy'-'MM'-'dd'T'HH':'mm':'ss.fffffffK")
        }

        $newObjectProperties[$property.Name] = $value
    }

    return New-Object -TypeName PSObject -Property $newObjectProperties
};

<#
    REQUIRES ffmpeg
    
    Update yt-dlp by running `yt-dlp -U` if the download fails with an error along the following lines:
    ```
    WARNING: [youtube] oprmuMXtfAo: nsig extraction failed: Some formats may be missing.
    Install PhantomJS to workaround the issue. Please download it from https://phantomjs.org/download.html
    ```
#>
function Download-YT {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$url,

        [Parameter(Mandatory = $false)]
        [string]$cookies
    )

    yt-dlp -U

    $cmd = "yt-dlp -f `"bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4][height<=1080]`" --merge-output-format mp4 `"$url`""

    if ($cookies) {
        $cmd += " --cookies-from-browser $cookies"
    }

    Invoke-Expression $cmd
}




function Download-Steam-Screenshots {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputValue,

        [string]$DownloadFolder
    )

    if ($InputValue -match '^https?://store\.steampowered\.com/app/(\d+)') {
        $AppId = $matches[1]
    }
    elseif ($InputValue -match '^\d+$') {
        $AppId = $InputValue
    }
    else {
        Write-Error "Invalid input: must be a numeric App ID or a valid Steam store URL."
        return
    }

    $url = "https://store.steampowered.com/api/appdetails?appids=$AppId"
    $response = Invoke-RestMethod -Uri $url

    if (-not $response."$AppId".success) {
        Write-Error "Failed to get data for AppID $AppId"
        return
    }

    $data = $response."$AppId".data
    $screenshots = $data.screenshots
    $name = $data.name
    $safeName = ($name -replace '[<>:"/\\|?*]', '').Trim()

    if (-not $DownloadFolder) {
        $DownloadFolder = Join-Path -Path (Get-Location) -ChildPath $safeName
    }

    if (-not (Test-Path $DownloadFolder)) {
        New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
    }

    $index = 1
    foreach ($screenshot in $screenshots) {
        # Strip query string from URL (e.g., ?t=timestamp)
        $url = $screenshot.path_full -replace '\?.*$', ''
        $extension = [System.IO.Path]::GetExtension($url)
        $fileName = "$safeName promo gameplay screenshot $index$extension"
        $filePath = Join-Path $DownloadFolder $fileName

        Write-Host "Downloading: $fileName"
        Invoke-WebRequest -Uri $url -OutFile $filePath

        $index++
    }

    Write-Host "Done. Screenshots saved to '$DownloadFolder'."
}



function Git-Sync-Branch {
    # Get the current branch name
    $currentBranch = git rev-parse --abbrev-ref HEAD
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get current branch. Are you in a git repository?"
        return
    }
    
    # Get the remote origin URL
    $remoteOrigin = git config --get remote.origin.url
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get remote origin URL. Does remote 'origin' exist?"
        return
    }
    
    Write-Host "Current branch: $currentBranch"
    Write-Host "Remote origin: $remoteOrigin"
    
    # Check if the branch exists remotely
    $remoteBranchExists = $false
    $remoteBranches = git ls-remote --heads origin $currentBranch
    
    if ($remoteBranches) {
        Write-Host "Branch '$currentBranch' already exists on remote."
        $remoteBranchExists = $true
    }
    else {
        Write-Host "Branch '$currentBranch' does not exist on remote."
    }
    
    # If branch doesn't exist remotely, push it
    if (-not $remoteBranchExists) {
        Write-Host "Creating branch '$currentBranch' on remote..."
        git push -u origin $currentBranch
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully created remote branch and set up tracking."
        }
        else {
            Write-Error "Failed to push branch to remote."
            return
        }
    }
    else {
        # Ensure tracking is set up if branch already exists
        $trackingBranch = git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Setting up tracking for existing remote branch..."
            git branch --set-upstream-to=origin/$currentBranch $currentBranch
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Successfully set up tracking for existing remote branch."
            }
            else {
                Write-Error "Failed to set upstream tracking branch."
                return
            }
        }
        else {
            Write-Host "Tracking already set up to $trackingBranch"
        }
    }
    
    Write-Host "Branch '$currentBranch' is now properly set up to track 'origin/$currentBranch'."
}



New-Alias restart Restart-PowerShell;

function Restart-PowerShell {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$Command,
        
        [Parameter(Mandatory = $false)]
        [bool]$RunAsAdmin = $false
    )
    
    # Determine the path to use
    $targetPath = if ($Path -and (Test-Path -Path $Path)) { 
        (Resolve-Path $Path).Path 
    }
    else { 
        $PWD.Path 
    }
    
    Write-Host "Restarting PowerShell in: $targetPath"
    
    $wtInstalled = $null -ne (Get-Command "wt.exe" -ErrorAction SilentlyContinue)
    
    $psExe = "powershell.exe"
    
    if ($RunAsAdmin) {
        Write-Host "Launching with administrator privileges..." -ForegroundColor Yellow
        
        $scriptContent = @"
try {
    Set-Location -Path '$targetPath' -ErrorAction Stop
    Write-Host "Successfully changed to directory: '$targetPath'" -ForegroundColor Green
} catch {
    Write-Warning "Could not access directory '$targetPath': `$(`$_.Exception.Message)"
    Write-Host "Starting in default location instead." -ForegroundColor Yellow
}

$Command
"@
        $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
        $scriptContent | Out-File -FilePath $tempFile -Encoding utf8
        
        # Use a direct PowerShell launch for admin mode as WT has issues with elevated processes and directory paths
        Start-Process $psExe -ArgumentList "-NoExit -File `"$tempFile`"" -Verb RunAs
    }
    else {
        if ($wtInstalled) {
            if ($Command) {
                # Create a base64 encoded command to avoid escaping issues
                $fullCommand = "Set-Location -Path '$targetPath'; $Command"
                $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullCommand)
                $encodedCommand = [Convert]::ToBase64String($bytes)
                
                # Use 'wt' to stay in Windows Terminal interface
                # runas.exe /trustlevel:0x20000 | wt.exe -d "$targetPath" powershell.exe
                runas /trustlevel:0x20000 | wt powershell.exe -NoExit -EncodedCommand $encodedCommand
                
            }
            else {
                runas /trustlevel:0x20000 | wt -d "$targetPath" powershell.exe
            }
        }
        else {
            # Fall back to regular PowerShell if Windows Terminal isn't available
            if ($Command) {
                Start-Process $psExe -ArgumentList "-NoExit -Command `"Set-Location -Path '$targetPath'; $Command`""
            }
            else {
                Start-Process $psExe -ArgumentList "-NoExit -Command `"Set-Location -Path '$targetPath'`""
            }
        }
    }
    
    # Wait a moment to ensure the new terminal launches
    Start-Sleep -Milliseconds 500
    
    # Exit the current session
    exit
}

New-Alias -name test-admin -value Test-Admin-Privileges;
function Test-Admin-Privileges {  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

<# function Obsidian {
    Start-Process "C:\Program Files\Obsidian\Obsidian.exe"
}
 #>

function Get-Custom-Functions {
    $myFns = Get-ChildItem function:
    Write-Host "You have $($myFns.Length) functions defined in your profile."
    $myFns.Name
}



function object-has-property {
    param(
        [Parameter(Mandatory = $true)]
        [string]$propertyName,
        
        [Parameter(Mandatory = $true)]
        [object]$object
    )
    [bool]($object.PSobject.Properties.name -match "$propertyName" )
}

<#
.DESCRIPTION
    Saves my PowerShell $PROFILE to its remote origin.
.LINK 
    https://github.com/dddominikk/powershell
#>

function git.CommitProfile {
    param(
        [Parameter(Mandatory = $false)]
        [string]$msg = "Updated PowerShell profile pushed to remote."
    )
    $currentLocation = (Get-Location).Path
    go-to-location $PROFILE
    commit "$msg"
    cd $currentLocation
}

function git.makeUniqueProjectId {
    $remoteUrl = git config --get remote.origin.url
    if ($remoteUrl -match 'github\.com[:/](.+?)(\.git)?$') {
        $ownerRepo = $Matches[1]
        $repoId = gh api "repos/$ownerRepo" --jq ".id"
        $branchName = git rev-parse --abbrev-ref HEAD
        $commitSha = git rev-parse HEAD
        return @{"repoId" = $repoId; repoContext = "$ownerRepo/branch:$branchName#$commitSha" }
    }
    else { Write-Error "Failed to parse GitHub owner/repo from remote origin url" }
}

function git.getLatestTag {
    (git tag --sort v:refname)[-1]
}



<#
.SYNOPSIS
    Creates a nested folder/file structure from a sloppy tree-style string.
#>
function Write-Tree {
    <#
    .SYNOPSIS
    Creates nested folder/file structure from a sloppy tree-style string.
    #>

    param (
        [Parameter(Mandatory)]
        [string]$Tree
    )

    # Remove non-breaking spaces and normalize line endings
    $lines = $Tree -replace "`r", '' -split "`n" | ForEach-Object {
        ($_ -replace '^[\s\|─—\-└├┤┬┴┼│]+', '') -replace '[\|]+$', ''
    } | Where-Object { $_.Trim() -ne '' }

    # Get the first valid root directory line
    $root = $lines | Where-Object { $_ -match '/$' } | Select-Object -First 1
    if (-not $root) {
        Write-Error "No valid root directory found (line ending in '/')."
        return
    }

    $root = $root.TrimEnd('/').Trim()
    if (-not (Test-Path $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    foreach ($line in $lines) {
        if ($line -eq "$root/") { continue }

        $cleanLine = ($line -replace '^[\s\|─—\-└├┤┬┴┼│]+', '') -replace '[\|]+$', ''
        $relativePath = $cleanLine.Trim().TrimEnd('/')

        if ($relativePath -eq '') { continue }

        $fullPath = Join-Path -Path $root -ChildPath $relativePath

        # Skip invalid or unresolved paths
        if (-not $fullPath -or $fullPath -match '[<>:"?*]') { continue }

        $isFile = [System.IO.Path]::HasExtension($relativePath)

        if ($isFile) {
            $dir = Split-Path $fullPath
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            New-Item -ItemType File -Path $fullPath -Force | Out-Null
        }
        else {
            New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        }
    }

    Write-Host "Initialized structure under '$root'" -ForegroundColor Green
}



# cd ..; rm .\ci-utils\ -force -Recurse; Restart-PowerShell -Command "New-GitHubRepo -repoName ci-utils -mainBranch main"
# gh repo delete ci-utils

# $latestV =  (git tag --sort v:refname)[-1]
# gh release create $latestV --title "Release $latestV" --notes "Just a test run for the mmain branch workflow."

<#
.EXAMPLE
    `Show-Tree -Exclude("node_modules")`
#>

function Show-Tree {
    param (
        [string]$Path = ".",
        [string[]]$Exclude = @("node_modules"),
        [int]$Level = 0
    )

    Get-ChildItem -LiteralPath $Path |
    Where-Object { $Exclude -notcontains $_.Name } |
    ForEach-Object {
        $indent = "  " * $Level

        if ($_.PSIsContainer) {
            Write-Output "$indent📁 $($_.Name)"
            Show-Tree -Path $_.FullName -Exclude $Exclude -Level ($Level + 1)
        }
        else {
            Write-Output "$indent📄 $($_.Name)"
        }
    }
}

function Open-Remote-Origin-in-Browser {
    Start-Process msedge.exe (git remote get-url origin)
}

<#
.DESCRIPTION
    Recursively extracts files of matching extensions from a given path, then copies them to the root of that path.

.EXAMPLE

# Copy all .cube files into D:\LUTS\_extracted (flat output)
ExtractFilesByExtension -Path "D:\LUTS" -Extensions ".cube"

# Multiple extensions, custom output folder name
ExtractFilesByExtension -Path "D:\Assets" -Extensions "cube","png","jpg" -OutputFolderName "collected"

# Preserve relative folders under the output directory
ExtractFilesByExtension -Path "D:\Assets" -Extensions ".cube" -Flatten:$false

# Overwrite collisions instead of auto-suffixing
ExtractFilesByExtension -Path "D:\Assets" -Extensions ".cube" -Overwrite

    
#>
function ExtractFilesByExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Extensions,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $OutputFolderName = "_extracted",

        [switch] $Overwrite,

        [switch] $Flatten = $true
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Path does not exist or is not a directory: $Path"
    }

    # Normalize root path
    $root = (Resolve-Path -LiteralPath $Path).Path.TrimEnd('\', '/')

    # Normalize extensions (ensure leading dot) and de-dupe (case-insensitive)
    $extSet = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $Extensions) {
        $n = $e.Trim()
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        if (-not $n.StartsWith('.')) { $n = ".$n" }
        [void]$extSet.Add($n)
    }

    if ($extSet.Count -eq 0) {
        throw "No valid extensions were provided."
    }

    $outDir = Join-Path $root $OutputFolderName
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null

    # Collect matching files
    $files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $extSet.Contains($_.Extension) }

    $copied = New-Object 'System.Collections.Generic.List[string]'

    foreach ($f in $files) {
        # Avoid re-copying output folder contents on reruns
        if ($f.FullName.StartsWith($outDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if ($Flatten) {
            $destPath = Join-Path $outDir $f.Name
        }
        else {
            $relative = $f.FullName.Substring($root.Length).TrimStart('\', '/')
            $destPath = Join-Path $outDir $relative
            $destParent = Split-Path -Parent $destPath
            New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        }

        if (-not $Overwrite) {
            # If destination exists, auto-suffix: name (1).ext, name (2).ext, ...
            if (Test-Path -LiteralPath $destPath) {
                $dir = Split-Path -Parent $destPath
                $base = [System.IO.Path]::GetFileNameWithoutExtension($destPath)
                $ext = [System.IO.Path]::GetExtension($destPath)
                $i = 1
                do {
                    $candidate = Join-Path $dir ("{0} ({1}){2}" -f $base, $i, $ext)
                    $i++
                } while (Test-Path -LiteralPath $candidate)
                $destPath = $candidate
            }
        }

        Copy-Item -LiteralPath $f.FullName -Destination $destPath -Force:$Overwrite | Out-Null
        [void]$copied.Add($destPath)
    }

    # SAFE: force enumeration to string[]
    $extArray = @($extSet) | Sort-Object

    [pscustomobject]@{
        RootPath     = $root
        OutputFolder = $outDir
        Extensions   = $extArray
        MatchedCount = $files.Count
        CopiedCount  = $copied.Count
        CopiedFiles  = $copied
    }
}



function dirname($path = ".") {
    Split-Path -LiteralPath $path
}


function Zip-Rootfiles {
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
    if (-not (Get-Command Invoke-CapacitiesReviveAuto -ErrorAction SilentlyContinue)) {
        Import-Module "$(Split-Path -Parent $PROFILE)\Modules\zip\rootfiles.psm1" -ErrorAction Stop;
    }
    Zip-All-Rootfiles @PSBoundParameters
}


function Get-PathItemSize {
    <#
.SYNOPSIS
  Lists sizes for all immediate files and folders within a path (du-like, one level).

.DESCRIPTION
  - PowerShell 5.1 compatible.
  - Extra-safe: handles access denied, reparse points, etc.
  - Performant: uses .NET enumeration instead of Get-ChildItem -Recurse.
  - Compact output by default (table). Use -Raw to return objects.

.PARAMETER Path
  Target directory. Defaults to current directory.

.PARAMETER Unit
  Display unit: B, KB, MB, GB, TB. Defaults to MB.

.PARAMETER IncludeHidden
  Include hidden/system items.

.PARAMETER FollowReparsePoints
  By default, folder sizes do NOT traverse reparse points (junctions/symlinks).
  Enable this to follow them (use with caution).

.PARAMETER Raw
  If set, return raw objects instead of formatted compact output.

.EXAMPLE
  Get-PathItemSize
  Get-PathItemSize -Path C:\Work -Unit GB
  Get-PathItemSize -Raw | Export-Csv sizes.csv -NoTypeInformation
#>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string] $Path = (Get-Location).Path,

        [ValidateSet('B', 'KB', 'MB', 'GB', 'TB')]
        [string] $Unit = 'MB',

        [switch] $IncludeHidden,

        [switch] $FollowReparsePoints,

        [switch] $Raw
    )

    begin {
        $unitMap = @{
            'B'  = 1.0
            'KB' = 1KB
            'MB' = 1MB
            'GB' = 1GB
            'TB' = 1TB
        }
        $divisor = [double]$unitMap[$Unit]

        function _FormatSize([long] $bytes) {
            if ($divisor -le 1) { return $bytes }
            return [math]::Round(($bytes / $divisor), 2)
        }

        function _IsHiddenOrSystem([System.IO.FileSystemInfo] $fsi) {
            $a = $fsi.Attributes
            return (($a -band [IO.FileAttributes]::Hidden) -ne 0) -or (($a -band [IO.FileAttributes]::System) -ne 0)
        }

        function _IsReparsePoint([System.IO.FileSystemInfo] $fsi) {
            return (($fsi.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
        }

        function _GetDirectorySizeBytes([string] $dirPath) {
            $total = 0L
            $stack = New-Object 'System.Collections.Generic.Stack[string]'
            $stack.Push($dirPath)

            while ($stack.Count -gt 0) {
                $current = $stack.Pop()

                # Files
                try {
                    foreach ($f in [System.IO.Directory]::EnumerateFiles($current)) {
                        try {
                            $fi = New-Object System.IO.FileInfo($f)
                            if (-not $IncludeHidden -and (_IsHiddenOrSystem $fi)) { continue }
                            $total += $fi.Length
                        }
                        catch { }
                    }
                }
                catch { }

                # Subdirs
                try {
                    foreach ($d in [System.IO.Directory]::EnumerateDirectories($current)) {
                        try {
                            $di = New-Object System.IO.DirectoryInfo($d)
                            if (-not $IncludeHidden -and (_IsHiddenOrSystem $di)) { continue }
                            if (-not $FollowReparsePoints -and (_IsReparsePoint $di)) { continue }
                            $stack.Push($di.FullName)
                        }
                        catch { }
                    }
                }
                catch { }
            }

            return $total
        }

        try {
            $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
        }
        catch {
            throw "Path not found or not accessible: $Path"
        }

        if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
            throw "Path is not a directory: $resolved"
        }

        $dirInfo = New-Object System.IO.DirectoryInfo($resolved)
    }

    process {
        $items = New-Object System.Collections.Generic.List[object]

        # Directories
        try {
            foreach ($di in $dirInfo.EnumerateDirectories()) {
                if (-not $IncludeHidden -and (_IsHiddenOrSystem $di)) { continue }

                $bytes = 0L
                $note = $null

                if (-not $FollowReparsePoints -and (_IsReparsePoint $di)) {
                    $note = 'ReparsePointSkipped'
                }
                else {
                    $bytes = _GetDirectorySizeBytes $di.FullName
                }

                $items.Add([PSCustomObject]@{
                        Name      = $di.Name
                        Type      = 'Dir'
                        SizeBytes = $bytes
                        Size      = _FormatSize $bytes
                        Unit      = $Unit
                        Note      = $note
                    })
            }
        }
        catch { }

        # Files
        try {
            foreach ($fi in $dirInfo.EnumerateFiles()) {
                if (-not $IncludeHidden -and (_IsHiddenOrSystem $fi)) { continue }

                $bytes = 0L
                try { $bytes = $fi.Length } catch { $bytes = 0L }

                $items.Add([PSCustomObject]@{
                        Name      = $fi.Name
                        Type      = 'File'
                        SizeBytes = $bytes
                        Size      = _FormatSize $bytes
                        Unit      = $Unit
                        Note      = $null
                    })
            }
        }
        catch { }

        $result = $items | Sort-Object SizeBytes -Descending

        if ($Raw) {
            return $result
        }

        # Default: compact display output
        $result |
        Select-Object @{
            Name = 'Size'; Expression = { "{0}{1}" -f $_.Size, $_.Unit }
        }, Type, Name, Note |
        Format-Table -AutoSize
    }
}

function capacities-revive {
    [CmdletBinding()]
    param(
        [string]$InputDir = ".",
        [string]$OutDir = "$($(remove-extension $inputDir))",
        [switch]$Overwrite = $false,
        [switch]$DryRun,
        [bool]$DeleteSource = $true
    )

    if (-not (Get-Command Invoke-CapacitiesReviveAuto -ErrorAction SilentlyContinue)) {
        Import-Module "$(Split-Path -Parent $PROFILE)\Modules\capacities.io\reviver.psm1" -ErrorAction Stop
    }

    Invoke-CapacitiesReviveAuto -InputDir $InputDir -OutDir "$OutDir" -overwrite -DeleteSource $DeleteSource
}

function Remove-Extension {
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject
    )

    process {

        $text = switch ($InputObject) {

            { $_ -is [System.IO.FileSystemInfo] } {
                $_.FullName
                break
            }

            { $_ -is [string] } {
                $_
                break
            }

            { $_.PSObject.Properties['FullName'] } {
                $_.FullName
                break
            }

            { $_.PSObject.Properties['Name'] } {
                $_.Name
                break
            }

            default {
                $_.ToString()
            }
        }

        # Remove last extension if it exists
        if ($text -match '\.d\.ts$') {
            return $text -replace '\.d\.ts$', ''
        }
        else {
            return $text -replace '\.[^.]+$', ''
        }
    }
}


function Get-AllItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [switch]$Recurse,

        [ScriptBlock]$ForEach
    )

    # Normalize / expand
    $p = [Environment]::ExpandEnvironmentVariables($Path)

    if ($p -eq '~' -or $p -like '~\*' -or $p -like '~/\*') {
        $home = [Environment]::GetFolderPath('UserProfile')
        $rest = $p.Substring(1).TrimStart('\', '/')
        $p = if ($rest) { Join-Path $home $rest } else { $home }
    }

    try {
        $abs = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
    }
    catch {
        $abs = [IO.Path]::GetFullPath($p)
    }

    # Ensure parent directory exists
    $ensuredDir = Ensure-Path -Path $abs -SkipLastNode:$true

    # CASE 1: Path exists and is a file → return single element
    if (Test-Path -LiteralPath $abs -PathType Leaf) {

        $item = Get-Item -LiteralPath $abs

        if ($ForEach) {
            Validate-ForEachBlock $ForEach
            return , (& $ForEach $item)
        }

        return , $item
    }

    # CASE 2: Path exists and is directory → enumerate it
    if (Test-Path -LiteralPath $abs -PathType Container) {

        $items = if ($Recurse) {
            Get-ChildItem -LiteralPath $abs -Recurse -Force
        }
        else {
            Get-ChildItem -LiteralPath $abs -Force
        }

        return Invoke-ForEachIfNeeded $items $ForEach
    }

    # CASE 3: Path does not exist → enumerate ensured parent
    $items = if ($Recurse) {
        Get-ChildItem -LiteralPath $ensuredDir -Recurse -Force
    }
    else {
        Get-ChildItem -LiteralPath $ensuredDir -Force
    }

    return Invoke-ForEachIfNeeded $items $ForEach
}

# Helper: validate ForEach scriptblock
function Validate-ForEachBlock {
    param([ScriptBlock]$Block)

    $pb = $Block.Ast.ParamBlock
    $count = if ($pb) { $pb.Parameters.Count } else { 0 }

    if ($count -ne 1) {
        throw "ForEach script block must accept exactly 1 parameter. Found: $count"
    }
}

# Helper: apply ForEach if provided
function Invoke-ForEachIfNeeded {
    param(
        [object[]]$Items,
        [ScriptBlock]$Block
    )

    if (-not $Block) { return $Items }

    Validate-ForEachBlock $Block

    return $Items | ForEach-Object {
        & $Block $_
    }
}


function Ensure-Path {
    
    <#
    Ensures the directory portion of a path exists, and optionally creates the last node.
    Always returns a normalized absolute path string.

    -SkipLastNode (default $true):
      Creates parent directories only and returns the parent (full path minus last node).

    -SkipLastNode:$false:
      Creates the last node too (dir or file) and returns the full path.
  #>

    [CmdletBinding(DefaultParameterSetName = "Auto")]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,

        [Parameter(ParameterSetName = "Directory")]
        [switch]$Directory,

        [Parameter(ParameterSetName = "File")]
        [switch]$File,

        [bool]$SkipLastNode = $true
    )

    # 1) Expand environment variables like %TEMP%
    $p = [Environment]::ExpandEnvironmentVariables($Path)

    # 2) Expand ~
    if ($p -eq '~' -or $p -like '~\*' -or $p -like '~/\*') {
        $home = [Environment]::GetFolderPath('UserProfile')
        $rest = $p.Substring(1).TrimStart('\', '/')
        $p = if ($rest) { Join-Path $home $rest } else { $home }
    }

    # 3) Normalize to absolute path *without requiring it to exist*
    #    If it exists, Resolve-Path gives canonical casing; otherwise GetFullPath is safe.
    try {
        $abs = (Resolve-Path -LiteralPath $p -ErrorAction Stop).Path
    }
    catch {
        $abs = [System.IO.Path]::GetFullPath($p)
    }

    # Determine whether path should be treated as directory.
    # - If user forces -Directory / -File, trust that.
    # - Otherwise: trailing slash/backslash means directory.
    $treatAsDir = $Directory.IsPresent -or (-not $File.IsPresent -and ($Path -match '[\\/]\s*$'))

    # If skipping last node, we ensure the *parent directory* exists and return it.
    if ($SkipLastNode) {
        # For a directory-ish path with trailing slash, "last node" is the final folder.
        # So parent is one level up.
        $targetDir = if ($treatAsDir) { Split-Path -Path $abs -Parent } else { Split-Path -Path $abs -Parent }

        if ([string]::IsNullOrWhiteSpace($targetDir)) {
            $targetDir = (Get-Location).Path
        }

        if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        return $targetDir
    }

    # Otherwise, ensure parent exists, then create the last node as file/dir.
    $parent = Split-Path -Path $abs -Parent
    if ([string]::IsNullOrWhiteSpace($parent)) {
        $parent = (Get-Location).Path
    }

    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ($treatAsDir) {
        if (-not (Test-Path -LiteralPath $abs -PathType Container)) {
            New-Item -ItemType Directory -Path $abs -Force | Out-Null
        }
        return $abs
    }
    else {
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            New-Item -ItemType File -Path $abs -Force | Out-Null
        }
        return $abs
    }


}