#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
Import-Module -Name "$PSScriptRoot\Functions.psm1" -Force

# region Variables
$Parameters = @{
    Message = 'Please choose a folder where are the xpui folders are located'
    Type = 'Folder'
}
$xpuiArchivePath = Get-PathFromDialog @Parameters

$Parameters = @{
    Message = 'Please choose a folder where is the css map is located'
    Type = 'File'
}
$cssMapPath = Get-PathFromDialog @Parameters
# endregion Variables

# region Main
Remove-OutdatedMappings -CssMapPath $cssMapPath -XpuiArchivePath $xpuiArchivePath
# endregion Main
