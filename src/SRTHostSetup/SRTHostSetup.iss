#define AppName "SRT Host"
#define AppExeNamePrefix "SRTHost"
#define SuffixText32Bit "(32-bit)"
#define SuffixText64Bit "(64-bit)"
#define AppURL "https://www.SpeedRunTool.com/"

; If the artifact directory exists, we're operating in the CI/CD pipeline on GitHub so use that path.
; Otherwise we're operating locally.
#if DirExists("..\..\artifact")
#define AppPublishDir "..\..\artifact"
#else
#define AppPublishDir "..\SRTHost\bin\Release\net7.0-windows\publish"
#endif

#define AppExe32Path AppPublishDir + "\" + AppExeNamePrefix + "32.exe"
#define AppExe64Path AppPublishDir + "\" + AppExeNamePrefix + "64.exe"

#ifndef AppCompany
#define AppCompany GetFileCompany(AppExe64Path)
#endif

#ifndef AppCopyright
#define AppCopyright GetFileCopyright(AppExe64Path)
#endif

#ifndef AppFileVersion
#define AppFileVersion GetFileVersionString(AppExe64Path)
#endif

#ifndef AppProductVersion
#define AppProductVersion GetFileProductVersion(AppExe64Path)
;#define AppProductVersion "4.0.0-beta"
#endif

; This is defined via command-line in the CI/CD pipeline as either -alpha, -beta, -RC, or an empty string
#ifndef VersionTag
#define VersionTag AppProductVersion
#endif

