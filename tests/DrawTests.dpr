{ ************************************************************************** }
{                                                                            }
{ DrawTests                                                                  }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }
program DrawTests;

{
  Drawing the curve itself. The old smoke test counted any pixel that differed
  from the background, and the grid, the axes and the labels give plenty of
  those - the curve might not be there at all and the test would not notice.

  Here the curve is painted in a colour that appears nowhere else, and pixels of
  exactly that colour are counted. Both drawing paths are checked separately:
  with smoothing (through GDI+) and without it.
}

{$APPTYPE CONSOLE}
{$I Directives.inc}

uses
  {$IFDEF FPC}
  Windows, Messages, SysUtils, Math, Graphics,
  {$ELSE}
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Math, Vcl.Graphics,
  {$ENDIF}
  // The order matters: the component has its own Check for array bounds, and
  // the one that counts checks is the one wanted here.
  CrossVision.Geometry.Types, CrossGraph, GraphTestKit;

const
  CurveColor = clRed;

var
  Host: TGraphHost;
  TracedPoint: TPointD;
  TracedCount: Integer = 0;

{
  Pixels noticeably redder than grey: the curve is painted red, and the grid,
  the axes and the labels never are. The comparison is by hue rather than by an
  exact value: smoothing blends the curve colour with the background, and on a
  slanted line the exact colour may not occur at all.
}
function ColorPixels(const Bitmap: TBitmap; const Color: TColor): Integer;
var
  X, Y, R, G, B: Integer;
  C: TColor;
begin
  Result := 0;
  if not Assigned(Bitmap) then Exit;
  for Y := 0 to Bitmap.Height - 1 do
    for X := 0 to Bitmap.Width - 1 do
    begin
      C := ColorToRGB(Bitmap.Canvas.Pixels[X, Y]);
      R := C and $FF;
      G := (C shr 8) and $FF;
      B := (C shr 16) and $FF;
      if (R - G > 40) and (R - B > 40) then Inc(Result);
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

{
  A pen width of zero is ordinary in saved settings: to GDI it means "the
  thinnest line". The curve has to be drawn in that case too.
}
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

{
  Tracing the curve: under the cursor the component has to give a point of the
  curve itself, not whatever was left in the variable from the previous
  computation. The test moves the cursor to several places and compares the
  answer with the formula.
}
type
  TTracer = class
    procedure Handle(Sender: TObject; const FormulaIndex: Integer; const Point: TPointD);
  end;

procedure TTracer.Handle(Sender: TObject; const FormulaIndex: Integer; const Point: TPointD);
begin
  TracedPoint := Point;
  Inc(TracedCount);
end;

{
  The colour of a formula. The computing part knows nothing about colours; the
  control hands them out from its palette, cycling when there are more formulas
  than colours. Without that a multicolour plot is drawn all in black.
}
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
  if (Host.Graph.Formula.Count < 2) or (Length(Host.Graph.ColorArray) < 2) then
    Exit;
  for I := 0 to 1 do
  begin
    Note(Format('formula %d: colour %.8x, in the palette %.8x', [I, Host.Graph.Formula.Data[I].Color, Host.Graph.ColorArray[I]]));
    Check(Host.Graph.Formula.Data[I].Color = Host.Graph.ColorArray[I], Format('formula %d got a palette colour', [I]));
  end;
  Check(Host.Graph.Formula.Data[0].Color <> Host.Graph.Formula.Data[1].Color, 'different formulas have different colours');
end;

procedure TestTrace;
const
  Places: array[0..3] of Double = (-3.0, -1.0, 1.0, 2.5);
var
  GraphCase: TGraphCase;
  Tracer: TTracer;
  I, X, Y: Integer;
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
      Note(Format('x = %.1f: got (%.3f; %.3f), expected (%.3f; %.3f)', [Places[I], TracedPoint.X, TracedPoint.Y, Places[I], Expected]));
      Check(Abs(TracedPoint.X - Places[I]) < 0.05, Format('x = %.1f: the argument', [Places[I]]));
      Check(Abs(TracedPoint.Y - Expected) < 0.05, Format('x = %.1f: the formula value', [Places[I]]));
    end;
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
