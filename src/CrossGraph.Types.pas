{ ************************************************************************** }
{                                                                            }
{ CrossGraph.Types                                                           }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit CrossGraph.Types;

{$B-}
{$I Directives.inc}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils, Types,
  {$ELSE}
  System.SysUtils, System.Types,
  {$ENDIF}
  CrossVision.Geometry.Types;

type
  TPointD = CrossVision.Geometry.Types.TPointD;
  TPointI = CrossVision.Geometry.Types.TPointI;
  TPointDArray = CrossVision.Geometry.Types.TPointDArray;
  TPointIArray = CrossVision.Geometry.Types.TPointIArray;

  PPointD = ^TPointD;
  PPointI = ^TPointI;

  TCurveD = TPointDArray;
  TCurveDArray = TArray<TCurveD>;

  TCurveI = TPointIArray;
  TCurveIArray = TArray<TCurveI>;

  TGraphColor = Integer;
  TColorArray = TArray<TGraphColor>;

const
  MaxByte = High(Byte);

function PointI(const X, Y: Integer): TPointI; inline; overload;
function PointI(const Point: TPointD): TPointI; inline; overload;

function Check(const Target: TPointDArray; const Index: Integer): Boolean; overload;
function Check(const Target: TCurveDArray; const Index: Integer): Boolean; overload;
function Check(const Target: TCurveDArray; const ArrayIndex, Index: Integer): Boolean; overload;
function Check(const Target: TPointIArray; const Index: Integer): Boolean; overload;
function Check(const Target: TCurveIArray; const Index: Integer): Boolean; overload;
function Check(const Target: TCurveIArray; const ArrayIndex, Index: Integer): Boolean; overload;

function New(var Target: TCurveDArray): Integer; overload;
function New(var Target: TCurveIArray): Integer; overload;

function Add(var Target: TPointDArray; const Value: TPointD): Integer; overload;
function Add(var Target: TCurveDArray; const Value: TPointD; Index: Integer = -1): Integer; overload;
function Add(var Target: TCurveDArray; const Source: TPointDArray): Integer; overload;
procedure Add(var Target: TCurveDArray; const Source: TCurveDArray; const SourceIndex: Integer;
  TargetIndex: Integer = -1); overload;
function Add(var Target: TPointIArray; const Value: TPointI): Integer; overload;
function Add(var Target: TCurveIArray; const Value: TPointI; Index: Integer = -1): Integer; overload;
procedure Add(var Target: TCurveIArray; const Source: TCurveIArray; const SourceIndex: Integer;
  TargetIndex: Integer = -1); overload;

procedure Delete(var Target: TCurveDArray); overload;
procedure Delete(var Target: TCurveIArray); overload;

implementation

function PointI(const X, Y: Integer): TPointI;
begin
  Result.X := X;
  Result.Y := Y;
end;

function PointI(const Point: TPointD): TPointI;
begin
  Result.X := Round(Point.X);
  Result.Y := Round(Point.Y);
end;

function Check(const Target: TPointDArray; const Index: Integer): Boolean;
begin
  Result := (Index >= Low(Target)) and (Index <= High(Target));
end;

function Check(const Target: TCurveDArray; const Index: Integer): Boolean;
begin
  Result := (Index >= Low(Target)) and (Index <= High(Target));
end;

function Check(const Target: TCurveDArray; const ArrayIndex, Index: Integer): Boolean;
begin
  Result := Check(Target, ArrayIndex) and Check(Target[ArrayIndex], Index);
end;

function Check(const Target: TPointIArray; const Index: Integer): Boolean;
begin
  Result := (Index >= Low(Target)) and (Index <= High(Target));
end;

function Check(const Target: TCurveIArray; const Index: Integer): Boolean;
begin
  Result := (Index >= Low(Target)) and (Index <= High(Target));
end;

function Check(const Target: TCurveIArray; const ArrayIndex, Index: Integer): Boolean;
begin
  Result := Check(Target, ArrayIndex) and Check(Target[ArrayIndex], Index);
