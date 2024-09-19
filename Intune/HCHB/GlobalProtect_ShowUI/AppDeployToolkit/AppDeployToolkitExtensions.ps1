<#
.SYNOPSIS

PSAppDeployToolkit - Provides the ability to extend and customise the toolkit by adding your own functions that can be re-used.

.DESCRIPTION

This script is a template that allows you to extend the toolkit with your own custom functions.

This script is dot-sourced by the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.EXAMPLE

powershell.exe -File .\AppDeployToolkitHelp.ps1

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'3.9.3'
[string]$appDeployExtScriptDate = '02/05/2023'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

# <Your custom functions go here>

#region Function Get-DeploymentProcess
Function Get-DeploymentProcess {
       [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$true)]
            [string]$Name = ''
        )

        $script:ProcessNames = @("$Name")
        #in script .ps1 method uses all below code:
        #$script:ProcessNames = @("notepad,iexplore,excel")

        # Gets the Full descriptive name for each process to show in the Defer screen
        foreach ($p in $ProcessNames -split ',') {
            $script:DeferProcesses += @(Get-Process $p -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Description | Sort-Object | Get-Unique)
        }
        # DeferAppNames shows the apps list in the Defer screen
        $script:DeferAppNames = $DeferProcesses
        # The ActiveProcess variable is used for determining if the app is already open when the script begins. If not the welcome screen and defer screen won't show at all
        $script:ActiveProcesses = $ProcessNames -split ','
        $script:ActiveProcess = Get-Process $ActiveProcesses -ErrorAction SilentlyContinue | Sort-Object | Get-Unique
}
#endregion

