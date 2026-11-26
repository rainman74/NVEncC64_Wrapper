# NVEncC64_Wrapper

Batch-Videotranscoding-Wrapper für [NVEncC64](https://github.com/rigaya/NVEnc) von rigaya mit automatischer Crop-Erkennung, Qualitätsautomatik, Audio-Behandlung und Metadaten-Bereinigung.

## Features

- **Auto-Crop** — Ermittelt schwarze Balken per `ffmpeg cropdetect` an 3 relativen Zeitpunkten (15/45/75 % der Laufzeit) und rastet auf Standard-Auflösungen ein (Full-HD- und HD-Tabellen; **kein freier Beschnitt** — außerhalb der Toleranz → `_Check`)
- **Auto-Quality** — Wählt Qualitätsstufe anhand des Jahrzehnts im Dateinamen (`(19xx)` = hq, `(20xx)` = def)
- **Auto-Skip** — Bereits im Zielcodec vorliegende Dateien werden ohne Neukodierung verschoben; in `nvencc64_wrapper2.cmd` werden abweichende Audiospuren vorher per FFmpeg neu encodet (Video bleibt `copy`)
- **Audio-Encoding** — AC3, AAC, E-AC3 oder direkte Kopie (auch selektive Streams)
- **VPP-Filter** — Denoise, Sharpening, Super-Resolution, VSR, Deinterlacing, HDR→SDR u.v.m.
- **VHS-Restore** — Feldreparatur + Deinterlacing für VHS-Captures (`vhsRestore`, ONNX-Modell PAL/SECAM)
- **Startzeitpunkt** — Anfang abschneiden über optionalen 9. Parameter `seek=<hh:mm:ss.ms>`
- **AviSynth** — `*.avs`-Skripte werden ohne Codec-Erkennung direkt über den AviSynth-Reader (`--avs`) kodiert
- **Tag-Bereinigung** — Automatische MKV-Metadaten-Normalisierung via `mkvpropedit`
- **Fehlerbehandlung** — Nicht analysierbare Dateien (außer `*.avs`) landen in `_Check/` zur manuellen Prüfung
- **Hilfsskripte** — `encode-all`, `move-all`, `clean-all` im `bin` (Details unten)
- **Debug-Modus** — Detaillierte Ausgabe (Auto-Crop, Parameter, Zwischenergebnisse) via `set "DEBUG=1"` in der Wrapper-Datei

## Voraussetzungen

Folgende Programme müssen im Pfad verfügbar sein:

```
ffmpeg.exe / ffprobe.exe
mediainfo.exe
nvencc64.exe
mkvpropedit.exe / mkvmerge.exe
```

## Eingabeformate

Im Arbeitsverzeichnis werden `*.mkv`, `*.mp4`, `*.mpg`, `*.mov`, `*.avi`, `*.webm` und `*.avs` verarbeitet; die Ausgabe landet als `_Converted\<Dateiname>.mkv`.

**AviSynth (`*.avs`):** Bei Skripten entfällt die mediainfo-Codec-Erkennung. Es wird immer der AviSynth-Reader (`--avs`) verwendet – unabhängig vom `decoder`-Parameter – und der `chkenc`-Check wird übersprungen. Schlägt bei `crop=auto` die Probe fehl (z. B. weil ffmpeg das Skript nicht öffnen kann), wird ohne Auto-Crop weiterkodiert; das Skript wird **nicht** nach `_Check` verschoben.

## Aufruf

```
nvencc64_wrapper <encoder> [audio] [quality] [crop] [filter] [mode] [decoder] [chkenc] [seek=<hh:mm:ss.ms>]
```

> **HD-Variante:** `nvencc64_wrapper2.cmd` ist die erweiterte Fassung für gemischtes Material (Full-HD **und** `1280x720`, inklusive nativ gecroppter Derivate wie `1280x536`, `960x720` oder `1440x1080`). Aufruf identisch. Der Auto-Crop rastet dort strikt auf die 1080p- bzw. 720p-Standardtabellen ein; Messwerte außerhalb der Toleranz führen zu `REJECTED` (Datei nach `_Check`), es wird **kein** freier Beschnitt berechnet. Der konkrete Ablehnungsgrund erscheint auf der Konsole. Bei `auto` + VSR-Filter warnt der Wrapper, dass NVEncC bei 1:1-Zielauflösung auf bicubic zurückfällt. Der Default-Decoder `hw` funktioniert auch bei Links-Crop (Pillarbox) — in NVEncC 9.41 verifiziert.

| Pos | Parameter | Default | Beschreibung |
|-----|-----------|---------|--------------|
| 1 | **encoder** | (required) | Videoencoder |
| 2 | **audio** | `ac3` | Audiobehandlung |
| 3 | **quality** | `def` | Qualitätsstufe (QVBR-Wert) |
| 4 | **crop** | `none` | Crop-Modus / Zielauflösung |
| 5 | **filter** | `none` | VPP-Filterkette |
| 6 | **mode** | `none` | Spezialmodi (Deinterlace, FPS, HDR→SDR, Dolby Vision) |
| 7 | **decoder** | `hw` | Hardware- oder Software-Decoder |
| 8 | **chkenc** | `true` | Bereits kodierte Dateien erkennen |
| 9 | **seek** | (optional) | Schneidet den Anfang ab: `seek=<hh:mm:ss.ms>` (z. B. `seek=00:00:30.989`) |

### Parameter-Details

#### encoder (Position 1)
| Wert | Codec | Profil |
|------|-------|--------|
| `def` / `hevc` | HEVC (H.265) | main |
| `he10` | HEVC (H.265) | main10, 10-bit |
| `h264` | H.264 | high |
| `av1` | AV1 | high |

#### audio (Position 2)
| Wert | Verhalten |
|------|-----------|
| `ac3` (default) | AC3, Stereo → 192k, 5.1 → 384k, 7.1 → 5.1 Downmix |
| `aac` | AAC, Stereo → 128k, 5.1 → 256k |
| `aacs` | AAC, alle Streams auf Stereo downmixen (128k) |
| `eac3` | E-AC3, Stereo → 320k, 5.1 → 640k |
| `copy` | Alle Audiostreams unverändert kopieren |
| `copy1` | Nur Stream 1 kopieren |
| `copy2` | Nur Stream 2 kopieren |
| `copy12` | Streams 1 und 2 kopieren |
| `copy23` | Streams 2 und 3 kopieren |

#### quality (Position 3)
| Wert | HEVC QVBR | H.264 QVBR | Tuning | Multipass |
|------|-----------|------------|--------|-----------|
| `uhq` | 24 | 20 | uhq / hq | 2pass-full |
| `hq` | 26 | 22 | hq | 2pass-quarter |
| `def` (default) | 28 | 24 | hq | none |
| `lq` | 30 | 26 | lowlatency | none |
| `ulq` | 32 | 28 | ultralowlatency | none |
| `auto` | auto | auto | Automatisch anhand Jahr im Dateinamen: `(19xx)` → hq, `(20xx)` → def, sonst def |

> AV1 verwendet dieselben Stufen wie HEVC.

#### crop (Position 4)
**Automatisch:**
| Wert | Verhalten |
|------|-----------|
| `auto` | Führt `ffmpeg cropdetect` an 3 relativen Zeitpunkten durch, ermittelt per Median schwarze Balken und rastet strikt auf Standard-Auflösungen ein. Full-HD-Quellen nutzen die 1080p-Tabellen, `1280x720`-Quellen die HD-Tabellen; liegt der Messwert außerhalb der Toleranz, geht die Datei als `REJECTED` nach `_Check` (kein freier Beschnitt). Der konkrete Grund wird als `WARNING: Auto-crop rejected (<Grund>).` ausgegeben. |
| `none` | Kein Crop |

**Vertikaler Crop (schwarze Balken oben/unten entfernen, Zielbreite 1920):**
`696`, `752`, `768`, `800`, `804`, `808`, `812`, `816`, `872`, `960`, `1012`, `1024`, `1036`, `1040`

**Resolutionen (kein aktiver Crop, nur Skalierung):**
| Wert | Auflösung |
|------|-----------|
| `43` | 720x540 (fest, 4:3-Downscale) |
| `169` | 960x540 (fest, 16:9-Downscale) |
| `720` | 1280x-2 (Breite fix) |
| `720p` | -2x720 (Höhe fix) |
| `720f` | 1280x720 (fest) |
| `1080` | 1920x-2 (Breite fix) |
| `1080p` | -2x1080 (Höhe fix) |
| `1080f` | 1920x1080 (fest) |
| `1440f` | 1440x1080 (fest) |
| `2160` | 3840x-2 (Breite fix) |
| `2160p` | -2x2160 (Höhe fix) |
| `2160f` | 3840x2160 (fest) |

**Letterbox-Standards (1920x1080 Basis mit horizontalem Crop):**
`1348`, `1408`, `1420`, `1440`, `1480`, `1500`, `1620`, `1764`, `1772`, `1780`, `1788`, `1792`, `1800`

**HD-Letterbox-Standards (Basis `1280x720`, nur 720p-Quellen — nur in `nvencc64_wrapper2.cmd`):**
`h692`, `h640`, `h580`, `h544`, `h536`, `h464` (Crop-only; ergibt `1280x692` … `1280x464`)

**HD-Pillarbox-Standards (Basis `1280x720`, nur 720p-Quellen — nur in `nvencc64_wrapper2.cmd`):**
`h960`, `h988`, `h1080`, `h1196` (`--crop` + `--output-res`; ergibt `960x720` … `1196x720`)

**Aliase (alle = kein Crop):** `c1`, `c2`, `c3`, `c4`, `c5`, `c6`

#### filter (Position 5)
| Wert | Effekt |
|------|--------|
| `none` | Kein Filter |
| `edgelevel` | Kantenschärfung (`--vpp-edgelevel --vpp-detailsharpen`) |
| `smooth` | Motion-Smoothing (`--vpp-msmooth`) |
| `nlmeans` | Rauschreduzierung (`--vpp-nlmeans` + Unsharp) |
| `gauss` | Weichzeichner Gauss 3px |
| `bm3d` | BM3D-Denoise (`--vpp-bm3d`) |
| `sharp` | Schärfung (`--vpp-msharpen`) |
| `denoise` | NVIDIA Webcam-Denoise (leicht) |
| `denoiseHQ` | NVIDIA Webcam-Denoise (stark) |
| `artifact` | ngx-vsr Denoise q8 (Alias für `vsrDenoise`) |
| `artifactHQ` | ngx-vsr Denoise q11 (Alias für `vsrDenoiseHQ`) |
| `vsr` | NVIDIA VSR (NGX), vsr-quality=4 |
| `vsrArtifact` | ngx-vsr Detail-Restoration q16 (Alias für `vsrDetailRestore`) |
| `vsrArtifactHQ` | ngx-vsr Detail-Restoration q19 (Alias für `vsrDetailRestoreHQ`) |
| `vsrDenoise` | ngx-vsr Denoise q8 (min, ohne Resize) |
| `vsrDenoiseHQ` | ngx-vsr Denoise q11 (max, ohne Resize) |
| `vsrDeBlur` | ngx-vsr DeBlur q12 (min, ohne Resize) |
| `vsrDeBlurHQ` | ngx-vsr DeBlur q15 (max, ohne Resize) |
| `vsrDetailRestore` | ngx-vsr Detail-Restoration q16 (min) |
| `vsrDetailRestoreHQ` | ngx-vsr Detail-Restoration q19 (max) |
| `vsrStream` | ngx-vsr Streaming q21 (min, Ampere+) |
| `vsrStreamHQ` | ngx-vsr Streaming q23 (max, Ampere+) |
| `deHalo` | Feines Dehalo (`--vpp-finedehalo rx=3.0,ry=3.0`) |
| `deHalo2` | Feines Dehalo (`--vpp-finedehalo rx=2.0,ry=2.0`) |
| `log` | Schreibt Input-Packet-Log (`--log-packets`) |
| `vhsRestore` | VHS-Bandrestaurierung (`--vpp-vhs-restore model=vhs_restore_pal,mode=bob,precision=fp32`) — Feldreparatur + GPU-Bwdif, verdoppelt die Framerate (bob), für interlaced VHS-Captures; nicht mit `--vpp-onnx-deint` kombinierbar |
| `f1`–`f6` | Aliase = kein Filter |

> **`vhsRestore`**: nutzt das ONNX-Modell `vhs_restore_pal` aus `%CMDPATH%\bin\onnx_models\vhs_restore\` (`--vpp-onnx-model-dir` setzt der Wrapper bereits). `mode=bob` verdoppelt die Framerate (50p bei 25i-Quelle); `--vpp-vhs-restore` ist mit `--vpp-onnx-deint` nicht kombinierbar. Für SECAM-Bänder liegt `vhs_restore_secam.onnx` bereit — dann in der `:SETFILTER`-Zeile `model=vhs_restore_secam` setzen.

#### mode (Position 6)
| Wert | Effekt |
|------|--------|
| `none` | Kein Spezialmodus |
| `deint` | Auto-Deinterlacing (adaptive) |
| `ivtc` | Inverse Telecine + Decimate (`--vpp-ivtc --vpp-decimate`) |
| `rtgmc` | RTGMC-Deinterlacer (progressiv, preset slower) |
| `rtgmcp` | RTGMC-Deinterlacer (Pretreatment, preset slower) |
| `double` | FRUC-Frameverdopplung |
| `framegen` | NVVFX Frame-Generation (medium, ×2, Ada GPU) |
| `framegen4` | NVVFX Frame-Generation (medium, ×4, Ada GPU) |
| `framegen8` | NVVFX Frame-Generation (medium, ×8, Ada GPU) |
| `framegenHQ` | NVVFX Frame-Generation (high, ×2, Ada GPU) |
| `23fps` | FPS auf 24000/1001 erzwingen |
| `25fps` | FPS auf 25.0 erzwingen |
| `30fps` | FPS auf 30.0 erzwingen |
| `60fps` | FPS auf 60.0 erzwingen |
| `29fps` | FPS auf 30000/1001 erzwingen |
| `59fps` | FPS auf 60000/1001 erzwingen |
| `tweak` | Helligkeit/Kontrast/Gamma/Sättigung anpassen |
| `lighter` | Curves heller |
| `darker` | Curves dunkler |
| `vintage` | Curves Vintage-Look |
| `linear` | Lineare Curves (alle Kanäle) |
| `hdrToSDR` | HDR→SDR (BT.2390) |
| `hdrToSDRR` | HDR→SDR (Reinhard) |
| `hdrToSDRM` | HDR→SDR (Mobius) |
| `hdrToSDRH` | HDR→SDR (Hable) |
| `dv` / `dolby-vision` | Dolby-Vision-Passthrough (RPU, Master-Display, MaxCLL) |

#### decoder (Position 7)
| Wert | Verhalten |
|------|-----------|
| `def` / `hw` | Hardware-Decoder (`--avhw`) |
| `sw` | Software-Decoder (`--avsw`) |
| `auto` | Kein expliziter Decoder — NVEncC wählt automatisch |

#### chkenc (Position 8)
| Wert | Verhalten |
|------|-----------|
| `def` / `true` (default) | Prüft, ob Quelle bereits im Zielcodec vorliegt → überspringt Neukodierung |
| `false` | Immer neu kodieren |

#### seek (Position 9, optional)
| Wert | Verhalten |
|------|-----------|
| (weggelassen) | Datei komplett encodieren |
| `seek=<hh:mm:ss.ms>` | Anfang abschneiden: Encoding erst ab dem Zeitpunkt, z. B. `seek=00:00:30.989` → `--seek 00:00:30.989`. Format `[hh:]mm:ss[.ms]` (wird in `:VALIDATE_SEEK` geprüft) |

- cmd.exe splittet Argumente an `=`; der Wrapper setzt `seek` + Wert wieder zusammen. Deshalb funktioniert `seek=00:00:30.989` ohne Quotes — `"seek=00:00:30.989"` ebenfalls.
- NVEncC `--seek` ist **keyframe-basiert**: Die Ausgabe beginnt am nächsten Keyframe nach der Zeit (bis zu eine GOP später); existiert danach kein Keyframe mehr, bricht NVEncC ab.
- Der Parameter wirkt auf alle Dateien des Laufs; ungültige Werte brechen mit Fehlermeldung ab, bevor encodiert wird.

## Auto-Crop im Detail

Der Auto-Crop (`crop=auto`) funktioniert folgendermaßen:

1. **Probe**: `ffmpeg cropdetect` wird an 3 relativen Zeitpunkten ausgeführt (15 %, 45 % und 75 % der Laufzeit; bei Clips < 1,5 s bei 0.2/0.6/1.0 s)
2. **Median**: Aus den plausiblen Crop-Ergebnissen wird der Median gebildet (Fenster < 50 % der Quellfläche werden verworfen)
3. **Mapping**: Der ermittelte vertikale oder horizontale Beschnitt wird strikt auf Standard-Auflösungen gemappt (Full-HD- und HD-Tabellen; kein freier Beschnitt — Über-Crop max. 4 px, Unter-Crop max. 8 px)
4. **Validierung & Rejects**: Bei Asymmetrie, Windowbox, anamorphem Material oder Abweichungen außerhalb der Snap-Toleranz wird die Datei samt konkretem Grund auf der Konsole nach `_Check/` verschoben

Die HD-Tabellen (`1280x720`-Basis) gelten nur in `nvencc64_wrapper2.cmd`; `nvencc64_wrapper.cmd` nutzt die Full-HD-Tabellen.

## Audio-Reencode bei bereits kodiertem Video (nur `nvencc64_wrapper2.cmd`)

Liegt der Videostream bereits im Zielcodec vor (`CHECK_ENCODED=1`), prüft `nvencc64_wrapper2.cmd` zusätzlich die Audiospuren:

- **`copy`/`copy1`/`copy2`/`copy12`/`copy23`** (kein Ziel-Audio-Codec): unverändertes Verschieben nach `_Converted`, Track-Filter werden ignoriert.
- **`ac3`/`aac`/`aacs`/`eac3`** (oder leer): Sind alle Audiospuren bereits konform (bzw. enthält die Datei gar kein Audio), wird wie bisher verschoben. Weicht mindestens eine Spur ab, wird die Quelldatei **nicht** verschoben und **nicht** gelöscht; stattdessen erzeugt `ffmpeg` die Ausgabe mit `-c:v copy`:
  - konforme Spuren: `-c:a:<idx> copy`
  - abweichende Spuren: AC3 (2ch 192k, mehrkanalig 384k / 5.1-Downmix), AAC (128k/256k), AAC-Stereo (`aacs`: immer 2ch 128k), E-AC3 (320k/640k)
- Untertitel, Kapitel und Anhänge (Fonts) werden übernommen; nach Erfolg laufen `EDIT_TAGS`, `REMUX_IF_NEEDED` und der 5-Sekunden-Countdown wie beim regulären Encode. Im Fehlerfall bleibt die Quelle unverändert, die `.part.mkv` wird gelöscht.

## Metadaten-Bereinigung (Tag-Edit)

Nach der Kodierung werden automatisch MKV-Metadaten via `mkvpropedit` normalisiert:

- **Video-Track**: Sprache auf `und`, Default/Forced-Flags auf 0, Name gelöscht
- **Audio**: Erster deutscher Track (`ger`/`deu`) wird als Default markiert
- **Subtitles**: Forced-Tracks werden korrekt geflaggt (erster Forced-Track = Default+Forced)
- **Track-Namen**: Reine Sprachennamen (`Deutsch`, `English`), `Full` oder `SDH`/`Forced` werden normalisiert oder gelöscht

## Debug-Modus

In `nvencc64_wrapper.cmd` (INIT-Bereich) umstellen:

```cmd
set "DEBUG=1"
```

Aktiviert detaillierte Ausgabe der Crop-Erkennung, NVEnc-Parameter und Zwischenergebnisse.

## Arbeitsablauf

1. Alle Videodateien im aktuellen Ordner werden nacheinander verarbeitet
2. Pro Datei: Codec-Prüfung (bei `*.avs` entfällt sie) → ggf. Auto-Crop → Encoding nach `_Converted/<name>.mkv`
3. Nach Encoding: 5s Pause, dann nächste Datei
4. Am Ende: Anzeige der Speicherersparnis (Summe der Quellgrößen mit vorhandener `_Converted`-Ausgabe vs. Ausgabegrößen; negativer Wert = Ausgabe größer). Gibt es nichts zu tun, erfolgt keine Meldung.

## Fehlerbehandlung

- **Unbekannter Codec** → Datei wird nach `_Check/` verschoben (nicht bei `*.avs` – dort entfällt die Codec-Erkennung)
- **Crop-Probe fehlgeschlagen** → Datei wird nach `_Check/` verschoben (bei `*.avs`: Warnung, Weiterkodierung ohne Crop)
- **Asymmetrische schwarze Balken** → Datei wird nach `_Check/` verschoben
- **Quelle zu klein** (< 1280×696, in `nvencc64_wrapper2.cmd`: < 960×464) → Datei wird nach `_Check/` verschoben
- **Tag-Edit fehlgeschlagen** → Datei wird nach `_Check/` verschoben

## Hilfsskripte im `bin`

| Skript | Aufgabe |
|--------|---------|
| `encode-all.cmd` | Batch-Lauf: `nvencc64_wrapper hevc ac3 auto auto` auf den aktuellen Ordner, danach `HQ`/`LQ`/`HEVC`-Unterordner (eigene Parameter) sowie `_Various` (`*.cmd` im Ordner) |
| `move-all.cmd` | verschiebt fertige `_Converted`-Dateien nach `E:\Videos\#Eltern Filme` bzw. `#Eltern Serien`; Serien-Heuristik `S[0-9][0-9]` bzw. `S[0-9]E[0-9]` (S01–S99); `.checked`-Marker entfallen |
| `clean-all.cmd` | räumt lose Sidecar-Dateien in Filmordnern auf (Policy A: lose Datei gewinnt) und verschiebt Nachzügler `<Ordner>-*`/`<Ordner>.*` in bestehende Ordner; keine Log-Meldungen |

> `clean-all.cmd` sollte nicht laufen, solange ein Download oder eine Kopie noch läuft: Bei `<Titel> (1).mkv` wird das Original gelöscht und die Kopie umbenannt (`:ProcessCopy`).

**Entfernt:** `sort-all.cmd` sowie die alten Pipeline-Starter `_1_sort.cmd`, `_2_encode.cmd`, `_3_move.cmd`. Der Workflow läuft über `clean-all`/`encode-all`/`move-all`. Die frühere Meldung `No files found.` wird von Wrapper und Convertern nicht mehr ausgegeben, wenn im Ordner nichts zu tun ist.

## Beispiele

```cmd
nvencc64_wrapper hevc ac3
```
Standard: HEVC, AC3-Audio, Qualität def, kein Crop, kein Filter.

```cmd
nvencc64_wrapper hevc ac3 auto auto
```
Automatische Qualität (anhand Jahreszahl) + automatischer Crop.

```cmd
nvencc64_wrapper hevc copy auto 1080 vsr
```
HEVC, Audio Kopie, Auto-Qualität, Skalierung auf 1080p, VSR-Upscaling.

```cmd
nvencc64_wrapper he10 copy hq 1080 gauss sw false
```
10-bit HEVC, Audio Kopie, hohe Qualität, Gauss-Weichzeichner, Software-Decoder, immer neu kodieren.

```cmd
nvencc64_wrapper hevc eac3 auto none vsrDenoise auto false
```
HEVC, E-AC3-Audio, Auto-Qualität, ngx-vsr Denoise (ohne Resize), HW-Decoder, immer kodieren.

```cmd
nvencc64_wrapper av1 aac lq 720p sharp
```
AV1, AAC-Audio, niedrige Qualität, 720p Höhen-skaliert, Schärfung.

```cmd
nvencc64_wrapper hevc ac3 auto none none hdrToSDR
```
HDR→SDR-Konvertierung mit BT.2390-Tonemapping.

```cmd
nvencc64_wrapper hevc copy hq none vhsRestore
```
VHS-Capture restaurieren: Feldreparatur + Deinterlacing über ONNX-Modell (PAL), Ausgabe mit doppelter Framerate (bob).

```cmd
nvencc64_wrapper hevc ac3 auto none rtgmc none hw true seek=00:00:30.989
```
Anfang abschneiden (Encoding erst ab 30,989 s) + RTGMC-Deinterlacing — `seek=` steht als 9. Parameter am Ende.

## Täglicher Gebrauch

Für einen automatisierten Workflow empfiehlt sich ein minimaler Parametersatz. Der Wrapper übernimmt dann Qualitätsauswahl, Crop und Audio automatisch:

```cmd
nvencc64_wrapper hevc ac3 auto auto
```

Neue Dateien im Verzeichnis werden damit einheitlich und ohne manuelle Eingriffe verarbeitet.

## Manual

Für weiterführende Fragen: [Wiki](https://github.com/rainman74/NVEncC64_Wrapper/wiki)

---

## Lizenz

Private use / experimental. No warranty.