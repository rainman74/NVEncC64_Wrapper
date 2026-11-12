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
| 4 | Check-Encoded-Block: Re-Mux via mkvmerge    | Z. 270–296                  | Z. 286–321 (auch `%%Format%%` statt `%Format%` in Z. 269 für delayed-expansion-kompatibles mediainfo-Template) |
| 5 | SETCROP-Tokens: nur Resize, kein impliziter Crop mehr | Z. 107–150                | Z. 128–172                  |
| 6 | ffmpeg-AQ-Optionen: Bindestrich statt Unterstrich    | (n/a — nvencc)             | Z. 419                       |

Im Detail:

1. **SET-Datei-Encoding hart ASCII**: `Out-File -Encoding Default` → `[System.IO.File]::WriteAllText($SetFile, ..., [System.Text.Encoding]::ASCII)`. Grund: BOM-Risiko bei `Out-File -Encoding Default` auf manchen Setups. Mit ASCII ist es deterministisch.

2. **Debug-Instrumentierung in EDIT_TAGS**: Zehn `%DBG%`-Marker geben bei `set DEBUG=1` Einsicht in Dateigröße vor/nach, Marker-Lines, PS-Exit, SET-File-Größe, EDIT_ACTIONS-Länge+Header, mkvpropedit-Exit, mediainfo/ffprobe-Verifikation. Hinter `%DBG%` (siehe INIT) — kein Overhead, wenn Debug aus. Umgebungsvariable wurde von `DEBUG_AUTOCROP` auf `DEBUG` umbenannt, weil sie jetzt mehr als nur Auto-Crop debuggt (auch EDIT_TAGS und REMUX_IF_NEEDED). `set "DEBUG=0"` steht explizit am Anfang jedes Wrappers und überschreibt damit eventuelle Environment-Variablen.

3. **Lavf-Kompatibilitäts-Fix via `:REMUX_IF_NEEDED`**: nvencc64 nutzt für MKV-Output den FFmpeg-Lavf-Muxer (avcodec muxer), dessen Output von MediaInfo / Windows-Property-Handler nicht voll geparst wird (Symptom: 0×0 in Explorer, "alle Tags weg"). Nach EDIT_TAGS prüft die Funktion generisch:
   - **Branch 1 (komplett kaputt, ff_streams=0)**: Source nach `_Check` verschieben, dann `_Converted`-Datei löschen — NUR wenn move erfolgreich war, und NUR wenn Pfade unterschiedlich sind (sonst wäre die Datei schon weg). Reihenfolge: erst `move`, dann `del` (sonst Datenverlust bei move-Fehler).
   - **Branch 2 (Lavf-Inkompatibilität, ff_streams>0 aber mi_video_count leer)**: `mkvmerge -o tmp file && move tmp file` zur Container-Normalisierung.
   - Generischer Ansatz, weil er nicht von einem bestimmten Muxer abhängt — jede Container-Inkompatibilität wird erkannt.
   - **Wichtiger Implementierungs-Hinweis**: Branches werden via `goto :BRANCH_BROKEN` / `goto :BRANCH_HEALTHY` getrennt, NICHT via `if (...)` mit Klammern. Hintergrund: mit `setlocal EnableDelayedExpansion` + `%DBG%`-Makro-Ersetzung hat die `if`-Variante die Bedingung nicht zuverlässig ausgewertet (Empirie aus Debug-Logs: `is_broken=0` wurde angezeigt, aber Branch-1-Code lief trotzdem). Mit `goto` ist die Logik eindeutig.
   - **Subshell-Pattern für mediainfo**: Innerhalb von `setlocal EnableDelayedExpansion` würde `for /f "usebackq" %%V in ('mediainfo "--Inform=General;%VideoCount%" ...')` das `%VideoCount%` als leere Variable interpretieren (ergibt leeren String). Daher wird `cmd /c` als Subshell eingesetzt — darin werden `%%X%%` zu `%X%` aufgelöst, und mediainfo bekommt den korrekten Template-Token. Wird in EDIT_TAGS (für `%Width%x%Height%` etc.) und in `:REMUX_IF_NEEDED` (für `%VideoCount%`) einheitlich verwendet.

