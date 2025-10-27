<#
.SYNOPSIS
	Organizes the video libraries for Radarr and Sonarr. I refer to both of these as Arr Apps.

.DESCRIPTION
	Searches the Sync filepath for files and adds them to the corresponding Arr App. The first pass will attempt to process files with the manual import API. Any unknown (i.e., not in the library) programs (i.e., Movies or TV) proceeds to a lookup API. The Arr App will attempt to match the lookup program with the files, keeping any matched programs in the Library. Finally, all shows in the Sync folder are processed using the command API, which posts data using the manual import command.
	Python source: https://www.reddit.com/r/sonarr/comments/1bt11re/comment/kxl169t/

.PARAMETER Name
	The name of the library: Movies, TV, or Both [default].

.PARAMETER Sync
	The full filepath of a directory either in the Arr App (Linux-style) or Windows filesystem (requires the Windows parameter). The Arr App API searches this filepath for videos using the manual import function.

.PARAMETER Library
	The full filepath either in the Arr App (Linux-style) or Windows filesystem (requires the Windows parameter). The Arr App organizes the Sync files into this directory as the base path.

.PARAMETER Windows
	The full filepath in the Windows filesystem. The filepath acts as the corresponding basepath to the Linux filesystem basepath. For example, the Windows path 'C:\Library\' will map to the Linux path '/data/'.

.PARAMETER Linux
	The full filepath in the Linux filesystem. The filepath points to the parent directory of video files, e.g. the Arr App stores TV shows in '/data/TV'.

.PARAMETER NonInteractive
	Non-interactive mode does not print to console using Write-Host, which avoids conflicts with return statements in nested PowerShell scripts.

.PARAMETER WhatIf
	Executes the script in dry-run mode without making changes. This will not add content to the Arr App library, causing cascading errors on new programs (i.e., Movies or TV), but there is nothing to worry about!

.PARAMETER Log
	Log all output for debugging. Enabling this option will significantly increase execution time.

.EXAMPLE
	&"C:\Tasks\library-organize.ps1" -Name 'Movies -Sync "E:\Downloads\Sync\~\TV\Show\Season" -Windows "E:\Downloads\Sync" -WhatIf

	Test run of the script without syncing or deleting any files. Translates the Sync folder to Linux-style for use in the Arr Apps.
#>
param (
	[ValidateSet('Both', 'Movies', 'TV')][string]$Name = 'Both',
	[string]$Sync,
	[string]$Library,
	[string]$Windows,
	[string]$Linux = '/data',
	[switch]$NonInteractive,
	[switch]$WhatIf,
	[switch]$Log
)

<#############################################################################################################

Utility functions to open and close the script

##############################################################################################################>

# Path to the lock and log file
$ScriptName = Split-Path -Leaf $PSCommandPath
$LockFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "${ScriptName}.lock"
$LogFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "${ScriptName}-$(New-Guid).log"

# Write data to console only in interactive mode
function Write-Custom {
	param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$String,
		[System.ConsoleColor]$ForegroundColor = $Host.UI.RawUI.ForegroundColor,
		[switch]$NoNewline,
		[switch]$Err # $Error is a built-in variable
	)
	process {
		# Cannot call a function so use Script-level variable for writing to host
		if((-not $NonInteractive) -or $Script:IsInteractive){
			if($Err){
				Write-Error $String
			} else {
				if($NoNewLine) {
					Write-Host $String -ForegroundColor $ForegroundColor -NoNewline
				} else {
					Write-Host $String -ForegroundColor $ForegroundColor
				}
			}
		} elseif($Script:Log) {
			$Label = if($Err) { "ERROR" } else { $ForegroundColor }
			$Value = "[$(Get-Date -Format u) *${Label}*] " + $String
			if($NoNewLine) {
				Add-Content -Path $Script:LogFile -Value $Value -NoNewLine
			} else {
				Add-Content -Path $Script:LogFile -Value $Value
			}
		}
	}
}

