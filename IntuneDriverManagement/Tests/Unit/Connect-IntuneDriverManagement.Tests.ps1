# Tests/Unit/Connect-IntuneDriverManagement.Tests.ps1

BeforeAll {
    # Load test helper functions
    . "$PSScriptRoot\..\TestHelper.ps1"
    $testEnv = Initialize-TestEnvironment

    # Define test variables
    $script:RequiredScopes = @(
        "DeviceManagementManagedDevices.ReadWrite.All",
        "Group.ReadWrite.All",
        "DeviceManagementConfiguration.ReadWrite.All",
        "GroupMember.ReadWrite.All"
    )

    # Set up default successful context
    $script:SuccessfulContext = [PSCustomObject]@{
        Account = "test@contoso.com"
        Scopes = $script:RequiredScopes
    }
}

Describe "Connect-IntuneDriverManagement" {
    BeforeEach {
        # Reset all mocks before each test
        Mock Connect-MgGraph { return $script:SuccessfulContext } -ModuleName $testEnv.ModuleName
        Mock Get-MgContext { return $null } -ModuleName $testEnv.ModuleName
        Mock Write-Error { } -ModuleName $testEnv.ModuleName
        Mock Write-Verbose { } -ModuleName $testEnv.ModuleName
    }

    Context "Connection Scenarios" {
        It "Should attempt to connect when no existing context exists" {
            # Arrange
            Mock Get-MgContext { return $null } -ModuleName $testEnv.ModuleName
            
            # Act
            $result = Connect-IntuneDriverManagement

            # Assert
            $result | Should -BeTrue
            Should -Invoke Connect-MgGraph -Times 1 -Exactly -ModuleName $testEnv.ModuleName
        }

        It "Should reuse existing connection when valid context exists" {
            # Arrange
            Mock Get-MgContext { return $script:SuccessfulContext } -ModuleName $testEnv.ModuleName

            # Act
            $result = Connect-IntuneDriverManagement

            # Assert
            $result | Should -BeTrue
            Should -Invoke Connect-MgGraph -Times 0 -Exactly -ModuleName $testEnv.ModuleName
        }

        It "Should handle connection failures gracefully" {
            # Arrange
            Mock Connect-MgGraph { throw "Connection failed" } -ModuleName $testEnv.ModuleName

            # Act
            $result = Connect-IntuneDriverManagement

            # Assert
            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ModuleName $testEnv.ModuleName
        }
    }

    Context "Error Handling" {
        It "Should handle null response from Get-MgContext" {
            # Arrange
            Mock Connect-MgGraph { return $null } -ModuleName $testEnv.ModuleName

            # Act
            $result = Connect-IntuneDriverManagement

            # Assert
            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ModuleName $testEnv.ModuleName
        }

        It "Should handle exceptions during context check" {
            # Arrange
            Mock Get-MgContext { throw "Unexpected error" } -ModuleName $testEnv.ModuleName

            # Act
            $result = Connect-IntuneDriverManagement

            # Assert
            $result | Should -BeFalse
            Should -Invoke Write-Error -Times 1 -ModuleName $testEnv.ModuleName
        }
    }
}