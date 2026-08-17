{ ************************************************************************** }
{                                                                            }
{ EngineTests                                                                }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

program EngineTests;

{$APPTYPE CONSOLE}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  {$IFDEF FPC}
  {$IFDEF UNIX}cthreads,{$ENDIF}
  {$IFNDEF NOFORMS}Interfaces,{$ENDIF} SysUtils, Math, Classes, Types,
  {$ELSE}
  Winapi.Windows, System.SysUtils, System.Math, System.Classes, System.Types,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossVision.Geometry, ParseJit.Parser, CrossGraph.Types,
  CrossGraph.Geometry, CrossGraph.Engine;

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
    Check(Length(Engine.OverlapArray) = Length(Roots),
      Format('%s: exactly %d intersections', [Name, Length(Roots)]));
    Check(Strays(Engine.OverlapArray, Roots, Grain) = 0, Name + ': no spurious points');
    Check(Twins(Engine.OverlapArray) = 0, Name + ': no point reported twice');
  finally
    Engine.Free;
    Waiter.Free;
  end;
end;

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
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
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

procedure Alike(const Name, A, B: string; const Polar: Boolean; const MaxX: Extended);
var
  Engine: TGraphEngine;
  Start: Cardinal;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
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

procedure Twice(const Name, A: string; const Polar: Boolean; const MaxX: Extended);
var
  Engine: TGraphEngine;
  Start: Cardinal;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
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

procedure Density(const Name, Formula: string; const Polar: Boolean; const MaxX: Extended);
var
  Engine: TGraphEngine;
  I, J, Points, Doubles, Pieces: Integer;
  Back, Face: TPoint;
begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
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
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
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
    Emit(Format('       %s: marks %d, off the expected places %d, repeats %d, %d ms',
      [Name, Count, Stray, Twin, GetTickCount - Start]));
    for J := Low(Found) to High(Found) do
      Emit(Format('         (%.6f, %.6f)', [Found[J].X, Found[J].Y]));
    Check(Done, Name + ': computation finished');
    Check(Count = Length(Spots), Format('%s: exactly %d marks', [Name, Length(Spots)]));
    Check(Stray = 0, Name + ': no mark off its place');
    Check(Twin = 0, Name + ': no place marked twice');
  finally
    Engine.Free;
    Waiter.Free;
  end;
end;

procedure Steady(const Name, Formula: string; const Polar: Boolean; const Near, Far: Extended;
  const Spacing: Integer);
var
  Engine: TGraphEngine;
  Close, Wide: Double;

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
    if K > 1 then Result := Result * CanvasSide / (2 * MaxX);
    Emit(Format('       %s: view %.4g, marks %d, closest pair %.1f pixels', [Name, MaxX, K, Result]));
  end;

begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    if Polar then
      Engine.CS := csPolar
    else
      Engine.CS := csRectangular;
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

procedure Sharp(const Name, Formula: string; const Expect: TRoot; const Near, Far: Extended;
  const Grain: Double = Tolerance);
var
  Engine: TGraphEngine;
  Close, Wide: TRoot;
  Apart: Double;

  function Nearest(const MaxX: Extended): TRoot;
  var
    Start: Cardinal;
    Spots: TRootArray;
    I: Integer;
    Best, D: Double;

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
    Result := Root(Infinity, Infinity);
    Engine.MaxX := MaxX;
    Engine.MaxY := MaxX;
    Engine.Prepare;
    Engine.Parse;
    Start := GetTickCount;
    while Engine.Busy and (GetTickCount - Start < WaitLimit) do Sleep(PollStep);
    Spots := nil;
    Collect(Engine.MaxArray);
    Collect(Engine.MinArray);
    Best := Infinity;
    for I := Low(Spots) to High(Spots) do
    begin
      D := Sqrt(Sqr(Spots[I].X - Expect.X) + Sqr(Spots[I].Y - Expect.Y));
      if D < Best then
      begin
        Best := D;
        Result := Spots[I];
      end;
    end;
    Emit(Format('       %s: view %.4g, marks %d, nearest (%.9f, %.9f), off by %.3g',
      [Name, MaxX, Length(Spots), Result.X, Result.Y, Best]));
  end;

begin
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    Engine.CS := csRectangular;
    Engine.Overlap := False;
    Engine.Extreme := True;
    Engine.HighPrecision := True;
    Engine.Formula.Add(Formula, True, True, False);
    Close := Nearest(Near);
    Wide := Nearest(Far);
  finally
    Engine.Free;
  end;
  Check(Sqrt(Sqr(Close.X - Expect.X) + Sqr(Close.Y - Expect.Y)) <= Grain,
    Format('%s: at the close view the extremum is where it is', [Name]));
  Check(Sqrt(Sqr(Wide.X - Expect.X) + Sqr(Wide.Y - Expect.Y)) <= Grain,
    Format('%s: at the wide view the extremum is where it is', [Name]));
  Apart := Sqrt(Sqr(Close.X - Wide.X) + Sqr(Close.Y - Wide.Y));
  Check(Apart <= Grain,
    Format('%s: the mark stayed put when the view changed, apart by %.3g', [Name, Apart]));
