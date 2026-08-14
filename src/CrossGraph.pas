{ ************************************************************************** }
{                                                                            }
{ CrossGraph                                                                 }
{                                                                            }
{ Copyright © 2006 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit CrossGraph;

{$B-}
{$I Directives.inc}

interface

uses
  {$IFDEF FPC}
  LCLIntf, LCLType, LMessages, SysUtils, Classes, extctrls, Contnrs, Controls, Graphics,
  BaseTypes, ExactTimer, FastList, CrossGraph.Types, CrossGraph.Geometry, CrossGraph.Engine,
  CrossVision.Geometry, CrossVision.Geometry.Types, TextConsts, Numeration, NumberUtils,
  Parser, ParseTypes, Thread, Types, ValueTypes;
  {$ELSE}
  {$IFDEF DELPHI_XE7}
  WinApi.Windows, Winapi.Messages, Winapi.GDIPOBJ, Winapi.GDIPAPI, System.SysUtils,
  System.Classes, System.Contnrs, Vcl.Controls, Vcl.Graphics, BaseTypes, ExactTimer,
  FastList, CrossGraph.Types, CrossGraph.Geometry, CrossGraph.Engine, CrossVision.Geometry,
  CrossVision.Geometry.Types, TextConsts, Numeration, NumberUtils, Parser, ParseTypes,
  Thread, Types, ValueTypes;
  {$ELSE}
  Windows, Messages, GDIPOBJ, GDIPAPI, SysUtils, Classes, Contnrs, Controls, Graphics,
  BaseTypes, ExactTimer, FastList, CrossGraph.Types, CrossGraph.Geometry, CrossGraph.Engine,
  CrossVision.Geometry, CrossVision.Geometry.Types, TextConsts, Numeration, NumberUtils,
  Parser, ParseTypes, Thread, Types, ValueTypes;
  {$ENDIF}
  {$ENDIF}

{$IFDEF FPC}
type
  TMessage = TLMessage;
  TWMSetCursor = TLMSetCursor;

const
  WM_SETCURSOR = LM_SETCURSOR;
  WM_MOUSEMOVE = LM_MOUSEMOVE;
{$ENDIF}

type
  TColorType = (ctB, ctG, ctR, ctA);
  TPixel = array[TColorType] of Byte;
  PPixel = ^TPixel;

  TRectangularTraceEvent = procedure(Sender: TObject; const FormulaIndex: Integer;
    const Point: TPointD) of object;
  TPolarTraceEvent = procedure(Sender: TObject; const FormulaIndex: Integer; const Angle: array of Extended;
    const Point: array of TPointD) of object;

  TLayoutType = (ltBottomLeft, ltBottomRight, ltTopLeft, ltTopRight);

const
  DefaultFormat = pf24bit;
  ByteCount: array[TPixelFormat] of Byte = (0, 1, 1, 1, 2, 2, 3, 4, 0);
  DefaultThreadWorkTime = 5000;
  MaxOverlapQueue = 256;
  DefaultAutoVary = True;
  DefaultAutoVoid = True;
  DefaultAccuracy = 1;
  DefaultHighPrecision = False;
  DefaultPrecisionFormat = '0.#########';
  DefaultAntialias = True;
  DefaultAutoquality = True;
  DefaultHeight = 300;
  DefaultMulticolor = True;
  DefaultWidth = 300;
  DefaultQuality = 1;
  DefaultTracing = True;
  DefaultOverlap = True;
  DefaultExtreme = True;
  DefaultCS = csRectangular;
  DefaultSign = True;
  DefaultSignBlendValue = 100;
  DefaultSignLayout = ltBottomRight;
  DefaultSignMargin = 16;
  DefaultTextBackground = clBlack;
  DefaultTextBlendValue = 100;
  DefaultTextLayout = ltTopLeft;
  DefaultTextMargin = 16;

type
  {$IFNDEF DELPHI_2006}
  TBitmap = class(Graphics.TBitmap)
  public
    procedure SetSize(const AWidth, AHeight: Integer); overload; virtual;
    procedure SetSize(const Size: TSize); overload; virtual;
  end;
  {$ENDIF}

  TZoomType = (ztNone, ztIn, ztOut);

  TGraph = class;

  TZoomTimer = class(TExactTimer)
  private
    FZoomType: TZoomType;
  public
    property ZoomType: TZoomType read FZoomType write FZoomType;
  end;

  TGraph = class(TCustomControl)
  private
    FAccuracy: Integer;
    FAfterParse: TNotifyEvent;
    FAngleDigitCount: Integer;
    FAngleFormat: string;
    FAntialias: Boolean;
    FAutoVary: Boolean;
    FAutoVoid: Boolean;
    FAxisArrow: TSize;
    FAxisFont: TFont;
    FAxisPen: TPen;
    FBeforeParse: TNotifyEvent;
    FBuffer: TBitmap;
    FBuildTimer: TExactTimer;
    FSilent: Boolean;
    FColorArray: TColorArray;
    FCursorArray: TCurveIArray;
    FCursorValue: TValue;
    FEngine: TGraphEngine;
    FNumeration: TNumeration;
    FFormulaFont: TFont;
    FGraphPen: TPen;
    FGridPen: TPen;
    FHSpacing: Extended;
    FLeadTimer: TExactTimer;
    FMarkerPen: TPen;
    FMaxZoom: array[TCoordinateSystem] of Extended;
    FMinZoom: array[TCoordinateSystem] of Extended;
    FMoving: Boolean;
    FMulticolor: Boolean;
    FOnExtreme: TNotifyEvent;
    FOnOffsetChange: TNotifyEvent;
    FOnOverlap: TNotifyEvent;
    FOnPolarTrace: TPolarTraceEvent;
    FOnRectangularTrace: TRectangularTraceEvent;
    FOnTraceDone: TNotifyEvent;
    FOverlapNameNumeration: Integer;
    FPivotPoint: TPointD;
    FPolarAxisPen: TPen;
    FPrecisionFormat: string;
    FShowAxis: Boolean;
    FShowGrid: Boolean;
    FSign: Boolean;
    FSignBlendValue: Byte;
    FSignFont: TFont;
    FSignLayout: TLayoutType;
    FSignMargin: Integer;
    FSize: TSize;
    FTextBackground: TColor;
    FTextBlendValue: Byte;
    FTextFont: TFont;
    FTextLayout: TLayoutType;
    FTextMargin: Integer;
    FTraceArray: TCurveIArray;
    FTracePen: TPen;
    FTracing: Boolean;
    FVSpacing: Extended;
    FXDigitCount: Integer;
    FXFactor: Extended;
    FXFormat: string;
    FXYFormat: string;
    FYDigitCount: Integer;
    FYFactor: Extended;
    FYFormat: string;
    FZoomInFactor: Extended;
    FZoomOutFactor: Extended;
    FZoomTimer: TZoomTimer;
    function GetBusy: Boolean;
    function GetAutoquality: Boolean;
    procedure SetAutoquality(const Value: Boolean);
    function GetCS: TCoordinateSystem;
    function GetCenter: TPointD;
    function GetEntireArray: TCurveDArray;
    procedure SetEntireArray(const Value: TCurveDArray);
    function GetEpsilon: Extended;
    function GetErrorMessage: string;
    procedure SetErrorMessage(const Value: string);
    function GetExtreme: Boolean;
    function GetExtremeVaryRadius: Extended;
    procedure SetExtremeVaryRadius(const Value: Extended);
    function GetExtremeVoidRadius: Extended;
    procedure SetExtremeVoidRadius(const Value: Extended);
    function GetFormula: TFormulaList;
    function GetHighPrecision: Boolean;
    function GetJitEnabled: Boolean;
    procedure SetJitEnabled(const Value: Boolean);
    function GetMax: TPointD;
    function GetMaxArray: TCurveDArray;
    procedure SetMaxArray(const Value: TCurveDArray);
    function GetMaxX: Extended;
    procedure SetMaxX(const Value: Extended);
    function GetMaxY: Extended;
    procedure SetMaxY(const Value: Extended);
    function GetMin: TPointD;
    function GetMinArray: TCurveDArray;
    procedure SetMinArray(const Value: TCurveDArray);
    function GetOffset: TPointD;
    function GetOverlap: Boolean;
    function GetOverlapArray: TOverlapArray;
    procedure SetOverlapArray(const Value: TOverlapArray);
    function GetParser: TParser;
    function GetPolarMaxAngle: Extended;
    procedure SetPolarMaxAngle(const Value: Extended);
    function GetQuality: Integer;
    procedure SetQuality(const Value: Integer);
    function GetSA: TScriptArray;
    procedure SetSA(const Value: TScriptArray);
    function GetThreadWorkTime: LongWord;
    function GetGlobalValue: TValue;
    procedure SetGlobalValue(const Value: TValue);
    function GetInternalParser: TParser;
    function GetCompute(const CS: TCoordinateSystem): TComputeMethod;
    function GetMaxZoom: Extended;
    function GetMinZoom: Extended;
    function GetOverlapMaxDepth: Integer;
    function GetOverlapMaxTime: Integer;
    function GetOverlapName(const Index: Integer): string;
    function GetOverlapTotal: Integer;
    function GetSameArray: TSameArray;
    function GetMarkSpacing: Integer;
    procedure SetMarkSpacing(const Value: Integer);
    function GetThreadCount: Integer;
    procedure SetCS(const Value: TCoordinateSystem);
    procedure SetExtreme(const Value: Boolean);
    procedure SetFormula(const Value: TFormulaList);
    procedure SetHighPrecision(const Value: Boolean);
    procedure SetMaxZoom(const Value: Extended);
    procedure SetMinZoom(const Value: Extended);
    procedure SetOffset(const Value: TPointD);
    procedure SetOverlap(const Value: Boolean);
    procedure SetOverlapMaxDepth(const Value: Integer);
    procedure SetOverlapMaxTime(const Value: Integer);
    procedure SetParser(const Value: TParser);
    procedure SetThreadCount(const Value: Integer);
    procedure SetThreadWorkTime(const Value: LongWord);
  protected
    procedure WndProc(var Message: TMessage); override;
    procedure DblClick; override;
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMEnter(var Message: TMessage); message CM_ENTER;
    procedure CMExit(var Message: TMessage); message CM_EXIT;
    procedure WMSetCursor(var Message: TWMSetCursor); message WM_SETCURSOR;
    procedure Notification(Component: TComponent; Operation: TOperation); override;
    procedure Paint; override;
    procedure Resize; override;
    function Available: Boolean; virtual;
    procedure DoOffsetChange; virtual;
    function MarkPoint(const Point: TPointD; var PointArray: TCurveIArray): Boolean; virtual;
    function GetPolarRangeArray: CrossGraph.Engine.TRangeArray; virtual;
    function FloatFormat(const Scale: Extended; const Count: Integer): string; overload; virtual;
    function CalcSize: TSize; virtual;
    function Examine(const Point: TPointD): Boolean; virtual;
    procedure Attach; virtual;
    procedure Detach; virtual;
    procedure DoBuildTimer(Sender: TObject); virtual;
    procedure DoEngineResult(Sender: TObject; const Kind: TResultKind); virtual;
    procedure DoLeadTimer(Sender: TObject); virtual;
    procedure DoZoomTimer(Sender: TObject); virtual;
    procedure DoTraceDone; virtual;
    procedure DoTrace(const FormulaIndex: Integer; const Point: TPointD); overload; virtual;
    procedure DoTrace(const FormulaIndex: Integer; const Angle: array of Extended;
      const Point: array of TPointD); overload; virtual;
    procedure DoBeforeParse; virtual;
    procedure DoAfterParse; virtual;
    procedure DoOverlap; virtual;
    procedure DoExtreme; virtual;
    function PointCount(const Segment: PExtended = nil): Extended; virtual;
    function Compare(const APoint, BPoint: TPoint; const AAccuracy: Integer = 0): Boolean; virtual;
    procedure Capture; virtual;
    function Inactive: Boolean; virtual;
    procedure UpdateCursor; virtual;
    procedure DrawFormula(const Target: TCanvas); virtual;
    procedure DrawOverlap(const Target: TCanvas); virtual;
    procedure DrawMaximum(const Target: TCanvas); virtual;
    procedure DrawMinimum(const Target: TCanvas); virtual;
    {$IFNDEF FPC}
    function DrawSmooth(const Target: TCanvas; const PointArray: TCurveIArray; const Entire: Boolean;
      const Back, Face: PPlace; const Color: PColor): Boolean; virtual;
    {$ENDIF}
    function DrawPointArray(const Target: TCanvas; const PointArray: TCurveIArray; const Pen: TPen = nil;
      const Smooth: Boolean = False; const Back: PPlace = nil; const Face: PPlace = nil;
      const Color: PColor = nil): Boolean; virtual;
    procedure DrawSign(const Mode: TRetrieveMode = rmUser); virtual;
    procedure Prepare; virtual;
    property Parser: TParser read GetParser write SetParser;
    property PolarRangeArray: CrossGraph.Engine.TRangeArray read GetPolarRangeArray;
    property Size: TSize read FSize write FSize;
    property Center: TPointD read GetCenter;
    property Min: TPointD read GetMin;
    property Max: TPointD read GetMax;
    property XFactor: Extended read FXFactor;
    property YFactor: Extended read FYFactor;
    property PivotPoint: TPointD read FPivotPoint write FPivotPoint;
    property Moving: Boolean read FMoving write FMoving;
    property BuildTimer: TExactTimer read FBuildTimer write FBuildTimer;
    property LeadTimer: TExactTimer read FLeadTimer write FLeadTimer;
    property ZoomTimer: TZoomTimer read FZoomTimer write FZoomTimer;
    property TraceArray: TCurveIArray read FTraceArray write FTraceArray;
    property Numeration: TNumeration read FNumeration write FNumeration;
    property OverlapNameNumeration: Integer read FOverlapNameNumeration write FOverlapNameNumeration;
  public
    constructor Create(AOwner: TComponent); override;
    function ComputeRectangular(const Value: Extended; const Script: TScript): TPointD; virtual;
    function ComputePolar(const Value: Extended; const Script: TScript): TPointD; virtual;
    destructor Destroy; override;
    procedure Invalidate; override;
    function GetDisplay: TDisplay; virtual;
    procedure DrawBitmap(const Bitmap: TBitmap; const Point: TPoint; const BlendValue: Byte); virtual;
    procedure DrawText(const S: string; const Font: TFont; const Background: TColor;
      const Layout: TLayoutType; const Margin: Integer; const BlendValue: Byte); virtual;
    procedure Parse; virtual;
    procedure Build; virtual;
    procedure Clear; virtual;
    procedure MakeZoom(const ZoomType: TZoomType); virtual;
    procedure Zoom(const ZoomType: TZoomType; const Factor: Extended = -1); virtual;
    function XToCursor(const X: Extended): Extended; overload; virtual;
    function YToCursor(const Y: Extended): Extended; overload; virtual;
    function PointToCursor(const Point: TPointD): TPointD; overload; virtual;
    function PointToCursor(const Point: TPoint): TPoint; overload; virtual;
    function XToPoint(const X: Extended): Extended; overload; virtual;
    function YToPoint(const Y: Extended): Extended; overload; virtual;
    function CursorToPoint(const Point: TPointD): TPointD; overload; virtual;
    function CursorToPoint(const Point: TPoint): TPoint; overload; virtual;
    function FloatFormat(const Format: string): string; overload; virtual;
    procedure MakeColor(const Formula: Integer); virtual;
    function WaitFor(const Thread: TThread; const Time: LongWord): Boolean; virtual;
    procedure Stop; virtual;
    procedure Abort; virtual;
    property InternalParser: TParser read GetInternalParser;
    property GlobalValue: TValue read GetGlobalValue write SetGlobalValue;
    property PolarMaxAngle: Extended read GetPolarMaxAngle write SetPolarMaxAngle;
    property SA: TScriptArray read GetSA write SetSA;
    property Compute[const CS: TCoordinateSystem]: TComputeMethod read GetCompute;
    property ThreadCount: Integer read GetThreadCount write SetThreadCount;
    property ThreadWorkTime: LongWord read GetThreadWorkTime write SetThreadWorkTime;
    property Buffer: TBitmap read FBuffer write FBuffer;
    property ErrorMessage: string read GetErrorMessage write SetErrorMessage;
    property XDigitCount: Integer read FXDigitCount write FXDigitCount;
    property YDigitCount: Integer read FYDigitCount write FYDigitCount;
    property AngleDigitCount: Integer read FAngleDigitCount write FAngleDigitCount;
    property ExtremeVaryRadius: Extended read GetExtremeVaryRadius write SetExtremeVaryRadius;
    property AutoVary: Boolean read FAutoVary write FAutoVary;
    property ExtremeVoidRadius: Extended read GetExtremeVoidRadius write SetExtremeVoidRadius;
    property AutoVoid: Boolean read FAutoVoid write FAutoVoid;
    property XFormat: string read FXFormat;
    property YFormat: string read FYFormat;
    property XYFormat: string read FXYFormat;
    property AngleFormat: string read FAngleFormat;
    property Epsilon: Extended read GetEpsilon;
    property EntireArray: TCurveDArray read GetEntireArray write SetEntireArray;
    property CursorArray: TCurveIArray read FCursorArray write FCursorArray;
    property OverlapArray: TOverlapArray read GetOverlapArray write SetOverlapArray;
    property OverlapName[const Index: Integer]: string read GetOverlapName;
    property MaxArray: TCurveDArray read GetMaxArray write SetMaxArray;
    property MinArray: TCurveDArray read GetMinArray write SetMinArray;
    property ColorArray: TColorArray read FColorArray write FColorArray;
    property Busy: Boolean read GetBusy;
    {$IFDEF FPC}
    property AxisArrow: TSize read FAxisArrow write FAxisArrow;
    property Offset: TPointD read GetOffset write SetOffset;
    {$ENDIF}
  published
    property Accuracy: Integer read FAccuracy write FAccuracy default DefaultAccuracy;
    property HighPrecision: Boolean read GetHighPrecision write SetHighPrecision;
    property JitEnabled: Boolean read GetJitEnabled write SetJitEnabled default True;
    property PrecisionFormat: string read FPrecisionFormat write FPrecisionFormat;
    property Align;
    property Anchors;
    property Antialias: Boolean read FAntialias write FAntialias default DefaultAntialias;
    property Silent: Boolean read FSilent write FSilent default False;
    property Autoquality: Boolean read GetAutoquality write SetAutoquality default DefaultAutoquality;
    property AutoSize;
    {$IFNDEF FPC}
    property AxisArrow: TSize read FAxisArrow write FAxisArrow;
    {$ENDIF}
    property AxisFont: TFont read FAxisFont write FAxisFont;
    property AxisPen: TPen read FAxisPen write FAxisPen;
    property BiDiMode;
    property Color;
    property Constraints;
    property CS: TCoordinateSystem read GetCS write SetCS default DefaultCS;
    {$IFNDEF FPC}
    property Ctl3D;
    {$ENDIF}
    property Cursor default crCross;
    property UseDockManager;
    property Sign: Boolean read FSign write FSign default DefaultSign;
    property SignBlendValue: Byte read FSignBlendValue write FSignBlendValue;
    property SignLayout: TLayoutType read FSignLayout write FSignLayout default DefaultSignLayout;
    property SignMargin: Integer read FSignMargin write FSignMargin default DefaultSignMargin;
    property SignFont: TFont read FSignFont write FSignFont;
    property TextBackground: TColor read FTextBackground write FTextBackground default DefaultTextBackground;
    property TextBlendValue: Byte read FTextBlendValue write FTextBlendValue default DefaultTextBlendValue;
    property TextLayout: TLayoutType read FTextLayout write FTextLayout default DefaultTextLayout;
    property TextMargin: Integer read FTextMargin write FTextMargin default DefaultTextMargin;
    property TextFont: TFont read FTextFont write FTextFont;
    property DockSite;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property Formula: TFormulaList read GetFormula write SetFormula;
    property FormulaFont: TFont read FFormulaFont write FFormulaFont;
    property GraphPen: TPen read FGraphPen write FGraphPen;
    property GridPen: TPen read FGridPen write FGridPen;
    property PolarAxisPen: TPen read FPolarAxisPen write FPolarAxisPen;
    property Height default DefaultHeight;
    property HSpacing: Extended read FHSpacing write FHSpacing;
    property MarkerPen: TPen read FMarkerPen write FMarkerPen;
    property MaxZoom: Extended read GetMaxZoom write SetMaxZoom;
    property OverlapMaxDepth: Integer read GetOverlapMaxDepth write SetOverlapMaxDepth;
    property OverlapTotal: Integer read GetOverlapTotal;
    property MarkSpacing: Integer read GetMarkSpacing write SetMarkSpacing;
    property SameArray: TSameArray read GetSameArray;
    property OverlapMaxTime: Integer read GetOverlapMaxTime write SetOverlapMaxTime;
    property MaxX: Extended read GetMaxX write SetMaxX;
    property MaxY: Extended read GetMaxY write SetMaxY;
    property MinZoom: Extended read GetMinZoom write SetMinZoom;
    property MultiColor: Boolean read FMulticolor write FMulticolor default DefaultMulticolor;
    {$IFNDEF FPC}
    property Offset: TPointD read GetOffset write SetOffset;
    {$ENDIF}
    property ParentBiDiMode;
    property ParentColor;
    {$IFNDEF FPC}
    property ParentCtl3D;
    {$ENDIF}
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property Quality: Integer read GetQuality write SetQuality default DefaultQuality;
    property ShowAxis: Boolean read FShowAxis write FShowAxis default True;
    property ShowGrid: Boolean read FShowGrid write FShowGrid default True;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property TracePen: TPen read FTracePen write FTracePen;
    property Tracing: Boolean read FTracing write FTracing default DefaultTracing;
    property Overlap: Boolean read GetOverlap write SetOverlap default DefaultOverlap;
    property Extreme: Boolean read GetExtreme write SetExtreme default DefaultExtreme;
    property VSpacing: Extended read FVSpacing write FVSpacing;
    property Visible;
    property ZoomInFactor: Extended read FZoomInFactor write FZoomInFactor;
    property ZoomOutFactor: Extended read FZoomOutFactor write FZoomOutFactor;
    property Width default DefaultWidth;
    {$IFNDEF FPC}
    property OnCanResize;
    {$ENDIF}
    property OnClick;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnDockDrop;
    property OnDockOver;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnOffsetChange: TNotifyEvent read FOnOffsetChange write FOnOffsetChange;
    property OnGetSiteInfo;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDock;
    property OnStartDrag;
    property OnUnDock;
    property BeforeParse: TNotifyEvent read FBeforeParse write FBeforeParse;
    property AfterParse: TNotifyEvent read FAfterParse write FAfterParse;
    property OnOverlap: TNotifyEvent read FOnOverlap write FOnOverlap;
    property OnExtreme: TNotifyEvent read FOnExtreme write FOnExtreme;
    property OnTraceDone: TNotifyEvent read FOnTraceDone write FOnTraceDone;
    property OnRectangularTrace: TRectangularTraceEvent read FOnRectangularTrace write FOnRectangularTrace;
    property OnPolarTrace: TPolarTraceEvent read FOnPolarTrace write FOnPolarTrace;
  end;

const
  WM_INVALIDATE = WM_USER;
  OverlapCode = 1;
  ExtremeCode = 2;
  DefaultThreadCount = 2;
  DefaultColorArray: array[0..9] of TColor = (clMaroon, clNavy, clPurple, clRed, clOlive, clTeal, clGreen, clBlue, clFuchsia, clBlack);
  IncorrectColor = clBlack;
  DefaultMaxX = 5;
  DefaultMaxY = 5;
  DefaultOffset: TPointD = (X: 0; Y: 0);
  DefaultXDigitCount = 3;
  DefaultYDigitCount = 3;
  DefaultAngleDigitCount = 3;
  DefaultAxisArrow: TSize = (cx: 12; cy: 6);
  DefaultShowAxis = True;
  DefaultShowGrid = True;
  DefaultHSpacing = 1;
  DefaultVSpacing = 1;
  DefaultZoomInFactor = 0.5;
  DefaultZoomOutFactor = 0.5;
  DefaultMinZoom: array[TCoordinateSystem] of Extended = (0.0000000000001, 0.00000001);
  DefaultMaxZoom: array[TCoordinateSystem] of Extended = (1000000000000, 10000000);
  DefaultOverlapMaxDepth: array[TCoordinateSystem] of Integer = (100, 100);
  DefaultOverlapMaxTime: array[TCoordinateSystem] of Integer = (500, 500);
  DefaultBuildDelay = 100;
  DefaultLeadDelay = 25;
  DefaultZoomDelay = 15;
  AngleVariableName = 'T';
  ValueVariableName = 'X';
  SmallMarkerMargin = 8;
  LargeMarkerMargin = 10;
  ExtremeVaryFactor = 5;
  ExtremeVoidFactor = 20;

function Check(const Target: TCurveIArray; const Place: TPlace): Boolean; overload;
function Shift(const Target: TCurveIArray; const Back, Face: TPlace; const Distance: Integer;
  out Place: TPlace): Boolean; overload;
function Shift(const Target: TCurveIArray; const Back, Face: TPlace; const Distance: Integer;
  out Point: PPoint): Boolean; overload;
function MovePlace(const Target: TCurveIArray; const Place: TPlace; const Forward: Boolean;
  out Value: TPlace): Boolean; overload;
function NextPlace(const Target: TCurveIArray; const Place: TPlace; out Value: TPlace): Boolean; overload;
function NextPlace(const Target: TCurveIArray; const Place: TPlace): TPlace; overload;
function PrevPlace(const Target: TCurveIArray; const Place: TPlace; out Value: TPlace): Boolean; overload;
function PrevPlace(const Target: TCurveIArray; const Place: TPlace): TPlace; overload;
function LastPlace(const Target: TCurveIArray): TPlace; overload;
function NextPoint(const Target: TCurveIArray; const Back, Face: TPlace; const X: Integer;
  out Value: PPoint): Boolean; overload;
function PrevPoint(const Target: TCurveIArray; const Back, Face: TPlace; const X: Integer;
  out Value: PPoint): Boolean; overload;
function GetRange(const Target: TCurveIArray; const Back, Face: TPlace; const ArrayIndex: Integer;
  out Min, Max: Integer): Boolean; overload;

procedure Register;

function Blend(const AValue, BValue, Factor: Byte): Byte;

implementation

uses
  {$IFDEF FPC}
  Forms, Math, Notifier, MemoryUtils, NumberConsts, ParseConsts, ParseErrors, ParseUtils,
  StrUtils, TextUtils, ThreadUtils, ValueUtils;
  {$ELSE}
  {$IFDEF DELPHI_XE7}
  Vcl.Forms, System.UITypes, Math, Notifier, MemoryUtils, NumberConsts, ParseConsts,
  ParseErrors, ParseUtils, StrUtils, TextUtils, ThreadUtils, ValueUtils;
  {$ELSE}
  Forms, Math, Notifier, MemoryUtils, NumberConsts, ParseConsts, ParseErrors, ParseUtils,
  StrUtils, TextUtils, ThreadUtils, ValueUtils;
  {$ENDIF}
  {$ENDIF}

{$IFNDEF FPC}
var
  GdiPlusToken: ULONG_PTR = 0;

function StartGdiPlus: Boolean;
var
  Input: TGdiplusStartupInput;
begin
  if not IsLibrary or (GdiPlusToken <> 0) then Exit(True);
  FillChar(Input, SizeOf(Input), 0);
  Input.GdiplusVersion := 1;
  Result := GdiplusStartup(GdiPlusToken, @Input, nil) = Ok;
  if not Result then GdiPlusToken := 0;
end;
{$ENDIF}

procedure Register;
begin
  RegisterComponents('Samples', [TGraph]);
end;

function Check(const Target: TCurveIArray; const Place: TPlace): Boolean;
begin
  Result := Check(Target, Place.ArrayIndex, Place.Index);
end;

function Shift(const Target: TCurveIArray; const Back, Face: TPlace; const Distance: Integer;
  out Place: TPlace): Boolean;
var
  I, J, Min, Max: Integer;
begin
  Result := not Empty(Back, Face) and Check(Target, Back) and Check(Target, Face);
  if Result then
  begin
    J := Distance;
    for I := Back.ArrayIndex to Face.ArrayIndex do
    begin
      if not GetRange(Target, Back, Face, I, Min, Max) then Break;
      if J <= Max - Min then
      begin
        Place := MakePlace(I, Min + J);
        Exit;
      end;
      Dec(J, Max - Min + 1);
    end;
    Result := False;
  end;
end;

function Shift(const Target: TCurveIArray; const Back, Face: TPlace; const Distance: Integer;
  out Point: PPoint): Boolean;
var
  Place: TPlace;
begin
  Result := Shift(Target, Back, Face, Distance, Place);
  if Result then Point := @Target[Place.ArrayIndex, Place.Index];
end;

function MovePlace(const Target: TCurveIArray; const Place: TPlace; const Forward: Boolean;
  out Value: TPlace): Boolean;
var
  Flag: Boolean;
  I, J: Integer;
begin
  Flag := True;
  I := Place.ArrayIndex;
  while Check(Target, I) do
  begin
    if Flag then
    begin
      if Forward then
        J := Place.Index + 1
      else
        J := Place.Index - 1;
      Flag := False;
    end
    else
      if Forward then
        J := 0
      else
        J := High(Target[I]);
    Result := Check(Target[I], J);
    if Result then
    begin
      Value := MakePlace(I, J);
      Exit;
    end;
    if Forward then
      Inc(I)
    else
      Dec(I);
  end;
  Result := False;
end;

function NextPlace(const Target: TCurveIArray; const Place: TPlace; out Value: TPlace): Boolean;
begin
  Result := MovePlace(Target, Place, True, Value);
end;

function NextPlace(const Target: TCurveIArray; const Place: TPlace): TPlace;
begin
  if not NextPlace(Target, Place, Result) then Result := Place;
end;

function PrevPlace(const Target: TCurveIArray; const Place: TPlace; out Value: TPlace): Boolean;
begin
  Result := MovePlace(Target, Place, False, Value);
end;

function PrevPlace(const Target: TCurveIArray; const Place: TPlace): TPlace;
begin
  if not PrevPlace(Target, Place, Result) then Result := Place;
end;

function LastPlace(const Target: TCurveIArray): TPlace;
var
  I, J: Integer;
begin
  I := High(Target);
  if I < 0 then
    Result := MakePlace(0, 0)
  else begin
    J := High(Target[I]);
    if J < 0 then
      Result := PrevPlace(Target, MakePlace(I, J))
    else
      Result := MakePlace(I, J);
  end;
end;

function NextPoint(const Target: TCurveIArray; const Back, Face: TPlace; const X: Integer;
  out Value: PPoint): Boolean;
var
  I: Integer;
begin
  I := 0;
  Value := nil;
  while Shift(Target, Back, Face, I, Value) and (Value.X < X) do Inc(I);
  Result := Assigned(Value);
end;

function PrevPoint(const Target: TCurveIArray; const Back, Face: TPlace; const X: Integer;
  out Value: PPoint): Boolean;
var
  I: Integer;
  Point: PPoint;
begin
  I := 0;
  Value := nil;
  while Shift(Target, Back, Face, I, Point) and (Point.X < X) do
  begin
    Value := Point;
    Inc(I);
  end;
  Result := Assigned(Value);
end;

function GetRange(const Target: TCurveIArray; const Back, Face: TPlace; const ArrayIndex: Integer;
  out Min, Max: Integer): Boolean;
var
  AFlag, BFlag: Boolean;
begin
  Result := Check(Target, Back) and Check(Target, Face);
  if Result then
  begin
    AFlag := Back.ArrayIndex = ArrayIndex;
    BFlag := Face.ArrayIndex = ArrayIndex;
    if AFlag and BFlag then
    begin
      Min := Back.Index;
      Max := Face.Index;
    end
    else begin
      if AFlag then
        Min := Back.Index
      else
        Min := 0;
      if BFlag then
        Max := Face.Index
      else
        Max := Length(Target[ArrayIndex]) - 1;
    end;
  end;
end;

{$IFNDEF DELPHI_2006}

procedure TBitmap.SetSize(const AWidth, AHeight: Integer);
begin
  Width := AWidth;
  Height := AHeight;
end;

procedure TBitmap.SetSize(const Size: TSize);
begin
  SetSize(Size.cx, Size.cy);
end;
{$ENDIF}

procedure TGraph.Abort;
begin
  FEngine.Abort;
end;

procedure TGraph.Attach;
begin
  FEngine.Attach;
end;

function TGraph.Available: Boolean;
begin
  Result := not (csDestroying in ComponentState);
end;

procedure TGraph.Build;
begin
  Prepare;
  Parse;
  Paint;
end;

function TGraph.CalcSize: TSize;
begin
  with Result, ClientRect do
  begin
    cx := Right - Left;
    cy := Bottom - Top;
  end;
end;

procedure TGraph.Capture;
var
  I, J: Integer;
  APoint: PPointD;
  CPoint: TPoint;
begin
  CrossGraph.Types.Delete(FCursorArray);
  SetLength(FCursorArray, Length(FEngine.EntireArray));
  for I := Low(FEngine.EntireArray) to High(FEngine.EntireArray) do
  begin
    APoint := nil;
    for J := Low(FEngine.EntireArray[I]) to High(FEngine.EntireArray[I]) do
    begin
      CPoint := PointI(PointToCursor(FEngine.EntireArray[I, J]));
      if not Assigned(APoint) or Compare(PointI(PointToCursor(APoint^)), CPoint) then
      begin
        CrossGraph.Types.Add(FCursorArray[I], CPoint);
        APoint := @FEngine.EntireArray[I, J];
      end;
    end;
  end;
end;

procedure TGraph.Clear;
begin
  Abort;
  CrossGraph.Types.Delete(FTraceArray);
  CrossGraph.Types.Delete(FCursorArray);
  FEngine.Clear;
end;

function TGraph.Compare(const APoint, BPoint: TPoint; const AAccuracy: Integer): Boolean;
begin
  if AAccuracy > 0 then
    Result := DistanceOf(PointD(APoint), PointD(BPoint)) >= AAccuracy
  else
    Result := DistanceOf(PointD(APoint), PointD(BPoint)) >= FAccuracy
end;

function TGraph.ComputePolar(const Value: Extended; const Script: TScript): TPointD;
begin
  Result := FEngine.ComputePolar(Value, Script);
end;

function TGraph.ComputeRectangular(const Value: Extended; const Script: TScript): TPointD;
begin
  Result := FEngine.ComputeRectangular(Value, Script);
end;

constructor TGraph.Create(AOwner: TComponent);
var
  I: Integer;
  J: TCoordinateSystem;
begin
  inherited;
  FEngine := TGraphEngine.Create(Self);
  FEngine.OnResultReady := DoEngineResult;
  FXDigitCount := DefaultXDigitCount;
  FYDigitCount := DefaultYDigitCount;
  FAngleDigitCount := DefaultAngleDigitCount;
  FAutoVary := DefaultAutoVary;
  FAutoVoid := DefaultAutoVoid;
  FBuildTimer := TExactTimer.Create(Self);
  with FBuildTimer do
  begin
    TimerType := ttOneShot;
    Elapse := DefaultBuildDelay;
    OnTimer := DoBuildTimer;
  end;
  FLeadTimer := TExactTimer.Create(Self);
  with FLeadTimer do
  begin
    TimerType := ttOneShot;
    Elapse := DefaultLeadDelay;
    OnTimer := DoLeadTimer;
  end;
  FZoomTimer := TZoomTimer.Create(Self);
  with FZoomTimer do
  begin
    TimerType := ttOneShot;
    Elapse := DefaultZoomDelay;
    OnTimer := DoZoomTimer;
  end;
  FNumeration := TNumeration.Create;
  FOverlapNameNumeration := FNumeration.Add(UCaseIndexChar);
  SetLength(FColorArray, Length(DefaultColorArray));
  for I := Low(FColorArray) to High(FColorArray) do FColorArray[I] := DefaultColorArray[I];
  ControlStyle := ControlStyle + [csOpaque];
  FBuffer := TBitmap.Create;
  FBuffer.PixelFormat := DefaultFormat;
  FAccuracy := DefaultAccuracy;
  FPrecisionFormat := DefaultPrecisionFormat;
  FAxisArrow := DefaultAxisArrow;
  FAxisFont := TFont.Create;
  FAxisPen := TPen.Create;
  Cursor := crCross;
  FSign := DefaultSign;
  FSignBlendValue := DefaultSignBlendValue;
  FSignLayout := DefaultSignLayout;
  FSignMargin := DefaultSignMargin;
  FSignFont := TFont.Create;
  FSignFont.Color := clWhite;
  FTextBackground := DefaultTextBackground;
  FTextBlendValue := DefaultTextBlendValue;
  FTextLayout := DefaultTextLayout;
  FTextMargin := DefaultTextMargin;
  FTextFont := TFont.Create;
  FTextFont.Color := clWhite;
  FFormulaFont := TFont.Create;
  FGraphPen := TPen.Create;
  FGraphPen.Color := clRed;
  FGridPen := TPen.Create;
  with FGridPen do
  begin
    Color := clGray;
    Style := psDot;
  end;
  FPolarAxisPen := TPen.Create;
  FPolarAxisPen.Color := clGray;
  Height := DefaultHeight;
  FMulticolor := DefaultMulticolor;
  Width := DefaultWidth;
  FHSpacing := DefaultHSpacing;
  for J := Low(TCoordinateSystem) to High(TCoordinateSystem) do
  begin
    FMaxZoom[J] := DefaultMaxZoom[J];
    FMinZoom[J] := DefaultMinZoom[J];
  end;
  FMarkerPen := TPen.Create;
  FMarkerPen.Color := clBlue;
  FAntialias := DefaultAntialias;
  FShowAxis := DefaultShowAxis;
  FShowGrid := DefaultShowGrid;
  FTracePen := TPen.Create;
  with FTracePen do
  begin
    Color := clBlue;
    Style := psDot;
  end;
  FTracing := DefaultTracing;
  FVSpacing := DefaultVSpacing;
  FZoomInFactor := DefaultZoomInFactor;
  FZoomOutFactor := DefaultZoomOutFactor;
end;

function TGraph.CursorToPoint(const Point: TPoint): TPoint;
begin
  Result := PointI(CursorToPoint(PointD(Point)));
end;

function TGraph.CursorToPoint(const Point: TPointD): TPointD;
begin
  Result.X := XToPoint(Point.X);
  Result.Y := YToPoint(Point.Y);
end;

procedure TGraph.DblClick;
var
  Point: TPoint;
begin
  inherited;
  if Available and GetCursorPos(Point) and PtInRect(ClientRect, ScreenToClient(Point)) then
    Zoom(ztIn);
end;

destructor TGraph.Destroy;
begin
  Abort;
  FNumeration.Free;
  CrossGraph.Types.Delete(FTraceArray);
  CrossGraph.Types.Delete(FCursorArray);
  FColorArray := nil;
  FBuffer.Free;
  FAxisFont.Free;
  FAxisPen.Free;
  FSignFont.Free;
  FTextFont.Free;
  FFormulaFont.Free;
  FGraphPen.Free;
  FGridPen.Free;
  FPolarAxisPen.Free;
  FMarkerPen.Free;
  FTracePen.Free;
  inherited;
end;

procedure TGraph.Detach;
begin
  FEngine.Detach;
end;

procedure TGraph.DoAfterParse;
begin
  if Assigned(FAfterParse) then FAfterParse(Self);
end;

procedure TGraph.DoBeforeParse;
begin
  if Assigned(FBeforeParse) then FBeforeParse(Self);
end;

procedure TGraph.DoExtreme;
begin
  if Assigned(FOnExtreme) then FOnExtreme(Self);
end;

procedure TGraph.DoEngineResult(Sender: TObject; const Kind: TResultKind);
begin
  if csDestroying in ComponentState then Exit;
  if Kind = rkOverlap then
    PostMessage(Handle, WM_INVALIDATE, OverlapCode, 0)
  else
    PostMessage(Handle, WM_INVALIDATE, ExtremeCode, 0);
end;

function TGraph.GetAutoquality: Boolean;
begin
  Result := FEngine.Autoquality;
end;

procedure TGraph.SetAutoquality(const Value: Boolean);
begin
  FEngine.Autoquality := Value;
end;

function TGraph.GetCS: TCoordinateSystem;
begin
  Result := FEngine.CS;
end;

function TGraph.GetCenter: TPointD;
begin
  Result := FEngine.Center;
end;

function TGraph.GetEntireArray: TCurveDArray;
begin
  Result := FEngine.EntireArray;
end;

procedure TGraph.SetEntireArray(const Value: TCurveDArray);
begin
  FEngine.EntireArray := Value;
end;

function TGraph.GetEpsilon: Extended;
begin
  Result := FEngine.Epsilon;
end;

function TGraph.GetErrorMessage: string;
begin
  Result := FEngine.ErrorMessage;
end;

procedure TGraph.SetErrorMessage(const Value: string);
begin
  FEngine.ErrorMessage := Value;
end;

function TGraph.GetExtreme: Boolean;
begin
  Result := FEngine.Extreme;
end;

function TGraph.GetExtremeVaryRadius: Extended;
begin
  Result := FEngine.ExtremeVaryRadius;
end;

procedure TGraph.SetExtremeVaryRadius(const Value: Extended);
begin
  FEngine.ExtremeVaryRadius := Value;
end;

function TGraph.GetExtremeVoidRadius: Extended;
begin
  Result := FEngine.ExtremeVoidRadius;
end;

procedure TGraph.SetExtremeVoidRadius(const Value: Extended);
begin
  FEngine.ExtremeVoidRadius := Value;
end;

function TGraph.GetFormula: TFormulaList;
begin
  Result := FEngine.Formula;
end;

function TGraph.GetJitEnabled: Boolean;
begin
  Result := FEngine.JitEnabled;
end;

procedure TGraph.SetJitEnabled(const Value: Boolean);
begin
  FEngine.JitEnabled := Value;
end;

function TGraph.GetHighPrecision: Boolean;
begin
  Result := FEngine.HighPrecision;
end;

function TGraph.GetMax: TPointD;
begin
  Result := FEngine.Max;
end;

function TGraph.GetMaxArray: TCurveDArray;
begin
  Result := FEngine.MaxArray;
end;

procedure TGraph.SetMaxArray(const Value: TCurveDArray);
begin
  FEngine.MaxArray := Value;
end;

function TGraph.GetMaxX: Extended;
begin
  Result := FEngine.MaxX;
end;

procedure TGraph.SetMaxX(const Value: Extended);
begin
  FEngine.MaxX := Value;
end;

function TGraph.GetMaxY: Extended;
begin
  Result := FEngine.MaxY;
end;

procedure TGraph.SetMaxY(const Value: Extended);
begin
  FEngine.MaxY := Value;
end;

function TGraph.GetMin: TPointD;
begin
  Result := FEngine.Min;
end;

function TGraph.GetMinArray: TCurveDArray;
begin
  Result := FEngine.MinArray;
end;

procedure TGraph.SetMinArray(const Value: TCurveDArray);
begin
  FEngine.MinArray := Value;
end;

function TGraph.GetOffset: TPointD;
begin
  Result := FEngine.Offset;
end;

function TGraph.GetOverlap: Boolean;
begin
  Result := FEngine.Overlap;
end;

function TGraph.GetOverlapArray: TOverlapArray;
begin
  Result := FEngine.OverlapArray;
end;

procedure TGraph.SetOverlapArray(const Value: TOverlapArray);
begin
  FEngine.OverlapArray := Value;
end;

function TGraph.GetParser: TParser;
begin
  Result := FEngine.Parser;
end;

function TGraph.GetPolarMaxAngle: Extended;
begin
  Result := FEngine.PolarMaxAngle;
end;

procedure TGraph.SetPolarMaxAngle(const Value: Extended);
begin
  FEngine.PolarMaxAngle := Value;
end;

function TGraph.GetQuality: Integer;
begin
  Result := FEngine.Quality;
end;

procedure TGraph.SetQuality(const Value: Integer);
begin
  FEngine.Quality := Value;
end;

function TGraph.GetSA: TScriptArray;
begin
  Result := FEngine.SA;
end;

procedure TGraph.SetSA(const Value: TScriptArray);
begin
  FEngine.SA := Value;
end;

function TGraph.GetThreadWorkTime: LongWord;
begin
  Result := FEngine.ThreadWorkTime;
end;

function TGraph.GetGlobalValue: TValue;
begin
  Result := FEngine.GlobalValue;
end;

procedure TGraph.SetGlobalValue(const Value: TValue);
begin
  FEngine.GlobalValue := Value;
end;

function TGraph.GetInternalParser: TParser;
begin
  Result := FEngine.Parser;
end;

procedure TGraph.DoBuildTimer(Sender: TObject);
begin
  Build;
end;

procedure TGraph.DoLeadTimer(Sender: TObject);
var
  Point: TPoint;
begin
  Prepare;
  GetCursorPos(Point);
  Point := ScreenToClient(Point);
  if PtInRect(ClientRect, Point) then
  begin
    FEngine.Offset := PointD(-XToPoint(Point.X), -YToPoint(Point.Y));
    DoOffsetChange;
  end;
  Build;
end;

function TGraph.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheelDown(Shift, MousePos);
  if Available then MakeZoom(ztOut);
end;

function TGraph.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  Result := inherited DoMouseWheelUp(Shift, MousePos);
  if Available then MakeZoom(ztIn);
end;

procedure TGraph.DoOffsetChange;
begin
  if Assigned(FOnOffsetChange) then FOnOffsetChange(Self);
end;

procedure TGraph.DoOverlap;
begin
  if Assigned(FOnOverlap) then FOnOverlap(Self);
end;

procedure TGraph.DoTrace(const FormulaIndex: Integer; const Angle: array of Extended;
  const Point: array of TPointD);
begin
  if Assigned(FOnPolarTrace) then FOnPolarTrace(Self, FormulaIndex, Angle, Point);
end;

procedure TGraph.DoTrace(const FormulaIndex: Integer; const Point: TPointD);
begin
  if Assigned(FOnRectangularTrace) then FOnRectangularTrace(Self, FormulaIndex, Point);
end;

procedure TGraph.DoTraceDone;
begin
  if Assigned(FOnTraceDone) then FOnTraceDone(Self);
end;

procedure TGraph.DoZoomTimer(Sender: TObject);
var
  Point: TPoint;
  Timer: TZoomTimer absolute Sender;
begin
  if GetCursorPos(Point) and PtInRect(ClientRect, ScreenToClient(Point)) then Zoom(Timer.ZoomType);
  Timer.ZoomType := ztNone;
end;

function Blend(const AValue, BValue, Factor: Byte): Byte;
begin
  Result := (AValue * (MaxByte - Factor) + BValue * Factor) div MaxByte;
end;

procedure TGraph.DrawBitmap(const Bitmap: TBitmap; const Point: TPoint; const BlendValue: Byte);
type
  TBitmapType = (btSource, btTarget);
var
  I, J, Count: Integer;
  K: TColorType;
  P: array[TBitmapType] of Pointer;
  Pixel: array[TBitmapType] of PPixel;
begin
  Count := ByteCount[Bitmap.PixelFormat];
  I := 0;
  while (I < Bitmap.Height) and (Point.Y + I < FBuffer.Height) do
  begin
    P[btSource] := Bitmap.ScanLine[I];
    P[btTarget] := PAnsiChar(FBuffer.ScanLine[Point.Y + I]) + Point.X * Count;
    J := 0;
    while (J < Bitmap.Width) and (Point.X + J < FBuffer.Width) do
    begin
      Pixel[btSource] := Pointer(PAnsiChar(P[btSource]) + J * Count);
      Pixel[btTarget] := Pointer(PAnsiChar(P[btTarget]) + J * Count);
      for K := Low(TColorType) to TColorType(Count) do
        Pixel[btTarget, K] := Blend(Pixel[btTarget, K], Pixel[btSource, K], BlendValue);
      Inc(J);
    end;
    Inc(I);
  end;
end;

var
  DrawCount: Integer;

procedure TGraph.DrawFormula(const Target: TCanvas);
var
  I, J: Integer;
  Data: PFormulaData;
begin
  if not FMulticolor then J := FGraphPen.Color;
  for I := 0 to FEngine.Formula.Count - 1 do if FEngine.Formula.Active[I] then
  begin
    Data := FEngine.Formula.Data[I];
    if Assigned(Data) then
    begin
      DrawPointArray(Target, FCursorArray, FGraphPen, True, @Data.CursorBack, @Data.CursorFace,
        PColor(IfThen(FMulticolor, NativeInt(@Data.Color), NativeInt(@J))));
      Inc(DrawCount);
    end;
  end;
end;

procedure TGraph.DrawMaximum(const Target: TCanvas);
const
  FontName = 'Courier New';
  FontSize = 8;
  HintMargin = 2;
  HintText = 'max';
var
  I, J, K, L, M: Integer;
  Data: PFormulaData;
  Cursor: TPoint;
  C: TColor;
  Extent: TSize;
  PointArray: TCurveIArray;
begin
  if FEngine.Extreme then
  begin
    for I := 0 to FEngine.Formula.Count - 1 do if FEngine.Formula.Active[I] then
    begin
      Data := FEngine.Formula.Data[I];
      if Assigned(Data) then for J := Data.MaxBack.ArrayIndex to Data.MaxFace.ArrayIndex do
        if GetRange(FEngine.MaxArray, Data.MaxBack, Data.MaxFace, J, L, M) then
          for K := L to M do
          begin
            Cursor := PointI(PointToCursor(FEngine.MaxArray[J, K]));
            try
              if FMulticolor then
                C := Data.Color
              else
                C := clBlack;
              Target.Font.Name := FontName;
              Target.Font.Size := FontSize;
              Target.Font.Color := C;
              Extent := Target.TextExtent(HintText);
              Target.TextOut(Cursor.X - Extent.cx div 2, Cursor.Y + SmallMarkerMargin div 2 + HintMargin, HintText);
              CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
              CrossGraph.Types.Add(PointArray, Point(Cursor.X, Cursor.Y - SmallMarkerMargin));
              CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
              CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
              DrawPointArray(Target, PointArray, FMarkerPen, False, nil, nil, @C);
            finally
              PointArray := nil;
            end;
          end;
    end;
  end;
end;

procedure TGraph.DrawMinimum(const Target: TCanvas);
const
  FontName = 'Courier New';
  FontSize = 8;
  HintMargin = 4;
  HintText = 'min';
var
  I, J, K, L, M: Integer;
  Data: PFormulaData;
  Cursor: TPoint;
  C: TColor;
  Extent: TSize;
  PointArray: TCurveIArray;
begin
  if FEngine.Extreme then
  begin
    for I := 0 to FEngine.Formula.Count - 1 do if FEngine.Formula.Active[I] then
    begin
      Data := FEngine.Formula.Data[I];
      if Assigned(Data) then for J := Data.MinBack.ArrayIndex to Data.MinFace.ArrayIndex do
        if GetRange(FEngine.MinArray, Data.MinBack, Data.MinFace, J, L, M) then
          for K := L to M do
          begin
            Cursor := PointI(PointToCursor(FEngine.MinArray[J, K]));
            try
              if FMulticolor then
                C := Data.Color
              else
                C := clBlack;
              Target.Font.Name := FontName;
              Target.Font.Size := FontSize;
              Target.Font.Color := C;
              Extent := Target.TextExtent(HintText);
              Target.TextOut(Cursor.X - Extent.cx div 2, Cursor.Y - SmallMarkerMargin div 2 - HintMargin - Extent.cy, HintText);
              CrossGraph.Types.Add(PointArray, Point(Cursor.X, Cursor.Y + SmallMarkerMargin));
              CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
              CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
              CrossGraph.Types.Add(PointArray, Point(Cursor.X, Cursor.Y + SmallMarkerMargin));
              DrawPointArray(Target, PointArray, FMarkerPen, False, nil, nil, @C);
            finally
              PointArray := nil;
            end;
          end;
    end;
  end;
end;

procedure TGraph.DrawOverlap(const Target: TCanvas);
const
  FontName = 'Courier New';
  FontSize = 8;
  NameMargin = 6;
var
  I, J, K: Integer;
  FD1, FD2: PFormulaData;
  Cursor: TPoint;
  PointArray: TCurveIArray;
  S: string;
  Extent: TSize;
begin
  if FEngine.Overlap and (FEngine.Formula.ActiveCount > 1) then
  begin
    for I := Low(FEngine.OverlapArray) to High(FEngine.OverlapArray) do
    begin
      J := FEngine.OverlapArray[I].AFormula;
      K := FEngine.OverlapArray[I].BFormula;
      FD1 := FEngine.Formula.Data[J];
      FD2 := FEngine.Formula.Data[K];
      if FEngine.Formula.Active[J] and FEngine.Formula.Active[K] and Assigned(FD1) and Assigned(FD2) then
      begin
        Cursor := PointI(PointToCursor(FEngine.OverlapArray[I].Point));
        try
          CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
          CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
          CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
          DrawPointArray(Target, PointArray, FMarkerPen, False, nil, nil, @FD1.Color);
          PointArray := nil;
          CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
          CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
          CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
          DrawPointArray(Target, PointArray, FMarkerPen);
          DrawPointArray(Target, PointArray, FMarkerPen, False, nil, nil, @FD2.Color);
          PointArray := nil;
          CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
          CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
          DrawPointArray(Target, PointArray, FMarkerPen, False, nil, nil, @FD1.Color);
          PointArray := nil;
          CrossGraph.Types.Add(PointArray, Point(Cursor.X + SmallMarkerMargin, Cursor.Y + SmallMarkerMargin));
          CrossGraph.Types.Add(PointArray, Point(Cursor.X - SmallMarkerMargin, Cursor.Y - SmallMarkerMargin));
          DrawPointArray(Target, PointArray, FMarkerPen, False, nil, nil, @FD2.Color);
          Target.Font.Name := FontName;
          Target.Font.Size := FontSize;
          Target.Font.Color := clBlack;
          S := OverlapName[I];
          Extent := Target.TextExtent(S);
          Target.TextOut(Cursor.X - Extent.cx div 2, Cursor.Y + SmallMarkerMargin div 2 + NameMargin, S);
        finally
          PointArray := nil;
        end;
      end;
    end;
  end;
end;

{$IFNDEF FPC}
function TGraph.DrawSmooth(const Target: TCanvas; const PointArray: TCurveIArray; const Entire: Boolean;
  const Back, Face: PPlace; const Color: PColor): Boolean;
var
  C: TColor;
  I: Integer;
  G: GpGraphics;
  P: GpPen;
begin
  Result := False;
  if not StartGdiPlus then Exit;
  G := nil;
  if (GdipCreateFromHDC(Target.Handle, G) <> Ok) or not Assigned(G) then Exit;
  try
    GdipSetCompositingQuality(G, CompositingQualityAssumeLinear);
    GdipSetInterpolationMode(G, InterpolationModeHighQuality);
    GdipSetSmoothingMode(G, SmoothingModeHighQuality);
    if Assigned(Color) then
      C := Color^
    else
      C := Target.Pen.Color;
    P := nil;
    if (GdipCreatePen1(ColorRefToARGB(C), Target.Pen.Width, UnitWorld, P) <> Ok) or not Assigned(P) then
      Exit;
    try
      if Entire then
        for I := Low(PointArray) to High(PointArray) do
          GdipDrawCurveI(G, P, PGPPoint(PointArray[I]), Length(PointArray[I]))
      else
        for I := Back.ArrayIndex to Face.ArrayIndex do
          GdipDrawCurveI(G, P, PGPPoint(PointArray[I]), Length(PointArray[I]));
      Result := True;
    finally
      GdipDeletePen(P);
    end;
  finally
    GdipDeleteGraphics(G);
  end;
end;
{$ENDIF}

function TGraph.DrawPointArray(const Target: TCanvas; const PointArray: TCurveIArray; const Pen: TPen;
  const Smooth: Boolean; const Back, Face: PPlace; const Color: PColor): Boolean;
const
  MaxLinePoints = 4000;
  MaxSmoothJump = 64;
var
  Entire, Done: Boolean;
  C: TColor;
  I: Integer;
  Draw: TCurveIArray;

  procedure Thin(const Line: TPointIArray);
  var
    Len, Stride, K, N, Slot: Integer;
  begin
    Len := Length(Line);
    if Len = 0 then Exit;
    Stride := (Len + MaxLinePoints - 1) div MaxLinePoints;
    if Stride < 1 then Stride := 1;
    Slot := Length(Draw);
    SetLength(Draw, Slot + 1);
    SetLength(Draw[Slot], Len div Stride + 2);
    N := 0;
    K := 0;
    while K < Len do
    begin
      Draw[Slot][N] := Line[K];
      Inc(N);
      if K = Len - 1 then Break;
      Inc(K, Stride);
      if K > Len - 1 then K := Len - 1;
    end;
    SetLength(Draw[Slot], N);
  end;

  function Jumpy(const Line: TPointIArray): Boolean;
  var
    K: Integer;
  begin
    Result := True;
    for K := Low(Line) + 1 to High(Line) do
      if (Abs(Line[K].X - Line[K - 1].X) > MaxSmoothJump) or (Abs(Line[K].Y - Line[K - 1].Y) > MaxSmoothJump) then
        Exit;
    Result := False;
  end;

  function Smoothable: Boolean;
  var
    K: Integer;
  begin
    Result := False;
    for K := Low(Draw) to High(Draw) do
      if Jumpy(Draw[K]) then Exit;
    Result := True;
  end;

begin
  Entire := not Assigned(Back) or not Assigned(Face);
  Result := Assigned(PointArray) and (Entire or not Entire and not Empty(Back^, Face^) and
    Check(PointArray, Back^) and Check(PointArray, Face^));
  if Result then
  begin
    if Assigned(Pen) then Target.Pen := Pen;
    Draw := nil;
    if Entire then
      for I := Low(PointArray) to High(PointArray) do Thin(PointArray[I])
    else
      for I := Back.ArrayIndex to Face.ArrayIndex do Thin(PointArray[I]);
    Done := False;
    {$IFNDEF FPC}
    if FAntialias and Smooth and Smoothable then
      Done := DrawSmooth(Target, Draw, True, nil, nil, Color);
    {$ENDIF}
    if not Done then
    begin
      C := Target.Pen.Color;
      try
        if Assigned(Color) then Target.Pen.Color := Color^;
        for I := Low(Draw) to High(Draw) do Target.Polyline(Draw[I]);
      finally
        Target.Pen.Color := C;
      end;
    end;
  end;
end;

procedure TGraph.DrawSign(const Mode: TRetrieveMode);
const
  XMargin = 3;
  YMargin = 3;
var
  Bitmap: TBitmap;
  I, J: Integer;
  AExtent, BExtent: TSize;
  APoint: TPoint;
  Data: PFormulaData;
  ARect: TRect;
begin
  if FSign and (FEngine.Formula.ActiveCount > 0) then
  begin
    Bitmap := TBitmap.Create;
    try
      Bitmap.PixelFormat := DefaultFormat;
      Bitmap.Canvas.Font.Assign(FSignFont);
      FillChar(AExtent, SizeOf(TSize), 0);
      for I := 0 to FEngine.Formula.Count - 1 do if FEngine.Formula.Active[I] then
      begin
        Data := FEngine.Formula.Data[I];
        if Assigned(Data) and Check(FEngine.SA, Data.ScriptIndex) then
        begin
          BExtent := Bitmap.Canvas.TextExtent(Parser.ScriptToString(FEngine.SA[Data.ScriptIndex], Mode));
          if AExtent.cx < BExtent.cx + XMargin then AExtent.cx := BExtent.cx + XMargin;
          if AExtent.cy < BExtent.cy + YMargin then AExtent.cy := BExtent.cy + YMargin;
        end;
      end;
      I := FEngine.Formula.ActiveCount * AExtent.cy;
      case FSignLayout of
        ltBottomLeft: APoint := Point(FSignMargin, ClientRect.Bottom - FSignMargin - I);
        ltBottomRight:
          APoint := Point(ClientRect.Right - FSignMargin - AExtent.cx, ClientRect.Bottom - FSignMargin - I);
        ltTopLeft: APoint := Point(FSignMargin, FSignMargin);
      else
        APoint := Point(ClientRect.Right - FSignMargin - AExtent.cx, FSignMargin);
      end;
      if APoint.X < 0 then APoint.X := 0;
      if APoint.Y < 0 then APoint.Y := 0;
      if APoint.X + AExtent.cx > FBuffer.Width then
        Bitmap.Width := FBuffer.Width - APoint.X
      else
        Bitmap.Width := AExtent.cx;
      if APoint.Y + I > FBuffer.Height then
        Bitmap.Height := FBuffer.Height - APoint.Y
      else
        Bitmap.Height := I;
      J := 0;
      for I := 0 to FEngine.Formula.Count - 1 do if FEngine.Formula.Active[I] then
      begin
        Data := FEngine.Formula.Data[I];
        if Assigned(Data) and Check(FEngine.SA, Data.ScriptIndex) then
        begin
          ARect := Rect(0, J, AExtent.cx, J + AExtent.cy);
          Bitmap.Canvas.Brush.Color := Data.Color;
          Bitmap.Canvas.FillRect(ARect);
          BExtent := Bitmap.Canvas.TextExtent(FEngine.Formula[I]);
          Bitmap.Canvas.TextRect(ARect, XMargin div 2, ARect.Top + ((ARect.Bottom - ARect.Top) - BExtent.cy) div 2,
            Parser.ScriptToString(FEngine.SA[Data.ScriptIndex], Mode));
          Inc(J, AExtent.cy);
        end;
      end;
      DrawBitmap(Bitmap, APoint, FSignBlendValue);
    finally
      Bitmap.Free;
    end;
  end;
end;

procedure TGraph.DrawText(const S: string; const Font: TFont; const Background: TColor;
  const Layout: TLayoutType; const Margin: Integer; const BlendValue: Byte);
var
  Bitmap: TBitmap;
  Extent: TSize;
  Point: TPoint;
begin
  Bitmap := TBitmap.Create;
  try
    Bitmap.PixelFormat := DefaultFormat;
    Bitmap.Canvas.Font.Assign(Font);
    Extent := Bitmap.Canvas.TextExtent(S);
    if (Extent.cx > 0) and (Extent.cy > 0) then
    begin
      case Layout of
        ltBottomLeft: Point := Types.Point(Margin, ClientRect.Bottom - Margin - Extent.cy);
        ltBottomRight:
          Point := Types.Point(ClientRect.Right - Margin - Extent.cx, ClientRect.Bottom - Margin - Extent.cy);
        ltTopLeft: Point := Types.Point(Margin, Margin);
      else
        Point := Types.Point(ClientRect.Right - Margin - Extent.cx, Margin);
      end;
      if Point.X < 0 then Point.X := 0;
      if Point.Y < 0 then Point.Y := 0;
      if Point.X + Extent.cx > FBuffer.Width then
        Bitmap.Width := FBuffer.Width - Point.X
      else
        Bitmap.Width := Extent.cx;
      if Point.Y + Extent.cy > FBuffer.Height then
        Bitmap.Height := FBuffer.Height - Point.Y
      else
        Bitmap.Height := Extent.cy;
      Bitmap.Canvas.Brush.Color := Background;
      Bitmap.Canvas.FillRect(Rect(0, 0, Bitmap.Width, Bitmap.Height));
      Bitmap.Canvas.TextOut(0, 0, S);
      DrawBitmap(Bitmap, Point, BlendValue);
    end;
  finally
    Bitmap.Free;
  end;
end;

function TGraph.Examine(const Point: TPointD): Boolean;
begin
  Result := FEngine.Examine(Point);
end;

function TGraph.FloatFormat(const Format: string): string;
begin
  if FEngine.HighPrecision then
    Result := FPrecisionFormat
  else
    Result := Format;
end;

function TGraph.FloatFormat(const Scale: Extended; const Count: Integer): string;
const
  Template = '0.';
begin
  Result := Template + DupeString('0', FracSize(Scale) + Count);
end;

function TGraph.GetBusy: Boolean;
begin
  Result := FEngine.Busy;
end;

function TGraph.GetCompute(const CS: TCoordinateSystem): TComputeMethod;
begin
  if CS = csPolar then
    Result := FEngine.ComputePolar
  else
    Result := FEngine.ComputeRectangular;
end;

function TGraph.GetDisplay: TDisplay;
begin
  Result := FEngine.Display;
end;

function TGraph.GetMaxZoom: Extended;
begin
  Result := FMaxZoom[FEngine.CS];
end;

function TGraph.GetMinZoom: Extended;
begin
  Result := FMinZoom[FEngine.CS];
end;

function TGraph.GetOverlapMaxDepth: Integer;
begin
  Result := FEngine.OverlapMaxDepth;
end;

function TGraph.GetOverlapTotal: Integer;
begin
  Result := FEngine.OverlapTotal;
end;

function TGraph.GetSameArray: TSameArray;
begin
  Result := FEngine.SameArray;
end;

function TGraph.GetMarkSpacing: Integer;
begin
  Result := FEngine.MarkSpacing;
end;

procedure TGraph.SetMarkSpacing(const Value: Integer);
begin
  if FEngine.MarkSpacing = Value then Exit;
  FEngine.MarkSpacing := Value;
  FEngine.StartOverlap;
end;

function TGraph.GetOverlapMaxTime: Integer;
begin
  Result := FEngine.OverlapMaxTime;
end;

function TGraph.GetOverlapName(const Index: Integer): string;
const
  Digits = 1;
begin
  if FOverlapNameNumeration < 0 then
    Result := IntToHex(Index, Digits)
  else
    Result := FNumeration.ConvertTo(Index, FOverlapNameNumeration);
end;

function TGraph.GetPolarRangeArray: CrossGraph.Engine.TRangeArray;
begin
  Result := FEngine.PolarRangeArray;
end;

function TGraph.GetThreadCount: Integer;
begin
  Result := FEngine.ThreadCount;
end;

procedure TGraph.Invalidate;
begin
  inherited;
  Prepare;
end;

function TGraph.MarkPoint(const Point: TPointD; var PointArray: TCurveIArray): Boolean;
var
  Cursor: TPointD;
begin
  Result := Examine(Point);
  if Result then
  begin
    Cursor := PointToCursor(Point);
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin)));
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X - SmallMarkerMargin, Cursor.Y - SmallMarkerMargin)));
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X + SmallMarkerMargin, Cursor.Y - SmallMarkerMargin)));
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X + SmallMarkerMargin, Cursor.Y + SmallMarkerMargin)));
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin)));
    New(PointArray);
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X - SmallMarkerMargin, Cursor.Y + SmallMarkerMargin)));
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X + SmallMarkerMargin, Cursor.Y - SmallMarkerMargin)));
    CrossGraph.Types.New(PointArray);
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X + SmallMarkerMargin, Cursor.Y + SmallMarkerMargin)));
    CrossGraph.Types.Add(PointArray, PointI(PointD(Cursor.X - SmallMarkerMargin, Cursor.Y - SmallMarkerMargin)));
    CrossGraph.Types.New(PointArray);
  end;
