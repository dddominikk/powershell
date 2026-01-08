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
function gitInit {
    param (
        [string]$remoteUrl,
        [string]$mainBranchName
    )

    # Set the current directory to your repository's local directory if necessary
    # Set-Location -Path "C:\Path\To\Your\Repo"

    # Check current branch and rename if needed
    $currentBranch = git rev-parse --abbrev-ref HEAD
    if ($currentBranch -ne $mainBranchName) {
        Write-Host "Renaming branch from $currentBranch to $mainBranchName..."
        git branch -m $mainBranchName
    }

    # Add remote origin and set it if it doesn't exist
    if (-not (git remote -v | Select-String "origin")) {
        Write-Host "Adding remote origin..."
        git remote add origin $remoteUrl
    }
    else {
        Write-Host "Remote origin already exists, setting URL..."
        git remote set-url origin $remoteUrl
    }

    # Perform a test push to the main branch
    try {
        Write-Host "Performing a test push to $mainBranchName..."
        git push -u origin $mainBranchName --allow-unrelated-histories
        Write-Host "Push successful!"
    }
    catch {
        Write-Host "Error during push. Please check your configuration."
    }
}

# Example usage:
# Connect-GitRepo -remoteUrl "https://github.com/yourusername/yourrepository.git" -mainBranchName "main"




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

function Obsidian {
    Start-Process "C:\Program Files\Obsidian\Obsidian.exe"
}


function Get-Custom-Functions {
    $myFns = Get-ChildItem function:
    Write-Host "You have $($myFns.Length) functions defined in your profile."
    $myFns.Name
}

<#
.DESCRIPTION
    1. Fetch "$MyGhUsername/$repoName" repo from GitHub.
    2. Create a new remote GH repo if it doesn't exist.
    3. Connect the fetched/created repo to the local directory.    
#>
function GhInit {
    param (
        [Parameter(Mandatory = $true)]
        [string]$repoName,

        # Optional path: ".", existing dir, or new dir
        [Parameter(Mandatory = $false)]
        [string]$path,

        [Parameter(Mandatory = $false)]
        [string]$mainBranch = "main",

        # Optional: explicit owner/org
        [Parameter(Mandatory = $false)]
        [string]$owner
    )

    if ((git config --get init.defaultBranch) -ne $mainBranch) {
        git config --global init.defaultBranch $mainBranch
    }

    # Resolve GitHub username if owner not provided
    if ([string]::IsNullOrWhiteSpace($owner)) {
        $owner = (gh api user -q .login).Trim()
    }

    $fullName = "$owner/$repoName"

    # Resolve working directory
    if ([string]::IsNullOrWhiteSpace($path)) {
        # Default: create/use folder named after repo
        $workingDir = $repoName
        if (-not (Test-Path -LiteralPath $workingDir)) {
            New-Item -ItemType Directory -Path $workingDir | Out-Null
        }
    }
    else {
        # Path explicitly provided (e.g. "." or custom dir)
        $workingDir = Resolve-Path -LiteralPath $path -ErrorAction SilentlyContinue
        if (-not $workingDir) {
            New-Item -ItemType Directory -Path $path | Out-Null
            $workingDir = Resolve-Path -LiteralPath $path
        }
        $workingDir = $workingDir.Path
    }

    Push-Location $workingDir

    try {
        # Init repo if needed
        if (-not (Test-Path -LiteralPath ".git")) {
            git init | Out-Null
        }

        # Ensure branch
        $currentBranch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
        if ([string]::IsNullOrWhiteSpace($currentBranch) -or $currentBranch -eq "HEAD") {
            git checkout -b $mainBranch | Out-Null
        }

        # .gitignore + initial commit
        if (-not (Test-Path -LiteralPath ".gitignore")) {
            "node_modules`n" | Set-Content -Encoding UTF8 .gitignore
            git add .gitignore | Out-Null
        }

        git rev-parse --verify HEAD *> $null
        if ($LASTEXITCODE -ne 0) {
            git add . | Out-Null
            git commit -m "Initial commit" | Out-Null
        }

        # Check if repo exists remotely
        gh repo view $fullName --json name --jq .name *> $null
        $repoExists = ($LASTEXITCODE -eq 0)

        if ($repoExists) {
            $remoteUrl = (gh repo view $fullName --json sshUrl -q .sshUrl).Trim()

            git remote get-url origin 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                git remote set-url origin $remoteUrl | Out-Null
            }
            else {
                git remote add origin $remoteUrl | Out-Null
            }

            $branchToPush = (git rev-parse --abbrev-ref HEAD).Trim()
            git push -u origin $branchToPush
        }
        else {
            gh repo create $fullName --private --source=. --remote=origin --push
        }
    }
    finally {
        Pop-Location
    }
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



