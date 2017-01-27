unit U_InetFile;

interface

uses
  Windows, WinInet, SysUtils, Forms;

{
  function downloading file from internet
}
function GetInetFile(const AFileURL, ADestFileName: String): boolean;

implementation

function GetInetFile(const AFileURL, ADestFileName: String): boolean;
const
  C_BUFFERSIZE = 1024;
var
  hSession, hURL: HInternet;
  Buffer: array[1..C_BUFFERSIZE] of Byte;
  BufferLen: DWORD;
  f: File;
  sAppName: string;
begin
  Result:=False;
  sAppName := ExtractFileName(Application.ExeName);
  hSession := InternetOpen(PChar(sAppName),
                          INTERNET_OPEN_TYPE_PRECONFIG,
                          nil, nil, 0);
  try
    hURL := InternetOpenURL(hSession,
              PChar(AFileURL),
              nil,0,0,0);
    try
      AssignFile(f, ADestFileName);
      try
        Rewrite(f,1);
        repeat
        InternetReadFile(hURL, @Buffer,
                         SizeOf(Buffer), BufferLen);
        BlockWrite(f, Buffer, BufferLen)
        until BufferLen = 0;
      finally
        CloseFile(f);
      end;
      Result:=True;
    finally
      InternetCloseHandle(hURL)
    end
  finally
    InternetCloseHandle(hSession)
  end
end;

end.