# Attempt to acquire the lock
$lockStream = $null
$waitSeconds = 0
while (-not $lockStream) {
	try {
		# Try to open the lock file exclusively
		$lockStream = [System.IO.File]::Open(
			$LockFile,
			[System.IO.FileMode]::OpenOrCreate,
			[System.IO.FileAccess]::ReadWrite,
			[System.IO.FileShare]::None
		)
		# Successfully acquired the lock
		Write-Custom "🔒 Lock acquired: $LockFile" -ForegroundColor Cyan
	} catch {
		$waitSeconds++
		# Lock is held by another process
		Write-Custom "⏳ Another instance has been running for ${waitSeconds} seconds. Waiting..." -ForegroundColor Red
		Start-Sleep -Seconds 1
	}
}

function Unlock-Script {
	if ($lockStream) {
		$lockStream.Close()
		Remove-Item -LiteralPath $LockFile -ErrorAction SilentlyContinue
		Write-Custom "🔓 Lock released: $LockFile" -ForegroundColor Cyan
	}
}

# Register cleanup to release lock on exit, even if script crashes
$null = Register-EngineEvent PowerShell.Exiting -Action {
	Unlock-Script
}

# Unlock the sync process and exit
function Exit-Script {
	param (
		[int]$Value = 0
	)
	Unlock-Script
	Write-Custom "👋 Exiting script..." -ForegroundColor Cyan
	exit $Value
}

<#############################################################################################################

Helper functions

##############################################################################################################>

function ConvertTo-HashtableLiteral {
	param([Parameter(ValueFromPipeline = $true)][object]$obj)
	if ($null -eq $obj) { return "@{}" }
	$json = $obj | ConvertTo-Json -Depth 100
	return $json -replace '\[','@(' -replace '\]',')' -replace '\{','@{' -replace ': ',' = ' -replace '(?m),\s*$',';'
}

function ConvertFrom-WindowsPath {
	param (
		[string]$Path,
		[string]$Base = $Script:Windows,
		[string]$LinuxBase = $Script:Linux
	)
	if((-not $Path) -or (-not $Base)) { return $Path }

	# Make sure both paths are full paths
	$WindowsBase = [System.IO.Path]::GetFullPath($Base)
	$FilePath    = [System.IO.Path]::GetFullPath($Path)

	# Check if the path is under the base
	if ($FilePath.StartsWith($WindowsBase, [System.StringComparison]::OrdinalIgnoreCase)) {
		# Strip the base path and replace backslashes with slashes
		$RelativePath = $FilePath.Substring($WindowsBase.Length) -replace '\\','/'

		return $LinuxBase.TrimEnd('/') + '/' + $RelativePath.TrimStart('/')
	} else {
		Write-Custom -Err "❗ Provided directory does not exist within the Windows path: $Path"
		Exit-Script 1
	}
}

<#############################################################################################################

Organizing videos

##############################################################################################################>

function Test-Server {
	Write-Custom "🛜 Pinging ${Script:TypeName} server: ${Script:Url}" -ForegroundColor DarkGreen

	$baseUrl = "${Script:Url}/api/v3/system/status"
	$headers = @{
		'X-Api-Key' = $Script:ApiKey
	}

	try {
		$response = Invoke-RestMethod -ErrorAction Stop -Method Get -Uri $baseUrl -Headers $headers
		Write-Custom "✅ Received ping response from ${Script:TypeName} server with app version: $($response.appName) $($response.version)" -ForegroundColor Green
		return $true
	}
	catch {
		Write-Custom -Err "❌ Failed to ping the ${Script:TypeName} server: $_"
		return $false
	}
}

function Find-Video {
	param (
		[string]$Folder
	)
	Write-Custom "🔍 Searching for $($Script:ProperNames.toLower()) in folder: $Folder" -ForegroundColor DarkGreen

	$baseUrl = "${Script:Url}/api/v3/manualimport?folder=$([uri]::EscapeDataString($Folder))"
	$headers = @{
		'X-Api-Key' = $Script:ApiKey
	}

	try {
		$response = Invoke-RestMethod -ErrorAction Stop -Method Get -Uri $baseUrl -Headers $headers
		return $response
	}
	catch {
		Write-Custom -Err "❌ Failed to fetch $($Script:ProperName.toLower()) from ${Folder}: $_"
		return
	}
}

