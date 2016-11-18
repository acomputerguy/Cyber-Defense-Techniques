#Input code at the end of Initialize-PowerCLIEnvironment.ps1 file
#This is where source code to automatically boot powercli is

#Create function to be called if login is incorrect
function loginVcenter {
	<#
	.SYNOPSIS
	Function will automatically log into VIServer
	.DESCRIPTION
	Function prompts user for server name, user name, and password
	.EXAMPLE
	Input the following respectively - vcenter.vase.local, fwebb, password
	.PARAMETER
	Queried vcenter.vase.local in my uses
	#>

	#Due to runtime issues, confirm for user to input first
	Write-Host "`nPress any key to continue...`n"
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | out-null
	
	Write-Host "Ctrl+C to exist custom login script`n"

	#Check if password has been logged before in boolean expression
	$FileExists = Test-Path C:\Users\Student\AppData\Roaming\VMware\credstore\vicredentials.xml

	#If file exists, then it is populated. Automatically log the user back in
	if ($FileExists -eq $true)
	{
		#There will only be 1 user so pull that user
		$cred = Get-VICredentialStoreItem -User *
		Connect-VIServer -Server $cred.Host -User $cred.User -password $cred.Password -Force
		break
	}

	#Prompt user for server to conncet to - vcenter.vase.local
	$server = Read-Host -Prompt 'Input domain address'

	#Parse for vase.local in server name
	$indexPos = $server.IndexOf(".") + 1;
	$length = $server.length
	$portionDomain = $server.substring($indexPos, $length - $indexPos)

	#Append @vase.local to username, format is as follows: <usrnm>@vase.local
	$user = Read-Host -Prompt 'Username'
	$user = $user + "@" + $portionDomain

	#Read passwords as asterisks, keep out of buffer, and convert back to plaintext for connection
	$maskedPassword = Read-Host -Prompt 'Password' -AsSecureString
	$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto( [Runtime.InteropServices.Marshal]::SecureStringToBSTR($maskedPassword) )

	#Connect to VIServer, ignoring invalid certificate action and multiple default servers
	Connect-VIServer -Server $server -Protocol https -User $user -Password $password -Force
	Write-Host "`n"

	return $server, $user, $password
}

#Call function and store results for relogin
$credentials = loginVcenter

#Error buffer is shell-specific, reinitiate login prompt if incorrect
while($true)
{
	if( ($error[0] -match "Cannot complete login due to an incorrect user name or password") -OR ($error[0] -match "Could not resolve the requested VC server") )
	{
		#Clear buffer
		$error.Clear()
		#Store only most recent results of login
		$credentials = loginVcenter
	}
	elseif ( ($error[0] -NotMatch "Cannot complete login due to an incorrect user name or password") -OR ($error[0] -NotMatch "Could not resolve the requested VC server") )
	{
		#Welcome user
		Write-Host "`t`nWelcome! You are now in " -NoNewLine
		Write-Host -foregroundcolor yellow $global:DefaultVIServer
		
		#If login is successful, store credentials
		$server = $credentials[1]
		$user = $credentials[2]
		$password = $credentials[3]
		New-VICredentialStoreItem -Host $server -User $user -Password $password
		
		Break
	}
}
