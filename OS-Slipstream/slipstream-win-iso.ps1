## 24-02-21
$HighComp = "disabled" ## enabled / disabled
$MakeIso = "disabled" ## enabled / disabled
$SetIndex = "3" ## Comment out if you dont know

## Directory Names
$IsoSrc = "Win-ISOs" #required.
$UpdatesSrc = "updates" #optional. if dir doesn't exist, updates don't get added.
$DriversSrc = "drivers" #optional if dir doesn't exist, drivers don't get added.

Write-Host -Object ""
Write-Host -Object ""
Write-Host -Object ""
Write-Host -Object ""

## Only used is makeISO is configured
If ($MakeIso -eq "enabled")
{
    $OSCLoc = "C:\scripts\Oscdimg" #C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg ##default location when ADK is installed
    If ((Test-Path -Path "$OSCLoc\oscdimg.exe") -eq $false)
    {
        Write-Host -Object " oscdimg.exe not found. I need it to make an iso file."
        exit
    }
}

If (Test-Path -Path "$PSScriptRoot\$IsoSrc")
{
    $GetIsos = Get-ChildItem -Path "$PSScriptRoot\$IsoSrc" -Filter "*.iso" -Recurse
    ForEach ($IsoFile in $GetIsos)
    {
        $IsoPath = $IsoFile.fullname
        $IsoName = $IsoFile.basename

        If (Test-Path -Path $IsoPath)
        {
            ## Copy Source Files
            Write-Host -Object " Copying Windows install source files"
            Mount-DiskImage -ImagePath "$IsoPath" -NoDriveLetter | Out-Null
            $IsoPathMnt = Get-DiskImage "$IsoPath" | Select-Object DevicePath -ExpandProperty DevicePath
            Copy-Item -Path "$IsoPathMnt\" -Destination "$PSScriptRoot\$IsoName-src" -Recurse
            Dismount-DiskImage -ImagePath "$IsoPath" | Out-Null

            If (Test-Path -Path "$PSScriptRoot\$IsoName-src\sources\install.esd")
            {
                $OrigImgName = "install.esd"
            }

            If (Test-Path -Path "$PSScriptRoot\$IsoName-src\sources\install.wim")
            {
                $OrigImgName = "install.wim"
            }

            $DecomImgName = "install-decom.wim"

            ## esd/wim conversion
            If ($null -eq $SetIndex)
            {
                $EnumOGImgIndexes = Get-WindowsImage -ImagePath "$PSScriptRoot\$IsoName-src\sources\$OrigImgName" | Select-Object -Property ImageName,ImageIndex

                ForEach ($OrigImgIndex in $EnumOGImgIndexes)
                {
                    Write-Host -Object " Converting index $($OrigImgIndex.ImageIndex) of $($EnumOGImgIndexes.ImageIndex.count): $($OrigImgIndex.ImageName)"
                    Export-WindowsImage -SourceImagePath "$PSScriptRoot\$IsoName-src\sources\$OrigImgName" -SourceIndex $($OrigImgIndex.ImageIndex) -DestinationImagePath "$PSScriptRoot\$IsoName-src\sources\$DecomImgName" -CompressionType maximum | Out-Null
                }
            }

            else {
                    Write-Host -Object " Converting index $SetIndex"
                    Export-WindowsImage -SourceImagePath "$PSScriptRoot\$IsoName-src\sources\$OrigImgName" -SourceIndex $SetIndex -DestinationImagePath "$PSScriptRoot\$IsoName-src\sources\$DecomImgName" -CompressionType maximum | Out-Null
            }

            Remove-Item -Path "$PSScriptRoot\$IsoName-src\sources\$OrigImgName" -Recurse -Force
            Rename-Item -Path "$PSScriptRoot\$IsoName-src\sources\$DecomImgName" -NewName "install.wim"

            If ((Test-Path -Path "$PSScriptRoot\$UpdatesSrc") -Or (Test-Path -Path "$PSScriptRoot\$DriversSrc"))
            {
                $EnumIndexes = Get-WindowsImage -ImagePath "$PSScriptRoot\$IsoName-src\sources\install.wim" | Select-Object -Property ImageName,ImageIndex

                ForEach ($WimIndex in $EnumIndexes)
                {
                    If ((Test-Path -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt") -eq $false)
                    {
                        New-Item -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" -ItemType Directory | Out-Null
                    }

                    Mount-WindowsImage -ImagePath "$PSScriptRoot\$IsoName-src\sources\install.wim" -Index $($WimIndex.ImageIndex) -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" | Out-Null

                    ## Apply Updates
                    If (Test-Path -Path "$PSScriptRoot\$UpdatesSrc")
                    {
                        Write-Host -Object " Adding updates to index $($WimIndex.ImageIndex) of $($EnumIndexes.ImageIndex.count): $($WimIndex.ImageName)"
                        Add-WindowsPackage -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" -PackagePath "$PSScriptRoot\$UpdatesSrc" -IgnoreCheck -ErrorAction SilentlyContinue
                    }

                    ## Add drivers
                    If (Test-Path -Path "$PSScriptRoot\$DriversSrc")
                    {
                        Write-Host -Object " Adding drivers to index $($WimIndex.ImageIndex) of $($EnumIndexes.ImageIndex.count): $($WimIndex.ImageName)"
                        Add-WindowsDriver -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" -Driver "$PSScriptRoot\$DriversSrc" -Recurse
                    }

                    ## Clean Image Index
                    #Repair-WindowsImage -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" -StartComponentCleanup -ResetBase | Out-Null #Only Works on Win 11+
                    Dism.exe /Image:"$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" /Cleanup-Image /RestoreHealth /StartComponentCleanup /ResetBase | Out-Null

                    ## Unmount Wim
                    Write-Host -Object " Saving changes"
                    Dismount-WindowsImage -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" -Save | Out-Null
                    Remove-Item -Path "$PSScriptRoot\win-wim$($WimIndex.ImageIndex)-mnt" -Recurse -Force
                }
            }

            ## High compression
            If ($HighComp -eq "enabled")
            {
                $EnumIndexesHC = Get-WindowsImage -ImagePath "$PSScriptRoot\$IsoName-src\sources\install.wim" | Select-Object -Property ImageName,ImageIndex
                Write-Host -Object " $($EnumIndexesHC.ImageIndex.count) Image Indexes to compress"

                ForEach ($WimIndexHC in $EnumIndexesHC)
                {
                    Dism.exe /export-image /SourceImageFile:"$PSScriptRoot\$IsoName-src\sources\install.wim" /SourceIndex:$($WimIndex.ImageIndex) /DestinationImageFile:"$PSScriptRoot\$IsoName-src\sources\install.esd" /Compress:recovery
                }

                Remove-Item -Path "$PSScriptRoot\$IsoName-src\sources\install.wim" -Recurse -Force
            }

            ## Make ISO
            If ($MakeISO -eq "enabled")
            {
                Write-Host -Object " Creating file $IsoName-updt.iso"
                Start-Process $OSCLoc\oscdimg.exe -ArgumentList "-m -o -u2 -udfver102 -bootdata:2#p0,e,b$PSScriptRoot\$IsoName-src\boot\etfsboot.com#pEF,e,b$PSScriptRoot\$IsoName-src\efi\microsoft\boot\efisys.bin $PSScriptRoot\$IsoName-src $PSScriptRoot\$IsoName-updt.iso" -Wait

                ## Clean up
                Write-Host -Object " Cleaning up"
                Remove-Item -Path "$PSScriptRoot\$IsoName-src" -Recurse -Force
            }
        }

        else {
            Write-Host -Object " No iso(s) found"
        }
    }
}

else {
    Write-Host -Object " No ISO folder found"
}