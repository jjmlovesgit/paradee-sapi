# Install Paradee-SAPI on Windows

This installer adds the offline `Paradee bm_fable` voice to 64-bit Windows SAPI.
It includes the model, ONNX Runtime, eSpeak NG, and voice registration. Playback
also includes the app-local Visual C++ runtime files ONNX Runtime needs.
Playback does not require Python, a browser extension, a local server, or an internet
connection. Administrator access is required to install or uninstall the voice
for all users.

## Install

1. Close Edge and other apps currently speaking with Paradee.
2. Run `Paradee-SAPI-0.1.1-x64-Setup.exe` and approve the Windows administrator
   prompt. The installer places files in `C:\Program Files\Paradee-SAPI` and
   registers the `Paradee bm_fable` voice. It does not change your default
   Windows voice.
3. Open Edge again. Start **Read Aloud**, open **Voice options**, and select
   **Paradee bm_fable**. If the voice is not listed, close Edge completely and
   reopen it; a Windows restart may be needed after a first machine-wide voice
   registration.

To check classic SAPI independently, open **Windows Speech Properties** and
use the **Text to Speech** tab's **Preview Voice** button. A SAPI application
can also select the installed name `Paradee bm_fable`.

The 0.1.1 setup executable is 18.08 MiB and its installed files total 43.74
MiB on the development desktop. The earlier 0.1.0 package passed clean laptop
installation, offline speech, Edge playback, and uninstall. Repeat those checks
for 0.1.1; its new word boundary events have only been tested on the desktop.
The test setup executable is not code-signed, so Windows may show an unknown
publisher prompt. Obtain it only from the project build you trust.

## Uninstall or upgrade

Close Edge and other apps using the voice, then use **Windows Settings → Apps →
Installed apps → Paradee-SAPI bm_fable → Uninstall**. The installer also adds
**Paradee-SAPI → Uninstall** to the Start menu. Uninstall removes the voice
tokens and package files. If you manually made Paradee your Windows default
voice, select another default before uninstalling so it does not point to a
removed voice. Installation itself does not change the default.

For an upgrade, close speech apps and run the newer setup package. If Windows
reports files in use, exit those apps and retry; a reboot may be required to
finish removal of a loaded DLL. Uninstall and reinstall passed on the
development desktop. Upgrade behavior on the clean laptop remains an
acceptance test.

## Privacy and current compatibility

The Paradee speech DLL reads the installed model and language data locally and
does not call a TTS service. A browser or other host app can independently send
its own data or telemetry; this installer does not control the host app.

The development desktop test confirmed Windows SAPI playback and selection in
Edge Read Aloud. Chrome Reading mode and Discord did not select this voice in
the recorded tests. The clean laptop passed the 0.1.0 installer. The 0.1.1
desktop test restored Edge word highlighting with Paradee; that newer build is
published for a clean laptop retest. Other Windows apps need individual
compatibility tests.

## Troubleshooting

- **Voice missing in Edge:** fully exit Edge, reopen it, then inspect Voice
  options. If needed, restart Windows and try again.
- **Preview Voice fails:** confirm that installation completed with admin
  access. Close speech apps and restart Windows before retrying.
- **No audio:** check the Windows output device, then try the Speech Properties
  preview to distinguish an app issue from a voice issue.
- **Text sounds unusual:** the native eSpeak phonemizer still differs from the
  upstream Paradee Misaki phonemizer. Pronunciation parity remains an open
  quality improvement.

See `THIRD_PARTY_NOTICES.md` and the `licenses` directory in the installed
folder for bundled component notices.
