library TestDLL;

uses
  System.SysUtils,
  System.Classes,
  WinApi.Windows,
  intf_dll in '..\..\Common\intf_dll.pas',
  intf_common in '..\..\Common\intf_common.pas';

{$R *.res}

type
  TStubDLL = class(TInterfacedObject, IDLLIntf)
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
  end;

  TNoDLLIntf = class(TInterfacedObject, IInterface)
    function GetDescription: WideString; safecall;
  end;

  TPCDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun, IPartsCatalog)
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
  end;

  TLDDLL = class(TInterfacedObject, IDLLIntf, IDllIntfRun, ILogData)
    function GetDescription: WideString; safecall;
    procedure Init; safecall;
    procedure Fin; safecall;
    procedure Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd); safecall;
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

{ TNoDLLIntf }

function TNoDLLIntf.GetDescription: WideString;
begin
  Result := 'No DLLIntf Interface';
end;

{ TPCDLL }

procedure TPCDLL.Fin;
begin

end;

function TPCDLL.GetDescription: WideString;
begin
  Result := 'Interface Parts Catalog for DUnitX tests';
end;

procedure TPCDLL.Init;
begin

end;

procedure TPCDLL.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
begin

end;

{ TLDLL }

procedure TLDDLL.Fin;
begin

end;

function TLDDLL.GetDescription: WideString;
begin
  Result := 'Interface Log Data for DUnitX tests';
end;

procedure TLDDLL.Init;
begin

end;

procedure TLDDLL.Run(ACallbackProc: TProc<WideString>; MainAppHandle: HWnd);
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

function InitNoDllIntf: IInterface; safecall
begin
  Result := TNoDLLIntf.Create;
end;

function InitPCDLL: IInterface; safecall
begin
  Result := TPCDLL.Create;
end;

function InitLDDLL: IInterface; safecall
begin
  Result := TLDDLL.Create;
end;

exports
  InitProc,
  FakeInitProc,
  InitNoDllIntf,
  InitPCDLL,
  InitLDDLL;


begin
end.
