{ ************************************************************************** }
{                                                                            }
{ CenterTests                                                                }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

{
  The contract for the centre of the view. The engine holds an offset, the user
  is shown a centre, and the two are different numbers: they differ in sign.
  What is checked here is the contract, not the way it currently happens to be
  implemented.

  The contract: with a centre of C and half sides of MaxX and MaxY, the visible
  area runs from C - MaxX to C + MaxX across and from C - MaxY to C + MaxY down,
  and the point of the plane under the middle of the canvas is C.

  From that, Offset = -C: Prepare sets the range to [-MaxX - Offset .. MaxX -
  Offset], and the middle of that stretch is -Offset.

  A trap in the names: the engine's Center property is the middle of the CANVAS
  in pixels, not the centre of the view in the coordinates of the plane. The
  checks below use it only as the pixel middle.

  Built by either compiler: the calculating part needs nothing to draw with.
}

program CenterTests;

{$APPTYPE CONSOLE}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  {$IFDEF FPC}
  {$IFDEF UNIX}cthreads,{$ENDIF}
  {$IFNDEF NOFORMS}Interfaces,{$ENDIF} SysUtils, Math, Classes, Types,
  {$ELSE}
  System.SysUtils, System.Math, System.Classes, System.Types,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Geometry,
  CrossGraph.Engine;

const
  Tolerance = 1E-9;
  CanvasWide = 800;
  CanvasHigh = 500;

var
  Total: Integer = 0;
  Failed: Integer = 0;
  Report: TStringList;

procedure Emit(const Line: string);
begin
  Writeln(Line);
  Flush(Output);
  Report.Add(Line);
end;

procedure Section(const Title: string);
begin
  Emit('');
  Emit('--- ' + Title + ' ---');
end;

procedure Check(const Condition: Boolean; const Description: string);
begin
  Inc(Total);
  if Condition then
    Emit('ok    ' + Description)
  else begin
    Inc(Failed);
    Emit('FAIL  ' + Description);
  end;
end;

procedure CheckNear(const Got, Want: Extended; const Description: string);
begin
  Check(Abs(Got - Want) <= Tolerance, Format('%s: got %.10g, expected %.10g', [Description, Got, Want]));
end;

function Sized(const W, H: Integer): TSize;
begin
  Result.cx := W;
  Result.cy := H;
end;

function MakeEngine: TGraphEngine;
begin
  Result := TGraphEngine.Create(nil);
  Result.Size := Sized(CanvasWide, CanvasHigh);
end;

{
  One case of the contract from end to end: the centre is set through the
  offset, then everything the user can see is asked about.
}
procedure RoundTrip(const CX, CY, MaxX, MaxY: Extended; const Name: string);
var
  E: TGraphEngine;
  MidX, MidY: Extended;
begin
  Section(Name);
  E := MakeEngine;
  try
    E.MaxX := MaxX;
    E.MaxY := MaxY;
    E.Offset := PointD(-CX, -CY);
    E.Prepare;
    // The edges of the visible area.
    CheckNear(E.Min.X, CX - MaxX, 'left edge');
    CheckNear(E.Max.X, CX + MaxX, 'right edge');
    CheckNear(E.Min.Y, CY - MaxY, 'bottom edge');
    CheckNear(E.Max.Y, CY + MaxY, 'top edge');
    // The middle of the range is the centre that was asked for.
    CheckNear((E.Min.X + E.Max.X) / 2, CX, 'middle of the range across');
    CheckNear((E.Min.Y + E.Max.Y) / 2, CY, 'middle of the range down');
    // The point of the plane under the middle of the canvas.
    MidX := E.XToPoint(E.Center.X);
    MidY := E.YToPoint(E.Center.Y);
    CheckNear(MidX, CX, 'point under the middle of the canvas, across');
    CheckNear(MidY, CY, 'point under the middle of the canvas, down');
    // The other way round: the centre of the view lands in the middle.
    CheckNear(E.XToCursor(CX), E.Center.X, 'the centre is drawn in the middle across');
    CheckNear(E.YToCursor(CY), E.Center.Y, 'the centre is drawn in the middle down');
    // The edges of the canvas give the edges of the range.
    CheckNear(E.XToPoint(0), CX - MaxX, 'left edge of the canvas');
    CheckNear(E.XToPoint(CanvasWide), CX + MaxX, 'right edge of the canvas');
    CheckNear(E.YToPoint(CanvasHigh), CY - MaxY, 'bottom edge of the canvas');
    CheckNear(E.YToPoint(0), CY + MaxY, 'top edge of the canvas');
    // There and back loses nothing.
    CheckNear(E.XToPoint(E.XToCursor(CX + MaxX / 3)), CX + MaxX / 3, 'there and back across');
    CheckNear(E.YToPoint(E.YToCursor(CY - MaxY / 7)), CY - MaxY / 7, 'there and back down');
  finally
    E.Free;
  end;
