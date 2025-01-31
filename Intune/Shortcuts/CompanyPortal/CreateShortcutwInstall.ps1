#Name of the application to install
$AppName = "Microsoft.CompanyPortal"
# Shortcut name that appears on the desktop. Make sure to include the .lnk extension.
$shortcutName = "Company Portal.lnk"
# Package Family Name of the application. This can be tricky to find. Get-AppxPackage *nameofapp* will show you the package family name.
$packageFamilyName = "Microsoft.CompanyPortal_8wekyb3d8bbwe"
# Application ID of the application. This can be tricky to find as well. If its a store app. then we need to check apps.microsoft.com for the ID in the URL.
$applicationId = "9wzdncrfj3pz"
# SKU ID of the application. Most likely this can be left alone
$skuId = 0016

if (-not $Package) {
    Write-Host "$appName not found. Installing..."
    $namespaceName = "root\cimv2\mdm\dmmap"
    $session = New-CimSession
    $omaUri = "./Vendor/MSFT/EnterpriseModernAppManagement/AppInstallation"
    $newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance "MDM_EnterpriseModernAppManagement_AppInstallation01_01", $namespaceName
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", $omaUri, "string", "Key")
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", $packageFamilyName, "String", "Key")
    $newInstance.CimInstanceProperties.Add($property)
    $Package = Get-AppxPackage | Where-Object {$_.Name -eq $AppName}

    $flags = 0
    $paramValue = [Security.SecurityElement]::Escape($('<Application id="{0}" flags="{1}" skuid="{2}"/>' -f $applicationId, $flags, $skuId))
    $params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
    $param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", $paramValue, "String", "In")
    $params.Add($param)

    try {
        $instance = $session.CreateInstance($namespaceName, $newInstance)
        $result = $session.InvokeMethod($namespaceName, $instance, "StoreInstallMethod", $params)
        Write-Host "Installation initiated. Result:"
        $result
        
        # Wait for package to become available with timeout
        $timeout = 300 # 5 minutes
        $timer = [Diagnostics.Stopwatch]::StartNew()
        
        Write-Host "Waiting for $appName installation to complete..."
        do {
            Start-Sleep -Seconds 10
            $Package = Get-AppxPackage | Where-Object {$_.Name -eq $AppName}
            
            if ($timer.Elapsed.TotalSeconds -gt $timeout) {
                throw "Installation timeout after $timeout seconds"
            }
        } while (-not $Package)
        
        $timer.Stop()
        Write-Host "Installation completed in $([math]::Round($timer.Elapsed.TotalSeconds)) seconds"
    }
    catch [Exception] {
        Write-Host "Installation Error:"
        Write-Host $_ | Out-String
        exit 1
    }
    finally {
        Remove-CimSession -CimSession $session
    }
}

if ($Package) {
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $ShortcutPath = "$env:PUBLIC\Desktop\$shortcutName"
        
        $PackageFamilyName = $Package.PackageFamilyName
        $ApplicationId = "App"
        
        $TargetPath = "shell:AppsFolder\$PackageFamilyName!$ApplicationId"
        
        $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = $TargetPath
        $Shortcut.Save()
        
        Write-Host "Shortcut created successfully at: $ShortcutPath"
        exit 0
    }
    catch {
        Write-Host "Error creating shortcut:"
        Write-Host $_ | Out-String
        exit 1
    }
} else {
    Write-Host "Error: Failed to install or locate $appName ."
    exit 1
}