end;

procedure TGraph.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Inactive then
  begin
    SetFocus;
    Exit;
  end;
  inherited;
  if Available and not FMoving then
  begin
    FMoving := True;
    FPivotPoint := PointD(XToPoint(X), YToPoint(Y));
  end;
end;

procedure TGraph.MouseMove(Shift: TShiftState; X, Y: Integer);
type
  TRemote = record
    Shift: Extended;
    Point: TPointD;
    Alive: Boolean;
  end;

  TRemoteType = (rtFace, rtBack);

  function MakeRemoteType(const Value: Boolean): TRemoteType;
  begin
    if Value then
      Result := rtFace
    else
      Result := rtBack;
  end;

  function MakeRemote(const AShift: Extended; const APoint: TPointD; const AAlive: Boolean): TRemote;
  begin
    FillChar(Result, SizeOf(TRemote), 0);
    with Result do
    begin
      Shift := AShift;
      Point := APoint;
      Alive := AAlive;
    end;
  end;

var
  Remote: array[TRemoteType] of TRemote;
  I: Integer;
  Data: PFormulaData;
  AShift, Float, Angle: Extended;
  APoint, BPoint: TPointD;
  J: TRemoteType;
  PointArray: TPointDArray;
  AngleArray: {$IFDEF DELPHI_10.2}TArray<Extended>{$ELSE}TExtendedDynArray{$ENDIF};
  Display: TDisplay;