#region Function Show-Defer
Function Show-DeferPrompt {
<#
.SYNOPSIS
	Show the Application Defer prompt window if a required app needs to be closed.
.DESCRIPTION
	Show the Application Defer prompt window if a required app needs to be closed.
.PARAMETER DeferLimit
	The number of times a user is allowed to defer the installation.
.PARAMETER DeferTimeIncrements
	The time units that a user is allowed to defer the installation.
.PARAMETER NetworkRequired
	For installations that require connection to the network to run. This is used in situations where a user defers and then reboots prior to the defer time.
.PARAMETER ShowBalloon
	Show balloon for the amount of time deferred.
.PARAMETER TopMostDefer
	Keep the defer prompt window as topmost.
.PARAMETER ShowMinimizeButton
	Show the MinimizeBox on the defer window.
.PARAMETER DeferCountdownTimer
	Show timer countdown for the deferral window. Once countdown is reached, open apps will auto close.
.PARAMETER DeferTimeOptions
	'ShowBoth', 'IncrementalOnly' or 'SelectTimeOnly' are the options. Chooses which defer time options are available when the form is opened.
.PARAMETER DeferDefaultTimeOption
	'Incremental' or 'SelectTime' are the options. Chooses which radio button as default when the form is opened.
.EXAMPLE
	Show-DeferPrompt -DeferLimit 3 -ShowMinimizeButton $true -NetworkRequired 'google.com' -DeferTimeIncrements '30m,1h,2h,4h,2d'
.EXAMPLE
    Show-DeferPrompt -DeferLimit 5 -DeferTimeOptions SelectTimeOnly -DeferTimeIncrements '15m,30m,1h,4h,8h' -DeferCountdownTimer '300' -DeferDefaultTimeOption Incremental[default]/SelectTime -NetworkRequired 'google.com' -ShowBalloon $True[default]/$False -TopMostDefer $True[default]/$False -ShowMinimizeButton $True/$False[default]  (Parameters are not required)
#>
       [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$false)]
            [string]$DeferLimit = '2',
            [Parameter(Mandatory=$false)]
            [string[]]$DeferTimeIncrements,
            [Parameter(Mandatory=$false)]
	        [string]$NetworkRequired,
            [Parameter(Mandatory=$false)]
	        [boolean]$ShowBalloon = $true,
            [Parameter(Mandatory=$false)]
	        [boolean]$TopMostDefer=$true,
            [Parameter(Mandatory=$false)]
	        [boolean]$ShowMinimizeButton = $false,
            [Parameter(Mandatory=$false)]
            [int]$DeferCountdownTimer,
            [Parameter(Mandatory=$false)]
            [ValidateSet('Incremental', 'SelectTime')]
            [String]$DeferDefaultTimeOption = 'Incremental',
            [Parameter(Mandatory=$false)]
            [ValidateSet('IncrementalOnly', 'SelectTimeOnly', 'ShowBoth')]
            [String]$DeferTimeOptions = 'ShowBoth'
        )
        ##<===================================================================================================================>##
        ######<In most, if not all cases you will not need to modify anything between these lines =======================>########
        ##<===================================================================================================================>##
        $script:ShowDeferTime = $false

        ## Test connection to domain if required
        If($NetworkRequired) {
            If(-not(Test-Connection -ComputerName "$NetworkRequired" -Count 1)) {

            $timeout = new-timespan -Minutes 115
            $sw = [diagnostics.stopwatch]::StartNew()

            While ($sw.elapsed -lt $timeout) {

                If (Test-Connection -ComputerName "$NetworkRequired" -Count 1) {
                    Write-Host "Found domain connection to $NetworkRequired. Start the install!"
                    Write-Log "Found domain connection to $NetworkRequired. Start the install!"
                    $NetCheck = $null
                    Return
                    }

                Write-Host "$NetworkRequired not found... Retrying."
                Write-Log "$NetworkRequired not found... Retrying."

                    if ($appVendor) { $AppTaskName = "$appVendor - $appName" }
                    else { $AppTaskName = "$appName" }
                    $RegPath = "HKLM:\SOFTWARE\Deferral\AppDefer"
                    $RegPathRunOnce = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
                    $name = "DeferCount-$appName"
                    $DeferAppNames = foreach($App in $DeferAppNames) { "$app`n" }

                    # Delete the scheduled task & runonce key if it already exists
                    Remove-ItemProperty -Path $RegPathRunOnce -Name $AppTaskName -Force -ErrorAction SilentlyContinue
                    Remove-ItemProperty -Path $RegPath -Name $Name -Force -ErrorAction SilentlyContinue

                    Write-Host "==============Removing Scheduled Task: $AppTaskName"
                    Write-Log "==============Removing Scheduled Task: $AppTaskName"

                    If(Get-ScheduledTask -TaskName $AppTaskName -ErrorAction SilentlyContinue ) {
                            Write-Host "Unregister Scheduled Task: $AppTaskName"
                            Write-Log "Unregister Scheduled Task: $AppTaskName"
                            Unregister-ScheduledTask -TaskName $AppTaskName -Confirm:$false -ErrorAction SilentlyContinue
                    }

                $NetCheck = $true
                Show-DeferInstallationPrompt -Message "You must be connected to the domain in order to continue the installation.`n`nConnect to VPN or an office network and click 'OK' to continue.`n`n`n" -buttonrighttext "OK" -PersistPrompt
                Start-Sleep -Seconds 2

            }
                Write-Host "Timed out"
                Exit-Script -ExitCode 1618 #Installation failed due to timeout
            }

            Else { Write-Host "Found domain connection to $NetworkRequired"; Write-Log "Found domain connection to $NetworkRequired" }

        }
        Else { Write-Host "Network connection not required."; Write-Log "Network connection not required." }
        ## End domain connection test


        if ($appVendor) { $AppTaskName = "$appVendor - $appName" }
        else { $AppTaskName = "$appName" }
        $RegPath = "HKLM:\SOFTWARE\Deferral\AppDefer"
        $RegPathRunOnce = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        $name = "DeferCount-$appName"
        $DeferAppNames = foreach($App in $DeferAppNames) { "$app`n" }

        Write-Host "$appVendor`n$appName`n$AppTaskName" -ForegroundColor Cyan

        # Delete the scheduled task & runonce key if it already exists
        If(Get-ScheduledTask -TaskName $AppTaskName -ErrorAction SilentlyContinue) {
             Write-Host "Removing the previous scheduled task." -ForegroundColor Cyan
             Unregister-ScheduledTask -TaskName $AppTaskName -Confirm:$false #-ErrorAction SilentlyContinue
        }

        $localvalue = Get-ItemProperty -Path $RegPath -Name $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $name
        if($localvalue -ne 0) {

            if($localvalue -eq $null) {$localvalue = $DeferLimit}

        If ($activeProcess -ne $null) {
        $ShowDeferTime = $True  #<Do show the defer time dropdown list>
        $ShowListBoxApp = $True  #<Do show the apps listbox>
        $ShowBoldButtonRight = $True #<Do show the buttonright in bold text>
        #$userResponse = Show-InstallationPrompt -Message "The following application is about to be installed:`n$appVendor $appNameDefer`n`n`nYou will be required to close out of the following applications for the installation to begin:`n`n`n`n`n`nNOTE:  You can choose to defer the installation until the deferral expires. Choosing 'defer' will re-run the installation at the selected time or at the next reboot/logon.`n`nRemaining Deferrals:  $localvalue`n`n`n`n" -ButtonRightText "Install Now" -ButtonLeftText "Defer" -PersistPrompt
        $userResponse = Show-DeferInstallationPrompt -Message "You will be required to close out of the following applications for the installation to begin:`n`n`n`n`n`nNOTE:  You can choose to defer the installation until the deferral expires. Choosing 'defer' will re-run the installation at the selected time or at the next reboot/logon.`n`n`n`n`n`n`n`n" -ButtonRightText "Install Now" -ButtonLeftText "Defer"
        $ShowDeferTime = $False  #<Don't show the defer time dropdown list>
        $ShowListBoxApp = $False   #<Don't show the apps listbox>
        $ShowBoldButtonRight = $False  #<Don't show the buttonright in bold text>
        $DeferCountdownTimer = $null

         If($userResponse -eq 'Defer') {
            Write-Host '---------User Selected to Defer the Installation---------' -ForegroundColor Cyan
            Write-Log "---------User Selected to Defer the Installation---------"

            ## Grabbed from function 'Show-InstallationPrompt', Combobox Dropdown List in the 'Main' toolkit file
            if($RadioButtonSelect.Checked) {
                #$DeferExactTime = $selectedTime
                $currentdate2 = Get-Date -Format "yyyy/MM/dd"
                $currentdate3 = Get-Date -Format "MM/dd/yyyy"
                $DeferExactTime = $selectedTime
                $Run = "$currentdate3 $DeferExactTime"
            }
            else {
                $DeferTime = $listBox.SelectedItem
                Write-Host "Selected defer time item: $DeferTime" -ForegroundColor Red
                Write-Log "Selected defer time item: $DeferTime"
                if($DeferTime -like '*minutes') { $HrMin = 'minutes'; $DeferTime = $DeferTime -replace ' minutes','' }
                elseif($DeferTime -like '*hours') { $HrMin = 'hours'; $DeferTime = $DeferTime -replace ' hours','' }
                elseif($DeferTime -like '*hour') { $HrMin = 'hour'; $DeferTime = $DeferTime -replace ' hour','' }
                elseif($DeferTime -like '*days*') { $HrMin = 'days'; $DeferTime = $DeferTime -replace ' days','' }
                #elseif($DeferTime -like '*day') { $HrMin = 'day'; $DeferTime = $DeferTime -replace ' day','' }
                Write-Host "Selected defer time is $DeferTime $HrMin" -ForegroundColor Red
                Write-Log "User selected to defer for $DeferTime $HrMin"
            }

            if($ShowBalloon -eq $true) {
                if($RadioButtonSelect.Checked) {
                    $timeCheck = $12selectedtime.StartsWith('0')
                    if($timeCheck -eq $true) {
                        Write-Host "=== time leads with a zero ==="
                        $fTime = $12selectedtime.Substring(1)
                    }
                    else { $fTime = $12selectedtime }
                    Write-Host "Selected time: $12selectedtime" -ForegroundColor Green
                    Show-BalloonTip -BalloonTipText "Installation deferred until $fTime"
                }
                else { Show-BalloonTip -BalloonTipText "Installation deferred for $DeferTime $HrMin" }
            }

                # Add new registry key and value for defer count
                $RegRoot = "HKLM:\SOFTWARE\Deferral"
                $RegPath = "HKLM:\SOFTWARE\Deferral\AppDefer"
                $name = "DeferCount-$appName"
                $newvalue = $DeferLimit
                $type = "String"
                $localvalue = Get-ItemProperty -Path $RegPath -Name $name -ErrorAction SilentlyContinue | Select -ExpandProperty $name

                # If the deferral reg key exists and it's not equal to '0', decrement the value by 1
                if(($localvalue -ne $null) -and ($localvalue -ne 0)) {
                    Write-Host 'found value'
                    $localvalue = $localvalue -1
                    Set-ItemProperty -Path $RegPath -Name $name -Value $localvalue
                }

                # If the If the deferral reg key is equal to '0', start the standard installation script section
                elseif($localvalue -eq 0) {}

                # If the deferral reg key doesn't exist, create it with the default value and decrement by 1
                else {
                    New-Item -Path $RegRoot -ErrorAction SilentlyContinue
                    New-Item -Path $RegPath -ErrorAction SilentlyContinue
                    Set-ItemProperty -Path $RegPath -Name $name -Value $newvalue
                    $localvalue = (Get-ItemProperty -Path $RegPath -Name $name).$name
                    $localvalue = $localvalue -1
                    Set-ItemProperty -Path $RegPath -Name $name -Value $localvalue
                }

            ## Scheduled task creation
                # Set the task name
                if(($appVendor) -and ($appName)) { $AppTaskName = "$appVendor - $appName" }
                else { $AppTaskName = "$appName" }

                $TaskDescription = 'Starts the PowerShell ADTK executable.'

                # Set the deferral time for minutes or hours
                $Now = Get-Date
                if($RadioButtonSelect.Checked) {
                    Write-Host "Selected Exact: $Run" -ForegroundColor Yellow
                    Write-Host "Rerun selected exact at: $Run" -ForegroundColor Cyan
                    Write-Log "Rerun selected exact at: $Run"
                    $Expire = $Now.AddDays('1').AddHours('1').ToString('s')
                    Write-Host "$Expire" -ForegroundColor Yellow
                }
                else {
                    # Set the deferral time for minutes or hours
                    if($HrMin -eq 'minutes') {
                        $Run = $Now.AddMinutes($DeferTime)
                    }
                    elseif(($HrMin -eq 'hours') -or ($HrMin -eq 'hour')) {
                        $Run = $Now.AddHours($DeferTime)
                    }
                    elseif($HrMin -eq 'days') {
                        $Run = $Now.AddDays($DeferTime)
                    }

                    Write-Host "Setting to: $HrMin" -ForegroundColor Cyan
                    Write-Host "Rerun at: $Run" -ForegroundColor Cyan
                    Write-Log "Rerun at: $Run"
                    # Create the scheduled task expiration
                    #$Expire = $Run.AddSeconds(1).ToString('s')
                    #$Expire = $Run.AddHours(5).ToString('s')
                    $Expire = $Run.AddDays(1).ToString('s')
                    Write-Host "$Expire" -ForegroundColor Yellow
                }


                # Set up action to run
                $TaskPathRoot = $PSScriptRoot -replace ('\\AppDeployToolkit','')
                $Action = New-ScheduledTaskAction -Execute "$TaskPathRoot\Deploy-Application.exe"

                # Setup trigger(s)
                #$Triggers = @()
                #$Triggers += New-ScheduledTaskTrigger -At $Run -Once
                #$Triggers += New-ScheduledTaskTrigger -AtLogOn
                $Triggers = @(
                    $(New-ScheduledTaskTrigger -At $Run -Once),
                    $(New-ScheduledTaskTrigger -AtLogOn)
                )

                # Setup initial task settings - NOTE: Win8 is used for Windows 10
                $Settings = New-ScheduledTaskSettingsSet
                $Settings.DeleteExpiredTaskAfter = "PT0S" #Immediately
                $Settings.ExecutionTimeLimit = 'PT2H' #2 hours
                $Settings.Priority = 5
                $Settings.StartWhenAvailable = $true
                $Settings.Compatibility = 'Win8'

                # Setup the Principal and Runlevel
                $Principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -RunLevel Highest

                # Setup the scheduled task
                $Task = New-ScheduledTask -Action $Action -Trigger $Triggers -Settings $Settings -Description "$TaskDescription" -Principal $Principal

                # Set additional desired tweaks
                $Task.Triggers[0].EndBoundary = $Expire
                $Task.Author = 'PowerShell ADT'
                $Task.Settings.RunOnlyIfNetworkAvailable = $true
                $Task.Settings.DisallowStartIfOnBatteries = $false
                $Task.Principal

                # Create the scheduled task and RunOnce key
                Register-ScheduledTask -TaskName "$AppTaskName" -TaskPath "\" -InputObject $Task
                Set-ItemProperty -Path $RegPathRunOnce -Name $AppTaskName -Value "$TaskPathRoot\Deploy-Application.exe"

            # Exit the script
            Clear-Variable listBox -Force -Scope Global -Confirm:$false -ErrorAction SilentlyContinue
            Clear-Variable ActiveProcess -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue
            Clear-Variable DeferProcesses -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue
            #Clear-Variable DeferCountdownTimer -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue
            Write-Host "Exiting with code 60012"
            exit 60012
         }
        }
        }

        # Remove the deferral limit and RunOnce registry keys
        if ($appVendor) { $AppTaskName = "$appVendor - $appName" }
        else { $AppTaskName = "$appName" }
        Remove-ItemProperty -Path $RegPath -Name $name -Force -ErrorAction SilentlyContinue
        Clear-Variable DeferProcesses -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue


        ##<===================================================================================================================>##

}
#endregion

