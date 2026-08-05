{ ************************************************************************** }
{                                                                            }
{ CrossVision.Geometry                                                       }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Geometry;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$MODESWITCH FUNCTIONREFERENCES}
  {$MODESWITCH ANONYMOUSFUNCTIONS}
{$ENDIF}

interface

uses
  CrossVision.Geometry.Types;

function Orient2D(const A, B, C: TPointI): Int64;

function SegmentsIntersect(const A, B, C, D: TPointI): Boolean;

function LinesIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;

function SegmentsIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;

function PointInPolygon(const X, Y: Double; const Polygon: TPointDArray): Boolean; overload;
function PointInPolygon(const Point: TPointD; const Polygon: TPointDArray): Boolean; overload;

function PolygonSignedArea(const Polygon: TPointDArray): Double;
function PolygonArea(const Polygon: TPointDArray): Double;
function PolygonCentroid(const Polygon: TPointDArray): TPointD;
function MeanPoint(const Points: TPointDArray): TPointD;

function ConvexHull(const Points: TPointDArray; const Close: Boolean = False): TPointDArray;

function Distance(const A, B: TPointD): Double;

function LineSlope(const A, B: TPointD): Double;
function LineYIntercept(const P: TPointD; const Slope: Double): Double;
function DirectionAngle(const A, B: TPointD): Double;
function IncludedAngle(const P1, Vertex, P2: TPointD): Double;
function WrapAngle360(const Angle: Double): Double;
function WrapAngle180(const Angle: Double): Double;
function AngularDifference(const A, B: Double): Double;
function CircularMean(const Angles: TArray<Double>): Double;
function PointAtAngleDistance(const P: TPointD; const Angle, Dist: Double): TPointD;

function PointSideOfLine(const P, A, B: TPointD): Integer;
function PointOnSegment(const P, A, B: TPointD; const Epsilon: Double = 1e-9): Boolean;
function SegmentsCollinear(const A, B, C, D: TPointD; const Epsilon: Double = 1e-9): Boolean;
function CollinearOverlapLength(const A, B, C, D: TPointD): Double;

function RotatePoints(const Points: TPointDArray; const Angle: Double; const Center: TPointD): TPointDArray;
function BoundingBox(const Points: TPointDArray): TRectD;
function NearestPoint(const FromPoint: TPointD; const Points: TPointDArray; out Index: Integer): Boolean;

function NormalizeRect(const R: TRectD): TRectD;
function RectWidth(const R: TRectD): Double;
function RectHeight(const R: TRectD): Double;
function RectArea(const R: TRectD): Double;
function RectIsEmpty(const R: TRectD): Boolean;
function RectCenter(const R: TRectD): TPointD;
function RectToPolygon(const R: TRectD): TPointDArray;
function RectsIntersect(const A, B: TRectD): Boolean;
function RectIntersection(const A, B: TRectD; out R: TRectD): Boolean;
function RectUnion(const A, B: TRectD): TRectD; overload;
function RectUnion(const Rects: TRectDArray): TRectD; overload;
function RectIoU(const A, B: TRectD): Double;
function RectGap(const A, B: TRectD): Double;
function RectsApproxEqual(const A, B: TRectD; const Tolerance: Double): Boolean;
function RectsCloserThan(const A, B: TRectD; const MaxGap: Double): Boolean;
function MergeNearbyRects(const Rects: TRectDArray; const MaxGap: Double): TRectDArray;

