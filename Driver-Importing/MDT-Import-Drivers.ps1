$MdtDeployPath = "\\mdt19\Deployment"
$DriverSrc = "\\fs01\user-homes\sysadmin\Driver-Work\drivers-finished"

Import-Module "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
New-PSDrive -Name "MDTDeployShare" -PSProvider MDTProvider -Root $MdtDeployPath | Out-Null

Function ImportDrivers
{
    $MakeT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT"
    If ($MakeT -eq $False)
    {
        New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT" -enable "True" -ItemType "folder" 
    }

    $ModelFlds = Get-ChildItem "$DriverSrc\$Make" -Directory
    ForEach ($Model in $ModelFlds)
    {
        $ModelT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model"
        If ($ModelT -eq $False)
        {
            New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model" -enable "True" -ItemType "folder" 
        }

        $DriverFlds = Get-ChildItem "$DriverSrc\$Make\$Model" -Directory
        ForEach ($Folder in $DriverFlds)
        {
            $ModelFolderT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model\$Folder"
            If ($ModelFolderT -eq $False)
            {
                New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model\$Folder" -enable "True" -ItemType "folder" 
            }

            Import-MDTdriver -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model\$Folder" -SourcePath "$DriverSrc\$Make\$Model\$Folder" -ImportDuplicates 
        }

        $DriverCabs = Get-ChildItem "$DriverSrc\$Make\$Model" -filter *.cab
        ForEach ($Cab in $DriverCabs)
        {
            $ModelCabT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model\$Cab"
            If ($ModelCabT -eq $False)
            {
                New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model\$Cab" -enable "True" -ItemType "folder" 
            }

            Import-MDTdriver -Path "MDTDeployShare:\Out-of-Box Drivers\$MakeMDT\$Model\$Cab" -SourcePath "$DriverSrc\$Make\$Model" -ImportDuplicates 
        }
    }
}

## Make folder structure and important drivers
$MakeFlds = Get-ChildItem "$DriverSrc" -Directory
ForEach ($Make in $MakeFlds)
{
    If ($Make.Name -eq "Dell")
    {
        $MakeMDT = "Dell Inc."
        ImportDrivers
    }

    else
    {
        $MakeMDT = $Make
        ImportDrivers
    }
}

## Copy HP drivers to folders Hewlett Packard and Hewlett-Packard
$HPFldT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\HP"
If ($HPFldT -eq $True)
{
    $HPFullFldT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\Hewlett Packard"
    If ($HPFullFldT -eq $False)
    {
        New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\Hewlett Packard" -enable "True" -ItemType "folder"
        Copy-Item -Path "MDTDeployShare:\Out-of-Box Drivers\HP\*" "MDTDeployShare:\Out-of-Box Drivers\Hewlett Packard" -Recurse
    }

    $HPDashFullFldT = Test-Path -Path "MDTDeployShare:\Out-of-Box Drivers\Hewlett-Packard"
    If ($HPDashFullFldT -eq $False)
    {
        New-Item -Path "MDTDeployShare:\Out-of-Box Drivers\Hewlett-Packard" -enable "True" -ItemType "folder"
        Copy-Item -Path "MDTDeployShare:\Out-of-Box Drivers\HP\*" "MDTDeployShare:\Out-of-Box Drivers\Hewlett-Packard" -Recurse
    }
}

##End