end;

function New(var Target: TCurveDArray): Integer;
begin
  Result := High(Target);
  if (Result < 0) or (Length(Target[Result]) > 0) then
  begin
    Inc(Result);
    SetLength(Target, Result + 1);
  end;
end;

function New(var Target: TCurveIArray): Integer;
begin
  Result := High(Target);
  if (Result < 0) or (Length(Target[Result]) > 0) then
  begin
    Inc(Result);
    SetLength(Target, Result + 1);
  end;
end;

function Add(var Target: TPointDArray; const Value: TPointD): Integer;
begin
  Result := Length(Target);
  SetLength(Target, Result + 1);
  Target[Result] := Value;
end;

function Add(var Target: TCurveDArray; const Value: TPointD; Index: Integer): Integer;
begin
  if Index < 0 then
  begin
    Index := High(Target);
    if Index < 0 then Index := 0;
  end;
  if Index > High(Target) then SetLength(Target, Index + 1);
  Result := Add(Target[Index], Value);
end;

function Add(var Target: TCurveDArray; const Source: TPointDArray): Integer;
var
  I: Integer;
begin
  I := Length(Source);
  if I = 0 then Exit(-1);
  Result := New(Target);
  SetLength(Target[Result], I);
  Move(Source[0], Target[Result, 0], I * SizeOf(TPointD));
end;

procedure Add(var Target: TCurveDArray; const Source: TCurveDArray; const SourceIndex: Integer;
  TargetIndex: Integer);
var
  I, J: Integer;
begin
  if (SourceIndex < Low(Source)) or (SourceIndex > High(Source)) then Exit;
  if not Assigned(Source[SourceIndex]) then Exit;
  if TargetIndex < 0 then
  begin
    TargetIndex := High(Target);
    if TargetIndex < 0 then TargetIndex := 0;
  end;
  if TargetIndex > High(Target) then SetLength(Target, TargetIndex + 1);
  I := Length(Target[TargetIndex]);
  J := Length(Source[SourceIndex]);
  SetLength(Target[TargetIndex], I + J);
  Move(Source[SourceIndex, 0], Target[TargetIndex, I], J * SizeOf(TPointD));
end;

function Add(var Target: TPointIArray; const Value: TPointI): Integer;
begin
  Result := Length(Target);
  SetLength(Target, Result + 1);
  Target[Result] := Value;
end;

function Add(var Target: TCurveIArray; const Value: TPointI; Index: Integer): Integer;
begin
  if Index < 0 then
  begin
    Index := High(Target);
    if Index < 0 then Index := 0;
  end;
  if Index > High(Target) then SetLength(Target, Index + 1);
  Result := Add(Target[Index], Value);
end;

procedure Add(var Target: TCurveIArray; const Source: TCurveIArray; const SourceIndex: Integer;
  TargetIndex: Integer);
var
  I, J: Integer;
begin
  if (SourceIndex < Low(Source)) or (SourceIndex > High(Source)) then Exit;
  if not Assigned(Source[SourceIndex]) then Exit;
  if TargetIndex < 0 then
  begin
    TargetIndex := High(Target);
    if TargetIndex < 0 then TargetIndex := 0;
  end;
  if TargetIndex > High(Target) then SetLength(Target, TargetIndex + 1);
  I := Length(Target[TargetIndex]);
  J := Length(Source[SourceIndex]);
  SetLength(Target[TargetIndex], I + J);
  Move(Source[SourceIndex, 0], Target[TargetIndex, I], J * SizeOf(TPointI));
end;

procedure Delete(var Target: TCurveDArray);
var
  I: Integer;
begin
  for I := Low(Target) to High(Target) do Target[I] := nil;
  Target := nil;
end;

procedure Delete(var Target: TCurveIArray);
var
  I: Integer;
begin
  for I := Low(Target) to High(Target) do Target[I] := nil;
  Target := nil;
end;

end.