begin
  inherited;
  if Available then
    if FMoving then
    begin
      if ssRight in Shift then
        FEngine.Offset := PointD(FEngine.Offset.X + XToPoint(X), FEngine.Offset.Y + YToPoint(Y))
      else
        FEngine.Offset := PointD(FEngine.Offset.X - FPivotPoint.X + XToPoint(X), FEngine.Offset.Y - FPivotPoint.Y + YToPoint(Y));
      DoOffsetChange;
      Build;
    end
    else begin
      if FTracing and Assigned(FEngine.SA) then
      begin
        CrossGraph.Types.Delete(FTraceArray);
        FillChar(Remote, SizeOf(Remote), 0);
        case FEngine.CS of
          csRectangular:
            if FEngine.Formula.ActiveCount > 0 then
            begin
              for I := 0 to FEngine.Formula.Count - 1 do
                if FEngine.Formula.Active[I] and FEngine.Formula.Tracing[I] then
                begin
                  Data := FEngine.Formula.Data[I];
                  if Assigned(Data) and Check(FEngine.SA, Data.ScriptIndex) then
                  begin
                    FCursorValue.Float80 := XToPoint(X);
                    APoint := ComputeRectangular(FCursorValue.Float80, FEngine.SA[Data.ScriptIndex]);
                    if Examine(APoint) then
                    begin
                      Remote[rtFace].Alive := True;
                      CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(PointD(FEngine.Min.X, APoint.Y))));
                      CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(PointD(FEngine.Max.X, APoint.Y))));
                      CrossGraph.Types.New(FTraceArray);
                      DoTrace(I, APoint);
                    end;
                  end;
                end;
              if Remote[rtFace].Alive then
              begin
                CrossGraph.Types.Add(FTraceArray, Point(X, Round(YToCursor(FEngine.Max.Y))));
                CrossGraph.Types.Add(FTraceArray, Point(X, Round(YToCursor(FEngine.Min.Y))));
                CrossGraph.Types.New(FTraceArray);
              end;
            end;
        else
          if FEngine.Formula.ActiveCount > 0 then
          begin
            for I := 0 to FEngine.Formula.Count - 1 do
              if FEngine.Formula.Active[I] and FEngine.Formula.Tracing[I] then
              begin
                Data := FEngine.Formula.Data[I];
                if Assigned(Data) and Check(FEngine.SA, Data.ScriptIndex) then
                begin
                  FCursorValue.Float80 := VertexAngle(PointD(FEngine.MaxX, 0), ZeroPoint, CursorToPoint(PointD(X, Y)));
                  if Above(Y, YToCursor(0), FEngine.Epsilon) then
                    FCursorValue.Float80 := Angle360 - FCursorValue.Float80;
                  PointArray := nil;
                  AngleArray := nil;
                  try
                    Float := FCursorValue.Float80;
                    Angle := 0;
                    while Below(Float + Angle, FEngine.PolarMaxAngle) do
                    begin
                      FCursorValue.Float80 := Float + Angle;
                      APoint := ComputePolar(FCursorValue.Float80, FEngine.SA[Data.ScriptIndex]);
                      if Examine(APoint) then
                      begin
                        Display := GetDisplay;
                        case Display.QuarterKind of
                          qkA:
                            BPoint := PointAtAngle(APoint, CounterClockwise(qtA, LineAngle(APoint, ZeroPoint)),
                              -DistanceOf(APoint, FEngine.Min));
                          qkB:
                            BPoint := PointAtAngle(APoint, CounterClockwise(qtB, LineAngle(APoint, ZeroPoint)),
                              -DistanceOf(APoint, PointD(FEngine.Max.X, FEngine.Min.Y)));
                          qkC:
                            BPoint := PointAtAngle(APoint, CounterClockwise(qtC, LineAngle(APoint, ZeroPoint)),
                              -DistanceOf(APoint, FEngine.Max));
                          qkD:
                            BPoint := PointAtAngle(APoint, CounterClockwise(qtD, LineAngle(APoint, ZeroPoint)),
                              -DistanceOf(APoint, PointD(FEngine.Min.X, FEngine.Max.Y)));
                          qkAB:
                            BPoint := LinesCross(APoint, ZeroPoint, FEngine.Min, PointD(FEngine.Max.X, FEngine.Min.Y));
                          qkBC:
                            BPoint := LinesCross(APoint, ZeroPoint, FEngine.Max, PointD(FEngine.Max.X, FEngine.Min.Y));
                          qkCD:
                            BPoint := LinesCross(APoint, ZeroPoint, PointD(FEngine.Min.X, FEngine.Max.Y),
                              FEngine.Max);
                          qkDA:
                            BPoint := LinesCross(APoint, ZeroPoint, FEngine.Min, PointD(FEngine.Min.X, FEngine.Max.Y));
                          qkABCD: BPoint := ZeroPoint;
                        end;
                        if Equal(APoint.Y, 0, FEngine.Epsilon) then
                          J := MakeRemoteType(Above(APoint.X, 0, FEngine.Epsilon))
                        else
                          J := MakeRemoteType(Above(APoint.Y, 0, FEngine.Epsilon));
                        AShift := DistanceOf(APoint, BPoint);
                        if Above(AShift, Remote[J].Shift, FEngine.Epsilon) then
                          Remote[J] := MakeRemote(AShift, APoint, True);
                        CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(PointD(FEngine.Min.X, APoint.Y))));
                        CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(PointD(FEngine.Max.X, APoint.Y))));
                        CrossGraph.Types.New(FTraceArray);
                        CrossGraph.Types.Add(PointArray, APoint);
                        Add(AngleArray, FCursorValue.Float80);
                      end;
                      Angle := Angle + Angle360;
                    end;
                    DoTrace(I, AngleArray, PointArray);
                  finally
                    PointArray := nil;
                    AngleArray := nil;
                  end;
                end;
                if Remote[rtFace].Alive and Remote[rtBack].Alive then
                begin
                  CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(Remote[rtFace].Point)));
                  CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(Remote[rtBack].Point)));
                  CrossGraph.Types.New(FTraceArray);
                end
                else if Remote[rtFace].Alive then
                begin
                  CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(BPoint)));
                  CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(Remote[rtFace].Point)));
                  CrossGraph.Types.New(FTraceArray);
                end
                else if Remote[rtBack].Alive then
                begin
                  CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(BPoint)));
                  CrossGraph.Types.Add(FTraceArray, PointI(PointToCursor(Remote[rtBack].Point)));
                  CrossGraph.Types.New(FTraceArray);
                end;
              end;
          end;
        end;
        DoTraceDone;
        inherited Invalidate;
      end;
    end;
