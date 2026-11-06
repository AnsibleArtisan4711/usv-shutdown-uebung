# USV-Übung: Geordnetes Herunterfahren ohne USV

Praxisübung zu Stromausfall und geordnetem Herunterfahren in einer **eigenen, isolierten Testumgebung** (Hyper-V, zwei Linux-VMs, privater Switch). Es wird **keine echte USV** gebraucht: Eine USV wird mit NUT (Network UPS Tools) simuliert, der Hyper-V-Host wird für ein sauberes Herunterfahren vorbereitet, und ein Skript rechnet, ob die Batterielaufzeit reicht. Alle Namen und Adressen sind frei erfunden.

## Inhalt

| Modul | Übung | Stufe |
|---|---|---|
| [01-geordnetes-herunterfahren](01-geordnetes-herunterfahren/) | 01.1 Geordnetes Herunterfahren ohne USV (Hyper-V vorbereiten, USV simulieren, Zeitbudget) | Aufbau bis Vertiefung |

## Stand

**Entwurf.** Die NUT-Skripte wurden mit echten NUT-Programmen (Version 2.8.1, Ubuntu 24.04) geprüft: simulierte USV, Verzögerung, Server und Client, jedoch mit von Hand gestarteten Programmen statt als Systemdienste. Die PowerShell-Skripte wurden mit nachgebauten Hyper-V-Befehlen getestet. **Auf Hyper-V selbst wurde nichts ausgeführt.** Was nicht gegen eine Quelle geprüft ist, steht in der Übung als „nicht bestätigt“. Abweichungen bitte als Issue melden.

## Sicherheit

- Nur in einer isolierten Testumgebung ausführen, nie auf produktiven Servern.
- `01.1-hyperv-herunterfahr-messung.ps1` fährt VMs herunter und startet sie wieder: nur Test-VMs verwenden. Mit `-WhatIf` lässt sich vorher prüfen.
- Die NUT-Skripte laufen standardmäßig im **Probemodus** (nur protokollieren). Das echte Herunterfahren wird bewusst eingeschaltet.
- NUT überträgt unverschlüsselt (TCP 3493). Die Kennwörter werden abgefragt und stehen nur in den NUT-Konfigurationsdateien.

## Lizenz

Skripte: MIT ([LICENSE](LICENSE)). Texte und Anleitungen: CC BY-NC-SA 4.0 ([LICENSE-DOCS.md](LICENSE-DOCS.md)). Microsoft, Windows und Hyper-V sind Marken der Microsoft-Gruppe, Debian und Ubuntu Marken ihrer Inhaber. NUT ist ein Projekt der Network UPS Tools Community. Dieses Projekt steht in keiner Verbindung zu diesen Unternehmen oder Projekten.
