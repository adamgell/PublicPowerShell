# Tests/Unit/IntuneDevice.Tests.ps1

BeforeAll {
    # Load test helper functions
    . "$PSScriptRoot\..\TestHelper.ps1"
    $testEnv = Initialize-TestEnvironment

    # Mock Get-LenovoFriendlyName since it's used by the class
    Mock Get-LenovoFriendlyName {
        param($MTM)
        return "ThinkPad L13 Gen 3"
    } -ModuleName $testEnv.ModuleName
}

Describe "IntuneDevice Class" {
    Context "Constructor Tests" {
        It "Should create a new instance with basic properties" {
            # Act
            $device = [IntuneDevice]::new("Microsoft", "Surface Pro")

            # Assert
            $device | Should -Not -BeNullOrEmpty
            $device.Manufacturer | Should -Be "Microsoft"
            $device.Model | Should -Be "Surface Pro"
            $device.OriginalModel | Should -Be "Surface Pro"
        }

        It "Should normalize manufacturer names" {
            $testCases = @(
                @{ Input = "LENOVO"; Expected = "Lenovo" }
                @{ Input = "Hewlett-Packard"; Expected = "HP" }
                @{ Input = "HP"; Expected = "HP" }
                @{ Input = "DELL"; Expected = "Dell" }
                @{ Input = "Microsoft Corporation"; Expected = "Microsoft" }
            )

            foreach ($test in $testCases) {
                # Act
                $device = [IntuneDevice]::new($test.Input, "Test Model")

                # Assert
                $device.Manufacturer | Should -Be $test.Expected -Because "Input was $($test.Input)"
            }
        }
    }

    Context "Lenovo Model Name Conversion" {
        It "Should convert Lenovo MTM to friendly name" {
            # Act
            $device = [IntuneDevice]::new("Lenovo", "20VX")

            # Assert
            $device.FriendlyName | Should -Be "ThinkPad L13 Gen 3"
            $device.OriginalModel | Should -Be "20VX"
            Should -Invoke Get-LenovoFriendlyName -ModuleName $testEnv.ModuleName -Times 1
        }

        It "Should handle invalid Lenovo MTM gracefully" {
            # Act
            $device = [IntuneDevice]::new("Lenovo", "InvalidMTM")

            # Assert
            $device.FriendlyName | Should -Be "InvalidMTM"
            $device.OriginalModel | Should -Be "InvalidMTM"
        }
    }
}