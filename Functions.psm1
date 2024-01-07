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
        [string]$XpuiPath
    )
    begin {
        $initialCssMap = Get-Content -Path $CssMapPath -Raw | ConvertFrom-Json -AsHashtable
        $outdatedCssMap = $initialCssMap.Clone()
        $classesToFind = $cssMap.Keys
        $xpuiFolders = Get-ChildItem -Path $XpuiPath -Directory
    }
    process {
        $foundClasses = $xpuiFolders | ForEach-Object -ThrottleLimit $env:NUMBER_OF_PROCESSORS -Parallel {
            $classesToFind = $using:classesToFind
            $PSItem.GetFiles() | ForEach-Object -ThrottleLimit $env:NUMBER_OF_PROCESSORS -Parallel {
                if ($PSItem.Extension -match 'js|css') {
                    $content = Get-Content -Path $PSItem.FullName -Raw
                    foreach ($class in $using:classesToFind) {
                        if ($content -match $class) { $class }
                    }
                }
            }
        }
    }
    end {
        $foundClasses | Get-Unique | ForEach-Object -Process {
            $outdatedCssMap.Remove($PSItem) | Out-Null
        }
        foreach ($key in $outdatedCssMap.Keys) {
            $initialCssMap.Remove($key) | Out-Null
        }
        $initialCssMap | ConvertTo-Json | Set-Content -Path $CssMapPath
    }
}
