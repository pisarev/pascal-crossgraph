{ ************************************************************************** }
{                                                                            }
{ CrossGraph.Surface                                                         }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit CrossGraph.Surface;

{$B-}
{$I Directives.inc}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils, Classes, Math,
  {$ELSE}
  System.SysUtils, System.Classes, System.Math,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossGraph.Types, ParseJit.Parser, Parser, ParseTypes,
  ValueTypes, ValueUtils, Notifier;

type
  TSurface = record
    Columns, Rows: Integer;
    MinX, MaxX, MinY, MaxY: Double;
    Values: TArray<Double>;
    Defined: TArray<Boolean>;
    MinZ, MaxZ: Double;
    function Value(const Column, Row: Integer): Double;
    function Ready(const Column, Row: Integer): Boolean;
    function X(const Column: Integer): Double;
    function Y(const Row: Integer): Double;
  end;

  TSurfaceEngine = class
  private
    FParser: TJitParser;
    FValueX: TValue;
    FValueY: TValue;
    FError: string;
  public
    constructor Create;
    destructor Destroy; override;
    function Build(const Formula: string; const MinX, MaxX, MinY, MaxY: Double; const Columns, Rows: Integer;
      out Surface: TSurface): Boolean;
    function Isolines(const Surface: TSurface; const Level: Double): TCurveDArray;
    property Error: string read FError;
    property Parser: TJitParser read FParser;
  end;

implementation

const
  VariableX = 'X';
  VariableY = 'Y';

function TSurface.Value(const Column, Row: Integer): Double;
begin
  Result := Values[Row * Columns + Column];
end;

function TSurface.Ready(const Column, Row: Integer): Boolean;
begin
  Result := Defined[Row * Columns + Column];
end;

function TSurface.X(const Column: Integer): Double;
begin
  if Columns < 2 then Exit(MinX);
  Result := MinX + (MaxX - MinX) * Column / (Columns - 1);
end;

function TSurface.Y(const Row: Integer): Double;
begin
  if Rows < 2 then Exit(MinY);
  Result := MinY + (MaxY - MinY) * Row / (Rows - 1);
end;

constructor TSurfaceEngine.Create;
begin
  inherited Create;
  FParser := TJitParser.Create(nil);
  FParser.IgnoreType[icFunction] := True;
  FValueX.ValueType := vtExtended;
  FValueY.ValueType := vtExtended;
  FParser.BeginUpdate;
  try
    FParser.AddVariable(VariableX, FValueX, False);
    FParser.AddVariable(VariableY, FValueY, False);
  finally
    FParser.EndUpdate;
    FParser.Notify(ntCompile, nil);
  end;
end;

destructor TSurfaceEngine.Destroy;
begin
  FParser.Free;
  inherited;
end;

function TSurfaceEngine.Build(const Formula: string; const MinX, MaxX, MinY, MaxY: Double;
  const Columns, Rows: Integer; out Surface: TSurface): Boolean;
var
  Script: TScript;
  Column, Row, Index: Integer;
  Value: Double;
begin
  Result := False;
  FError := '';
  FillChar(Surface, SizeOf(Surface), 0);
  if (Columns < 2) or (Rows < 2) then
  begin
    FError := 'the grid has fewer than two nodes on a side';
    Exit;
  end;
  Script := nil;
  try
    FParser.StringToScript(Formula, Script);
  except
    on E: Exception do
    begin
      FError := E.Message;
      Exit;
    end;
  end;
  Surface.Columns := Columns;
  Surface.Rows := Rows;
  Surface.MinX := MinX;
  Surface.MaxX := MaxX;
  Surface.MinY := MinY;
  Surface.MaxY := MaxY;
  SetLength(Surface.Values, Columns * Rows);
  SetLength(Surface.Defined, Columns * Rows);
  Surface.MinZ := Infinity;
  Surface.MaxZ := NegInfinity;
  for Row := 0 to Rows - 1 do
    for Column := 0 to Columns - 1 do
    begin
      Index := Row * Columns + Column;
      FValueX.Float80 := Surface.X(Column);
      FValueY.Float80 := Surface.Y(Row);
      Value := 0;
      Surface.Defined[Index] := False;
      try
        Value := GetExtended(FParser.ExecuteScript(Script)^);
        Surface.Defined[Index] := not IsNan(Value) and not IsInfinite(Value);
      except
      end;
      Surface.Values[Index] := Value;
      if Surface.Defined[Index] then
      begin
        if Value < Surface.MinZ then Surface.MinZ := Value;
        if Value > Surface.MaxZ then Surface.MaxZ := Value;
      end;
    end;
  if Surface.MinZ > Surface.MaxZ then
  begin
    Surface.MinZ := 0;
    Surface.MaxZ := 0;
  end;
  Result := True;
