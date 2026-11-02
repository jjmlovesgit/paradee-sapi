# Paradee-SAPI Italian Voice Pack

The Italian pack is a separate offline Windows x64 installer. It contains the
`if_sara` and `im_nicola` Italian student models, Italian eSpeak NG phonemization, and the SAPI
runtime. It does not contain English voice weights or require the English
Paradee-SAPI installer.

## Install and try the Italian voices

1. Close Edge and other apps that use SAPI voices.
2. Run the Italian setup executable and approve the administrator
   prompt. The installer registers `Paradee if_sara` and `Paradee im_nicola` with Italian language ID
   `0410` and installs to `C:\Program Files\Paradee-SAPI-Italian`.
3. Fully quit Edge after installation, including its background `msedge.exe`
   processes, then reopen it. Edge may otherwise keep an older voice list.
4. Open Windows Speech Properties or Edge Read Aloud and select either Italian voice.
   SAPI-compatible apps can also select the voice by its registered name.
5. Test Italian accents, punctuation, dates, numbers, long text, and offline
   playback. Voice quality is bounded by the Kokoro `if_sara` teacher.

The setup executable is not code-signed, so Windows may show an unknown
publisher prompt. Use the checksum published with the installer.

## Uninstall

Close Edge and apps using the voice. Select **Windows Settings → Apps →
Installed apps → Paradee-SAPI Italian → Uninstall**, or use the Start menu
uninstaller. If `Paradee if_sara` is the Windows default, choose another voice
before uninstalling.

## Build

On the Windows build desktop, run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-italian-installer.ps1 -Version 0.2.0
```

`packaging/italian-voices-lock.json` pins the upstream model revision and
hashes. The package includes both Italian student models, not the English
Paradee model. It has an independent SAPI COM class and install directory, so
it can coexist with the English package.

## Current validation

The installed Sara voice spoke an accented sentence through SAPI on the
desktop, and Edge playback was confirmed by the user. Edge listed Sara after
its background processes were stopped and the browser reopened. Nicola
requires installed desktop and Edge playback checks before release.
