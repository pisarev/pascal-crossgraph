{ ************************************************************************** }
{                                                                            }
{ EngineTests                                                                }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

{
  Intersection search with no form, no window and no message queue. Readiness
  arrives as an event straight from the worker thread, so the handler only
  raises a flag and the actual inspection runs on the main thread.
}

program EngineTests;

{$APPTYPE CONSOLE}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  {$IFDEF FPC}
  {$IFDEF UNIX}cthreads,{$ENDIF}
  {
    Built with -dNOFORMS: then the base Thread does not pull in Forms and no
    widgetset is needed at all - no nogui, no gtk, no display. Without that
    flag (the ordinary build) Interfaces is included, because Thread brings
    Forms along. GetTickCount64 and Sleep come from SysUtils, so the Windows
    unit is not needed.
  }
  {$IFNDEF NOFORMS}Interfaces,{$ENDIF} SysUtils, Math, Classes, Types,
  {$ELSE}
  Winapi.Windows, System.SysUtils, System.Math, System.Classes, System.Types,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Geometry,
  CrossGraph.Engine;

{$IFDEF FPC}
function GetTickCount: LongWord;
begin
  Result := LongWord(SysUtils.GetTickCount64);
end;
{$ENDIF}

const
  Tolerance = 1E-4;
  CanvasSide = 600;
  WaitLimit = 20000;
  PollStep = 5;

type
  TRoot = record
    X, Y: Double;
  end;
  TRootArray = array of TRoot;

  TWaiter = class
    Ready: Boolean;
    Peaked: Boolean;
    procedure Handle(Sender: TObject; const Kind: TResultKind);
  end;

procedure TWaiter.Handle(Sender: TObject; const Kind: TResultKind);
begin
  if Kind = rkOverlap then Ready := True;
  if Kind = rkExtreme then Peaked := True;
end;

var
  Total: Integer = 0;
  Failed: Integer = 0;
  Report: TStringList;

procedure Emit(const Line: string);
begin
  Writeln(Line);
  Report.Add(Line);
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

function Root(const X, Y: Double): TRoot;
begin
  Result.X := X;
  Result.Y := Y;
end;

function MaxError(const Overlaps: TOverlapArray; const Roots: TRootArray): Double;
var
  I, J: Integer;
  Best, D: Double;
begin
  Result := 0;
  for I := Low(Roots) to High(Roots) do
  begin
    Best := Infinity;
    for J := Low(Overlaps) to High(Overlaps) do
    begin
      D := Sqrt(Sqr(Overlaps[J].Point.X - Roots[I].X) + Sqr(Overlaps[J].Point.Y - Roots[I].Y));
      if D < Best then Best := D;
    end;
    if Best > Result then Result := Best;
  end;
end;

{
  How many found points landed on no expected root at all. The error over the
  expected roots cannot see this: it measures the distance from each ROOT to
  the nearest find, and a spurious find affects nothing.
}
function Strays(const Overlaps: TOverlapArray; const Roots: TRootArray; const Grain: Double): Integer;
var
  I, J: Integer;
  Best, D: Double;
begin
  Result := 0;
  for J := Low(Overlaps) to High(Overlaps) do
  begin
    Best := Infinity;
    for I := Low(Roots) to High(Roots) do
    begin
      D := Sqrt(Sqr(Overlaps[J].Point.X - Roots[I].X) + Sqr(Overlaps[J].Point.Y - Roots[I].Y));
      if D < Best then Best := D;
    end;
    if Best > Grain then Inc(Result);
  end;
end;

{
  How many pairs of found points stand on the same spot. One point under two
  letters is not "found with a margin", it is a defect: the person sees one
  mark where the list promises two.
}
function Twins(const Overlaps: TOverlapArray): Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := Low(Overlaps) to High(Overlaps) do
    for J := I + 1 to High(Overlaps) do
      if Sqrt(Sqr(Overlaps[I].Point.X - Overlaps[J].Point.X) + Sqr(Overlaps[I].Point.Y - Overlaps[J].Point.Y)) <=
        Tolerance then
          Inc(Result);
end;

procedure One(const Name, A, B: string; const Polar: Boolean; const MaxX, MaxY: Extended;
  const Depth: Integer; const Roots: TRootArray; const Time: Integer = 2000; const Precise: Boolean = True;
  const Grain: Double = Tolerance);
var
  Engine: TGraphEngine;
  Waiter: TWaiter;
  Start: Cardinal;
  Error: Double;
  Done: Boolean;
