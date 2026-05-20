# escape=`
ARG WINDOWS_BASE=mcr.microsoft.com/windows/servercore:ltsc2022
FROM ${WINDOWS_BASE}

SHELL ["powershell", "-NoLogo", "-ExecutionPolicy", "Bypass", "-Command"]

RUN New-Item -ItemType Directory -Path C:\WazuhLocal -Force | Out-Null
COPY entrypoint.ps1 C:\WazuhLocal\entrypoint.ps1

ENTRYPOINT ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-File", "C:\\WazuhLocal\\entrypoint.ps1"]
