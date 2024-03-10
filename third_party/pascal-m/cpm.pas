unit cpm;

interface

procedure GetCommandLine(var commandLine: packed array of char);

implementation
    procedure GetCommandLine(var commandLine: packed array of char);
    var
        s: ShortString;
        i: integer;
    begin
        s := '';
        for i := 1 to ParamCount do
        begin
            if i <> 1 then
                s := s + ' ';
            s := s + ParamStr(i);
        end;

        commandLine[0] := chr(Length(s));
        for i := 0 to Length(s)-1 do
            commandLine[i+1] := s[i+1];
    end;
end.

