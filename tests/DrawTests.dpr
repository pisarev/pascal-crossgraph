{ ************************************************************************** }
{                                                                            }
{ DrawTests                                                                  }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

program DrawTests;

{$APPTYPE CONSOLE}
{$I Directives.inc}

uses
  {$IFDEF FPC}
  Windows, Messages, SysUtils, Math, Graphics,
  {$ELSE}
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Math, Vcl.Graphics,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossGraph, GraphTestKit;

const
  CurveColor = clRed;
  TraceColor = clLime;

var
  Host: TGraphHost;
  TracedPoint: TPointD;
  TracedCount: Integer = 0;

function ColorPixels(const Bitmap: TBitmap; const Color: TColor): Integer;
const
  Near = 40;
var
  X, Y, R, G, B, WantR, WantG, WantB: Integer;
  C, Want: TColor;
begin
  Result := 0;
  if not Assigned(Bitmap) then Exit;
  Want := ColorToRGB(Color);
  WantR := Want and $FF;
  WantG := (Want shr 8) and $FF;
  WantB := (Want shr 16) and $FF;
  for Y := 0 to Bitmap.Height - 1 do
    for X := 0 to Bitmap.Width - 1 do
    begin
      C := ColorToRGB(Bitmap.Canvas.Pixels[X, Y]);
      R := C and $FF;
      G := (C shr 8) and $FF;
      B := (C shr 16) and $FF;
      if (Abs(R - WantR) < Near) and (Abs(G - WantG) < Near) and (Abs(B - WantB) < Near) then
        Inc(Result);
    end;
end;

procedure One(const Name, Formula: string; const Antialias: Boolean; const MaxX, MaxY: Extended);
var
  GraphCase: TGraphCase;
  Painted: Integer;
begin
  GraphCase := MakeCase(Name, Formula, '', MaxX, MaxY);
  GraphCase.Antialias := Antialias;
  GraphCase.PenColor := CurveColor;
  Host.Run(GraphCase, wkNone);
  Painted := ColorPixels(Host.Graph.Buffer, CurveColor);
  Note(Format('%s: curve pixels %d', [Name, Painted]));
  Check(Painted > 0, Format('%s: the curve was drawn', [Name]));
end;

procedure TestCurveDrawn;
begin
  Section('Drawing the curve in the pen colour');
  One('sin with smoothing', 'sin(X)', True, 5, 2);
  One('sin without smoothing', 'sin(X)', False, 5, 2);
  One('a line with smoothing', 'X', True, 5, 5);
  One('a line without smoothing', 'X', False, 5, 5);
  One('a parabola with smoothing', 'X * X', True, 3, 9);
  One('a discontinuity with smoothing', '1 / X', True, 5, 5);
end;

procedure TestZeroPenWidth;
var
  GraphCase: TGraphCase;
  Painted: Integer;
begin
  Section('Drawing with a pen width of zero');
  GraphCase := MakeCase('a zero pen', 'sin(X)', '', 5, 2);
  GraphCase.PenColor := CurveColor;
  GraphCase.PenWidth := 0;
  Host.Run(GraphCase, wkNone);
  Painted := ColorPixels(Host.Graph.Buffer, CurveColor);
  Note(Format('curve pixels %d', [Painted]));
  Check(Painted > 0, 'the curve was drawn with a zero-width pen');
end;

type
  TTracer = class
    procedure Handle(Sender: TObject; const FormulaIndex: Integer; const Point: TPointD);
  end;

procedure TTracer.Handle(Sender: TObject; const FormulaIndex: Integer; const Point: TPointD);
begin
  TracedPoint := Point;
  Inc(TracedCount);
end;

procedure TestFormulaColor;
var
  GraphCase: TGraphCase;
  I: Integer;
begin
  Section('The formula colour from the palette');
  GraphCase := MakeCase('colours', 'sin(X)', 'cos(X)', 5, 2);
  Host.Run(GraphCase, wkNone);
  Host.Graph.MultiColor := True;
  Check(Length(Host.Graph.ColorArray) > 1, 'the palette is filled');
  Check(Host.Graph.Formula.Count = 2, 'there are two formulas');
  if (Host.Graph.Formula.Count < 2) or (Length(Host.Graph.ColorArray) < 2) then Exit;
  for I := 0 to 1 do
  begin
    Note(Format('formula %d: colour %.8x, in the palette %.8x',
      [I, Host.Graph.Formula.Data[I].Color, Host.Graph.ColorArray[I]]));
    Check(Host.Graph.Formula.Data[I].Color = Host.Graph.ColorArray[I],
      Format('formula %d got a palette colour', [I]));
  end;
  Check(Host.Graph.Formula.Data[0].Color <> Host.Graph.Formula.Data[1].Color,
    'different formulas have different colours');
end;

procedure TestTrace;
const
  Places: array[0..3] of Double = (-3.0, -1.0, 1.0, 2.5);
var
  GraphCase: TGraphCase;
  Tracer: TTracer;
  I, X, Y, Painted: Integer;
  Expected: Double;
begin
  Section('Tracing the curve under the cursor');
  GraphCase := MakeCase('tracing', 'sin(X)', '', 5, 2);
  GraphCase.PenColor := CurveColor;
  GraphCase.TraceFormula := True;
  Host.Run(GraphCase, wkNone);
  Tracer := TTracer.Create;
  try
    Host.Graph.Tracing := True;
    Host.Graph.OnRectangularTrace := Tracer.Handle;
    for I := Low(Places) to High(Places) do
    begin
      TracedCount := 0;
      X := Round(Host.Graph.XToCursor(Places[I]));
      Y := Host.Graph.Height div 2;
      Host.Graph.Perform(WM_MOUSEMOVE, 0, LPARAM(X or (Y shl 16)));
      Expected := Sin(Places[I]);
      Check(TracedCount > 0, Format('x = %.1f: tracing worked', [Places[I]]));
      if TracedCount = 0 then Continue;
      Note(Format('x = %.1f: got (%.3f; %.3f), expected (%.3f; %.3f)',
        [Places[I], TracedPoint.X, TracedPoint.Y, Places[I], Expected]));
      Check(Abs(TracedPoint.X - Places[I]) < 0.05, Format('x = %.1f: the argument', [Places[I]]));
      Check(Abs(TracedPoint.Y - Expected) < 0.05, Format('x = %.1f: the formula value', [Places[I]]));
    end;
    Host.Graph.TracePen.Color := TraceColor;
    Host.Graph.TracePen.Width := 3;
    X := Round(Host.Graph.XToCursor(Places[High(Places)]));
    Y := Host.Graph.Height div 2;
    Host.Graph.Perform(WM_MOUSEMOVE, 0, LPARAM(X or (Y shl 16)));
    Painted := ColorPixels(Host.Graph.Buffer, TraceColor);
    Note(Format('tracing pen pixels in the buffer: %d', [Painted]));
    Check(Painted > 0, 'the tracing goes into the buffer instead of over it');
  finally
    Host.Graph.OnRectangularTrace := nil;
    Tracer.Free;
  end;
end;

begin
  try
    Host := TGraphHost.Create;
    try
      TestCurveDrawn;
      TestZeroPenWidth;
      TestFormulaColor;
      TestTrace;
    finally
      Host.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('EXCEPTION: ', E.ClassName, ': ', E.Message);
      Check(False, 'the run raised no exceptions');
    end;
  end;
  Writeln;
  Writeln(Format('TOTAL: checks %d, failures %d', [TotalCount, FailedCount]));
  SaveReport(ChangeFileExt(ParamStr(0), '.log'));
  ExitCode := FailedCount;
end.
