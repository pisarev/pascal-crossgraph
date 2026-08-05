{ ************************************************************************** }
{                                                                            }
{ EngineBench                                                                }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

{
  What machine code gives when sampling the points of a plot. The sampling
  itself is timed on a large canvas, where it dominates, and separately it is
  checked whether the accelerator takes a particular formula.
}

program EngineBench;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Math, System.Classes, ParseTypes, Parser,
  ParseJit.Parser, CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Engine;

const
  CanvasSide = 4000;
  Repeats = 40;

{ A precise timer: a few milliseconds is below the resolution of GetTickCount }
function Ticks: Int64;
begin
  QueryPerformanceCounter(Result);
end;

function Frequency: Int64;
begin
  QueryPerformanceFrequency(Result);
end;

var
  Report: TStringList;

procedure Emit(const Line: string);
begin
  Writeln(Line);
  Report.Add(Line);
end;

// Whether the accelerator takes the formula, and why not.
function JitVerdict(const Formula: string): string;
var
  Parser: TJitParser;
  Script: TScript;
  Value: Double;
  Code: TJitScript;
begin
  Parser := TJitParser.Create(nil);
  try
    Parser.AddVariable('X', Value);
    Parser.AddVariable('T', Value);
    Parser.StringToScript(Formula, Script);
    Code := Parser.CompileScript(Script);
    try
      if not Assigned(Code) then Exit('compilation did not happen');
      if Code.Ready then
        Exit('machine code')
      else
        Exit('the parser: ' + Code.Reason);
    finally
      Code.Free;
      Script := nil;
    end;
  finally
    Parser.Free;
  end;
end;

// The number of points over all curves - a measure of how much was sampled.
function PointTotal(const Curves: TCurveDArray): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Curves) to High(Curves) do Inc(Result, Length(Curves[I]));
end;

procedure Measure(const A, B: string; const Jit: Boolean; out Elapsed: Double;
  out Points, Compiled, Rejected: Integer);
var
  Engine: TGraphEngine;
  Start: Int64;
  I: Integer;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    Engine.CS := csRectangular;
    Engine.MaxX := 5;
    Engine.MaxY := 2;
    // Sampling only: the search for intersections and extrema is switched off.
    Engine.Overlap := False;
    Engine.Extreme := False;
    Engine.JitEnabled := Jit;
    Engine.Formula.Add(A, True, True, False);
    if B <> '' then Engine.Formula.Add(B, True, True, False);
    Engine.Prepare;
    ResetJitCounters;
    Start := Ticks;
    for I := 1 to Repeats do Engine.Parse;
    Elapsed := (Ticks - Start) * 1000 / Frequency;
    Points := PointTotal(Engine.EntireArray);
    Compiled := JitCompiledCount;
    Rejected := JitRejectedCount;
  finally
    Engine.Free;
  end;
end;

procedure Compare(const Name, A, B: string);
var
  PlainTime, JitTime: Double;
  PlainPoints, JitPoints, PlainCompiled, PlainRejected, JitCompiled, JitRejected: Integer;
begin
  Emit(Name);
  Emit('    the accelerator takes the formula: ' + JitVerdict(A));
  Measure(A, B, False, PlainTime, PlainPoints, PlainCompiled, PlainRejected);
  Measure(A, B, True, JitTime, JitPoints, JitCompiled, JitRejected);
  Emit(Format('    scripts in machine code: %d, declined: %d', [JitCompiled, JitRejected]));
  if JitRejected > 0 then Emit('    reason for declining: ' + JitLastReason);
  Emit(Format('    the parser:   %8.2f ms over %d runs, points %d', [PlainTime, Repeats, PlainPoints]));
  Emit(Format('    machine code: %8.2f ms over %d runs, points %d', [JitTime, Repeats, JitPoints]));
  if JitTime > 0 then
    Emit(Format('    %.2f times faster', [PlainTime / JitTime]))
  else
    Emit('    the gain cannot be measured: too fast');
  Emit(Format('    the same number of points: %s', [BoolToStr(PlainPoints = JitPoints, True)]));
end;

begin
  Report := TStringList.Create;
  try
    try
      Emit(Format('Canvas %dx%d, %d sampling runs each', [CanvasSide, CanvasSide, Repeats]));
      Emit('');
      Compare('plain arithmetic', 'X * X * 0.1', 'X * 0.3 + 0.5');
      Emit('');
      Compare('trigonometry', 'sin(X)', 'cos(X)');
      Emit('');
      Compare('a heavy formula', 'sin(X) * cos(X) + sin(X * 2) / 3', '');
    except
      on E: Exception do Emit('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
    end;
    try
      Report.SaveToFile(ChangeFileExt(ParamStr(0), '.log'), TEncoding.UTF8);
    except
      on E: Exception do Writeln('the log was not saved: ', E.Message);
    end;
  finally
    Report.Free;
  end;
end.
