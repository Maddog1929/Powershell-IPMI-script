#Powershell script for R720 auto fan control.
 
 #change these
$dracIP = "192.168.50.204"
$dracUser = "root"
$dracPass = "password"
$ipmiToolDir = "C:\Program Files (x86)\Dell\SysMgt\bmc"


$dangerTemp = [int]65     # server goes back to auto if this temp is reached
[int]$percentFan = 50
[int]$hysteresis = 2
[int]$tempTarget = 40

$setManual = [String]("0x30 0x30 0x01 0x00")
$setAuto = [String]("0x30 0x30 0x01 0x01")
$setSpeed = [String]('0x30 0x30 0x02 0xff 0x') #append values 0x00 (0%) through 0x64 (100%)

$start = './ipmitool.exe -I lanplus -H '+$dracIP+ ' -U '+ $dracUser +' -P '+$dracPass +' raw' #this is the template we will use to generate our commands


function do-Setup(){
Set-ExecutionPolicy -ExecutionPolicy Unrestricted
cd $ipmiToolDir
($start +" "+ $setManual) | Invoke-Expression
}
function get-Temp()
{
$command = './ipmitool.exe -I lanplus -H ' +$dracIP+ ' -U ' +$dracUser+ ' -P ' +$dracPass+ ' sensor reading "Temp"'
$stringtemp = Invoke-Expression -Command $command
$stringtemp = [String]$stringtemp
return [int]$stringtemp.Substring($stringtemp.IndexOf("|")+2)
}

function get-FanRpm()
{
$command = './ipmitool.exe -I lanplus -H ' +$dracIP+' -U '+$dracUser+' -P '+$dracPass+' sensor reading "Fan3"'
$stringtemp = Invoke-Expression -Command $command
return [int]$stringtemp.Substring($stringtemp.IndexOf("|")+1)
}

do-Setup
[int]$temp = get-Temp
[int]$rpm = get-FanRpm


#begin loop
Do{
  $temp = get-Temp
  $rpm = get-FanRpm

Write-Host "The temp is" $temp"c"
Write-Host "Current fan rpm is" $rpm


if ($temp -ge $dangerTemp){
    ($start +" "+ $setAuto) | Invoke-Expression
    Write-Host "Temps are too high, switching back to auto mode for 5 minutes"
    Start-Sleep -s 300
    ($start +" "+ $setManual) | Invoke-Expression
}

if($temp -gt ($tempTarget + $hysteresis) -and $percentFan -lt 100){
  Write-Host "Temps are high"
  $percentFan++
}elseif ($temp -lt ($tempTarget )) {
  Write-Host "Temps are low"
  $percentFan--
}

$hex = [System.String]::Format('{0:X}', $percentFan) #map returns a int, so convert to hex value to pass to the raw command
Write-Host "PWM is set to $hex"

if($percentFan -le 15){
($start +" "+ ($setSpeed+"0"+$hex)) | Invoke-Expression
}else{
($start +" "+ ($setSpeed+$hex)) | Invoke-Expression
}

Start-Sleep -s 1

} While(1)