[Setup]
; NOTE: The value of AppId uniquely identifies this application. Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{B10F5521-C2F3-4A9D-AB05-1E0BF0A27AC1}
AppName={#AppName}
AppVersion={#AppProductVersion}
;AppVerName={#AppName} {#AppProductVersion}
AppPublisher={#AppCompany}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
VersionInfoCompany={#AppCompany}
VersionInfoCopyright={#AppCopyright}
VersionInfoVersion={#AppFileVersion}
DefaultDirName={localappdata}\{#AppCompany}\{#AppExeNamePrefix}
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no
TimeStampsInUTC=yes
ArchitecturesAllowed=x86 x64
; Require Windows 7 SP1 or newer (minimum needed for .NET 7)
MinVersion=6.1sp1
OutputBaseFilename=SRTHostSetup-v{#VersionTag}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#AppPublishDir}\appsettings.json"; DestDir: "{app}"; Flags: onlyifdoesntexist
Source: "{#AppPublishDir}\appsettings.Production.json"; DestDir: "{app}"; Flags: onlyifdoesntexist
Source: "{#AppPublishDir}\appsettings.Development.json"; DestDir: "{app}"; Flags: onlyifdoesntexist
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#AppPublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs
Source: "NetCoreCheck_x64.exe"; DestDir: "{tmp}"; Flags: dontcopy
Source: "NetCoreCheck_x86.exe"; DestDir: "{tmp}"; Flags: dontcopy
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Dirs]
Name: "{app}\.db"
Name: "{app}\plugins"

[Icons]
Name: "{userprograms}\{#AppName} {#SuffixText32Bit}"; Filename: "{app}\{#AppExeNamePrefix}32.exe"
Name: "{userprograms}\{#AppName} {#SuffixText64Bit}"; Filename: "{app}\{#AppExeNamePrefix}64.exe"
Name: "{userdesktop}\{#AppName} {#SuffixText32Bit}"; Filename: "{app}\{#AppExeNamePrefix}32.exe"; Tasks: desktopicon
Name: "{userdesktop}\{#AppName} {#SuffixText64Bit}"; Filename: "{app}\{#AppExeNamePrefix}64.exe"; Tasks: desktopicon

[Code]
var
  DownloadPage: TDownloadWizardPage;

function OnDownloadProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  if Progress = ProgressMax then
    Log(Format('Successfully downloaded file to {tmp}: %s', [FileName]));
  Result := True;
end;

procedure InitializeWizard;
begin
  DownloadPage := CreateDownloadPage(SetupMessage(msgWizardPreparing), SetupMessage(msgPreparingDesc), @OnDownloadProgress);
end;

function IsDotNetInstalled(const ProductName, ProductVersion, ProductArch: String): Boolean;
var
  ResultCode: Integer;
begin
  if not FileExists(ExpandConstant('{tmp}{\}') + 'netcorecheck_' + ProductArch + '.exe') then begin
    ExtractTemporaryFile('netcorecheck_' + ProductArch + '.exe');
  end;
  Result := ShellExec('', ExpandConstant('{tmp}{\}') + 'netcorecheck_' + ProductArch + '.exe', '-n ' + ProductName + ' -v ' + ProductVersion, '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
end;

function RunProgram(const Filename, Params: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if ShellExec('', Filename, Params, '', SW_SHOWNORMAL, ewWaitUntilTerminated, ResultCode) then begin
    if ResultCode = 0 then begin // ERROR_SUCCESS
      Result := True;
    end
    else if ResultCode = 1641 then begin // ERROR_SUCCESS_REBOOT_INITIATED
      Result := True; // Reboot needed.
    end
    else if ResultCode = 3010 then begin // ERROR_SUCCESS_REBOOT_REQUIRED
      Result := True; // Reboot needed.
    end;
  end;
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  if CurPageID = wpReady then begin
    DownloadPage.Clear;

    if (not IsDotNetInstalled('Microsoft.AspNetCore.App', '7.0.0', 'x64') OR not IsDotNetInstalled('Microsoft.AspNetCore.App', '7.0.0', 'x86')) then begin
        DownloadPage.Add('https://aka.ms/dotnet/7.0/dotnet-hosting-win.exe', 'dotnet-hosting-win.exe', '');
    end;

    if (not IsDotNetInstalled('Microsoft.WindowsDesktop.App', '7.0.0', 'x64')) then begin
        DownloadPage.Add('https://aka.ms/dotnet/7.0/windowsdesktop-runtime-win-x64.exe', 'windowsdesktop-runtime-win-x64.exe', '');
    end;

    if not IsDotNetInstalled('Microsoft.WindowsDesktop.App', '7.0.0', 'x86') then begin
        DownloadPage.Add('https://aka.ms/dotnet/7.0/windowsdesktop-runtime-win-x86.exe', 'windowsdesktop-runtime-win-x86.exe', '');
    end;

    DownloadPage.Show;
    try
      try
        DownloadPage.Download; // This downloads the files to {tmp}
        
        if FileExists(ExpandConstant('{tmp}{\}') + 'dotnet-hosting-win.exe') then begin
          RunProgram(ExpandConstant('{tmp}{\}') + 'dotnet-hosting-win.exe', 'lcid ' + IntToStr(GetUILanguage) + ' /passive /norestart');
        end;
        
        if FileExists(ExpandConstant('{tmp}{\}') + 'windowsdesktop-runtime-win-x64.exe') then begin
          RunProgram(ExpandConstant('{tmp}{\}') + 'windowsdesktop-runtime-win-x64.exe', 'lcid ' + IntToStr(GetUILanguage) + ' /passive /norestart');
        end;
        
        if FileExists(ExpandConstant('{tmp}{\}') + 'windowsdesktop-runtime-win-x86.exe') then begin
          RunProgram(ExpandConstant('{tmp}{\}') + 'windowsdesktop-runtime-win-x86.exe', 'lcid ' + IntToStr(GetUILanguage) + ' /passive /norestart');
        end;
        
        Result := True;
      except
        if DownloadPage.AbortedByUser then
          Log('Aborted by user.')
        else
          SuppressibleMsgBox(AddPeriod(GetExceptionMessage), mbCriticalError, MB_OK, IDOK);
        Result := False;
      end;
    finally
      DownloadPage.Hide;
    end;
  end else
    Result := True;
end;
