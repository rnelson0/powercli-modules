Some simple modules for interacting with PowerCLI.

To install for the first time, launch PowerShell ISE. Cd to the directory where the files are and run these commands:

    Import-Module .\Copy-Module.psm1
    Copy-Module Copy-Module.psm1 
    Copy-Module PowerCLI-Administrator-Cmdlets.psm1
    Copy-Module PowerCLI-User-Cmdlets.psm1

To upgrade to a new version:

    Copy-Module Copy-Module.psm1 -Overwrite
    Copy-Module PowerCLI-Administrator-Cmdlets.psm1 -Overwrite
    Copy-Module PowerCLI-User-Cmdlets.psm1 -Overwrite