end;

{
  Moving the centre moves the picture the same way the number moves. That is
  what the user sees: raise the centre across, and the view goes right.
}
procedure Direction;
var
  E: TGraphEngine;
  Was, Became: Extended;
begin
  Section('direction of the shift');
  E := MakeEngine;
  try
    E.MaxX := 10;
    E.MaxY := 10;
    E.Offset := PointD(0, 0);
    E.Prepare;
    Was := E.Max.X;
    E.Offset := PointD(-5, 0);
    E.Prepare;
    Became := E.Max.X;
    Check(Became > Was, 'the centre grew and the right edge went right');
    CheckNear(Became - Was, 5, 'the edge moved as far as the centre did');
    E.Offset := PointD(-5, -3);
    E.Prepare;
    CheckNear(E.XToPoint(E.Center.X), 5, 'the middle shows a centre across of 5');
    CheckNear(E.YToPoint(E.Center.Y), 3, 'the middle shows a centre down of 3');
  finally
    E.Free;
  end;
end;

{
  The size of the canvas does not enter the contract: the centre and the edges
  are given in the coordinates of the plane. Working it out through pixels once
  gave a different centre for a narrow panel and for a wide one.
}
procedure SizeIndependent;
var
  E: TGraphEngine;
  Sizes: array [0 .. 3] of TSize;
  I: Integer;
begin
  Section('the size of the canvas does not matter');
  Sizes[0] := Sized(100, 100);
  Sizes[1] := Sized(1920, 200);
  Sizes[2] := Sized(200, 1080);
  Sizes[3] := Sized(1, 1);
  for I := 0 to High(Sizes) do
  begin
    E := TGraphEngine.Create(nil);
    try
      E.Size := Sizes[I];
      E.MaxX := 8;
      E.MaxY := 6;
      E.Offset := PointD(-2.5, 1.25);
      E.Prepare;
      CheckNear((E.Min.X + E.Max.X) / 2, 2.5, Format('canvas %dx%d: centre across', [Sizes[I].cx, Sizes[I].cy]));
      CheckNear((E.Min.Y + E.Max.Y) / 2, -1.25, Format('canvas %dx%d: centre down', [Sizes[I].cx, Sizes[I].cy]));
    finally
      E.Free;
    end;
  end;
end;

{
  Polar coordinates keep the same contract: the centre of the view stays the
  centre of the view, only the way the curve is built changes.
}
procedure Polar;
var
  E: TGraphEngine;
begin
  Section('polar coordinates');
  E := MakeEngine;
  try
    E.CS := csPolar;
    E.MaxX := 12;
    E.MaxY := 9;
    E.Offset := PointD(-4, -2);
    E.Prepare;
    CheckNear((E.Min.X + E.Max.X) / 2, 4, 'centre across in polar');
    CheckNear((E.Min.Y + E.Max.Y) / 2, 2, 'centre down in polar');
    CheckNear(E.XToPoint(E.Center.X), 4, 'middle of the canvas in polar');
  finally
    E.Free;
  end;
end;

begin
  Report := TStringList.Create;
  try
    try
      RoundTrip(0, 0, 10, 10, 'centre at the origin');
      RoundTrip(5, 0, 10, 10, 'centre moved right');
      RoundTrip(-5, 0, 10, 10, 'centre moved left');
      RoundTrip(0, 7, 10, 10, 'centre moved up');
      RoundTrip(0, -7, 10, 10, 'centre moved down');
      RoundTrip(3.25, -1.75, 4, 2.5, 'fractional centre, uneven half sides');
      RoundTrip(1E6, -1E6, 1E5, 1E5, 'distant centre');
      RoundTrip(1E-6, 1E-6, 1E-5, 1E-5, 'small scale');
      Direction;
      SizeIndependent;
      Polar;
    except
      on E: Exception do
      begin
        Inc(Failed);
        Emit('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
      end;
    end;
    Emit('');
    Emit(Format('TOTAL: checks %d, failures %d', [Total, Failed]));
    try
      Report.SaveToFile(ChangeFileExt(ParamStr(0), '.log'){$IFNDEF FPC},
        TEncoding.UTF8{$ENDIF});
    except
      on E: Exception do Writeln('log not written: ' + E.Message);
    end;
  finally
    Report.Free;
  end;
  if Failed > 0 then Halt(1);
end.
