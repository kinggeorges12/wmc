<#
.SYNOPSIS
	Creates a hardlinked copy of a media library.

.DESCRIPTION
	Synchronizes files by creating hardlinks from the Library to the Sync directory. The purpose is to provide a set of files for organizing with Arr-type apps. Also contains functionality to prevent multiple instances of this script.

.PARAMETER Source
	The full filepath of the original library files.

.PARAMETER Destination
	The full filepath where the source files will be synced.

.PARAMETER Sync
	The relative filepath of a directory within the destination to sync files.

.PARAMETER Filter
	The relative filepath of a single folder or file in the source directory to process.

.PARAMETER NonInteractive
	Non-interactive mode does not pause or wait for input of parameters. Non-interactive mode does not print to console using Write-Host, which avoids conflicts with return statements in nested PowerShell scripts.

.PARAMETER WhatIf
	Executes the script in dry-run mode without making changes.

.PARAMETER Log
	Log all output for debugging. Enabling this option will significantly increase execution time.

.EXAMPLE
	&"C:\Tasks\library-sync.ps1" -Source "E:\Downloads\Library" -Destination "E:\Downloads\Sync" -Sync "~" -WhatIf

	Test run of the script without syncing or deleting any files. Returns the directory that was synced.
#>
param (
	[string]$Source,
	[string]$Destination,
	[string]$Sync,
	[string]$Filter,
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

function Wait-ForKeyPress {
	param (
		[int]$Timeout = 10
	)
	Write-Custom "Press any key to enter interactive mode (timeout in $Timeout seconds)..."
	for ($i = $Timeout; $i -ge 0; $i--) {
		if ([System.Console]::KeyAvailable) {
			$null = [System.Console]::ReadKey($true)
			Write-Custom "`nKey pressed. Continuing in interactive mode."
			return $true
		}
		# Update countdown display
		Write-Custom "`rWaiting: $i seconds... " -NoNewline
		Start-Sleep -Seconds 1
	}
	Write-Custom "`nNo key pressed within timeout. Continuing in non-interactive mode."
	return $false
}

# Bypasses certain user inputs and waits
function Test-Interactive {
	if((-not $NonInteractive) -and ($null -eq $Script:IsInteractive)){
		$Script:IsInteractive = Wait-ForKeyPress
	}
	return (-not $NonInteractive) -and $Script:IsInteractive
}

# Tests for interactivity before pausing
function Suspend-Interactive {
	if (Test-Interactive) {
		Pause
	}
}

# Unlock the sync process and exit
function Exit-Script {
	param (
		[int]$Value = 0
	)
	Unlock-Script
	Suspend-Interactive
	Write-Custom "👋 Exiting script..." -ForegroundColor Cyan
	exit $Value
}

# Unlock the sync process and return a value
function Exit-Return {
	param (
		$Value
	)
	Unlock-Script
	Suspend-Interactive
	Write-Custom "👋 Exiting script..." -ForegroundColor Cyan
	$Value | Write-Output
	exit ($Value ? 0 : -1)
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
	Write-Custom "This script requires PowerShell 7 or later. Please upgrade your PowerShell version." -Error
	Exit-Script 1
}

<#############################################################################################################

Setup Paths

##############################################################################################################>

# Prompt user for options with defaults
$defaultSource = "E:\Downloads\Library"
$defaultDestination = "E:\Downloads\Sync"
$defaultSync = "~"

# If no other keys are set, check for what-if
if (-not $Source -and -not $Destination -and -not $Sync -and -not $PSBoundParameters.ContainsKey('WhatIf')) {
	if (Test-Interactive) {
		$WhatIf_Response = Read-Host "Run in WhatIf mode? [y/N]"
	}
	if (-not ([string]::IsNullOrWhiteSpace($WhatIf_Response) -or $WhatIf_Response -match "^[Nn]")) {
		$WhatIf = $true
	}
}

if (-not $Source) {
	if (Test-Interactive) {
		$Source = Read-Host "Enter source path [$defaultSource]"
	}
	if ([string]::IsNullOrWhiteSpace($Source)) { $Source = $defaultSource }
}

if (-not $Destination) {
	if (Test-Interactive) {
		$Destination = Read-Host "Enter destination path [$defaultDestination]"
	}
	if ([string]::IsNullOrWhiteSpace($Destination)) { $Destination = $defaultDestination }
}

if (-not $Sync) {
	if (Test-Interactive) {
		$Sync = Read-Host "Enter sync folder within the destination path (or '/' to use the destination path) [$defaultSync]"
	}
	if ([string]::IsNullOrWhiteSpace($Sync)) { $Sync = $defaultSync }
}

# Check if source folder exists
if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
	Write-Custom "❌ Source folder does not exist: $Source" -ForegroundColor Red
	Exit-Script 1
}

