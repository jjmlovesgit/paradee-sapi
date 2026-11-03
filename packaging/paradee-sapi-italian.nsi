!include "MUI2.nsh"

!ifndef APP_VERSION
  !error "APP_VERSION is required"
!endif
!ifndef STAGE_DIR
  !error "STAGE_DIR is required"
!endif
!ifndef OUT_FILE
  !error "OUT_FILE is required"
!endif

!define APP_NAME "Paradee-SAPI Italian"
!define VOICE_NAME "Paradee if_sara"
!define TOKEN "ParadeeSapiIfSara"
!define NICOLA_TOKEN "ParadeeSapiImNicola"
!define CLSID "{B17E11A1-9A42-40A6-8DF4-5D0F7DAA3A51}"
!define INSTALL_DIR "$PROGRAMFILES64\Paradee-SAPI-Italian"
!define UNINSTALL_KEY "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Paradee-SAPI-Italian"
!define SAPI_KEY "SOFTWARE\Microsoft\Speech\Voices\Tokens\${TOKEN}"
!define ONECORE_KEY "SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\${TOKEN}"
!define NICOLA_SAPI_KEY "SOFTWARE\Microsoft\Speech\Voices\Tokens\${NICOLA_TOKEN}"
!define NICOLA_ONECORE_KEY "SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens\${NICOLA_TOKEN}"
!define COM_KEY "SOFTWARE\Classes\CLSID\${CLSID}"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "${OUT_FILE}"
InstallDir "${INSTALL_DIR}"
RequestExecutionLevel admin
Unicode true
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "FileDescription" "Offline Italian SAPI voice setup"
VIAddVersionKey "CompanyName" "Paradee-SAPI contributors"
VIAddVersionKey "LegalCopyright" "Copyright Paradee-SAPI contributors and upstream authors"

; Use the same Windows-standard Modern UI pages and colors as the English pack.
!define MUI_INSTFILESPAGE_COLORS /windows
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  SetRegView 64
  ReadRegStr $0 HKLM "${SAPI_KEY}" "CLSID"
  StrCmp $0 "" +4
  StrCmp $0 "${CLSID}" +3
    MessageBox MB_ICONSTOP "Another SAPI engine owns the Paradee if_sara token. Setup will not replace it."
    Abort
  ReadRegStr $0 HKLM "${ONECORE_KEY}" "CLSID"
  StrCmp $0 "" +4
  StrCmp $0 "${CLSID}" +3
    MessageBox MB_ICONSTOP "Another OneCore engine owns the Paradee if_sara token. Setup will not replace it."
    Abort
  ReadRegStr $0 HKLM "${NICOLA_SAPI_KEY}" "CLSID"
  StrCmp $0 "" +4
  StrCmp $0 "${CLSID}" +3
    MessageBox MB_ICONSTOP "Another SAPI engine owns the Paradee im_nicola token. Setup will not replace it."
    Abort
  ReadRegStr $0 HKLM "${NICOLA_ONECORE_KEY}" "CLSID"
  StrCmp $0 "" +4
  StrCmp $0 "${CLSID}" +3
    MessageBox MB_ICONSTOP "Another OneCore engine owns the Paradee im_nicola token. Setup will not replace it."
    Abort
FunctionEnd

Section "Install Italian voice" SEC_MAIN
  SetRegView 64
  SetShellVarContext all
  SetOutPath "$INSTDIR"
  File "${STAGE_DIR}\paradee_sapi_bridge.dll"
  File "${STAGE_DIR}\onnxruntime.dll"
  File "${STAGE_DIR}\msvcp140.dll"
  File "${STAGE_DIR}\msvcp140_1.dll"
  File "${STAGE_DIR}\vcruntime140.dll"
  File "${STAGE_DIR}\vcruntime140_1.dll"
  File "${STAGE_DIR}\payload-manifest.json"
  File "${STAGE_DIR}\runtime-lock-italian.json"
  File "${STAGE_DIR}\THIRD_PARTY_NOTICES.md"
  SetOutPath "$INSTDIR\assets"
  File /r "${STAGE_DIR}\assets\*.*"
  SetOutPath "$INSTDIR\licenses"
  File /r "${STAGE_DIR}\licenses\*.*"

  WriteRegStr HKLM "${COM_KEY}\InprocServer32" "" "$INSTDIR\paradee_sapi_bridge.dll"
  WriteRegStr HKLM "${COM_KEY}\InprocServer32" "ThreadingModel" "Both"
  WriteRegStr HKLM "${SAPI_KEY}" "" "${VOICE_NAME}"
  WriteRegStr HKLM "${SAPI_KEY}" "CLSID" "${CLSID}"
  WriteRegStr HKLM "${SAPI_KEY}" "0410" "${VOICE_NAME}"
  WriteRegStr HKLM "${SAPI_KEY}" "VoiceName" "if_sara"
  WriteRegStr HKLM "${SAPI_KEY}" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Name" "${VOICE_NAME}"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "VoiceName" "${VOICE_NAME}"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Language" "0410"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Gender" "Female"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Age" "Adult"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Vendor" "Paradee-SAPI"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "VoiceId" "if_sara"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${SAPI_KEY}\Attributes" "Rate" "1.0"
  WriteRegStr HKLM "${ONECORE_KEY}" "" "${VOICE_NAME}"
  WriteRegStr HKLM "${ONECORE_KEY}" "CLSID" "${CLSID}"
  WriteRegStr HKLM "${ONECORE_KEY}" "0410" "${VOICE_NAME}"
  WriteRegStr HKLM "${ONECORE_KEY}" "VoiceName" "if_sara"
  WriteRegStr HKLM "${ONECORE_KEY}" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Name" "${VOICE_NAME}"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "VoiceName" "${VOICE_NAME}"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Language" "0410"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Gender" "Female"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Age" "Adult"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Vendor" "Paradee-SAPI"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "VoiceId" "if_sara"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${ONECORE_KEY}\Attributes" "Rate" "1.0"

  WriteRegStr HKLM "${NICOLA_SAPI_KEY}" "" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}" "CLSID" "${CLSID}"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}" "0410" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}" "VoiceName" "im_nicola"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "Name" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "VoiceName" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "Language" "0410"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "Gender" "Male"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "Age" "Adult"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "Vendor" "Paradee-SAPI"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "VoiceId" "im_nicola"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${NICOLA_SAPI_KEY}\Attributes" "Rate" "1.0"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}" "" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}" "CLSID" "${CLSID}"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}" "0410" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}" "VoiceName" "im_nicola"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "Name" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "VoiceName" "Paradee im_nicola"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "Language" "0410"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "Gender" "Male"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "Age" "Adult"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "Vendor" "Paradee-SAPI"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "VoiceId" "im_nicola"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "AssetsDir" "$INSTDIR\assets"
  WriteRegStr HKLM "${NICOLA_ONECORE_KEY}\Attributes" "Rate" "1.0"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "Paradee-SAPI contributors"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1
  CreateDirectory "$SMPROGRAMS\Paradee-SAPI Italian"
  CreateShortcut "$SMPROGRAMS\Paradee-SAPI Italian\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
