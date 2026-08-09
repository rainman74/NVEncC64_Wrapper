# Project: NVEncC64_Wrapper

Wrapper-Skript für `nvencc64.exe` (NVIDIA Hardware-Encoder). Hauptsächlich eine `.cmd`-Datei plus zugehörige Hilfs-Skripte.

## Target Platform

Dieses Projekt läuft ausschließlich auf **Windows 11** mit **PowerShell 5.1+**.

Folge daraus:
- PowerShell 3.0+-Features (z.B. `[string]::IsNullOrWhiteSpace`) sind verfügbar — kein Workaround nötig.
- Codepage für `call` von generierten `.cmd`-Dateien ist Windows-1252 (deutsche Locale) — Sonderzeichen in Dateinamen/Track-Namen funktionieren.
- Im EDIT_TAGS-PS-Block wird `Out-File -Encoding Default` absichtlich **nicht** verwendet (siehe Aktive Fixes #1) — stattdessen `WriteAllText` mit explizitem ASCII-Encoding.

## Pfad-Setup (CMDPATH-basiert)

Der Wrapper ist **explizit nicht** skript-relativ, sondern nutzt den System-`CMDPATH`. Architekturentscheidung mit Konsequenzen:

```batch
REM Z. 7-9 im INIT-Block:
set "VFX_MODEL_DIR=%NVVFX_MODEL_DIR%"
set "ONNX_MODEL_DIR=%CMDPATH%\bin\onnx_models"
set "NV_FLAGS=--vpp-onnx-model-dir "%ONNX_MODEL_DIR%" --vpp-nvvfx-model-dir "%VFX_MODEL_DIR%""
```

**Voraussetzungen für korrekte Funktion:**
- `CMDPATH` muss auf das Verzeichnis zeigen, in dem `bin\onnx_models\` liegt (typisch: zentrale Toolchain wie `D:\Apps\Commands`)
- `NVVFX_MODEL_DIR` muss auf den NVIDIA-Video-Effects-Modell-Ordner zeigen (typisch: `C:\Program Files\NVIDIA Corporation\NVIDIA Video Effects\models`)

**Warum nicht `%~dp0`?** Der Wrapper kann unabhängig von der Toolchain-Installation in beliebigen Verzeichnissen liegen (z.B. `D:\Sources\NVEncC64_Wrapper\`), während die Modelle zentral vorgehalten werden. Bei einer reinen `%~dp0`-basierten Variante müsste `bin\onnx_models\` zwingend neben dem Wrapper liegen — das schränkt die Deployment-Optionen ein.

**Konsequenz für Tests:** Bei CMDPATH=`D:\Apps\Commands` müssen onnx_models unter `D:\Apps\Commands\bin\onnx_models\` liegen. Wer den Wrapper auf einem anderen System laufen lässt, muss CMDPATH und NVVFX_MODEL_DIR entsprechend setzen.

## nvencc64_wrapper.cmd — Dry-Run-Status

Am **2026-07-21** wurde ein vollständiger statischer Dry-Run der Datei `nvencc64_wrapper.cmd` durchgeführt.

**Ergebnis:** Skript ist valide. 125/125 Tokens sind in den Mapping-Tabellen abgedeckt. 22 End-to-End-Szenarien PASS.

> **Hinweis:** Dieser Dry-Run-Stand bezieht sich auf den Code vor den unten dokumentierten aktiven Fixes. Ein erneuter Dry-Run nach den Fixes wurde nicht durchgeführt, da die Fixes rein additiv / bugfixend sind (kein Token-Mapping verändert, keine Mapping-Tabelle erweitert).

### Reorganisation 2026-08-09

Am 2026-08-09 wurden die `SETxxx`-Routinen (`:SETQUALITY-HEVC` bis `:SETCHKENC`) **vor `:MAIN`** verschoben. Reihenfolge jetzt:

```
:INIT → :SETQUALITY-HEVC → :SETQUALITY-H264 → :SETENCODER → :SETAUDIO → :SETCROP
       → :SETFILTER → :SETMODE → :SETDECODER → :SETCHKENC → :MAIN → ...
```

Funktional **keine** Auswirkung: cmd.exe braucht keine Forward-Declarations, `call :FOO` springt unabhängig von der Label-Position. Der Schritt war rein organisatorisch — Hauptkonfig oben, Verarbeitungs-Routinen (`:EDIT_TAGS`, `:REMUX_IF_NEEDED`, `:RUN_PROBE`) bleiben unten. `:SETESC` und `:SETTOKEN` wurden **nicht** mit verschoben (bleiben unten) — bewusste Entscheidung, um den INIT-Block unverändert zu lassen.

Konsequenz für die Zeilennummern in diesem Dokument: viele `MAIN`-interne Zeilennummern (D1–D6, Aufruf-Stellen) haben sich verschoben — siehe die aktualisierten Stellen unten.

### Akzeptierte "Bugs" (NICHT erneut flaggen ohne Rückfrage)

Diese Punkte wurden in einem Review zunächst als potentielle Bugs gemeldet und vom User explizit als **gewollt und in Ordnung** bestätigt. Sie dürfen in zukünftigen Reviews nicht erneut als Issues markiert werden, sofern sich die Plattform-Anforderungen nicht ändern:

1. **`[string]::IsNullOrWhiteSpace` im EDIT_TAGS-Block** — erfordert PowerShell 3.0+. Auf Windows 11 mit PS 5.1 kein Problem.
2. **AV1-Encoder nutzt `SETQUALITY-HEVC`** (Mapping in `:MAIN` Z. 293–294) — keine eigene AV1-Qualitätstabelle. Bewusste Designentscheidung.

### Aktive Fixes (Stand 2026-08-09)

Diese Fixes sind in **beide** Wrapper (`nvencc64_wrapper.cmd` und `ffmpeg_wrapper.cmd`) übernommen. Die Zeilennummern unterscheiden sich — siehe Tabelle.

| # | Fix                                          | nvencc64_wrapper.cmd        | ffmpeg_wrapper.cmd          |
|---|----------------------------------------------|-----------------------------|-----------------------------|
| 1 | SET-Datei-Encoding hart ASCII                | Z. 940                      | Z. 997                      |
| 2 | Debug-Instrumentierung in EDIT_TAGS          | Z. 411–499 (EDIT_TAGS…EDIT_TAGS_CLEANUP) | Z. 451–539 (EDIT_TAGS…EDIT_TAGS_CLEANUP) |
| 3 | `:REMUX_IF_NEEDED` Lavf-Fix                  | Z. 504, Calls Z. 279/361    | Z. 544, Calls Z. 298/407    |

Im Detail:

1. **SET-Datei-Encoding hart ASCII**: `Out-File -Encoding Default` → `[System.IO.File]::WriteAllText($SetFile, ..., [System.Text.Encoding]::ASCII)`. Grund: BOM-Risiko bei `Out-File -Encoding Default` auf manchen Setups. Mit ASCII ist es deterministisch.

2. **Debug-Instrumentierung in EDIT_TAGS**: Zehn `%DBG%`-Marker geben bei `set DEBUG=1` Einsicht in Dateigröße vor/nach, Marker-Lines, PS-Exit, SET-File-Größe, EDIT_ACTIONS-Länge+Header, mkvpropedit-Exit, mediainfo/ffprobe-Verifikation. Hinter `%DBG%` (siehe INIT) — kein Overhead, wenn Debug aus. Umgebungsvariable wurde von `DEBUG_AUTOCROP` auf `DEBUG` umbenannt, weil sie jetzt mehr als nur Auto-Crop debuggt (auch EDIT_TAGS und REMUX_IF_NEEDED). `set "DEBUG=0"` steht explizit am Anfang jedes Wrappers und überschreibt damit eventuelle Environment-Variablen.

3. **Lavf-Kompatibilitäts-Fix via `:REMUX_IF_NEEDED`**: nvencc64 nutzt für MKV-Output den FFmpeg-Lavf-Muxer (avcodec muxer), dessen Output von MediaInfo / Windows-Property-Handler nicht voll geparst wird (Symptom: 0×0 in Explorer, "alle Tags weg"). Nach EDIT_TAGS prüft die Funktion generisch:
   - **Branch 1 (komplett kaputt, ff_streams=0)**: Source nach `_Check` verschieben, dann `_Converted`-Datei löschen — NUR wenn move erfolgreich war, und NUR wenn Pfade unterschiedlich sind (sonst wäre die Datei schon weg). Reihenfolge: erst `move`, dann `del` (sonst Datenverlust bei move-Fehler).
   - **Branch 2 (Lavf-Inkompatibilität, ff_streams>0 aber mi_video_count leer)**: `mkvmerge -o tmp file && move tmp file` zur Container-Normalisierung.
   - Generischer Ansatz, weil er nicht von einem bestimmten Muxer abhängt — jede Container-Inkompatibilität wird erkannt.
   - **Wichtiger Implementierungs-Hinweis**: Branches werden via `goto :BRANCH_BROKEN` / `goto :BRANCH_HEALTHY` getrennt, NICHT via `if (...)` mit Klammern. Hintergrund: mit `setlocal EnableDelayedExpansion` + `%DBG%`-Makro-Ersetzung hat die `if`-Variante die Bedingung nicht zuverlässig ausgewertet (Empirie aus Debug-Logs: `is_broken=0` wurde angezeigt, aber Branch-1-Code lief trotzdem). Mit `goto` ist die Logik eindeutig.
   - **Subshell-Pattern für mediainfo**: Innerhalb von `setlocal EnableDelayedExpansion` würde `for /f "usebackq" %%V in ('mediainfo "--Inform=General;%VideoCount%" ...')` das `%VideoCount%` als leere Variable interpretieren (ergibt leeren String). Daher wird `cmd /c` als Subshell eingesetzt — darin werden `%%X%%` zu `%X%` aufgelöst, und mediainfo bekommt den korrekten Template-Token. Wird in EDIT_TAGS (für `%Width%x%Height%` etc.) und in `:REMUX_IF_NEEDED` (für `%VideoCount%`) einheitlich verwendet.

### Akzeptierte Design-Issues (NICHT erneut flaggen ohne Rückfrage)

Auch diese wurden explizit als gewollt bestätigt:

- **D1** (Z. 841–842): `$Top`/`$Bottom` enthalten Seiten-Crop-Werte, nicht Top/Bottom. Irreführend, aber funktional korrekt.
- **D2** (Z. 246, in `:MAIN`): Fragmentierte `RESIZE_REQUIRED`-Logik über mehrere MAIN-Stellen verteilt. Funktioniert wie intendiert.
- **D3** (Z. 365–368, in `:MAIN`): 5-Sekunden-Wartezeit zwischen Encodes (`for /L 5,-1,1` × `timeout /t 1`). Bewusste Drosselung.
- **D4** (Z. 276, in `:MAIN`): Dead-looking `powershell write-output` URL-Print — absichtlicher Notification-Hook auf stdout.
- **D5** (Z. 229, in `:MAIN`): `_Converted`-Verzeichnis wird unbedingt erstellt, auch wenn keine Medien gefunden werden. Akzeptiert.
- **D6** (Z. 276, in `:MAIN`): URL-Print vor dem ersten `mediainfo`-Aufruf pro Datei. Akzeptiert.
- **D7**: `:REMUX_IF_NEEDED` re-muxt jede Datei, bei der `ffprobe` Tracks sieht, `mediainfo` aber nicht. Generischer Ansatz statt expliziter Lavf-Heuristik — kostet pro Aufruf zwei Tool-Invocations (ffprobe + mediainfo), bringt aber Robustheit gegen alle Container-Inkompatibilitäten.
- **D8**: CMDPATH-basierte Modell-Pfade (siehe Abschnitt oben) statt `%~dp0`-basiert. Bewusste Architekturentscheidung gegen skript-relatives Deployment.

## ffmpeg_wrapper.cmd — Paralleler Wrapper

Analog zu `nvencc64_wrapper.cmd` existiert `ffmpeg_wrapper.cmd` (Software-Encoder via FFmpeg). Er hat die gleiche Struktur: gleiche `SETxxx`-Routinen, gleiches EDIT_TAGS, gleiches `:REMUX_IF_NEEDED`. Die Fixes #1–#3 sind 1:1 übernommen. Wenn ein Fix in einem Wrapper gefunden/gefixt wird, muss er im anderen Wrapper nachgezogen werden — sie sind Code-Zwillinge.

Unterschiede sind rein encoder-spezifisch (CLI-Args für ffmpeg vs nvencc64), nicht in der Steuerlogik. Kein separater Dry-Run dokumentiert — die Mapping-Tabellen sind geteilt.

## Konventionen für Erweiterungen

Bei Änderungen oder Erweiterungen an `nvencc64_wrapper.cmd` **oder** `ffmpeg_wrapper.cmd` (siehe vorheriger Abschnitt — beide müssen synchron gehalten werden):

- **Token-Validierung erweitern?** Jedes neue Token muss in **beide** Listen: `TOK_*` in `:SETTOKEN` (Z. 703) und als `if`-Branch in der entsprechenden `:SETxxx`-Routine.
- **Neue Filter/Mode-Tokens mit Resize?** Prüfe, ob die Ausgabe `--vpp-resize` enthält — die Erkennung in Z. 22–29 steuert, ob ein zusätzliches `--vpp-resize spline36` injiziert wird. Bei true sollte der Token dort nicht doppelt resize hinzufügen.
- **Neue Encoder?** Analog zu AV1 entweder explizit auf `SETQUALITY-HEVC` mappen (mit Kommentar warum) oder eigene `:SETQUALITY-<NAME>`-Routine schreiben.
- **Neue PS-Sub-Skripte?** Marker-Format `#PS_<NAME>_BEGIN#` / `#PS_<NAME>_END#` verwenden, Block am Ende der `.cmd` anhängen, Extraction-Logik aus `:EDIT_TAGS` (Z. 411) oder `:RUN_PROBE` (Z. 564) kopieren.
- **Neue Branches in :REMUX_IF_NEEDED?** `goto` verwenden, nicht `if`-Klammern (siehe Hinweis in Aktive Fixes #3).
