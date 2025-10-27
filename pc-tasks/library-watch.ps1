<#
.SYNOPSIS
	Watch the library folder and syncs all newly created files.

.DESCRIPTION
	Registers a file watcher for all subdirectories in the library folder. Runs the library-sync.ps1 script on the discovered files.

.PARAMETER Source
	The full filepath of the original library files.

.EXAMPLE
	&"C:\Tasks\library-watch.ps1" -Source "E:\Downloads\Library"

	Watch the library and run library-sync when changes are detected.
#>
param (
	[string]$Source = "E:\Downloads\Library"
)

# Path to the log file
$ScriptName = Split-Path -Leaf $PSCommandPath
$LogFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "${ScriptName}-$(New-Guid).log"

# https://stackoverflow.com/a/29067433
Function Register-FileWatcher {
	param (
		[string]$Folder,
		[string]$EventName = 'Created',
		[string]$Filter = '*', # Look for all files, excluding folders in the event handler
		[string]$SyncScript = 'C:\Tasks\library-sync.ps1',
		[string]$OrganizeScript = 'C:\Tasks\library-organize.ps1',
		[string]$LogFile
	)
	# This block calls the sync script after waiting for the new file to become available
	$action = [scriptblock]::Create('
		# This is the code which will be executed every time a file change is detected
		$fullPath = $Event.SourceEventArgs.FullPath
		if(-not (Test-Path -LiteralPath $fullPath -PathType Container)){
			$previousSize = -1
			Start-Sleep -Seconds 1
			do {
				try {
					Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] Testing the file for size: ${fullPath}"
					$currentSize = (Get-Item -LiteralPath $fullPath).Length
				} catch {
					Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] Error while checking the file size: ${fullPath}"
					# Exits the loop if the file was deleted or transfer was cancelled
					return
				}
			# Loop iterates if the size has changed, and sleeps 5 seconds before continuing
			} while ($currentSize -ne $previousSize -and ($previousSize = $currentSize) -and -not (Start-Sleep -Seconds 5))
			$relPath = $Event.SourceEventArgs.Name
			$changeType = $Event.SourceEventArgs.ChangeType
			$timeStamp = $Event.TimeGenerated
			Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] The file ${relPath} was ${changeType} at ${timeStamp}: ${fullPath}"
			Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] &""' + $SyncScript + '"" -Filter ""${relPath}"" -NonInteractive"
			$syncFolder = & pwsh -File "' + $SyncScript + '" -Filter "${relPath}" -NonInteractive
			$exitCode = $LASTEXITCODE
			Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] ExitCode=$exitCode"
			Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] &""' + $OrganizeScript + '"" -Sync ""${syncFolder}"" -Windows ""E:\Downloads\Sync"" "
			if($exitCode -eq 0) {
				Start-Sleep -Seconds 1
				& pwsh -File "' + $OrganizeScript + '" -Sync "${syncFolder}" -Windows "E:\Downloads\Sync"
			}
			Add-Content -Path "' + $LogFile + '" -Value "[$(Get-Date -Format u)] Watch complete: ${fullPath}"
		}
	')
	# Create FileSystemWatcher
	$watcher = New-Object IO.FileSystemWatcher $Folder, $Filter -Property @{ 
		IncludeSubdirectories = $true
		EnableRaisingEvents = $true
	}

	# Process events
	Register-ObjectEvent -InputObject $Watcher -EventName $EventName -Action $Action
}
# Watch the source folder for changes
Register-FileWatcher -Folder $Source -LogFile $LogFile

# Keep the script alive forever
Add-Content -Path $LogFile -Value "[$(Get-Date -Format u)] Library watcher started for $Source"
while ($true) {
	# The sleep cycle determines how often to fire the event
	Start-Sleep -Seconds 10
}