# Resolve full, normalized paths for comparison
$resolvedSource = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
$resolvedDestination = (Resolve-Path -LiteralPath $Destination -ErrorAction SilentlyContinue)?.Path.TrimEnd('\')
# Check if source and destination are the same path
if ($resolvedSource -ieq $resolvedDestination) {
	Write-Custom "❌ Source and destination paths are the same. This will cause a loop or overwrite!" -ForegroundColor Red
	Exit-Script 1
}

# Check if source and destination are on the same drive
$sourceDrive = ([System.IO.Path]::GetPathRoot($Source)).TrimEnd('\')
$destDrive = ([System.IO.Path]::GetPathRoot($Destination)).TrimEnd('\')

if ($sourceDrive -ne $destDrive) {
	Write-Custom "❌ Source and Destination must be on the same drive to create hard links." -ForegroundColor Red
	Write-Custom "Source drive: $sourceDrive" -ForegroundColor Yellow
	Write-Custom "Destination drive: $destDrive" -ForegroundColor Yellow
	Exit-Script 1
}

# Normalize and resolve paths
$Source = (Resolve-Path $Source).Path.TrimEnd('\')
$DestinationPath = Resolve-Path $Destination -ErrorAction SilentlyContinue

if (-not $DestinationPath) {
	if ($WhatIf) {
		New-Item -ItemType Directory -Path $Destination -WhatIf
		Write-Custom "📂 Would create directory: $Destination" -ForegroundColor Cyan
	} else {
		New-Item -ItemType Directory -Path $Destination | Out-Null
		Write-Custom "📁 Created directory: $Destination" -ForegroundColor Cyan
	}
}

$DestinationPath = (Resolve-Path $Destination).Path.TrimEnd('\')
$SyncPath = Join-Path -Path $DestinationPath -ChildPath $Sync
Write-Custom "📁 Using sync path: $SyncPath" -ForegroundColor Cyan

<#############################################################################################################

Helper functions

##############################################################################################################>

function Limit-PathToMaxLength {
	param (
		[string]$FullPath,
		[int]$MaxPathLength = 259, # Windows must have a hidden character or something to not allow 260 character paths
		[int]$MinFileLength = 16
	)
	if ($FullPath.Length -le $MaxPathLength) {
		return $FullPath
	}
	$directory = Split-Path $FullPath
	$fileName = [IO.Path]::GetFileNameWithoutExtension($FullPath)
	$extension = [IO.Path]::GetExtension($FullPath)
	# Calculate max length allowed for filename (including tilde and extension)
	$maxFileNameLength = $MaxPathLength - $directory.Length - 1 # minus 1 for the path separator
	# Adjust for extension and tilde
	$maxFileNameLength = $maxFileNameLength - $extension.Length - 1 # minus 1 for tilde
	# If the filename length is less than the min length. Caveat if the min length is greater than the actual filename, use half the original filename length as the min length.
	if (($maxFileNameLength -le $MinFileLength) -or (($MinFileLength -ge $fileName.Length) -and ($maxFileNameLength -le [math]::Floor($fileName.Length / 2)))) {
		throw "Path too long, cannot truncate filename enough"
	}
	# Truncate filename and add tilde
	$truncatedFileName = $fileName.Substring(0, $maxFileNameLength) + "~"
	# Rebuild path
	$newPath = Join-Path -Path $directory -ChildPath ($truncatedFileName + $extension)
	return $newPath
}

function Remove-ToRecycleBin {
	param (
		[string]$File
	)
	if (-not ("RecycleBinHelper" -as [type])) {
		Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class RecycleBinHelper {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SHFILEOPSTRUCT {
        public IntPtr hwnd;
        public uint wFunc;
        public string pFrom;
        public string pTo;
        public ushort fFlags;
        [MarshalAs(UnmanagedType.Bool)]
        public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        public string lpszProgressTitle;
    }

    private const uint FO_DELETE = 3;
    private const ushort FOF_ALLOWUNDO = 0x0040;       // Send to Recycle Bin
    private const ushort FOF_NOCONFIRMATION = 0x0010;  // No "Are you sure?" prompt
    private const ushort FOF_NOERRORUI = 0x0400;       // Suppress error dialogs
    private const ushort FOF_SILENT = 0x0004;          // No progress UI

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SHFileOperation(ref SHFILEOPSTRUCT lpFileOp);

    public static bool MoveToRecycleBin(string path) {
        if (string.IsNullOrWhiteSpace(path))
            return false;

        SHFILEOPSTRUCT fileOp = new SHFILEOPSTRUCT();
        fileOp.wFunc = FO_DELETE;
        fileOp.pFrom = path + '\0' + '\0';  // double null-terminated string
        fileOp.fFlags = (ushort)(FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_NOERRORUI | FOF_SILENT);

        int result = SHFileOperation(ref fileOp);
        return result == 0 && !fileOp.fAnyOperationsAborted;
    }
}
"@
	}

	# Shell for interactive mode
	$shell = New-Object -ComObject Shell.Application
	try {
		if ($WhatIf) {
			Write-Custom "🗑️ Would send file to Recycle Bin: $File" -ForegroundColor DarkRed
		} else {
			if (Test-Interactive) {
				Write-Custom "🗑️ Sent file to Recycle Bin (Shell): $File" -ForegroundColor DarkRed
				$fileFolder = Split-Path $File
				$filename = Split-Path $File -Leaf
				$directory = $shell.Namespace($fileFolder)
				$item = $directory.ParseName($filename)
				$item.InvokeVerb("delete")
			} else {
				Write-Custom "🗑 Sent️ file to Recycle Bin (RecycleBinHelper): $File" -ForegroundColor DarkRed
				[RecycleBinHelper]::MoveToRecycleBin($File) | Write-Output
			}
		}
	} catch {
		Write-Custom "❌ Failed to delete: $File" -ForegroundColor Red
		return $false
	}
	return $true
}

function Get-HardLinks {
	param(
		[Parameter(Mandatory=$true)]
		[string]$FilePath,

		[bool]$ReturnEmptyListIfOnlyOne = $false
	)

	# A unique handle is possible, but the [HardLinkHelper] handle must be called in subsequent PowerShell commands, complicating things
	if (-not ("HardLinkHelper" -as [type])) {
		Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class HardLinkHelper {
	public static readonly IntPtr INVALID_HANDLE_VALUE = new IntPtr(-1);

	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern IntPtr FindFirstFileNameW(
		string lpFileName,
		uint dwFlags,
		ref uint StringLength,
		[Out] char[] LinkName
	);

	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	public static extern bool FindNextFileNameW(
		IntPtr hFindStream,
		ref uint StringLength,
		[Out] char[] LinkName
	);

	[DllImport("kernel32.dll", SetLastError = true)]
	public static extern bool FindClose(IntPtr hFindFile);
}
"@
	}

	# Prepare input path with \\?\ prefix to support long paths
	$longPath = if ($FilePath.StartsWith("\\\\?\\")) { $FilePath } else { "\\?\$FilePath" }

	$bufferSize = 1024
	$charBuffer = New-Object Char[] $bufferSize
	$len = [uint32]$bufferSize

	# Get first hardlink name (relative path from root of volume)
	$handle = [HardLinkHelper]::FindFirstFileNameW($longPath, 0, [ref]$len, $charBuffer)
	if ($handle -eq [HardLinkHelper]::INVALID_HANDLE_VALUE -or $handle -eq [IntPtr]::Zero) {
		$err = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
		Write-Custom "Could not retrieve hard links. Error code: $err" -Error
		return @()
	}

	$results = @()
	$results += -join ($charBuffer[0..($len - 1)])

	# Loop to get remaining hardlinks
	$len = [uint32]$bufferSize
	while ([HardLinkHelper]::FindNextFileNameW($handle, [ref]$len, $charBuffer)) {
		$results += -join ($charBuffer[0..($len - 1)])
		$len = [uint32]$bufferSize
		$charBuffer = New-Object Char[] $bufferSize
	}

	[HardLinkHelper]::FindClose($handle) | Out-Null

	# Get drive root like "E:"
	$driveRoot = ([System.IO.Path]::GetPathRoot($FilePath)).TrimEnd('\')

	# Combine drive root with the relative hardlink names for absolute paths
	$fullPaths = $results | ForEach-Object {
		$driveRoot + $_  # $_ starts with a backslash, e.g. "\path\to\file.ext"
	}

	if ($ReturnEmptyListIfOnlyOne -and $fullPaths.Count -lt 2) {
		return @()
	}

	return $fullPaths
}

<#############################################################################################################

Syncing files

##############################################################################################################>

# Scan only a single file or folder if specified
if($Filter){
	$searchFolder = Join-Path $Source $Filter
} else {
	$searchFolder = $Source
}
# Recursively process files
$processed = Get-ChildItem -LiteralPath $searchFolder -Recurse -File | ForEach-Object {
	$sourcePath = $_.FullName
	$sourceDir = Split-Path -LiteralPath $sourcePath
	$sourceName = [System.IO.Path]::GetFileName($sourcePath)
	Write-Custom "📂 Working on sourcePath: $sourcePath" -ForegroundColor Cyan
	Write-Custom "📂 Working on sourceDir: $sourceDir" -ForegroundColor Cyan

	$relPath = $sourcePath.Substring($Source.Length).TrimStart('\')
	# Split relative path into directories and check for any that start with a dot
	if ($relPath -match '^\.') {
		Write-Custom "🚫 Skipping hidden/system folder: $relPath" -ForegroundColor Gray
		return
	}

	# Get the parent folder representing the category in qbit
	$relParent = (Split-Path -Path $relPath -Parent)
	# Detect if the file is naked in Library\Movies or Library\TV or Library\TV+Movie
	if ($relParent -match "^(Movies|TV|TV\+Movie)$") {
		$nakedDir = [System.IO.Path]::GetFileNameWithoutExtension($sourceName)
		# Move the file into a folder named after itself
		$relPath = Join-Path -Path $relParent -ChildPath (Join-Path -Path $nakedDir -ChildPath $sourceName)
		Write-Custom "📂 Moving naked file to directory: $nakedDir" -ForegroundColor Yellow
	} else {
		Write-Custom "📂 Working on relPath: $relPath" -ForegroundColor Cyan
	}

	$newFilePath = Join-Path -Path $SyncPath -ChildPath $relPath
	$newFilePath = Limit-PathToMaxLength -FullPath $newFilePath
	$newFileDir = Split-Path -LiteralPath $newFilePath
	$fileName = [System.IO.Path]::GetFileName($newFilePath)
	Write-Custom "📂 Working on newFilePath: $newFilePath" -ForegroundColor Cyan
	Write-Custom "📂 Working on newFileDir: $newFileDir" -ForegroundColor Cyan
	Write-Custom "📂 Working on fileName: $fileName" -ForegroundColor Cyan

	# Expect relPath like: TV\Show Folder\episode.mkv
	$relPathParts = $relPath -split '\\'
	# Construct top-level sync folder path
	$newFileBaseDir = Join-Path -Path $SyncPath -ChildPath (Join-Path $relPathParts[0] $relPathParts[1])
	if ((Get-Item -LiteralPath $sourcePath).LinkType -eq 'HardLink') {
		# Get all hardlink paths
		$sourceHardLinks = Get-HardLinks $sourcePath
		# Filter out links in $RECYCLE.BIN or .Trash-0
		$validHardLinks = $sourceHardLinks | Where-Object { $_ -notmatch '\\\$RECYCLE\.BIN\\' -and $_ -notmatch '\\.Trash-0\\' }
		if ($validHardLinks.Count -gt 1) {
			Write-Custom "🚫 Skipping already hardlinked file: $sourcePath" -ForegroundColor Gray
			return
		} else {
			Write-Custom "⏩ Continuing since all hardlinks are in the trash: $sourcePath" -ForegroundColor Gray
		}
	}

	if (-not (Test-Path -LiteralPath $newFileDir)) {
		if ($WhatIf) {
			$null = New-Item -ItemType Directory -Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($newFileDir) -Force -ErrorAction Stop -WhatIf
			Write-Custom "📂 Would create directory: $newFileDir" -ForegroundColor Cyan
		} else {
			$null = New-Item -ItemType Directory -Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($newFileDir) -Force -ErrorAction Stop | Out-Null
			Write-Custom "📁 Created directory: $newFileDir" -ForegroundColor Cyan
		}
	}

	if (-not (Test-Path -LiteralPath $newFilePath)) {
		if ($WhatIf) {
			$null = Push-Location -LiteralPath $sourceDir
			try {
				Write-Custom "🔗 Would hardlink: $relPath" -ForegroundColor Gray
				$null = New-Item -ItemType HardLink -Path $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($newFileDir) -Name "${fileName}" -Target $(Get-Item -LiteralPath $sourcePath) -ErrorAction Stop -WhatIf
			} catch {
				Write-Custom "🔗 Would hardlink (cmd): $relPath" -ForegroundColor Magenta
			}
			finally {
				$null = Pop-Location
			}
		} else {
			$null = Push-Location -LiteralPath $sourceDir
			try {
				Write-Custom "✅ Hardlinked: $relPath" -ForegroundColor Green
				$null = New-Item -ItemType HardLink -Path $(Get-Item -LiteralPath $newFileDir) -Name "${fileName}" -Target $sourceName -ErrorAction Stop
			}
			finally {
				$null = Pop-Location
			}
			if (-not (Test-Path -LiteralPath $newFilePath)) {
				Write-Custom "🔗 Hardlinked (forced): $relPath" -ForegroundColor Magenta
				$null = cmd /v:off /c ("mklink /H `"" + $newFilePath + "`" `"" + $sourcePath + "`"")
				# fsutil just says path not found
				#Start-Process -FilePath "fsutil.exe" -ArgumentList "hardlink", "create", "`"$newFilePath`"", "`"$sourcePath`"" -NoNewWindow -Wait
			}
		}
	} else {
		Write-Custom "⚠️ Already exists: $relPath" -ForegroundColor Yellow
	}
	return @{
		sourcePath = $sourcePath
		sourceDir = $sourceDir
		sourceName = $sourceName
		relPath = $relPath
		relParent = $relParent
		nakedDir = $nakedDir
		newFilePath = $newFilePath
		newFileDir = $newFileDir
		fileName = $fileName
		newFileBaseDir = $newFileBaseDir
		validHardLinks = $validHardLinks
	}
}

<#############################################################################################################

Cleanup files

##############################################################################################################>

function Merge-Library {
	param (
		[string]$SearchPath
	)
	if(-not $SearchPath.StartsWith($DestinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
		Write-Custom -Error "Path being processed not found in Destination Path, exiting before something bad happens: $SearchPath"
	}
	$LibraryPath = (Resolve-Path $Source).Path.ToLowerInvariant()

	Write-Custom "SearchPath=$SearchPath"
	# Delete files not found in the Library. Sort any Sync files into extras folders
	Get-ChildItem -Path $SearchPath -Recurse -File | Where-Object {
		$ext = $_.Extension.ToLowerInvariant()
		$ext -notin @(".png", ".jpg", ".nfo")
	} | ForEach-Object {
		$file = $_.FullName
		# Get all hardlink paths
		$hardlinks = Get-HardLinks $file

		$flagLibrary = $false
		$flagExtra = $false

		foreach ($link in $hardlinks) {
			$normalizedLink = $link.Trim().TrimEnd([char]0).Replace('/', '\').ToLowerInvariant()
			$normalizedLibrary = $LibraryPath.Trim().TrimEnd([char]0).Replace('/', '\').ToLowerInvariant()

			# Skip files that are found in the library
			if ($normalizedLink.StartsWith($normalizedLibrary) -and
				# Remove files in the qbit Trash folder
				(-not ($normalizedLink.StartsWith((Join-Path $normalizedLibrary ".Trash-0").ToLowerInvariant())))
			) {
				# Ensure file is in the SyncPath, which should be sorted for extras
				if (($file.StartsWith($SyncPath, [System.StringComparison]::OrdinalIgnoreCase)) -and
					# Ensure the synced file is NOT already in an extras folder
					$file -notmatch "\\extras\\" -and (
						# Look for subfolders in the Library Ensure the pattern matches:
						# $LibraryPath/1. Category (TV or Movies)/2. Download Folder/3. Folder(s)**/FileName.extension
						($normalizedLink -match [regex]::Escape($normalizedLibrary) + '(\\[^\\]+){3,}\\' -and (
							# Check for folder patterns in path
							$normalizedLink -match '\\special[^\\]*\\' -or
							$normalizedLink -match '\\[^\\]*specials\\' -or
							$normalizedLink -match '\\[^\\]+extras\\' -or
							$normalizedLink -match '\\extras[^\\]+\\' -or
							$normalizedLink -match '\\xtras\\' -or
							$normalizedLink -match '\\[^\\]*featurettes[^\\]*\\' )) -or
						# Check for file patterns in path
						($normalizedLink -match '\\[^\\]*sample\.[^\\.]+$' -or
						$normalizedLink -match '\\rarbg\.com\.mp4$' -or
						$normalizedLink -match '\\etrg\.mp4$')
					)
				) {
					$flagExtra = $true
				}
				$flagLibrary = $true
				break
			}
		}

		# Flag for delete if this is not in the library
		if ((-not $flagLibrary)) {
			Write-Custom "🗑️ Removing file not found in library: $file" -ForegroundColor DarkYellow
			Remove-ToRecycleBin -File $file | Out-Null
		} elseif ($flagExtra) {
			# Compute base path (e.g., series folder) and target Extras folder
			$basePath = (Get-Item -LiteralPath $file).Directory.FullName
			$extrasPath = Join-Path $basePath 'Extras'
			$extrasFile = Join-Path $extrasPath (Split-Path $file -Leaf)
			Write-Custom "⌛ Moving this file: $file" -ForegroundColor DarkYellow
			if ($WhatIf) {
				Write-Custom "🚚️ Would move file to Extras folder: $extrasFile" -ForegroundColor Yellow
			} else {
				Write-Custom "🚚 Moved file to Extras folder: $extrasFile" -ForegroundColor Yellow
				if (-not (Test-Path -LiteralPath $extrasPath)) {
					New-Item -ItemType Directory -Path $extrasPath | Out-Null
				}
				Move-Item -LiteralPath $file -Destination $extrasFile -Force
			}
		}
		return @{
			file = $file
		}
	} | Out-Null
}

# If filtered, only Merge-Library for processed files.
if ($Filter) {
	Write-Custom "✅ Folder scan complete." -ForegroundColor Green
	@($processed) | ForEach-Object { Merge-Library -SearchPath $_.newFileDir }
	Exit-Return (@($processed.newFileDir) | Select-Object -First 1)
} else {
	Write-Output "🗑️ Would send file to Recycle Bin"
	# Empty all Trash folders into Recycle Bin
	@(
		"D:\Docker\qBittorrent\Temp\.Trash-0\files",
		"D:\Docker\qBittorrent\Temp\.Trash-0\info",
		"D:\Docker\qBittorrent\Incomplete\.Trash-0\files",
		"D:\Docker\qBittorrent\Incomplete\.Trash-0\info",
		"E:\Downloads\Library\.Trash-0\files",
		"E:\Downloads\Library\.Trash-0\info",
		"E:\Downloads\.Trash-0\Radarr",
		"E:\Downloads\.Trash-0\Sonarr"
	) | ForEach-Object {
		$trashFolder = $_
		Write-Custom "🗑️ Emptying recycling bin: $trashFolder" -ForegroundColor DarkYellow
		Get-ChildItem -LiteralPath $trashFolder -Force -ErrorAction Stop | ForEach-Object {
			Remove-ToRecycleBin -File $_.FullName
		}
	} | Out-Null

	# Do complete Merge-Library on Destination
	Merge-Library -SearchPath $DestinationPath
}

Exit-Script
