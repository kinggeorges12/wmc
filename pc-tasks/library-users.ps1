<#
.SYNOPSIS
	Adds Jellyfin users to Jellyseerr and resets the password to passthrough login parameters for the nginx interface.

.DESCRIPTION
	Helps automate the login process for Jellyseerr when used alongside Jellyfin. The nginx interface uses a single login credential to automatically login users who authenticate with Jellyfin.

.PARAMETER NonInteractive
	Non-interactive mode does not print to console using Write-Host, which avoids conflicts with return statements in nested PowerShell scripts.

.PARAMETER WhatIf
	Executes the script in dry-run mode without making adding any torrents.

.PARAMETER Log
	Log all output for debugging. Enabling this option will significantly increase execution time.

.EXAMPLE
	&"C:\Tasks\library-requests.ps1" -Log -WhatIf

	Log a test run of the script without importing Jellyfin users to Jellyseerr.
#>
param (
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

<#############################################################################################################

Requesting videos

##############################################################################################################>

function Test-Server {
	Write-Custom "🛜 Pinging ${Script:TypeName} server: ${Script:Url}" -ForegroundColor DarkGreen

	$baseUrl = "${Script:Url}/api/v1/status"
	$headers = @{
		accept = 'application/json'
	}

	try {
		$response = Invoke-RestMethod -ErrorAction Stop -Method Get -Uri $baseUrl -Headers $headers
		Write-Custom "✅ Received ping response from ${Script:TypeName} server with app version: $($response.version)" -ForegroundColor Green
		return $true
	}
	catch {
		Write-Custom -Err "❌ Failed to ping the ${Script:TypeName} server: $_"
		return $false
	}
}

function Connect-Server {
	Write-Custom "🛜 Authenticating ${Script:TypeName} server: ${Script:Url}" -ForegroundColor DarkGreen

	# Read password from file
	$Script:Password = Get-Content $Script:PasswordFile -Raw
	$baseUrl = "${Script:Url}/api/v1/auth/local"
	$headers = @{
		'Content-Type' = 'application/json'
		'Referer' = $Script:Url
	}
	$body = @{
		'email'    = $Script:Email
		'password' = $Script:Password
	} | ConvertTo-Json

	try {
		$null = Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $headers -Body $body -SessionVariable session
		$cookie = ($session.Cookies.GetCookies($Script:Url) | Where-Object { $_.Name -eq 'connect.sid' }).Value
		Write-Custom "✅ Received authentication session from ${Script:TypeName} server: $cookie" -ForegroundColor Green
		$Script:Session = $session
		$Script:Cookie = $cookie
		return $true
	}
	catch {
		Write-Custom -Err "❌ Failed to authenticate the ${Script:TypeName} server: $_"
		return $false
	}
}

function Reset-Password {
	param (
		[int]$UserId
	)

	Write-Custom "🔑 Resetting user password on ${Script:TypeName} server for ID: $UserId" -ForegroundColor DarkGreen

	$baseUrl = "${Script:Url}/api/v1/user/${UserId}/settings/password"
	$headers = @{
		'Content-Type' = 'application/json'
		'Referer' = $Script:Url
	}
	$body = @{
		'currentPassword' = ''
		'newPassword' = $Script:Password
		'confirmPassword' = $Script:Password
	} | ConvertTo-Json

	if($WhatIf) {
		Write-Custom "🔒 Would reset user password on ${Script:TypeName} server for ID: $UserId" -ForegroundColor Cyan
	} else {
		try {
			$response = Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $headers -Body $body -WebSession $Script:Session
			Write-Custom "🔐 Reset user password on ${Script:TypeName} server." -ForegroundColor Green
			return $response
		}
		catch {
			Write-Custom -Err "❌ Failed to reset user password on ${Script:TypeName} server: $_"
			return
		}
	}
}

function Import-ExternalUser {
	param (
		[string[]]$ExternalIds
	)

	Write-Custom "👥 Importing $($ExternalIds.Count) ${Script:External} user(s) to ${Script:TypeName} server." -ForegroundColor DarkGreen

	$baseUrl = "${Script:Url}/api/v1/user/import-from-$(${Script:External}.toLower())"
	$headers = @{
		'Content-Type' = 'application/json'
		'Referer' = $Script:Url
	}
	$body = @{
		'jellyfinUserIds' = $ExternalIds
	} | ConvertTo-Json

	if($WhatIf) {
		Write-Custom "🙋 Would import ${Script:External} user(s) to ${Script:TypeName} server with ID(s): $($ExternalIds -Join ', ')" -ForegroundColor Cyan
	} else {
		try {
			$response = Invoke-RestMethod -ErrorAction Stop -Method Post -Uri $baseUrl -Headers $headers -Body $body -WebSession $Script:Session
			Write-Custom "👤 Imported $($response.Count) ${Script:External} user(s) to ${Script:TypeName} server with ID(s): $($response.id -Join ', ')" -ForegroundColor Green
			return @($response)
		}
		catch {
			Write-Custom -Err "❌ Failed importing ${Script:External} user(s) to ${Script:TypeName} server: $_"
			return
		}
	}
}

function Get-ExternalUsers {
	Write-Custom "🔍 Fetching ${Script:External} users on ${Script:TypeName} server." -ForegroundColor DarkGreen

	$baseUrl = "${Script:Url}/api/v1/settings/$(${Script:External}.toLower())/users"
	$headers = @{
		'Content-Type' = 'application/json'
		'Referer' = $Script:Url
	}

	try {
		$response = Invoke-RestMethod -ErrorAction Stop -Method Get -Uri $baseUrl -Headers $headers -WebSession $Script:Session
		Write-Custom "👤 Found $($response.Count) ${Script:External} users on ${Script:TypeName} server: $($response.email -Join ', ')" -ForegroundColor Green
		return $response
	}
	catch {
		Write-Custom -Err "❌ Failed processing local users on ${Script:TypeName} server: $_"
		return
	}
}

function Get-LocalUsers {
	Write-Custom "🔍 Fetching local users on ${Script:TypeName} server." -ForegroundColor DarkGreen

	# Take all users, skipping admin
	$baseUrl = "${Script:Url}/api/v1/user?take=-1"
	$headers = @{
		'Content-Type' = 'application/json'
		'Referer' = $Script:Url
		#'Cookie' = "connect.sid=${Script:Cookie}"
	}

	try {
		$response = Invoke-RestMethod -ErrorAction Stop -Method Get -Uri $baseUrl -Headers $headers -WebSession $Script:Session
		$usernames = $response.results."$(${Script:External}.toLower())Username"
		Write-Custom "👤 Found $($response.pageInfo.results) local users on ${Script:TypeName} server: $($usernames -Join ', ')" -ForegroundColor Green
		return $response
	}
	catch {
		Write-Custom -Err "❌ Failed processing local users on ${Script:TypeName} server: $_"
		return
	}
}

function Initialize-Library {
	param (
		[string]$Config
	)
	$Script:TypeName = 'Jellyseerr'
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

		try {
			# Look for required keys for Library
			$jsonKey = $json.${Script:TypeName}
			if(-not $jsonKey) { throw [System.Exception] "key=${Script:TypeName}" }
			# Assign to script-scoped variables
			$Script:Url          = if($jsonKey.Url) { $jsonKey.Url } else { throw [System.Exception] "attribute=Url" }
			$Script:External     = if($jsonKey.External) { $jsonKey.External } else { throw [System.Exception] "attribute=External" }
			$Script:Email        = if($jsonKey.Email) { $jsonKey.Email } else { throw [System.Exception] "attribute=Email" }
			$Script:PasswordFile = if($jsonKey.PasswordFile) { $jsonKey.PasswordFile } else { throw [System.Exception] "attribute=PasswordFile" }
			Write-Custom "💡 Using ${Script:TypeName} server: ${Script:Url}" -ForegroundColor Gray
		} catch {
			Write-Custom -Err "🐞 Missing required configuration for $($Script:TypeName) server: $_"
			Exit-Script
		}
	}
	catch [System.Management.Automation.ItemNotFoundException] {
		Write-Custom -Err "🐞 Configuration file not found for $($Script:TypeName) server: $Config"
		Exit-Script
	}
	catch [System.Management.Automation.RuntimeException] {
		Write-Custom -Err "🐞 Error reading configuration file for $($Script:TypeName) server: $_"
		Exit-Script
	}
	catch {
		Write-Custom -Err "🐞 Unknown error when reading configuration file for $($Script:TypeName) server: $_"
		Exit-Script
	}

	$waitTimeout = 15
	$waitSeconds = 0
	while (-not (Test-Server)) {
		# Server is not responding to health check
		Write-Custom "⏳ Waiting for $($Script:TypeName) server to start for ${waitSeconds}s. Pausing for ${waitTimeout}s..." -ForegroundColor Red
		$waitSeconds += $waitTimeout
		Start-Sleep -Seconds $waitTimeout
	}
	
	$waitTimeout = 60
	$waitSeconds = 0
	while (-not (Connect-Server)) {
		# Server is not responding to health check
		Write-Custom "⏳ Waiting for ${Script:TypeName} server to connect for ${waitSeconds}s. Pausing for ${waitTimeout}s..." -ForegroundColor Red
		$waitSeconds += $waitTimeout
		Start-Sleep -Seconds $waitTimeout
	}
}

function Invoke-UserSync {
	Initialize-Library | Out-Null

	# Find existing users
	$localUsers = Get-LocalUsers
	# Get users from external
	$externalUsers = Get-ExternalUsers
	# Parse new users
	$newUsers = $externalUsers | Where-Object {
		-not ($_.username -in $localUsers.results."$(${Script:External}.toLower())Username")
	}
	# If there are new users
	if($newUsers.Count){
		# Import users into Jellyseerr
		$importedUsers = Import-ExternalUser -ExternalIds $newUsers.id
		# Reset all passwords to the global key for auto-login
		$importedUsers | ForEach-Object {
			$user = $_
			Reset-Password -UserId $user.id | Out-Null
		}
	}
}

Invoke-UserSync

Exit-Script