function Search-Unknown {
	param (
		[string]$Title
	)
	Write-Custom "🔍 Looking up unknown $($Script:ProperName.toLower()): $Title" -ForegroundColor DarkGreen

	$term = $Title -replace '[._]', ' '
	$baseUrl = "${Script:Url}/api/v3/${Script:Endpoint}/lookup?term=$term"
	$headers = @{
		'X-Api-Key' = $Script:ApiKey
	}

	try {
		$response = Invoke-RestMethod -ErrorAction Stop -Method Get -Uri $baseUrl -Headers $headers
		if($response) {
			Write-Custom "✅ Found $($response.Count) results from ${Script:TypeName} server: $Title" -ForegroundColor DarkGreen
		} else { throw }
		$sorted = switch($Script:TypeName){
			'Movies' { $response | Sort-Object -Property 'popularity' -Descending }
			'TV' { $response | Sort-Object -Property @{ Expression = { $_.ratings.votes }; Descending = $true } }
		}
		return $sorted
	}
	catch {
		Write-Custom -Err "❌ Failed to find unknown $($Script:ProperName.toLower()): $_"
		return @()
	}

}

function Add-Unknown {
	param (
		[PSObject]$Data
	)

	$baseUrl = "${Script:Url}/api/v3/${Script:Endpoint}"
	$headers = @{
		'Accept'       = 'application/json, text/javascript, */*; q=0.01'
		'Content-Type' = 'application/json'
		'X-Api-Key'    = $Script:ApiKey
	}

	# Add common properties
	$Data | Add-Member -Force -NotePropertyName 'monitored' -NotePropertyValue $true
	$Data | Add-Member -Force -NotePropertyName 'qualityProfileId' -NotePropertyValue 1
	$Data | Add-Member -Force -NotePropertyName 'path' -NotePropertyValue ($Script:LibraryPath + $Data.folder)
	$Data | Add-Member -Force -NotePropertyName 'rootFolderPath' -NotePropertyValue $Script:LibraryPath
	# Add Movies properties
	if($Script:TypeName -eq 'Movies') {
		$Data | Add-Member -Force -NotePropertyName 'minimumAvailability' -NotePropertyValue 'released'
		$Data | Add-Member -Force -NotePropertyName 'addOptions' -NotePropertyValue @{
			'monitor'        = 'movieOnly'
			'searchForMovie' = $true
		}
	}
	# Add TV properties
	if($Script:TypeName -eq 'TV') {
		$Data | Add-Member -Force -NotePropertyName 'addOptions' -NotePropertyValue @{
			monitor                  = 'all'
			searchForMissingEpisodes = $true
		}
	}

	Write-Custom "🚀 Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $($headers | ConvertTo-HashtableLiteral) -Body $Data" -ForegroundColor Gray
	if($WhatIf) {
		Write-Custom "📺 Would add $($Script:ProperName.toLower()): $($Data | ConvertTo-HashtableLiteral)" -ForegroundColor Cyan
	} else {
		try {
			Write-Custom "📺 Adding $($Script:ProperName.toLower()) to library: $($Data.folder)" -ForegroundColor Green
			$response = Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $headers -Body ($Data | ConvertTo-Json -Depth 100)
			Write-Custom "📝 Received response from ${Script:TypeName} server: $response" -ForegroundColor Yellow
			return $response
		}
		catch {
			$errorObj = $_
			Write-Custom -Err "❌ Failed to add unknown $($Script:ProperName.toLower()): $errorObj"
			if("This ${Script:Endpoint} has already been added") {
				throw [System.InvalidOperationException]::new($errorObj)
			}
		}
	}
	return $Data
}

