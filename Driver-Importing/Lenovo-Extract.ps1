$srcfld = "C:\foo\Drivers-to-extract\Lenovo"
$xtractLocal = "C:\foo\Drivers-to-extract\Lenovo\"

$ModelFolders = Get-ChildItem $srcfld -Directory
ForEach ($Modelfld in $ModelFolders)
{
    $GetExes = Get-ChildItem "$srcfld\$Modelfld\_drivers" -filter *.exe | select-object -property fullname,name,basename
    ForEach ($LenExe in $GetExes)
    {
	    & $LenExe.fullname /VERYSILENT /DIR=$xtractLocal\$Modelfld\$($LenExe.basename) /Extract="YES"
    }
}
