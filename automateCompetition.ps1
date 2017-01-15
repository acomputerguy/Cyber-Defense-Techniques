#Author: Felipe Webb
#Description: Automate the process to run the competition.

#Pre-conditions:
#Virtual machines are in respective folders, different folders (red/blue) for different competitions (1/2/3)
#Example: File structure for blue team VMs are in a Resource Pool named CDT Class, a folder named Blue Comp 2
#Student accounts follow a naming convention: <first letter of first name in upper case><last name in all lower case>
#Example: Aschwarzenegger

#Functionalities (commands run consectuvively):
#Prompt user for snapshot names and descriptions
#Turn on blue and red team virtual machines that aren't already on consecutively
#White team also requested scoring engine to be included
#Grant access to all Red & Blue Team members via Console Only roles
#User-defined input will indicate waiting time until the next command in a progress bar
#(Sometimes there are white team delays or a server goes down)
#When time is up, terminate the session key of all the students in competition
#(Require killing session so new permissions are pushed)
#Suspend all red and blue team boxes
#Take snapshots with predefined user-input

###Consitent formatting with PowerCLI###
function printFormat {
	$len = $args[0].length
	$totalHyphens = "-" * $len
	Write-Host "`n$args`n$totalHyphens"
}
###End of formatting###

###Prompt user for snapshot details###
Write-Host "Thinking way ahead...`nSnapshot name of" -NoNewline
Write-Host " blue " -foregroundcolor blue -NoNewline
$blueName = Read-Host -Prompt "VMs"

Write-Host "Snapshot description of" -NoNewline
Write-Host " blue " -foregroundcolor blue -NoNewline
$blueDescription = Read-Host -Prompt "VMs"

Write-Host "Snapshot name of" -NoNewline
Write-Host " red " -foregroundcolor red -NoNewline
$redName = Read-Host -Prompt "VMs"

Write-Host "Snapshot description of" -NoNewline
Write-Host " red " -foregroundcolor red -NoNewline
$redDescription = Read-Host -Prompt "VMs"

###Grab all blue and red virtual machines for specific competition who have yet to be turned on###
$blueVMs = Get-Folder "Blue Comp 2" | Get-VM
$redVMs = Get-Folder "Red Comp 2" | Get-VM

###Grant privileges in Console-Only role to its respective members###
Set-VIRole -Role "Console Only" -AddPrivilege "Console interaction"
Set-VIRole -Role "Console Only" -AddPrivilege "Answer question"

#Need to turn on scoring engine for white team as per request
$scoringEngineVM = Get-VM | where {$_.name -eq "Heartbeat - Scoring Engine" }
if ($scoringEngineVM.PowerState -eq "Suspended" -Or $scoringEngineVM.PowerState -eq "PoweredOff")
{ Start-VM $scoringEngineVM }

#VM input validation - what if a VM is already turned on? In case a student turns it on
$startBlueVMs = $blueVMs | where { $_.Powerstate -ne "PoweredOn" }
$startRedVMs = $redVMs | where { $_.Powerstate -ne "PoweredOn" }

###Print out affected virtual macines###
printFormat "VMs in competition include"
foreach($VM in $startBlueVMs)
{ Write-Host $VM -foregroundcolor blue }
foreach($VM in $startRedVMs)
{ Write-Host $VM -foregroundcolor red }

###Start all affected virtual machines in background consecutively###
printFormat "Powered on the following VMs"
foreach($VM in $startBlueVMs)
{ Start-VM -VM $VM -RunAsync:$false }
foreach($VM in $startRedVMs)
{ Start-VM -VM $VM -RunAsync:$false }

###Defining Session for Message of the Day so it is broadcasted to everyone###
$serviceInstance = Get-View ServiceInstance
$sessionManager = Get-View $serviceInstance.Content.SessionManager
$sessionManager.Message

###User input for time to wait in progress bar until next commands###
$timeWait = Read-Host -Prompt "Waiting time [format is HR,MIN e.g. 1,25]"

$hours = $timeWait[0]
[int]$intHours = [convert]::ToInt32($hours, 10)

$length = $timeWait.length

function inputValidation {
	if($length -eq 3)
	{ $minutes = $timeWait[2]; return $minutes }
	elseif ($length -eq 4)
	{ $minutes = $timeWait[2] + $timeWait[3]; return $minutes }
}

$minutes = inputValidation
[int]$intMinutes = [convert]::ToInt32($minutes, 10)

$totalSeconds = $intHours * 3600 + $intMinutes * 60

$currentTime = Get-Date
$currentTime = $currentTime.AddHours($intHours)
$currentTime = $currentTime.AddMinutes($intMinutes)
$endTime = Get-Date $currentTime -Format T

for($i=1;$i -lt $totalSeconds; $i++)
{
	#include the final moment this all ends
	$activity = "Waiting ${intHours}H ${intMinutes}M..."
	$status = "Currently at $i seconds"
	$remaining = $totalSeconds - $i
	[int]$percentage = $i / $totalSeconds * 100
	$operation = "$percentage% complete...over at $endTime"
	
	#When there is 5 sec left, broadcast a message to everyone
	if ($i -eq ($totalSeconds - 300))
	{ $sessionManager.UpdateServiceMessage("5 minutes left lol") }
	
	Write-Progress -Activity $activity -Status $status -SecondsRemaining $remaining -PercentComplete $percentage -CurrentOperation $operation
	Sleep 1
	
	#End the progress bar
	Write-Progress -Activity "Finishing..." -Status "Wrapping up" -Completed
}

#Remove MOTD
$sessionManager.UpdateServiceMessage("")

###Kill all red/blue team students' sessions###
$sessionMgr = Get-View $DefaultVIServer.ExtensionData.Client.ServiceContent.SessionManager

$allSessions = @()

#Only need username and session key
$sessionMgr.sessionList | foreach {
		$session = New-Object -TypeName PSObject -Property @{
		Username = $_.Username
		Key = $_.Key
		#Fullname = $_.Fullname
		#IPAddress = $_.IPAddress
		#LoginTime = ($_.logintime).ToLocaltime()
		#LastActiveTime = ($_.LastActiveTime).ToLocalTime()
	}
	$allSessions += $session
}
#Students are listed as VASE\Students
#Checking for usernames with first letter in upper case
$disconnectUsers = $allSessions | Where {$_.Username -cmatch "^VASE\\[A-Z]"}

$disconnectUsers | foreach { 
	$SessionMgr.TerminateSession($_.Key)
}

###Remove privileges from role to its respective members###
Set-VIRole -Role "Console Only" -RemovePrivilege "Console interaction"
Set-VIRole -Role "Console Only" -RemovePrivilege "Answer question"

#Input validation for VMs - suspend VMs for machines who have yet to be suspended
$stopBlueVMs = $blueVMs | where { $_.Powerstate -eq "PoweredOn" }
$stopRedVMs = $redVMs | where { $_.Powerstate -eq "PoweredOn" }

#Suspend all affected virtual machines when time is up
printFormat "Suspended the following VMs"
foreach($VM in $stopBlueVMs)
{ Suspend-VM -VM $VM -Confirm:$false -RunAsync:$false }
foreach($VM in $stopRedVMs)
{ Suspend-VM -VM $VM -Confirm:$false -RunAsync:$false }

###Snapshot virtual machines###
function snapshotVMs{
	foreach($VM in $redVMs)
	{ New-Snapshot -VM $VM -Name $redName -Description $redDescription }
	foreach($VM in $blueVMs)
	{ New-Snapshot -VM $VM -Name $blueName -Description $blueDescription }
}
