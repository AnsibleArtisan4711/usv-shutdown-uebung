<#
.SYNOPSIS
    Rechnet, ob die Batterielaufzeit der USV fuer ein geordnetes Herunterfahren reicht.

.DESCRIPTION
    Benoetigte Zeit = Verzoegerung auf Batterie + Herunterfahren aller VMs + Herunterfahren des Hosts
                      + Zuschlag (Sicherheitsfaktor auf die Zeiten fuer VMs und Host).
    Die VMs werden entweder nacheinander (Summe) oder gleichzeitig (laengste Dauer) gerechnet, siehe -Gleichzeitig.
    Ausgabe: Aufstellung und Urteil. Rueckgabewert 0 = Laufzeit reicht, 1 = reicht nicht.

.PARAMETER LaufzeitMinuten
    Restlaufzeit der USV bei der tatsaechlichen Last (aus Datenblatt oder Messung, nicht die Angabe bei Halblast).

.PARAMETER VerzoegerungMinuten
    So lange wartet das System auf Batterie, bevor es herunterfaehrt (Standard 3).

.PARAMETER VMDauerSekunden
    Herunterfahrdauer je VM in Sekunden (zum Beispiel aus 01.1-hyperv-herunterfahr-messung.ps1).

.PARAMETER HostSekunden
    Herunterfahrdauer des Hosts ohne VMs (Standard 90).

.PARAMETER Sicherheitsfaktor
    Zuschlag auf VM- und Hostzeiten (Standard 1.5, erlaubt 1.0 bis 5.0).

.PARAMETER Gleichzeitig
    Rechnet mit der laengsten VM statt mit der Summe (nur sinnvoll, wenn der Host VMs parallel herunterfaehrt).

.EXAMPLE
    .\01.1-zeitbudget.ps1 -LaufzeitMinuten 12 -VMDauerSekunden 45,60,120,40 -HostSekunden 90

.NOTES
    Zu Uebung 01.1. Reine Rechnung, es wird nichts am System geaendert.
    Ob Hyper-V VMs gleichzeitig oder nacheinander herunterfaehrt, ist nicht bestaetigt. Im Zweifel mit der Summe rechnen.
    Batterien altern, die tatsaechliche Laufzeit sinkt mit den Jahren: das Ergebnis regelmaessig neu rechnen.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(0.1, 1440)][double]$LaufzeitMinuten,
    [ValidateRange(0, 120)][double]$VerzoegerungMinuten = 3,
    [Parameter(Mandatory)][ValidateRange(1, 7200)][double[]]$VMDauerSekunden,
    [ValidateRange(0, 3600)][double]$HostSekunden = 90,
    [ValidateRange(1.0, 5.0)][double]$Sicherheitsfaktor = 1.5,
    [switch]$Gleichzeitig
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$vmSek = if ($Gleichzeitig) { ($VMDauerSekunden | Measure-Object -Maximum).Maximum } else { ($VMDauerSekunden | Measure-Object -Sum).Sum }
$vmHostMin = ($vmSek + $HostSekunden) * $Sicherheitsfaktor / 60
$benoetigt = $VerzoegerungMinuten + $vmHostMin
$reserve = $LaufzeitMinuten - $benoetigt
$maxVerz = $LaufzeitMinuten - $vmHostMin

$c = [System.Globalization.CultureInfo]::GetCultureInfo('de-AT')
function F([double]$x) { return $x.ToString('0.0', $c) }
Write-Host ('Laufzeit der USV:                      {0} min' -f (F $LaufzeitMinuten))
Write-Host ('Verzoegerung auf Batterie:             {0} min' -f (F $VerzoegerungMinuten))
Write-Host ('VMs ({0}, {1}):  {2} s' -f $VMDauerSekunden.Count, $(if ($Gleichzeitig) { 'gleichzeitig' } else { 'nacheinander' }), (F $vmSek))
Write-Host ('Host:                                  {0} s' -f (F $HostSekunden))
Write-Host ('VMs + Host inkl. Faktor {0}:        {1} min' -f (F $Sicherheitsfaktor), (F $vmHostMin))
Write-Host ('Benoetigt insgesamt:                   {0} min' -f (F $benoetigt))
Write-Host ('Reserve:                               {0} min' -f (F $reserve))
if ($reserve -ge 0) {
    Write-Host ('Urteil: Laufzeit reicht. Groesste zulaessige Verzoegerung: {0} min.' -f (F $maxVerz)) -ForegroundColor Green
    exit 0
}
Write-Host ('Urteil: Laufzeit reicht NICHT. Groesste zulaessige Verzoegerung waere {0} min{1}.' -f (F ([math]::Max(0, $maxVerz))), $(if ($maxVerz -lt 0) { ' (auch ohne Verzoegerung zu knapp: Last senken, groessere Batterie oder weniger VMs)' } else { '' })) -ForegroundColor Yellow
exit 1