SectionEnd

Function un.onInit
  SetRegView 64
  ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Speech\Voices" "DefaultTokenId"
  StrCmp $0 "HKEY_LOCAL_MACHINE\${SAPI_KEY}" 0 +3
    MessageBox MB_ICONSTOP "Paradee if_sara is your default voice. Select another default before uninstalling."
    Abort
  ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Speech_OneCore\Voices" "DefaultTokenId"
  StrCmp $0 "HKEY_LOCAL_MACHINE\${ONECORE_KEY}" 0 +3
    MessageBox MB_ICONSTOP "Paradee if_sara is your default voice. Select another default before uninstalling."
    Abort
  ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Speech\Voices" "DefaultTokenId"
  StrCmp $0 "HKEY_LOCAL_MACHINE\${NICOLA_SAPI_KEY}" 0 +3
    MessageBox MB_ICONSTOP "Paradee im_nicola is your default voice. Select another default before uninstalling."
    Abort
  ReadRegStr $0 HKCU "SOFTWARE\Microsoft\Speech_OneCore\Voices" "DefaultTokenId"
  StrCmp $0 "HKEY_LOCAL_MACHINE\${NICOLA_ONECORE_KEY}" 0 +3
    MessageBox MB_ICONSTOP "Paradee im_nicola is your default voice. Select another default before uninstalling."
    Abort
FunctionEnd

Section "Uninstall"
  SetRegView 64
  SetShellVarContext all
  ReadRegStr $0 HKLM "${SAPI_KEY}" "AssetsDir"
  StrCmp $0 "$INSTDIR\assets" 0 +2
    DeleteRegKey HKLM "${SAPI_KEY}"
  ReadRegStr $0 HKLM "${ONECORE_KEY}" "AssetsDir"
  StrCmp $0 "$INSTDIR\assets" 0 +2
    DeleteRegKey HKLM "${ONECORE_KEY}"
  ReadRegStr $0 HKLM "${NICOLA_SAPI_KEY}" "AssetsDir"
  StrCmp $0 "$INSTDIR\assets" 0 +2
    DeleteRegKey HKLM "${NICOLA_SAPI_KEY}"
  ReadRegStr $0 HKLM "${NICOLA_ONECORE_KEY}" "AssetsDir"
  StrCmp $0 "$INSTDIR\assets" 0 +2
    DeleteRegKey HKLM "${NICOLA_ONECORE_KEY}"
  ReadRegStr $0 HKLM "${COM_KEY}\InprocServer32" ""
  StrCmp $0 "$INSTDIR\paradee_sapi_bridge.dll" 0 +2
    DeleteRegKey HKLM "${COM_KEY}"
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
  Delete "$SMPROGRAMS\Paradee-SAPI Italian\Uninstall.lnk"
  RMDir "$SMPROGRAMS\Paradee-SAPI Italian"
  Delete /REBOOTOK "$INSTDIR\paradee_sapi_bridge.dll"
  Delete /REBOOTOK "$INSTDIR\onnxruntime.dll"
  Delete /REBOOTOK "$INSTDIR\msvcp140.dll"
  Delete /REBOOTOK "$INSTDIR\msvcp140_1.dll"
  Delete /REBOOTOK "$INSTDIR\vcruntime140.dll"
  Delete /REBOOTOK "$INSTDIR\vcruntime140_1.dll"
  Delete "$INSTDIR\payload-manifest.json"
  Delete "$INSTDIR\runtime-lock-italian.json"
  Delete "$INSTDIR\THIRD_PARTY_NOTICES.md"
  RMDir /r /REBOOTOK "$INSTDIR\assets"
  RMDir /r /REBOOTOK "$INSTDIR\licenses"
  Delete /REBOOTOK "$INSTDIR\Uninstall.exe"
  RMDir /REBOOTOK "$INSTDIR"
SectionEnd
