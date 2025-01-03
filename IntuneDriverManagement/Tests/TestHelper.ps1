# Tests/TestHelper.ps1

function Initialize-TestEnvironment {
    [CmdletBinding()]
    param()
    
    # Get module root path
    $script:ModuleRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
    $script:ModuleName = 'IntuneDriverManagement'

    # Import class definition directly
    . "$ModuleRoot\classes\IntuneDevice.ps1"
    
    # Import module
    Import-Module $ModuleRoot -Force

    # Set up default mocks that all tests might need
    Mock Write-Error { } -ModuleName $ModuleName
    Mock Write-Warning { } -ModuleName $ModuleName
    Mock Write-Verbose { } -ModuleName $ModuleName

    # Return paths for use in tests
    return @{
        ModuleRoot = $ModuleRoot
        ModuleName = $ModuleName
    }
}