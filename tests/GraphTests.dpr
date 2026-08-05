{ ************************************************************************** }
{                                                                            }
{ GraphTests                                                                 }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

{
  The regression of the plotting component. Intersections and extrema are
  compared against the analytic answer, discontinuities against the number of
  continuous pieces, and navigation over a slice against a direct enumeration of
  the points.
}

program GraphTests;

{$APPTYPE CONSOLE}

uses
  Winapi.Windows, System.SysUtils, System.Math, System.Classes, Vcl.Forms, Vcl.Graphics,
  CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Engine, CrossGraph,
  GraphTestKit in 'GraphTestKit.pas';

const
  Tolerance = 1E-4;
  {
    Extrema are taken from points already sampled on the curve and have no
    refinement pass, unlike intersections. Their precision is bounded by the
    sampling step, which is tied to a screen distance of two pixels.
  }
  ExtremeTolerance = 0.05;
  RootPi4 = Pi / 4;
  RootPi3 = Pi / 3;
  DepthLow = 1;
  DepthMid = 10;
  DepthHigh = 100;

type
  TRoot = record
    X, Y: Double;
  end;
  TRootArray = array of TRoot;

function Root(const X, Y: Double): TRoot;
begin
  Result.X := X;
  Result.Y := Y;
end;

// The maximum over the roots of the distance to the nearest point found.
function MaxError(const Points: TPointDArray; const Roots: TRootArray): Double;
var
  I: Integer;
  D: Double;
begin
  Result := 0;
  for I := Low(Roots) to High(Roots) do
  begin
    D := NearestDistance(Points, Roots[I].X, Roots[I].Y);
    if D > Result then Result := D;
  end;
end;

{
  The number of pixels that differ from the background: a smoke signal that
  drawing happened at all. The corner pixel is taken as the background - there
  are certainly no axes and no curves there.
}
function DrawnPixels(const Bitmap: TBitmap): Integer;
var
  X, Y: Integer;
  Background: TColor;
begin
  Result := 0;
  if (Bitmap.Width = 0) or (Bitmap.Height = 0) then Exit(0);
  Background := Bitmap.Canvas.Pixels[0, 0];
  for Y := 0 to Bitmap.Height - 1 do
    for X := 0 to Bitmap.Width - 1 do
      if Bitmap.Canvas.Pixels[X, Y] <> Background then Inc(Result);
end;

var
  Host: TGraphHost;

procedure TestOverlapAccuracy;

  procedure One(const Name, A, B: string; const Polar: Boolean; const MaxX, MaxY: Extended;
    const Roots: TRootArray);
  var
    GraphCase: TGraphCase;
    Rough, Fine: Double;
    RoughCount, FineCount: Integer;
  begin
    GraphCase := MakeCase(Name, A, B, MaxX, MaxY);
    GraphCase.Polar := Polar;
    GraphCase.MaxDepth := DepthHigh;
    Host.Run(GraphCase, wkOverlap);
    Rough := MaxError(OverlapPoints(Host.Graph), Roots);
    RoughCount := Length(Host.Graph.OverlapArray);
    GraphCase.HighPrecision := True;
    Host.Run(GraphCase, wkOverlap);
    Fine := MaxError(OverlapPoints(Host.Graph), Roots);
    FineCount := Length(Host.Graph.OverlapArray);
    Note(Format('%s: ordinary %.8f (%d points), high precision %.8f (%d points)', [Name, Rough, RoughCount, Fine, FineCount]));
    Check(FineCount >= Length(Roots), Name + ': every expected intersection was found');
    Check(Fine <= Tolerance, Name + ': high precision stays within tolerance');
  end;

