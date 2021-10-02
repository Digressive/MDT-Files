$MdtDeployPath = "C:\DeploymentShare"
$DriverSrc = "C:\Driver-Source\MDT-Import"

Import-Module "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
New-PSDrive -Name "MDTDeployShare" -PSProvider MDTProvider -Root $MdtDeployPath | Out-Null

$MakeFlds = Get-ChildItem "$DriverSrc" -Directory
ForEach ($Make in $MakeFlds)
{
    $MakeT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$Make"
    If ($MakeT -eq $False)
    {
        New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$Make" -enable "True" -ItemType "folder" -Verbose
    }

    $ModelFlds = Get-ChildItem "$DriverSrc\$Make" -Directory
    ForEach ($Model in $ModelFlds)
    {
        $ModelT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model"
        If ($ModelT -eq $False)
        {
            New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model" -enable "True" -ItemType "folder" -Verbose
        }

        $DriverFlds = Get-ChildItem "$DriverSrc\$Make\$Model" -Directory
        ForEach ($Folder in $DriverFlds)
        {
            $ModelFolderT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model\$Folder"
            If ($ModelFolderT -eq $False)
            {
                New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model\$Folder" -enable "True" -ItemType "folder" -Verbose
            }

            Import-MDTdriver -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model\$Folder" -SourcePath "$DriverSrc\$Make\$Model\$Folder" -ImportDuplicates –Verbose
        }
    
        $DriverCabs = Get-ChildItem "$DriverSrc\$Make\$Model" -filter *.cab
        ForEach ($Cab in $DriverCabs)
        {
            $ModelCabT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model\$Cab"
            If ($ModelCabT -eq $False)
            {
                New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model\$Cab" -enable "True" -ItemType "folder" -Verbose
            }

            Import-MDTdriver -Path "MDTDeployShare:\Out-of-Box Drivers\$Make\$Model\$Cab" -SourcePath "$DriverSrc\$Make\$Model" -ImportDuplicates –Verbose
        }
    }
}