begin
  Waiter := TWaiter.Create;
  Engine := TGraphEngine.Create(nil);
  try
    Engine.OnResultReady := Waiter.Handle;
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxY;
    Engine.Overlap := True;
    Engine.Extreme := False;
    {
      Thinning is switched off here on purpose. These checks ask WHAT was
      found, while thinning decides what to SHOW and depends on the zoom: with
      a view of ten on a canvas of six hundred, the two points of the polar
      circles stand 13.4 pixels apart, so with a spacing of 14 one of them is
      legitimately hidden. Thinning itself has separate checks below.
    }
    Engine.MarkSpacing := 0;
    Engine.HighPrecision := Precise;
    Engine.OverlapMaxDepth := Depth;
    Engine.OverlapMaxTime := Time;
    Engine.Formula.Add(A, True, True, False);
    Engine.Formula.Add(B, True, True, False);
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    repeat
      Sleep(PollStep);
      Done := Waiter.Ready and not Engine.Busy;
    until Done or (GetTickCount - Start > WaitLimit);
    Error := MaxError(Engine.OverlapArray, Roots);
    Emit(Format('       %s: points %d, expected %d, error %.10f, %d ms',
      [Name, Length(Engine.OverlapArray), Length(Roots), Error, GetTickCount - Start]));
    Check(Done, Name + ': computation finished');
    Check(Error <= Grain, Name + ': coordinates match the analytic ones');
    {
      This used to say "found at least as many as expected". Such a check goes
      green both when one point is reported twice and when an invented point
      lies next to a real one. The full answer is known beforehand - so the
      full question must be asked: how many, the right ones, and no repeats.
    }
    Check(Length(Engine.OverlapArray) = Length(Roots), Format('%s: exactly %d intersections', [Name, Length(Roots)]));
    Check(Strays(Engine.OverlapArray, Roots, Grain) = 0, Name + ': no spurious points');
    Check(Twins(Engine.OverlapArray) = 0, Name + ': no point reported twice');
  finally
    Engine.Free;
    Waiter.Free;
  end;
end;

{
  Mark thinning. What is asked is not a number - that depends on the zoom -
  but the contract itself: shown marks are no closer than the given number of
  pixels to each other, and the total count of what was found is not lost.
}
procedure Crowd(const Name, A, B: string; const Polar: Boolean; const MaxX: Extended;
  const Spacing, Least: Integer);
var
  Engine: TGraphEngine;
  Start: Cardinal;
  I, J: Integer;
  Pixel, Near: Double;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then Engine.CS := csPolar else Engine.CS := csRectangular;
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxX;
    Engine.Overlap := True;
    Engine.Extreme := False;
    Engine.MarkSpacing := Spacing;
    Engine.HighPrecision := True;
    Engine.OverlapMaxDepth := 100;
    Engine.OverlapMaxTime := 2000;
    Engine.Formula.Add(A, True, True, False);
    Engine.Formula.Add(B, True, True, False);
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    while Engine.Busy and (GetTickCount - Start < WaitLimit) do Sleep(PollStep);
    Pixel := 2 * MaxX / CanvasSide;
    Near := Infinity;
    for I := Low(Engine.OverlapArray) to High(Engine.OverlapArray) do
      for J := I + 1 to High(Engine.OverlapArray) do
        if DistanceOf(Engine.OverlapArray[I].Point, Engine.OverlapArray[J].Point) < Near then
          Near := DistanceOf(Engine.OverlapArray[I].Point, Engine.OverlapArray[J].Point);
    Emit(Format('       %s: shown %d, total %d, closest pair %.1f pixels',
      [Name, Length(Engine.OverlapArray), Engine.OverlapTotal, Near / Pixel]));
    Check(Engine.OverlapTotal >= Least, Format('%s: found at least %d', [Name, Least]));
    Check(Length(Engine.OverlapArray) <= Engine.OverlapTotal, Name + ': shown no more than found');
    if Spacing > 0 then
    begin
      Check(Length(Engine.OverlapArray) < Engine.OverlapTotal, Name + ': thinning kicked in');
      Check(
        Near / Pixel >= Spacing,
        Format(
          '%s: shown marks no closer than %d pixels',
          [
            Name,
            Spacing
          ]
        )
      );
    end
    else
      Check(Near / Pixel < 14, Name + ': without thinning marks sit closer than the spacing');
  finally
    Engine.Free;
  end;
end;

