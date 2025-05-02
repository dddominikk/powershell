Set-StrictMode -Version 5;
<#git autocomplete#>
Import-Module posh-git

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
Commits unstaged changes to tracked files.
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
    
    git push
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to push changes. You may need to pull first or resolve conflicts."
        return
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


function gb {
    git branch;
};

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
function listAllCustomFunctions {
    return Get-ChildItem function:\;
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

    git init

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
        git push -u origin $mainBranchName
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
        git pull origin $currentBranch
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




function Download-SteamScreenshots {
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
    
    # Check if Windows Terminal is installed
    $wtInstalled = $null -ne (Get-Command "wt.exe" -ErrorAction SilentlyContinue)
    
    # Base PowerShell executable
    $psExe = "powershell.exe"
    
    # Check if administrator mode is requested
    if ($RunAsAdmin) {
        Write-Host "Launching with administrator privileges..." -ForegroundColor Yellow
        
        # Create a script that properly sets the location and then runs any commands
        $scriptContent = @"
try {
    # Attempt to set location to target path
    Set-Location -Path '$targetPath' -ErrorAction Stop
    Write-Host "Successfully changed to directory: '$targetPath'" -ForegroundColor Green
} catch {
    Write-Warning "Could not access directory '$targetPath': `$(`$_.Exception.Message)"
    Write-Host "Starting in default location instead." -ForegroundColor Yellow
}

# Execute any provided commands
$Command
"@
        
        # Save to a temporary file
        $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
        $scriptContent | Out-File -FilePath $tempFile -Encoding utf8
        
        # For admin mode, we'll use a direct PowerShell launch
        # Windows Terminal has issues with elevated processes and directory paths
        Start-Process $psExe -ArgumentList "-NoExit -File `"$tempFile`"" -Verb RunAs
    }
    else {
        # Standard non-admin launch
        if ($wtInstalled) {
            # Use Windows Terminal if available
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