#Prompt for numbered-based options

$title = "Menu Options"
$message = "Choose the following:"
	
$option1 = New-Object System.Management.Automation.Host.ChoiceDescription "&1`bOption 1", "First choice"
$option2 = New-Object System.Management.Automation.Host.ChoiceDescription "&2`bOption 2", "Second choice"
$option3 = New-Object System.Management.Automation.Host.ChoiceDescription "&3`bOption 3", "Third choice"
$option4 = New-Object System.Management.Automation.Host.ChoiceDescription "&4`bOption 4", "Fourth choice"
$quit = New-Object System.Management.Automation.Host.ChoiceDescription "&5`bQuit", "Quit the program"

$options = [System.Management.Automation.Host.ChoiceDescription[]]($option1, $option2, $option3, $option4, $quit)

$result = $host.ui.PromptForChoice($title, $message, $options, 4)

switch($result)
{
	0 { "Executing choice #1..." }
	1 { "Executing choice #2..." }
	2 { "Executing choice #3..." }
	3 { "Executing choice #4..." }
	4 {"Quitting..."}
}
