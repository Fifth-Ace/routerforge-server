# RouterForge Server P1 — first publication, PowerShell 5.1 compatible.
# Only creates Fifth-Ace/routerforge-server and commits to main/dev. No VPS action.
$ErrorActionPreference = 'Stop'

function Invoke-Native {
    param(
        [Parameter(Mandatory=$true)][string]$Executable,
        [Parameter(Mandatory=$true)][string[]]$Arguments
    )
    & $Executable @Arguments
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw ('NATIVE_COMMAND_FAILED: {0} {1} / EXIT={2}' -f $Executable, ($Arguments -join ' '), $exitCode)
    }
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = 'Fifth-Ace/routerforge-server'
Write-Host '=== PRECHECK / READ ONLY ==='
foreach ($cmd in @('gh', 'git')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "MISSING_COMMAND: $cmd" }
}
Invoke-Native -Executable 'gh' -Arguments @('--version')
Invoke-Native -Executable 'git' -Arguments @('--version')
Invoke-Native -Executable 'gh' -Arguments @('auth', 'status')
$login = (& gh api user --jq '.login').Trim()
if ($LASTEXITCODE -ne 0 -or $login -ne 'Fifth-Ace') { throw "WRONG_GITHUB_LOGIN: $login" }
$email = (& git config --global --get user.email).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($email)) { throw 'MISSING_GIT_USER_EMAIL' }
$required = @('manager.sh','install.sh','README.md','CHANGELOG.md','tests/test.sh','.github/workflows/verify.yml')
foreach ($f in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $f) -PathType Leaf)) { throw "SOURCE_MISSING: $f" }
}
if (Test-Path -LiteralPath (Join-Path $root '.git')) { throw 'LOCAL_GIT_EXISTS: use fresh extraction' }
# gh repo create itself rejects an existing name; do not overwrite or amend anything.
Write-Host 'GATE: PASS / CORRECT ACCOUNT / NEW TARGET / FILES READY'

Write-Host '=== ACTION / CREATE NEW REPOSITORY ==='
Invoke-Native -Executable 'gh' -Arguments @('repo','create',$repo,'--public','--description','RouterForge Server - Linux VPS manager')
Set-Location -LiteralPath $root
Write-Host '=== ACTION / MAIN INITIALIZATION ==='
Invoke-Native -Executable 'git' -Arguments @('init','-b','main')
Invoke-Native -Executable 'git' -Arguments @('config','user.name','Fifth-Ace')
Invoke-Native -Executable 'git' -Arguments @('config','user.email',$email)
'# RouterForge Server' | Set-Content -LiteralPath (Join-Path $root 'REPOSITORY.md') -Encoding UTF8
Invoke-Native -Executable 'git' -Arguments @('add','REPOSITORY.md')
Invoke-Native -Executable 'git' -Arguments @('commit','-m','chore: initialize RouterForge Server repository')
Invoke-Native -Executable 'git' -Arguments @('remote','add','origin','https://github.com/Fifth-Ace/routerforge-server.git')
Invoke-Native -Executable 'git' -Arguments @('push','-u','origin','main')
Write-Host '=== ACTION / DEV INITIAL IMPLEMENTATION ==='
Invoke-Native -Executable 'git' -Arguments @('checkout','-b','dev')
Invoke-Native -Executable 'git' -Arguments @('add','--all')
Invoke-Native -Executable 'git' -Arguments @('commit','-m','feat: initial RouterForge Server CLI')
Invoke-Native -Executable 'git' -Arguments @('push','-u','origin','dev')
Write-Host '=== VERIFY ==='
Invoke-Native -Executable 'gh' -Arguments @('repo','view',$repo,'--json','name,visibility,defaultBranchRef','--jq','{name:.name,visibility:.visibility,defaultBranch:.defaultBranchRef.name}')
Invoke-Native -Executable 'git' -Arguments @('log','-1','--format=%H')
Write-Host '=== RESULT ==='
Write-Host 'STATE: PASS / P1 DEV PUBLISHED'
Write-Host 'MAIN: INITIAL STUB / DEV: INITIAL CLI'
Write-Host 'ROUTERFORGE CORE / PORTAL / VPS: UNTOUCHED'
