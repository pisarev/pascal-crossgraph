{ ************************************************************************** }
{                                                                            }
{ GraphTestKit                                                               }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

{
  The harness for the plotting component tests: a hidden host form, waiting for
  readiness and a check counter. The curves are ready right after Build, while
  intersections and extrema arrive as events, so they have to be waited for by
  subscription rather than by polling a busy flag.
}

unit GraphTestKit;

{$I Directives.inc}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  Windows, SysUtils, Classes, Forms, Controls, Graphics,
  {$ELSE}
  Winapi.Windows, System.SysUtils, System.Classes, Vcl.Forms, Vcl.Controls, Vcl.Graphics,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Engine, CrossGraph;

type
  TWaitKind = (wkNone, wkOverlap, wkExtreme);

  TGraphCase = record
    Name: string;
    AFormula, BFormula: string;
    Polar: Boolean;
    MaxX, MaxY: Extended;
    HighPrecision: Boolean;
    MaxDepth: Integer;
    Overlap, Extreme: Boolean;
    ThreadCount: Integer;
    // The curve pen and smoothing: the drawing test needs them to tell a curve
    // from the grid and the axes, and to take both drawing paths.
    Antialias: Boolean;
    PenColor: TColor;
    PenWidth: Integer;
    // Tracing is switched on per formula.
    TraceFormula: Boolean;
  end;

  TGraphHost = class
  private
    FForm: TForm;
    FGraph: TGraph;
    FOverlapReady: Boolean;
    FExtremeReady: Boolean;
    FTimedOut: Boolean;
    procedure HandleOverlap(Sender: TObject);
    procedure HandleExtreme(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Run(const GraphCase: TGraphCase; const Wait: TWaitKind);
    property Graph: TGraph read FGraph;
    property TimedOut: Boolean read FTimedOut;
  end;

function MakeCase(const AName, AFormula, BFormula: string; const AMaxX, AMaxY: Extended): TGraphCase;
procedure Check(const Condition: Boolean; const Description: string);
procedure Note(const Description: string);
procedure Section(const Description: string);
function TotalCount: Integer;
function FailedCount: Integer;
{
  The run log in UTF-8. The console writes in the OEM code page and mangles
  non-ASCII text when redirected, so the result is read from this file.
}
procedure SaveReport(const FileName: string);

// The shortest distance from a point to a set; infinity for an empty set.
function NearestDistance(const Points: TPointDArray; const X, Y: Double): Double;
// Every point of an array of curves as one list.
function FlattenCurves(const Curves: TCurveDArray): TPointDArray;
function OverlapPoints(const Graph: TGraph): TPointDArray;

implementation

uses
  {$IFDEF FPC}Math{$ELSE}System.Math{$ENDIF};

const
  HostSize = 640;
  GraphSize = 600;
  WaitLimit = 20000;
  PollStep = 5;
  MaxTimeLimit = 2000;

var
  Total: Integer = 0;
  Failed: Integer = 0;
  Report: TStringList = nil;

procedure Emit(const Line: string);
begin
  Writeln(Line);
  if not Assigned(Report) then Report := TStringList.Create;
  Report.Add(Line);
end;

procedure SaveReport(const FileName: string);
begin
  if not Assigned(Report) then Exit;
  try
    Report.SaveToFile(FileName, TEncoding.UTF8);
  except
    on E: Exception do Writeln('the log was not saved: ', E.Message);
  end;
end;

function MakeCase(const AName, AFormula, BFormula: string; const AMaxX, AMaxY: Extended): TGraphCase;
begin
  FillChar(Result, SizeOf(TGraphCase), 0);
  Result.Name := AName;
  Result.AFormula := AFormula;
  Result.BFormula := BFormula;
  Result.MaxX := AMaxX;
  Result.MaxY := AMaxY;
  Result.MaxDepth := 100;
  Result.Overlap := True;
  Result.ThreadCount := 0;
  Result.Antialias := True;
  Result.PenColor := clNone;
  Result.PenWidth := 1;
  Result.TraceFormula := False;
end;

procedure Check(const Condition: Boolean; const Description: string);
begin
  Inc(Total);
  if Condition then
    Emit('  ok   ' + Description)
  else begin
    Inc(Failed);
    Emit('  FAIL ' + Description);
  end;
end;

procedure Note(const Description: string);
begin
  Emit('       ' + Description);
end;

procedure Section(const Description: string);
begin
  Emit('');
  Emit(Description);
end;

function TotalCount: Integer;
begin
  Result := Total;
end;

function FailedCount: Integer;
begin
  Result := Failed;
end;

function NearestDistance(const Points: TPointDArray; const X, Y: Double): Double;
var
  I: Integer;
  D: Double;
begin
  Result := Infinity;
  for I := Low(Points) to High(Points) do
  begin
    D := Sqrt(Sqr(Points[I].X - X) + Sqr(Points[I].Y - Y));
    if D < Result then Result := D;
  end;
end;

function FlattenCurves(const Curves: TCurveDArray): TPointDArray;
var
  I, J, K: Integer;
begin
  K := 0;
  for I := Low(Curves) to High(Curves) do Inc(K, Length(Curves[I]));
  SetLength(Result, K);
  K := 0;
  for I := Low(Curves) to High(Curves) do
    for J := Low(Curves[I]) to High(Curves[I]) do
    begin
      Result[K] := Curves[I, J];
      Inc(K);
    end;
end;

function OverlapPoints(const Graph: TGraph): TPointDArray;
var
  I: Integer;
begin
  SetLength(Result, Length(Graph.OverlapArray));
  for I := Low(Result) to High(Result) do
    Result[I] := Graph.OverlapArray[I].Point;
end;

constructor TGraphHost.Create;
begin
  inherited Create;
  FForm := TForm.Create(nil);
  FForm.SetBounds(0, 0, HostSize, HostSize);
end;

destructor TGraphHost.Destroy;
begin
  FGraph.Free;
  FForm.Free;
  inherited;
end;

procedure TGraphHost.HandleOverlap(Sender: TObject);
begin
  FOverlapReady := True;
end;

procedure TGraphHost.HandleExtreme(Sender: TObject);
begin
  FExtremeReady := True;
end;

procedure TGraphHost.Run(const GraphCase: TGraphCase; const Wait: TWaitKind);

  function Ready(const Kind: TWaitKind; const AOverlap, AExtreme, ABusy: Boolean): Boolean;
  begin
    case Kind of
      wkOverlap: Result := AOverlap and not ABusy;
      wkExtreme: Result := AExtreme and not ABusy;
    else
      Result := not ABusy;
    end;
  end;

var
  Start: Cardinal;
begin
  FreeAndNil(FGraph);
  FOverlapReady := False;
  FExtremeReady := False;
  FTimedOut := False;
  FGraph := TGraph.Create(FForm);
  FGraph.OnOverlap := HandleOverlap;
  FGraph.OnExtreme := HandleExtreme;
  FGraph.Parent := FForm;
  FGraph.SetBounds(0, 0, GraphSize, GraphSize);
  if GraphCase.Polar then
    FGraph.CS := csPolar
  else
    FGraph.CS := csRectangular;
  FGraph.MaxX := GraphCase.MaxX;
  FGraph.MaxY := GraphCase.MaxY;
  FGraph.Overlap := GraphCase.Overlap;
  FGraph.Extreme := GraphCase.Extreme;
  FGraph.Tracing := False;
  FGraph.Antialias := GraphCase.Antialias;
  if GraphCase.PenColor <> clNone then
  begin
    FGraph.MultiColor := False;
    FGraph.GraphPen.Color := GraphCase.PenColor;
    FGraph.GraphPen.Width := GraphCase.PenWidth;
  end;
  FGraph.HighPrecision := GraphCase.HighPrecision;
  FGraph.OverlapMaxDepth := GraphCase.MaxDepth;
  FGraph.OverlapMaxTime := MaxTimeLimit;
  if GraphCase.ThreadCount > 0 then FGraph.ThreadCount := GraphCase.ThreadCount;
  if GraphCase.AFormula <> '' then
    FGraph.Formula.Add(GraphCase.AFormula, True, True, GraphCase.TraceFormula);
  if GraphCase.BFormula <> '' then
    FGraph.Formula.Add(GraphCase.BFormula, True, True, GraphCase.TraceFormula);
  FGraph.Build;
  Start := GetTickCount;
  while not Ready(Wait, FOverlapReady, FExtremeReady, FGraph.Busy) do
  begin
    Application.ProcessMessages;
    Sleep(PollStep);
    if GetTickCount - Start > WaitLimit then
    begin
      FTimedOut := True;
      FGraph.Abort;
      Break;
    end;
  end;
end;

end.