end;

procedure TGraph.MakeColor(const Formula: Integer);
begin
  FEngine.Formula.Data[Formula].Color := TColor(RGB(Random(MaxByte + 1), Random(MaxByte + 1), Random(MaxByte + 1)));
end;

procedure TGraph.MakeZoom(const ZoomType: TZoomType);
begin
  FZoomTimer.ZoomType := ZoomType;
  FZoomTimer.SetTimer;
end;

procedure TGraph.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Available and FMoving then FMoving := False;
end;

function TGraph.Inactive: Boolean;
begin
  Result := not Focused and Showing and CanFocus;
end;

procedure TGraph.UpdateCursor;
var
  Point: TPoint;
begin
  if HandleAllocated and GetCursorPos(Point) and PtInRect(ClientRect, ScreenToClient(Point)) then
    Perform(WM_SETCURSOR, WPARAM(Handle), MakeLong(HTCLIENT, WM_MOUSEMOVE));
end;

procedure TGraph.CMEnter(var Message: TMessage);
begin
  inherited;
  UpdateCursor;
end;

procedure TGraph.CMExit(var Message: TMessage);
begin
  inherited;
  UpdateCursor;
end;

procedure TGraph.WMSetCursor(var Message: TWMSetCursor);
begin
  if (Message.HitTest = HTCLIENT) and (Message.CursorWnd = Handle) and (Screen.Cursor = crDefault) and
    Inactive then
    begin
      {$IFDEF FPC}
      LCLIntf.SetCursor(Screen.Cursors[crArrow]);
      {$ELSE}
      {$IFDEF DELPHI_XE7}
      Winapi.Windows.SetCursor(Screen.Cursors[crArrow]);
      {$ELSE}
      Windows.SetCursor(Screen.Cursors[crArrow]);
      {$ENDIF}
      {$ENDIF}
      Message.Result := 1;
    end
    else
      inherited;
