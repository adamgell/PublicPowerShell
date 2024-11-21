Describe "RenameComputer Script Tests" {
    BeforeAll {
        $script:testPath = ".\RenameComputerPrefixSerialNoTaskLocked.ps1"
        
        # Mock cmdlets
        Mock Write-Host { }
        Mock Start-Transcript { }
        Mock Stop-Transcript { }
        Mock mkdir { }
        Mock Set-Content { }
        Mock Test-Path { $false } # Default to directory not existing
        Mock Get-ComputerInfo {
            @{
                CsUserName = "defaultUser"
                CsPartOfDomain = $true
                BiosSerialNumber = "TEST123"
                CsPCSystemTypeEx = "Laptop"
            }
        }
    }

    Context "Environment Setup" {
        It "Creates log directory if it doesn't exist" {
            Mock Test-Path { return $false }
            & $testPath
            Assert-MockCalled mkdir -Times 1 -Exactly
        }
    }

    Context "Computer Information" {
        It "Retrieves computer information" {
            & $testPath
            Assert-MockCalled Get-ComputerInfo -Times 1 -Exactly
        }

        It "Handles info retrieval errors" {
            Mock Get-ComputerInfo { throw "Error" }
            & $testPath
            Assert-MockCalled Stop-Transcript -Times 1 -Exactly
        }
    }

    Context "Computer Rename Operation" {
        BeforeEach {
            $env:ComputerName = "PREFIX-OLD"
            Mock Get-ComputerInfo {
                @{
                    CsUserName = "defaultUser"
                    CsPartOfDomain = $true
                    BiosSerialNumber = "TEST123"
                    CsPCSystemTypeEx = "Desktop"
                }
            }
            Mock Rename-Computer { }
        }

        It "Executes rename with correct parameters" {
            & $testPath
            Assert-MockCalled Rename-Computer -Times 1 -Exactly
        }
    }

    Context "Domain Checks" {
        It "Exits if not domain joined" {
            Mock Get-ComputerInfo {
                @{
                    CsUserName = "defaultUser"
                    CsPartOfDomain = $false
                }
            }
            & $testPath
            Assert-MockCalled Stop-Transcript -Times 1 -Exactly
        }
    }
}