function Remove-Video {
	param (
		[string]$Id,
		[switch]$Delete
	)

	$deleteFiles = ([bool]$Delete).toString().toLower()
	$baseUrl = "${Script:Url}/api/v3/${Script:Endpoint}/${Id}?deleteFiles=${deleteFiles}&addImportExclusion=false"
	$headers = @{
		'Accept'       = 'application/json, text/javascript, */*; q=0.01'
		'Content-Type' = 'application/json'
		'X-Api-Key'    = $Script:ApiKey
	}

	Write-Custom "🚀 Invoke-RestMethod -ErrorAction Stop -Method Delete -Uri $baseUrl -Headers $($headers | ConvertTo-HashtableLiteral)" -ForegroundColor Gray
	if($WhatIf) {
		Write-Custom "✂️ Would remove $($Script:ProperName.toLower()) with ID: $Id" -ForegroundColor Cyan
	} else {
		try {
			Write-Custom "✂️ Removing $($Script:ProperName.toLower()) from library with ID: $Id" -ForegroundColor Green
			$response = Invoke-RestMethod -ErrorAction Stop -Method Delete -Uri $baseUrl -Headers $headers
			Write-Custom "📝 Received response from ${Script:TypeName} server: $response" -ForegroundColor Yellow
			return $true
		}
		catch {
			Write-Custom -Err "❌ Failed to remove $($Script:ProperName.toLower()) with ID: $_"
		}
	}
	return $false
}

function Debug-Rejections {
	param (
		[array]$Rejections
	)
	$reasons = @{}
	foreach($rejection in $Rejections) {
		$reason = $rejection.reason
		if($reason.toLower() -eq "Unknown $($Script:Endpoint)".toLower()) {
			Write-Custom "ℹ️ Rejection reason: $($rejection)" -ForegroundColor DarkCyan
			$reasons | Add-Member -Force -NotePropertyName 'Info' -NotePropertyValue $reason
		} elseif (($Script:TypeName -eq 'TV') -and ($rejection.reason -Like 'Episode * was unexpected considering the * folder name')) {
			Write-Custom "❗ Rejection reason: $($rejection)" -ForegroundColor DarkYellow
			$reasons | Add-Member -Force -NotePropertyName 'Warn' -NotePropertyValue $reason
		} else {
			Write-Custom "⛔ Rejection reason: $($rejection)" -ForegroundColor DarkRed
			$reasons | Add-Member -Force -NotePropertyName 'Error' -NotePropertyValue $reason
		}
		# Always set debug value if a rejection is found
		$reasons | Add-Member -Force -NotePropertyName 'Debug' -NotePropertyValue $true
	}
	return $reasons
}

function Repair-Rejections {
	param (
		[array]$Videos
	)
	Write-Custom "🛠️ Analyzing $($Videos.Count) $($Script:ProperNames.toLower())..." -ForegroundColor DarkGreen

	$processed = @($Videos | ForEach-Object {
		$video = $_
		$reasons = Debug-Rejections -Rejections $video.rejections
		if($reasons.Info){
			# Try finding video before searching in case its already added
			$recheckVideo = Find-Video -Folder $video.path
			$recheckReasons = Debug-Rejections -Rejections $recheckVideo.rejections
			if(-not $recheckReasons.Info) {
				Write-Custom "✅ Successfully rechecked $($Script:ProperName.toLower()): $($video.name)" -ForegroundColor DarkCyan
				$video = $recheckVideo
			} else {
				# Search for the video
				$searchResults = Search-Unknown -Title $video.name
				$searchSuccess = $null
				foreach($result in $searchResults) {
					try {
						$addedVideo = Add-Unknown -Data $result
					} catch [System.InvalidOperationException] {
						# Title already exists in the library but does not match, search for different titles
						continue
					} catch {
						# Other error
						break
					}
					$foundVideo = Find-Video -Folder $video.path
					# Check each movie again with find video
					$foundReasons = Debug-Rejections -Rejections $foundVideo.rejections
					if(-not $foundReasons.Info){
						$searchSuccess = $foundVideo
						break
					} else {
						#  Check next search result, eg. Flow (2024) vs Flow (2019)
						$removed = Remove-Video -Id $addedVideo.Id -Delete
						# Stop processing if there was an error removing
						if($removed) { continue } else { break }
					}
				}
				if($searchSuccess) {
					$video = $searchSuccess
				} else {
					Write-Custom -Err "❌ Failed to find matching $($Script:ProperName.toLower()) title: $video.name"
					continue
				}
			}
		}
		if($reasons.Error){
			Write-Custom "⚠️ $($Script:ProperName) rejected: $($video.path)" -ForegroundColor Red
			continue
		}
		$video
	})
	return $processed
}

