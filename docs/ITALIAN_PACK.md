# Paradee-SAPI Italian Voice Pack

The Italian pack is a separate offline Windows x64 installer. It contains the
`if_sara` Italian student model, Italian eSpeak NG phonemization, and the SAPI
runtime. It does not contain English voice weights or require the English
Paradee-SAPI installer.

## Install and try `if_sara`

1. Close Edge and other apps that use SAPI voices.
2. Run [Paradee-SAPI-Italian-0.1.1-x64-Setup.exe](https://github.com/jjmlovesgit/paradee-sapi/releases/download/v0.1.1-italian-preview.1/Paradee-SAPI-Italian-0.1.1-x64-Setup.exe) and approve the administrator
   prompt. The installer registers `Paradee if_sara` with Italian language ID
   `0410` and installs to `C:\Program Files\Paradee-SAPI-Italian`.
3. Fully quit Edge after installation, including its background `msedge.exe`
   processes, then reopen it. Edge may otherwise keep an older voice list.
4. Open Windows Speech Properties or Edge Read Aloud and select `Paradee if_sara`.
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
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-italian-installer.ps1 -Version 0.1.1
```

`packaging/italian-if-sara-lock.json` pins the upstream model revision and
hashes. The package includes only `if_sara/model_int8.onnx`, not the English
Paradee model. It has an independent SAPI COM class and install directory, so
it can coexist with the English package.

## Current validation

The installed Italian voice spoke an accented sentence through SAPI on the
desktop. Edge listed `Paradee if_sara` after its background processes were
stopped and the browser reopened. Edge playback, clean-machine install,
offline playback, uninstall, and resource checks remain to be confirmed.
