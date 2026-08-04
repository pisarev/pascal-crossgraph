{ ************************************************************************** }
{                                                                            }
{ CrossGraph.Geometry                                                        }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit CrossGraph.Geometry;

{$B-}
{$I Directives.inc}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils, Math, Types, CrossVision.Geometry, CrossVision.Geometry.Types;
  {$ELSE}
  System.SysUtils, System.Math, System.Types, CrossVision.Geometry,
  CrossVision.Geometry.Types;
  {$ENDIF}

const
  Angle90 = Pi / 2;
  Angle180 = Pi;
  Angle360 = Pi * 2;
  Angle540 = Pi * 3;

  SlopeInfinity = 1E30;
  SlopeZero = 1E-30;

type
  TQuarterType = (qtA, qtB, qtC, qtD);

function LineSlopeOf(const APoint, BPoint: TPointD): Double;
function DistortSlope(const Slope: Double): Double;
function LineIntercept(const Point: TPointD; const Slope: Double): Double;

function LineAngle(const APoint, BPoint: TPointD): Double;
function VertexAngle(const APoint, BPoint, CPoint: TPointD): Double;
function CounterClockwise(const QuarterType: TQuarterType; const Angle: Double): Double; overload;
function CounterClockwise(const Point: TPointD; const Angle: Double): Double; overload;

function LinesCross(const APoint, BPoint, CPoint, DPoint: TPointD): TPointD;

function SegmentsCross(const APoint, BPoint, CPoint, DPoint: TPointD; out Point: TPointD): Boolean;

function SegmentsGap(const APoint, BPoint, CPoint, DPoint: TPointD; out Point: TPointD): Double;

function NearestOnSegment(const Point, APoint, BPoint: TPointD; out Near: TPointD): Double;

function DistanceOf(const APoint, BPoint: TPointD): Double; inline;
function PointAtAngle(const Point: TPointD; const Angle, Distance: Double): TPointD; inline;

function AreaOf(const Min, Max: TPointD): TRectD; inline;
function Inside(const X, Y: Double; const Area: TRectD): Boolean; inline; overload;
function Inside(const Point: TPointD; const Area: TRectD): Boolean; inline; overload;

implementation

function LineSlopeOf(const APoint, BPoint: TPointD): Double;
begin
  if APoint.X = BPoint.X then Exit(Infinity);
  if APoint.Y = BPoint.Y then Exit(0);
  Result := (APoint.Y - BPoint.Y) / (APoint.X - BPoint.X);
end;

function DistortSlope(const Slope: Double): Double;
begin
  if IsInfinite(Slope) then Exit(SlopeInfinity);
  if Slope = 0 then Exit(SlopeZero);
  Result := Slope;
end;

function LineIntercept(const Point: TPointD; const Slope: Double): Double;
begin
  Result := Point.Y - Slope * Point.X;
end;

function LineAngle(const APoint, BPoint: TPointD): Double;
var
  Slope: Double;
begin
  Slope := LineSlopeOf(APoint, BPoint);
  if IsInfinite(Slope) then Exit(Angle90);
  Result := ArcTan(Slope);
end;

function VertexAngle(const APoint, BPoint, CPoint: TPointD): Double;
begin
  Result := IncludedAngle(APoint, BPoint, CPoint);
end;

function CounterClockwise(const QuarterType: TQuarterType; const Angle: Double): Double;
begin
  case QuarterType of
    qtB, qtC: Result := Pi + Angle;
    qtD: Result := Angle360 + Angle;
  else
    Result := Angle;
  end;
end;

function CounterClockwise(const Point: TPointD; const Angle: Double): Double;
begin
  if Point.X < 0 then Exit(Pi + Angle);
  if Point.Y < 0 then Exit(Angle360 + Angle);
  Result := Angle;
end;

function LinesCross(const APoint, BPoint, CPoint, DPoint: TPointD): TPointD;
var
  ASlope, BSlope, AIntercept, BIntercept: Double;
begin
  ASlope := DistortSlope(LineSlopeOf(APoint, BPoint));
  AIntercept := LineIntercept(APoint, ASlope);
  BSlope := DistortSlope(LineSlopeOf(CPoint, DPoint));
  BIntercept := LineIntercept(CPoint, BSlope);
  Result.X := (BIntercept - AIntercept) / (ASlope - BSlope);
  Result.Y := ASlope * Result.X + AIntercept;