begin
  Section('Intersections: against the analytic answer');
  One(
    'sin and cos',
    'sin(X)',
    'cos(X)',
    False,
    5,
    2,
    [
      Root(
        RootPi4,
        Sin(RootPi4)
      ),
      Root(
        RootPi4 + Pi,
        Sin(RootPi4 + Pi)
      ),
      Root(
        RootPi4 - Pi,
        Sin(RootPi4 - Pi)
      )
    ]
  );
  One('a parabola and a line', 'X * X', 'X + 2', False, 4, 6, [Root(-1, 1), Root(2, 4)]);
  One('a line and its mirror', 'X', '0 - X', False, 4, 4, [Root(0, 0)]);
  One('a cubic and a line', 'X * X * X', 'X', False, 3, 3, [Root(-1, -1), Root(0, 0), Root(1, 1)]);
  One('polar circles', '1', '2 * cos(T)', True, 3, 3, [Root(Cos(RootPi3), Sin(RootPi3)), Root(Cos(RootPi3), -Sin(RootPi3))]);
end;

procedure TestOverlapConvergence;

  procedure One(const Name, A, B: string; const Polar: Boolean; const MaxX, MaxY: Extended;
    const Roots: TRootArray);
  var
    GraphCase: TGraphCase;
    Errors: array[0..2] of Double;
    Depths: array[0..2] of Integer;
    I: Integer;
  begin
    Depths[0] := DepthLow;
    Depths[1] := DepthMid;
    Depths[2] := DepthHigh;
    GraphCase := MakeCase(Name, A, B, MaxX, MaxY);
    GraphCase.Polar := Polar;
    GraphCase.HighPrecision := True;
    for I := Low(Depths) to High(Depths) do
    begin
      GraphCase.MaxDepth := Depths[I];
      Host.Run(GraphCase, wkOverlap);
      Errors[I] := MaxError(OverlapPoints(Host.Graph), Roots);
      Note(Format('%s: depth %3d, error %.10f, points %d', [Name, Depths[I], Errors[I], Length(Host.Graph.OverlapArray)]));
    end;
    Check(
      (Errors[1] <= Errors[0] + Max(1E-9, Errors[0] * 0.01)) and (Errors[2] <= Errors[1] + Max(1E-9, Errors[1] * 0.01)),
      Name + ': the error falls as the depth grows'
    );
  end;

begin
  Section('Intersections: convergence with refinement depth');
  One(
    'sin and cos',
    'sin(X)',
    'cos(X)',
    False,
    5,
    2,
    [
      Root(
        RootPi4,
        Sin(RootPi4)
      ),
      Root(
        RootPi4 + Pi,
        Sin(RootPi4 + Pi)
      ),
      Root(
        RootPi4 - Pi,
        Sin(RootPi4 - Pi)
      )
    ]
  );
  One('a parabola and a line', 'X * X', 'X + 2', False, 4, 6, [Root(-1, 1), Root(2, 4)]);
  One('a cubic and a line', 'X * X * X', 'X', False, 3, 3, [Root(-1, -1), Root(0, 0), Root(1, 1)]);
  One('polar circles', '1', '2 * cos(T)', True, 3, 3, [Root(Cos(RootPi3), Sin(RootPi3)), Root(Cos(RootPi3), -Sin(RootPi3))]);
end;

procedure TestExtremes;

  procedure One(const Name, Formula: string; const MaxX, MaxY: Extended; const Maxima, Minima: TRootArray);
  var
    GraphCase: TGraphCase;
    MaxPoints, MinPoints: TPointDArray;
    EMax, EMin: Double;
  begin
    GraphCase := MakeCase(Name, Formula, '', MaxX, MaxY);
    GraphCase.Overlap := False;
    GraphCase.Extreme := True;
    Host.Run(GraphCase, wkExtreme);
    MaxPoints := FlattenCurves(Host.Graph.MaxArray);
    MinPoints := FlattenCurves(Host.Graph.MinArray);
    EMax := MaxError(MaxPoints, Maxima);
    EMin := MaxError(MinPoints, Minima);
    Note(Format('%s: maxima %d (error %.6f), minima %d (error %.6f)', [Name, Length(MaxPoints), EMax, Length(MinPoints), EMin]));
    Check(not Host.TimedOut, Name + ': the extrema were computed without a timeout');
    Check(EMax <= ExtremeTolerance, Name + ': the maxima match the analytic ones');
    Check(EMin <= ExtremeTolerance, Name + ': the minima match the analytic ones');
  end;