{
  Coinciding curves. Two curves lying on top of each other have no separate
  intersection points: the intersection is the whole curve. There must be no
  marks at all, and the indistinguishable span must be named.
}
procedure Alike(const Name, A, B: string; const Polar: Boolean; const MaxX: Extended);
var
  Engine: TGraphEngine;
  Start: Cardinal;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then Engine.CS := csPolar else Engine.CS := csRectangular;
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxX;
    Engine.Overlap := True;
    Engine.Extreme := False;
    Engine.HighPrecision := True;
    Engine.OverlapMaxDepth := 100;
    Engine.OverlapMaxTime := 2000;
    Engine.Formula.Add(A, True, True, False);
    Engine.Formula.Add(B, True, True, False);
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    while Engine.Busy and (GetTickCount - Start < WaitLimit) do Sleep(PollStep);
    Emit(Format('       %s: marks %d, total %d, spans %d',
      [Name, Length(Engine.OverlapArray), Engine.OverlapTotal, Length(Engine.SameArray)]));
    Check(Length(Engine.OverlapArray) = 0, Name + ': no marks');
    Check(Engine.OverlapTotal = 0, Name + ': nothing found either');
    Check(Length(Engine.SameArray) > 0, Name + ': the indistinguishable span is named');
  finally
    Engine.Free;
  end;
end;

{
  The same formula entered twice. The formula list keeps a single instance, so
  the intersection search never even starts.
}
procedure Twice(const Name, A: string; const Polar: Boolean; const MaxX: Extended);
var
  Engine: TGraphEngine;
  Start: Cardinal;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then Engine.CS := csPolar else Engine.CS := csRectangular;
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxX;
    Engine.Overlap := True;
    Engine.Extreme := False;
    Engine.Formula.Add(A, True, True, False);
    Engine.Formula.Add(A, True, True, False);
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    while Engine.Busy and (GetTickCount - Start < WaitLimit) do Sleep(PollStep);
    Emit(Format('       %s: curves %d, marks %d', [Name, Engine.Formula.Count, Length(Engine.OverlapArray)]));
    Check(Engine.Formula.Count = 1, Name + ': a single curve remained');
    Check(Length(Engine.OverlapArray) = 0, Name + ': no marks');
  finally
    Engine.Free;
  end;
end;

{
  The sampling contract: neighbouring accepted points lie in DIFFERENT pixels.
  It is the contract that is checked, not a point count: a fast oscillation
  travels across the screen many times the canvas perimeter, so any limit on
  the count would be plucked from thin air - sin(60*X) on a window of ten
  honestly yields six thousand points against a perimeter of twenty four
  hundred.

  One coincidence per piece is allowed: the last point of a piece is always
  stored, even if it lands in an occupied pixel, otherwise the polyline never
  reaches the end of the curve.

  Without this contract the point count was driven by the parameter step and
  grew with zoom without bound: a window of one produced 38790 points, of
  which 33243 (85.7%) landed in an already occupied pixel. They could not be
  seen, yet they were computed, stored, walked during assembly and shipped to
  the page as text.
}
procedure Density(const Name, Formula: string; const Polar: Boolean; const MaxX: Extended);
var
  Engine: TGraphEngine;
  I, J, Points, Doubles, Pieces: Integer;
  Back, Face: TPoint;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then Engine.CS := csPolar else Engine.CS := csRectangular;
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxX;
    Engine.Overlap := False;
    Engine.Extreme := False;
    Engine.Formula.Add(Formula, True, True, False);
    Engine.Prepare;
    Engine.Parse;
    while Engine.Busy do Sleep(PollStep);
    Points := 0;
    Doubles := 0;
    Pieces := 0;
    for I := Low(Engine.EntireArray) to High(Engine.EntireArray) do
    begin
      Inc(Points, Length(Engine.EntireArray[I]));
      if Length(Engine.EntireArray[I]) > 0 then Inc(Pieces);
      for J := Low(Engine.EntireArray[I]) + 1 to High(Engine.EntireArray[I]) do
      begin
        Back := PointI(Engine.PointToCursor(Engine.EntireArray[I][J - 1]));
        Face := PointI(Engine.PointToCursor(Engine.EntireArray[I][J]));
        if (Back.X = Face.X) and (Back.Y = Face.Y) then Inc(Doubles);
      end;
    end;
    Emit(Format('       %s: points %d, pieces %d, in an occupied pixel %d', [Name, Points, Pieces, Doubles]));
    Check(Points > 0, Name + ': the curve is not empty');
    Check(Doubles <= Pieces, Format('%s: neighbouring points in different pixels', [Name]));
  finally
    Engine.Free;
  end;