end;

procedure TGraph.Notification(Component: TComponent; Operation: TOperation);
begin
  inherited;
  if Available and (Operation = opRemove) and (Component = FEngine.Parser) then SetParser(nil);
end;

procedure TGraph.Paint;

  procedure DrawLine(const Angle: Extended);
  var
    APoint, BPoint: TPointD;
  begin
    if Equal(Angle, 0) then
    begin
      APoint := PointD(FEngine.Min.X, 0);
      BPoint := PointD(FEngine.Max.X, 0);
    end
    else begin
      APoint := LinesCross(FEngine.Min, PointD(FEngine.Max.X, FEngine.Min.Y), ZeroPoint, PointAtAngle(ZeroPoint, Angle, 1));
      BPoint := LinesCross(PointD(FEngine.Min.X, FEngine.Max.Y), FEngine.Max, ZeroPoint, APoint);
    end;
    FBuffer.Canvas.MoveTo(Round(XToCursor(APoint.X)), Round((YToCursor(APoint.Y))));
    FBuffer.Canvas.LineTo(Round(XToCursor(BPoint.X)), Round((YToCursor(BPoint.Y))));
  end;

const
  MaxLC = 500;
  XText = 'X';
  YText = 'Y';
  TextMargin = 20;
var
  I: Integer;
  APoint, BPoint, CPoint: TPointD;
  Display: TDisplay;
  S: string;