end;

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
    Emit(Format('       polar angle in radians: one turn %d points, two %d, ratio %.2f',
      [Single_, Double_, Double_ / Single_]));
    Check((Double_ / Single_ > 1.5) and (Double_ / Single_ < 3),
      'the polar angle is given in radians, not degrees');
  finally
    Engine.Free;
  end;
end;

procedure AbortWaitFollowsWorkTime;
var
  T: TGraphThread;
  Limits: array [0 .. 4] of LongWord;
  I: Integer;
begin
  Emit('');
  Emit('--- the abort wait follows the work limit ---');
  Limits[0] := 1;
  Limits[1] := 20;
  Limits[2] := 5000;
  Limits[3] := 60000;
  Limits[4] := 0;
  T := TGraphThread.Create(nil);
  try
    Check(T.AbortTime > T.WorkTime, 'by default the wait is longer than the limit');
    for I := Low(Limits) to High(Limits) do
    begin
      T.WorkTime := Limits[I];
      Check(T.AbortTime = T.WorkTime * 2, Format('limit %d: the wait is twice as long', [Limits[I]]));
      Check((Limits[I] = 0) or (T.AbortTime > T.WorkTime),
        Format('limit %d: the wait is strictly longer', [Limits[I]]));
    end;
  finally
    T.Free;
  end;
end;

procedure ParserSwapChecks;
var
  Engine: TGraphEngine;
  Other: TJitParser;
begin
  Emit('');
  Emit('replacing the parser');
  Other := TJitParser.Create(nil);
  Engine := TGraphEngine.Create(nil);
  try
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    Engine.Overlap := False;
    Engine.Extreme := False;
    Engine.Formula.Add('sin(X)', True, True, False);
    Engine.Formula.Add('cos(X)', True, True, False);
    Engine.Prepare;
    Engine.Parse;
    Check(Length(Engine.SA) = 2, 'parsing produced the scripts of both formulas');
    Check(not Engine.Busy, 'with overlaps off the engine is not busy');
    Engine.Overlap := True;
    Check(Engine.Busy, 'the old parser prepared the overlaps and they await the start');
    Engine.Overlap := False;
    Engine.Formula.Correct[1] := False;
    Engine.Formula.Visible[1] := False;
    Engine.Parser := Other;
    Check(Length(Engine.SA) = 0, 'the bytecode of the old parser is gone from the engine');
    Check(Engine.Formula.Correct[1] and Engine.Formula.Visible[1], 'the rejected formula got another chance');
    Engine.Overlap := True;
    Check(not Engine.Busy, 'what the old parser prepared went away with it');
    Engine.StartOverlap;
    Check(not Engine.Busy, 'the start after the replacement raised no old bytecode');
    Engine.Overlap := False;
    Engine.Parse;
    Check(Length(Engine.SA) = 2, 'the new parser parsed both formulas again');
  finally
    Engine.Free;
    Other.Free;
  end;
end;

procedure HullChecks;

  function Hull(const Xs: array of Double): TPointDArray;
  var
    Points: TPointDArray;
    I: Integer;
  begin
    SetLength(Points, Length(Xs));
    for I := 0 to High(Xs) do
    begin
      Points[I].X := Xs[I];
      Points[I].Y := Xs[I] * Xs[I];
    end;
    Result := ConvexHull(Points, False);
  end;

  function OnParabola(const H: TPointDArray; const Count: Integer): Boolean;
  var
    I: Integer;
  begin
    Result := Length(H) = Count;
    if not Result then Exit;
    for I := 0 to High(H) do
      if Abs(H[I].Y - H[I].X * H[I].X) > 1e-9 then Exit(False);
  end;

var
  H: TPointDArray;
  Nasty: TPointDArray;
  I, N: Integer;
begin
  Emit('');
  Emit('the convex hull');
  H := Hull([0, 1, 2, 3, 4, 5, 6, 7]);
  Check(OnParabola(H, 8), 'the hull of a parabola: all eight points, ascending');
  H := Hull([0, 3, 5, 7, 1, 4, 2, 6]);
  Check(OnParabola(H, 8), 'the same hull on the permutation from the review');
  N := 200000;
  SetLength(Nasty, N);
  for I := 0 to N - 1 do
  begin
    if Odd(I) then
      Nasty[I].X := I
    else
      Nasty[I].X := N - I;
    Nasty[I].Y := Nasty[I].X * Nasty[I].X;
  end;
  try
    H := ConvexHull(Nasty, False);
    Check(Length(H) > 0,
      Format('two hundred thousand points did not blow the stack, %d vertices', [Length(H)]));
  except
    on E: Exception do
      Check(False, 'two hundred thousand points: ' + E.ClassName + ': ' + E.Message);
  end;