begin
  Section('Extrema: against the analytic answer');
  One('a sine', 'sin(X)', 5, 2, [Root(Pi / 2, 1)], [Root(0 - Pi / 2, -1)]);
  // The bounds are chosen so that both turning points lie inside the view.
  One('a shifted cubic', 'X * X * X - 3 * X', 1.5, 3, [Root(-1, 2)], [Root(1, -2)]);
end;

procedure TestDiscontinuity;

  function CurveCount(const Index: Integer): Integer;
  var
    Data: PFormulaData;
  begin
    Data := Host.Graph.Formula.Data[Index];
    if not Assigned(Data) then Exit(0);
    Result := Data.EntireFace.ArrayIndex - Data.EntireBack.ArrayIndex + 1;
  end;

  procedure One(const Name, Formula: string; const MaxX, MaxY: Extended; const Least: Integer);
  var
    GraphCase: TGraphCase;
    Count: Integer;
  begin
    GraphCase := MakeCase(Name, Formula, '', MaxX, MaxY);
    GraphCase.Overlap := False;
    Host.Run(GraphCase, wkNone);
    Count := CurveCount(0);
    Note(Format('%s: continuous pieces %d, expected at least %d', [Name, Count, Least]));
    Check(Count >= Least, Name + ': the discontinuities split the curve');
  end;

begin
  Section('Discontinuities: a function falls into several curves');
  One('a hyperbola', '1 / X', 4, 4, 2);
  One('a tangent', 'tan(X)', 5, 4, 4);
end;

procedure TestTouchAndMiss;
var
  GraphCase: TGraphCase;
  Points: TPointDArray;
begin
  Section('Touching, and no intersection at all');
  GraphCase := MakeCase('touching at zero', 'X * X', '0 - X * X', 3, 3);
  GraphCase.HighPrecision := True;
  Host.Run(GraphCase, wkOverlap);
  Points := OverlapPoints(Host.Graph);
  Note(Format('touching: points %d, error %.8f', [Length(Points), NearestDistance(Points, 0, 0)]));
  Check(Length(Points) > 0, 'touching at zero: the point was found');
  Check(NearestDistance(Points, 0, 0) <= Tolerance, 'touching at zero: the coordinates are right');
  GraphCase := MakeCase('no intersections', 'X * X + 1', 'X', 3, 4);
  GraphCase.HighPrecision := True;
  Host.Run(GraphCase, wkOverlap);
  Points := OverlapPoints(Host.Graph);
  Note(Format('no intersections: points %d, expected 0', [Length(Points)]));
  Check(Length(Points) = 0, 'curves that do not meet: no false points');
end;

procedure TestSameCurve;
var
  GraphCase: TGraphCase;
begin
  Section('A degenerate case: two identical curves');
  GraphCase := MakeCase('identical', 'sin(X)', 'sin(X)', 4, 2);
  GraphCase.HighPrecision := True;
  Host.Run(GraphCase, wkOverlap);
  Note(Format('identical curves: points %d', [Length(Host.Graph.OverlapArray)]));
  Check(not Host.TimedOut, 'identical curves: the computation finished, nothing hung');
end;

{
  Meeting at the pole: two circles through the origin at different angles.
  sin(T) drives the radius to zero at T = 0 and T = Pi, cos(T)/2 at T = Pi/2 and
  3*Pi/2. The ordinary segment-intersection search missed this meeting.
}
procedure TestPoleOverlap;
var
  GraphCase: TGraphCase;
  Points: TPointDArray;
  I: Integer;
  Pole: Boolean;