#region Function Show-InstallationPrompt
Function Show-DeferInstallationPrompt {
    <#
.SYNOPSIS
Displays a custom installation prompt with the toolkit branding and optional buttons.

.DESCRIPTION
Any combination of Left, Middle or Right buttons can be displayed. The return value of the button clicked by the user is the button text specified.

.PARAMETER Title
Title of the prompt. Default: the application installation name.

.PARAMETER Message
Message text to be included in the prompt

.PARAMETER MessageAlignment
Alignment of the message text. Options: Left, Center, Right. Default: Center.

.PARAMETER ButtonLeftText
Show a button on the left of the prompt with the specified text

.PARAMETER ButtonRightText
Show a button on the right of the prompt with the specified text

.PARAMETER ButtonMiddleText
Show a button in the middle of the prompt with the specified text

.PARAMETER Icon
Show a system icon in the prompt. Options: Application, Asterisk, Error, Exclamation, Hand, Information, None, Question, Shield, Warning, WinLogo. Default: None

.PARAMETER NoWait
Specifies whether to show the prompt asynchronously (i.e. allow the script to continue without waiting for a response). Default: $false.

.PARAMETER PersistPrompt
Specify whether to make the prompt persist in the center of the screen every couple of seconds, specified in the AppDeployToolkitConfig.xml. The user will have no option but to respond to the prompt - resistance is futile!

.PARAMETER MinimizeWindows
Specifies whether to minimize other windows when displaying prompt. Default: $false.

.PARAMETER Timeout
Specifies the time period in seconds after which the prompt should timeout. Default: UI timeout value set in the config XML file.

.PARAMETER ExitOnTimeout
Specifies whether to exit the script if the UI times out. Default: $true.

.PARAMETER TopMost
Specifies whether the progress window should be topmost. Default: $true.

.INPUTS
None
You cannot pipe objects to this function.

.OUTPUTS
None
This function does not generate any output.

.EXAMPLE
Show-InstallationPrompt -Message 'Do you want to proceed with the installation?' -ButtonRightText 'Yes' -ButtonLeftText 'No'

.EXAMPLE
Show-InstallationPrompt -Title 'Funny Prompt' -Message 'How are you feeling today?' -ButtonRightText 'Good' -ButtonLeftText 'Bad' -ButtonMiddleText 'Indifferent'

.EXAMPLE
Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install, or remove it completely for unattended installations.' -Icon Information -NoWait

.NOTES
.LINK
https://psappdeploytoolkit.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [String]$Title = $installTitle,
        [Parameter(Mandatory = $false)]
        [String]$Message = '',
        [Parameter(Mandatory = $false)]
        [ValidateSet('Left', 'Center', 'Right')]
        [String]$MessageAlignment = 'Center',
        [Parameter(Mandatory = $false)]
        [String]$ButtonRightText = '',
        [Parameter(Mandatory = $false)]
        [String]$ButtonLeftText = '',
        [Parameter(Mandatory = $false)]
        [String]$ButtonMiddleText = '',
        [Parameter(Mandatory = $false)]
        [ValidateSet('Application', 'Asterisk', 'Error', 'Exclamation', 'Hand', 'Information', 'None', 'Question', 'Shield', 'Warning', 'WinLogo')]
        [String]$Icon = 'None',
        [Parameter(Mandatory = $false)]
        [Switch]$NoWait = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$PersistPrompt = $false,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [Boolean]$MinimizeWindows = $false,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [Int32]$Timeout = $configInstallationUITimeout,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [Boolean]$ExitOnTimeout = $true,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [Boolean]$TopMost = $true
    )

    Begin {
        ## Get the name of this function and write header
        [String]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        ## Bypass if in non-interactive mode
        If ($deployModeSilent) {
            Write-Log -Message "Bypassing Show-InstallationPrompt [Mode: $deployMode]. Message:$Message" -Source ${CmdletName}
            Return
        }

        ## Get parameters for calling function asynchronously
        [Hashtable]$installPromptParameters = $PSBoundParameters

        ## Check if the countdown was specified
        If ($timeout -gt $configInstallationUITimeout) {
            [String]$CountdownTimeoutErr = 'The installation UI dialog timeout cannot be longer than the timeout specified in the XML configuration file.'
            Write-Log -Message $CountdownTimeoutErr -Severity 3 -Source ${CmdletName}
            Throw $CountdownTimeoutErr
        }

        ## If the NoWait parameter is specified, launch a new PowerShell session to show the prompt asynchronously
        If ($NoWait) {
            # Remove the NoWait parameter so that the script is run synchronously in the new PowerShell session. This also prevents the function to loop indefinitely.
            $installPromptParameters.Remove('NoWait')
            # Format the parameters as a string
            [String]$installPromptParameters = ($installPromptParameters.GetEnumerator() | ForEach-Object { & $ResolveParameters $_ }) -join ' '


            Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -NoProfile -NoLogo -WindowStyle Hidden -Command & {& `'$scriptPath`' -ReferredInstallTitle `'$Title`' -ReferredInstallName `'$installName`' -ReferredLogName `'$logName`' -ShowInstallationPrompt $installPromptParameters -AsyncToolkitLaunch}" -WindowStyle 'Hidden' -ErrorAction 'SilentlyContinue'
            Return
        }

        [Windows.Forms.Application]::EnableVisualStyles()
        $formInstallationPrompt = New-Object -TypeName 'System.Windows.Forms.Form'
        $pictureBanner = New-Object -TypeName 'System.Windows.Forms.PictureBox'
        If ($Icon -ne 'None') {
            $pictureIcon = New-Object -TypeName 'System.Windows.Forms.PictureBox'
        }
        $labelText = New-Object -TypeName 'System.Windows.Forms.Label'
<#MOD#> If($ShowDeferTime -eq $True) {
<#MOD#>     $labelWelcomeMessage = New-Object -TypeName 'System.Windows.Forms.Label'  <#MOD add line#>
<#MOD#>     $labelAppName = New-Object -TypeName 'System.Windows.Forms.Label' <#MOD add line#>
<#MOD#> }
        $buttonRight = New-Object -TypeName 'System.Windows.Forms.Button'
        $buttonMiddle = New-Object -TypeName 'System.Windows.Forms.Button'
        $buttonLeft = New-Object -TypeName 'System.Windows.Forms.Button'
        $buttonAbort = New-Object -TypeName 'System.Windows.Forms.Button'
        $flowLayoutPanel = New-Object -TypeName 'System.Windows.Forms.FlowLayoutPanel'
        $panelButtons = New-Object -TypeName 'System.Windows.Forms.Panel'

        [ScriptBlock]$Install_Prompt_Form_Cleanup_FormClosed = {
            ## Remove all event handlers from the controls
            Try {
                $labelText.remove_Click($handler_labelText_Click)
<#MOD#>         If($ShowDeferTime -eq $True) {
<#MOD#>             $labelWelcomeMessage.remove_Click($handler_labelWelcomeMessage_Click) <#MOD add line#>
<#MOD#>             $labelAppName.remove_Click($handler_labelAppName_Click) <#MOD add line#>
<#MOD#>         }
                $buttonLeft.remove_Click($buttonLeft_OnClick)
                $buttonRight.remove_Click($buttonRight_OnClick)
                $buttonMiddle.remove_Click($buttonMiddle_OnClick)
                $buttonAbort.remove_Click($buttonAbort_OnClick)
                $installPromptTimer.remove_Tick($installPromptTimer_Tick)
                $installPromptTimer.Dispose()
                $installPromptTimer = $null
                $installPromptTimerPersist.remove_Tick($installPromptTimerPersist_Tick)
                $installPromptTimerPersist.Dispose()
                $installPromptTimerPersist = $null
                $formInstallationPrompt.remove_Load($Install_Prompt_Form_StateCorrection_Load)
                $formInstallationPrompt.remove_FormClosed($Install_Prompt_Form_Cleanup_FormClosed)
            }
            Catch {
            }
        }

        [ScriptBlock]$Install_Prompt_Form_StateCorrection_Load = {
            # Disable the X button
            Try {
                $windowHandle = $formInstallationPrompt.Handle
                If ($windowHandle -and ($windowHandle -ne [IntPtr]::Zero)) {
                    $menuHandle = [PSADT.UiAutomation]::GetSystemMenu($windowHandle, $false)
                    If ($menuHandle -and ($menuHandle -ne [IntPtr]::Zero)) {
                        [PSADT.UiAutomation]::EnableMenuItem($menuHandle, 0xF060, 0x00000001)
                        [PSADT.UiAutomation]::DestroyMenu($menuHandle)
                    }
                }
            }
            Catch {
                # Not a terminating error if we can't disable the button. Just disable the Control Box instead
                Write-Log 'Failed to disable the Close button. Disabling the Control Box instead.' -Severity 2 -Source ${CmdletName}
                $formInstallationPrompt.ControlBox = $false
            }
            $formInstallationPrompt.WindowState = 'Normal'
            $formInstallationPrompt.AutoSize = $true
            $formInstallationPrompt.AutoScaleMode = 'Font'
            $formInstallationPrompt.AutoScaleDimensions = New-Object System.Drawing.SizeF(6, 13) #Set as if using 96 DPI
            $formInstallationPrompt.TopMost = $TopMost
<#MOD#>     If(($TopMostDefer -ne $false) -or ($TopMostDefer -eq $null)) {
<#MOD#>     $formInstallationPrompt.TopMost = $true }
<#MOD#>     else { $formInstallationPrompt.TopMost = $false }
            $formInstallationPrompt.BringToFront()
            # Get the start position of the form so we can return the form to this position if PersistPrompt is enabled
            Set-Variable -Name 'formInstallationPromptStartPosition' -Value $formInstallationPrompt.Location -Scope 'Script'
        }

        ## Form

        ##----------------------------------------------
        ## Create padding object
        $paddingNone = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (0, 0, 0, 0)

        ## Default control size
        $DefaultControlSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (450, 0)

        ## Generic Button properties
        #$buttonSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (130, 24)
<#MOD#> $buttonSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (130, 28)
<#MOD#> $buttonSizeDropDown = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (128, 28)

        ## Picture Banner
        $pictureBanner.DataBindings.DefaultDataSourceUpdateMode = 0
        $pictureBanner.ImageLocation = $appDeployLogoBanner
        $pictureBanner.Size = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (450, $appDeployLogoBannerHeight)
        $pictureBanner.MinimumSize = $DefaultControlSize
        $pictureBanner.SizeMode = 'CenterImage'
        $pictureBanner.Margin = $paddingNone
        $pictureBanner.TabStop = $false
        $pictureBanner.Location = New-Object -TypeName 'System.Drawing.Point' -ArgumentList (0, 0)

        ## Picture Icon
        If ($Icon -ne 'None') {
            $pictureIcon.DataBindings.DefaultDataSourceUpdateMode = 0
            $pictureIcon.Image = ([Drawing.SystemIcons]::$Icon).ToBitmap()
            $pictureIcon.Name = 'pictureIcon'
            $pictureIcon.MinimumSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (64, 32)
            $pictureIcon.Size = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (64, 32)
            $pictureIcon.Padding = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (24, 0, 8, 0)
            $pictureIcon.SizeMode = 'CenterImage'
            $pictureIcon.TabStop = $false
            $pictureIcon.Anchor = 'None'
            $pictureIcon.Margin = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (0, 10, 0, 5)
        }

<#MOD#> #added this entire section#>
        $script:RadioButtonSelect = $null
        $script:RadioButtonIncrement = $null

<#MOD#> If($ShowDeferTime -eq $True) {
        ## Label Welcome Message
            $labelWelcomeMessage.DataBindings.DefaultDataSourceUpdateMode = 0
            $labelWelcomeMessage.Font = $defaultFont
            $labelWelcomeMessage.Name = 'labelWelcomeMessage'
            $labelWelcomeMessage.Size = $defaultControlSize
            $labelWelcomeMessage.MinimumSize = $defaultControlSize
            $labelWelcomeMessage.MaximumSize = $defaultControlSize
            $labelWelcomeMessage.Margin = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (0, 10, 0, 0)
            $labelWelcomeMessage.Padding = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (10, 0, 10, 0)
            $labelWelcomeMessage.TabStop = $false
            $labelWelcomeMessage.Text = $configDeferPromptWelcomeMessage
            $labelWelcomeMessage.TextAlign = 'MiddleCenter'
            $labelWelcomeMessage.Anchor = 'Top'
            $labelWelcomeMessage.AutoSize = $true
            $labelWelcomeMessage.add_Click($handler_labelWelcomeMessage_Click)
        }

<#MOD#> #added this entire section#>
<#MOD#> If($ShowDeferTime -eq $True) {
        ## Label App Name
            $labelAppName.DataBindings.DefaultDataSourceUpdateMode = 0
            $labelAppName.Font = "$($defaultFont.Name), $($defaultFont.Size + 2), style=Bold"
            $labelAppName.Name = 'labelAppName'
            $labelAppName.Size = $defaultControlSize
            $labelAppName.MinimumSize = $defaultControlSize
            $labelAppName.MaximumSize = $defaultControlSize
            $labelAppName.Margin = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (0, 5, 0, 5)
            $labelAppName.Padding = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (10, 0, 10, 0)
            $labelAppName.TabStop = $false
            $labelAppName.Text = $installTitle
            $labelAppName.TextAlign = 'MiddleCenter'
            $labelAppName.Anchor = 'Top'
            $labelAppName.AutoSize = $true
            $labelAppName.add_Click($handler_labelAppName_Click)

            $labelRemainingDeferrals = New-Object system.Windows.Forms.Label
            $labelRemainingDeferrals.AutoSize                  = $true
            $labelRemainingDeferrals.Width                     = 25
            $labelRemainingDeferrals.Height                    = 5
            $labelRemainingDeferrals.Location                  = New-Object System.Drawing.Point(160,437)
            $labelRemainingDeferrals.Font                      = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
            $labelRemainingDeferrals.SendToBack()
            #$labelRemainingDeferrals.BorderStyle = 'FixedSingle'
            #$labelRemainingDeferrals.TextAlign = 'MiddleCenter'
            $labelRemainingDeferrals.Text                      = "Remaining Deferrals:  $localvalue"
            $formInstallationPrompt.Controls.AddRange(@($labelRemainingDeferrals))
        }

        ## Label Text
        $labelText.DataBindings.DefaultDataSourceUpdateMode = 0
        $labelText.Font = $defaultFont
        #$labelText.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
        $labelText.Name = 'labelText'
        $System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (386, 0)
        $labelText.Size = $System_Drawing_Size
        If ($Icon -ne 'None') {
            $labelText.MinimumSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (386, $pictureIcon.Height)
        }
        Else {
            $labelText.MinimumSize = $System_Drawing_Size
        }
        $labelText.MaximumSize = $System_Drawing_Size
        $labelText.Margin = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (0, 10, 0, 5)
        $labelText.Padding = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (20, 0, 20, 0)
        $labelText.TabStop = $false
        $labelText.Text = $message
        $labelText.TextAlign = "Middle$($MessageAlignment)"
        $labelText.Anchor = 'None'
        $labelText.AutoSize = $true
        $labelText.add_Click($handler_labelText_Click)

        If ($Icon -ne 'None') {
            # Add margin for the icon based on labelText Height so its centered
            $pictureIcon.Height = $labelText.Height
        }

