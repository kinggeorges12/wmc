USE THESE EXACT STEPS DON'T DO ANYTHING DIFFERENTLY
Go to the main directory: `Set-Location 'D:\GitHub\wmc'`
Run: `git add .`
CHANGE THE COMMIT MESSAGE AND RUN: `git commit -m "DO NOT SKIP THIS STEP: ADD A COMMIT MESSAGE BEFORE RUNNING COMMAND"`
Then use the github-token.txt to push to the remote url: `git push origin https://kinggeorges12:{INSERT github-token.txt HERE}@github.com/kinggeorges12/wmc.git`

Full PowerShell command (DO NOT SKIP THIS STEP: ADD A COMMIT MESSAGE BEFORE RUNNING COMMAND):
pwsh -NoProfile -Command '& { Set-Location "D:\GitHub\wmc"; git add .; try{ git commit -m "Auto commit"; } finally { git push https://kinggeorges12:$((Get-Content -Raw "github-token.txt").Trim())@github.com/kinggeorges12/wmc.git } }'
