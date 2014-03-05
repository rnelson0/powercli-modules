<#
.Synopsis
   Copy a specified module file to the User or Global module path
.DESCRIPTION
   Copy a specified module file. Determine whether it is loaded in the User or Global module path and whether existing modules should be overwritten
.EXAMPLE
   Copy-Module C:\powershell\sample-module.psm1
.EXAMPLE
   Copy-Module C:\powershell\sample-module.psm1 -Global -Overwrite
#>
Function Copy-Module
{
    [CmdletBinding()]
    Param
    (
        # The full path to the module
        [string]
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Path,

        # When set to true, the module is copied to the Global module location. Otherwise, the User module location is used.
        [switch]
        [Parameter()]
        $Global,

        # Indicate whether to overwrite an existing module with the same name.
        [switch]
        [Parameter()]
        $Overwrite
    )
    $UserPath = $env:PSModulePath.split(";")[0]
    $GlobalPath = $env:PSModulePath.split(";")[1]
    if ($Global) {
        $Target = $GlobalPath
    }
    else {
        $Target = $UserPath
    }
    $ModulePath = Join-Path -path $Target -childpath (Get-Item -path $Path).basename
    if ($Overwrite) {
        New-Item  -path $ModulePath -itemtype directory -Force | Out-Null
        Copy-item -path $Path -destination $ModulePath -Force | Out-Null
    }
    else {
        New-Item  -path $ModulePath -itemtype directory | Out-Null
        Copy-item -path $Path -destination $ModulePath | Out-Null
    }
}