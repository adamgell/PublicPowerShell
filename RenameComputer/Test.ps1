# Run this in PowerShell to check for syntax errors
$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(".\RenameBySubnet2.ps1", [ref]$tokens, [ref]$errors)
$errors