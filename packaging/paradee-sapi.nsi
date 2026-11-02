; Offline Windows x64 Paradee-SAPI setup. Compile with scripts/build-installer.ps1.
!include "MUI2.nsh"
!include "x64.nsh"
!include "LogicLib.nsh"

!ifndef APP_VERSION
  !define APP_VERSION "0.1.0"
!endif
!ifndef STAGE_DIR
  !error "STAGE_DIR must point to the staged runtime"
!endif
!ifndef OUT_FILE
  !error "OUT_FILE must point to the installer executable"
!endif

!define APP_NAME "Paradee-SAPI"
!define VOICE_CLSID "{14A9D4B6-B47D-46FB-B319-6067CAFB2AD9}"
!define VOICE_TOKEN "ParadeeSapiBmFable"
!define COM_KEY "SOFTWARE\Classes\CLSID\${VOICE_CLSID}"
!define SAPI_KEY "SOFTWARE\Microsoft\Speech\Voices\Tokens\${VOICE_TOKEN}"
!define ONECORE_KEY "SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\${VOICE_TOKEN}"
!define UNINSTALL_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Paradee-SAPI"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\Paradee-SAPI"
RequestExecutionLevel admin
Unicode true
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "0.1.0.0"
VIAddVersionKey "ProductName" "Paradee-SAPI"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "FileDescription" "Offline Paradee bm_fable SAPI voice setup"
VIAddVersionKey "CompanyName" "Paradee-SAPI contributors"
VIAddVersionKey "LegalCopyright" "Copyright Paradee-SAPI contributors and upstream authors"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  SetShellVarContext all
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Paradee-SAPI requires 64-bit Windows."
    Abort
  ${EndIf}
  SetRegView 64
  ReadRegStr $0 HKLM "${SAPI_KEY}" "CLSID"
  StrCmp $0 "" registration_ok
  StrCmp $0 "${VOICE_CLSID}" registration_ok
  MessageBox MB_ICONSTOP "A different SAPI engine already owns the Paradee voice token. Setup will not replace it."
  Abort
registration_ok:
FunctionEnd

Section "Install Paradee bm_fable" SEC_MAIN
  SetRegView 64
  SetOutPath "$INSTDIR"
  File "${STAGE_DIR}\paradee_sapi_bridge.dll"
  File "${STAGE_DIR}\onnxruntime.dll"
  File "${STAGE_DIR}\msvcp140.dll"
  File "${STAGE_DIR}\msvcp140_1.dll"
  File "${STAGE_DIR}\vcruntime140.dll"
  File "${STAGE_DIR}\vcruntime140_1.dll"
  File "${STAGE_DIR}\INSTALL.md"
  File "${STAGE_DIR}\THIRD_PARTY_NOTICES.md"
  File "${STAGE_DIR}\runtime-lock.json"
  File "${STAGE_DIR}\payload-manifest.json"
  SetOutPath "$INSTDIR\assets"
  File /r "${STAGE_DIR}\assets\*.*"
  SetOutPath "$INSTDIR\licenses"
  File "${STAGE_DIR}\licenses\*.*"

  WriteRegStr HKLM "${COM_KEY}" "" "Paradee SAPI5 Local Bridge"
  WriteRegStr HKLM "${COM_KEY}\InprocServer32" "" "$INSTDIR\paradee_sapi_bridge.dll"
  WriteRegStr HKLM "${COM_KEY}\InprocServer32" "ThreadingModel" "Both"

  WriteRegStr HKLM "${SAPI_KEY}" "" "Paradee bm_fable"
  WriteRegStr HKLM "${SAPI_KEY}" "CLSID" "${VOICE_CLSID}"
  WriteRegStr HKLM "${SAPI_KEY}" "809" "Paradee bm_fable"
  WriteRegStr HKLM "${SAPI_KEY}" "VoiceName" "bm_fable"
  WriteRegStr HKLM "${SAPI_KEY}" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Name" "Paradee bm_fable"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "VoiceName" "Paradee bm_fable"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Language" "0809"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Gender" "Male"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Age" "Adult"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Vendor" "Paradee-SAPI"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "VoiceId" "bm_fable"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Rate" "1.0"

  WriteRegStr HKLM "${ONECORE_KEY}" "" "Paradee bm_fable"
  WriteRegStr HKLM "${ONECORE_KEY}" "CLSID" "${VOICE_CLSID}"
  WriteRegStr HKLM "${ONECORE_KEY}" "VoiceName" "bm_fable"
  WriteRegStr HKLM "${ONECORE_KEY}" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Name" "Paradee bm_fable"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "VoiceName" "Paradee bm_fable"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Language" "0809"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Gender" "Male"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Age" "Adult"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Vendor" "Paradee-SAPI"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "VoiceId" "bm_fable"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Rate" "1.0"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "Paradee-SAPI bm_fable"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "Paradee-SAPI contributors"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1
  CreateDirectory "$SMPROGRAMS\Paradee-SAPI"
  CreateShortCut "$SMPROGRAMS\Paradee-SAPI\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Function un.onInit
  SetShellVarContext all
  SetRegView 64
  ReadRegStr $0 HKLM "${UNINSTALL_KEY}" "InstallLocation"
  StrCmp $0 "$INSTDIR" uninstall_ok
  MessageBox MB_ICONSTOP "The installed Paradee-SAPI location does not match this uninstaller. Nothing was removed."
  Abort
uninstall_ok:
FunctionEnd

Section "Uninstall"
  SetRegView 64
  ReadRegStr $0 HKLM "${COM_KEY}\InprocServer32" ""
  StrCmp $0 "$INSTDIR\paradee_sapi_bridge.dll" 0 +2
    DeleteRegKey HKLM "${COM_KEY}"
  ReadRegStr $0 HKLM "${SAPI_KEY}" "AssetsDir"
  StrCmp $0 "$INSTDIR\assets" 0 +2
    DeleteRegKey HKLM "${SAPI_KEY}"
  ReadRegStr $0 HKLM "${ONECORE_KEY}" "AssetsDir"
  StrCmp $0 "$INSTDIR\assets" 0 +2
    DeleteRegKey HKLM "${ONECORE_KEY}"
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
  Delete "$SMPROGRAMS\Paradee-SAPI\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Paradee-SAPI"
  Delete /REBOOTOK "$INSTDIR\paradee_sapi_bridge.dll"
  Delete /REBOOTOK "$INSTDIR\onnxruntime.dll"
  Delete /REBOOTOK "$INSTDIR\msvcp140.dll"
  Delete /REBOOTOK "$INSTDIR\msvcp140_1.dll"
  Delete /REBOOTOK "$INSTDIR\vcruntime140.dll"
  Delete /REBOOTOK "$INSTDIR\vcruntime140_1.dll"
  Delete "$INSTDIR\INSTALL.md"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  Delete "$INSTDIR\runtime-lock.json"
  Delete "$INSTDIR\payload-manifest.json"
  RMDir /r /REBOOTOK "$INSTDIR\assets"
  RMDir /r /REBOOTOK "$INSTDIR\licenses"
  Delete /REBOOTOK "$INSTDIR\Uninstall.exe"
  RMDir /REBOOTOK "$INSTDIR"
SectionEnd