function Import-Videos {
	param (
		[array]$Videos
	)
	Write-Custom "📺 Importing $($Videos.Count) $($Script:ProperNames.toLower())..." -ForegroundColor Green

	$baseUrl = "${Script:Url}/api/v3/command"
	$headers = @{
		'Accept'       = 'application/json, text/javascript, */*; q=0.01'
		'Content-Type' = 'application/json'
		'X-Api-Key'    = $Script:ApiKey
	}

	$seriesId
	$files = @($Videos | ForEach-Object {
		$file = $_
		Write-Custom "✅ Importing file: $($file.path)" -ForegroundColor Cyan

		$video = @{
			path          = $file.path
			releaseGroup  = $file.releaseGroup
			quality       = $file.quality
			languages     = $file.languages
			indexerFlags  = $file.indexerFlags
			triggerImport = $true
		}
		if($Script:TypeName -eq 'Movies') {
			$video.movieId = $file.movie.id
		}
		if($Script:TypeName -eq 'TV') {
			$video.seriesId = ($file.episodes.seriesId | Select-Object -First 1)
			$video.episodeIds = @($file.episodes.id)
		}
		$video
	})

	# No videos found
	if(-not $files){
		Write-Custom "⭕ No videos processed." -ForegroundColor Cyan
		return
	}

	$data = @{
		name                = "ManualImport"
		files               = $files
		importMode          = "move"
		filterExistingFiles = $true # Ignore files if the titles already exist in the library
	}

	Write-Custom "🚀 Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $($headers | ConvertTo-HashtableLiteral) -Body $data" -ForegroundColor Gray
	if($WhatIf) {
		Write-Custom "📺 Would process $($Script:ProperNames.toLower()): $($data | ConvertTo-HashtableLiteral)" -ForegroundColor Cyan
	} else {
		try {
			$response = Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $headers -Body ($data | ConvertTo-Json -Depth 100)
			Write-Custom "📺 Received response from ${Script:TypeName} server: $response" -ForegroundColor Yellow
			return $response
		}
		catch {
			Write-Custom -Err "❌ Failed to post $($Script:ProperNames.toLower()): $($data | ConvertTo-HashtableLiteral)"
			return
		}
	}
}