end;

function SegmentsCross(const APoint, BPoint, CPoint, DPoint: TPointD; out Point: TPointD): Boolean;
var
  AVector, BVector: TPointD;
  Denominator, AFactor, BFactor: Double;
begin
  Point.X := 0;
  Point.Y := 0;
  AVector.X := BPoint.X - APoint.X;
  AVector.Y := BPoint.Y - APoint.Y;
  BVector.X := DPoint.X - CPoint.X;
  BVector.Y := DPoint.Y - CPoint.Y;
  Denominator := AVector.X * BVector.Y - AVector.Y * BVector.X;
  Result := Denominator <> 0;
  if not Result then Exit;
  AFactor := ((CPoint.X - APoint.X) * BVector.Y - (CPoint.Y - APoint.Y) * BVector.X) / Denominator;
  BFactor := ((CPoint.X - APoint.X) * AVector.Y - (CPoint.Y - APoint.Y) * AVector.X) / Denominator;
  Result := (AFactor >= 0) and (AFactor <= 1) and (BFactor >= 0) and (BFactor <= 1);
  if Result then
  begin
    Point.X := APoint.X + AFactor * AVector.X;
    Point.Y := APoint.Y + AFactor * AVector.Y;
  end;
end;

function DistanceOf(const APoint, BPoint: TPointD): Double;
begin
  Result := Distance(APoint, BPoint);
end;

function NearestOnSegment(const Point, APoint, BPoint: TPointD; out Near: TPointD): Double;
var
  Vector: TPointD;
  Span, Factor: Double;
begin
  Vector.X := BPoint.X - APoint.X;
  Vector.Y := BPoint.Y - APoint.Y;
  Span := Vector.X * Vector.X + Vector.Y * Vector.Y;
  if Span = 0 then
  begin
    Near := APoint;
    Exit(DistanceOf(Point, APoint));
  end;
  Factor := ((Point.X - APoint.X) * Vector.X + (Point.Y - APoint.Y) * Vector.Y) / Span;
  if Factor < 0 then Factor := 0;
  if Factor > 1 then Factor := 1;
  Near.X := APoint.X + Factor * Vector.X;
  Near.Y := APoint.Y + Factor * Vector.Y;
  Result := DistanceOf(Point, Near);
end;

function SegmentsGap(const APoint, BPoint, CPoint, DPoint: TPointD; out Point: TPointD): Double;

  procedure Take(const Value: Double; const AFrom, ATill: TPointD; var Best: Double; var Middle: TPointD);
  begin
    if Value >= Best then Exit;
    Best := Value;
    Middle.X := (AFrom.X + ATill.X) / 2;
    Middle.Y := (AFrom.Y + ATill.Y) / 2;
  end;

var
  Near: TPointD;
  Value: Double;
begin
  Point := APoint;
  Result := Infinity;
  Value := NearestOnSegment(APoint, CPoint, DPoint, Near);
  Take(Value, APoint, Near, Result, Point);
  Value := NearestOnSegment(BPoint, CPoint, DPoint, Near);
  Take(Value, BPoint, Near, Result, Point);
  Value := NearestOnSegment(CPoint, APoint, BPoint, Near);
  Take(Value, CPoint, Near, Result, Point);
  Value := NearestOnSegment(DPoint, APoint, BPoint, Near);
  Take(Value, DPoint, Near, Result, Point);
end;

function PointAtAngle(const Point: TPointD; const Angle, Distance: Double): TPointD;
begin
  Result := PointAtAngleDistance(Point, Angle, Distance);
end;

function AreaOf(const Min, Max: TPointD): TRectD;
begin
  Result.Left := Min.X;
  Result.Top := Min.Y;
  Result.Right := Max.X;
  Result.Bottom := Max.Y;
end;

function Inside(const X, Y: Double; const Area: TRectD): Boolean;
begin
  Result := (X >= Area.Left) and (X <= Area.Right) and (Y >= Area.Top) and (Y <= Area.Bottom);
end;

function Inside(const Point: TPointD; const Area: TRectD): Boolean;
begin
  Result := Inside(Point.X, Point.Y, Area);
end;

end.
