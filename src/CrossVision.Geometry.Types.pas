{ ************************************************************************** }
{                                                                            }
{ CrossVision.Geometry.Types                                                 }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

unit CrossVision.Geometry.Types;

interface

uses
  {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF};

type
  TPointD = record
    X, Y: Double;
  end;

  TPointDArray = TArray<TPointD>;

  TRectD = record
    Left, Top, Right, Bottom: Double;
  end;

  TRectDArray = TArray<TRectD>;

  TRectI = {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF}.TRect;

  TRectOverlapKind = (okNone, okSame, okInside, okInsideTL, okInsideTR, okInsideBR, okInsideBL,
    okInsideL, okInsideT, okInsideR, okInsideB, okInsideH, okInsideV, okInsideLTB, okInsideTLR,
    okInsideRTB, okInsideBLR, okOutside, okOutsideL, okOutsideT, okOutsideR, okOutsideB,
    okTL, okTR, okBR, okBL, okH, okV, okInnerL, okInnerT, okInnerR, okInnerB,
    okOuterL, okOuterT, okOuterR, okOuterB);

  TRectPositionKind = (pkNone, pkL, pkT, pkR, pkB, pkLT, pkTL, pkTR, pkRT, pkRB, pkBR, pkBL, pkLB,
    pkTTLL, pkTTRR, pkBBRR, pkBBLL, pkLTB, pkTLR, pkRTB, pkBLR);

  TPointI = {$IFDEF FPC}Types{$ELSE}System.Types{$ENDIF}.TPoint;
  TPointIArray = TArray<TPointI>;

function PointD(const X, Y: Double): TPointD; inline; overload;
function PointD(const Point: TPointI): TPointD; inline; overload;
function RectD(const Left, Top, Right, Bottom: Double): TRectD; inline;

implementation

function PointD(const X, Y: Double): TPointD;
begin
  Result.X := X;
  Result.Y := Y;
end;

function PointD(const Point: TPointI): TPointD;
begin
  Result.X := Point.X;
  Result.Y := Point.Y;
end;

function RectD(const Left, Top, Right, Bottom: Double): TRectD;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Right := Right;
  Result.Bottom := Bottom;
end;

end.
