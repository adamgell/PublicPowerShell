# Tests/Module.Tests.ps1

BeforeAll {
    # Get the module root path
    $script:ModuleRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
    $script:ModuleName = 'IntuneDriverManagement'
    
    # Import the module
    Import-Module $script:ModuleRoot -Force
    
    # Get the module path
    $script:ModuleRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
    
    # Import required Graph modules first
    Import-Module Microsoft.Graph.Authentication -Force
    Import-Module Microsoft.Graph.DeviceManagement -Force
    Import-Module Microsoft.Graph.Groups -Force
    Import-Module Microsoft.Graph.DeviceManagement.Actions -Force
    
    # Import our module
    Import-Module $script:ModuleRoot -Force
}

Describe "$ModuleName Module Structure" {
    Context "Module Setup" {
        It "Should be valid PowerShell module" {
            Test-ModuleManifest -Path $script:ModuleRoot\$script:ModuleName.psd1 | Should -Not -BeNullOrEmpty
            $true | Should -BeTrue
        }

        It "Should have required functions exported" {
            Get-Command -Module $script:ModuleName -CommandType Function | Should -Not -BeNullOrEmpty
        }

        It "Should have all required dependencies available" {
            $manifest = Import-PowerShellDataFile -Path $script:ModuleRoot\$script:ModuleName.psd1
            foreach ($module in $manifest.RequiredModules) {
                if ($module -is [System.Collections.Hashtable]) {
                    Get-Module -ListAvailable -Name $module.ModuleName | Should -Not -BeNullOrEmpty
                } else {
                    Get-Module -ListAvailable -Name $module | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
}

# Run after all tests to clean up
AfterAll {
    Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
}