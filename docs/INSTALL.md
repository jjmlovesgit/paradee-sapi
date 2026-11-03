# Install Paradee-SAPI on Windows

The 0.2.0 installer adds the offline `Paradee af_heart`, `Paradee bf_isabella`,
`Paradee am_puck`, and `Paradee bm_fable` voices to 64-bit Windows SAPI through
one shared model and runtime.
It includes the model, ONNX Runtime, eSpeak NG, and voice registration. Playback
also includes the app-local Visual C++ runtime files ONNX Runtime needs.
Playback does not require Python, a browser extension, a local server, or an internet
connection. Administrator access is required to install or uninstall the voice
for all users.

## Install

1. Close Edge and other apps currently speaking with Paradee.
2. Download and run the [Paradee-SAPI 0.2.0 Windows x64 setup executable](https://github.com/jjmlovesgit/paradee-sapi/releases/download/v0.2.0/Paradee-SAPI-0.2.0-x64-Setup.exe),
   then approve the Windows administrator prompt. The installer places files in
   `C:\Program Files\Paradee-SAPI` and registers its Paradee voices. It does
   not change your default Windows voice.
3. Open Edge again. Start **Read Aloud**, open **Voice options**, and select
   a **Paradee** voice. If it is not listed, close Edge completely and
   reopen it; a Windows restart may be needed after a first machine-wide voice
   registration.

To check classic SAPI independently, open **Windows Speech Properties** and
use the **Text to Speech** tab's **Preview Voice** button. A SAPI application
can also select the installed name `Paradee bm_fable`.

The setup executable is 18.08 MiB and its installed files total 43.74 MiB on
the development desktop. The installer is not code-signed, so Windows may show
an unknown publisher prompt. Verify its checksum from the release page before
installation.

## Uninstall or upgrade

Close Edge and other apps using the voice, then use **Windows Settings → Apps →
Installed apps → Paradee-SAPI → Uninstall**. The installer also adds
**Paradee-SAPI → Uninstall** to the Start menu. Uninstall removes the voice
tokens and package files. If you manually made Paradee your Windows default
voice, select another default before uninstalling so it does not point to a
removed voice. The 0.2.0 uninstaller refuses removal while Paradee is the
current user's default. Installation itself does not change the default.

For an upgrade, close speech apps and run the newer setup package. If Windows
reports files in use, exit those apps and retry; a reboot may be required to
finish removal of a loaded DLL. Uninstall and reinstall passed on the
development desktop. Upgrade behavior on the clean laptop remains an
acceptance test.

## Privacy and current compatibility

The Paradee speech DLL reads the installed model and language data locally and
does not call a TTS service. A browser or other host app can independently send
its own data or telemetry; this installer does not control the host app.

Windows SAPI and Edge Read Aloud have been verified with all four voices, and
Edge word highlighting works. Chrome Reading mode and Discord did not select
Paradee in recorded tests. Other Windows apps need individual compatibility
tests.

To keep a malformed or unexpectedly large SAPI request from monopolizing its
host process, the native engine rejects a single `Speak` call over 1,048,576
UTF-16 characters, caps generated audio, and observes cancellation between
model chunks. Reading applications should submit longer documents in bounded
segments, as Edge and other interactive readers normally do.

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