begin
  if FSilent then Exit;
  DrawCount := 0;
  inherited;
  if Available then
  begin
    FBuffer.SetSize(FSize.cx, FSize.cy);
    FBuffer.Canvas.Brush.Color := Color;
    FBuffer.Canvas.FillRect(Rect(0, 0, FBuffer.Width, FBuffer.Height));
    if FShowGrid then
    begin
      I := Round(FEngine.MaxX / FHSpacing + FEngine.MaxY / FVSpacing);
      if I < MaxLC then
        case FEngine.CS of
          csRectangular:
            begin
              FBuffer.Canvas.Pen.Assign(FGridPen);
              I := FBuffer.Canvas.Pen.Width;
              if FShowAxis then
                APoint := PointD(-FHSpacing, -FVSpacing)
              else
                APoint := ZeroPoint;
              while AboveOrEqual(APoint.X, FEngine.Min.X, FEngine.Epsilon) do
              begin
                FBuffer.Canvas.MoveTo(Round(XToCursor(APoint.X)), Round(YToCursor(FEngine.Min.Y)));
                FBuffer.Canvas.LineTo(Round(XToCursor(APoint.X)), Round(YToCursor(FEngine.Max.Y)));
                APoint.X := APoint.X - FHSpacing;
              end;
              while AboveOrEqual(APoint.Y, FEngine.Min.Y, FEngine.Epsilon) do
              begin
                FBuffer.Canvas.MoveTo(Round(XToCursor(FEngine.Min.X)), Round(YToCursor(APoint.Y)) - I);
                FBuffer.Canvas.LineTo(Round(XToCursor(FEngine.Max.X)), Round(YToCursor(APoint.Y)) - I);
                APoint.Y := APoint.Y - FVSpacing;
              end;
              APoint := PointD(FHSpacing, FVSpacing);
              while BelowOrEqual(APoint.X, FEngine.Max.X, FEngine.Epsilon) do
              begin
                FBuffer.Canvas.MoveTo(Round(XToCursor(APoint.X) - I), Round(YToCursor(FEngine.Min.Y)));
                FBuffer.Canvas.LineTo(Round(XToCursor(APoint.X) - I), Round(YToCursor(FEngine.Max.Y)));
                APoint.X := APoint.X + FHSpacing;
              end;
              while BelowOrEqual(APoint.Y, FEngine.Max.Y, FEngine.Epsilon) do
              begin
                FBuffer.Canvas.MoveTo(Round(XToCursor(FEngine.Min.X)), Round(YToCursor(APoint.Y)));
                FBuffer.Canvas.LineTo(Round(XToCursor(FEngine.Max.X)), Round(YToCursor(APoint.Y)));
                APoint.Y := APoint.Y + FVSpacing;
              end;
            end;
        else
          FBuffer.Canvas.Pen.Assign(FPolarAxisPen);
          FBuffer.Canvas.Pen.Assign(FPolarAxisPen);
          DrawLine(Pi / 4);
          DrawLine(Pi * 3 / 4);
          FBuffer.Canvas.Pen.Assign(FGridPen);
          DrawLine(Pi / 8);
          DrawLine(Angle540 / 8);
          DrawLine(Pi * 5 / 8);
          DrawLine(Pi * 7 / 8);
          Display := GetDisplay;
          if Above(Display.FromCenter[dtMin], 0, FEngine.Epsilon) then
            APoint := PointD(NextStep(Display.FromCenter[dtMin], FHSpacing, 1), NextStep(Display.FromCenter[dtMin], FVSpacing, 1))
          else
            APoint := PointD(FHSpacing, FVSpacing);
          FBuffer.Canvas.Brush.Style := bsClear;
          while BelowOrEqual(APoint.X, Display.FromCenter[dtMax], FEngine.Epsilon) and BelowOrEqual(APoint.Y, Display.FromCenter[dtMax], FEngine.Epsilon) do
          begin
            FBuffer.Canvas.Ellipse(Round(XToCursor(-APoint.X)), Round(YToCursor(-APoint.Y)), Round(XToCursor(APoint.X)),
              Round(YToCursor(APoint.Y)));
            APoint.X := APoint.X + FHSpacing;
            APoint.Y := APoint.Y + FVSpacing;
          end;
        end;
    end;
    if FShowAxis then
    begin
      FBuffer.Canvas.Pen.Assign(FAxisPen);
      FBuffer.Canvas.MoveTo(Round(XToCursor(0)), Round(YToCursor(FEngine.Min.Y)));
      FBuffer.Canvas.LineTo(Round(XToCursor(0)), Round(YToCursor(FEngine.Max.Y)));
      FBuffer.Canvas.MoveTo(Round(XToCursor(FEngine.Min.X)), Round(YToCursor(0)));
      FBuffer.Canvas.LineTo(Round(XToCursor(FEngine.Max.X)), Round(YToCursor(0)));
      FBuffer.Canvas.Brush.Color := FBuffer.Canvas.Pen.Color;
      APoint := PointD(XToCursor(FEngine.Max.X) - FAxisArrow.cx, YToCursor(0) - FAxisArrow.cy);
      BPoint := PointD(XToCursor(FEngine.Max.X), YToCursor(0));
      CPoint := PointD(XToCursor(FEngine.Max.X) - FAxisArrow.cx, YToCursor(0) + FAxisArrow.cy);
      FBuffer.Canvas.Polygon([PointI(APoint), PointI(BPoint), PointI(CPoint)]);
      APoint := PointD(XToCursor(0) - FAxisArrow.cy, YToCursor(FEngine.Max.Y) + FAxisArrow.cx);
      BPoint := PointD(XToCursor(0), YToCursor(FEngine.Max.Y));
      CPoint := PointD(XToCursor(0) + FAxisArrow.cy, YToCursor(FEngine.Max.Y) + FAxisArrow.cx);
      FBuffer.Canvas.Polygon([PointI(APoint), PointI(BPoint), PointI(CPoint)]);
      FBuffer.Canvas.Brush.Style := bsClear;
      FBuffer.Canvas.Font.Assign(FAxisFont);
      FBuffer.Canvas.TextOut(Round(XToCursor(FEngine.Max.X)) - FBuffer.Canvas.TextWidth(XText),
        Round(YToCursor(0)) - TextMargin - FBuffer.Canvas.TextHeight(XText), XText);
      S := FormatFloat(FloatFormat(FXFormat), FEngine.Max.X);
      FBuffer.Canvas.TextOut(FSize.cx - FBuffer.Canvas.TextWidth(S), Round(FEngine.Center.Y) + TextMargin, S);
      S := FormatFloat(FloatFormat(FXFormat), FEngine.Min.X);
      FBuffer.Canvas.TextOut(0, Round(FEngine.Center.Y) + TextMargin, S);
      FBuffer.Canvas.TextOut(Round(XToCursor(0)) - TextMargin - FBuffer.Canvas.TextWidth(YText), Round(YToCursor(FEngine.Max.Y)), YText);
      S := FormatFloat(FloatFormat(FYFormat), FEngine.Max.Y);
      FBuffer.Canvas.TextOut(Round(FEngine.Center.X) + TextMargin, 0, S);
      S := FormatFloat(FloatFormat(FYFormat), FEngine.Min.Y);
      FBuffer.Canvas.TextOut(Round(FEngine.Center.X) + TextMargin, FSize.cy - FBuffer.Canvas.TextHeight(S), S);
    end;
    DrawFormula(FBuffer.Canvas);
    DrawOverlap(FBuffer.Canvas);
    DrawMaximum(FBuffer.Canvas);
    DrawMinimum(FBuffer.Canvas);
    DrawSign;
    if Trim(FEngine.ErrorMessage) <> '' then
      DrawText(FEngine.ErrorMessage, FTextFont, FTextBackground, FTextLayout, FTextMargin, FTextBlendValue);
    if Assigned(FTraceArray) then DrawPointArray(FBuffer.Canvas, FTraceArray, FTracePen);
    Canvas.Draw(0, 0, FBuffer);
  end;