begin
  Section('The pole: meeting at the origin');
  GraphCase := MakeCase('circles through the pole', 'sin(T)', 'cos(T) / 2', 3, 3);
  GraphCase.Polar := True;
  Host.Run(GraphCase, wkOverlap);
  Points := OverlapPoints(Host.Graph);
  Pole := False;
  for I := Low(Points) to High(Points) do
    if (Abs(Points[I].X) < 0.01) and (Abs(Points[I].Y) < 0.01) then
      Pole := True;
  Note(Format('intersections found: %d', [Length(Points)]));
  Check(Pole, 'the intersection at the pole was found');
  Check(Length(Points) >= 2, 'both intersections were found: the pole and the one outside it');
end;

procedure TestRootOnBorder;
var
  GraphCase: TGraphCase;
  Points: TPointDArray;
begin
  Section('A root on the edge of the view');
  GraphCase := MakeCase('a root at MaxX', 'X', '2', 2, 4);
  GraphCase.HighPrecision := True;
  Host.Run(GraphCase, wkOverlap);
  Points := OverlapPoints(Host.Graph);
  Note(Format('a root on the edge: points %d, distance to (2, 2) is %.8f', [Length(Points), NearestDistance(Points, 2, 2)]));
  Check(NearestDistance(Points, 2, 2) <= Tolerance, 'the root on the edge of the view was found');
end;

procedure TestPainting;
var
  GraphCase: TGraphCase;
  Painted: Integer;
begin
  Section('Drawing: a smoke check of the buffer');
  GraphCase := MakeCase('drawing', 'sin(X)', 'cos(X)', 5, 2);
  Host.Run(GraphCase, wkOverlap);
  Check(Assigned(Host.Graph.Buffer), 'the buffer was created');
  if not Assigned(Host.Graph.Buffer) then Exit;
  Check((Host.Graph.Buffer.Width > 0) and (Host.Graph.Buffer.Height > 0), 'the buffer has a size');
  Painted := DrawnPixels(Host.Graph.Buffer);
  Note(Format('pixels differing from the background: %d of %d', [Painted, Host.Graph.Buffer.Width * Host.Graph.Buffer.Height]));
  Check(Painted > 0, 'something is drawn on the buffer');
  // If the background is misidentified the whole buffer differs, and that is not drawing.
  Check(Painted < Host.Graph.Buffer.Width * Host.Graph.Buffer.Height,
    'the buffer background was identified, the whole canvas is not painted');
end;

{
  The pixel array has to mirror the computed one curve for curve: the formula
  slices are given by curve numbers, and a mismatch would send the drawing to
  the wrong place. A discontinuity that falls on the seam between threads is
  checked separately: there the curve is split not by the thread itself but by
  the break flag of the previous one.
}
procedure TestCurveStructure;

  procedure One(const Name, Formula: string; const MaxX, MaxY: Extended; const Threads, Least: Integer);
  var
    GraphCase: TGraphCase;
    Data: PFormulaData;
    Count: Integer;
  begin
    GraphCase := MakeCase(Name, Formula, '', MaxX, MaxY);
    GraphCase.Overlap := False;
    GraphCase.ThreadCount := Threads;
    Host.Run(GraphCase, wkNone);
    Check(
      Length(Host.Graph.CursorArray) = Length(Host.Graph.EntireArray),
      Name + Format(': the same number of curves (computed %d, pixel %d)', [Length(Host.Graph.EntireArray), Length(Host.Graph.CursorArray)])
    );
    Data := Host.Graph.Formula.Data[0];
    if not Assigned(Data) then
    begin
      Check(False, Name + ': the formula data was obtained');
      Exit;
    end;
    Check(
      (Data.CursorFace.ArrayIndex >= Low(Host.Graph.CursorArray)) and (Data.CursorFace.ArrayIndex <= High(Host.Graph.CursorArray)),
      Name + ': the slice of pixel curves is inside the array'
    );
    Count := Data.EntireFace.ArrayIndex - Data.EntireBack.ArrayIndex + 1;
    Note(Format('%s: threads %d, pieces %d', [Name, Threads, Count]));
    Check(Count >= Least, Name + Format(': the discontinuity split the curve (pieces %d)', [Count]));
  end;

