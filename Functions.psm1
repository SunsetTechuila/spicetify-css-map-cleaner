#Requires -Version 7.0
$ErrorActionPreference = 'Stop'

function Get-PathFromDialog {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet('File', 'Folder')]
        [string]$Type
    )
    begin {
        Add-Type -AssemblyName 'System.Windows.Forms'
        switch ($Type) {
            'File' {
                $dialog = New-Object -TypeName 'System.Windows.Forms.OpenFileDialog'
            }
            'Folder' {
                $dialog = New-Object -TypeName 'System.Windows.Forms.FolderBrowserDialog'
            }
        }
    }  
    process {
        if ($Message) {
            Write-Host -Object $Message
        }
        if ($dialog.ShowDialog() -ne 'OK') {
            Write-Error -Message 'No folder selected!'
        }
    }
    end {
        switch ($Type) {
            'File' {
                $dialog.FileName
            }
            'Folder' {
                $dialog.SelectedPath
            }
        }
    }
}

function Remove-OutdatedMappings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
        [string]$CssMapPath,

        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path -Path $_ -PathType 'Container' })]
        [string]$XpuiArchivePath
    )
    begin {
        $initialCssMap = Get-Content -Path $CssMapPath -Force -Raw | ConvertFrom-Json -AsHashtable
        $outdatedCssMap = $initialCssMap.Clone()
        $actualCssMap = $initialCssMap.Clone()
        $xpuiFolders = Get-ChildItem -Path $XpuiArchivePath -Force -Directory
        Write-Host -Object 'Searching for outdated mappings...' -ForegroundColor 'Cyan'
    }
    process {
        foreach ($folder in $xpuiFolders) {
            $foundClasses = $folder.GetFiles() | ForEach-Object -Parallel {
                if ($PSItem.Extension -match 'js|css') {
                    $content = [System.IO.File]::ReadAllText($PSItem.FullName)
                    foreach ($class in $($using:outdatedCssMap.Keys)) {
                        if ($content -match $class) { $class }
                    }
                }
            } -ThrottleLimit 50
            foreach ($class in $foundClasses) {
                $outdatedCssMap.Remove($class)
            }
        }
        
        foreach ($key in $outdatedCssMap.Keys) {
            $actualCssMap.Remove($key) > $null
        }
        $droppedClasses = foreach ($value in $outdatedCssMap.Values) {
            if (-not ($actualCssMap.ContainsValue($value))) { $value }
        }

        Set-Content -Value $droppedClasses -Path "$PSScriptRoot\dropped-classes.txt" -Force
        $outdatedCssMap | ConvertTo-Json | Set-Content -Path "$PSScriptRoot\css-map-outdated.json" -Force
    }
    end {
        Write-Host -Object 'Done!' -ForegroundColor 'Green'
        Write-Host -Object "Initial amount of mapped classes: $($initialCssMap.Count)"
        Write-Host -Object "Current amount of mapped classes: $($actualCssMap.Count)"
        Write-Host -Object "Amount of outdated mappings: $($outdatedCssMap.Count)"
        Write-Host -Object "Amount of dropped classes that may need to be remapped: $($droppedClasses.Count)"

        $host.UI.RawUI.FlushInputBuffer()
        $choice = $host.UI.PromptForChoice('', 'Do you want to remove outdated mappings?', @('&Yes', '&No'), 1)
        if ($choice -eq 0) {
            $actualCssMap | ConvertTo-Json | Set-Content -Path $CssMapPath -Force
            Write-Host -Object 'Outdated mappings removed!' -ForegroundColor 'Yellow'
        }
        else {
            $actualCssMap | ConvertTo-Json | Set-Content -Path "$PSScriptRoot\css-map-actual.json" -Force
        }
    }
}