<#MOD#> ## Listbox Close Applications
<#<#>   if($ShowListBoxApp -eq $true) {
            $listBoxApp = New-Object System.Windows.Forms.ListBox
            #$listBoxApp.Location = New-Object System.Drawing.Point(127,162)
            $listBoxApp.Location = New-Object System.Drawing.Point(98,190)
            $listBoxApp.Size = New-Object System.Drawing.Size(260,21)
            $listBoxApp.FormattingEnabled = $true
            $listBoxApp.HorizontalScrollbar = $true
            $listBoxApp.BorderStyle = "Fixed3D"
            $listBoxApp.Sorted = $true
            $listBoxApp.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
            $listBoxApp.Height = 65
            #$listBoxApp.Width = 200
            $listBoxApp.Width = 250
            if($UseCustomNames) { foreach($Name in $CustomNames -split ',') {[void] $listBoxApp.Items.Add("$Name") } }
            else { foreach($app in $DeferAppNames) {[void] $listBoxApp.Items.Add("$App") } }
            $formInstallationPrompt.Controls.Add($listBoxApp)
        }

<#MOD#> ## Combobox Dropdown List
        #Show-DialogBox -Text "$DeferTimeOptions" -Buttons OK
        If($ShowDeferTime -eq $True) {
            if(($DeferTimeOptions -eq "ShowBoth") -or ($DeferTimeOptions -eq "IncrementalOnly")) {
                $script:listBox = New-Object System.Windows.Forms.ComboBox
                #$script:listBox.Location = New-Object System.Drawing.Point(16,310)
                $script:listBox.Location = '19,400'
                $script:listBox.Size = New-Object System.Drawing.Size(120,20)
                #$script:listBox.Size = $buttonSizeDropDown
                $script:listBox.Height = 62
                $script:listBox.SendToBack()
                $script:listBox.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
                $script:listBox.DropDownStyle = 'DropDownList'
                if($DeferTimeIncrements) {
                    $script:options = @("$DeferTimeIncrements")
                    foreach($option in $options -split ',') {
                        Write-Log $option
                        if($option.endswith("m")) { $timeunit = 'minutes'; $option = $option -replace 'm','' }
                        elseif($option.endswith("1h")) { $timeunit = 'hour'; $option = $option -replace 'h','' }
                        elseif($option.endswith("h")) { $timeunit = 'hours'; $option = $option -replace 'h','' }
                        elseif($option.endswith("d")) { $timeunit = 'days'; $option = $option -replace 'd','' }
                        [void] $script:listBox.Items.Add("$option $timeunit")
                    }
                }
                else {
                    #[void] $script:listBox.Items.Add('3 minutes')
                    [void] $script:listBox.Items.Add('30 minutes')
                    [void] $script:listBox.Items.Add('1 hour')
                    [void] $script:listBox.Items.Add('2 hours')
                    [void] $script:listBox.Items.Add('4 hours')
                    #[void] $script:listBox.Items.Add('24 hours')
                }
                $script:listBox.SelectedItem = $listBox.Items[0]
                $formInstallationPrompt.Controls.Add($script:listBox)
            }
<#MOD#> }
<#MOD#>
        If($ShowDeferTime -eq $True) {
            ## Create TimePicker
            if(($DeferTimeOptions -eq "ShowBoth") -or ($DeferTimeOptions -eq "SelectTimeOnly")) {
                $script:TimePicker = New-Object System.Windows.Forms.DateTimePicker
                $script:TimePicker.Location = "19, 399"
                $script:TimePicker.Width = "120"
                $script:TimePicker.Format = [windows.forms.datetimepickerFormat]::custom
                $script:TimePicker.CustomFormat = "hh:mm tt"
                $script:TimePicker.ShowUpDown = $TRUE
                $script:TimePicker.BringToFront()
                $script:TimePicker.Font = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
                $script:TimePicker.Visible = $false
                $formInstallationPrompt.Controls.Add($script:TimePicker)
            }

            ## Create group box
            $radiogroupBox = New-Object System.Windows.Forms.GroupBox
            if($DeferTimeOptions -eq "ShowBoth") {
                $radiogroupBox.Location = New-Object System.Drawing.Size(15,348)
                $radiogroupBox.size = New-Object System.Drawing.Size(128,81) #the size in px of the group box (length, height)
            }
            else {
                $radiogroupBox.Location = New-Object System.Drawing.Size(15,388)
                $radiogroupBox.size = New-Object System.Drawing.Size(128,41) #the size in px of the group box (length, height)
            }
            #$radiogroupBox.text = "Choose Deferral Time:"
            #$radiogroupBox.BackColor = "white"
            $radiogroupBox.Font = [System.Drawing.Font]::new("Segoe UI", 8, [System.Drawing.FontStyle]::Regular)
            $radiogroupBox.SendToBack()
            $formInstallationPrompt.Controls.Add($radiogroupBox) #activate the group box

            ## Create incremental radio button
            if(($DeferTimeOptions -eq "ShowBoth") -or ($DeferTimeOptions -eq "IncrementalOnly")) {
                $script:RadioButtonIncrement = New-Object Windows.Forms.radiobutton
                $RadioButtonIncrement.text = "Incremental"
                $RadioButtonIncrement.height = 15
                $RadioButtonIncrement.width = 87
                $RadioButtonIncrement.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
                #$RadioButtonIncrement.Location = "13, 375"
                if($DeferTimeOptions -eq "IncrementalOnly") {
                    $RadioButtonIncrement.Visible = $false
                }
                else {
                    $RadioButtonIncrement.Location = "5, 30"
                }
                    # create event handler for button
                    $eventIncrement = { $TimePicker.Visible = $false; $TimePicker.Refresh() }
                    # attach event handler
                    $RadioButtonIncrement.Add_Click($eventIncrement)
                $radiogroupBox.controls.add($RadioButtonIncrement)
            }

            ## Create select time radio button
            if(($DeferTimeOptions -eq "ShowBoth") -or ($DeferTimeOptions -eq "SelectTimeOnly")) {
            #if($DeferTimeOptions -eq "ShowBoth") {
                $script:RadioButtonSelect = New-Object Windows.Forms.radiobutton
                $RadioButtonSelect.text = "Select Time"
                $RadioButtonSelect.height = 15
                $RadioButtonSelect.width = 88
                $RadioButtonSelect.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
                #$RadioButtonSelect.Location = "13, 356"
                $RadioButtonSelect.Location = "5, 12"
                if($DeferTimeOptions -eq "SelectTimeOnly") {
                    $RadioButtonSelect.Visible = $false
                }
                    # create event handler for button
                    $eventSelect = { $TimePicker.Visible = $true; $TimePicker.BringToFront(); $TimePicker.Refresh() }
                    # attach event handler
                    $script:RadioButtonSelect.Add_Click($eventSelect)
                $radiogroupBox.controls.add($RadioButtonSelect)
            }

            # Set the default checked option
            if(($DeferDefaultTimeOption -eq 'SelectTime') -or ($DeferTimeOptions -eq "SelectTimeOnly")) { $RadioButtonSelect.checked = $true;$RadioButtonSelect.Focus();$TimePicker.Visible = $true;$TimePicker.BringToFront(); $TimePicker.Refresh() }
            else { $RadioButtonIncrement.Checked = $true; $RadioButtonIncrement.Focus() }

            $DeferEvent = {
                if($resetLeftButton) {}
                else {
                    if($RadioButtonSelect.Checked) {
                        #<Do stuff for the selected time options>
		                $script:selectedtime = $TimePicker.Value.ToString("HH:mm:ss")
                        $script:12selectedtime = $TimePicker.Value.ToString("hh:mm tt")
		                $currentdate = Get-Date -Format "MM/dd/yyyy"
		                $currentdatetime = Get-Date -Format "MM/dd/yyyy HH:mm:ss"
		                $script:selecteddatetime = "$currentdate $selectedtime"
		                Write-Log "The current date/time is: $currentdatetime"
		                Write-Log "The selected date/time is: $selecteddatetime"

		                    if ($currentdatetime -ge $selecteddatetime) {
			                    #<Display a warning that the time must be in the future>
                                Write-Log "Selected time is in the past. Retry."
                                Show-DialogBox -Text "You must select a time that meets the following requirements:`n`n   - Selected time must be today.`n   - Selected time must be in the future.`n`nPlease try again." -Title "Warning" -Buttons "Ok" -Icon "Information"
                            }
                            else {
                                Write-Host "Selected time is acceptable."
                                $buttonLeft.DialogResult = 'No'
                                $resetLeftButton = $true
                                Clear-Variable DeferCountdownTimer -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue
                                $buttonLeft.PerformClick()
                            }
                    }

                    else {
                        Write-Log "Selected time is not checked."
                        $buttonLeft.DialogResult = 'No'
                        $resetLeftButton = $true
                        $buttonLeft.PerformClick()
                    }
                }
            }

        }
<#MOD Above#>
<#MOD#>
        if($DeferCountdownTimer -gt 0) {
            $rbuttonEvent = {
                    Write-Log "Right event Closing the Defer form."
                    $rButtonClicked = $true
                    $timerUpdate.Stop()
                    $timerUpdate.Dispose()
                    $buttonRight.PerformClick()
            }
        }
<#MOD#>

<#MOD#> if(($DeferCountdownTimer -gt 0) -and ($ShowDeferTime -eq $True)) {
                $labelCountdownMessage = New-Object system.Windows.Forms.Label
                $labelCountdownMessage.AutoSize                  = $true
                $labelCountdownMessage.Width                     = 25
                $labelCountdownMessage.Height                    = 10
                $labelCountdownMessage.Location                  = New-Object System.Drawing.Point(48,325)
                $labelCountdownMessage.Font                      = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
                $labelCountdownMessage.TextAlign                 = "TopCenter"
                $labelCountdownMessage.BringToFront()
                $labelCountdownMessage.Text                    = "If no selection is chosen, applications will automatically close in:"
                $formInstallationPrompt.controls.add($labelCountdownMessage)

                $labelCountdownDefer = New-Object system.Windows.Forms.Label
                $labelCountdownDefer.AutoSize                  = $true
                $labelCountdownDefer.Width                     = 25
                $labelCountdownDefer.Height                    = 10
                $labelCountdownDefer.Location                  = New-Object System.Drawing.Point(178,348)
                $labelCountdownDefer.Font                      = [System.Drawing.Font]::new("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
                $labelCountdownDefer.BringToFront()
                $formInstallationPrompt.Controls.AddRange(@($labelCountdownDefer))

                # Create a timer.
                $totalTime = $DeferCountdownTimer
                $timerUpdate = New-Object -TypeName 'System.Windows.Forms.Timer'

                $script:startTimeDefer = (Get-Date).AddSeconds($TotalTime)
                $timerUpdate.Start()
                Write-Log "Running Timer for $DeferCountdownTimer."

                $timerUpdate_Tick={
                    #TODO: Place custom script here
                    $labelCountdownDefer.text = (Get-Date).ToString("HH:mm:ss")
                    [TimeSpan]$span = $startTimeDefer - (Get-Date)
	                $s = "{0:N0}" -f $span.TotalSeconds
	                $ts = [timespan]::fromseconds($s)
                    $labelCountdownDefer.Text = ("{0:hh\:mm\:ss}" -f $ts)
                    $labelCountdownDefer.Refresh()
                    #Write-Host $span.TotalSeconds

                    if ($span.TotalSeconds -le '0.8') {
                        Write-Log "Closing the Defer form."
                        #$script:ForceSilentWelcome = $true
                        $script:deployModeNonInteractive = $true
                        $timerUpdate.Stop()
                        $timerUpdate.Dispose()
		                $buttonRight.PerformClick()
	                }
                    else { $resetRightButton = $true }

                }

                $timerUpdate.Enabled = $True
                $timerUpdate.Interval = 100
                $timerUpdate.add_Tick($timerUpdate_Tick)
            }
<#MOD#>

		# Generic Y location for buttons
        if ($WindowSize -eq 'Biggest') { $buttonLocationY = 600 + $appDeployLogoBannerHeightDifference }
<#>#>   elseif ($WindowSize -eq 'Bigger')  { $buttonLocationY = 480 + $appDeployLogoBannerHeightDifference }
<#MOD#> else { $buttonLocationY = 360 + $appDeployLogoBannerHeightDifference }

        ## Button Left
        $buttonLeft.DataBindings.DefaultDataSourceUpdateMode = 0
        $buttonLeft.Name = 'buttonLeft'
        $buttonLeft.Font = $defaultFont
        $buttonLeft.Size = $buttonSize
        $buttonLeft.MinimumSize = $buttonSize
        $buttonLeft.MaximumSize = $buttonSize
        $buttonLeft.TabIndex = 0
        $buttonLeft.Text = $buttonLeftText
<#MOD#> if($resetleftbutton) {$buttonLeft.DialogResult = 'No'}
        else {$buttonLeft.DialogResult = 'None'}
        $buttonLeft.AutoSize = $false
        $buttonLeft.Margin = $paddingNone
        $buttonLeft.Padding = $paddingNone
        $buttonLeft.BringToFront()
        $buttonLeft.UseVisualStyleBackColor = $true
        #$buttonLeft.Location = '14,4'
<#MOD#> $buttonLeft.Location = '14,0'
<#MOD#> If($ShowDeferTime -eq $True) {
            if($resetleftbutton) {
                Write-Host "in button left section w/reset"
                Clear-Variable DeferCountdownTimer -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue
                $buttonLeft.add_Click($buttonLeft_OnClick)
            }
            else {
                Write-Host "in button left section without/reset"
                Clear-Variable DeferCountdownTimer -Force -Scope Script -Confirm:$false -ErrorAction SilentlyContinue
                $buttonLeft.add_Click($DeferEvent)
            }
        }
        else { $buttonLeft.add_Click($buttonLeft_OnClick) }

        ## Button Middle
        $buttonMiddle.DataBindings.DefaultDataSourceUpdateMode = 0
        $buttonMiddle.Name = 'buttonMiddle'
        $buttonMiddle.Font = $defaultFont
        $buttonMiddle.Size = $buttonSize
        $buttonMiddle.MinimumSize = $buttonSize
        $buttonMiddle.MaximumSize = $buttonSize
        $buttonMiddle.TabIndex = 1
        $buttonMiddle.Text = $buttonMiddleText
        $buttonMiddle.DialogResult = 'Ignore'
        $buttonMiddle.AutoSize = $true
        $buttonMiddle.Margin = $paddingNone
        $buttonMiddle.Padding = $paddingNone
        $buttonMiddle.UseVisualStyleBackColor = $true
