# Modul 01: Geordnetes Herunterfahren

| Datei | Zweck |
|---|---|
| [01.1-geordnetes-herunterfahren-ohne-usv.md](01.1-geordnetes-herunterfahren-ohne-usv.md) | Übung mit Hintergrund, Prüfbefehlen, Musterlösung |
| `01.1-hyperv-stoppaktion.ps1` | Stopp- und Startaktion der VMs berichten oder setzen, gestaffelter Start (`-WhatIf` möglich) |
| `01.1-hyperv-herunterfahr-messung.ps1` | Herunterfahrdauer von Test-VMs messen (fährt VMs herunter und startet sie wieder) |
| `01.1-zeitbudget.ps1` | Rechnet, ob die Batterielaufzeit für Verzögerung, VMs und Host reicht (Rückgabewert 0/1) |
| `01.1-nut-server.sh` | NUT-Server mit simulierter USV, `upsmon` (primary), Verzögerung über `upssched` |
| `01.1-nut-client.sh` | NUT-Client (secondary) auf einer zweiten VM |
| `01.1-usv-zustand.sh` | Zustand der simulierten USV umschalten (`netz`, `ausfall`, `schwach`) |

PowerShell-Skripte sind UTF-8 mit BOM gespeichert (Windows PowerShell 5.1). Shell-Skripte haben Unix-Zeilenenden. Beim Kopieren Kodierung und Zeilenenden beibehalten. Die NUT-Skripte laufen als root und starten im Probemodus.