4. **Check-Encoded-Block: Re-Mux via mkvmerge** (Z. 268–290): Für Source-Dateien mit Container != `.mkv` (z.B. `.mp4`/`.mov`/`.avi`/`.webm`, die schon im Ziel-Codec vorliegen), wird die Datei via `mkvmerge -o` re-encodet statt nur per `move` umbenannt. Hintergrund: Eine `.mp4` in `.mkv` umzubenennen erzeugt kein gültiges Matroska (Inhalt bleibt MP4-Box-Format), EDIT_TAGS (`mkvpropedit`) scheitert mit "not a Matroska file", der EDIT_TAGS-Fehlerbehandler (Z. 484) verschiebt sie nach `_Check`. Symptom: Datei geht erst nach `_Converted`, dann sofort nach `_Check` (zwei Moves). Re-Mux via mkvmerge ist schnell (Sekunden, kein Re-Encode), produziert echtes MKV-Container-Format. Für bereits `.mkv`-quellen bleibt der einfache `move`. Fallback bei mkvmerge-Fehler: einfacher `move` (mit Warnung) — Datei bleibt dann vermutlich kaputt in `_Converted`. WARNING-Message ist kontextspezifisch: `.mkv` → "Moving to", sonst → "Re-muxing to".

5. **SETCROP-Tokens aufgeräumt** (nvencc Z. 107–150, ffmpeg Z. 128–172): Tokens sind reine Resize-Befehle (`--output-res` / `scale=`), kein impliziter Crop mehr (frühere Werte wie `--crop 60,0,60,0` bei `c720` waren willkürlich und haben das Aspect-Ratio versteckt verändert). Die Tokens bedeuten jetzt:
   - **`none`**: kein Crop, kein Resize (Source bleibt wie sie ist)
   - **`auto`**: CROP_MODE=AUTO, RUN_PROBE ermittelt Crop autonom (impliziter H/V-Crop für Letterbox/Pillarbox)
   - **`43`** → `--output-res 720x540` (4:3-Format)
   - **`169`** → `--output-res 960x540` (16:9-Format)
   - **`c696`-`c1040`** → nur V-Crop auf Ziel-Höhe (Aspect-Ratio ändert sich, für 16:9 mit Letterbox oben+unten gedacht)
   - **`c720`/`c720p`/`c720f`**, **`c1080`/`c1080p`/`c1080f`**, **`c2160`/`c2160p`/`c2160f`**: Resize auf Standard-HD-Auflösungen, `f`-Varianten erzwingen fixe Dimension (kann zu Verzerrung führen wenn Source nicht passend)
   - **`c1348`**, **`c1440`**: nur Resize auf 4:3-Format (Aspect-Ratio ändert sich, für 16:9-Source in 4:3-Container gedacht)
   - **`c1408`-`c1800`**: nur Resize auf DVD-PAL-Auflösungen (Aspect-Ratio-Verzerrung wenn Source 16:9 ist, also nur für 4:3-Source gedacht)
   - **`c1`-`c6`**: keine (leer) — früher als User-Defined-Slots dokumentiert, aktuell ungenutzt

   **Faustregel**: Für Letterbox/Pillarbox-Entfernung → `c0+auto` (oder in Verbindung mit einem Resize-Token). Die expliziten Tokens machen nur Resize, keinen impliziten Crop. ffmpeg_wrapper hatte ursprünglich nur c1420-c1800, c1408 und c1620 wurden für 1:1-Sync zum nvencc_wrapper nachgerüstet.

6. **ffmpeg-Wrapper: AQ-Optionen Bindestrich statt Unterstrich** (ffmpeg Z. 419): `-spatial_aq:v` → `-spatial-aq:v`, `-temporal_aq:v` → `-temporal-aq:v`. Die anderen Optionen im Aufruf (`-aq-strength:v`, `-rc-lookahead:v`, `-multipass:v`) waren schon mit Bindestrich. Symptom des Bugs: `Unrecognized option 'spatial_aq:v'. Error splitting the argument list: Option not found` direkt beim ffmpeg-Start.

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

