# Project: NVEncC64_Wrapper

Wrapper-Skript für `nvencc64.exe` (NVIDIA Hardware-Encoder). Hauptsächlich eine `.cmd`-Datei plus zugehörige Hilfs-Skripte.

> **Dokument-Stand: 2026-11-25 (Review-Nachtrag 2026-11-27).** Abgleich gegen den Repo-Code: `nvencc64_wrapper.cmd` = 1050 Zeilen (Commit `b340600`; Basis `5c34ad0` + 1772-Ergänzung); `ffmpeg_wrapper.cmd` = 1004 Zeilen, Commit `83c3e74` (Schwester-Repo `D:\Sources\FFmpeg_Wrapper`); `nvencc64_wrapper2.cmd` = 1267 Zeilen (HD/Full-HD-Extension, Stand 2026-11-27). **Alle Zeilenangaben in diesem Dokument beziehen sich auf diesen Stand** — bei Code-Änderungen Zeilenangaben mitpflegen (oder Abschnitt „Toter Code" als Referenz nutzen, dort steht das Prüfverfahren).
>
> **Korrekturen 2026-11-25 (Doku-Drift beseitigt):** Pfad-Setup (Z. 7–9 nutzt `%CMDPATH%\bin\nvvfx_models`, nicht `NVVFX_MODEL_DIR`), Zeilennummern in Fixes-Tabelle/D1–D6/Konventionen, Token-Naming in SETCROP (kein `c`-Präfix), SETCROP-Semantik (teils Crop + Resize, nicht „nur Resize"), Token-Zahl (134 statt 125), `cmd /c`-Subshell-Aussage, ffmpeg_wrapper-Divergenz. **Nachtrag:** `1772` als horizontale Standardbreite + Crop-Token in beiden Wrappern (nvencc Z. 152/814/882; Auto-Erkennung funktional getestet); ffmpeg-Baseline auf `83c3e74`/1004 Zeilen aktualisiert.

## Target Platform

Dieses Projekt läuft ausschließlich auf **Windows 11** mit **PowerShell 5.1+**.

Folge daraus:
- PowerShell 3.0+-Features (z.B. `[string]::IsNullOrWhiteSpace`) sind verfügbar — kein Workaround nötig.
- Codepage für `call` von generierten `.cmd`-Dateien ist Windows-1252 (deutsche Locale) — Sonderzeichen in Dateinamen/Track-Namen funktionieren.
- In den PS-Blöcken wird ASCII-Encoding deterministisch erzwungen (siehe Aktive Fixes #1): `EDIT_TAGS` schreibt die SET-Datei per `[System.IO.File]::WriteAllText(..., ASCII)` (Z. 1049), `RUN_PROBE` per `Out-File -Encoding ASCII` (Z. 923/932/956). `Out-File -Encoding Default` kommt im Wrapper nicht vor.

## Pfad-Setup (CMDPATH-basiert)

Der Wrapper ist **explizit nicht** skript-relativ, sondern nutzt den System-`CMDPATH`. Architekturentscheidung mit Konsequenzen:

```batch
REM Z. 7-9 im INIT-Block (Stand 2026-11-25):
set "VFX_MODEL_DIR=%CMDPATH%\bin\nvvfx_models"
set "ONNX_MODEL_DIR=%CMDPATH%\bin\onnx_models"
set "NV_FLAGS=--vpp-onnx-model-dir "%ONNX_MODEL_DIR%" --vpp-nvvfx-model-dir "%VFX_MODEL_DIR%""
```

> **Korrektur 2026-11-25:** Eine frühere Fassung dieses Abschnitts zeigte `set "VFX_MODEL_DIR=%NVVFX_MODEL_DIR%"` und verlangte ein Modell-Verzeichnis unter `C:\Program Files\NVIDIA Corporation\…`. Das ist seit Commit `4bdf067` überholt: die Repo-Version holt **beide** Modellordner aus `%CMDPATH%\bin\`; `NVVFX_MODEL_DIR` kommt in `nvencc64_wrapper.cmd` nicht mehr vor.

**Voraussetzungen für korrekte Funktion:**
- `CMDPATH` muss auf das Verzeichnis zeigen, in dem `bin\onnx_models\` **und** `bin\nvvfx_models\` liegen (typisch: zentrale Toolchain wie `D:\Apps\Commands`)

**Warum nicht `%~dp0`?** Der Wrapper kann unabhängig von der Toolchain-Installation in beliebigen Verzeichnissen liegen (z.B. `D:\Sources\NVEncC64_Wrapper\`), während die Modelle zentral vorgehalten werden. Bei einer reinen `%~dp0`-basierten Variante müsste `bin\onnx_models\` zwingend neben dem Wrapper liegen — das schränkt die Deployment-Optionen ein.

**Konsequenz für Tests:** Bei CMDPATH=`D:\Apps\Commands` müssen `onnx_models` unter `D:\Apps\Commands\bin\onnx_models\` und `nvvfx_models` unter `D:\Apps\Commands\bin\nvvfx_models\` liegen. Wer den Wrapper auf einem anderen System laufen lässt, muss CMDPATH entsprechend setzen.

## nvencc64_wrapper.cmd — Dry-Run-Status

Am **2026-07-21** wurde ein vollständiger statischer Dry-Run der Datei `nvencc64_wrapper.cmd` durchgeführt (damaliger Dateistand).

**Ergebnis (damals):** Skript ist valide. 125/125 Tokens waren in den Mapping-Tabellen abgedeckt. 22 End-to-End-Szenarien PASS.

**Abgleich 2026-11-25 (heutige Datei, 1050 Zeilen):** **134 gültige Tokens** — 127 in den sieben 1:1-Tabellen (`TOK_ENCODER` 5, `TOK_AUDIO` 9, `TOK_CROP` 47, `TOK_FILTER` 32, `TOK_MODE` 27, `TOK_DECODER` 4, `TOK_CHKENC` 3), dazu `TOK_QUALITY` 6 und `TOK_SEEK` 1. Mapping-Abgleich mechanisch geprüft: 0 Tokens ohne Branch, 0 Branches ohne Token (Details im Abschnitt „Toter Code").

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
2. **AV1-Encoder nutzt `SETQUALITY-HEVC`** (Mapping in `:MAIN` Z. 339–340) — keine eigene AV1-Qualitätstabelle. Bewusste Designentscheidung.

### Aktive Fixes (Stand 2026-08-09; Zeilenangaben abgeglichen 2026-11-25)

Diese Fixes sind in **beide** Wrapper (`nvencc64_wrapper.cmd` und `ffmpeg_wrapper.cmd`) übernommen. Die Zeilennummern unterscheiden sich — siehe Tabelle.

| # | Fix                                          | nvencc64_wrapper.cmd        | ffmpeg_wrapper.cmd          |
|---|----------------------------------------------|-----------------------------|-----------------------------|
| 1 | SET-Datei-Encoding hart ASCII                | Z. 923/932/956 (`Out-File -Encoding ASCII`), Z. 1049 (`WriteAllText`) | Z. 877/886/910 (`Out-File -Encoding ASCII`), Z. 1003 (`WriteAllText`) |
| 2 | Debug-Instrumentierung in EDIT_TAGS          | Z. 509–600 (EDIT_TAGS…EDIT_TAGS_CLEANUP), 19 `%DBG%` | Z. 458–546 (EDIT_TAGS…EDIT_TAGS_CLEANUP) |
| 3 | `:REMUX_IF_NEEDED` Lavf-Fix                  | Z. 602; Calls Z. 326/424    | Z. 551; Calls Z. 302/420    |
| 4 | Check-Encoded-Block: Re-Mux via mkvmerge    | Z. 296–327                  | Z. 272–303 (auch `%%Format%%` statt `%Format%` in Z. 254 für delayed-expansion-kompatibles mediainfo-Template) |
| 5 | SETCROP-Tokens: explizite Crop-/Resize-Ketten | Z. 111–163                 | Z. 96–146                   |
| 6 | ffmpeg-AQ-Optionen: Bindestrich statt Unterstrich | (n/a — nvencc)        | Z. 401                       |

> Die früher hier genannten Nummern (nvencc: 940/411–499/504/279+361/270–296/107–150; ffmpeg: 997/451–539/544/298+407/286–321/419) stammten von älteren Dateiständen und sind damit überholt. Stand 2026-11-25: nvencc 1050 Zeilen (Commit `b340600`), ffmpeg 1004 Zeilen (Commit `83c3e74`).

Im Detail:

1. **SET-Datei-Encoding hart ASCII**: ASCII wird in beiden PS-Blöcken erzwungen — `EDIT_TAGS` schreibt die SET-Datei per `[System.IO.File]::WriteAllText($SetFile, ..., [System.Text.Encoding]::ASCII)` (nvencc Z. 1049), `RUN_PROBE` per `Out-File -Encoding ASCII` (nvencc Z. 923/932/956). Grund: BOM-Risiko bei `Out-File -Encoding Default` auf manchen Setups. Mit ASCII ist es deterministisch; `Out-File -Encoding Default` kommt in den Wrappern nicht mehr vor.

2. **Debug-Instrumentierung in EDIT_TAGS**: `%DBG%`-Marker (im ganzen nvencc-Wrapper **47** Stellen, davon 19 in EDIT_TAGS) geben bei `set DEBUG=1` Einsicht in Dateigröße vor/nach, Marker-Lines, PS-Exit, SET-File-Größe, EDIT_ACTIONS-Länge+Header, mkvpropedit-Exit, mediainfo/ffprobe-Verifikation. Hinter `%DBG%` (siehe INIT) — kein Overhead, wenn Debug aus. Umgebungsvariable wurde von `DEBUG_AUTOCROP` auf `DEBUG` umbenannt, weil sie jetzt mehr als nur Auto-Crop debuggt (auch EDIT_TAGS und REMUX_IF_NEEDED). `set "DEBUG=0"` steht explizit am Anfang jedes Wrappers und überschreibt damit eventuelle Environment-Variablen (siehe auch „Toter Code" — dadurch ist `:DEBUG` bis zum Datei-Edit unerreichbar).

3. **Lavf-Kompatibilitäts-Fix via `:REMUX_IF_NEEDED`**: nvencc64 nutzt für MKV-Output den FFmpeg-Lavf-Muxer (avcodec muxer), dessen Output von MediaInfo / Windows-Property-Handler nicht voll geparst wird (Symptom: 0×0 in Explorer, "alle Tags weg"). Nach EDIT_TAGS prüft die Funktion generisch:
   - **Branch 1 (komplett kaputt: `ffprobe` liefert keinen Wert oder 0 Streams)**: Source nach `_Check` verschieben, dann `_Converted`-Datei löschen — NUR wenn move erfolgreich war, und NUR wenn Pfade unterschiedlich sind (sonst wäre die Datei schon weg). Reihenfolge: erst `move`, dann `del` (sonst Datenverlust bei move-Fehler).
   - **Branch 2 (Lavf-Inkompatibilität, ff_streams>0 aber mi_video_count leer)**: `mkvmerge -o tmp file && move tmp file` zur Container-Normalisierung.
   - Generischer Ansatz, weil er nicht von einem bestimmten Muxer abhängt — jede Container-Inkompatibilität wird erkannt.
   - **Wichtiger Implementierungs-Hinweis**: Branches werden via `goto :BRANCH_BROKEN` / `goto :BRANCH_HEALTHY` getrennt, NICHT via `if (...)` mit Klammern. Hintergrund: mit `setlocal EnableDelayedExpansion` + `%DBG%`-Makro-Ersetzung hat die `if`-Variante die Bedingung nicht zuverlässig ausgewertet (Empirie aus Debug-Logs: `is_broken=0` wurde angezeigt, aber Branch-1-Code lief trotzdem). Mit `goto` ist die Logik eindeutig.
   - **Subshell-Pattern für mediainfo**: Innerhalb von `setlocal EnableDelayedExpansion` würde ein einfaches `%VideoCount%` als leere Umgebungsvariable expandieren — mediainfo bekäme kein Template-Token. Daher steht in den Aufrufen die verdoppelte Form `%%VideoCount%%` bzw. `%%Width%%x%%Height%%` (Z. 278, 588–593, 614). **Korrektur 2026-11-25:** Die Repo-Version ruft mediainfo dabei **ohne** `cmd /c`-Subshell auf; das ist auch nicht nötig — verifiziert mit `test.mkv`: `mediainfo "--Inform=Video;%%Format%%"` liefert `AVC`, die einfache `%Format%`-Variante liefert Müll (`Forced : No`). Die frühere `cmd /c`-Variante funktioniert ebenfalls, ist in der Repo-Version aber nicht implementiert.

4. **Check-Encoded-Block: Re-Mux via mkvmerge** (Z. 296–327): Für Source-Dateien mit Container != `.mkv` (z.B. `.mp4`/`.mov`/`.avi`/`.webm`, die schon im Ziel-Codec vorliegen), wird die Datei via `mkvmerge -o` re-encodet statt nur per `move` umbenannt. Hintergrund: Eine `.mp4` in `.mkv` umzubenennen erzeugt kein gültiges Matroska (Inhalt bleibt MP4-Box-Format), EDIT_TAGS (`mkvpropedit`) scheitert mit "not a Matroska file", der EDIT_TAGS-Fehlerbehandler (Z. 546–558 / 579–584) verschiebt sie nach `_Check`. Symptom: Datei geht erst nach `_Converted`, dann sofort nach `_Check` (zwei Moves). Re-Mux via mkvmerge ist schnell (Sekunden, kein Re-Encode), produziert echtes MKV-Container-Format. Für bereits `.mkv`-quellen bleibt der einfache `move`. Fallback bei mkvmerge-Fehler: einfacher `move` (mit Warnung) — Datei bleibt dann vermutlich kaputt in `_Converted`. WARNING-Message ist kontextspezifisch: `.mkv` → "Moving to", sonst → "Re-muxing to".

5. **SETCROP-Tokens: explizite Crop-/Resize-Ketten** (nvencc Z. 111–163, ffmpeg Z. 96–146): Die Tokens enthalten keinen impliziten *Default*-Crop mehr (kein automatisches `--crop` bei reinen Resize-Tokens). **Korrektur 2026-11-25:** Sie sind aber auch nicht „nur Resize" — pro Token ist die Kette explizit hinterlegt, teils Crop + Resize. Stand Repo-Code:
   - **`none`**: kein Crop, kein Resize (Source bleibt wie sie ist)
   - **`auto`**: `CROP_MODE=AUTO`, `RUN_PROBE` ermittelt Crop autonom (impliziter H/V-Crop für Letterbox/Pillarbox)
   - **`43`** → `--output-res 720x540` (4:3-Format)
   - **`169`** → `--output-res 960x540` (16:9-Format)
   - **`696`–`1040`** → nur V-Crop (`--crop 0,N,0,N`), kein Resize — für 16:9 mit Letterbox oben+unten gedacht
   - **`720`/`720p`/`720f`**, **`1080`/`1080p`/`1080f`**, **`2160`/`2160p`/`2160f`**: nur `--output-res` auf Standard-HD-Auflösungen; `f`-Varianten erzwingen fixe Dimension
   - **`1440`** → `--crop 240,0,240,0 --output-res 1440x1080`; **`1440f`** → nur `--output-res 1440x1080`
   - **`1348`/`1408`/`1420`/`1480`/`1500`/`1620`/`1764`/`1772`/`1780`/`1788`/`1792`/`1800`** → Seiten-Crop + `--output-res <N>x1080` (Crop-Werte: `1348`→286, `1408`→256, `1420`→250, `1480`→220, `1500`→210, `1620`→150, `1764`→78, **`1772`→74**, `1780`→70, `1788`→66, `1792`→64, `1800`→60)
   - **`c1`–`c6`**: keine (leer) — reservierte, aktuell ungenutzte Slots
   - **Horizontale Auto-Erkennung** (`$StandardWidths`, Z. 882): nutzt dieselben Standardbreiten inkl. `1772`; bei rein seitlichen Balken (`TotalV ≤ 2`, `TotalH > 8`) wird die nächstliegende Breite gewählt und beidseitig gecroppt (Test 2026-11-25 mit 74px-Balken → `74:0:74:0`, Res `1772x1080`).
   - **Token-Naming:** numerische Tokens haben **kein `c`-Präfix** (`696`, nicht `c696`); ein `c`-Präfix existiert nur bei `c1`–`c6`. Die frühere Doku-Schreibweise `c720`/`c696` stammt aus der `bin`-Variante.
   - **ffmpeg-Pendant:** Variable heißt dort `CROP_VAL` statt `CROP`; `696`–`1040` → `crop=1920:N:0:N` (nur Crop), `720*`/`1080*`/`2160*` → `zscale=w=…,h=…:filter=spline36` (seit 2026-11-25, vorher `scale=`), `1348`/`1420`/`1440`/`1480`/`1500`/`1764`/`1772`/`1780`/`1788`/`1792`/`1800` → `crop=…:1080:…` (nur Crop, **kein** `scale`; `1440f` → `crop=1440:1080:0:0`, `1772` → `crop=1772:1080:74:0`). Der ffmpeg-Wrapper hat **kein** `43`/`169`/`752`/`1408`/`1620` (Abgleich 2026-11-25).

   **Faustregel**: Für Letterbox/Pillarbox-Entfernung → `auto` (autonomer Probe-Crop) oder ein `696`–`1040`-Token. Die Tokens machen genau das, was hinterlegt ist — keinen zusätzlichen Crop.

6. **ffmpeg-Wrapper: AQ-Optionen Bindestrich statt Unterstrich** (ffmpeg Z. 401): `-spatial_aq:v` → `-spatial-aq:v`, `-temporal_aq:v` → `-temporal-aq:v`. Die anderen Optionen im Aufruf (`-aq-strength:v`, `-rc-lookahead:v`, `-multipass:v`) waren schon mit Bindestrich. Symptom des Bugs: `Unrecognized option 'spatial_aq:v'. Error splitting the argument list: Option not found` direkt beim ffmpeg-Start.

### Akzeptierte Design-Issues (NICHT erneut flaggen ohne Rückfrage)

Auch diese wurden explizit als gewollt bestätigt:

- **D1** (Z. 950–951): `$Top`/`$Bottom` enthalten Seiten-Crop-Werte, nicht Top/Bottom. Irreführend, aber funktional korrekt.
- **D2** (Z. 380–386 und 401–403, in `:MAIN`): Fragmentierte `RESIZE_REQUIRED`-Logik über mehrere MAIN-Stellen verteilt. Funktioniert wie intendiert. Detail: `RESIZE_REQUIRED=1` setzt nur der Token-Pfad (Z. 383); der AUTO-Crop-Pfad setzt es nie (Z. 366) — `--vpp-resize spline36` wird daher nur bei Resize-Tokens injiziert.
- **D3** (Z. 427–430, in `:MAIN`): 5-Sekunden-Wartezeit zwischen Encodes (`for /L 5,-1,1` × `timeout /t 1`). Bewusste Drosselung.
- **D4** (Z. 322, in `:MAIN`, TARGET_DIR-Pfad): Dead-looking `powershell write-output` URL-Print — absichtlicher Notification-Hook auf stdout.
- **D5** (Z. 248, in `:MAIN`): `_Converted`-Verzeichnis wird unbedingt erstellt, auch wenn keine Medien gefunden werden. Akzeptiert.
- **D6** (Z. 388, in `:MAIN`, Encode-Pfad): URL-Print vor dem ersten `mediainfo`-Aufruf pro Datei. Akzeptiert.
- **D7**: `:REMUX_IF_NEEDED` re-muxt jede Datei, bei der `ffprobe` Tracks sieht, `mediainfo` aber nicht. Generischer Ansatz statt expliziter Lavf-Heuristik — kostet pro Aufruf zwei Tool-Invocations (ffprobe + mediainfo), bringt aber Robustheit gegen alle Container-Inkompatibilitäten.
- **D8**: CMDPATH-basierte Modell-Pfade (siehe Abschnitt oben) statt `%~dp0`-basiert. Bewusste Architekturentscheidung gegen skript-relatives Deployment.

## ffmpeg_wrapper.cmd — Paralleler Wrapper

> **Stand 2026-11-12**: `ffmpeg_wrapper.cmd` ist **nicht** in diesem Repo; die aktive Quelle liegt im Schwester-Repo `D:\Sources\FFmpeg_Wrapper\` (dort committed) und deployed unter `D:\Apps\Commands\bin\ffmpeg_wrapper.cmd`. Die Sektion bleibt hier als Referenz.

Analog zu `nvencc64_wrapper.cmd` existiert `ffmpeg_wrapper.cmd` (Software-Encoder via FFmpeg). Er hat die gleiche Struktur: gleiche `SETxxx`-Routinen, gleiches EDIT_TAGS, gleiches `:REMUX_IF_NEEDED`. Die Fixes #1–#4 sind 1:1 übernommen. **Sonderfall Fix #4 im ffmpeg_wrapper**: zusätzlich wurde Z. 254 von `--Inform=Video;%Format%` auf `--Inform=Video;%%Format%%` korrigiert (im nvencc_wrapper war das schon korrekt). Mit dem einfachen `%Format%` und globalem `setlocal enabledelayedexpansion` wurde die Variable zu leer expandiert, mediainfo bekam kein Template-Token, `SRC_CODEC` blieb leer, Check-Encoded triggerte nie.

**Korrektur 2026-11-25 — die Wrapper sind inzwischen divergiert** (Stand `ffmpeg_wrapper.cmd`: 1004 Zeilen, Commit `83c3e74`, 25.11.2026): Die Token-Tabellen sind **nicht mehr identisch** und getrennt zu pflegen:
- `TOK_ENCODER`: ffmpeg zusätzlich `av10`; `TOK_AUDIO`: nvencc zusätzlich `aacs`.
- `TOK_CROP`: ffmpeg 42 statt 47 Tokens — `43`/`169`/`752`/`1408`/`1620` fehlen dort (und ffmpeg nutzt `CROP_VAL` statt `CROP`).
- `TOK_FILTER`: ffmpeg hat eigene Tokens (`text`, `reverb`, `deblock`, `smooth31/63`, `gauss5`, `median`, `largemedian`, `superres*`, `ushrp*`), aber nicht `bm3d`/`vsr*`/`deHalo*`/`vhsRestore`.
- `TOK_MODE`: ffmpeg hat `yadif`/`yadifbob`/`brighter` statt `ivtc`/`rtgmc*`/`framegen*`.
- `TOK_DECODER`: ffmpeg 9 Tokens (`cuda`, `cuvid`, `vp8`, `vp9`, `vpx`, `mpeg2` …) statt 4.
- **Zuschnitt-Profile:** `720*`/`1080*`/`2160*` nutzen `zscale=…:filter=spline36` (seit 25.11., vorher `scale=`); `1772` ergänzt.

Gemeinsam sind Struktur und Fixes #1–#4 — die Token-Tabellen nicht. Kein separater Dry-Run für ffmpeg dokumentiert.

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

## Toter Code — Kandidatenliste (Stand 2026-11-25)

Systematische Dead-Code-Prüfung von `nvencc64_wrapper.cmd` (1050 Zeilen, Commit `b340600`). Geprüft: alle Labels gegen `call`/`goto`-Ziele (dynamischer Dispatch: **keiner**), alle `set`-Ziele gegen Reads (`%X%`, `!X!`, `!X:~…!`, `defined X`, indirekte Reads `!%TOK%!`), Token-Listen gegen Branches, `REM`-Zeilen, Code nach bedingungslosen Sprüngen, doppelte Labels, PS-Blöcke. **Ergebnis: 9 belegte Dead-Code-Stellen** — bis auf den Diagnose-Kanal (B) ohne Verhaltenswirkung. Nichts davon ist entfernt; das ist die Arbeitsliste für später. Alle Zeilenangaben = Stand oben; nach Wrapper-Änderungen neu verifizieren (Verfahren unter F).

### A) Definitiv tot — risikofrei entfernbar

| Stelle | Befund | Impact |
|---|---|---|
| Z. 250, 255, 436 | `FOUND` wird gesetzt und in den Aufrufer-Scope re-exportiert, aber nie gelesen | keiner — Rest der entfernten Meldung „No files found." (siehe „Stiller Leerlauf") |
| Z. 263–264, 371–374 | `CROP_L`/`CROP_R` werden gesetzt, nie gelesen; zusätzlich Bug: `for /f "tokens=1,3"` bindet nur `%%A`/`%%B`, `%%C` ist ungebunden → `CROP_R` = Literal `%C` (2026-11-25 experimentell verifiziert) | aktuell keiner; latent falsche Werte, falls später genutzt |
| Z. 597 | `:EDIT_TAGS_CLEANUP` wird nie angesprungen (nur Fallthrough von Z. 595) | toter Labelname; Cleanup-Code Z. 598–600 lebt |
| Z. 530, 675 | `set /a E=E` — Selbstzuweisung ohne Wirkung | keiner |
| Z. 382 | `if not "!CROP!"=="--crop 0,0,0,0"` kann nie falsch sein (der String entsteht nur im AUTO-Pfad, der hier ausgeschlossen ist) | keiner |
| Z. 492 | `if /i "!SEEK_ARG!"=="seek"` unerreichbar (Z. 19–22 schreibt jeden `seek`-Wert vorher in `seek=<…>` um) | keiner |
| Z. 645 | `if defined FF_STREAMS` immer wahr (Z. 619/620 haben das schon bewiesen) | keiner |
| Z. 262, 366–367 | `RESIZE_PARAM`/`RESIZE_REQUIRED`-Resets, die Z. 400 unmittelbar überschreibt (kein Reader dazwischen) | keiner; `RESIZE_PARAM` selbst ist **lebend** (siehe D letzter Punkt) |
| Z. 15–16, 830–834 | `DEBUG` hart `0` → `set "DBG=call :DEBUG"` unerreichbar, `:DEBUG` toter Label; alle **47** `%DBG%`-Stellen rufen `:NOP` | **bewusst** (Env-Override gewollt) — nur dokumentiert, nicht entfernen |

### B) Funktional toter Kanal — Ausgabe ohne Konsument

| Stelle | Befund |
|---|---|
| Z. 668/684/696 → PS Z. 846, 850–853, 898, 946 | `PS_STATUS_FILE` wird vom Probe-Skript per `Write-Status "REJECTED: …"` beschrieben, vom Batch **nie gelesen** und in Z. 696 gelöscht. Die berechneten Ablehnungsgründe („vertical asymmetry", „source too small", „one-sided vertical crop", …) erreichen den User nie — sichtbar ist nur „Probe failed or source too small". Entscheidung nötig: anzeigen oder Kanal entfernen. |
| PS Z. 891 | `$ExitCode = 2` wird nie als Exitcode 2 zurückgegeben: der folgende Reject-Pfad (PS Z. 894–900) endet immer mit `exit 8`. |

### C) Verwaist / Duplikate (kein toter Code im engeren Sinne)

| Stelle | Befund |
|---|---|
| Z. 772–773 | `if defined CALLER_NAME` — `CALLER_NAME` wird im Repo und in den Aufrufern (`encode-all.cmd` ruft direkt auf) nirgends gesetzt; externer Hook oder Rest eines alten Launchers |
| Z. 322 + 388 | identischer PowerShell-URL-Print zweimal (beide Pfade lebend — D4/D6 akzeptiert, nur das Duplikat fällt auf) |
| Z. 299 + 306 | identische Bedingung `x!INNAME:~-4!==x.mkv` zweimal ausgewertet |
| Z. 252 | `if exist "%%I"` im `for`-Loop tautologisch (FOR liefert nur existierende Dateien) |
| Z. 176/181, 177/182, 179/185, 180/186, 228/229 | Alias-Tokens mit identischem Kommando (`artifact`≡`vsrDenoise`, `artifactHQ`≡`vsrDenoiseHQ`, `vsrArtifact`≡`vsrDetailRestore`, `vsrArtifactHQ`≡`vsrDetailRestoreHQ`, `dv`≡`dolby-vision`) |
| 18 Branches | wiederholen exakt die Default-Zuweisung (No-Op): Z. 91/92, 105, 117, 157–162, 167, 193–198, 203, 234–235, 242–243 — für die Token-Validierung nötig, im Code wirkungslos |

### D) Bewusst so — NICHT entfernen / nicht erneut melden

- `%DBG%`-Instrumentierung (47 Stellen) + `:DEBUG`/`:NOP`: Debug-Facility, per `set "DEBUG=1"` im Skript aktivierbar (bewusst vor Env-Override geschützt).
- `c1`–`c6` (SETCROP) und `f1`–`f6` (SETFILTER): reservierte User-Slots, setzen bewusst nichts.
- `EDIT_TAGS` als Konstante `1` (Z. 14; Guards Z. 325/423): Kill-Switch per Datei-Edit.
- Akzeptierte Design-Punkte D1–D8 (oben), insbesondere AV1→`SETQUALITY-HEVC`, 5-s-Wartezeit, URL-Prints, `$Top`/`$Bottom`, CMDPATH-Pfade.
- **`--vpp-resize spline36`-Injektion (Z. 401–403) ist NICHT tot:** `RESIZE_PARAM` hat genau einen Writer (Z. 402) und einen Reader (Z. 409); der Pfad ist erreichbar (z. B. `hevc ac3 def 720 none` → `CROP=--output-res 1280x-2`, `FILTER_HAS_RESIZE=0`). nvencc-Default für `--vpp-resize` ist `algo=auto` — die Injektion pinnt also `spline36`. Tote Reste sind nur die Resets Z. 262/366–367.

### E) Geprüft und NICHT tot (damit es nicht erneut auftaucht)

- PS-Blöcke Z. 839–1050 (RUN_PROBE/EDIT_TAGS): für cmd „toter Text", werden aber per `findstr`-Marker extrahiert und als `.ps1` ausgeführt → **Datenquelle**.
- `:PARAM_ERROR` (504), `:BRANCH_BROKEN` (623), `:BRANCH_HEALTHY` (644), `:PROBE_OK` (703), `:NOP` (823), `:GET_ARG10` (465), `:USAGE` (764): über `goto`/`%DBG%` erreichbar. `:INIT` (3) ist der Einstiegspunkt ohne Sprungziel — kein toter Label.
- `TOK_*`-Variablen: indirekte Reads in Z. 442 (`!%2!`) und Z. 740 (`!%TOKVAR%!`) — eine naive „nie gelesen"-Suche ist ein False Positive.
- `SKIP_FILE`-Guard Z. 399: kein Duplikat von Z. 329 — Z. 360 setzt das Flag zwischenzeitlich.
- Keine dynamischen Labelsprünge (`call :%X%` = 0 Treffer), keine doppelten Labels, alle `goto`-Ziele existieren, kein auskommentierter Code (4 `REM`-Zeilen = Kommentare), keine unerreichbaren Fallthrough-Blöcke.
- Token-Mapping vollständig: 127/127 in den 1:1-Tabellen (QUALITY/SEEK prozedural; Details im Dry-Run-Abschnitt).

### F) Re-Verifikation

Mechanisch prüfbar (PowerShell, read-only): Labels (`^\s*:NAME`) gegen `call`/`goto`-Ziele; `set`-Ziele gegen `%X%`, `!X!`, `!X:~…!`, `defined X`, indirekte Reads; `TOK_*`-Listen gegen `if /i "%n"=="…"`-Branches; `%DBG%` gegen `:NOP`; PS-Marker-Bereiche als lebende Datenquelle behandeln. Bei Änderungen am Wrapper: dieses Kapitel fortschreiben, nicht stillschweigend löschen.

**Empfohlene Aufräum-Reihenfolge** (klein → groß): `set /a E=E` → `FOUND` → Label `:EDIT_TAGS_CLEANUP` → die drei toten Bedingungen (Z. 382/492/645) → `CROP_L`/`CROP_R` → `PS_STATUS_FILE` (erst nach Entscheidung: anzeigen vs. entfernen). `%DBG%`/`:DEBUG` bleibt.

## Konventionen für Erweiterungen

Bei Änderungen oder Erweiterungen an `nvencc64_wrapper.cmd` **oder** `ffmpeg_wrapper.cmd` (Steuerlogik und Fixes werden synchron gehalten; **die Token-Tabellen sind seit 2026-11-25 divergiert** — siehe ffmpeg-Abschnitt):

- **Token-Validierung erweitern?** Jedes neue Token muss in **beide** Listen: `TOK_*` in `:SETTOKEN` (nvencc Z. 810) und als `if`-Branch in der entsprechenden `:SETxxx`-Routine.
- **Neue Filter/Mode-Tokens mit Resize?** Prüfe, ob die Ausgabe `--vpp-resize` enthält — die Erkennung in Z. 31–38 (`FILTER_HAS_RESIZE`) steuert, ob ein zusätzliches `--vpp-resize spline36` injiziert wird (Z. 401–403). Bei true sollte der Token dort nicht doppelt resize hinzufügen.
- **Neue Encoder?** Analog zu AV1 entweder explizit auf `SETQUALITY-HEVC` mappen (mit Kommentar warum) oder eigene `:SETQUALITY-<NAME>`-Routine schreiben.
- **Neue PS-Sub-Skripte?** Marker-Format `#PS_<NAME>_BEGIN#` / `#PS_<NAME>_END#` verwenden, Block am Ende der `.cmd` anhängen, Extraction-Logik aus `:EDIT_TAGS` (nvencc Z. 509) oder `:RUN_PROBE` (nvencc Z. 658) kopieren.
- **Neue Branches in :REMUX_IF_NEEDED?** `goto` verwenden, nicht `if`-Klammern (siehe Hinweis in Aktive Fixes #3).
- **Auto-Crop-Schwellen?** Immer als geschlossene Partition der Messwerte definieren (Passthrough/Windowbox/Pillarbox/Letterbox) und die Grenzwerte ±1 px testen — siehe Review-Lehre in der Wrapper2-Sektion.
- **Reject-/Diagnosemeldungen?** Nie in einer Datei versanden lassen: Grund bis zur Konsole propagieren (`Set-Reject` → `PROBE_REASON` → `:MAIN`-WARNING) und im Batch testen.
- **Nach jeder Änderung an einer `.cmd`: sofort nach `%CMDPATH%\bin\` syncen** (`.___PUSH___.cmd` oder `xcopy "*.cmd" "%CMDPATH%\bin\" /y`) — nicht optional, siehe Deployment-Abschnitt.
- **Toter Code?** Vor dem Entfernen den Abschnitt „Toter Code — Kandidatenliste" prüfen; neue Funde dort mit Zeilenbeleg und Datum eintragen, statt sie nur im Chat zu erwähnen.

## Meldungen, Pipeline & Deployment (Stand 2026-11-12)

- **Stiller Leerlauf**: `echo No files found.` und die Abschlusszeile `[INFO] Savings: …` wurden aus `nvencc64_wrapper.cmd` und `ffmpeg_wrapper.cmd` (sowie aus den Convertern des FFmpeg_Wrapper-Repos) **entfernt**. Bei leerem Ordner/„nichts zu tun" gibt der Wrapper jetzt **keine** Ausgabe mehr aus (Exit 0). Grund: Es waren keine Fehler, der User wollte sie nicht sehen.
- **Alte Pipeline entfernt**: `sort-all.cmd` gelöscht; die Starter `_1_sort.cmd`, `_2_encode.cmd`, `_3_move.cmd` (in `%CMDPATH%\bin\scripts\`) gelöscht; `encode-edit.cmd` gelöscht (referenzierte das gelöschte `sort-all.cmd`). Der Workflow läuft über `clean-all` / `encode-all` / `move-all`.
- **README.md** erweitert: neuer Abschnitt „Hilfsskripte im `bin`" (encode-all, move-all inkl. Serien-Heuristik/`.checked`-Wegfall, clean-all inkl. `:ProcessCopy`-Warnung), Features-Bullet „Hilfsskripte", Arbeitsablauf-Punkt 4 (Savings) präzisiert; Hinweis auf entfernte Pipeline/Lean-Meldungen.
- **Repo vs. `bin`**: Das Repo enthält die sanitisierte Version von `nvencc64_wrapper.cmd`. **Custom Crops und Filter (`cX`/`fX`) sind nicht zu beachten** — private Token-Werte im `bin` (`smooth`, `nlmeans`, `f1`–`f3` mit eigenen `--vpp-*`-Ketten, z. B. realesrgan/msmooth/chromashift) sind nur temporär, jederzeit zurücksetzbar und werden nicht benötigt. `.___PUSH___.cmd` überschreibt `bin` direkt; kein Sichern/Zurückspielen.
- **Deployment — Pflichtschritt nach jeder Wrapper-Änderung**: `.___PUSH___.cmd` aus dem Repo-Root (xcopy `*.cmd` → `%CMDPATH%\bin`, `git add .`, Commit „Updates", `git push`). **Jede Änderung an `*.cmd` wird unmittelbar nach `%CMDPATH%\bin\` gesynct** — der Alltags-Workflow ruft ausschließlich die `bin`-Kopien auf (Wrapper, `encode-all`, `move-all`, `clean-all`), eine nur im Repo geänderte Datei ist dort unsichtbar. Reiner Sync ohne Commit/Push: `xcopy "*.cmd" "%CMDPATH%\bin\" /y /exclude:exclude.txt` (exclude.txt = `README.md`, `.___CLAUDE___.cmd`, `.___PUSH___.cmd`, wie im Skript). `README.md`, `.___CLAUDE___.cmd`, `.___PUSH___.cmd` sind von der Kopie ausgeschlossen. **Stand 2026-11-25:** Repo und `bin` sind aktuell: `nvencc64_wrapper.cmd` (1050 Zeilen, inkl. 1772) und `ffmpeg_wrapper.cmd` (1004 Zeilen, Commit `83c3e74`) sind jeweils hash-identisch mit ihren `bin`-Kopien; ebenso `clean-all`, `move-all`, `encode-all`; zusätzlich `nvencc64_wrapper2.cmd` (1267 Zeilen, HD/Full-HD-Extension inkl. Audio-Reencode-Pfad).

## Abbruch-/CTRL+C-Sicherheit (Stand 2026-11-13)

Bei CTRL+C während der Konvertierung bleiben keine unvollständigen Dateien unter dem finalen Namen liegen und die Quelle wird nicht mehr nach `_Check` verschoben:

- **Temp-Datei + Rename**: Ausgaben werden zuerst als `_Converted\<Name>.part.mkv` geschrieben und **erst nach Erfolg** auf `<Name>.mkv` umbenannt (Encode-Pfad in `nvencc64_wrapper`/`ffmpeg_wrapper`; ebenso der `mkvmerge`-Re-Mux im Check-Encoded-Block).
- **Fehlerpfad**: Bei Encoder-Fehler/Abbruch wird die Teil-Ausgabe **gelöscht**, eine WARNUNG ausgegeben und die **Quelle bleibt stehen** (`WARNING: Encoding failed or cancelled. Source not moved.`). Kein `_Check`-Move.
- **Exitcode-Auswertung**: Nicht mehr `if errorlevel 1`, sondern `set "RC=!ERRORLEVEL!"` + `if not "!RC!"=="0"` — damit wird **jeder** Code ≠ 0 als Fehler/Abbruch erkannt, auch der CTRL+C-Status `0xC000013A` (als `-1073741510`). Vorher wurde ein Abbruch mit negativem Exitcode übersehen (Teil-Datei wurde dann als final umbenannt).
- **`_Check` bleibt** ausschließlich für echte **Vorprüf-Fehler**: „Could not detect codec", „Probe failed or source too small" (beide unverändert).
- **Aufräumen beim Start**: `MAIN` löscht alte `_Converted\*.part.mkv`-Reste (Rest einer „Terminate batch job"-Beendigung); Z. 249.
- **Betroffen**: `nvencc64_wrapper` (Encode + mkvmerge-Re-Mux), `ffmpeg_wrapper` (im FFmpeg_Wrapper-Repo), `ffmpeg_avs`, `ffmpeg_audio_converter`, `ffmpeg_video_converter`, `cube`, `clut`.

## nvencc64_wrapper2.cmd — HD/Full-HD-Extension (Stand 2026-11-26)

Parallele Fassung des Wrappers für **gemischtes Material**: Full-HD (`1920x1080` inkl. nativ gecroppter Derivate wie `1920x800`) **und** HD (`1280x720` inkl. `1280x536`, `960x720`, `1440x1080` usw.), verzerrungsfrei. `nvencc64_wrapper.cmd` bleibt unverändert die Referenz/Produktivfassung; `nvencc64_wrapper2.cmd` (1267 Zeilen) unterscheidet sich in `:SETCROP`/`TOK_CROP`, dem PS-Block `#PS_RUN_PROBE_BEGIN#…#PS_RUN_PROBE_END#` (Z. 964–1177), `:SETAUDIO` (zusätzlich `AUDIO_MODE`), der neuen Routine `:CHECK_AUDIO_STREAMS` sowie wenigen `:MAIN`/`:RUN_PROBE`-Zeilen (PROBE_REASON, VSR-Warnung, Audio-Reencode-Pfad).

### Ursachen im Basis-Wrapper (in v2 behoben)
- PS-Block rechnete ausschließlich mit 1080p-Tabellen (`$StandardResolutions`, `$StandardWidths`) → bei 720p-Quellen falsche Crop-Werte und gestreckte Ziele (z. B. `1280x872`), negative Pillarbox-Offsets.
- Mindest-Guard `OrigWidth < 1280 -or OrigHeight < 696` lehnte bereits balkenfreie bzw. kleine HD-Quellen ab, obwohl sie nur durchgereicht werden müssten.
- Feste Probe-Zeitpunkte (2/10/20 min) → kurze Clips/Trailer ohne Messwerte; keine Plausibilitätsprüfung der Messfenster.

### Auflösungsbewusste Tabellen (nur Snapping, kein freier Beschnitt — Vorgabe)
- **Full-HD-Basis** (`OrigWidth >= 1600` oder `OrigHeight >= 1000`): `$StandardResolutions1080` (TotalV → Crop/Res, unverändert zum Basis-Wrapper) und `$StandardWidths1080` (Pillarbox-Breiten 1800…1348, inkl. 1772).
- **HD-Basis:** `$StandardResolutions720` (TotalV → Zielhöhe; mod8/mod4-bevorzugt: 720, 692, 640, 580, 544, 536, 464) und `$StandardWidths720` (Pillarbox-Breiten 1196, 1080, 988, 960).
- **Snap-Fenster:** Über-Crop max. 4 px (`$SnapOver`), Unter-Crop max. 8 px (`$SnapUnder`); außerhalb → `REJECTED` (Exit 8) → Datei nach `_Check`. **Keine** freien Pixelwerte aus `cropdetect` gehen an NVEncC.
- **Schwellen lückenlos (2026-11-26):** Passthrough `TotalV <= 4` **und** `TotalH <= 10`; Pillarbox-Zweig `TotalV <= 4`; Windowbox `TotalV > 4` **und** `TotalH > 10`; horizontale Asymmetrie nur bei `TotalH > 10` **und** `TotalV <= 4`. Damit fällt `TotalV = 3..4 px` (vertikales Rauschen bei Pillarbox) nicht mehr fälschlich in den Letterbox-Zweig (`no standard letterbox height`).
- **Passthrough:** kein Balken → `0:0:0:0` + Quellauflösung (deckt nativ gecroppte Quellen ab).
- **Rejects:** Windowbox, einseitige/unsymmetrische Balken, ungerade Quellmaße, Quelle < `960x464`, anamorphe Quelle (`SAR != 1:1|0:1`), kein Standard-Match — manueller Beschnitt erforderlich.
- **Crop-Offsets dürfen ungerade sein:** `NVEncC 9.41` akzeptiert ungerade `--crop`-Werte; eine Mod2-Reject-Prüfung wurde bewusst **nicht** eingebaut (am 2026-11-26 auf User-Korrektur wieder zurückgerollt).
- **Ablehnungsgrund sichtbar:** PS schreibt `SET NVEnc_Reject=<Grund>` in die SET-Datei; `:RUN_PROBE` reicht das als `PROBE_REASON` an `:MAIN` weiter, das konkret `WARNING: Auto-crop rejected (<Grund>). Moving file to _Check.` ausgibt (Fallback: bisherige Pauschalmeldung). Auch `no cropdetect result` und nicht lesbare Auflösung laufen als Reject mit Grund (Exit 8 statt früher 2/4).
- **Probe:** relative Zeitpunkte 15/45/75 % der Laufzeit (Clips < 1,5 s: 0.2/0.6/1.0 s), Median aus 3 Messungen, Fenster < 50 % der Quellfläche verworfen.

### Neue manuelle HD-Tokens (`:SETCROP`/`TOK_CROP`, nur 720p-Container)
| Token | Wirkung |
|---|---|
| `h692` | `--crop 0,14,0,14` (1280x692) |
| `h640` | `--crop 0,40,0,40` (1280x640) |
| `h580` | `--crop 0,70,0,70` (1280x580) |
| `h544` | `--crop 0,88,0,88` (1280x544) |
| `h536` | `--crop 0,92,0,92` (1280x536) |
| `h540` | `--crop 0,90,0,90` (1280x540, manuelle Mod4-Alternative; Auto bevorzugt 536/Mod8) |
| `h464` | `--crop 0,128,0,128` (1280x464) |
| `h960` | `--crop 160,0,160,0 --output-res 960x720` |
| `h988` | `--crop 146,0,146,0 --output-res 988x720` |
| `h1080` | `--crop 100,0,100,0 --output-res 1080x720` |
| `h1196` | `--crop 42,0,42,0 --output-res 1196x720` |

Bestehende Tokens (`696`–`1040`, `1348`–`1800`, `c1`–`c6`) unverändert. `h`-Tokens sind **fixe 720p-Werte** und nur für `1280x720`-Container gedacht (auf 1080p-Quellen würden sie falsch croppen). `TOK_CROP` = 58 Tokens ↔ 58 Branches.

### Wechselwirkungen (geprüft)
- `--crop` + `--output-res` = gecroppte Größe ⇒ **keine Skalierung** (NVEncC-Protokoll zeigt nur `crop: …`, keinen Resize); SAR bleibt 1:1 → keine Verzerrung.
- `RESIZE_REQUIRED`/`FILTER_HAS_RESIZE` unverändert: im AUTO-Pfad wird kein `--vpp-resize spline36` injiziert (D2 bleibt gültig).
- **ngx-vsr + AUTO:** kein Abbruch, aber NVEncC meldet `resolution change: normalization resize falls back from ngx-vsr to bicubic` — bei 1:1-Ziel greift kein VSR; `:MAIN` gibt zusätzlich eine gelbe Konsolenwarnung aus (`VSR filter combined with auto-crop …`). Für echten VSR-Effekt explizites Resize-Token nötig.
- **`--avhw` + Links-Crop:** Die NVEncC-Hilfe behauptet „left crop is unavailable with avhw reader"; in 9.41 empirisch geprüft (Auto 960x720/1440x1080 und manuelle Tokens `h960`/`1440`, Default-Decoder `hw`): Crop wird korrekt angewandt (`crop: 160,0,160,0` bzw. `240,0,240,0`), kein Fehler, **kein `avsw`-Fallback nötig**; auch 10-bit-Quelle + Token `1440` funktioniert mit `--avhw`. Kein automatischer Decoder-Wechsel implementiert.
- **Bekannte Grenze (10-bit):** `cropdetect` mit `limit=24` wertet die rohen 10-bit-Samples aus (Schwarzbalken ≈ 64) → bei 10-bit-Quellen erkennt Auto-Crop keine Balken und geht auf Passthrough; manuelle Tokens funktionieren. Nicht im Scope dieses Feintunings (Fix wäre `format=yuv420p,cropdetect…` oder angepasstes Limit).

### Zweistufige Codec-/Stream-Prüfung (Audio-Reencode-Pfad, 2026-11-27)

Nur in v2: Bei `CHECK_ENCODED=1` und passendem Video-Codec wird zusätzlich Audio geprüft (`:SETAUDIO` setzt dafür `AUDIO_MODE`; `:CHECK_AUDIO_STREAMS` liest `ffprobe -select_streams a -show_entries stream=index,codec_name,channels -of csv=p=0` und baut `FF_AUDIO_ARGS`/`FF_AUDIO_INFO`).

- **Fall A — `copy`/`copy1`/`copy2`/`copy12`/`copy23`:** `AUDIO_MODE=copy`; altes Verhalten (Verschieben/Muxen nach `_Converted`, `SKIP_FILE=1`); Track-Filter werden ignoriert.
- **Fall B — Ziel-Audio-Codec (`ac3`/`aac`/`aacs`/`eac3`, leer = ac3):** keine Audiospuren oder alle Spuren konform → altes Verschieben (`TARGET_DIR`). Mindestens eine Spur abweichend → `TARGET_DIR` bleibt leer, `AUDIO_ONLY_FFMPEG=1`, NVEncC-Block wird übersprungen.
- **Stream-Regeln (nur abweichende Spuren werden neu encodet):** `ac3` → 2ch 192k / >2ch 384k (`-ac 6`, 7.1→5.1); `aac` → 2ch 128k / >2ch 256k; `aacs` → immer aac 2ch 128k (konform nur `aac` mit `channels <= 2`); `eac3` → 2ch 320k / >2ch 640k. Konforme Spuren: `-c:a:<idx> copy` — nie reencodet, auch bei abweichender Bitrate.
- **FFmpeg-Aufruf:** `-map 0:v -map 0:a? -map 0:s? -map 0:t? -map_chapters 0 -c:v copy -c:s copy -c:t copy <FF_AUDIO_ARGS>` → `_Converted\<Name>.part.mkv`; danach Rename, `EDIT_TAGS`, `REMUX_IF_NEEDED`, 5-s-Countdown. Quelle bleibt unangetastet; bei Fehler `.part.mkv` löschen + Warnung (`FFmpeg audio re-encoding failed or cancelled. Source not moved.`), Abbruch via `exit /b` wie im Encode-Fehlerpfad.
- **Konsole:** Warnung `Video already encoded as <Codec>, but audio tracks require re-encoding via FFmpeg...` + pro Spur `Track <n>: <codec> (<ch>ch) -> copy|<ziel> (<details>)`, dann URL-Print + mediainfo-Kurzinfo. `FF_AUDIO_INFO` wird nach der Schleife um das abschließende `"; "` bereinigt (`!FF_AUDIO_INFO:~0,-2!`).
- **Grenze:** `mediainfo --Inform=Video;%Format%` liefert bei **mehreren Videospuren** verketteten Text (z. B. `HEVCHEVC`) → kein Video-Match → normaler NVEncC-Encode-Pfad (kein Audio-Reencode). Bewusst so: mehrdeutige Video-Lagen werden nicht automatisch verarbeitet.

### Tests (2026-11-26)
- 43 Unit-Fälle für den PS-Block (HD/FHD letterbox + pillarbox, nativ gecroppte Quellen, Snap-Kanten, Rejects, Anamorph, Windowbox, 1-s-Clip, neuer Edge-Case **Pillarbox mit TotalV=4 px Rauschen**, `TotalH=10`-Grenze, ungerade Offsets erlaubt): **43/43 PASS**.
- 7 End-to-End-Läufe + Batch-Checks: auto → `1280x536` / `1920x800` / `960x720`; manuell `h536`/`h988`/`h464`/`h960` → korrekte Ausgabedimensionen; **PROBE_REASON-Ausgabe** (`WARNING: Auto-crop rejected (windowbox …)`) inkl. `_Check`-Move; **VSR-Warnung** sichtbar; `hw`-Decoder + Links-Crop (960x720, 1440x1080) ohne Fehler. Im Vpp-Protokoll nur `crop`, kein Resize.
- Usage/Tokens: `h`-Tokens in der Usage-Liste; unbekannte Tokens (`h999`) werden mit vollständiger Liste abgelehnt.
- **Audio-Reencode-Pfad (2026-11-27, 8 Fälle):** `mixed_ac3` (aac 6ch → ac3 6ch 384k, ac3 2ch copy), alle Spuren konform/kein Audio/`copy` → Verschieben, `aacs` (aac 6ch → aac 2ch 128k), `eac3` (2ch 320k / 6ch 640k), AVC+eac3 → h264-Copy. Verifikation: **Video-MD5 identisch** (echtes `copy`), keine NVEncC-Ausgabe, Quelle bleibt; Untertitel + Font-Attachment erhalten; MP4 mit Data-Stream (`tmcd`) läuft; normaler Encode-Pfad unverändert. 2-Video-Fall zeigt die o. g. mediainfo-Grenze (normaler Encode).

### Review 2026-11-27 — Lessons Learned (externes Review)

**Positiv bestätigt:** Architektur-Integration ohne Regressionen (Delayed Expansion, Subshell-Isolation, Token-Validierung in `:SETTOKEN`/`:SETCROP`, ASCII-Encoding der temporären `.cmd`-Dateien); strikte Whitelist-Logik mit asymmetrischem Snap-Fenster (`$SnapOver=4`/`$SnapUnder=8` schützt vor Beschnitt ins Bild); Error-Propagation über `Set-Reject`/`NVEnc_Reject` → `PROBE_REASON`; empirische Verifikation statt Hilfe-Glauben (`--avhw`-Links-Crop, 10-bit-`cropdetect`); Test-/Doku-Disziplin (43 Unit-Fälle, Batch-Assertions, Mod2-Rollback ohne Code-Reste, Doku- und `bin`-Sync).

**Schwächen im ersten Entwurf — als Regel für künftige Auto-Crop-Änderungen:**
1. **Schwellenwert-Lücke `TotalV = 3..4 px`:** Passthrough `<=4`, Windowbox `>4`, Pillarbox `<=2` — bei `TotalV=3..4` fiel die Datei fälschlich in den Letterbox-Zweig (`no standard letterbox height`). Fix: Pillarbox auf `<=4`, horizontale Asymmetrie/Windowbox konsistent auf `>10`; **Regel: Schwellen immer als geschlossene Partition definieren und die 3/4-px-Ränder explizit testen** (Fälle `t37`/`t38`/`t42`/`t43`).
2. **Ungenutzter Diagnose-Kanal:** `Write-Status` schrieb Reject-Gründe in `%PS_STATUS_FILE%`, das `:RUN_PROBE` unverändert löschte — sichtbar blieb nur die Pauschalmeldung. Fix: `Set-Reject` schreibt `SET NVEnc_Reject=…` in die SET-Datei, `:RUN_PROBE` propagiert `PROBE_REASON`, `:MAIN` zeigt den konkreten Grund; auch Probe-Sonderfälle (`no cropdetect result`, unlesbare Auflösung) laufen als Reject mit Grund. **Regel: Diagnosekanäle sofort an einen Konsumenten verdrahten und im Batch testen — nicht nur im PS-Block.**

### Pflege
- Steuerlogik (`:MAIN`, EDIT_TAGS, REMUX) weiterhin in **beiden** Wrappern nachziehen; Token-Tabelle in v2 zusätzlich um die `h`-Tokens erweitert.
- Die Dead-Code-Befunde (Abschnitt „Toter Code") gelten auch für v2 (identischer Batch-Teil; der tote `PS_STATUS_FILE`-Kanal existiert weiterhin).

## Rollback: Version ohne Part-Handling

- **Part-Handling eingeführt**: Commit **`d6f8c09`** (Temp-Datei `.part.mkv` + Rename, Fehlerpfad ohne `_Check`-Move); Exitcode-Auswertung (`RC=!ERRORLEVEL!`) danach in **`b094e22`**. Spätere Commits `c97b30f`/`f0b5fb9` betreffen nur `nvencc64.txt` (Restore/Löschung).
- **Letzter Stand OHNE Part-Handling: Commit `a145433`**.
- **Rollback des Wrappers**:
  ```
  git checkout a145433 -- nvencc64_wrapper.cmd
  ```
  danach committen/pushen (Repo `NVEncC64_Wrapper`). Danach ggf. `.___PUSH___.cmd` ausführen, um `bin` zu aktualisieren.
