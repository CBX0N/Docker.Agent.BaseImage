# CBXON (On-Premise) Agent Docker Base Image
# For creating multiple containerised on-prem build agents for Azure DevOps pipelines.
FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS base
WORKDIR /temp
COPY agent.zip .
RUN powershell -Command "Expand-Archive -Path 'agent.zip' -DestinationPath 'c:\azp\agent'"
WORKDIR /azp
COPY start.ps1 /azp/start.ps1
COPY test.ps1 /azp/test.ps1

FROM mcr.microsoft.com/windows/servercore:ltsc2019 AS packages
ARG PAT
ENV Auth_Token $PAT
ENV Repository_Name 'CBXON'
ENV Repository_Url 'https://pkgs.dev.azure.com/cbxon/_packaging/CBXON/nuget/v2/'

RUN powershell -Command "Install-PackageProvider -Name NuGet -force | Out-Null"

RUN powershell -Command "$credential = New-Object System.Management.Automation.PSCredential($Env:Auth_Token, ($Env:Auth_Token | ConvertTo-SecureString -AsPlainText -Force))"; \
                        "Unregister-PSRepository -Name $Env:Repository_Name -ErrorAction SilentlyContinue"; \
                        "Register-PSRepository -Name $Env:Repository_Name -SourceLocation $Env:Repository_Url -InstallationPolicy Trusted -Credential $credential -ErrorAction SilentlyContinue"

RUN powershell -Command "$credential = New-Object System.Management.Automation.PSCredential($Env:Auth_Token, ($Env:Auth_Token | ConvertTo-SecureString -AsPlainText -Force))"; \
                        "Register-PackageSource -Name 'CBXON' -Location $Env:Repository_Url -ProviderName NuGet -Credential $credential -Trusted"; \
                        "Install-Package CBXON.Reporting.Services -RequiredVersion 1.0.31 -Source 'CBXON' -ProviderName NuGet -Credential $credential | Out-Null"; \
                        "Install-Module -Name PowershellGet -Repository $Env:Repository_Name -AllowClobber -Credential $credential -force -WarningAction SilentlyContinue | Out-Null"; \
                        "Install-Module -Name dbatools -Repository $Env:Repository_Name -AllowClobber -Credential $credential -WarningAction SilentlyContinue | Out-Null"; \
                        "Install-Module -Name CBXON.Deployment.Utilities -Repository $Env:Repository_Name -AllowClobber -Credential $credential -WarningAction SilentlyContinue | Out-Null"

FROM mcr.microsoft.com/windows/servercore:ltsc2019
LABEL maintainer "CBXON"

COPY --from=base /azp /azp
COPY --from=packages ["/Program Files/WindowsPowerShell/Modules/", "/PackagesTemp"]

RUN powershell -Command "(Get-ChildItem C:\PackagesTemp\| get-childitem).fullname | ForEach { $path = $_ ; $splitpath = $path.split('\'); $package = $splitpath[2]; \
                        $version = $splitpath[3]; $dest = Join-Path 'C:\Program Files\WindowsPowerShell\Modules\' -ChildPath $package | join-path -ChildPath $version; \
                        Copy-Item -recurse -Path $path -Destination $dest }"

RUN powershell -Command "Remove-item -recurse -force 'C:\PackagesTemp\'"

WORKDIR /azp
ENV PATH="C:\azp\agent\externals\git\cmd;C:\azp\agent\externals\git\mingw64\bin;C:\Windows\system32;C:\Windows;C:\Windows\System32\Wbem;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Windows\System32\OpenSSH\;C:\Users\ContainerAdministrator\AppData\Local\Microsoft\WindowsApps;C:\Windows\System32\OpenSSH\;C:\azp\agent\externals\nuget"
CMD powershell .\start.ps1