end;

{
  Extrema of a single curve. The expectation is given as points on the plane,
  not by parameter: in polar coordinates the radius maximum at one angle and
  the minimum at that angle plus pi are the same point of the plane, and there
  must be as many marks on screen as there are places, not as many roots as
  the derivative has.
}
procedure Peaks(const Name, Formula: string; const Polar: Boolean; const MaxX, MaxY: Extended;
  const Spots: TRootArray; const Grain: Double = Tolerance);
var
  Engine: TGraphEngine;
  Waiter: TWaiter;
  Start: Cardinal;
  Done: Boolean;
  I, J, Count, Stray, Twin: Integer;
  Found: TRootArray;
  Best, D: Double;

  procedure Collect(const Source: TCurveDArray);
  var
    K, L: Integer;
  begin
    for K := Low(Source) to High(Source) do
      for L := Low(Source[K]) to High(Source[K]) do
      begin
        SetLength(Found, Length(Found) + 1);
        Found[High(Found)].X := Source[K][L].X;
        Found[High(Found)].Y := Source[K][L].Y;
      end;
  end;

begin
  Waiter := TWaiter.Create;
  Engine := TGraphEngine.Create(nil);
  try
    Engine.OnResultReady := Waiter.Handle;
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then Engine.CS := csPolar else Engine.CS := csRectangular;
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxY;
    Engine.Overlap := False;
    Engine.Extreme := True;
    Engine.HighPrecision := True;
    Engine.Formula.Add(Formula, True, True, False);
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    repeat
      Sleep(PollStep);
      Done := Waiter.Peaked and not Engine.Busy;
    until Done or (GetTickCount - Start > WaitLimit);

    Found := nil;
    Collect(Engine.MaxArray);
    Collect(Engine.MinArray);
    Count := Length(Found);

    Stray := 0;
    for J := Low(Found) to High(Found) do
    begin
      Best := Infinity;
      for I := Low(Spots) to High(Spots) do
      begin
        D := Sqrt(Sqr(Found[J].X - Spots[I].X) + Sqr(Found[J].Y - Spots[I].Y));
        if D < Best then Best := D;
      end;
      if Best > Grain then Inc(Stray);
    end;

    Twin := 0;
    for I := Low(Found) to High(Found) do
      for J := I + 1 to High(Found) do
        if Sqrt(Sqr(Found[I].X - Found[J].X) + Sqr(Found[I].Y - Found[J].Y)) <= Grain then
          Inc(Twin);

    Emit(Format('       %s: marks %d, off the expected places %d, repeats %d, %d ms', [Name, Count, Stray, Twin, GetTickCount - Start]));
    for J := Low(Found) to High(Found) do
      Emit(Format('         (%.6f, %.6f)', [Found[J].X, Found[J].Y]));
    Check(Done, Name + ': computation finished');
    {
      The mark is a TURN of the drawn curve, not its highest point within the
      window: a polyline vertex whose both neighbours are lower (or both
      higher). In polar coordinates the measure is the distance to the pole.
      The expected places are printed nearby for checking by eye.
    }
    Check(Count = Length(Spots), Format('%s: exactly %d marks', [Name, Length(Spots)]));
    Check(Stray = 0, Name + ': no mark off its place');
    Check(Twin = 0, Name + ': no place marked twice');
  finally
    Engine.Free;
    Waiter.Free;
  end;
end;

{
  The spacing between marks is kept in PIXELS and does not drift with zoom.
  Asked at two views at once: at both, the closest pair of extrema must stand
  no closer than the given spacing.

  Previously the merge radius of nearby extrema was computed once and stored
  in graph units. At a different zoom the same radius meant a different number
  of pixels, and the crowding of marks drifted with the scale.
}
procedure Steady(const Name, Formula: string; const Polar: Boolean; const Near, Far: Extended;
  const Spacing: Integer);
