unit FMX.FontInstaller;

{ forked from TheOriginalBytePlayer }

interface

{$IFNDEF MSWINDOWS}
   {$MESSAGE ERROR 'Windows Only Unit'}
{$ENDIF}

uses
  System.SysUtils, System.Classes, WinAPI.Windows, Winapi.Messages;

function IsKnownFont(const FontFamily: string): Boolean;

function GetLoadedFonts: TArray<string>;

procedure CollectFonts(FontList: TStringList);

implementation

uses
  FMX.Canvas.D2D, FMX.Platform.Win, System.IOUtils;

var
  AddedFonts: TStringList;


function EnumFontsProc(var LogFont: TLogFont; var TextMetric: TTextMetric; FontType: Integer; Data: Pointer): Integer; stdcall;
var
  S: TStrings;
  Temp: string;
begin
  S := TStrings(Data);
  Temp := LogFont.lfFaceName;
  if (S.Count = 0) or (AnsiCompareText(S[S.Count - 1], Temp) <> 0) then
    S.Add(Temp);
  Result := 1;
end;

procedure CollectFonts(FontList: TStringList);
var
  DC: HDC;
  LFont: TLogFont;
begin
  DC := GetDC(0);
  try
    FillChar(LFont, SizeOf(LFont), 0);
    LFont.lfCharset := DEFAULT_CHARSET;
    EnumFontFamiliesEx(DC, LFont, @EnumFontsProc, LPARAM(FontList), 0);
  finally
    ReleaseDC(0, DC);
  end;
end;

function IsKnownFont(const FontFamily: string): Boolean;
var
  AvailableFonts: TStringList;
begin
  AvailableFonts := TStringList.Create;
  try
    CollectFonts(AvailableFonts);
    Result := AvailableFonts.IndexOf(FontFamily) >= 0;
  finally
    AvailableFonts.Free;
  end;
end;

function GetLoadedFonts: TArray<string>;
begin
  Result := AddedFonts.ToStringArray;
end;

function LoadTemporaryFonts: Boolean;
var
  FontID: Integer;
  ResStream: TResourceStream;

  function GetTempFileNameWithExt(WithExtension: string): string;
  begin
    Result := TPath.GetTempFileName + WithExtension;
  end;

begin
  Result := False;
  FontID := 1;
  while FindResource(HInstance, PChar(FontID), RT_FONT) <> 0 do
  begin
    ResStream := TResourceStream.CreateFromID(HInstance, FontID, RT_FONT);
    try
      AddedFonts.Add(GetTempFileNameWithExt('.ttf'));
      ResStream.SaveToFile(AddedFonts[AddedFonts.Count - 1]);
      Result := (AddFontResource(PChar(AddedFonts[AddedFonts.Count - 1])) <> 0) or Result;
    finally
      ResStream.Free;
    end;
    Inc(FontID);
  end;

  if not Result then
    Exit;

  PostMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);
  PostMessage(ApplicationHWnd, WM_FONTCHANGE, 0, 0);

  UnregisterCanvasClasses;
  RegisterCanvasClasses;
end;

procedure UnloadTemporaryFonts;
begin
  while AddedFonts.Count > 0 do
  begin
    RemoveFontResource(PWideChar(AddedFonts[0]));
    AddedFonts.Delete(0);
  end;
  PostMessage(HWND_BROADCAST, WM_FONTCHANGE, 0, 0);
  PostMessage(ApplicationHWnd, WM_FONTCHANGE, 0, 0);
end;

initialization
begin
  AddedFonts := TStringList.Create;
  try
    LoadTemporaryFonts;
  except
  end;
end;

finalization
begin
  try
    UnloadTemporaryFonts;
  except
  end;
  AddedFonts.Free;
end;

end.