function Initialize-Library {
	param (
		[string]$Name,
		[string]$Sync,
		[string]$Library,
		[string]$Config
	)

	# Set script variables per library
	$Script:TypeName = $Name
	if(-not $Sync) { $Sync = "/data/~/${Script:TypeName}/" }
	if(-not $Library) { $Library = "/data/${Script:TypeName}/" }
	$Script:SyncPath = $Sync
	$Script:LibraryPath = $Library
	Write-Custom "💡 Using ${Script:TypeName} server sync path: ${Script:SyncPath}" -ForegroundColor Gray
	Write-Custom "💡 Using ${Script:TypeName} server library path: ${Script:LibraryPath}" -ForegroundColor Gray

	try {
		# Load default config file, e.g., C:\ScriptPath\ScriptName.json
		if(-not $Config) {
			$ScriptDir = Split-Path -Path $PSCommandPath -Parent
			$ScriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
			$Config = Join-Path $ScriptDir ($ScriptBaseName + '.json')
		}
		Write-Custom "💡 Loading configuration file: $Config" -ForegroundColor Gray
		# Load config
		$configContents = Get-Content -ErrorAction Stop -Raw -Path $Config
		$json = $configContents | ConvertFrom-Json

		# Look for required keys
		try {
			$jsonKey = $json.${Script:TypeName}
			if(-not $jsonKey) { throw [System.Exception] "key=${Script:TypeName}" }
			# Assign to script-scoped variables
			$Script:Url        = if($jsonKey.Url) { $jsonKey.Url } else { throw [System.Exception] "attribute=Url" }
			$Script:ApiKey     = if($jsonKey.ApiKey) { $jsonKey.ApiKey } else { throw [System.Exception] "attribute=ApiKey" }
			# Endpoint is for the lookup function
			$Script:Endpoint   = if($jsonKey.Endpoint) { $jsonKey.Endpoint } else { throw [System.Exception] "attribute=Endpoint" }
			$Script:ProperName = if($jsonKey.ProperName) { $jsonKey.ProperName } else { "${Script:TypeName}" }
			$Script:ProperNames= if($jsonKey.ProperNames) { $jsonKey.ProperNames } else { "${Script:TypeName}(s)" }
		} catch {
			Write-Custom -Err "🐞 Missing required configuration for ${Script:TypeName} server: $_"
			Exit-Script
		}
	}
	catch [System.Management.Automation.ItemNotFoundException] {
		Write-Custom -Err "🐞 Configuration file not found for ${Script:TypeName} server: $Config"
		Exit-Script
	}
	catch [System.Management.Automation.RuntimeException] {
		Write-Custom -Err "🐞 Error reading configuration file for ${Script:TypeName} server: $_"
		Exit-Script
	}
	catch {
		Write-Custom -Err "🐞 Unknown error when reading configuration file for ${Script:TypeName} server: $_"
		Exit-Script
	}

	$waitTimeout = 15
	$waitSeconds = 0
	while (-not (Test-Server)) {
		# Server is not responding to health check
		Write-Custom "⏳ Waiting for ${Script:TypeName} server to start for ${waitSeconds}s. Pausing for ${waitTimeout}s..." -ForegroundColor Red
		$waitSeconds += $waitTimeout
		Start-Sleep -Seconds $waitTimeout
	}
}

function Invoke-Organize {
	param (
		[string]$Name,
		[string]$Sync,
		[string]$Library,
		[string]$Config
	)
	Initialize-Library -Name $Name -Sync $Sync -Library $Library -Config $Config | Out-Null

	$findVideos = Find-Video -Folder $Script:SyncPath

	if ($findVideos) {
		$addVideos = Repair-Rejections -Videos $findVideos
		if($addVideos) {
			$null = Import-Videos -Videos $addVideos
		} else {
			Write-Custom "🚫 All $($Script:ProperNames.toLower()) rejected, nothing to import." -ForegroundColor Gray
		}
	}
	else {
		Write-Custom "🚫 No $($Script:ProperNames.toLower()) to import." -ForegroundColor Gray
	}
}

# Convert from Windows to Linux, if WindowsPath is provided
$Sync = ConvertFrom-WindowsPath -Path $Sync
$Library = ConvertFrom-WindowsPath -Path $Library

# Explicitly set the Name if the Sync folder matches the folder pattern
if(($Sync) -and ($Name -eq 'Both')) {
	if($Sync.StartsWith("${Script:Linux}/~/Movies/")) {
		$Name = 'Movies'
		$Library = "${Script:Linux}/$Name/"
	}
	if($Sync.StartsWith("${Script:Linux}/~/TV/")) {
		$Name = 'TV'
		$Library = "${Script:Linux}/$Name/"
	}
}

if($Name -eq 'Both') {
	Invoke-Organize -Name 'Movies'
	Invoke-Organize -Name 'TV'
} else {
	Invoke-Organize -Name $Name -Sync $Sync -Library $Library
}

# Check for task finished, then call Jellyfin server to update the library
# Not really necessary since Jellyfin has real-time monitoring enabled on all libraries
#📺 Received response from TV server: @{name=ManualImport; commandName=Manual Import; body=; priority=high; status=started; result=unknown; queued=09/09/2025 01:19:57; started=09/09/2025 01:19:57; trigger=manual; stateChangeTime=09/09/2025 01:19:57; sendUpdatesToClient=True; updateScheduledTask=True; id=158787}

Exit-Script