var
  Engine: TGraphEngine;
  Close, Wide: Double;

  {
    The zoom CHANGES on one and the same engine - exactly what a person does
    in the panel. Two separate engines would check nothing here: each would
    compute the merge radius afresh for its own view, and the substitution
    would go unnoticed.
  }
  function Tight(const MaxX: Extended): Double;
  var
    Start: Cardinal;
    Spots: TRootArray;
    I, J, K: Integer;

    procedure Collect(const Source: TCurveDArray);
    var
      M, N: Integer;
    begin
      for M := Low(Source) to High(Source) do
        for N := Low(Source[M]) to High(Source[M]) do
        begin
          SetLength(Spots, Length(Spots) + 1);
          Spots[High(Spots)] := Root(Source[M][N].X, Source[M][N].Y);
        end;
    end;

  begin
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxX;
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    while Engine.Busy and (GetTickCount - Start < WaitLimit) do Sleep(PollStep);
    Spots := nil;
    Collect(Engine.MaxArray);
    Collect(Engine.MinArray);
    Result := Infinity;
    K := Length(Spots);
    for I := 0 to K - 1 do
      for J := I + 1 to K - 1 do
        if DistanceOf(PointD(Spots[I].X, Spots[I].Y), PointD(Spots[J].X, Spots[J].Y)) < Result then
          Result := DistanceOf(PointD(Spots[I].X, Spots[I].Y), PointD(Spots[J].X, Spots[J].Y));
    // From graph units into pixels of this view.
    if K > 1 then Result := Result * CanvasSide / (2 * MaxX);
    Emit(Format('       %s: view %.4g, marks %d, closest pair %.1f pixels', [Name, MaxX, K, Result]));
  end;

begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then Engine.CS := csPolar else Engine.CS := csRectangular;
    Engine.MarkSpacing := Spacing;
    Engine.Overlap := False;
    Engine.Extreme := True;
    Engine.Formula.Add(Formula, True, True, False);
    Close := Tight(Near);
    Wide := Tight(Far);
  finally
    Engine.Free;
  end;
  Check(Close >= Spacing, Format('%s: at the near view marks no closer than %d pixels', [Name, Spacing]));
  Check(Wide >= Spacing, Format('%s: at the far view marks no closer than %d pixels', [Name, Spacing]));
end;

{
  Point count of the curve over one turn and over two. The ratio must be close
  to two: the angle is given in radians.
}
procedure Turns;
var
  Engine: TGraphEngine;
  Single_, Double_: Integer;

  function Points(const Angle: Extended): Integer;
  var
    I: Integer;
  begin
    Engine.PolarMaxAngle := Angle;
    Engine.Prepare;
    Engine.Parse;
    while Engine.Busy do Sleep(PollStep);
    Result := 0;
    for I := Low(Engine.EntireArray) to High(Engine.EntireArray) do
      Inc(Result, Length(Engine.EntireArray[I]));
  end;

begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    Engine.CS := csPolar;
    Engine.MaxX := 2;
    Engine.MaxY := 2;
    Engine.Overlap := False;
    Engine.Extreme := False;
    Engine.Formula.Add('sin(T)', True, True, False);
    Single_ := Points(Pi * 2);
    Double_ := Points(Pi * 4);
    Emit(Format('       polar angle in radians: one turn %d points, two %d, ratio %.2f', [Single_, Double_, Double_ / Single_]));
    Check((Double_ / Single_ > 1.5) and (Double_ / Single_ < 3), 'the polar angle is given in radians, not degrees');
  finally
    Engine.Free;
  end;
end;