end;

procedure TGraph.Parse;
var
  I, J: Integer;
  Data: PFormulaData;
begin
  DoBeforeParse;
  CrossGraph.Types.Delete(FTraceArray);
  FEngine.Parse;
  Capture;
  for I := 0 to FEngine.Formula.Count - 1 do
  begin
    Data := FEngine.Formula.Data[I];
    if not Assigned(Data) then Continue;
    if Length(FColorArray) > 0 then
    begin
      J := I;
      while J >= Length(FColorArray) do Dec(J, Length(FColorArray));
      Data.Color := FColorArray[J];
    end;
    Data.CursorBack := MakePlace(Data.EntireBack.ArrayIndex, 0);
    if (Data.EntireFace.ArrayIndex >= 0) and (Data.EntireFace.ArrayIndex < Length(FCursorArray)) then
      Data.CursorFace := MakePlace(Data.EntireFace.ArrayIndex, High(FCursorArray[Data.EntireFace.ArrayIndex]))
    else
      Data.CursorFace := MakePlace(Data.EntireFace.ArrayIndex, -1);
  end;
  DoAfterParse;
end;

function TGraph.PointCount(const Segment: PExtended): Extended;
begin
  Result := FEngine.PointCount(Segment);
end;

function TGraph.PointToCursor(const Point: TPoint): TPoint;
begin
  Result := PointI(PointToCursor(PointD(Point)));
