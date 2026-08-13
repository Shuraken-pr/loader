library TestDLL;

uses
  System.SysUtils,
  System.Classes,
  intf_dll in '..\..\Common\intf_dll.pas';

{$R *.res}

type
  TStubDLL = class(TInterfacedObject, IDLLIntf)
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
  end;

{ TStubDLL }

procedure TStubDLL.Fin;
begin

end;

function TStubDLL.GetDescription: WideString;
begin
  Result := 'Test Dll for DUnitX Tests';
end;

procedure TStubDLL.Init;
begin

end;

function InitProc: IInterface; safecall;
begin
  Result := TStubDLL.Create;
end;

function FakeInitProc: IInterface; safecall
begin
  Result := nil;
end;

exports
  InitProc,
  FakeInitProc;

begin
end.
