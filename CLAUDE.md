# Project: NVEncC64_Wrapper

Wrapper-Skript für `nvencc64.exe` (NVIDIA Hardware-Encoder). Hauptsächlich eine `.cmd`-Datei plus zugehörige Hilfs-Skripte.

## Target Platform

Dieses Projekt läuft ausschließlich auf **Windows 11** mit **PowerShell 5.1+**.

Folge daraus:
- PowerShell 3.0+-Features (z.B. `[string]::IsNullOrWhiteSpace`) sind verfügbar — kein Workaround nötig.
- `Out-File -Encoding Default` schreibt ANSI ohne BOM auf dieser Plattform — kein Risiko für cmd `call`.
- Codepage für `call` von generierten `.cmd`-Dateien ist Windows-1252 (deutsche Locale) — Sonderzeichen in Dateinamen/Track-Namen funktionieren.

## nvencc64_wrapper.cmd — Dry-Run-Status

Am **2026-07-21** wurde ein vollständiger statischer Dry-Run der Datei `nvencc64_wrapper.cmd` durchgeführt.

**Ergebnis:** Skript ist valide. 125/125 Tokens sind in den Mapping-Tabellen abgedeckt. 22 End-to-End-Szenarien PASS.

### Akzeptierte "Bugs" (NICHT erneut flaggen ohne Rückfrage)

Diese Punkte wurden in einem Review zunächst als potentielle Bugs gemeldet und vom User explizit als **gewollt und in Ordnung** bestätigt. Sie dürfen in zukünftigen Reviews nicht erneut als Issues markiert werden, sofern sich die Plattform-Anforderungen nicht ändern:

1. **`[string]::IsNullOrWhiteSpace` im EDIT_TAGS-Block** (Zeilen 763, 770, 801, 828) — erfordert PowerShell 3.0+. Auf Windows 11 mit PS 5.1 kein Problem.
2. **`Out-File -Encoding Default`** für die SET-Datei in EDIT_TAGS (Zeile 841) — könnte theoretisch BOM schreiben. Auf PS 5.1 unter Windows 11 schreibt es ANSI ohne BOM, cmd `call` liest sauber.
3. **AV1-Encoder nutzt `SETQUALITY-HEVC`** (Zeilen 101–107) — keine eigene AV1-Qualitätstabelle. Bewusste Designentscheidung.

### Akzeptierte Design-Issues (NICHT erneut flaggen ohne Rückfrage)

Auch diese wurden explizit als gewollt bestätigt:

- **D1** (Z. 742–743): `$Top`/`$Bottom` enthalten Seiten-Crop-Werte, nicht Top/Bottom. Irreführend, aber funktional korrekt.
- **D2** (Z. 124–147 + 161–163): Fragmentierte `RESIZE_REQUIRED`-Logik über zwei Blöcke verteilt. Funktioniert wie intendiert.
- **D3** (Z. 176–179): 5-Sekunden-Wartezeit zwischen Encodes. Bewusste Drosselung.
- **D4** (Z. 89): Dead-looking `powershell write-output` URL-Print — absichtlicher Notification-Hook auf stdout.
- **D5** (Z. 42): `_Converted`-Verzeichnis wird unbedingt erstellt, auch wenn keine Medien gefunden werden. Akzeptiert.
- **D6** (Z. 149): URL-Print vor jedem `mediainfo`-Aufruf. Akzeptiert.

## Konventionen für Erweiterungen

Bei Änderungen oder Erweiterungen an `nvencc64_wrapper.cmd`:

- **Token-Validierung erweitern?** Jedes neue Token muss in **beide** Listen: `TOK_*` in `:SETTOKEN` (Zeile 605) und als `if`-Branch in der entsprechenden `:SETxxx`-Routine.
- **Neue Filter/Mode-Tokens mit Resize?** Prüfe, ob die Ausgabe `--vpp-resize` enthält — die Erkennung in Zeilen 22–29 steuert, ob ein zusätzliches `--vpp-resize spline36` injiziert wird. Bei true sollte der Token dort nicht doppelt resize hinzufügen.
- **Neue Encoder?** Analog zu AV1 entweder explizit auf `SETQUALITY-HEVC` mappen (mit Kommentar warum) oder eigene `:SETQUALITY-<NAME>`-Routine schreiben.
- **Neue PS-Sub-Skripte?** Marker-Format `#PS_<NAME>_BEGIN#` / `#PS_<NAME>_END#` verwenden, Block am Ende der `.cmd` anhängen, Extraction-Logik aus `:EDIT_TAGS` (Z. 405) oder `:RUN_PROBE` (Z. 466) kopieren.