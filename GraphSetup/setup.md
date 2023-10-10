# Graph setup

## Set-up

Using any Windows 10 computer. 

Make sure you run the powershell/terminal window as an administrator. 

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Script -name Get-WindowsAutopilotInfo -Force
Get-WindowsAutopilotInfo -Online
```

This will install the following script from PowerShell Gallery: 

[Get-WindowsAutoPilotInfo 3.9](https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.9)

This uses the Connect-MgGraph command with the following scopes:

```
Group.ReadWrite.All
Device.ReadWrite.All
DeviceManagementManagedDevices.ReadWrite.All
DeviceManagementServiceConfig.ReadWrite.All
GroupMember.ReadWrite.All
```

These are required so you are covered if you also use the “-group” parameter to add devices to an Azure AD Group.

## Login

You’ll be prompted to login to your tenant:

![login box for azure ad](https://github.com/adamgell/PublicPowerShell/blob/main/GraphSetup/images/login.png)

Microsoft Graph Command Line Tools (it may be listed as Microsoft Graph PowerShell on some tenants) which are used by the SDK to run commands needs to setup an Application within your Azure Active Directory with the permissions selected earlier:

After you login, you will see the following popup: 

![https://andrewstaylor.com/wp-content/uploads/2023/06/image-10.png](https://andrewstaylor.com/wp-content/uploads/2023/06/image-10.png)

Make sure you check the box that says “consent on behalf..” if this isn’t checked then each time you or the team import a hash. They will need access to accept these permissions. Usually that is accessible by the global administrator role. 

We can then close the powershell window after accepting the permissions. We don’t need the computer’s hash to complete the upload. 

## Setting up user access to upload hashes

If we navigate to Azure AD and click on Enterprise Applications, we can see the app in there:

![Microsoft Graph Command Line Tools](https://andrewstaylor.com/wp-content/uploads/2023/06/image-5.png)

Microsoft Graph Command Line Tools

Now in the enterprise app, the permissions are setup for any one configured with permission to use the app. We can add users or groups and those folks will be able to upload any computer to Autopilot. 

![Untitled](Graph%20setup%204cafe5302df04bc7a6596c9fdbd0608c/Untitled.png)
