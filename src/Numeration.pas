{ ************************************************************************** }
{                                                                            }
{ Numeration                                                                 }
{                                                                            }
{ Copyright © 2003-2004 Yuriy Pisarev (ypisareff@outlook.com)                }
{                                                                            }
{ ************************************************************************** }

unit Numeration;

{$B-}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils, Classes, TextConsts;
  {$ELSE}
  {$IFDEF DELPHI_XE7}
  System.SysUtils, System.Classes, TextConsts;
  {$ELSE}
  SysUtils, Classes, TextConsts;
  {$ENDIF}
  {$ENDIF}

type
  TCustomNumeration = class
  protected
    function GetCount: Integer; virtual; abstract;
    function GetNegative: Char; virtual; abstract;
    function GetNumeration(const Index: Integer): string; virtual; abstract;
    function GetPositive: Char; virtual; abstract;
    procedure SetNegative(const Value: Char); virtual; abstract;
    procedure SetNumeration(const Index: Integer; const Value: string); virtual; abstract;
    procedure SetPositive(const Value: Char); virtual; abstract;
  public
    function Add(const Value: string): Integer; virtual; abstract;
    procedure Delete(const Index: Integer); virtual; abstract;
    function Check(const Value: string): Boolean; virtual; abstract;
    procedure Clear; virtual; abstract;
    function ConvertFrom(Value: string; const Index: Integer): Int64; virtual; abstract;
    function ConvertTo(Value: Int64; const Index: Integer): string; virtual; abstract;
    property Count: Integer read GetCount;
    property Negative: Char read GetNegative write SetNegative;
    property Positive: Char read GetPositive write SetPositive;
    property Numeration[const Index: Integer]: string read GetNumeration write SetNumeration; default;
  end;

  ENumerationError = class(Exception);

  TNumeration = class(TCustomNumeration)
  private
    FList: TStrings;
    FNegative: Char;
    FPositive: Char;
  protected
    function GetCount: Integer; override;
    function GetNegative: Char; override;
    function GetNumeration(const Index: Integer): string; override;
    function GetPositive: Char; override;
    procedure SetNegative(const Value: Char); override;
    procedure SetNumeration(const Index: Integer; const Value: string); override;
    procedure SetPositive(const Value: Char); override;
    function Error(const Message: string): Exception; overload; virtual;
    function Error(const Message: string; const Arguments: array of const): Exception; overload; virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    function Add(const Value: string): Integer; override;
    procedure Delete(const Index: Integer); override;
    function Check(const Value: string): Boolean; override;
    procedure Clear; override;
    function ConvertFrom(Value: string; const Index: Integer): Int64; override;
    function ConvertTo(Value: Int64; const Index: Integer): string; override;
  end;

const
  ValueError = '"%s" is not valid value';

implementation

uses
  {$IFDEF FPC}
  Math, TextUtils;
  {$ELSE}
  {$IFDEF DELPHI_XE7}
  System.Math, TextUtils;
  {$ELSE}
  Math, TextUtils;
  {$ENDIF}
  {$ENDIF}

{ TNumeration }

function TNumeration.Add(const Value: string): Integer;
begin
  if Check(Value) then
    Result := FList.Add(Value)
  else
    Result := -1;
end;

function TNumeration.Check(const Value: string): Boolean;
var
  I: Integer;
begin
  Result := (Length(Value) > 1) and not Contains(Value, FNegative) and
    not Contains(Value, FPositive);
  if Result then
    for I := 1 to Length(Value) do
      if Duplicated(Value, I) then
      begin
        Result := False;
        Break;
      end;
end;

procedure TNumeration.Clear;
begin
  inherited;
  FList.Clear;
end;

function TNumeration.ConvertFrom(Value: string; const Index: Integer): Int64;
var
  Flag: Boolean;
  S: string;
  I, J, K, L: Integer;
begin
  if Value = '' then raise Error(ValueError, [Value]);
  Result := 0;
  Flag := DeletePrefix(Value, FNegative);
  S := FList[Index];
  J := Length(Value);
  L := Length(S);
  for I := 1 to J do
  begin
    K := Pos(Value[I], S);
    if K = 0 then
      raise Error(ValueError, [Value])
    else
      Result := Result + (K - 1) * Trunc(Power(L, J - I));
  end;
  if Flag then
    Result := -Result;
end;

function TNumeration.ConvertTo(Value: Int64; const Index: Integer): string;
var
  Flag: Boolean;
  S: string;
  I: Int64;
  J: Integer;
begin
  Result := '';
  Flag := Value < 0;
  if Flag then Value := -Value;
  S := FList[Index];
  J := Length(S);
  repeat
    I := Value;
    Value := Value div J;
    I := I - Value * J;
    Result :=  S[I + 1] + Result;
  until Value = 0;
  if Flag then
    Result := FNegative + Result;
end;

constructor TNumeration.Create;
begin
  inherited;
  FList := TStringList.Create;
  FNegative := TextConsts.Negative;
  FPositive := TextConsts.Positive;
end;

procedure TNumeration.Delete(const Index: Integer);
begin
  inherited;
  FList.Delete(Index);
end;

destructor TNumeration.Destroy;
begin
  FList.Free;
  inherited;
end;

function TNumeration.Error(const Message: string): Exception;
begin
  Result := Error(Message, []);
end;

function TNumeration.Error(const Message: string; const Arguments: array of const): Exception;
begin
  Result := ENumerationError.CreateFmt(Message, Arguments);
end;

function TNumeration.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TNumeration.GetNegative: Char;
begin
  Result := FNegative;
end;

function TNumeration.GetNumeration(const Index: Integer): string;
begin
  Result := FList[Index];
end;

function TNumeration.GetPositive: Char;
begin
  Result := FPositive;
end;

procedure TNumeration.SetNegative(const Value: Char);
begin
  FNegative := Value;
end;

procedure TNumeration.SetNumeration(const Index: Integer; const Value: string);
begin
  FList[Index] := Value;
end;

procedure TNumeration.SetPositive(const Value: Char);
begin
  FPositive := Value;
end;

end.
