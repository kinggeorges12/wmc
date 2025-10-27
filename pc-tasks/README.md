# PC Tasks

PowerShell scripts for media library management with hardlink synchronization and Arr app integration.

## File Structure

### PowerShell Scripts (`.ps1`)
- `library-watch.ps1` - File system watcher for the library directory
- `library-sync.ps1` - Creates hardlinked copies from library to sync directory
- `library-organize.ps1` - Imports media files into Sonarr/Radarr
- `library-users.ps1` - Syncs Jellyfin users to Jellyseerr for auto-login

### JSON Configuration Files
- `library-organize.json` - Radarr and Sonarr API keys
- `library-users.json` - Jellyseerr API configuration

### PC Task Scheduler XML Files
- `Library Watch.xml` - Starts file watcher on logon
- `Library Sync.xml` - Triggers sync when files are created
- `Library Organize.xml` - Runs import after sync completes
- `Library Users.xml` - Updates user passwords after organize

## Installation

### Prerequisites
- PowerShell 7+ (optional, supports PS 5.1)
- Admin rights for Task Scheduler

### Setup Steps

1. Copy all files to your scripts directory:
   ```powershell
   C:\Tasks\
   ```

2. Configure `library-organize.json`:
   - Get API keys from Radarr front-end (Settings > General > API Key) - [Radarr API docs](https://wiki.servarr.com/radarr/api)
   - Get API keys from Sonarr front-end (Settings > General > API Key) - [Sonarr API docs](https://wiki.servarr.com/sonarr/api)
   - Replace `***REMOVED: get this from [App] front-end***` placeholders

3. Configure `library-users.json`:
   - Set Email to admin email used for Jellyseerr API calls ([Jellyseerr documentation](https://docs.jellyseerr.dev/))
   - Update `PasswordFile` path if different from default
   - Make sure password file exists at specified path

4. Update script file paths in XML files:
   - Search for `C:\Tasks\` and replace with your actual script path
   - Update UserId fields (PC User GUID) in all XML files
   
   **To find your UserId (User GUID):**
   ```powershell
   # Run this in PowerShell to get your User SID
   (New-Object System.Security.Principal.WindowsIdentity([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)).User.Value
   ```
   Or alternatively:
   ```powershell
   ([System.Security.Principal.WindowsIdentity]::GetCurrent().User).Value
   ```
   Replace `<UserId>` in all XML files with the value returned by the above command.

5. Set PowerShell execution policy:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

6. Import XML files into Task Scheduler:
   ```powershell
   schtasks /create /xml "Library Watch.xml" /tn "Watch Library"
   schtasks /create /xml "Library Sync.xml" /tn "Library Sync"
   schtasks /create /xml "Library Organize.xml" /tn "Library Organize"
   schtasks /create /xml "Library Users.xml" /tn "Library Users"
   ```

## Manual Execution

Test scripts individually before scheduling:

```powershell
# Test file watcher
.\library-watch.ps1 -Source "E:\Downloads\Library"

# Test sync (dry run)
.\library-sync.ps1 -Source "E:\Downloads\Library" -Destination "E:\Downloads\Sync" -Sync "~" -WhatIf

# Test organize (dry run)
.\library-organize.ps1 -Sync "E:\Downloads\Sync\TV\Show\Season" -Windows "E:\Downloads\Sync" -WhatIf

# Test user sync
.\library-users.ps1 -Log
```

## Configuration Files

All config files contain placeholders in format `***REMOVED: instructions***` that must be replaced.

### library-organize.json
Placeholder fields:
- `ApiKey` - Get from Radarr front-end (Settings > General)
- `ApiKey` - Get from Sonarr front-end (Settings > General)

### library-users.json
Placeholder fields:
- `Email` - Admin email used in Jellyseerr API calls ([Jellyseerr documentation](https://docs.jellyseerr.dev/))
- `PasswordFile` - Path to password file (shared with nginx)

### XML Files (Task Scheduler)
Placeholder fields:
- `<UserId>` - Replace with your PC user GUID (SID)

## How It Works

1. `library-watch.ps1` monitors library directory for new files
2. When a file is created, it calls `library-sync.ps1` to hardlink to sync directory
3. After sync completes, `library-organize.ps1` imports files into Sonarr/Radarr
4. `library-users.ps1` updates user passwords for Jellyseerr auto-login

All scripts write logs to `$env:TEMP\` directory.

## Troubleshooting

### Scripts Won't Run

**Check execution policy:**
```powershell
Get-ExecutionPolicy
```
If needed, set to RemoteSigned (see Setup Step 5).

### Hardlink Failures

**Common causes:**
- **Paths don't exist**: Verify both Source and Destination directories exist
- **Drive mismatch**: Hardlinks only work on the same volume. Use same drive letter for both paths
- **Insufficient permissions**: Run PowerShell as Administrator
- **Reserved characters**: PC paths cannot contain `< > : " | ? *`

**Test manual hardlink:**
```powershell
New-Item -ItemType HardLink -Path "Destination\file.ext" -Target "Source\file.ext"
```

### Tasks Not Triggering

1. **Check Task Scheduler**: Open Task Scheduler and verify tasks exist
2. **Verify trigger conditions**: Check XML files for correct paths and UserId
3. **View task history**: In Task Scheduler, check Last Run Result
4. **Check logs**: Scripts log to `$env:TEMP\` with timestamps

### Import Failures in Sonarr/Radarr

1. **Verify API keys in `library-organize.json`**
2. **Check Sonarr/Radarr logs**: Dashboard → System → Logs
3. **Test API connection:**
   ```powershell
   $headers = @{'X-Api-Key' = 'YOUR_API_KEY'}
   Invoke-RestMethod -Uri 'http://localhost:8989/api/status' -Headers $headers
   ```

## Additional Resources

### PowerShell & PC
- [PowerShell documentation](https://docs.microsoft.com/en-us/powershell/)
- [PC Task Scheduler documentation](https://docs.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page)
- [PowerShell file system watcher](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/register-watcher)

### Media Management APIs
- [Radarr API documentation](https://wiki.servarr.com/radarr/api)
- [Radarr GitHub repository](https://github.com/Radarr/Radarr)
- [Sonarr API documentation](https://wiki.servarr.com/sonarr/api)
- [Sonarr GitHub repository](https://github.com/Sonarr/Sonarr)
- [Jellyseerr documentation](https://docs.jellyseerr.dev/)
- [Jellyseerr GitHub repository](https://github.com/Fallenbagel/jellyseerr)

### Hardlinks & PC File Systems
- [PC hard links and junctions](https://docs.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions)
- [New-Item PowerShell documentation](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-item)
