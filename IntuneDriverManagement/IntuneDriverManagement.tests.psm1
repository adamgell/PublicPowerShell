# Tests.ps1

BeforeAll {
    # Import the module
    Import-Module ./IntuneDriverManagement.psm1 -Force
}

Describe "Device Information Processing" {
    Context "When processing Lenovo devices" {
        It "Should correctly normalize Lenovo manufacturer names" {
            $deviceInfo = Get-IntuneDeviceInfo -Manufacturer "LENOVO" -Model "20VX"
            $deviceInfo.Manufacturer | Should -Be "Lenovo"
        }

        It "Should handle Lenovo model name conversion" {
            $deviceInfo = Get-IntuneDeviceInfo -Manufacturer "LENOVO" -Model "20VX"
            $deviceInfo.FriendlyName | Should -Not -Be "20VX"
            $deviceInfo.OriginalModel | Should -Be "20VX"
        }
    }

    Context "When processing HP devices" {
        It "Should normalize different HP manufacturer names" {
            $deviceInfo1 = Get-IntuneDeviceInfo -Manufacturer "HP" -Model "EliteBook"
            $deviceInfo2 = Get-IntuneDeviceInfo -Manufacturer "Hewlett-Packard" -Model "EliteBook"
            
            $deviceInfo1.Manufacturer | Should -Be "HP"
            $deviceInfo2.Manufacturer | Should -Be "HP"
        }
    }
}

Describe "Group Management" {
    Context "When creating new groups" {
        BeforeAll {
            # Mock the Graph API calls
            Mock Get-MgGroup { return $null }
            Mock New-MgGroup { 
                return @{
                    Id = "test-group-id"
                    DisplayName = "Test Group"
                }
            }
        }

        It "Should create a group with correct naming convention" {
            $deviceInfo = [IntuneDevice]::new("Lenovo", "ThinkPad")
            $group = New-IntuneDriverGroup -DeviceInfo $deviceInfo
            
            Should -Invoke Get-MgGroup -Times 1
            Should -Invoke New-MgGroup -Times 1
            $group | Should -Not -BeNullOrEmpty
        }
    }

    Context "When group already exists" {
        BeforeAll {
            Mock Get-MgGroup { 
                return @{
                    Id = "existing-group-id"
                    DisplayName = "Existing Group"
                }
            }
            Mock New-MgGroup { throw "Should not be called" }
        }

        It "Should not create duplicate groups" {
            $deviceInfo = [IntuneDevice]::new("Lenovo", "ThinkPad")
            $group = New-IntuneDriverGroup -DeviceInfo $deviceInfo
            
            Should -Invoke Get-MgGroup -Times 1
            Should -Invoke New-MgGroup -Times 0
            $group.Id | Should -Be "existing-group-id"
        }
    }
}

Describe "Profile Assignment" {
    Context "When creating new assignments" {
        BeforeAll {
            Mock Invoke-MgGraphRequest {
                param($Method, $Uri)
                if ($Method -eq "GET") {
                    return @{ value = @() }
                }
                return @{ id = "new-assignment-id" }
            }
        }

        It "Should create assignment when none exists" {
            $result = New-IntuneDriverProfileAssignment -ProfileId "test-profile" -GroupId "test-group"
            $result | Should -Not -BeNullOrEmpty
            Should -Invoke Invoke-MgGraphRequest -Times 2
        }
    }
}