end;

function TSurfaceEngine.Isolines(const Surface: TSurface; const Level: Double): TCurveDArray;
var
  Column, Row, Code, Count: Integer;
  Corner: array[0..3] of Double;
  Ready: Boolean;
  Points: array[0..3] of TPointD;

  function Cross(const AX, AY, AValue, BX, BY, BValue: Double): TPointD;
  var
    Part: Double;
  begin
    if Abs(BValue - AValue) < 1E-300 then
      Part := 0.5
    else
      Part := -AValue / (BValue - AValue);
    Part := EnsureRange(Part, 0, 1);
    Result := PointD(AX + (BX - AX) * Part, AY + (BY - AY) * Part);
  end;

begin
  Result := nil;
  if (Surface.Columns < 2) or (Surface.Rows < 2) then Exit;
  for Row := 0 to Surface.Rows - 2 do
    for Column := 0 to Surface.Columns - 2 do
    begin
      Ready := Surface.Ready(Column, Row) and Surface.Ready(Column + 1, Row) and
        Surface.Ready(Column + 1, Row + 1) and Surface.Ready(Column, Row + 1);
      if not Ready then Continue;
      Corner[0] := Surface.Value(Column, Row) - Level;
      Corner[1] := Surface.Value(Column + 1, Row) - Level;
      Corner[2] := Surface.Value(Column + 1, Row + 1) - Level;
      Corner[3] := Surface.Value(Column, Row + 1) - Level;
      Code := 0;
      if Corner[0] > 0 then Code := Code or 1;
      if Corner[1] > 0 then Code := Code or 2;
      if Corner[2] > 0 then Code := Code or 4;
      if Corner[3] > 0 then Code := Code or 8;
      if (Code = 0) or (Code = 15) then Continue;
      Count := 0;
      if (Corner[0] > 0) <> (Corner[1] > 0) then
      begin
        Points[Count] := Cross(Surface.X(Column), Surface.Y(Row), Corner[0], Surface.X(Column + 1),
          Surface.Y(Row), Corner[1]);
        Inc(Count);
      end;
      if (Corner[1] > 0) <> (Corner[2] > 0) then
      begin
        Points[Count] := Cross(Surface.X(Column + 1), Surface.Y(Row), Corner[1],
          Surface.X(Column + 1), Surface.Y(Row + 1), Corner[2]);
        Inc(Count);
      end;
      if (Corner[2] > 0) <> (Corner[3] > 0) then
      begin
        Points[Count] := Cross(Surface.X(Column + 1), Surface.Y(Row + 1), Corner[2],
          Surface.X(Column), Surface.Y(Row + 1), Corner[3]);
        Inc(Count);
      end;
      if (Corner[3] > 0) <> (Corner[0] > 0) then
      begin
        Points[Count] := Cross(Surface.X(Column), Surface.Y(Row + 1), Corner[3], Surface.X(Column),
          Surface.Y(Row), Corner[0]);
        Inc(Count);
      end;
      if Count >= 2 then
      begin
        SetLength(Result, Length(Result) + 1);
        SetLength(Result[High(Result)], 2);
        Result[High(Result), 0] := Points[0];
        Result[High(Result), 1] := Points[1];
      end;
      if Count = 4 then
      begin
        SetLength(Result, Length(Result) + 1);
        SetLength(Result[High(Result)], 2);
        Result[High(Result), 0] := Points[2];
        Result[High(Result), 1] := Points[3];
      end;
    end;
end;

end.