<#MOD#> $buttonMiddle.Location = '160,0'
        $buttonMiddle.add_Click($buttonMiddle_OnClick)

        ## Button Right
        $buttonRight.DataBindings.DefaultDataSourceUpdateMode = 0
        $buttonRight.Name = 'buttonRight'
        $buttonRight.Font = $defaultFont
        $buttonRight.Size = $buttonSize
        $buttonRight.MinimumSize = $buttonSize
        $buttonRight.MaximumSize = $buttonSize
        $buttonRight.TabIndex = 2
        $buttonRight.Text = $ButtonRightText
        $buttonRight.DialogResult = 'Yes'
<#MOD#> $buttonRight.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $buttonRight.AutoSize = $true
        $buttonRight.Margin = $paddingNone
        $buttonRight.Padding = $paddingNone
        $buttonRight.UseVisualStyleBackColor = $true
<#MOD#> $buttonRight.Location = '306,0'
        $buttonRight.add_Click($buttonRight_OnClick)

<#MOD#>
# Add this entire button to fix an issue with the clicking events from the countdown timer.
# This was a workaround because I could not figure it out...
        if(($DeferCountdownTimer -gt 0) -and ($ShowDeferTime -eq $True)) {
            $rButton = New-Object System.Windows.Forms.Button
            #$rButton.Location = New-Object System.Drawing.Size(35,35)
            #$rButton.Size = New-Object System.Drawing.Size(120,23)
            $rButton.Font = $defaultFont
            $rButton.Size = $buttonSize
            $rButton.MinimumSize = $buttonSize
            $rButton.DialogResult = 'Yes'
            $rButton.Font = [System.Drawing.Font]::new("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
            $rButton.MaximumSize = $buttonSize
            $rButton.AutoSize = $true
            $rButton.Margin = $paddingNone
            $rButton.Padding = $paddingNone
            $rButton.UseVisualStyleBackColor = $true
            $rButton.Location = '306,432'
            $rButton.Text = "Install Now"
            $rButton.Add_Click($rbuttonEvent)
            $formInstallationPrompt.Controls.Add($rButton)
        }
<#MOD#>

        ## Button Abort (Hidden)
        $buttonAbort.DataBindings.DefaultDataSourceUpdateMode = 0
        $buttonAbort.Name = 'buttonAbort'
        $buttonAbort.Font = $defaultFont
        $buttonAbort.Size = '0,0'
        $buttonAbort.MinimumSize = '0,0'
        $buttonAbort.MaximumSize = '0,0'
        $buttonAbort.BackColor = [System.Drawing.Color]::Transparent
        $buttonAbort.ForeColor = [System.Drawing.Color]::Transparent
        $buttonAbort.FlatAppearance.BorderSize = 0
        $buttonAbort.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
        $buttonAbort.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent
        $buttonAbort.FlatStyle = [System.Windows.Forms.FlatStyle]::System
        $buttonAbort.DialogResult = 'Abort'
        $buttonAbort.TabStop = $false
        $buttonAbort.Visible = $true # Has to be set visible so we can call Click on it
        $buttonAbort.Margin = $paddingNone
        $buttonAbort.Padding = $paddingNone
        $buttonAbort.UseVisualStyleBackColor = $true
        $buttonAbort.add_Click($buttonAbort_OnClick)

        ## FlowLayoutPanel
        $flowLayoutPanel.MinimumSize = $DefaultControlSize
        $flowLayoutPanel.MaximumSize = $DefaultControlSize
        $flowLayoutPanel.Size = $DefaultControlSize
        $flowLayoutPanel.AutoSize = $true
        $flowLayoutPanel.AutoSizeMode = 'GrowAndShrink'
        $flowLayoutPanel.Anchor = 'Top,Left'
        $flowLayoutPanel.FlowDirection = 'LeftToRight'
        $flowLayoutPanel.WrapContents = $true
        $flowLayoutPanel.Margin = $paddingNone
        $flowLayoutPanel.Padding = $paddingNone
        ## Make sure label text is positioned correctly
        If ($Icon -ne 'None') {
            $labelText.Padding = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (0, 0, 10, 0)
            $pictureIcon.Location = New-Object -TypeName 'System.Drawing.Point' -ArgumentList (0, 0)
            $labelText.Location = New-Object -TypeName 'System.Drawing.Point' -ArgumentList (64, 0)
        }
        Else {
            $labelText.Padding = New-Object -TypeName 'System.Windows.Forms.Padding' -ArgumentList (10, 0, 10, 0)
            $labelText.MinimumSize = $DefaultControlSize
            $labelText.MaximumSize = $DefaultControlSize
            $labelText.Size = $DefaultControlSize
            $labelText.Location = New-Object -TypeName 'System.Drawing.Point' -ArgumentList (0, 0)
        }
        If ($Icon -ne 'None') {
            $flowLayoutPanel.Controls.Add($pictureIcon)
        }
<#MOD#> If($ShowDeferTime -eq $True) {
<#MOD#>     $flowLayoutPanel.Controls.Add($labelWelcomeMessage)  <#MOD add line#>
<#MOD#>     $flowLayoutPanel.Controls.Add($labelAppName)  <#MOD add line#>
<#MOD#> }
        $flowLayoutPanel.Controls.Add($labelText)

        $flowLayoutPanel.Location = New-Object -TypeName 'System.Drawing.Point' -ArgumentList (0, $appDeployLogoBannerHeight)

        ## ButtonsPanel
        $panelButtons.MinimumSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (450, 39)
        $panelButtons.Size = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (450, 39)
        If ($Icon -ne 'None') {
            $panelButtons.Location = New-Object -TypeName 'System.Drawing.Point' -ArgumentList (64, 0)
        }
        Else {
            $panelButtons.Padding = $paddingNone
        }
        $panelButtons.Margin = $paddingNone
        $panelButtons.MaximumSize = New-Object -TypeName 'System.Drawing.Size' -ArgumentList (450, 39)
        $panelButtons.AutoSize = $true
        If ($buttonLeftText) {
            $panelButtons.Controls.Add($buttonLeft)
        }
        If ($buttonMiddleText) {
            $panelButtons.Controls.Add($buttonMiddle)
        }
        If ($buttonRightText) {
            $panelButtons.Controls.Add($buttonRight)
        }
        ## Add the ButtonsPanel to the flowLayoutPanel if any buttons are present
        If ($buttonLeftText -or $buttonMiddleText -or $buttonRightText) {
            $flowLayoutPanel.Controls.Add($panelButtons)
        }


        ## Form Installation Prompt
        $formInstallationPrompt.MinimumSize = $DefaultControlSize
        $formInstallationPrompt.Size = $DefaultControlSize
        $formInstallationPrompt.Padding = $paddingNone
        $formInstallationPrompt.Margin = $paddingNone
        $formInstallationPrompt.DataBindings.DefaultDataSourceUpdateMode = 0
<#MOD#> if($ShowMinimizeButton -eq $true) { $formInstallationPrompt.MinimizeBox = $true }
<#MOD#> else { $formInstallationPrompt.MinimizeBox = $false }
        $formInstallationPrompt.Name = 'InstallPromptForm'
        $formInstallationPrompt.Text = $title
        $formInstallationPrompt.StartPosition = 'CenterScreen'
        # $formInstallationPrompt.FormBorderStyle = 'FixedDialog'
        $formInstallationPrompt.MaximizeBox = $false
<#MOD#> #$formInstallationPrompt.MinimizeBox = $false
        $formInstallationPrompt.TopMost = $TopMost
        $formInstallationPrompt.TopLevel = $true
        $formInstallationPrompt.AutoSize = $true
        $formInstallationPrompt.AutoScaleMode = 'Font'
        $formInstallationPrompt.AutoScaleDimensions = New-Object System.Drawing.SizeF(6, 13) #Set as if using 96 DPI
        $formInstallationPrompt.Icon = New-Object -TypeName 'System.Drawing.Icon' -ArgumentList ($AppDeployLogoIcon)
        $formInstallationPrompt.Controls.Add($pictureBanner)
        $formInstallationPrompt.Controls.Add($buttonAbort)
        $formInstallationPrompt.Controls.Add($flowLayoutPanel)
        ## Timer
        $installPromptTimer = New-Object -TypeName 'System.Windows.Forms.Timer'
        $installPromptTimer.Interval = ($timeout * 1000)
        $installPromptTimer.Add_Tick({
                Write-Log -Message 'Installation action not taken within a reasonable amount of time.' -Source ${CmdletName}
                $buttonAbort.PerformClick()
            })
        ## Init the OnLoad event to correct the initial state of the form
        $formInstallationPrompt.add_Load($Install_Prompt_Form_StateCorrection_Load)
        ## Clean up the control events
        $formInstallationPrompt.add_FormClosed($Install_Prompt_Form_Cleanup_FormClosed)

        ## Start the timer
        $installPromptTimer.Start()

        ## Persistence Timer
        If ($persistPrompt) {
            $installPromptTimerPersist = New-Object -TypeName 'System.Windows.Forms.Timer'
            $installPromptTimerPersist.Interval = ($configInstallationPersistInterval * 1000)
            [ScriptBlock]$installPromptTimerPersist_Tick = {
                $formInstallationPrompt.WindowState = 'Normal'
                $formInstallationPrompt.TopMost = $TopMost
                $formInstallationPrompt.BringToFront()
                $formInstallationPrompt.Location = "$($formInstallationPromptStartPosition.X),$($formInstallationPromptStartPosition.Y)"
<#MOD#>         $formInstallationPrompt.WindowState = 'Normal'
            }
            $installPromptTimerPersist.add_Tick($installPromptTimerPersist_Tick)
            $installPromptTimerPersist.Start()
        }

        If (-not $AsyncToolkitLaunch) {
            ## Close the Installation Progress Dialog if running
            Close-InstallationProgress
        }

        [String]$installPromptLoggedParameters = ($installPromptParameters.GetEnumerator() | ForEach-Object { & $ResolveParameters $_ }) -join ' '
        Write-Log -Message "Displaying custom installation prompt with the parameters: [$installPromptLoggedParameters]." -Source ${CmdletName}


        ## Show the prompt synchronously. If user cancels, then keep showing it until user responds using one of the buttons.
        $showDialog = $true
        While ($showDialog) {
            # Minimize all other windows
            If ($minimizeWindows) {
                $null = $shellApp.MinimizeAll()
            }
            # Show the Form
            $result = $formInstallationPrompt.ShowDialog()
            If (($result -eq 'Yes') -or ($result -eq 'No') -or ($result -eq 'Ignore') -or ($result -eq 'Abort')) {
                $showDialog = $false
            }
        }
        $formInstallationPrompt.Dispose()

        Switch ($result) {
            'Yes' {
                Write-Output -InputObject ($buttonRightText)
            }
            'No' {
                Write-Output -InputObject ($buttonLeftText)
            }
            'Ignore' {
                Write-Output -InputObject ($buttonMiddleText)
            }
            'Abort' {
                # Restore minimized windows
                $null = $shellApp.UndoMinimizeAll()
                If ($ExitOnTimeout) {
                    Exit-Script -ExitCode $configInstallationUIExitCode
                }
                Else {
                    Write-Log -Message 'UI timed out but `$ExitOnTimeout set to `$false. Continue...' -Source ${CmdletName}
                }
            }
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion


##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
}
Else {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================
