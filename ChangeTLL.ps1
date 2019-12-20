<#
.SYNOPSIS
    Configure TTL of records from CSV to 1 minute if IPs have been updated in order that DNS reflects new IP. 
    Afterwards, change TTL back to time sepcified on CSV.
.DESCRIPTION
    Performs the following action on a DNS Record:
    Configure TTL time from previous to 1 minute
    Configure TTL to previous value    
.NOTES
  Version:        1.0
  Author:         <Joshua Dooling>
  Creation Date:  <04/11/2019>
  Purpose/Change: Automate TTL change in order for DNS to update record IP quicker
.EXAMPLE
    PS C:\> ChangeTTL.ps1
#>
Clear-Host

#Region Import CSV
[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
$ImportDialog = New-Object System.Windows.Forms.OpenFileDialog
$ImportDialog.Title = "Select List of VMs CSV"
$ImportDialog.Multiselect = $false
$ImportDialog.filter = "Comma Delimetered (*.csv)|*.csv|Text File (*.txt)| *.txt|All Files (*.*)|*.*"
$ImportDialogResult = $ImportDialog.ShowDialog()

if($ImportDialogResult -ne "OK")
{
    break
}

$csv = Import-Csv -Path $ImportDialog.FileName
#endregion

$computerNameNET = "DC1.DC.company.com"
$zoneNameNET = "DC.company.com"

$ServerReseourceList = Get-DnsServerResourceRecord -ComputerName $computerNameNET -ZoneName $zoneNameNET | select hostname, TimeToLive, @{ Name = 'IP'; E= { $_.RecordData | select -ExpandProperty ipv4address } }

$run1min = Read-Host "Do you need to change the TTL to 1 minute"

if($run1min -match 'Y' -or $run1min -match 'y'){
    foreach($name in $csv){

        foreach($server in $ServerReseourceList){

            if(($name.name -contains $server.hostname) -and ($name.oldIP -match $server.IP)){

                if($server.TimeToLive -ge "00:01:00"){
                    Write-Host "Currently modifying: "$server.hostname  $server.ip " TTL -> 1 min" "`n"
                    $oldObj = Get-DnsServerResourceRecord -Name $name.name -ComputerName $computerNameNET -ZoneName $zoneNameNET
                    $newObj = $oldObj.Clone();
                    $newObj.TimeToLive = [System.TimeSpan]::FromMinutes(1)
                    Set-DnsServerResourceRecord -NewInputObject $newObj -OldInputObject $oldObj -ComputerName $computerNameNET -ZoneName $zoneNameNET -WhatIf
                    break
                }else{
                    Write-Host $server.hostname "TTL is already set at 1 minute"
                    break
                }
            }
        }
    }
}


do{
    
    $answer = Read-Host "`nAre all the resource records reflecting their new IPs? If so, type 'Y' or 'y' to set TTL back to their normal time"

}while($answer -match 'N' -or $answer -match 'n')


if($answer -match 'Y' -or $answer -match 'y'){

    foreach($name in $csv){

        foreach($server in $ServerReseourceList){

            if($name.name -contains $server.hostname){

                Write-Host "`nCurrently Modifying: "$server.hostname "  " $server.ip "`n"
                $oldObj = Get-DnsServerResourceRecord -Name $name.name -ComputerName $computerNameNET -ZoneName $zoneNameNET
                $newObj = $oldObj.Clone()
                
                if($name.ttl -match "min"){
                    $value = $name.ttl.Substring(0, $name.ttl.IndexOf(" "))
                    $newObj.TimeToLive = [System.TimeSpan]::FromMinutes($value)
                    Write-Host "TTL ->" $value "minute(s)`n"
                }elseif($name.ttl -match "hour"){
                    $value = $name.ttl.Substring(0, $name.ttl.IndexOf(" "))
                    $newObj.TimeToLive = [System.TimeSpan]::FromHours($value)
                    Write-Host "TTL ->" $value "hour(s)`n"
                }

                Set-DnsServerResourceRecord -NewInputObject $newObj -OldInputObject $oldObj -ComputerName $computerNameNET -ZoneName $zoneNameNET -WhatIf
                break;
            }          
        }
    }
}