end;

procedure TGraph.Prepare;
var
  Resolution: Extended;
  Display: TDisplay;
begin
  FSize := CalcSize;
  FEngine.Size := FSize;
  FEngine.Prepare;
  FXFactor := FEngine.Center.X / FEngine.MaxX;
  FYFactor := FEngine.Center.Y / FEngine.MaxY;
  if FAutoVary or FAutoVoid then
  begin
    Resolution := DistanceOf(CursorToPoint(PointD(0, 0)), CursorToPoint(PointD(1, 1)));
    if FAutoVary then FEngine.ExtremeVaryRadius := ExtremeVaryFactor * Resolution;
    if FAutoVoid then FEngine.ExtremeVoidRadius := ExtremeVoidFactor * Resolution;
  end;
  FXFormat := FloatFormat(FEngine.MaxX, FXDigitCount);
  FYFormat := FloatFormat(FEngine.MaxY, FYDigitCount);
  if Length(FXFormat) > Length(FYFormat) then
    FXYFormat := FXFormat
  else
    FXYFormat := FYFormat;
  Display := GetDisplay;
  FAngleFormat := FloatFormat(Display.Range.Max - Display.Range.Min, FAngleDigitCount);
end;

function TGraph.PointToCursor(const Point: TPointD): TPointD;
begin
  Result.X := XToCursor(Point.X);
  Result.Y := YToCursor(Point.Y);
end;

procedure TGraph.Resize;
begin
  inherited;
  if not (csLoading in ComponentState) and Available then
  begin
    Prepare;
    FBuildTimer.SetTimer;
  end;
end;

procedure TGraph.SetExtreme(const Value: Boolean);
begin
  FEngine.Extreme := Value;
  FEngine.StartExtreme;
end;

procedure TGraph.SetCS(const Value: TCoordinateSystem);
begin
  if FEngine.CS <> Value then
  begin
    Clear;
    FEngine.CS := Value;
    Zoom(ztNone);
  end;
end;

procedure TGraph.SetFormula(const Value: TFormulaList);
begin
  FEngine.Formula.Assign(Value);
end;

procedure TGraph.SetHighPrecision(const Value: Boolean);
begin
  if FEngine.HighPrecision <> Value then
  begin
    FEngine.HighPrecision := Value;
    FEngine.HighPrecision := Value;
  end;
end;

procedure TGraph.SetMaxZoom(const Value: Extended);
begin
  FMaxZoom[FEngine.CS] := Value;
end;

procedure TGraph.SetMinZoom(const Value: Extended);
begin
  FMinZoom[FEngine.CS] := Value;
  if Below(FMinZoom[FEngine.CS], FEngine.Epsilon) then FEngine.Epsilon := FMinZoom[FEngine.CS];
end;

procedure TGraph.SetOffset(const Value: TPointD);
begin
  FEngine.Offset := Value;
  DoOffsetChange;
  Prepare;
end;

procedure TGraph.SetOverlap(const Value: Boolean);
begin
  FEngine.Overlap := Value;
  FEngine.StartOverlap;
end;

procedure TGraph.SetOverlapMaxDepth(const Value: Integer);
begin
  FEngine.OverlapMaxDepth := Value;
end;

procedure TGraph.SetOverlapMaxTime(const Value: Integer);
begin
  FEngine.OverlapMaxTime := Value;
end;

procedure TGraph.SetParser(const Value: TParser);
begin
  FEngine.Parser := Value;
end;

procedure TGraph.SetThreadCount(const Value: Integer);
begin
  FEngine.ThreadCount := Value;
end;

procedure TGraph.SetThreadWorkTime(const Value: LongWord);
begin
  FEngine.ThreadWorkTime := Value;
end;

procedure TGraph.Stop;
begin
  FEngine.Stop;
end;

function TGraph.WaitFor(const Thread: TThread; const Time: LongWord): Boolean;
begin
  Result := FEngine.WaitFor(Thread, Time);
end;

procedure TGraph.WndProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_INVALIDATE:
      case Message.WParam of
        OverlapCode:
          if Available then
          begin
            FEngine.TakeOverlap;
            if not FSilent then
            begin
              inherited Invalidate;
            end;
            DoOverlap;
          end;
        ExtremeCode:
          if Available then
          begin
            FEngine.TakeExtreme;
            if not FSilent then
            begin
              inherited Invalidate;
            end;
            DoExtreme;
          end;
      end;
    CM_INVALIDATE:
      if Available and not FSilent then
      begin
        if HandleAllocated and IsWindowVisible(Handle) then
          inherited
        else
          Paint;
      end;
  else
    inherited;
  end;
end;

function TGraph.XToCursor(const X: Extended): Extended;
begin
  Result := FEngine.XToCursor(X);
end;

function TGraph.XToPoint(const X: Extended): Extended;
begin
  Result := FEngine.XToPoint(X);
end;

function TGraph.YToCursor(const Y: Extended): Extended;
begin
  Result := FEngine.YToCursor(Y);
end;

function TGraph.YToPoint(const Y: Extended): Extended;
begin
  Result := FEngine.YToPoint(Y);
end;

procedure TGraph.Zoom(const ZoomType: TZoomType; const Factor: Extended);
var
  AFactor: Extended;
begin
  case ZoomType of
    ztIn:
      begin
        if Below(Factor, 0) then
          AFactor := ZoomInFactor
        else
          AFactor := Factor;
        if Above(FEngine.MaxX, 1 / FMaxZoom[FEngine.CS], FEngine.Epsilon) then
          FEngine.MaxX := EnsureRange(FEngine.MaxX - FEngine.MaxX * AFactor, 1 / FMaxZoom[FEngine.CS],
            1 / FMinZoom[FEngine.CS]);
        if Above(FEngine.MaxY, 1 / FMaxZoom[FEngine.CS], FEngine.Epsilon) then
          FEngine.MaxY := EnsureRange(FEngine.MaxY - FEngine.MaxY * AFactor, 1 / FMaxZoom[FEngine.CS],
            1 / FMinZoom[FEngine.CS]);
        FLeadTimer.SetTimer;
      end;
    ztOut:
      begin
        if Below(Factor, 0) then
          AFactor := ZoomOutFactor
        else
          AFactor := Factor;
        if Below(FEngine.MaxX, 1 / FMinZoom[FEngine.CS], FEngine.Epsilon) then
          FEngine.MaxX := EnsureRange(FEngine.MaxX + FEngine.MaxX * AFactor, 1 / FMaxZoom[FEngine.CS],
            1 / FMinZoom[FEngine.CS]);
        if Below(FEngine.MaxY, 1 / FMinZoom[FEngine.CS], FEngine.Epsilon) then
          FEngine.MaxY := EnsureRange(FEngine.MaxY + FEngine.MaxY * AFactor, 1 / FMaxZoom[FEngine.CS],
            1 / FMinZoom[FEngine.CS]);
        FLeadTimer.SetTimer;
      end;
  else
    if Below(FEngine.MaxX, 1 / FMaxZoom[FEngine.CS], FEngine.Epsilon) then
      FEngine.MaxX := 1 / FMaxZoom[FEngine.CS];
    if Below(FEngine.MaxY, 1 / FMaxZoom[FEngine.CS], FEngine.Epsilon) then
      FEngine.MaxY := 1 / FMaxZoom[FEngine.CS];
    if Above(FEngine.MaxX, 1 / FMinZoom[FEngine.CS], FEngine.Epsilon) then
      FEngine.MaxX := 1 / FMinZoom[FEngine.CS];
    if Above(FEngine.MaxY, 1 / FMinZoom[FEngine.CS], FEngine.Epsilon) then
      FEngine.MaxX := 1 / FMinZoom[FEngine.CS];
    Prepare;
    Build;
  end;
end;

end.
