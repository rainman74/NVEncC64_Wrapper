# NVEncC64_Wrapper

Batch-Videotranscoding-Wrapper für [NVEncC64](https://github.com/rigaya/NVEnc) von rigaya mit automatischer Crop-Erkennung, Qualitätsautomatik, Audio-Behandlung und Metadaten-Bereinigung.

## Features

- **Auto-Crop** — Ermittelt schwarze Balken per `ffmpeg cropdetect` an 3 Zeitpunkten und mapped auf Standard-16:9-Resolutionen
- **Auto-Quality** — Wählt Qualitätsstufe anhand des Jahrzehnts im Dateinamen (`(19xx)` = hq, `(20xx)` = def)
- **Auto-Skip** — Bereits im Zielcodec vorliegende Dateien werden ohne Neukodierung verschoben
- **Audio-Encoding** — AC3, AAC, E-AC3 oder direkte Kopie (auch selektive Streams)
- **VPP-Filter** — Denoise, Sharpening, Super-Resolution, VSR, Deinterlacing, HDR→SDR u.v.m.
- **Tag-Bereinigung** — Automatische MKV-Metadaten-Normalisierung via `mkvpropedit`
- **Fehlerbehandlung** — Nicht analysierbare Dateien landen in `_Check/` zur manuellen Prüfung
- **Debug-Modus** — Detaillierte Ausgabe des Auto-Crop-Prozesses via `DEBUG_AUTOCROP=1`

## Voraussetzungen

Folgende Programme müssen im Pfad verfügbar sein:

```
ffmpeg.exe / ffprobe.exe
mediainfo.exe
nvencc64.exe
mkvpropedit.exe / mkvmerge.exe
```

## Aufruf

```
nvencc64_wrapper <encoder> [audio] [quality] [crop] [filter] [mode] [decoder] [chkenc]
```

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
| `hq` | 26 | 22 | hq | 2pass-full |
| `def` (default) | 28 | 24 | hq | 2pass-quarter |
| `lq` | 30 | 26 | lowlatency | none |
| `ulq` | 32 | 28 | ultralowlatency | none |
| `auto` | auto | auto | Automatisch anhand Jahr im Dateinamen: `(19xx)` → hq, `(20xx)` → def, sonst def |

#### crop (Position 4)
**Automatisch:**
| Wert | Verhalten |
|------|-----------|
| `auto` | Führt `ffmpeg cropdetect` an 3 Zeitpunkten durch, ermittelt per Median schwarze Balken und mapped auf Standard-16:9-Resolutionen |
| `none` | Kein Crop |

**Vertikaler Crop (schwarze Balken oben/unten entfernen, Zielbreite 1920):**
`696`, `768`, `800`, `804`, `808`, `812`, `816`, `872`, `960`, `1012`, `1024`, `1036`, `1040`

**Resolutionen (kein aktiver Crop, nur Skalierung):**
| Wert | Auflösung |
|------|-----------|
| `720` | 1280x-2 (Breite fix) |
| `720p` | -2x720 (Höhe fix) |
| `720f` | 1280x720 (fest) |
| `1080` | 1920x-2 (Breite fix) |
| `1080p` | -2x1080 (Höhe fix) |
| `1080f` | 1920x1080 (fest) |
| `2160` | 3840x-2 (Breite fix) |
| `2160p` | -2x2160 (Höhe fix) |
| `2160f` | 3840x2160 (fest) |

**Letterbox-Standards (1920x1080 Basis mit horizontalem Crop):**
`1440`, `1348`, `1420`, `1480`, `1500`, `1764`, `1780`, `1788`, `1792`, `1800`

**Aliase (alle = kein Crop):** `c1`, `c2`, `c3`, `c4`, `c5`, `c6`

#### filter (Position 5)
| Wert | Effekt |
|------|--------|
| `none` | Kein Filter |
| `edgelevel` | Kantenschärfung (`--vpp-edgelevel`) |
| `smooth` | Motion-Smoothing (`--vpp-msmooth`) |
| `smooth3` | Motion-Smoothing, Stärke 3 |
| `smooth6` | Motion-Smoothing, Stärke 6 |
| `nlmeans` | Rauschreduzierung (`--vpp-nlmeans`) |
| `gauss` | Weichzeichner Gauss 3px |
| `gauss5` | Weichzeichner Gauss 5px |
| `sharp` | Schärfung (`--vpp-msharpen`) |
| `denoise` | NVIDIA Denoise (leicht) |
| `denoisehq` | NVIDIA Denoise (stark) |
| `artifact` | NVIDIA Artifact-Reduction (leicht) |
| `artifacthq` | NVIDIA Artifact-Reduction (stark) |
| `superres` | NVIDIA Super-Resolution (Mode 0) |
| `superreshq` | NVIDIA Super-Resolution (Mode 1) |
| `vsr` | NVIDIA VSR (NGX) + Unsharp |
| `vsrdenoise` | VSR + Denoise (leicht) |
| `vsrdenoisehq` | VSR + Denoise (stark) |
| `vsrartifact` | VSR + Artifact-Reduction (leicht) |
| `vsrartifacthq` | VSR + Artifact-Reduction (stark) |
| `log` | Schreibt Input-Packet-Log (`--log-packets`) |
| `f1`–`f6` | Aliase = kein Filter |

#### mode (Position 6)
| Wert | Effekt |
|------|--------|
| `none` | Kein Spezialmodus |
| `deint` | Auto-Deinterlacing (adaptive) |
| `yadif` | Yadif-Deinterlacing (auto) |
| `yadifbob` | Yadif Bob (verdoppelt Framerate) |
| `double` | FRUC-Frameverdopplung |
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
| `HDRtoSDR` | HDR→SDR (BT.2390) |
| `HDRtoSDRR` | HDR→SDR (Reinhard) |
| `HDRtoSDRM` | HDR→SDR (Mobius) |
| `HDRtoSDRH` | HDR→SDR (Hable) |
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

## Auto-Crop im Detail

Der Auto-Crop (`crop=auto`) funktioniert folgendermaßen:

1. **Probe**: `ffmpeg cropdetect` wird an 3 Zeitpunkten ausgeführt (00:02:00, 00:10:00, 00:20:00)
2. **Median**: Aus den Crop-Ergebnissen wird der Median gebildet
3. **Mapping**: Der ermittelte vertikale Crop wird auf eine Standard-16:9-Höhe gemappt:
   - 696px ↔ 192+192, 768px ↔ 156+156, 800px ↔ 140+140, …
   - 1080px ↔ 0+0 (kein Crop = Full HD)
4. **Asymmetrie-Erkennung**: Bei zu großen Abweichungen zwischen oberem und unterem Crop wird die Datei nach `_Check/` verschoben

Der Auto-Crop skaliert auf 1920px Breite. Horizontale Letterbox-Varianten (z.B. 2.35:1) werden auf passende Breiten gemapped.

## Metadaten-Bereinigung (Tag-Edit)

Nach der Kodierung werden automatisch MKV-Metadaten via `mkvpropedit` normalisiert:

- **Video-Track**: Sprache auf `und`, Default/Forced-Flags auf 0, Name gelöscht
- **Audio**: Erster deutscher Track (`ger`/`deu`) wird als Default markiert
- **Subtitles**: Forced-Tracks werden korrekt geflaggt (erster Forced-Track = Default+Forced)
- **Track-Namen**: Reine Sprachennamen (`Deutsch`, `English`), `Full` oder `SDH`/`Forced` werden normalisiert oder gelöscht

## Debug-Modus

```cmd
set "DEBUG_AUTOCROP=1"
```

Aktiviert detaillierte Ausgabe der Crop-Erkennung, NVEnc-Parameter und Zwischenergebnisse.

## Arbeitsablauf

1. Alle Videodateien im aktuellen Ordner werden nacheinander verarbeitet
2. Pro Datei: Codec-Prüfung → ggf. Auto-Crop → Encoding nach `_Converted/<name>.mkv`
3. Nach Encoding: 5s Pause, dann nächste Datei
4. Am Ende: Anzeige der Speicherersparnis (komprimierte vs. originale Größe)

## Fehlerbehandlung

- **Unbekannter Codec** → Datei wird nach `_Check/` verschoben
- **Crop-Probe fehlgeschlagen** → Datei wird nach `_Check/` verschoben
- **Asymmetrische schwarze Balken** → Datei wird nach `_Check/` verschoben  
- **Quelle zu klein** (< 1280×696) → Datei wird nach `_Check/` verschoben
- **Tag-Edit fehlgeschlagen** → Datei wird nach `_Check/` verschoben

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
nvencc64_wrapper hevc eac3 auto auto vsrdenoise auto false
```
HEVC, E-AC3-Audio, Auto-Qualität, Auto-Crop, VSR+Denoise, HW-Decoder, immer kodieren.

```cmd
nvencc64_wrapper av1 aac lq 720p sharp
```
AV1, AAC-Audio, niedrige Qualität, 720p Höhen-skaliert, Schärfung.

```cmd
nvencc64_wrapper hevc ac3 auto none none HDRtoSDR
```
HDR→SDR-Konvertierung mit BT.2390-Tonemapping.

## Täglicher Gebrauch

Für einen automatisierten Workflow empfiehlt sich ein minimaler Parametersatz. Der Wrapper übernimmt dann Qualitätsauswahl, Crop und Audio automatisch:

```cmd
nvencc64_wrapper hevc ac3 auto auto
```

Neue Dateien im Verzeichnis werden damit einheitlich und ohne manuelle Eingriffe verarbeitet.

## Manual

Für weiterführende Fragen: [Wiki](https://github.com/rainman74/NVEncC64_Wrapper/wiki)

---

## License

Private use / experimental. No warranty.