[CmdletBinding(DefaultParameterSetName="Operate")]
param (
    [Parameter(ParameterSetName="Operate", Mandatory=$false)]
    [Parameter(ParameterSetName="Install", Mandatory=$false)]
    [ValidateSet("Portrait", "Landscape")]
    # collect pictures in landscape format; for pictures in portrait format, configure this to "Portrait"
    [string] $Format = "Landscape", 
    [Parameter(ParameterSetName="Install", Mandatory=$true)]
    [switch] $Install,
    [Parameter(ParameterSetName="Uninstall", Mandatory=$true)]
    [switch] $Uninstall
)

# -------------- Configuration area --------------
# folder to store the wallpaper picture files
$CollectionFolder = 'lockscreen-pics' 
# $true, to set the desktop background image, $false, to collect picture files only
$SetWallpaper = $true 
# ---------------- End config area ----------------

if($Install) {
    "Install ..."
    # install script as scheduled task in Windows on OS level 
    $posh = 'powershell'
    if($PSVersionTable.PSEdition -eq 'Core') {
        $posh = 'pwsh'
    }
    $script = '-EP Bypass -NoLogo -NonInteractive -WindowStyle Hidden -File "' + $MyInvocation.MyCommand.Definition + '"';
    if($Format -eq "Portrait") {
        $script += " -Format Portrait";
    }
    $action = New-ScheduledTaskAction -Execute $posh -Argument $script;
    $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddSeconds(10)) -RepetitionInterval (New-TimeSpan -Days 1);
    $settings = New-ScheduledTaskSettingsSet -Hidden -DontStopIfGoingOnBatteries -DontStopOnIdleEnd -StartWhenAvailable;
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings;
    Register-ScheduledTask 'Collect-Lockscreens' -InputObject $task | Out-Null;
    "Done."
    exit
}

if($Uninstall) {
    "Uninstall ..."
    # uninstall script from scheduled tasks in Windows
    Unregister-ScheduledTask 'Collect-Lockscreens';
    "Done."
    exit
}

# here we can find the lockscreen pictures and their descriptions as they are downloaded by Windows
$assetDir = [IO.Path]::Combine($env:LocalAppData, 'Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\Assets')
$metaDir = [IO.Path]::Combine($env:LocalAppData, 'Packages\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy\LocalState\ContentManagementSDK\Creatives\338387')

# all copied pictues are stored in a subfolder under the "Pictures" folder (as defined in $CollectionFolder)
$myPics = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyPictures)
$lockScreenDir = [IO.Path]::Combine($myPics, $CollectionFolder)
if(-not (Test-Path $lockScreenDir)) {
    New-Item -Path $lockScreenDir -ItemType Directory | Out-Null
}

# all pictures >=100KB could by lockscreen picture... thus, we calculate their SHA256 hash
$candidates = Get-ChildItem $assetDir -File | Where-Object Length -ge 100KB
$hashAlgo = [Security.Cryptography.HashAlgorithm]::Create("SHA256")
foreach($c in $candidates) {
    $fileBytes = [IO.File]::ReadAllBytes($c.FullName)
    $hashBytes = $hashAlgo.ComputeHash($fileBytes)
    $hash = [Convert]::ToBase64String($hashBytes)
    $c | Add-Member -MemberType NoteProperty -Name 'Hash' -Value $hash
}

# here we extract title / description and the like from the metadata
$lockScreenGuess = $null
foreach($metaFile in (Get-ChildItem $metaDir -Filter *. -File)) {
    $meta = $metaFile | Get-Content | ConvertFrom-Json
    $spotlights = $meta.batchrsp.items
    if($spotlights) {
        $firstEntry = $null
        foreach($entry in $spotlights) {
            $objImage =  $entry.item | ConvertFrom-Json
            $ad = $objImage.ad
            if($ad) {
                $title = $ad.items[0].properties.description.text
                $image = $ad.properties.landscapeImage
                if($Format -eq "Portrait") { $image = $ad.properties.portraitImage }
                if($image) {
                    $imageFile = $candidates | Where-Object Hash -eq $image.sha256
                    if($imageFile) {
                        $fileName = $title + '.jpg'
                        # $fileName = '{0} {1}x{2}.jpg' -f $title, $image.width, $image.height
                        Copy-Item $imageFile.FullName ([IO.Path]::Combine($lockScreenDir, $fileName)) -Force
<#
                        # --- DEBUG ---
                        $logFile = [IO.Path]::Combine($lockScreenDir, 'Lockscreen.log')
                        'Datum:      {0}' -f (Get-Date) | Out-File $logFile -Append -Encoding utf8
                        'Quelldatei: {0}' -f ($imageFile.Name) | Out-File $logFile -Append -Encoding utf8
                        'Zieldatei:  {0}' -f $fileName | Out-File $logFile -Append -Encoding utf8
                        'Größe:      {0} x {1}' -f $image.width, $image.height | Out-File $logFile -Append -Encoding utf8
                        'Metadaten:  {0}' -f $metaFile.Name | Out-File $logFile -Append -Encoding utf8
                        "----------------------------------------------------------`r`n" | Out-File $logFile -Append -Encoding utf8
                        # --- /DEBUG ---
#>
                        if(-not $firstEntry) { $firstEntry = $fileName }
                    }
                }
            }
        }
        if($firstEntry) { $lockScreenGuess = $firstEntry }
    }
}
if($lockScreenGuess) {
<#
    # --- DEBUG ---
    $logFile = [IO.Path]::Combine($lockScreenDir, 'Lockscreen.log')
    'Datum:                       {0}' -f (Get-Date) | Out-File $logFile -Append -Encoding utf8
    'Wahrscheinlicher Lockscreen: {0}' -f $lockScreenGuess | Out-File $logFile -Append -Encoding utf8
    "----------------------------------------------------------`r`n" | Out-File $logFile -Append -Encoding utf8
    # --- /DEBUG ---
#>
    if($SetWallpaper) {
        $code = @'
            using System;
            using System.Runtime.InteropServices;
            public static class Win32{
                [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
                [return: MarshalAs(UnmanagedType.Bool)]
                static extern bool SystemParametersInfo(uint uiAction, uint uiParam, String pvParam, uint fWinIni);

                const uint SPI_SETDESKWALLPAPER = 0x0014;
                const uint SPIF_UPDATEINIFILE = 0x01;
                const uint SPIF_SENDCHANGE = 0x02;
                public static void SetWallpaper(string ImagePath)
                {
                    SystemParametersInfo(SPI_SETDESKWALLPAPER, 0, ImagePath, SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
                }
            }
'@
        Add-Type $code
        [Win32]::SetWallpaper([IO.Path]::Combine($lockScreenDir, $lockScreenGuess))
    }
}
