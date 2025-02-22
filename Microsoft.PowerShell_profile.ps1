Set-StrictMode -Version 5;
<#git autocomplete#>
Import-Module posh-git

<#
 .NOTES
    See [PowerShell Docs](https://learn.microsoft.com/en-us/powershell/module/psreadline/set-psreadlineoption).
#>
Set-PSReadLineOption -Colors @{
    "Parameter"="#86BBD8"
    #"Command"="Blue"
    "Error"=[System.ConsoleColor]::DarkRed 
}

[System.Collections.Stack]$GLOBAL:dirStack = @()
$GLOBAL:oldDir = ''
$GLOBAL:addToStack = $true
function prompt
{
    Write-Host "PS $(get-location)>"  -NoNewLine -foregroundcolor "Magenta"
    $GLOBAL:nowPath = (Get-Location).Path
    if(($nowPath -ne $oldDir) -AND $GLOBAL:addToStack){
        $GLOBAL:dirStack.Push($oldDir)
        $GLOBAL:oldDir = $nowPath
    }
    $GLOBAL:AddToStack = $true
    return ' '
}
function GoBack{
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
function toJson64(){
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$obj
        )
    $hsh = {}
    if($obj) {$hsh = $obj}
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $hsh -compress)));
}

New-Alias iu Invoke-Utility;

<#
.DESCRIPTION
`npm run` shorthand.
#>
function nrun {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptName,

        [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)]
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




<#
.DESCRIPTION
Commits unstaged changes to tracked files.
#>
function git.commit {
    Param([Parameter(Mandatory)][string]$message);
    git add -u;
    git commit -m $message;
    git fetch;
    git pull;
    git push;
};

New-Alias commit git.commit;



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
function git.resetUntracked {
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
function tsn ($path){
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

function git.tagLastCommit($tag, $message) {
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
    } else {
        Write-Host "Remote origin already exists, setting URL..."
        git remote set-url origin $remoteUrl
    }

    # Perform a test push to the main branch
    try {
        Write-Host "Performing a test push to $mainBranchName..."
        git push -u origin $mainBranchName
        Write-Host "Push successful!"
    } catch {
        Write-Host "Error during push. Please check your configuration."
    }
}

# Example usage:
# Connect-GitRepo -remoteUrl "https://github.com/yourusername/yourrepository.git" -mainBranchName "main"




    #[System.Windows.Forms.SendKeys]::SendWait("A");
    #[System.Windows.Forms.SendKeys]::SendWait("{ENTER}");




function git.forcePush() {
    $push0,$push1 = $null;
    $push0 = git push;
    <#Check if the last command yielded an error.#>
    if (-not $?) {
            echo "First git push failed!"
            $push1 = git push --set-upstream origin main
            if(-not $?) {
                throw "`git push --set-upstream origin main` failed as well!"
            }
            else{ echo "Second git push successful!"}
        }
    else {echo "First git push successful!"}        
}


function updateNpm { npm update -g npm; };




function deleteAllFilesByExtension() {
      param(
        [Parameter(
            Mandatory=$True,
            Position = 0
        )]
        [string]
        $firstArg,
     
        [Parameter(
            Mandatory=$True,
            ValueFromRemainingArguments=$true,
            Position = 1
        )][string[]]
        $listArgs
    )

    #'$listArgs[{0}]: {1}' -f $count, $listArg
    foreach($listArg in $listArgs) {
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


function Force-Delete($path){
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
#>
function Download-YT {
    param(
            [Parameter(Mandatory=$true, ValueFromPipeline = $true)]
        [string]$url
    )

    yt-dlp -f "bestvideo[ext=mp4][height<=1080]+bestaudio[ext=m4a]/best[ext=mp4][height<=1080]" --merge-output-format mp4 "$url"

}