begin
  Section('How the curve arrays are built');
  { The discontinuity of 1 / X falls exactly on a thread boundary when their count is even }
  One('a hyperbola, 2 threads', '1 / X', 4, 4, 2, 2);
  One('a hyperbola, 4 threads', '1 / X', 4, 4, 4, 2);
  One('a tangent, 3 threads', 'tan(X)', 5, 4, 3, 4);
  {
    The invisible part ends exactly on a thread boundary: 4 / (X * X) stays
    within MaxY = 1 only for |X| >= 2, and with four threads over [-4, 4] the
    boundary is precisely at X = 2. The middle threads give no points at all,
    and only the break flag of the previous non-empty thread can split the curve.
  }
  One('a discontinuity on a thread seam', '4 / (X * X)', 4, 1, 4, 2);
end;

procedure TestPlaceNavigation;
var
  GraphCase: TGraphCase;
  Data: PFormulaData;
  Expected: TPointDArray;
  Place: TPlace;
  I, J, Min, Max, Count: Integer;
  Ok: Boolean;
begin
  Section('Navigating a slice of curves');
  GraphCase := MakeCase('a slice of a tangent', 'tan(X)', '', 5, 4);
  GraphCase.Overlap := False;
  Host.Run(GraphCase, wkNone);
  Data := Host.Graph.Formula.Data[0];
  Check(Assigned(Data), 'the formula data was obtained');
  if not Assigned(Data) then Exit;
  // A direct enumeration of the slice points - the reference for comparing with Shift.
  Count := 0;
  SetLength(Expected, 0);
  for I := Data.EntireBack.ArrayIndex to Data.EntireFace.ArrayIndex do
  begin
    if not GetRange(Host.Graph.EntireArray, Data.EntireBack, Data.EntireFace, I, Min, Max) then
      Continue;
    for J := Min to Max do
    begin
      SetLength(Expected, Count + 1);
      Expected[Count] := Host.Graph.EntireArray[I, J];
      Inc(Count);
    end;
  end;
  Note(Format('pieces %d, points in the slice %d', [Data.EntireFace.ArrayIndex - Data.EntireBack.ArrayIndex + 1, Count]));
  Check(Count > 0, 'the slice is not empty');
  Ok := True;
  for I := 0 to Count - 1 do
    if not Shift(Host.Graph.EntireArray, Data.EntireBack, Data.EntireFace, I, Place) or
      (Host.Graph.EntireArray[Place.ArrayIndex, Place.Index].X <> Expected[I].X) or
      (Host.Graph.EntireArray[Place.ArrayIndex, Place.Index].Y <> Expected[I].Y) then
      begin
        Ok := False;
        Note(Format('a mismatch at offset %d', [I]));
        Break;
      end;
  Check(Ok, 'Shift walks the slice in the same order as a direct enumeration');
  Check(not Shift(Host.Graph.EntireArray, Data.EntireBack, Data.EntireFace, Count, Place), 'Shift past the end of the slice refuses');
  Check(Empty(MakePlace(1, 0), MakePlace(0, 5)), 'a reversed slice counts as empty');
  Check(not Empty(MakePlace(0, 0), MakePlace(1, 5)), 'a forward slice does not count as empty');
end;

begin
  try
    Application.Initialize;
    Host := TGraphHost.Create;
    try
      TestOverlapAccuracy;
      TestOverlapConvergence;
      TestExtremes;
      TestDiscontinuity;
      TestCurveStructure;
      TestTouchAndMiss;
      TestSameCurve;
      TestPoleOverlap;
      TestRootOnBorder;
      TestPainting;
      TestPlaceNavigation;
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
  Section(Format('TOTAL: checks %d, failures %d', [TotalCount, FailedCount]));
  SaveReport(ChangeFileExt(ParamStr(0), '.log'));
  ExitCode := FailedCount;
end.
