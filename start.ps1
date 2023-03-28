Write-Host "1. Determining matching Azure Pipelines agent..." -ForegroundColor Cyan
if (-not (Test-Path Env:AZP_URL)) {
    Write-Error "error: missing AZP_URL environment variable"
    exit 1
}
  
if (-not (Test-Path Env:AZP_TOKEN_FILE)) {
  if (-not (Test-Path Env:AZP_TOKEN)) {
    Write-Error "error: missing AZP_TOKEN environment variable"
    exit 1
  }
    
  $Env:AZP_TOKEN_FILE = "\azp\.token"
  $Env:AZP_TOKEN | Out-File -FilePath $Env:AZP_TOKEN_FILE
}
  
Remove-Item Env:AZP_TOKEN
  
if ((Test-Path Env:AZP_WORK) -and -not (Test-Path $Env:AZP_WORK)) {
  New-Item $Env:AZP_WORK -ItemType directory | Out-Null
}

if(-not(Test-Path -Path "\azp\agent" -ErrorAction Ignore)) {
  New-Item "\azp\agent" -ItemType directory | Out-Null
}

# Let the agent ignore the token env variables
$Env:VSO_AGENT_IGNORE = "AZP_TOKEN,AZP_TOKEN_FILE"

Write-Host "Setting path to azp\agent`n"
Set-Location agent | Out-Null

Write-Host "2. Getting Agent installation files..." -ForegroundColor Cyan
if(Test-Path -Path "\azp\agent" -ErrorAction Ignore) {
  Write-Host "   Agent installation files already found."
}
else {
  if((Test-Path -Path "c:\temp\agent.zip") -match "False"){
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$(Get-Content ${Env:AZP_TOKEN_FILE})"))
    $package = Invoke-RestMethod -Headers @{Authorization=("Basic $base64AuthInfo")} "$(${Env:AZP_URL})/_apis/distributedtask/packages/agent?platform=win-x64&`$top=1"
    $packageUrl = $package[0].Value.downloadUrl
    
    Write-Host $packageUrl
    Write-Host "   Downloading and installing Azure Pipelines agent..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($packageUrl, "$(Get-Location)\agent.zip")
    Expand-Archive -Path "agent.zip" -DestinationPath "\azp\agent"
  }
  else{
    Write-Host "   Expanding Azure Pipelines agent..."
    Expand-Archive -Path "c:\temp\agent.zip" -DestinationPath "\azp\agent"
  }
}

try {
  Write-Host "3. Configuring Azure Pipelines agent..." -ForegroundColor Cyan
  $agent = "$(if (Test-Path Env:AZP_AGENT_NAME) { ${Env:AZP_AGENT_NAME} } else { hostname })"
  $url   = "$(${Env:AZP_URL})"
  $token = "$(Get-Content ${Env:AZP_TOKEN_FILE})"
  $pool  = "$(if (Test-Path Env:AZP_POOL) { ${Env:AZP_POOL} } else { 'Default' })"
  $work  = "$(if (Test-Path Env:AZP_WORK) { ${Env:AZP_WORK} } else { '_work' })"
  Write-Host "   .\config.cmd --unattended --agent `"$agent`" --url `"$url`" --auth PAT --pool `"$pool`" --work `"$work`" --replace --token `"`$token`""
  .\config.cmd --unattended --agent "$agent" --url "$url" --auth PAT --pool "$pool" --work "$work" --replace --token "$token"

  Write-Host "4. Running Azure Pipelines agent..." -ForegroundColor Cyan
  .\run.cmd
}
finally {
  Write-Host "5. Cleanup. Removing Azure Pipelines agent..." -ForegroundColor Cyan

  $token = "$(Get-Content ${Env:AZP_TOKEN_FILE})"
  Write-Host "   .\config.cmd remove --unattended --auth PAT --token `"`$token`""
  .\config.cmd remove --unattended --auth PAT --token `"$token`"

  #C:\azp\agent\_diag\Agent_20221007-182919-utc.log
  $logFile = Get-ChildItem -Path "\azp\agent\_diag\Agent*.log" | Sort-Object LastWriteTime | Select-Object -Last 1
  if($null -ne $logFile) {
    Write-Host "`n$($logFile.FullName):" -ForegroundColor Cyan
    Write-Host "".PadRight(80,'=')
    Write-Host (Get-Content -Path $logFile.FullName -Raw)
    Write-Host "".PadRight(80,'=')
  }
}