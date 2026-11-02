# Third-party components in the Windows installer

This test package contains these upstream components and their license texts
under `licenses/`:

Project source: <https://github.com/jjmlovesgit/paradee-sapi>.

- Paradee v1.2 int8 model and configuration, by Sahil Mahendrakar, Apache-2.0.
  Model revision: `ed2934d4df8a4fd891e29584c5e1104649409765` at
  <https://huggingface.co/sahilmahendrakar/Paradee-8M-v1.2>.
- ONNX Runtime 1.31.1 native Windows x64 library, Microsoft, MIT.
  <https://github.com/microsoft/onnxruntime>
- App-local Microsoft Visual C++ runtime DLLs 14.50.35710 from the licensed
  Visual Studio Build Tools installation. These are included so ONNX Runtime
  can load on a clean offline Windows laptop. Their redistribution is subject
  to the Microsoft Visual Studio license terms. Local deployment means this
  package must ship updates when those runtime libraries are serviced.
- eSpeak NG 1.52.0 library and speech data, eSpeak NG contributors,
  GPL-3.0-or-later. The binary and data came from the `espeakng-loader` 0.2.4
  Windows x64 wheel. Corresponding upstream source:
  <https://github.com/espeak-ng/espeak-ng/tree/1.52.0>.
- `espeakng-loader` packaging, thewh1teagle, MIT.
  <https://github.com/thewh1teagle/espeakng-loader>
- SAPI COM shell adapted from `zotero-minimax-tts`, MIT. Its license is also
  retained beside the source at `src/sapi5_bridge/UPSTREAM_LICENSE`.
- Installer built with NSIS 3.12; its applicable licenses are in `NSIS.txt`.

The package does not include Python or the `espeakng-loader` Python module.
Before public distribution, review the complete obligations for the bundled
eSpeak NG library/data and the combined binary, including corresponding-source
availability. The current package is for local installation testing.
