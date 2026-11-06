<#
.SYNOPSIS
    Zeigt oder setzt Stopp- und Startaktion der Hyper-V-VMs fuer ein geordnetes Herunterfahren und Wiederanlaufen.

.DESCRIPTION
    Modus Bericht (Standard, aendert nichts):
      Listet je VM: Zustand, Stoppaktion, Startaktion, Startverzoegerung, Integrationsdienst "Herunterfahren".
      Rueckgabewert 0 = alles wie gewuenscht, 1 = mindestens eine Abweichung.
    Modus Setzen:
      - setzt die Stoppaktion aller betroffenen VMs auf ShutDown (Gastbetriebssystem herunterfahren),
      - setzt fuer die unter -Reihenfolge genannten VMs die Startaktion auf Start und eine gestaffelte
        Startverzoegerung (erste VM: 0 s, zweite: Schritt, dritte: 2 x Schritt, ...).
      Der Integrationsdienst wird nur geprueft, nicht geaendert.

.PARAMETER Modus
    Bericht oder Setzen.

.PARAMETER VMName
    Nur diese VMs (Standard: alle VMs des Hosts).

.PARAMETER Reihenfolge
    Namen der VMs in der gewuenschten Startreihenfolge, zum Beispiel 'DC01','FS01','APP01'.

.PARAMETER Schritt
    Sekunden zwischen den Starts (Standard 60).

.PARAMETER Ausgabe
    Optional: Pfad einer CSV-Datei fuer den Bericht.

.EXAMPLE
    .\01.1-hyperv-stoppaktion.ps1

.EXAMPLE
    .\01.1-hyperv-stoppaktion.ps1 -Modus Setzen -Reihenfolge 'DC01','FS01','APP01' -WhatIf

.NOTES
    Zu Uebung 01.1. Muss in einer administrativen PowerShell auf dem Hyper-V-Host laufen.
    Der Dienst "Herunterfahren" wird ueber die Kennung (Id) des Integrationsdienstes gefunden, weil sein
    Anzeigename je nach Sprache der Windows-Version anders lautet (Kennung nicht bestaetigt, Rueckfall auf den Namen).
    Nur mit nachgebauten Hyper-V-Cmdlets getestet.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Bericht', 'Setzen')][string]$Modus = 'Bericht',
    [string[]]$VMName,
    [string[]]$Reihenfolge = @(),
    [ValidateRange(0, 3600)][int]$Schritt = 60,
    [string]$Ausgabe
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$shutdownGuid = '9F8233AC-BE49-4C79-8EE3-E7E1985B2077'
$vms = @(Get-VM)
if ($VMName) { $vms = @($vms | Where-Object { $VMName -contains $_.Name }) }
foreach ($n in $Reihenfolge) {
    if (-not ($vms | Where-Object { $_.Name -eq $n })) { throw "VM '$n' aus -Reihenfolge nicht gefunden." }
}

function Get-ShutdownDienst {
    param([string]$Name)
    $dienste = @(Get-VMIntegrationService -VMName $Name)
    $treffer = @($dienste | Where-Object { "$($_.Id)" -match $shutdownGuid -or $_.Name -in 'Shutdown', 'Herunterfahren' })
    if ($treffer.Count -gt 0) { return $treffer[0] }
    return $null
}

if ($Modus -eq 'Setzen') {
    foreach ($vm in $vms) {
        if ("$($vm.AutomaticStopAction)" -ne 'ShutDown') {
            if ($PSCmdlet.ShouldProcess($vm.Name, "Stoppaktion '$($vm.AutomaticStopAction)' -> ShutDown")) {
                Set-VM -Name $vm.Name -AutomaticStopAction ShutDown
            }
        }
    }
    for ($i = 0; $i -lt $Reihenfolge.Count; $i++) {
        $verz = $i * $Schritt
        if ($PSCmdlet.ShouldProcess($Reihenfolge[$i], "Startaktion Start, Verzoegerung $verz s")) {
            Set-VM -Name $Reihenfolge[$i] -AutomaticStartAction Start -AutomaticStartDelay $verz
        }
    }
    $vms = @(Get-VM)
    if ($VMName) { $vms = @($vms | Where-Object { $VMName -contains $_.Name }) }
}

$zeilen = foreach ($vm in $vms) {
    $dienst = Get-ShutdownDienst -Name $vm.Name
    $dienstText = if ($null -eq $dienst) { 'nicht gefunden' } elseif ($dienst.Enabled) { 'aktiv' } else { 'AUS' }
    $problem = @()
    if ("$($vm.AutomaticStopAction)" -ne 'ShutDown') { $problem += 'Stoppaktion' }
    if ("$($vm.State)" -eq 'Running' -and $dienstText -ne 'aktiv') { $problem += 'Integrationsdienst' }
    if ($Reihenfolge -contains $vm.Name -and "$($vm.AutomaticStartAction)" -ne 'Start') { $problem += 'Startaktion' }
    [pscustomobject]@{
        VM            = $vm.Name
        Zustand       = "$($vm.State)"
        Stoppaktion   = "$($vm.AutomaticStopAction)"
        Startaktion   = "$($vm.AutomaticStartAction)"
        StartVerzSek  = [int]$vm.AutomaticStartDelay
        Herunterfahren = $dienstText
        Urteil        = if ($problem.Count -eq 0) { 'OK' } else { 'ABWEICHUNG: ' + ($problem -join ', ') }
    }
}
$zeilen = @($zeilen)
($zeilen | Format-Table -AutoSize | Out-String -Width 200) | Write-Host
if ($Ausgabe) { $zeilen | Export-Csv -LiteralPath $Ausgabe -NoTypeInformation -Encoding UTF8; Write-Host "CSV geschrieben: $Ausgabe" }

$fehler = @($zeilen | Where-Object { $_.Urteil -ne 'OK' }).Count
if ($fehler -gt 0) { Write-Host "$fehler VM(s) mit Abweichung." -ForegroundColor Yellow; exit 1 }
Write-Host 'Alle VMs wie gewuenscht.' -ForegroundColor Green
exit 0
