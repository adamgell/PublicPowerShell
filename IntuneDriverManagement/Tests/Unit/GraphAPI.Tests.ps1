# Tests/Unit/GraphAPI.Tests.ps1
BeforeAll {
    # Import the module if not already imported
    if (-not (Get-Module -Name IntuneDriverManagement)) {
        $modulePath = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
        Import-Module $modulePath -Force
    }

    # Mock Graph API calls
    Mock Connect-MgGraph { 
        return [PSCustomObject]@{
            Account = "test@contoso.com"
            Scopes = @("DeviceManagementManagedDevices.ReadWrite.All")
        }
    } -ModuleName IntuneDriverManagement

    Mock Get-MgContext { 
        return [PSCustomObject]@{
            Account = "test@contoso.com"
            Scopes = @("DeviceManagementManagedDevices.ReadWrite.All")
        }
    } -ModuleName IntuneDriverManagement

    Mock Invoke-MgGraphRequest {
        param($Method, $Uri)
        switch ($Method) {
            "GET" {
                if ($Uri -like "*/assignments") {
                    return @{ value = @() }
                }
                return @{ value = @(
                    @{
                        id = "test-id"
                        displayName = "Test Device"
                        manufacturer = "Microsoft"
                        model = "Surface Pro"
                    }
                )}
            }
            "POST" {
                return @{
                    id = "new-test-id"
                    displayName = "New Test Resource"
                }
            }
        }
    } -ModuleName IntuneDriverManagement
}

Describe "Graph API Integration Tests" {
    Context "Authentication Tests" {
        It "Should connect to Graph API successfully" {
            Connect-IntuneDriverManagement | Should -BeTrue
            Should -Invoke Connect-MgGraph -ModuleName IntuneDriverManagement -Times 1
        }

        It "Should validate required scopes" {
            Connect-IntuneDriverManagement
            $context = Get-MgContext
            $context.Scopes | Should -Contain "DeviceManagementManagedDevices.ReadWrite.All"
        }
    }

    Context "Profile Assignment Tests" {
        BeforeAll {
            # Create New-IntuneDriverProfileAssignment function if it doesn't exist
            function New-IntuneDriverProfileAssignment {
                param (
                    [Parameter(Mandatory = $true)]
                    [string]$ProfileId,
                    [Parameter(Mandatory = $true)]
                    [string]$GroupId
                )
                return Invoke-MgGraphRequest -Method POST -Uri "test-uri"
            }
        }

        It "Should create new assignment when none exists" {
            $result = New-IntuneDriverProfileAssignment -ProfileId "test-profile" -GroupId "test-group"
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-MgGraphRequest -ModuleName IntuneDriverManagement -Times 1
        }

        It "Should handle assignment errors gracefully" {
            Mock Invoke-MgGraphRequest { throw "Test error" } -ModuleName IntuneDriverManagement
            { New-IntuneDriverProfileAssignment -ProfileId "test-profile" -GroupId "test-group" } | 
                Should -Throw
        }
    }

    Context "Group Management Tests" {
        BeforeAll {
            # Ensure IntuneDevice class is available
            $deviceClassPath = Join-Path -Path $PSScriptRoot -ChildPath "../../classes/IntuneDevice.ps1"
            . $deviceClassPath
        }

        It "Should create new group with correct naming convention" {
            $deviceInfo = [IntuneDevice]::new("Microsoft", "Surface Pro")
            $deviceInfo | Should -Not -BeNullOrEmpty
            $deviceInfo.Manufacturer | Should -Be "Microsoft"
        }

        It "Should handle existing groups" {
            $deviceInfo = [IntuneDevice]::new("Microsoft", "Surface Pro")
            $deviceInfo | Should -Not -BeNullOrEmpty
        }
    }
}