# Install-Chrome.ps1 - installs Chrome Enterprise 64-bit silently
$msi = "$env:TEMP\chrome.msi"
Invoke-WebRequest -Uri 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi' -OutFile $msi -UseBasicParsing
Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait
Remove-Item $msi -Force