begin
  Report := TStringList.Create;
  try
    try
      Emit('Headless engine: intersections');
      One('sin and cos', 'sin(X)', 'cos(X)', False, 5, 2, 100,
        [Root(Pi / 4, Sin(Pi / 4)), Root(Pi / 4 + Pi, Sin(Pi / 4 + Pi)), Root(Pi / 4 - Pi, Sin(Pi / 4 - Pi))]);
      One('parabola and line', 'X * X', 'X + 2', False, 4, 6, 100, [Root(-1, 1), Root(2, 4)]);
      One('cubic and line', 'X * X * X', 'X', False, 3, 3, 100, [Root(-1, -1), Root(0, 0), Root(1, 1)]);
      One('polar circles', '1', '2 * cos(T)', True, 3, 3, 100, [Root(Cos(Pi / 3), Sin(Pi / 3)), Root(Cos(Pi / 3), -Sin(Pi / 3))]);
      {
        The case that showed the single polar test was too easy. There both
        curves met at ONE angle, and neither touched the pole. Here it is the
        other way round, with both hard spots at once:

          r = sin(t)      is the circle  x^2 + y^2 = y
          r = cos(t) / 2  is the circle  x^2 + y^2 = x / 2

        Subtract one from the other: y = x/2; substitute: x = 0 or x = 2/5.
        Exactly two points, (0, 0) and (0.4, 0.2), and no others.

        The first is the pole: the curves arrive there at DIFFERENT angles,
        sin at t=0, cos/2 at t=pi/2, and the difference has no common root
        there at all. The second, if searched by a shared angle, is found
        twice: the root repeats at t and t+pi, where the radius of both flips
        sign while the point of the plane stays the same.
      }
      One('polar circles through the pole', 'sin(T)', 'cos(T) / 2', True, 2, 2, 100, [Root(0, 0), Root(0.4, 0.2)]);
      {
        The same case with the limits the panel ships with: depth 16 and one
        second for refinement, and a wider view - plus-minus ten, the way the
        panel opens. This is how it looks to the user.
      }
      One('polar circles, panel limits', 'sin(T)', 'cos(T) / 2', True, 10, 10, 16, [Root(0, 0), Root(0.4, 0.2)], 1000);
      {
        And the same with high precision off - exactly how the panel opens:
        the "High precision" switch is off by default.
      }
      {
        Without high precision the answer is coarser by definition - that is
        what the switch is about. Measured: 1.02E-4 against 0 with it on. We
        ask for what is promised - a thousandth, not a ten-thousandth.
      }
      One('polar circles, panel without high precision', 'sin(T)', 'cos(T) / 2', True, 10, 10, 16, [Root(0, 0), Root(0.4, 0.2)],
        1000, False, 1E-3);

      {
        Why the polar search cannot simply compare curves at a shared angle.
        The rose r = sin(2t) draws four petals, but HALF of them with a
        negative radius: for t from pi/2 to pi the radius is below zero, and
        the point lands at the angle t+pi, in the opposite quadrant.

        The circle r = 0.5 crosses every petal twice - eight points. Four of
        them meet at a shared angle; the other four only at angles that differ
        by pi, with a plus on one curve and a minus on the other. Comparison
        at a shared angle finds exactly half.
      }
      One(
        'rose and circle',
        'sin(2 * T)',
        '0.5',
        True,
        1.5,
        1.5,
        100,
        [
          Root(
            0.5 * Cos(Pi / 12),
            0.5 * Sin(Pi / 12)
          ),
          Root(
            0.5 * Cos(5 * Pi / 12),
            0.5 * Sin(5 * Pi / 12)
          ),
          Root(
            0.5 * Cos(7 * Pi / 12),
            0.5 * Sin(7 * Pi / 12)
          ),
          Root(
            0.5 * Cos(11 * Pi / 12),
            0.5 * Sin(11 * Pi / 12)
          ),
          Root(
            0.5 * Cos(13 * Pi / 12),
            0.5 * Sin(13 * Pi / 12)
          ),
          Root(
            0.5 * Cos(17 * Pi / 12),
            0.5 * Sin(17 * Pi / 12)
          ),
          Root(
            0.5 * Cos(19 * Pi / 12),
            0.5 * Sin(19 * Pi / 12)
          ),
          Root(
            0.5 * Cos(23 * Pi / 12),
            0.5 * Sin(23 * Pi / 12)
          )
        ]
      );

      {
        Tangency: the curves share a point but never cross each other. The
        segment-intersection search knows nothing about such a point - a
        tangency has no sign change - and it used to be lost entirely.

        There are two checks here, and the second matters more. Finding a
        tangency is easy if any approach counts: then two curves running side
        by side would sprinkle a mark on every pair of segments. So next to
        the "found it" check stands the "did not invent it" check.
      }
      One('tangency at zero', 'X * X', '0 - X * X', False, 3, 3, 100, [Root(0, 0)]);
      {
        A tangency NOT at a sampling node. The previous case is symmetric and
        zero lands exactly on a node: the curves meet at polyline vertices,
        and the answer comes out right even without refinement. The sine
        touches one at pi/2 - an irrational number that never lands on a node.
        Both refinement and the neighbouring-cell lookup work here: the chords
        near the tangency run on opposite sides of one, and a cell boundary
        may fall exactly between them.
      }
      One('sine touching one', 'sin(X)', '1', False, 5, 2, 100, [Root(Pi / 2, 1), Root(Pi / 2 - 2 * Pi, 1)]);
      {
        A tangency exactly on a grid cell boundary. The curves lie on opposite
        sides of zero and meet at the zeros of the sine; the joint extent runs
        from minus one to one, and the grid splits it in half - a cell
        boundary lands exactly on zero. If the lookup does not take the
        neighbouring cell, the segments of the two curves never meet AT ALL,
        and the tangency is lost entirely. Two tangencies out of three fall on
        plus-minus pi, that is, not on a sampling node.

        The tolerance here is a hundredth, not a ten-thousandth, and that is
        not a favour to the code but a property of the problem itself. The
        curves are mirrored, and near the tangency the distance between them
        grows as the FOURTH power of the offset: 0.0016 to the side moves them
        apart by a mere 5e-6. Asking for the coordinate to 1e-4 would mean
        telling apart distances of the order of 4e-16 - beyond double
        precision. In the picture this difference is a hundredth of a pixel.

        The check is still strict where it matters: exactly three tangencies,
        none spurious, no repeats.
      }
      One(
        'tangency on a cell boundary',
        'sin(X) * sin(X)',
        '0 - sin(X) * sin(X)',
        False,
        4,
        2,
        100,
        [
          Root(
            0,
            0
          ),
          Root(
            Pi,
            0
          ),
          Root(
            -Pi,
            0
          )
        ],
        2000,
        True,
        1E-2
      );
      {
        An inner tangency in polar coordinates: the circle of radius 2 and the
        circle r = 2 cos t, which lies inside it and reaches the rim exactly
        at t = 0. A single shared point - (2, 0).
      }
      One('tangency of polar circles', '2', '2 * cos(T)', True, 3, 3, 100, [Root(2, 0)]);
      {
        The curves run closer than a chord length yet never meet: the gap is
        even, there is no local minimum - and there must be no marks at all.
        A bare closeness threshold without this rule would produce them by
        the hundred.
      }
      One('curves nearby, not touching', 'X * X', 'X * X + 0.005', False, 3, 3, 100, []);
      {
        The same in polar coordinates, and this case is harder than the
        Cartesian one. Between two concentric circles the gap is CONSTANT
        along the whole walk: there is no local minimum at all, and whatever
        minimum is found is decided by rounding noise in the last digit. The
        Cartesian case never does this - there the normal distance changes
        with the slope.
      }
      One('circles nearby, not touching', '2', '1.995', True, 3, 3, 100, []);
      One('parallel lines', 'X', 'X + 1', False, 3, 3, 100, []);
      {
        A root exactly on the view edge: the line y = x and the level y = 2
        with MaxX = 2 meet in the very corner of the area. The parameter step
        accumulated by addition and fell just short of the edge, so the point
        stayed beyond the end of the last segment. On win64 Extended is half
        as wide, the miss is larger, and the check failed only there - a sign
        that the trouble was in accumulation, not in the search.
      }
      One('root at the view edge', 'X', '2', False, 2, 4, 100, [Root(2, 2)]);

      {
        The engine's polar angle is in RADIANS. Not a cosmetic detail: the
        panel used to send 360 from the page, meaning degrees, and put that
        number straight into the property. That made 57 full turns instead of
        one - the curve was traced 57 times over, points multiplied by as
        much, and the intersection search ran into its time limit and
        returned an empty list. In the picture the substitution is invisible:
        the loops lie on top of each other.

        The check pins down the unit: doubling the angle doubles the point
        count. If someone passes degrees here again, the ratio becomes 57
        instead of 2 and the check fails.
      }
      Emit('');
      Emit('Headless engine: mark thinning');
      {
        A fast sine crosses the line some four hundred times. All of them are
        real and the count must not be lost, but drawing them side by side is
        pointless: on screen they merge into a band. The contract is checked,
        not the quantity: shown marks no closer than the given pixels, found
        marks no fewer than the floor.
      }
      {
        The count expectation is modest and depends on the canvas: at six
        hundred pixels over a view of twenty, one period of sin(60 * X) takes
        three pixels, and the polyline resolves not all four hundred
        intersections but some fifty. That is a property of sampling, not of
        the search; this check is about the thinning contract, and it needs
        the number only so the case is not empty.
      }
      Crowd('fast sine, spacing 14', 'sin(60 * X)', '0', False, 10, 14, 30);
      Crowd('same without thinning', 'sin(60 * X)', '0', False, 10, 0, 30);

      Emit('');
      Emit('Headless engine: coinciding curves');
      {
        In polar coordinates 2 and -2 are ONE AND THE SAME circle: the points
        (r, t) and (-r, t+pi) coincide. The curves lie on each other entirely.

        This used to yield 128 marks: neighbouring links of one polyline meet
        at a shared vertex at an angle, and the search honestly reported a
        segment intersection - at every vertex along the whole curve. The
        marks were correct one by one and meaningless together: there is no
        spot to point at where the curves intersect, because they intersect
        everywhere.
      }
      Alike('polar: 2 and -2', '2', '0 - 2', True, 6);
      {
        Whereas the same formula entered twice never reaches the search at
        all: the formula list keeps a single instance. There is nothing to
        compare, and that is right - the user added the same curve, not a
        second one. The check pins exactly this down, so the behaviour cannot
        change silently.
      }
      Twice('cartesian: sin(X) twice', 'sin(X)', False, 10);
      Twice('polar: the rose twice', 'sin(2 * T)', True, 1.5);

      Turns;

      Emit('');
      Emit('Headless engine: sampling density');
      {
        One and the same circle at three zoom levels. The point count grows
        with its size on screen - which is right - but is capped by the canvas
        bounds, not by the parameter step.
      }
      Density('circle, window 10', 'sin(T)', True, 10);
      Density('circle, window 1', 'sin(T)', True, 1);
      Density('circle, window 0.2', 'sin(T)', True, 0.2);
      Density('sine, window 10', 'sin(X)', False, 10);
      Density('fast sine, window 10', 'sin(60 * X)', False, 10);

      Emit('');
      Emit('Headless engine: extrema');
      {
        The circle r = sin(t) in polar coordinates. The polar extremum measure
        is the distance to the pole, and it has exactly two turns: the far
        point is the top (0, 1), the near one is the pole itself, which the
        circle passes through. The radius maximum at t = pi/2 and the minimum
        at t = 3pi/2 give ONE point of the plane: at t = 3pi/2 the radius is
        minus one and the point reflects into itself.

        The tolerance is wider than the common one, and that is a promise of
        the design, not a favour: the mark goes to the nearest COMPUTED point
        of the curve, and after the switch to per-pixel sampling points are
        stored no denser than one per pixel. So the mark is correct to within
        a pixel - nothing more can be asked of a mark on screen. The view
        pixel here is 2 * 2 / 600; the tolerance is taken with a threefold
        margin.
      }
      Peaks('circle in polar', 'sin(T)', True, 2, 2, [Root(0, 1), Root(0, 0)], 1E-2);
      {
        A parabola in Cartesian: one turn, at the vertex. The window edges,
        where the curve leaves the frame, give no marks - an edge is not a
        turn.
      }
      Peaks('parabola', 'X * X', False, 3, 3, [Root(0, 0)]);
      {
        A sine in Cartesian, the window wider than the period: turns every pi,
        and all four must be marked. The view pixel here is 2 * 5 / 600 =
        0.0167, the tolerance is two pixels.
      }
      Peaks('sine', 'sin(X)', False, 5, 2, [Root(-3 * Pi / 2, 1), Root(Pi / 2, 1), Root(-Pi / 2, -1), Root(3 * Pi / 2, -1)], 3.4E-2);
      {
        A constant radius: NO turns at all. In polar coordinates an extremum
        is a turn of the distance to the pole, and for r = 2 it never changes.

        This used to produce some fifty peaks and as many dips, covering the
        circle with a solid picket fence. The cause was not the search but the
        tolerance: it was a constant 1e-16, while the distance itself is
        computed with an error of about 2e-16 - twice as large. Every spike of
        last-digit noise was declared a turn.
      }
      Peaks('circle of constant radius', '2', True, 6, 6, []);
      {
        The same curve written differently: 0 - 2 in polar gives THE SAME
        circle, because the points (r, t) and (-r, t+pi) coincide. No turns
        either.
      }
      Peaks('same circle with a minus', '0 - 2', True, 6, 6, []);
      {
        A fast sine at two zoom levels: it has hundreds of turns, and without
        a shared measure they would merge into a picket fence. What is asked
        is not a number - that depends on the view - but the contract itself:
        both near and far, marks no denser than the spacing.
      }
      Steady('fast sine at two views', 'sin(30 * X)', False, 3, 12, 14);
    except
      on E: Exception do
      begin
        Emit('EXCEPTION: ' + E.ClassName + ': ' + E.Message);
        Check(False, 'run without exceptions');
      end;
    end;
    Emit('');
    Emit(Format('TOTAL: checks %d, failures %d', [Total, Failed]));
    try
      Report.SaveToFile(ChangeFileExt(ParamStr(0), '.log'), TEncoding.UTF8);
    except
      on E: Exception do Writeln('the log was not saved: ', E.Message);
    end;
  finally
    Report.Free;
  end;
  ExitCode := Failed;
end.