> **Stand 2026-11-12**: `ffmpeg_wrapper.cmd` ist **nicht** in diesem Repo; die aktive Quelle liegt im Schwester-Repo `D:\Sources\FFmpeg_Wrapper\` (dort committed) und deployed unter `D:\Apps\Commands\bin\ffmpeg_wrapper.cmd`. Die Sektion bleibt hier als Referenz.

Analog zu `nvencc64_wrapper.cmd` existiert `ffmpeg_wrapper.cmd` (Software-Encoder via FFmpeg). Er hat die gleiche Struktur: gleiche `SETxxx`-Routinen, gleiches EDIT_TAGS, gleiches `:REMUX_IF_NEEDED`. Die Fixes #1–#4 sind 1:1 übernommen. **Sonderfall Fix #4 im ffmpeg_wrapper**: zusätzlich wurde Z. 269 von `--Inform=Video;%Format%` auf `--Inform=Video;%%Format%%` korrigiert (im nvencc_wrapper war das schon korrekt). Mit dem einfachen `%Format%` und globalem `setlocal enabledelayedexpansion` wurde die Variable zu leer expandiert, mediainfo bekam kein Template-Token, `SRC_CODEC` blieb leer, Check-Encoded triggerte nie.

Unterschiede sind rein encoder-spezifisch (CLI-Args für ffmpeg vs nvencc64), nicht in der Steuerlogik. Kein separater Dry-Run dokumentiert — die Mapping-Tabellen sind geteilt.

## move-all.cmd — Aufräumarbeiten (Stand 2026-11-12)

`move-all` ist ein Hilfsskript (kein Encoder-Wrapper), deployt nach `%CMDPATH%\bin\`. Das frühere Schwester-Skript `sort-all.cmd` wurde am **2026-11-12** auf Wunsch gelöscht (Repo- und Deploy-Kopie) — es wurde im aktuellen Flow seit längerem nicht mehr verwendet.

- **attrib-Stdout-Falle in `move-all`**: `attrib -h "…checked" 2>NUL` unterdrückt die Meldung „Datei … nicht gefunden" **nicht** — `attrib` schreibt sie nach stdout, `2>NUL` fängt nur stderr. Im alten Flow entstand dadurch pro verschobener Datei eine Fehlerzeile. Ersetzt durch direktes `del /A /F /Q "…checked" >NUL 2>&1` (löscht versteckte Dateien direkt, ein Prozessaufruf weniger).
- **Serien-Heuristik erweitert**: statt `findstr /i "S0 S1"` jetzt `findstr /i /r /c:"S[0-9][0-9]" /c:"S[0-9]E[0-9]"` (alle drei Vorkommen: HQ/LQ-Block, Root-Block, `_Converted`-Block). Deckt S01–S99 ab — vorher wurden nur S0x/S1x erkannt, z. B. `Navy CIS - S23E01` landete fälschlich in `#Eltern Filme`. Einstellige Staffeln mit Episodenmarker (`S1E10`, `S9E5`) laufen weiter über das zweite Muster (das frühere Literal `S1` hatte sie mitgefangen). Falsch-Positive wie `S1m0ne (2002)` werden vermieden.
- **`.checked`-Marker entfernt**: Marker wurden ausschließlich von `sort-all` erzeugt/gelesen (Probe-Cache: Dateien ohne Crop wurden bei späteren sort-all-Läufen übersprungen) und von `move-all` gelöscht. Mit dem Löschen von `sort-all` ist die Marker-Logik komplett entfallen — `move-all` enthält keine Marker-Erzeugung/-Löschung mehr.

## clean-all.cmd — Sidecar-Pass (Stand 2026-11-12)

`clean-all.cmd` (aufgerufen über `_clean.cmd` in den Zielordnern) sortiert lose Dateien in Filmordner. Es war **rein MKV-getrieben**: verarbeitet wurde nur, was als loses `.mkv` vorliegt; der Ordner-/Zielname wird aus dem MKV-Namen abgeleitet. Nachzügler-Sidecars blieben dadurch liegen, wenn der Filmordner bereits existierte und das MKV schon darin lag — konkreter Fall: `Unschuld und Verlangen (2021)-poster.jpg` in `E:\Videos\#Eltern Filme`.

**Pass 2** (nach der MKV-Schleife) verschiebt verwaiste Sidecars zu bereits existierenden Ordnern:
- Muster `<Ordner>-*` und `<Ordner>.*`, nur wenn der Ordner existiert; ausgeschlossen sind `_Converted`, `_Check`, `_HEVC` sowie Medien-Endungen (`.mkv/.mp4/.avi/.mov/.webm/.mpg`).
- **Policy A (vom User gewählt): lose Datei gewinnt** → `move /Y`, **ohne zusätzliche Ausgaben** (bewusst keine Echo-Zeilen/Log-Meldungen; der Lauf bleibt so still wie vorher). Hintergrund: `move` überschreibt in dieser Umgebung auch ohne `/Y` still; die auf 490x720 normalisierten Poster (aus `poster.cmd`) sind die gewünschte Version und sollen tMM-Scrapes (480x720) ersetzen.
- Grenzen: Präfix-Kollisionen bei Ordnernamen, die Präfixe voneinander sind (`Film` vs. `Film-2`); Sprachsuffixe (`-poster.de.jpg`) werden nicht erkannt; Nachzügler ohne existierenden Ordner bleiben liegen; Serien-Naming (`Navy CIS - S23E01-thumb.jpg` → `Navy CIS\Staffel N`) ist nicht abgedeckt.
- **Warnung zu `:ProcessCopy`**: Bei `<Titel> (1).mkv` löscht clean-all das Original und benennt die `(1)`-Kopie um — nicht ausführen, solange ein Download oder eine Kopie noch läuft.

