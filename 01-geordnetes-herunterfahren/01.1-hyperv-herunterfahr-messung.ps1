<#
.SYNOPSIS
    Misst, wie lange VMs fuer ein geordnetes Herunterfahren brauchen, und startet sie danach wieder.

.DESCRIPTION
    Fuer jede genannte VM, einzeln nacheinander:
      1. faehrt sie ueber die Integrationsdienste herunter (Stop-VM ohne -TurnOff),
      2. misst die Zeit bis zum Zustand "Off" (Abbruch nach -TimeoutSekunden),
      3. startet sie wieder (ausser mit -NichtWiederStarten).
    Das Ergebnis geht als Tabelle (und optional CSV) an die Ausgabe und kann direkt in 01.1-zeitbudget.ps1 verwendet werden.
    Rueckgabewert 0 = alle VMs sauber heruntergefahren, 1 = mindestens eine VM hat das Zeitlimit ueberschritten.
    Muss in einer administrativen PowerShell auf dem Hyper-V-Host laufen. Nur fuer Test-VMs verwenden.

.PARAMETER VMName
    Namen der VMs (Pflicht).

.PARAMETER TimeoutSekunden
    Wartezeit je VM (Standard 300, erlaubt 30 bis 3600).

.PARAMETER NichtWiederStarten
    VM bleibt nach der Messung ausgeschaltet.

.PARAMETER Ausgabe
    Optional: Pfad einer CSV-Datei.

.EXAMPLE
    .\01.1-hyperv-herunterfahr-messung.ps1 -VMName APP01 -WhatIf

.NOTES
    Zu Uebung 01.1. Nur mit nachgebauten Hyper-V-Cmdlets getestet. Ein VM-Neustart aendert Zeitstempel und
    laufende Dienste: nicht auf VMs mit wichtigen Daten anwenden.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string[]]$VMName,
    [ValidateRange(30, 3600)][int]$TimeoutSekunden = 300,
    [switch]$NichtWiederStarten,
    [string]$Ausgabe
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$ergebnis = foreach ($name in $VMName) {
    $vm = Get-VM -Name $name
    if ("$($vm.State)" -ne 'Running') {
        [pscustomobject]@{ VM = $name; Sekunden = ''; Ergebnis = "uebersprungen (Zustand $($vm.State))" }
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($name, 'Herunterfahren, Dauer messen, wieder starten')) { continue }

    $uhr = [System.Diagnostics.Stopwatch]::StartNew()
    Stop-VM -Name $name -Confirm:$false
    # Stop-VM wartet bei einem Gast-Herunterfahren nicht in jedem Fall bis zum Ende, deshalb zusaetzlich pruefen
    while ("$((Get-VM -Name $name).State)" -ne 'Off' -and $uhr.Elapsed.TotalSeconds -lt $TimeoutSekunden) {
        Start-Sleep -Seconds 2
    }
    $uhr.Stop()
    $ok = "$((Get-VM -Name $name).State)" -eq 'Off'
    [pscustomobject]@{
        VM       = $name
        Sekunden = [math]::Round($uhr.Elapsed.TotalSeconds, 0)
        Ergebnis = if ($ok) { 'sauber heruntergefahren' } else { "Zeitlimit $TimeoutSekunden s ueberschritten" }
    }
    if ($ok -and -not $NichtWiederStarten) { Start-VM -Name $name }
}
$ergebnis = @($ergebnis)
($ergebnis | Format-Table -AutoSize | Out-String -Width 200) | Write-Host
if ($Ausgabe) { $ergebnis | Export-Csv -LiteralPath $Ausgabe -NoTypeInformation -Encoding UTF8; Write-Host "CSV geschrieben: $Ausgabe" }
if (@($ergebnis | Where-Object { $_.Ergebnis -like 'Zeitlimit*' }).Count -gt 0) { exit 1 }
exit 0
