$Found = 0

bomgar-scc.exe

if (Test-Path "C:\ProgramData\bomgar*")
{
	$Found = 1
} 
if($Found -gt 0)
{
	Write-Host "Found it!" -ForegroundColor Green
	Exit 0
} 
else
{
	#if no path matched this will execute
    Write-Host "Not Found it!" -ForegroundColor Red
	Exit 1
}