## Konventionen für Erweiterungen

Bei Änderungen oder Erweiterungen an `nvencc64_wrapper.cmd` **oder** `ffmpeg_wrapper.cmd` (siehe vorheriger Abschnitt — beide müssen synchron gehalten werden):

- **Token-Validierung erweitern?** Jedes neue Token muss in **beide** Listen: `TOK_*` in `:SETTOKEN` (Z. 703) und als `if`-Branch in der entsprechenden `:SETxxx`-Routine.
- **Neue Filter/Mode-Tokens mit Resize?** Prüfe, ob die Ausgabe `--vpp-resize` enthält — die Erkennung in Z. 22–29 steuert, ob ein zusätzliches `--vpp-resize spline36` injiziert wird. Bei true sollte der Token dort nicht doppelt resize hinzufügen.
- **Neue Encoder?** Analog zu AV1 entweder explizit auf `SETQUALITY-HEVC` mappen (mit Kommentar warum) oder eigene `:SETQUALITY-<NAME>`-Routine schreiben.
- **Neue PS-Sub-Skripte?** Marker-Format `#PS_<NAME>_BEGIN#` / `#PS_<NAME>_END#` verwenden, Block am Ende der `.cmd` anhängen, Extraction-Logik aus `:EDIT_TAGS` (Z. 411) oder `:RUN_PROBE` (Z. 564) kopieren.
- **Neue Branches in :REMUX_IF_NEEDED?** `goto` verwenden, nicht `if`-Klammern (siehe Hinweis in Aktive Fixes #3).

## Meldungen, Pipeline & Deployment (Stand 2026-11-12)

- **Stiller Leerlauf**: `echo No files found.` und die Abschlusszeile `[INFO] Savings: …` wurden aus `nvencc64_wrapper.cmd` und `ffmpeg_wrapper.cmd` (sowie aus den Convertern des FFmpeg_Wrapper-Repos) **entfernt**. Bei leerem Ordner/„nichts zu tun" gibt der Wrapper jetzt **keine** Ausgabe mehr aus (Exit 0). Grund: Es waren keine Fehler, der User wollte sie nicht sehen.
- **Alte Pipeline entfernt**: `sort-all.cmd` gelöscht; die Starter `_1_sort.cmd`, `_2_encode.cmd`, `_3_move.cmd` (in `%CMDPATH%\bin\scripts\`) gelöscht; `encode-edit.cmd` gelöscht (referenzierte das gelöschte `sort-all.cmd`). Der Workflow läuft über `clean-all` / `encode-all` / `move-all`.
- **README.md** erweitert: neuer Abschnitt „Hilfsskripte im `bin`" (encode-all, move-all inkl. Serien-Heuristik/`.checked`-Wegfall, clean-all inkl. `:ProcessCopy`-Warnung), Features-Bullet „Hilfsskripte", Arbeitsablauf-Punkt 4 (Savings) präzisiert; Hinweis auf entfernte Pipeline/Lean-Meldungen.
- **Repo vs. `bin`**: Das Repo enthält die sanitisierte Version von `nvencc64_wrapper.cmd`. **Custom Crops und Filter (`cX`/`fX`) sind nicht zu beachten** — private Token-Werte im `bin` (`smooth`, `nlmeans`, `f1`–`f3` mit eigenen `--vpp-*`-Ketten, z. B. realesrgan/msmooth/chromashift) sind nur temporär, jederzeit zurücksetzbar und werden nicht benötigt. `.___PUSH___.cmd` überschreibt `bin` direkt; kein Sichern/Zurückspielen.
- **Deployment**: `.___PUSH___.cmd` aus dem Repo-Root (xcopy `*.cmd` → `%CMDPATH%\bin`, `git add .`, Commit „Updates", `git push`). `README.md`, `.___CLAUDE___.cmd`, `.___PUSH___.cmd` sind von der Kopie ausgeschlossen.
