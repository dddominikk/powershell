﻿Set-StrictMode -Version 5;

<#
.DESCRIPTION
Commits unstaged changes to tracked files.
#>
function git.commit {
    Param([Parameter(Mandatory)][string]$message);
    git add -u;
    git commit -m $message;
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


function gitNoNode {
    git rm - r--cached.;
    git add.;
    git commit - m "auto-recommiting to get rid of node_modules dirs from source control.";
    git push;
};

function tsc($flag) {
    
    if ($flag) { return npx tsc -$flag };

    return npx tsc;
};

function Is-File ($path) { Test-Path "$path" -PathType Leaf };
function Is-Folder ($path) { Test-Path "$path" -PathType Container };

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

function updateNpm { npm update -g npm; };

function deleteAllFilesByExtension($format) {
    del *.$format;
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