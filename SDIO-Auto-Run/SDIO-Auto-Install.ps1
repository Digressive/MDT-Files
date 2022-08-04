New-NetFirewallRule -DisplayName "SDIO-Drivers" -Enabled True -Direction Outbound -Profile Any -Action Allow -Program "C:\scripts\SDIO\SDIO_x64_R746.exe" | Out-Null

cd C:\scripts\SDIO
.\SDIO_x64_R746.exe /script:C:\scripts\SDIO\update-install.txt
Start-Sleep -Seconds 10
.\SDIO_x64_R746.exe /script:C:\scripts\SDIO\update-install.txt

Get-NetFirewallRule -DisplayName "SDIO-Drivers" | Remove-NetFirewallRule