end;

begin
  Report := TStringList.Create;
  try
    try
      AbortWaitFollowsWorkTime;
      Emit('Headless engine: intersections');
      One('sin and cos', 'sin(X)', 'cos(X)', False, 5, 2, 100,
        [Root(Pi / 4, Sin(Pi / 4)), Root(Pi / 4 + Pi, Sin(Pi / 4 + Pi)), Root(Pi / 4 - Pi, Sin(Pi / 4 - Pi))]);
      One('parabola and line', 'X * X', 'X + 2', False, 4, 6, 100, [Root(-1, 1), Root(2, 4)]);
      One('cubic and line', 'X * X * X', 'X', False, 3, 3, 100, [Root(-1, -1), Root(0, 0), Root(1, 1)]);
      One('polar circles', '1', '2 * cos(T)', True, 3, 3, 100,
        [Root(Cos(Pi / 3), Sin(Pi / 3)), Root(Cos(Pi / 3), -Sin(Pi / 3))]);
      One('polar circles through the pole', 'sin(T)', 'cos(T) / 2', True, 2, 2, 100,
        [Root(0, 0), Root(0.4, 0.2)]);
      One('polar circles, panel limits', 'sin(T)', 'cos(T) / 2', True, 10, 10, 16,
        [Root(0, 0), Root(0.4, 0.2)], 1000);
      One('polar circles, panel without high precision', 'sin(T)', 'cos(T) / 2', True, 10, 10, 16,
        [Root(0, 0), Root(0.4, 0.2)], 1000, False, 1E-3);
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
      One('tangency at zero', 'X * X', '0 - X * X', False, 3, 3, 100, [Root(0, 0)]);
      One('sine touching one', 'sin(X)', '1', False, 5, 2, 100, [Root(Pi / 2, 1), Root(Pi / 2 - 2 * Pi, 1)]);
      One('tangency on a cell boundary', 'sin(X) * sin(X)', '0 - sin(X) * sin(X)', False, 4, 2, 100,
        [Root(0, 0), Root(Pi, 0), Root(-Pi, 0)], 2000, True, 1E-2);
      One('tangency of polar circles', '2', '2 * cos(T)', True, 3, 3, 100, [Root(2, 0)]);
      One('curves nearby, not touching', 'X * X', 'X * X + 0.005', False, 3, 3, 100, []);
      One('circles nearby, not touching', '2', '1.995', True, 3, 3, 100, []);
      One('parallel lines', 'X', 'X + 1', False, 3, 3, 100, []);
      One('root at the view edge', 'X', '2', False, 2, 4, 100, [Root(2, 2)]);
      Emit('');
      Emit('Headless engine: mark thinning');
      Crowd('fast sine, spacing 14', 'sin(60 * X)', '0', False, 10, 14, 30);
      Crowd('same without thinning', 'sin(60 * X)', '0', False, 10, 0, 30);
      Emit('');
      Emit('Headless engine: coinciding curves');
      Alike('polar: 2 and -2', '2', '0 - 2', True, 6);
      Twice('cartesian: sin(X) twice', 'sin(X)', False, 10);
      Twice('polar: the rose twice', 'sin(2 * T)', True, 1.5);
      Turns;
      Emit('');
      Emit('Headless engine: sampling density');
      Density('circle, window 10', 'sin(T)', True, 10);
      Density('circle, window 1', 'sin(T)', True, 1);
      Density('circle, window 0.2', 'sin(T)', True, 0.2);
      Density('sine, window 10', 'sin(X)', False, 10);
      Density('fast sine, window 10', 'sin(60 * X)', False, 10);
      Emit('');
      Emit('Headless engine: extrema');
      Peaks('circle in polar', 'sin(T)', True, 2, 2, [Root(0, 1), Root(0, 0)], 1E-2);
      Peaks('parabola', 'X * X', False, 3, 3, [Root(0, 0)]);
      Sharp('shifted parabola', '(X - 0.3719) * (X - 0.3719)', Root(0.3719, 0), 3, 7);
      Sharp('shifted sine', 'sin(X - 0.4)', Root(0.4 + Pi / 2, 1), 3, 7);
      Sharp('shifted cusp', 'sqrt((X - 0.3719) * (X - 0.3719))', Root(0.3719, 0), 3, 7);
      Peaks('sine', 'sin(X)', False, 5, 2,
        [Root(-3 * Pi / 2, 1), Root(Pi / 2, 1), Root(-Pi / 2, -1), Root(3 * Pi / 2, -1)], 3.4E-2);
      Peaks('circle of constant radius', '2', True, 6, 6, []);
      Peaks('same circle with a minus', '0 - 2', True, 6, 6, []);
      Steady('fast sine at two views', 'sin(30 * X)', False, 3, 12, 14);
      HullChecks;
      ParserSwapChecks;
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