function RotateRectCorners(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TPointDArray; overload;
function RotateRectCorners(const R: TRectD; const Skew: Double): TPointDArray; overload;
function RotatedRectBounds(const R: TRectD; const Skew: Double): TRectD; overload;
function RotatedRectBounds(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TRectD; overload;

function ClassifyRectOverlap(const First, Second: TRectI): TRectOverlapKind;
function ClassifyRectPosition(const First, Second: TRectI): TRectPositionKind;

implementation

uses
  {$IFDEF FPC}
  Types, Math, Generics.Collections, Generics.Defaults;
  {$ELSE}
  System.Types, System.Math, System.Generics.Collections, System.Generics.Defaults;
  {$ENDIF}

const
  GeometryEpsilon = 1e-12;
  TwoPi = 2 * Pi;

function Orient2D(const A, B, C: TPointI): Int64;
begin
  Result := Int64(B.X - A.X) * Int64(C.Y - A.Y) - Int64(B.Y - A.Y) * Int64(C.X - A.X);
end;

function OnBox(const A, B, P: TPointI): Boolean;
begin
  Result := (P.X >= Min(A.X, B.X)) and (P.X <= Max(A.X, B.X)) and (P.Y >= Min(A.Y, B.Y)) and
    (P.Y <= Max(A.Y, B.Y));
end;

function SegmentsIntersect(const A, B, C, D: TPointI): Boolean;
var
  O1, O2, O3, O4: Int64;
begin
  O1 := Orient2D(A, B, C);
  O2 := Orient2D(A, B, D);
  O3 := Orient2D(C, D, A);
  O4 := Orient2D(C, D, B);
  if (((O1 > 0) and (O2 < 0)) or ((O1 < 0) and (O2 > 0))) and (((O3 > 0) and (O4 < 0)) or ((O3 < 0) and
    (O4 > 0))) then
      Exit(True);
  if (O1 = 0) and OnBox(A, B, C) then Exit(True);
  if (O2 = 0) and OnBox(A, B, D) then Exit(True);
  if (O3 = 0) and OnBox(C, D, A) then Exit(True);
  if (O4 = 0) and OnBox(C, D, B) then Exit(True);
  Result := False;
end;

function CrossD(const AX, AY, BX, BY: Double): Double; inline;
begin
  Result := AX * BY - AY * BX;
end;

function LinesIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;
var
  RX, RY, SX, SY, Denom, T: Double;
begin
  Point := PointD(0, 0);
  RX := B.X - A.X;
  RY := B.Y - A.Y;
  SX := D.X - C.X;
  SY := D.Y - C.Y;
  Denom := CrossD(RX, RY, SX, SY);
  if Abs(Denom) < GeometryEpsilon then Exit(False);
  T := CrossD(C.X - A.X, C.Y - A.Y, SX, SY) / Denom;
  Point := PointD(A.X + T * RX, A.Y + T * RY);
  Result := True;
end;

function SegmentsIntersectionPoint(const A, B, C, D: TPointD; out Point: TPointD): Boolean;
var
  RX, RY, SX, SY, Denom, T, U: Double;
begin
  Point := PointD(0, 0);
  RX := B.X - A.X;
  RY := B.Y - A.Y;
  SX := D.X - C.X;
  SY := D.Y - C.Y;
  Denom := CrossD(RX, RY, SX, SY);
  if Abs(Denom) < GeometryEpsilon then Exit(False);
  T := CrossD(C.X - A.X, C.Y - A.Y, SX, SY) / Denom;
  U := CrossD(C.X - A.X, C.Y - A.Y, RX, RY) / Denom;
  if (T < 0) or (T > 1) or (U < 0) or (U > 1) then Exit(False);
  Point := PointD(A.X + T * RX, A.Y + T * RY);
  Result := True;
end;

function PointInPolygon(const X, Y: Double; const Polygon: TPointDArray): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  if Length(Polygon) < 3 then Exit;
  J := High(Polygon);
  for I := Low(Polygon) to High(Polygon) do
  begin
    if (((Polygon[I].Y < Y) and (Polygon[J].Y >= Y)) or ((Polygon[J].Y < Y) and (Polygon[I].Y >= Y))) and
      (Polygon[I].X + (Y - Polygon[I].Y) / (Polygon[J].Y - Polygon[I].Y) * (Polygon[J].X - Polygon[I].X) > X) then
        Result := not Result;
    J := I;
  end;
end;

function PointInPolygon(const Point: TPointD; const Polygon: TPointDArray): Boolean;
begin
  Result := PointInPolygon(Point.X, Point.Y, Polygon);
end;

function PolygonSignedArea(const Polygon: TPointDArray): Double;
var
  I, K, N: Integer;
  S: Double;
begin
  N := Length(Polygon);
  if N < 3 then Exit(0);
  S := 0;
  for I := 0 to N - 1 do
  begin
    K := (I + 1) mod N;
    S := S + (Polygon[I].X * Polygon[K].Y) - (Polygon[K].X * Polygon[I].Y);
  end;
  Result := S * 0.5;
end;

function PolygonArea(const Polygon: TPointDArray): Double;
begin
  Result := Abs(PolygonSignedArea(Polygon));
end;

function MeanPoint(const Points: TPointDArray): TPointD;
var
  I: Integer;
  X, Y: Double;
begin
  Result := PointD(0, 0);
  if Length(Points) = 0 then Exit;
  X := 0;
  Y := 0;
  for I := Low(Points) to High(Points) do
  begin
    X := X + Points[I].X;
    Y := Y + Points[I].Y;
  end;
  Result := PointD(X / Length(Points), Y / Length(Points));
end;

function PolygonCentroid(const Polygon: TPointDArray): TPointD;
var
  I, K, N: Integer;
  Area, Factor, X, Y: Double;
begin
  N := Length(Polygon);
  if N < 3 then Exit(MeanPoint(Polygon));
  Area := 0;
  X := 0;
  Y := 0;
  for I := 0 to N - 1 do
  begin
    K := (I + 1) mod N;
    Factor := (Polygon[I].X * Polygon[K].Y) - (Polygon[K].X * Polygon[I].Y);
    X := X + (Polygon[I].X + Polygon[K].X) * Factor;
    Y := Y + (Polygon[I].Y + Polygon[K].Y) * Factor;
    Area := Area + Factor;
  end;
  Area := Area * 0.5;
  if Area = 0 then Exit(MeanPoint(Polygon));
  Result := PointD(X / (Area * 6), Y / (Area * 6));
end;

function ConvexHull(const Points: TPointDArray; const Close: Boolean): TPointDArray;
var
  Sorted: TPointDArray;
  I, N, K, L: Integer;

  function Turn(const O, P, Q: TPointD): Double; inline;
  begin
    Result := (P.X - O.X) * (Q.Y - O.Y) - (P.Y - O.Y) * (Q.X - O.X);
  end;

begin
  N := Length(Points);
  if N < 4 then Exit(Copy(Points));
  Sorted := Copy(Points);
  {$IFDEF FPC}TArrayHelper<TPointD>.Sort{$ELSE}TArray.Sort<TPointD>{$ENDIF}(Sorted, TComparer<TPointD>.Construct(
    function(const A, B: TPointD): Integer
    begin
      if A.X < B.X then
        Result := -1
      else if A.X > B.X then
        Result := 1
      else if A.Y < B.Y then
        Result := -1
      else if A.Y > B.Y then
        Result := 1
      else
        Result := 0;
    end));
  SetLength(Result, N * 2);
  K := 0;
  for I := 0 to N - 1 do
  begin
    while (K >= 2) and (Turn(Result[K - 2], Result[K - 1], Sorted[I]) <= 0) do
      Dec(K);
    Result[K] := Sorted[I];
    Inc(K);
  end;
  L := K + 1;
  for I := N - 2 downto 0 do
  begin
    while (K >= L) and (Turn(Result[K - 2], Result[K - 1], Sorted[I]) <= 0) do
      Dec(K);
    Result[K] := Sorted[I];
    Inc(K);
  end;
  if Close then
  begin
    SetLength(Result, K);
    Result[K - 1] := Result[0];
  end
  else
    SetLength(Result, K - 1);
end;

function Distance(const A, B: TPointD): Double;
begin
  if A.X = B.X then Exit(Abs(A.Y - B.Y));
  if A.Y = B.Y then Exit(Abs(A.X - B.X));
  Result := Sqrt(Sqr(A.X - B.X) + Sqr(A.Y - B.Y));
end;

function LineSlope(const A, B: TPointD): Double;
begin
  if A.X = B.X then Exit(Infinity);
  Result := (B.Y - A.Y) / (B.X - A.X);
end;

function LineYIntercept(const P: TPointD; const Slope: Double): Double;
begin
  Result := P.Y - Slope * P.X;
end;

function WrapAngle360(const Angle: Double): Double;
begin
  Result := Angle - Floor(Angle / TwoPi) * TwoPi;
end;

function WrapAngle180(const Angle: Double): Double;
begin
  Result := Angle - Floor(Angle / Pi) * Pi;
end;

function DirectionAngle(const A, B: TPointD): Double;
begin
  Result := WrapAngle360(ArcTan2(B.Y - A.Y, B.X - A.X));
end;

function IncludedAngle(const P1, Vertex, P2: TPointD): Double;
var
  A, B, C, Cosine: Double;
begin
  A := Distance(Vertex, P1);
  B := Distance(Vertex, P2);
  if (A < GeometryEpsilon) or (B < GeometryEpsilon) then Exit(0);
  C := Distance(P1, P2);
  Cosine := EnsureRange((Sqr(A) + Sqr(B) - Sqr(C)) / (2 * A * B), -1, 1);
  Result := ArcCos(Cosine);
end;

function AngularDifference(const A, B: Double): Double;
begin
  Result := WrapAngle360(A - B);
  if Result > Pi then Result := TwoPi - Result;
end;

function CircularMean(const Angles: TArray<Double>): Double;
var
  I: Integer;
  S, C: Double;
begin
  S := 0;
  C := 0;
  for I := Low(Angles) to High(Angles) do
  begin
    S := S + Sin(Angles[I]);
    C := C + Cos(Angles[I]);
  end;
  Result := WrapAngle360(ArcTan2(S, C));
end;

function PointAtAngleDistance(const P: TPointD; const Angle, Dist: Double): TPointD;
begin
  Result := PointD(P.X + Dist * Cos(Angle), P.Y + Dist * Sin(Angle));
end;

function PointSideOfLine(const P, A, B: TPointD): Integer;
begin
  Result := Sign((B.X - A.X) * (P.Y - A.Y) - (B.Y - A.Y) * (P.X - A.X));
end;

function PointOnSegment(const P, A, B: TPointD; const Epsilon: Double): Boolean;
begin
  if Abs((B.X - A.X) * (P.Y - A.Y) - (B.Y - A.Y) * (P.X - A.X)) > Epsilon then
    Exit(False);
  Result := (P.X >= Min(A.X, B.X) - Epsilon) and (P.X <= Max(A.X, B.X) + Epsilon) and
    (P.Y >= Min(A.Y, B.Y) - Epsilon) and (P.Y <= Max(A.Y, B.Y) + Epsilon);
end;

function SegmentsCollinear(const A, B, C, D: TPointD; const Epsilon: Double): Boolean;
begin
  Result := (Abs((B.X - A.X) * (C.Y - A.Y) - (B.Y - A.Y) * (C.X - A.X)) <= Epsilon) and
    (Abs((B.X - A.X) * (D.Y - A.Y) - (B.Y - A.Y) * (D.X - A.X)) <= Epsilon);
end;

function CollinearOverlapLength(const A, B, C, D: TPointD): Double;
var
  DX, DY, L2, TC, TD, OverlapMin, OverlapMax: Double;
begin
  Result := 0;
  if not SegmentsCollinear(A, B, C, D) then Exit;
  DX := B.X - A.X;
  DY := B.Y - A.Y;
  L2 := DX * DX + DY * DY;
  if L2 < GeometryEpsilon then Exit;
  TC := ((C.X - A.X) * DX + (C.Y - A.Y) * DY) / L2;
  TD := ((D.X - A.X) * DX + (D.Y - A.Y) * DY) / L2;
  OverlapMin := Max(0.0, Min(TC, TD));
  OverlapMax := Min(1.0, Max(TC, TD));
  if OverlapMax < OverlapMin then Exit;
  Result := (OverlapMax - OverlapMin) * Sqrt(L2);
end;

function RotatePoints(const Points: TPointDArray; const Angle: Double; const Center: TPointD): TPointDArray;
var
  I: Integer;
  S, C, DX, DY: Double;
begin
  S := Sin(Angle);
  C := Cos(Angle);
  SetLength(Result, Length(Points));
  for I := Low(Points) to High(Points) do
  begin
    DX := Points[I].X - Center.X;
    DY := Points[I].Y - Center.Y;
    Result[I] := PointD(Center.X + DX * C - DY * S, Center.Y + DX * S + DY * C);
  end;
end;

function BoundingBox(const Points: TPointDArray): TRectD;
var
  I: Integer;
begin
  if Length(Points) = 0 then Exit(RectD(0, 0, 0, 0));
  Result := RectD(Points[0].X, Points[0].Y, Points[0].X, Points[0].Y);
  for I := 1 to High(Points) do
  begin
    if Points[I].X < Result.Left then Result.Left := Points[I].X;
    if Points[I].X > Result.Right then Result.Right := Points[I].X;
    if Points[I].Y < Result.Top then Result.Top := Points[I].Y;
    if Points[I].Y > Result.Bottom then Result.Bottom := Points[I].Y;
  end;
end;

function NearestPoint(const FromPoint: TPointD; const Points: TPointDArray; out Index: Integer): Boolean;
var
  I: Integer;
  Best, D: Double;
begin
  Index := -1;
  if Length(Points) = 0 then Exit(False);
  Best := MaxDouble;
  for I := Low(Points) to High(Points) do
  begin
    D := Distance(FromPoint, Points[I]);
    if D < Best then
    begin
      Best := D;
      Index := I;
    end;
  end;
  Result := Index >= 0;
end;

function NormalizeRect(const R: TRectD): TRectD;
begin
  Result.Left := Min(R.Left, R.Right);
  Result.Right := Max(R.Left, R.Right);
  Result.Top := Min(R.Top, R.Bottom);
  Result.Bottom := Max(R.Top, R.Bottom);
end;

function RectWidth(const R: TRectD): Double;
begin
  Result := R.Right - R.Left;
end;

function RectHeight(const R: TRectD): Double;
begin
  Result := R.Bottom - R.Top;
end;

function RectArea(const R: TRectD): Double;
begin
  Result := Max(0, R.Right - R.Left) * Max(0, R.Bottom - R.Top);
end;

function RectIsEmpty(const R: TRectD): Boolean;
begin
  Result := (R.Right <= R.Left) or (R.Bottom <= R.Top);
end;

function RectCenter(const R: TRectD): TPointD;
begin
  Result := PointD((R.Left + R.Right) / 2, (R.Top + R.Bottom) / 2);
end;

function RectToPolygon(const R: TRectD): TPointDArray;
begin
  Result := [PointD(R.Left, R.Top), PointD(R.Right, R.Top), PointD(R.Right, R.Bottom), PointD(R.Left, R.Bottom)];
end;

function RectsIntersect(const A, B: TRectD): Boolean;
begin
  Result := (A.Left < B.Right) and (B.Left < A.Right) and (A.Top < B.Bottom) and (B.Top < A.Bottom);
end;

function RectIntersection(const A, B: TRectD; out R: TRectD): Boolean;
begin
  R.Left := Max(A.Left, B.Left);
  R.Top := Max(A.Top, B.Top);
  R.Right := Min(A.Right, B.Right);
  R.Bottom := Min(A.Bottom, B.Bottom);
  Result := (R.Right > R.Left) and (R.Bottom > R.Top);
  if not Result then R := RectD(0, 0, 0, 0);
end;

function RectUnion(const A, B: TRectD): TRectD;
begin
  Result := RectD(Min(A.Left, B.Left), Min(A.Top, B.Top), Max(A.Right, B.Right), Max(A.Bottom, B.Bottom));
end;

function RectUnion(const Rects: TRectDArray): TRectD;
var
  I: Integer;
begin
  if Length(Rects) = 0 then Exit(RectD(0, 0, 0, 0));
  Result := Rects[0];
  for I := 1 to High(Rects) do
    Result := RectUnion(Result, Rects[I]);
end;

function RectIoU(const A, B: TRectD): Double;
var
  R: TRectD;
  Inter, Union: Double;
begin
  if not RectIntersection(A, B, R) then Exit(0);
  Inter := RectArea(R);
  Union := RectArea(A) + RectArea(B) - Inter;
  if Union <= GeometryEpsilon then Exit(0);
  Result := Inter / Union;
end;

function RectGap(const A, B: TRectD): Double;
var
  DX, DY: Double;
begin
  DX := Max(0, Max(A.Left - B.Right, B.Left - A.Right));
  DY := Max(0, Max(A.Top - B.Bottom, B.Top - A.Bottom));
  Result := Sqrt(DX * DX + DY * DY);
end;

function RectsApproxEqual(const A, B: TRectD; const Tolerance: Double): Boolean;
begin
  Result := (Abs(A.Left - B.Left) <= Tolerance) and (Abs(A.Top - B.Top) <= Tolerance) and
    (Abs(A.Right - B.Right) <= Tolerance) and (Abs(A.Bottom - B.Bottom) <= Tolerance);
end;

function RectsCloserThan(const A, B: TRectD; const MaxGap: Double): Boolean;
begin
  Result := RectGap(A, B) <= MaxGap;
end;

function MergeNearbyRects(const Rects: TRectDArray; const MaxGap: Double): TRectDArray;
var
  Work: TRectDArray;
  I, J, N: Integer;
  Merged: Boolean;
begin
  Work := Copy(Rects);
  N := Length(Work);
  Merged := True;
  while Merged do
  begin
    Merged := False;
    I := 0;
    while I < N do
    begin
      J := I + 1;
      while J < N do
        if RectGap(Work[I], Work[J]) <= MaxGap then
        begin
          Work[I] := RectUnion(Work[I], Work[J]);
          Work[J] := Work[N - 1];
          Dec(N);
          Merged := True;
        end
        else
          Inc(J);
      Inc(I);
    end;
  end;
  SetLength(Work, N);
  Result := Work;
end;

function RotateRectCorners(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TPointDArray;
var
  Corners: TPointDArray;
  I: Integer;
  Ang, Dist: Double;
begin
  SetLength(Corners, 4);
  Corners[0] := PointD(R.Left, R.Top);
  Corners[1] := PointD(R.Right, R.Top);
  Corners[2] := PointD(R.Right, R.Bottom);
  Corners[3] := PointD(R.Left, R.Bottom);
  SetLength(Result, 4);
  for I := 0 to 3 do
  begin
    Ang := DirectionAngle(SourceCenter, Corners[I]);
    Dist := Distance(SourceCenter, Corners[I]);
    Result[I] := PointAtAngleDistance(TargetCenter, Ang - Skew, Dist);
  end;
end;

function RotateRectCorners(const R: TRectD; const Skew: Double): TPointDArray;
var
  Center: TPointD;
begin
  Center := RectCenter(R);
  Result := RotateRectCorners(R, Skew, Center, Center);
end;

function RotatedRectBounds(const R: TRectD; const Skew: Double): TRectD;
begin
  Result := BoundingBox(RotateRectCorners(R, Skew));
end;

function RotatedRectBounds(const R: TRectD; const Skew: Double;
  const SourceCenter, TargetCenter: TPointD): TRectD;
begin
  Result := BoundingBox(RotateRectCorners(R, Skew, SourceCenter, TargetCenter));
end;

function ClassifyRectOverlap(const First, Second: TRectI): TRectOverlapKind;
var
  A, B: TRectI;
  AA, AB, AD, BA, BB, BD: TPointI;
begin
  A := First;
  A.NormalizeRect;
  B := Second;
  B.NormalizeRect;
  if (A.Left = B.Left) and (A.Top = B.Top) and (A.Right = B.Right) and (A.Bottom = B.Bottom) then
    Exit(okSame);
  AA := Point(A.Left, A.Top);
  AB := Point(A.Right, A.Top);
  AD := Point(A.Left, A.Bottom);
  BA := Point(B.Left, B.Top);
  BB := Point(B.Right, B.Top);
  BD := Point(B.Left, B.Bottom);
  if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
    Result := okInside
  else if (BA.X = AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideTL
  else if (BA.X = AA.X) and (BB.X < AB.X) and (BD.Y = AD.Y) and (BA.Y > AA.Y) then
    Result := okInsideBL
  else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideTR
  else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y = AD.Y) then
    Result := okInsideBR
  else if (BA.X = AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideL
  else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideT
  else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideR
  else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y = AD.Y) then
    Result := okInsideB
  else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y = AD.Y) then
    Result := okInsideV
  else if (BA.X = AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideH
  else if (BA.X = AA.X) and (BB.X = AB.X) and (BA.Y = AA.Y) and (BD.Y < AD.Y) then
    Result := okInsideTLR
  else if (BA.X = AA.X) and (BB.X < AB.X) and (BA.Y = AA.Y) and (BD.Y = AD.Y) then
    Result := okInsideLTB
  else if (BA.X > AA.X) and (BB.X = AB.X) and (BA.Y = AA.Y) and (BD.Y = AD.Y) then
    Result := okInsideRTB
  else if (BA.X = AA.X) and (BB.X = AB.X) and (BA.Y > AA.Y) and (BD.Y = AD.Y) then
    Result := okInsideBLR
  else if (BA.X < AA.X) and (BB.X > AB.X) and (BA.Y < AA.Y) and (BD.Y > AD.Y) then
    Result := okOutside
  else if BB.X = AA.X then
    Result := okOutsideL
  else if BD.Y = AA.Y then
    Result := okOutsideL
  else if BA.X = AB.X then
    Result := okOutsideT
  else if BA.Y = AD.Y then
    Result := okOutsideB
  else if (BA.X < AA.X) and (BB.X > AA.X) and (BB.X < AB.X) and (BD.Y > AA.Y) and (BD.Y < AD.Y) and
    (BA.Y < AA.Y) then
      Result := okTL
  else if (BA.X > AA.X) and (BA.X < AB.X) and (BB.X > AB.X) and (BD.Y > AA.Y) and (BD.Y < AD.Y) and
    (BA.Y < AA.Y) then
      Result := okTR
  else if (BA.X > AA.X) and (BA.X < AB.X) and (BB.X > AB.X) and (BA.Y > AA.Y) and (BA.Y < AD.Y) and
    (BD.Y > AD.Y) then
      Result := okBR
  else if (BB.X > AA.X) and (BB.X < AB.X) and (BA.X < AA.X) and (BA.Y > AA.Y) and (BA.Y < AD.Y) and
    (BD.Y > AD.Y) then
      Result := okBL
  else if (BA.X < AA.X) and (BB.X > AB.X) and (BA.Y >= AA.Y) and (BD.Y <= AD.Y) then
    Result := okH
  else if (BA.X >= AA.X) and (BB.X <= AB.X) and (BA.Y < AA.Y) and (BD.Y > AD.Y) then
    Result := okV
  else if (BB.X > AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) and (BA.X < AA.X) then
    Result := okInnerL
  else if (BA.X > AA.X) and (BB.X < AB.X) and (BD.Y > AA.Y) and (BD.Y < AD.Y) and (BA.Y < AA.Y) then
    Result := okInnerT
  else if (BA.X > AA.X) and (BA.X < AB.X) and (BA.Y > AA.Y) and (BD.Y < AD.Y) and (BB.X > AB.X) then
    Result := okInnerR
  else if (BA.X > AA.X) and (BB.X < AB.X) and (BA.Y > AA.Y) and (BA.Y < AD.Y) and (BD.Y > AD.Y) then
    Result := okInnerB
  else if (BA.Y < AA.Y) and (BD.Y > AD.Y) and (BB.X > AA.X) and (BB.X < AB.X) and (BA.X < AA.X) then
    Result := okOuterL
  else if (BA.X < AA.X) and (BB.X > AB.X) and (BD.Y > AA.Y) and (BD.Y < AD.Y) and (BA.Y < AA.Y) then
    Result := okOuterT
  else if (BA.Y < AA.Y) and (BD.Y > AD.Y) and (BA.X > AA.X) and (BA.X < AB.X) and (BB.X > AB.X) then
    Result := okOuterR
  else if (BA.X < AA.X) and (BB.X > AB.X) and (BA.Y > AA.Y) and (BA.Y < AD.Y) and (BD.Y > AD.Y) then
    Result := okOuterB
  else
    Result := okNone;
end;

function ClassifyRectPosition(const First, Second: TRectI): TRectPositionKind;
var
  A, B: TRectI;
  AA, AB, AD, BA, BB, BD: TPointI;
begin
  A := First;
  A.NormalizeRect;
  B := Second;
  B.NormalizeRect;
  AA := Point(A.Left, A.Top);
  AB := Point(A.Right, A.Top);
  AD := Point(A.Left, A.Bottom);
  BA := Point(B.Left, B.Top);
  BB := Point(B.Right, B.Top);
  BD := Point(B.Left, B.Bottom);
  if (BA.X >= AA.X) and (BB.X <= AB.X) then
  begin
    if AD.Y < BA.Y then
      Result := pkB
    else if AA.Y > BD.Y then
      Result := pkT
    else
      Result := pkNone;
  end
  else if (BA.Y >= AA.Y) and (BD.Y <= AD.Y) then
  begin
    if AB.X < BA.X then
      Result := pkR
    else if AA.X > BB.X then
      Result := pkL
    else
      Result := pkNone;
  end
  else if (AA.X >= BA.X) and (AB.X <= BB.X) then
  begin
    if AD.Y < BA.Y then
      Result := pkBLR
    else if AA.Y > BD.Y then
      Result := pkTLR
    else
      Result := pkNone;
  end
  else if (AA.X >= BA.X) and (AA.X <= BB.X) then
  begin
    if AD.Y < BA.Y then
      Result := pkBL
    else if AA.Y > BD.Y then
      Result := pkTL
    else
      Result := pkNone;
  end
  else if (AB.X >= BA.X) and (AB.X <= BB.X) then
  begin
    if AD.Y < BA.Y then
      Result := pkBR
    else if AA.Y > BD.Y then
      Result := pkTR
    else
      Result := pkNone;
  end
  else if (AA.Y >= BA.Y) and (AD.Y <= BD.Y) then
  begin
    if AB.X < BA.X then
      Result := pkRTB
    else if AA.X > BB.X then
      Result := pkLTB
    else
      Result := pkNone;
  end
  else if (AA.Y >= BA.Y) and (AA.Y <= BD.Y) then
  begin
    if AB.X < BA.X then
      Result := pkRT
    else if AA.X > BB.X then
      Result := pkLT
    else
      Result := pkNone;
  end
  else if (AD.Y >= BA.Y) and (AD.Y <= BD.Y) then
  begin
    if AB.X < BA.X then
      Result := pkRB
    else if AA.X > BB.X then
      Result := pkLB
    else
      Result := pkNone;
  end
  else if (AA.X > BB.X) and (AA.Y > BD.Y) then
    Result := pkTTLL
  else if (AB.X < BA.X) and (AA.Y > BD.Y) then
    Result := pkTTRR
  else if (AB.X < BA.X) and (AD.Y < BA.Y) then
    Result := pkBBRR
  else if (AA.X > BB.X) and (AD.Y < BA.Y) then
    Result := pkBBLL
  else
    Result := pkNone;
end;

end.
