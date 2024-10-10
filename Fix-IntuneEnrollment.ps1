<#PSScriptInfo
.VERSION 0.11
.GUID 715a6707-796c-445f-9e8a-8a0fffd778a4
.AUTHOR Rudy Ooms
.COMPANYNAME
.COPYRIGHT
.TAGS Windows, AutoPilot, Powershell
.LICENSEURI
.PROJECTURI https://www.github.com
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.RELEASENOTES
Version 0.1: Initial Release.
version 0.2: added way more checks and fixes
version 0.3: added the mdmurls check
version 0.8: added the IME service check and reinstall functionality and improved some error handling
Adam Gell - edits the comments and expanded the encoded code. 
.PRIVATEDATA
#>
<#
.DESCRIPTION
.SYNOPSIS
GUI to fix intune sync issues.
MIT LICENSE
Copyright (c) 2022 Rudy Ooms
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
.DESCRIPTION
The goal of this script is to help with the troubleshooting of Attestation issues when enrolling your device with Autopilot for Pre-Provisioned deployments
.EXAMPLE
Blog post with examples and explanations @call4cloud.nl
.LINK
Online version: https://call4cloud.nl/
#>
function test-intunesyncerrors {

    ########
    ### Version 0.8 | This tool will check for missing Intune certificates, if the Certificate is in the wrong certificate store, and if the certificate has been expired
    #######

    #################################
    #defining some functions first###
    ###################################

    function fix-wrongstore { 
        $title = 'Fixing missing Certificate in the System Store'
        $question = 'Are you sure you want to proceed?'
        $choices = '&Yes', '&No'
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
                
        if ($decision -eq 0) {        
            $progressPreference = 'silentlyContinue'
            write-host "Exporting and Importing the Intune certificate to the proper Certificate Store" -foregroundcolor yellow
            Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/PSTools.zip' -OutFile 'pstools.zip'
            Expand-Archive -Path 'pstools.zip' -DestinationPath "$env:TEMP\pstools" -force
            Move-Item -Path "$env:TEMP\pstools\psexec.exe" -force
            reg.exe ADD HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f | out-null
            Start-Process -windowstyle hidden -FilePath "$env:TEMP\pstools\psexec.exe" -ArgumentList '-s cmd /c "powershell.exe -ExecutionPolicy Bypass -encodedcommand JABjAGUAcgB0AGkAZgBpAGMAYQB0AGUAIAA9ACAARwBlAHQALQBDAGgAaQBsAGQASQB0AGUAbQAgAC0AUABhAHQAaAAgAEMAZQByAHQAOgBcAEMAdQByAHIAZQBuAHQAdQBzAGUAcgBcAE0AeQBcAAoAJABwAGEAcwBzAHcAbwByAGQAPQAgACIAcwBlAGMAcgBlAHQAIgAgAHwAIABDAG8AbgB2AGUAcgB0AFQAbwAtAFMAZQBjAHUAcgBlAFMAdAByAGkAbgBnACAALQBBAHMAUABsAGEAaQBuAFQAZQB4AHQAIAAtAEYAbwByAGMAZQAKAEUAeABwAG8AcgB0AC0AUABmAHgAQwBlAHIAdABpAGYAaQBjAGEAdABlACAALQBDAGUAcgB0ACAAJABjAGUAcgB0AGkAZgBpAGMAYQB0AGUAIAAtAEYAaQBsAGUAUABhAHQAaAAgAGMAOgBcAGkAbgB0AHUAbgBlAC4AcABmAHgAIAAtAFAAYQBzAHMAdwBvAHIAZAAgACQAcABhAHMAcwB3AG8AcgBkAAoASQBtAHAAbwByAHQALQBQAGYAeABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIAAtAEUAeABwAG8AcgB0AGEAYgBsAGUAIAAtAFAAYQBzAHMAdwBvAHIAZAAgACQAcABhAHMAcwB3AG8AcgBkACAALQBDAGUAcgB0AFMAdABvAHIAZQBMAG8AYwBhAHQAaQBvAG4AIABDAGUAcgB0ADoAXABMAG8AYwBhAGwATQBhAGMAaABpAG4AZQBcAE0AeQAgAC0ARgBpAGwAZQBQAGEAdABoACAAYwA6AFwAaQBuAHQAdQBuAGUALgBwAGYAeAA="'
        }
        else {
            Write-Host 'Exiting...' -foregroundcolor red
            read-Host -prompt "Press any key to continue..."
            exit
        }
    }    

    function check-certdate {
        Write-Host "Checking If the Certificate hasn't expired" -foregroundcolor yellow
        if ((Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumbprint -and $_.NotAfter -lt (Get-Date) }) -eq $null) {
            Write-Host "The Intune Device Certificate is not expired." -foregroundcolor green
        }
        else {
            Write-Host "The Intune Device Certificate is EXPIRED!" -foregroundcolor red
            fix-certificate
        }
    }



    function check-intunecert {
        if (Get-ChildItem Cert:\LocalMachine\My\ | where { $_.issuer -like "*Microsoft Intune MDM Device CA*" }) {
            write-Host "Intune Device Certificate is in installed in the Local Machine Certificate store" -foregroundcolor green
        }
        else {
            Write-Host "Intune device Certificate still seems to be missing... sorry!" -foregroundcolor red    
        }
    }


    function fix-certificate { 
        $title = 'Fixing the Intune Enrollment'
        $question = 'Are you 100% sure you want to proceed?'
        $choices = '&Yes', '&No'
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
                
        if ($decision -eq 0) {
            $progressPreference = 'silentlyContinue'
            write-host "Trying to enroll your device into Intune or something else..." -foregroundcolor yellow
            fix-mdmurls
            Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/PSTools.zip' -OutFile 'pstools.zip'
            Expand-Archive -Path 'pstools.zip' -DestinationPath "$env:TEMP\pstools" -force
            Move-Item -Path "$env:TEMP\pstools\psexec.exe" -force
            reg.exe ADD HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f | out-null
            $enroll = Start-Process -windowstyle hidden -FilePath "$env:TEMP\pstools\psexec.exe" -ArgumentList '-s cmd /c "powershell.exe -ExecutionPolicy Bypass -encodedcommand JABSAGUAZwBpAHMAdAByAHkASwBlAHkAcwAgAD0AIAAiAEgASwBMAE0AOgBcAFMATwBGAFQAVwBBAFIARQBcAE0AaQBjAHIAbwBzAG8AZgB0AFwARQBuAHIAbwBsAGwAbQBlAG4AdABzACIALAAgACIASABLAEwATQA6AFwAUwBPAEYAVABXAEEAUgBFAFwATQBpAGMAcgBvAHMAbwBmAHQAXABFAG4AcgBvAGwAbABtAGUAbgB0AHMAXABTAHQAYQB0AHUAcwAiACwAIgBIAEsATABNADoAXABTAE8ARgBUAFcAQQBSAEUAXABNAGkAYwByAG8AcwBvAGYAdABcAEUAbgB0AGUAcgBwAHIAaQBzAGUAUgBlAHMAbwB1AHIAYwBlAE0AYQBuAGEAZwBlAHIAXABUAHIAYQBjAGsAZQBkACIALAAgACIASABLAEwATQA6AFwAUwBPAEYAVABXAEEAUgBFAFwATQBpAGMAcgBvAHMAbwBmAHQAXABQAG8AbABpAGMAeQBNAGEAbgBhAGcAZQByAFwAQQBkAG0AeABJAG4AcwB0AGEAbABsAGUAZAAiACwAIAAiAEgASwBMAE0AOgBcAFMATwBGAFQAVwBBAFIARQBcAE0AaQBjAHIAbwBzAG8AZgB0AFwAUABvAGwAaQBjAHkATQBhAG4AYQBnAGUAcgBcAFAAcgBvAHYAaQBkAGUAcgBzACIALAAiAEgASwBMAE0AOgBcAFMATwBGAFQAVwBBAFIARQBcAE0AaQBjAHIAbwBzAG8AZgB0AFwAUAByAG8AdgBpAHMAaQBvAG4AaQBuAGcAXABPAE0AQQBEAE0AXABBAGMAYwBvAHUAbgB0AHMAIgAsACAAIgBIAEsATABNADoAXABTAE8ARgBUAFcAQQBSAEUAXABNAGkAYwByAG8AcwBvAGYAdABcAFAAcgBvAHYAaQBzAGkAbwBuAGkAbgBnAFwATwBNAEEARABNAFwATABvAGcAZwBlAHIAIgAsACAAIgBIAEsATABNADoAXABTAE8ARgBUAFcAQQBSAEUAXABNAGkAYwByAG8AcwBvAGYAdABcAFAAcgBvAHYAaQBzAGkAbwBuAGkAbgBnAFwATwBNAEEARABNAFwAUwBlAHMAcwBpAG8AbgBzACIACgAkAEkAbgB0AHUAbgBlAEMAZQByAHQAIAA9ACAARwBlAHQALQBDAGgAaQBsAGQASQB0AGUAbQAgAC0AUABhAHQAaAAgAEMAZQByAHQAOgBcAEwAbwBjAGEAbABNAGEAYwBoAGkAbgBlAFwATQB5ACAAfAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAKAAkACQAkAF8ALgBJAHMAcwB1AGUAcgAgAC0AbQBhAHQAYwBoACAAIgBJAG4AdAB1AG4AZQAgAE0ARABNACIAIAAKAAkAfQAgAHwAIABSAGUAbQBvAHYAZQAtAEkAdABlAG0ACgAkAEUAbgByAG8AbABsAG0AZQBuAHQASQBEACAAPQAgAEcAZQB0AC0AUwBjAGgAZQBkAHUAbABlAGQAVABhAHMAawAgAHwAIABXAGgAZQByAGUALQBPAGIAagBlAGMAdAAgAHsAJABfAC4AVABhAHMAawBQAGEAdABoACAALQBsAGkAawBlACAAIgAqAE0AaQBjAHIAbwBzAG8AZgB0ACoAVwBpAG4AZABvAHcAcwAqAEUAbgB0AGUAcgBwAHIAaQBzAGUATQBnAG0AdAAqACIAfQAgAHwAIABTAGUAbABlAGMAdAAtAE8AYgBqAGUAYwB0ACAALQBFAHgAcABhAG4AZABQAHIAbwBwAGUAcgB0AHkAIABUAGEAcwBrAFAAYQB0AGgAIAAtAFUAbgBpAHEAdQBlACAAfAAgAFcAaABlAHIAZQAtAE8AYgBqAGUAYwB0ACAAewAkAF8AIAAtAGwAaQBrAGUAIAAiACoALQAqAC0AKgAiAH0AIAB8ACAAUwBwAGwAaQB0AC0AUABhAHQAaAAgAC0ATABlAGEAZgAKAEcAZQB0AC0AUwBjAGgAZQBkAHUAbABlAGQAVABhAHMAawAgAHwAIABXAGgAZQByAGUALQBPAGIAagBlAGMAdAAgAHsAJABfAC4AVABhAHMAawBwAGEAdABoACAALQBtAGEAdABjAGgAIAAkAEUAbgByAG8AbABsAG0AZQBuAHQASQBEAH0AIAB8ACAAVQBuAHIAZQBnAGkAcwB0AGUAcgAtAFMAYwBoAGUAZAB1AGwAZQBkAFQAYQBzAGsAIAAtAEMAbwBuAGYAaQByAG0AOgAkAGYAYQBsAHMAZQAKAAkACQAJAGYAbwByAGUAYQBjAGgAIAAoACQASwBlAHkAIABpAG4AIAAkAFIAZQBnAGkAcwB0AHIAeQBLAGUAeQBzACkAIAB7AAoACQAJAAkACQBpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAALQBQAGEAdABoACAAJABLAGUAeQApACAAewAKAAkACQAJAAkACQBnAGUAdAAtAEMAaABpAGwAZABJAHQAZQBtACAALQBQAGEAdABoACAAJABLAGUAeQAgAHwAIABXAGgAZQByAGUALQBPAGIAagBlAGMAdAAgAHsAJABfAC4ATgBhAG0AZQAgAC0AbQBhAHQAYwBoACAAJABFAG4AcgBvAGwAbABtAGUAbgB0AEkARAB9ACAAfAAgAFIAZQBtAG8AdgBlAC0ASQB0AGUAbQAgAC0AUgBlAGMAdQByAHMAZQAgAC0ARgBvAHIAYwBlACAALQBDAG8AbgBmAGkAcgBtADoAJABmAGEAbABzAGUAIAAtAEUAcgByAG8AcgBBAGMAdABpAG8AbgAgAFMAaQBsAGUAbgB0AGwAeQBDAG8AbgB0AGkAbgB1AGUACgAJAH0ACgBmAG8AcgBlAGEAYwBoACAAKAAkAGUAbgByAG8AbABsAG0AZQBuAHQAIABpAG4AIAAkAGUAbgByAG8AbABsAG0AZQBuAHQAaQBkACkAewAKAEcAZQB0AC0AUwBjAGgAZQBkAHUAbABlAGQAVABhAHMAawAgAHwAIABXAGgAZQByAGUALQBPAGIAagBlAGMAdAAgAHsAJABfAC4AVABhAHMAawBwAGEAdABoACAALQBtAGEAdABjAGgAIAAkAEUAbgByAG8AbABsAG0AZQBuAHQAfQAgAHwAIABVAG4AcgBlAGcAaQBzAHQAZQByAC0AUwBjAGgAZQBkAHUAbABlAGQAVABhAHMAawAgAC0AQwBvAG4AZgBpAHIAbQA6ACQAZgBhAGwAcwBlAAoAfQAgAAkACgAJAAkACQB9AAoACQAJAAkAUwB0AGEAcgB0AC0AUwBsAGUAZQBwACAALQBTAGUAYwBvAG4AZABzACAANQAKACQARQBuAHIAbwBsAGwAbQBlAG4AdABQAHIAbwBjAGUAcwBzACAAPQAgAFMAdABhAHIAdAAtAFAAcgBvAGMAZQBzAHMAIAAtAEYAaQBsAGUAUABhAHQAaAAgACIAQwA6AFwAVwBpAG4AZABvAHcAcwBcAFMAeQBzAHQAZQBtADMAMgBcAEQAZQB2AGkAYwBlAEUAbgByAG8AbABsAGUAcgAuAGUAeABlACIAIAAtAEEAcgBnAHUAbQBlAG4AdABMAGkAcwB0ACAAIgAvAEMAIAAvAEEAdQB0AG8AZQBuAHIAbwBsAGwATQBEAE0AIgAgAC0ATgBvAE4AZQB3AFcAaQBuAGQAbwB3ACAALQBXAGEAaQB0ACAALQBQAGEAcwBzAFQAaAByAHUA"' 
            $enroll
            write-host "`n"

            write-host "Please give the OMA DM client some time (about 20 seconds)to sync and get your device enrolled into Intune" -foregroundcolor yellow
            write-host "`n"
            start-sleep -seconds 20
            write-host "Checking the Intune Certificate Again!." -foregroundcolor yellow
            check-intunecert
            check-dmwapservice
            Get-ScheduledTask | ? { $_.TaskName -eq 'Schedule #1 created by enrollment client' } | Start-ScheduledTask
            start-sleep -seconds 10
            $Shell = New-Object -ComObject Shell.Application
            $Shell.open("intunemanagementextension://syncapp")
            check-dmpcert
            start-sleep -seconds 5
            get-schedule1
            read-Host -prompt "Press any key to continue..."
            exit    
        }
        else {
            write-host "`n"
            Write-Host 'You dont like me fixing it...? Fine...exiting now' -foregroundcolor red
            exit 1
        }
    }



    function fix-privatekey {                 
        $title = 'Intune Private Key'
        $question = 'Are you sure you want to fix the private key missing??'
        $choices = '&Yes', '&No'
        $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
                
        if ($decision -eq 0) {
            Write-Host "List certificates without private key: " -NoNewline
            $certsWithoutKey = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.HasPrivateKey -eq $false }
                            
            if ($certsWithoutKey) {
                Write-Host "V" -ForegroundColor Green
                $Choice = $certsWithoutKey | Select-Object Subject, Issuer, NotAfter, ThumbPrint | Out-Gridview -Passthru
                                    
                if ($Choice) {
                    Write-Host "Search private key for $($Choice.Thumbprint): " -NoNewline
                    $Output = certutil -repairstore my "$($Choice.Thumbprint)"
                    $Result = [regex]::match($output, "CertUtil: (.*)").Groups[1].Value
                                        
                    if ($Result -eq '-repairstore command completed successfully.') {
                        Write-Host "V" -ForegroundColor Green
                    }
                    else {
                        Write-Host $Result -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "No choice was made." -ForegroundColor DarkYellow
                }
            }
            else {
                Write-Host "There were no certificates found without private key." -ForegroundColor DarkYellow
            }
        }
        else {
            Write-Host 'You cancelled the fix... why?' -foregroundcolor red
            Write-Host "Press any key to continue..."
            $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            exit 1
        }
    }


    function get-privatekey { 
        if ((Get-ChildItem Cert:\LocalMachine\My | where { $_.Thumbprint -match $thumbprint }).HasPrivateKey) {
            Write-Host "Nice.. your Intune Device Certificate still has its private key" -foregroundcolor green
        }
        else {
            Write-Host "I guess we need to fix something because the certificate is missing its private key"  -foregroundcolor red 
            fix-privatekey
        }
    }


    function check-mdmlog {
        Write-Host "Hold on a moment... Initializing a sync and checking the MDM logs for sync errors!"  -foregroundcolor yellow
        $Shell = New-Object -ComObject Shell.Application
        $Shell.open("intunemanagementextension://syncapp")
        start-sleep -seconds 5

        Remove-Item -Path $env:TEMP\diag\* -Force -ErrorAction SilentlyContinue 
        Start-Process MdmDiagnosticsTool.exe -Wait -ArgumentList "-out $env:TEMP\diag\" -NoNewWindow

        $checkmdmlog = Select-String -Path $env:TEMP\diag\MDMDiagReport.html -Pattern "The last sync failed"
        if ($checkmdmlog -eq $null) {
            Write-Host "Not detecting any sync errors in the MDM log" -foregroundcolor green
        }
        else {
            Write-Host "It's a good thing you are running this script because you do have some Intune sync issues going on"  -foregroundcolor red 
        }
    }


    function check-imelog { 
        $path = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log"
        If (Test-Path $path) { 
            $checklog = Select-String -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log' -Pattern "Set MdmDeviceCertificate : $thumbprint"
            if ($checklog -ne $null) {
                Write-Host "The proper Intune certificate with $thumbprint is also mentioned in the IME" -foregroundcolor green
            }
            else {
                $checklogzero = Select-String -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log' -Pattern "Find 0 MDM certificates"
                $firstline = $checklogzero | select-object -first 1         
                Write-Host "this is could not be a good thing... $firstline"  -foregroundcolor red 
            }
        }
        Else { Write-Host "the log is missing... it seems the IME is not installed"  -foregroundcolor red }
        check-imeservice
    }
 


    function check-dmpcert {
        write-host "`n"
        write-host "Determing if the certificate mentioned in the SSLClientCertreference is also configured in the Enrollments part of the registry " -foregroundcolor yellow
        try {     
            $ProviderRegistryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Enrollments"
            $ProviderPropertyName = "ProviderID"
            $ProviderPropertyValue = "MS DM Server"
            $GUID = (Get-ChildItem -Path Registry::$ProviderRegistryPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty -Name $ProviderPropertyName -Path $_.PSPath -ErrorAction SilentlyContinue | Get-ItemPropertyValue -Name $ProviderPropertyName -ErrorAction SilentlyContinue) -match $ProviderPropertyValue) { $_ } }).PSChildName
            $cert = (Get-ChildItem Cert:\LocalMachine\My\ | where { $_.issuer -like "*Microsoft Intune MDM Device CA*" })
            $certthumbprint = $cert.thumbprint
            $certsubject = $cert.subject
            $subject = $certsubject -replace "CN=", ""
        }
        catch {
            Write-host "Failed to get guid for enrollment from registry, device doesnt seem enrolled?" -foregroundcolor red
        } 

        if ((Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Enrollments\$guid").DMPCertThumbPrint -eq $certthumbprint) {
            Write-Host "Great!!! The Intune Device Certificate with the Thumbprint $certthumbprint is configured in the registry Enrollments" -foregroundcolor green
        }
        else {
            Write-Host "Intune Device Certificate is not configured in the Registry Enrollments" -foregroundcolor red
        }
    }


    function get-sslclientcertreference {
        try { 
            $ProviderRegistryPath = "HKLM:SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\"
            $ProviderPropertyName = "ServerVer"
            $ProviderPropertyValue = "4.0"
            $GUID = (Get-ChildItem -Path $ProviderRegistryPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty -Name $ProviderPropertyName -Path $_.PSPath -ErrorAction SilentlyContinue | Get-ItemPropertyValue -Name $ProviderPropertyName -ErrorAction SilentlyContinue) -match $ProviderPropertyValue) { $_ } }).PSChildName
            $ssl = (Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$guid" -ErrorAction SilentlyContinue).sslclientcertreference
        } 
        catch [System.Exception] {
            Write-Error "Failed to get Enrollment GUID or SSL Client Reference for enrollment from registry, device doesnt seem enrolled or it needs a reboot first" 
            $result = $false
        }

        if ($ssl -eq $null) {
            Write-Host "Thats weird, your device doesnt seem to be enrolled into Intune." -foregroundcolor red
        }
        else {
            Write-Host "Device seems to be Enrolled into Intune... proceeding" -foregroundcolor green
        }                        
    }



    function check-imeservice {
        write-host "`n"
        write-host "Determing if the IME service is succesfully installed" -foregroundcolor yellow
        $path = "C:\Program Files (x86)\Microsoft Intune Management Extension\Microsoft.Management.Services.IntuneWindowsAgent.exe"
        If (Test-Path $path) { 
            write-host "IntuneWindowsAgent.exe is available on the device"-foregroundcolor green
            write-host "Going to check if the IME service is installed" -foregroundcolor yellow
            $service = Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue
            if ($service.Length -gt 0) {
                Write-Host "the IME service seems to be installed!" -foregroundcolor green
            }
            else {
                Write-Host "Mmm okay.. The IME software isn't installed" -foregroundcolor red
            }
        }
        else {
            write-host "IntuneWindowsAgent.exe seems to be missing, checking if its even installed" -foregroundcolor red
            if ((Get-WmiObject -Class Win32_Product).caption -eq "Microsoft Intune Management Extension") { 
                Write-Host "the IME software seems to be installed!" -foregroundcolor green
            }
            else {
                Write-Host "The IME software isn't installed" -foregroundcolor red
                $title = 'Fixing the IME'
                $question = 'Are you 100% sure you want to proceed?!!!!!'
                $choices = '&Yes', '&No'
                $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
                
                if ($decision -eq 0) {
                    $ProviderRegistryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\EnterpriseDesktopAppManagement\S-0-0-00-0000000000-0000000000-000000000-000\MSI"    
                    $ProviderPropertyName = "CurrentDownloadUrl"        
                    $ProviderPropertyValue = "*IntuneWindowsAgent.msi*"    
                    $GUID = (Get-ChildItem -Path Registry::$ProviderRegistryPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty -Name $ProviderPropertyName -Path $_.PSPath -ErrorAction SilentlyContinue | Get-ItemPropertyValue -Name $ProviderPropertyName -ErrorAction SilentlyContinue) -like $ProviderPropertyValue) { $_ } }).pschildname | select-object -first 1                      
                    $link = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\EnterpriseDesktopAppManagement\S-0-0-00-0000000000-0000000000-000000000-000\MSI\$GUID                    
                    $link = $link.currentdownloadurl                    
                    Invoke-WebRequest -Uri $link -OutFile 'IntuneWindowsAgent.msi'                    
                    .\IntuneWindowsAgent.msi /quiet
                }
                else {
                    write-host "`n"
                    Write-Host 'Exiting now' -foregroundcolor red
                                            
                }                

            }

        }
    }



    function check-entdmid {
        write-host "`n"
        write-host "Determing if the certificate subject is also configured in the EntDMID key " -foregroundcolor yellow
        try {     
            $ProviderRegistryPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Enrollments"
            $ProviderPropertyName = "ProviderID"
            $ProviderPropertyValue = "MS DM Server"
            $GUID = (Get-ChildItem -Path Registry::$ProviderRegistryPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty -Name $ProviderPropertyName -Path $_.PSPath -ErrorAction SilentlyContinue | Get-ItemPropertyValue -Name $ProviderPropertyName -ErrorAction SilentlyContinue) -match $ProviderPropertyValue) { $_ } }).PSChildName
            $cert = (Get-ChildItem Cert:\LocalMachine\My\ | where { $_.issuer -like "*Microsoft Intune MDM Device CA*" })
            $certthumbprint = $cert.thumbprint
            $certsubject = $cert.subject
            $subject = $certsubject -replace "CN=", ""
        }
        catch {
            Write-host "Failed to get guid for enrollment from registry, device doesnt seem enrolled?" -foregroundcolor red
        } 

        if ((Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Enrollments\$guid\DMClient\MS DM Server").entdmid -eq $subject) {
            Write-Host "I have good news!! The subject of the Intune Certificate is also set in the EntDMID registry key. Let's party!!!!" -foregroundcolor green
        }
        else {
            Write-Host "The EntDMID key is not configured, you probably need to reboot the device and run the test again" -foregroundcolor red
        }
    }


    function check-dmwapservice {
        write-host "`n"
        write-host "Determing if the dmwappushservice is running because we don't want to end up with no endpoints left to the endpointmapper" -foregroundcolor yellow
        $ServiceName = "dmwappushservice"
        $ServiceStatus = (Get-Service -Name $ServiceName).status
        if ($ServiceStatus -eq "Running") {
            Write-Host "I am happy...! The DMWAPPUSHSERVICE is Running!" -foregroundcolor green
        }
        else {
            Write-Host "The DMWAPPUSHSERVICE isn't running, let's kickstart that damn service to speed up the enrollment! " -foregroundcolor red
            Start-Service $Servicename -ErrorAction SilentlyContinue    
        }
    }

    function get-schedule1 {
        write-host "Almost finished, checking if the EnterpriseMGT tasks are running to start the sync!" -foregroundcolor yellow
        If ((Get-ScheduledTask | Where TaskName -eq 'Schedule #1 created by enrollment client').State -eq 'running') {
            write-host "`n"
            write-host "Enrollment task is running! It looks like I fixed your sync issues.I guess you owe me a membeer now!" -foregroundcolor green
        }
        elseif ((Get-ScheduledTask | Where TaskName -eq 'Schedule #1 created by enrollment client').State -eq 'ready') {
            write-host "Enrollment task is ready!!!" -foregroundcolor green
        }
        else {
            write-host "Enrollment task doesn't exist" -foregroundcolor red
        }
    }


    function fix-mdmurls {
        write-host "`n"
        write-host "Determing if the required MDM enrollment urls are configured in the registry" -foregroundcolor yellow

        $key = 'SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\*' 
        $keyinfo = Get-Item "HKLM:\$key" -ErrorAction Ignore
        $url = $keyinfo.name
        $url = $url.Split("\")[-1]
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\TenantInfo\$url" 

        if (test-path $path) {
            $mdmurl = get-itemproperty -LiteralPath $path -Name 'MdmEnrollmentUrl'
            $mdmurl = $mdmurl.mdmenrollmenturl
        }
        else {
            write-host "I guess I am missing the proper tenantinfo" -foregroundcolor red 
        }


        if ($mdmurl -eq "https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc") {
            write-host "MDM Enrollment URLS are configured the way I like it!Nice!!" -foregroundcolor green
        
        }
        else {
            write-host "MDM enrollment url's are missing! Let me get my wrench and fix it for you!" -foregroundcolor red 
            New-ItemProperty -LiteralPath $path -Name 'MdmEnrollmentUrl' -Value 'https://enrollment.manage.microsoft.com/enrollmentserver/discovery.svc' -PropertyType String -Force -ea SilentlyContinue;
            New-ItemProperty -LiteralPath $path  -Name 'MdmTermsOfUseUrl' -Value 'https://portal.manage.microsoft.com/TermsofUse.aspx' -PropertyType String -Force -ea SilentlyContinue;
            New-ItemProperty -LiteralPath $path -Name 'MdmComplianceUrl' -Value 'https://portal.manage.microsoft.com/?portalAction=Compliance' -PropertyType String -Force -ea SilentlyContinue;

            
        }
    }

    ##################################################################
    ###############starting the reallll script########################
    ##################################################################

    check-mdmlog
    write-host "`n"
    write-host "Determining if the device is enrolled and fetching the SSLClientCertReference registry key" -foregroundcolor yellow
    try { 
        $ProviderRegistryPath = "HKLM:SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\"
        $ProviderPropertyName = "SslClientCertReference"
        $GUID = (Get-ChildItem -Path $ProviderRegistryPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty -Name $ProviderPropertyName -Path $_.PSPath -ErrorAction SilentlyContinue | Get-ItemPropertyValue -Name $ProviderPropertyName -ErrorAction SilentlyContinue)) { $_ } }).PSChildName
        $ssl = (Get-ItemProperty -Path "HKLM:SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$guid" -ErrorAction SilentlyContinue).sslclientcertreference
    } 
    catch [System.Exception] {
        Write-Error "Failed to get Enrollment GUID or SSL Client Reference for enrollment from registry... that's odd almost as if the Intune Certificate is gone" 
        $result = $false
    }
    if ($ssl -eq $null) {
        Write-Host "Your device doesnt seem to be enrolled into Intune, lets find out why!" -foregroundcolor red
    }
    else {
        Write-Host "Device seems to be Enrolled into Intune... proceeding" -foregroundcolor green
    }

    write-host "`n"
    write-host "Checking the Certificate Prefix.. to find out if it is configured as SYSTEM or USER" -foregroundcolor yellow

    try {
        $thumbprintPrefix = "MY;System;"
        $thumbprint = $ssl.Replace($thumbprintPrefix, "")         
        if ($ssl.StartsWith($thumbprintPrefix) -eq $true) { 
            write-host "The Intune Certificate Prefix is configured as $thumbprintprefix" -foregroundcolor green
            write-host "`n"
            write-host "Determing if the certificate is installed in the local machine certificate store" -foregroundcolor yellow
            if (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumbprint }) {
                Write-Host "Intune Device Certificate is installed in the Local Machine Certificate store" -foregroundcolor green
                write-host "`n"
                check-certdate
                write-host "`n"
                write-host "Checking if the Certificate is also mentioned in the IME log" -foregroundcolor yellow
                check-imelog
            }
            else {
                Write-Host "Intune device Certificate is missing in the Local Machine Certificate store" -foregroundcolor red    
                fix-certificate
                write-host "Running some tests to determine if the device has the SSLClientCertReference registry key configured!" -foregroundcolor yellow
                get-sslclientcertreference
            }
            write-host "`n"
            write-host "Determing if the certificate has a Private Key Attached" -foregroundcolor yellow
            get-privatekey
            check-dmpcert
        }
        else {
            write-host "Damn... the SSL prefix is not configured as SYSTEM but as $SSL" -foregroundcolor red
            $thumbprintPrefix = "MY;User;"
            $thumbprint = $ssl.Replace($thumbprintPrefix, "")
    
            write-host "`n"
            write-host "Determing if the certificate is also not in the System Certificate Store" -foregroundcolor yellow
    
            if (Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq $thumbprint }) {
                Write-Host "Intune Device Certificate is installed in the Local Machine Certificate store" -foregroundcolor green
                write-host "`n"
                check-certdate
                write-host "`n"
                write-host "Determing if the certificate has a Private Key Attached" -foregroundcolor yellow
                get-privatekey
                check-dmpcert
            }
            else {
                Write-Host "Intune device Certificate is installed in the wrong user store. I will fix it for you!" -foregroundcolor red
                fix-wrongstore
                write-host "Determing if the certificate is now been installed in the proper store" -foregroundcolor yellow
                check-intunecert
            }
        }
    }
    catch {
        Write-host "Failed to get Intune Enrollment Guid from registry, device doesnt seem enrolled? Who cares?Let's fix it" -foregroundcolor red
        fix-certificate
          
    }

    check-entdmid  
}


test-intunesyncerrors