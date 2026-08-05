{ ************************************************************************** }
{                                                                            }
{ CrossGraph.Engine                                                          }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

unit CrossGraph.Engine;

{$B-}
{$I Directives.inc}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  SysUtils, Classes, Contnrs, Types,
  {$ELSE}
  Winapi.Windows, System.SysUtils, System.Classes, System.Contnrs, System.Types,
  {$ENDIF}
  BaseTypes, FastList, TextConsts, NumberUtils, Parser, ParseJit.Parser, ParseTypes,
  Thread, ValueTypes, CrossVision.Geometry, CrossVision.Geometry.Types, CrossGraph.Types,
  CrossGraph.Geometry;

type
  PCoordinateSystem = ^TCoordinateSystem;
  TCoordinateSystem = (csRectangular, csPolar);

  PRange = ^TRange;
  TRange = record
    Min, Max: Extended;
  end;
  TRangeArray = array of TRange;

const
  WholeRange: TRange = (Min: 0; Max: Angle360);

type
  TQuarterKind = (qkA, qkB, qkC, qkD, qkAB, qkBC, qkCD, qkDA, qkABCD);

  TDistanceType = (dtMin, dtMax);
  TDisplay = record
    QuarterKind: TQuarterKind;
    Range: TRange;
    FromCenter: array[TDistanceType] of Extended;
  end;

  TConvertMethod = function(const Point: TPointD): TPointD of object;
  TComputeMethod = function(const Value: Extended; const Script: TScript): TPointD of object;
  TExamineMethod = function(const Point: TPointD): Boolean of object;

  TGraphEngine = class;

  TParseThread = class;
  TOverlapThread = class;
  TExtremeThread = class;

  TThreadList = class(TObjectList)
  private
    function GetItem(Index: Integer): TParseThread;
    procedure SetItem(Index: Integer; const Value: TParseThread);
  public
    property Items[Index: Integer]: TParseThread read GetItem write SetItem; default;
  end;

  PPlace = ^TPlace;
  TPlace = record
    ArrayIndex, Index: Integer;
  end;

  POverlap = ^TOverlap;
  TOverlap = record
    Point: TPointD;
    Range: TRange;
    AFormula: Integer;
    BFormula: Integer;
    Step: Extended;
    Argument: Extended;
    AAngle: Extended;
    BAngle: Extended;
  end;
  TOverlapArray = array of TOverlap;

  PSame = ^TSame;
  TSame = record
    Range: TRange;
    Back: TPointD;
    Face: TPointD;
    AFormula: Integer;
    BFormula: Integer;
  end;
  TSameArray = array of TSame;

  PFormulaData = ^TFormulaData;
  TFormulaData = record
    ScriptIndex: Integer;
    Visible, Corrent, Tracing: Boolean;
    EntireBack, EntireFace, CursorBack, CursorFace, MinBack, MinFace, MaxBack, MaxFace: TPlace;
    Color: TGraphColor;
  end;

  TFormulaList = class(TFastList)
  private
    FOnChanging: TThreadMethod;
    function GetActive(const Index: Integer): Boolean;
    function GetActiveCount: Integer;
    function GetCorrect(const Index: Integer): Boolean;
    function GetCorrectCount: Integer;
    function GetData(const Index: Integer): PFormulaData;
    function GetTracing(const Index: Integer): Boolean;
    function GetVisible(const Index: Integer): Boolean;
    function GetVisibleCount: Integer;
    procedure SetCorrect(const Index: Integer; const Value: Boolean);
    procedure SetTracing(const Index: Integer; const Value: Boolean);
    procedure SetVisible(const Index: Integer; const Value: Boolean);
  protected
    procedure InsertItem(Index: Integer; const S: string; AObject: TObject); override;
    procedure DataNeeded(const Index: Integer); virtual;
    procedure DeleteData(const Index: Integer); virtual;
  public
    constructor Create; override;
    destructor Destroy; override;
    function Add(const S: string;
      AVisible, ACorrect, ATracing: Boolean): Integer; reintroduce; overload; virtual;
    function AddObject(const S: string; AObject: TObject;
      AVisible, ACorrect, ATracing: Boolean): Integer; reintroduce; overload; virtual;
    function AddObject(const S: string; AObject: TObject): Integer; overload; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    property Data[const Index: Integer]: PFormulaData read GetData;
    property Visible[const Index: Integer]: Boolean read GetVisible write SetVisible;
    property VisibleCount: Integer read GetVisibleCount;
    property Correct[const Index: Integer]: Boolean read GetCorrect write SetCorrect;
    property CorrectCount: Integer read GetCorrectCount;
    property Tracing[const Index: Integer]: Boolean read GetTracing write SetTracing;
    property Active[const Index: Integer]: Boolean read GetActive;
    property ActiveCount: Integer read GetActiveCount;
    property OnChanging: TThreadMethod read FOnChanging write FOnChanging;
  end;

  PExchange = ^TExchange;
  TExchange = record
    OverlapArray: TOverlapArray;
    MaxArray: TCurveDArray;
    MinArray: TCurveDArray;
  end;

  TVariable = record
    Handle: NativeInt;
    Value: TValue;
  end;

  TJitEntryItem = record
    Script: TScript;
    Code: TJitScript;
  end;
  TJitEntryArray = array of TJitEntryItem;

  TFunction2 = array[0..1] of PFunction;

  TGraphThread = class(TThread)
  private
    FGlobalValue: PValue;
    FWorkTime: LongWord;
    FRedirectCategory: NativeInt;
    FLocalValue: TValue;
    FParser: TParser;
    FRedirectList: TList;
    FJitArray: TJitEntryArray;
    FJitEnabled: Boolean;
    function GetFloat80: PExtended;
    function GetEngine: TGraphEngine;
    procedure SetParser(const Value: TParser);
    procedure SetWorkTime(const Value: LongWord);
  protected
    procedure Done; override;
    procedure DeleteWorkData; virtual;
    procedure DeleteRedirect; virtual;
    function GetGlobalFunction: TFunction2; virtual;
    function GetLocalFunction: PFunction; virtual;
    function LocalizeMethod(var Index: NativeInt; const Header: PScriptHeader; const ItemHeader: PItemHeader;
      const Item: PScriptItem; const P: Pointer): Boolean; virtual;
    procedure CompileJit(const Script: TScript); virtual;
    procedure ClearJit; virtual;
    function Evaluate(const Script: TScript): Extended; virtual;
    function ComputePolar(const Value: Extended; const Script: TScript): TPointD; virtual;
    function ComputeRectangular(const Value: Extended; const Script: TScript): TPointD; virtual;
    property LocalValue: TValue read FLocalValue write FLocalValue;
    property RedirectList: TList read FRedirectList write FRedirectList;
    property RedirectCategory: NativeInt read FRedirectCategory write FRedirectCategory;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear; virtual;
    procedure Attach; virtual;
    procedure Detach; virtual;
    property WorkTime: LongWord read FWorkTime write SetWorkTime;
    property Engine: TGraphEngine read GetEngine;
    property Parser: TParser read FParser write SetParser;
    property GlobalValue: PValue read FGlobalValue write FGlobalValue;
    property Float80: PExtended read GetFloat80;
    property JitEnabled: Boolean read FJitEnabled write FJitEnabled;
  end;

  TGapType = (gtBack, gtFace);
  TGap = array[TGapType] of Boolean;

  TParseWorkData = record
    MapArray: TRangeArray;
  end;

  TParseThread = class(TGraphThread)
  private
    FAutoquality: Boolean;
    FMinStep: Extended;
    FEpsilon: Extended;
    FMaxX: Extended;
    FStep: Extended;
    FMaxY: Extended;
    FCompute: TComputeMethod;
    FPointToCursor: TConvertMethod;
    FCursorToPoint: TConvertMethod;
    FCS: TCoordinateSystem;
    FDisplay: TDisplay;
    FPointArray: TCurveDArray;
    FExamine: TExamineMethod;
    FGap: TGap;
    FWorkData: TParseWorkData;
    FRangeArray: TRangeArray;
    FScript: TScript;
    procedure SetScript(const Value: TScript);
  protected
    procedure Work; override;
    procedure DeleteWorkData; override;
    function Map(const Range: TRange; const Space: Extended): TRangeArray; overload; virtual;
    function Map(var MapArray: TRangeArray; const Range: TRange;
      const Space: Extended): Boolean; overload; virtual;
    property WorkData: TParseWorkData read FWorkData write FWorkData;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear; override;
    function Push(const Range: TRange): Integer; virtual;
    property PointArray: TCurveDArray read FPointArray write FPointArray;
    property Gap: TGap read FGap write FGap;
    property MinStep: Extended read FMinStep write FMinStep;
    property Script: TScript read FScript write SetScript;
    property RangeArray: TRangeArray read FRangeArray write FRangeArray;
    property Step: Extended read FStep write FStep;
    property Display: TDisplay read FDisplay write FDisplay;
    property Epsilon: Extended read FEpsilon write FEpsilon;
    property Autoquality: Boolean read FAutoquality write FAutoquality;
    property CS: TCoordinateSystem read FCS write FCS;
    property MaxX: Extended read FMaxX write FMaxX;
    property MaxY: Extended read FMaxY write FMaxY;
    property Compute: TComputeMethod read FCompute write FCompute;
    property PointToCursor: TConvertMethod read FPointToCursor write FPointToCursor;
    property CursorToPoint: TConvertMethod read FCursorToPoint write FCursorToPoint;
    property Examine: TExamineMethod read FExamine write FExamine;
  end;

  TOverlapThread = class(TGraphThread)
  private
    FPrepared: Boolean;
    FHighPrecision: Boolean;
    FEpsilon: Extended;
    FPolarMaxAngle: Extended;
    FStep: Extended;
    FMaxY: Extended;
    FMaxX: Extended;
    FMin: Extended;
    FMax: Extended;
    FMaxDepth: Integer;
    FMaxTime: Integer;
    FExchange: PExchange;
    FCompute: TComputeMethod;
    FCS: TCoordinateSystem;
    FExamine: TExamineMethod;
    FFormula: TFormulaList;
    FOverlapArray: TOverlapArray;
    FMediateArray: TOverlapArray;
    FResultArray: TOverlapArray;
    FSiblingArray: TOverlapArray;
    FRangeArray: TRangeArray;
    FSA: TScriptArray;
    FSize: TSize;
    FMarkSpacing: Integer;
    FTotal: Integer;
    FSameArray: TSameArray;
    function GetDistance: Extended;
    procedure SetSA(const Value: TScriptArray);
  protected
    procedure Work; override;
    procedure Done; override;
    property OverlapArray: TOverlapArray read FOverlapArray write FOverlapArray;
    property MediateArray: TOverlapArray read FMediateArray write FMediateArray;
  public
    destructor Destroy; override;
    procedure Clear; override;
    property Exchange: PExchange read FExchange write FExchange;
    property Prepared: Boolean read FPrepared write FPrepared;
    property SA: TScriptArray read FSA write SetSA;
    property Distance: Extended read GetDistance;
    property RangeArray: TRangeArray read FRangeArray write FRangeArray;
    property Min: Extended read FMin write FMin;
    property Max: Extended read FMax write FMax;
    property PolarMaxAngle: Extended read FPolarMaxAngle write FPolarMaxAngle;
    property Step: Extended read FStep write FStep;
    property CS: TCoordinateSystem read FCS write FCS;
    property MaxX: Extended read FMaxX write FMaxX;
    property MaxY: Extended read FMaxY write FMaxY;
    property HighPrecision: Boolean read FHighPrecision write FHighPrecision;
    property MaxDepth: Integer read FMaxDepth write FMaxDepth;
    property MaxTime: Integer read FMaxTime write FMaxTime;
    property Size: TSize read FSize write FSize;
    property MarkSpacing: Integer read FMarkSpacing write FMarkSpacing;
    property Total: Integer read FTotal;
    property SameArray: TSameArray read FSameArray;
    property Formula: TFormulaList read FFormula write FFormula;
    property Epsilon: Extended read FEpsilon write FEpsilon;
    property Compute: TComputeMethod read FCompute write FCompute;
    property Examine: TExamineMethod read FExamine write FExamine;
  end;

  TExtremeWorkData = record
    MinArray, MaxArray, PointArray: TPointDArray;
  end;

  TExtremeThread = class(TGraphThread)
  private
    FPrepared: Boolean;
    FMaxY: Extended;
    FMaxX: Extended;
    FStep: Extended;
    FVaryRadius: Extended;
    FVoidRadius: Extended;
    FEpsilon: Extended;
    FExchange: PExchange;
    FCS: TCoordinateSystem;
    FMaxArray: TCurveDArray;
    FMinArray: TCurveDArray;
    FEntireArray: TCurveDArray;
    FMax: TPointD;
    FMin: TPointD;
    FWorkData: TExtremeWorkData;
    FFormula: TFormulaList;
  protected
    procedure Work; override;
    procedure Done; override;
    procedure DeleteWorkData; override;
    property MaxArray: TCurveDArray read FMaxArray write FMaxArray;
    property MinArray: TCurveDArray read FMinArray write FMinArray;
    property WorkData: TExtremeWorkData read FWorkData write FWorkData;
  public
    destructor Destroy; override;
    procedure Clear; override;
    property Exchange: PExchange read FExchange write FExchange;
    property Prepared: Boolean read FPrepared write FPrepared;
    property VaryRadius: Extended read FVaryRadius write FVaryRadius;
    property VoidRadius: Extended read FVoidRadius write FVoidRadius;
    property Min: TPointD read FMin write FMin;
    property Max: TPointD read FMax write FMax;
    property Step: Extended read FStep write FStep;
    property CS: TCoordinateSystem read FCS write FCS;
    property MaxX: Extended read FMaxX write FMaxX;
    property MaxY: Extended read FMaxY write FMaxY;
    property Epsilon: Extended read FEpsilon write FEpsilon;
    property EntireArray: TCurveDArray read FEntireArray write FEntireArray;
    property Formula: TFormulaList read FFormula write FFormula;
  end;

  TResultKind = (rkOverlap, rkExtreme);
  TResultEvent = procedure(Sender: TObject; const Kind: TResultKind) of object;

  TGraphEngine = class(TComponent)
  private
    FActive: Boolean;
    FAutoquality: Boolean;
    FCenter: TPointD;
    FCompute: array[TCoordinateSystem] of TComputeMethod;
    FCS: TCoordinateSystem;
    FEntireArray: TCurveDArray;
    FEpsilon: Extended;
    FErrorMessage: string;
    FParsing: Boolean;
    FExchange: TExchange;
    FExtreme: Boolean;
    FExtremeThread: TExtremeThread;
    FExtremeVaryRadius: Extended;
    FExtremeVoidRadius: Extended;
    FFormula: TFormulaList;
    FGlobalValue: TValue;
    FHighPrecision: Boolean;
    FJitEnabled: Boolean;
    FMax: TPointD;
    FMaxArray: TCurveDArray;
    FMaxX: Extended;
    FMaxY: Extended;
    FMin: TPointD;
    FMinArray: TCurveDArray;
    FOffset: TPointD;
    FOnResultReady: TResultEvent;
    FOverlap: Boolean;
    FOverlapArray: TOverlapArray;
    FOverlapMaxDepth: array[TCoordinateSystem] of Integer;
    FOverlapMaxTime: array[TCoordinateSystem] of Integer;
    FOverlapThread: TOverlapThread;
    FMarkSpacing: Integer;
    FOwnParser: Boolean;
    FParser: TParser;
    FPolarMaxAngle: Extended;
    FQuality: Integer;
    FSA: TScriptArray;
    FSize: TSize;
    FThreadList: TThreadList;
    FThreadWorkTime: LongWord;
    FXFactor: Extended;
    FYFactor: Extended;
    function GetBusy: Boolean;
    function GetMaxArray: TCurveDArray;
    function GetMinArray: TCurveDArray;
    function GetOverlapArray: TOverlapArray;
    function GetOverlapMaxDepth: Integer;
    function GetOverlapMaxTime: Integer;
    function GetOverlapTotal: Integer;
    function GetSameArray: TSameArray;
    function GetThreadCount: Integer;
    procedure SetOverlapMaxDepth(const Value: Integer);
    procedure SetOverlapMaxTime(const Value: Integer);
    procedure SetParser(const Value: TParser);
    procedure SetThreadCount(const Value: Integer);
    procedure SetThreadWorkTime(const Value: LongWord);
  protected
    function GetDisplay: TDisplay; virtual;
    function GetPolarRangeArray: TRangeArray; virtual;
    procedure Capture; virtual;
    procedure ParseRange(const Script: TScript; const RangeArray: TRangeArray; const Step: Extended;
      const MinStep: PExtended); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function ComputePolar(const Value: Extended; const Script: TScript): TPointD; virtual;
    function ComputeRectangular(const Value: Extended; const Script: TScript): TPointD; virtual;
    function Examine(const Point: TPointD): Boolean; virtual;
    function PointCount(const Segment: PExtended = nil): Extended; virtual;
    procedure Abort; virtual;
    procedure Attach; virtual;
    procedure Detach; virtual;
    procedure Prepare; virtual;
    procedure Clear; virtual;
    procedure Parse; virtual;
    procedure DoParse; virtual;
    procedure Stop; virtual;
    procedure StartOverlap; virtual;
    procedure StartExtreme; virtual;
    procedure FormulaChanging; virtual;
    procedure ResultReady(const Kind: TResultKind); virtual;
    procedure TakeOverlap; virtual;
    procedure TakeExtreme; virtual;
    function WaitFor(const AThread: TThread; const Time: LongWord): Boolean; virtual;
    function CursorToPoint(const Point: TPointD): TPointD; overload;
    function PointToCursor(const Point: TPointD): TPointD; overload;
    function XToCursor(const X: Extended): Extended;
    function XToPoint(const X: Extended): Extended;
    function YToCursor(const Y: Extended): Extended;
    function YToPoint(const Y: Extended): Extended;
    property Active: Boolean read FActive write FActive;
    property Autoquality: Boolean read FAutoquality write FAutoquality;
    property Busy: Boolean read GetBusy;
    property Center: TPointD read FCenter;
    property CS: TCoordinateSystem read FCS write FCS;
    property Display: TDisplay read GetDisplay;
    property PolarRangeArray: TRangeArray read GetPolarRangeArray;
    property EntireArray: TCurveDArray read FEntireArray write FEntireArray;
    property Epsilon: Extended read FEpsilon write FEpsilon;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property Extreme: Boolean read FExtreme write FExtreme;
    property ExtremeVaryRadius: Extended read FExtremeVaryRadius write FExtremeVaryRadius;
    property ExtremeVoidRadius: Extended read FExtremeVoidRadius write FExtremeVoidRadius;
    property Formula: TFormulaList read FFormula;
    property GlobalValue: TValue read FGlobalValue write FGlobalValue;
    property HighPrecision: Boolean read FHighPrecision write FHighPrecision;
    property JitEnabled: Boolean read FJitEnabled write FJitEnabled;
    property Max: TPointD read FMax;
    property MaxArray: TCurveDArray read GetMaxArray write FMaxArray;
    property MaxX: Extended read FMaxX write FMaxX;
    property MaxY: Extended read FMaxY write FMaxY;
    property Min: TPointD read FMin;
    property MinArray: TCurveDArray read GetMinArray write FMinArray;
    property Offset: TPointD read FOffset write FOffset;
    property Overlap: Boolean read FOverlap write FOverlap;
    property OverlapArray: TOverlapArray read GetOverlapArray write FOverlapArray;
    property OverlapMaxDepth: Integer read GetOverlapMaxDepth write SetOverlapMaxDepth;
    property OverlapMaxTime: Integer read GetOverlapMaxTime write SetOverlapMaxTime;
    property OverlapTotal: Integer read GetOverlapTotal;
    property MarkSpacing: Integer read FMarkSpacing write FMarkSpacing;
    property SameArray: TSameArray read GetSameArray;
    property Parser: TParser read FParser write SetParser;
    property PolarMaxAngle: Extended read FPolarMaxAngle write FPolarMaxAngle;
    property Quality: Integer read FQuality write FQuality;
    property SA: TScriptArray read FSA write FSA;
    property Size: TSize read FSize write FSize;
    property ThreadCount: Integer read GetThreadCount write SetThreadCount;
    property ThreadWorkTime: LongWord read FThreadWorkTime write SetThreadWorkTime;
    property OnResultReady: TResultEvent read FOnResultReady write FOnResultReady;
  end;

function Check(const Target: TScriptArray; const Index: Integer): Boolean; overload;

function MakeRange(const AMin, AMax: Extended): TRange;
function MakeRangeArray(const RangeArray: array of TRange): TRangeArray; overload;
function MakeRangeArray(const Range: TRange): TRangeArray; overload;
function Add(var Target: TRangeArray; const Value: TRange): Integer; overload;
procedure Add(var Target: TRangeArray; const Source: TRangeArray); overload;
function Inside(const Target: Extended; const Range: TRange; const Epsilon: Extended = 0): Boolean;
function RangeCompare(const AIndex, BIndex: Integer; const Target: Pointer;
  const Data: Pointer = nil): {$IFDEF FPC}Types{$ELSE}{$IFDEF DELPHI_XE7}System.Types{$ELSE}Types{$ENDIF}{$ENDIF}.TValueRelationship;
procedure RangeExchange(const AIndex, BIndex: Integer; const Target: Pointer; const Data: Pointer = nil);
procedure Sort(var Target: TRangeArray);

function MakePlace(const AArrayIndex, AIndex: Integer): TPlace;
function Empty(const Back, Face: TPlace): Boolean;

function Check(const Target: TCurveDArray; const Place: TPlace): Boolean; overload;
function Shift(const Target: TCurveDArray; const Back, Face: TPlace; const Distance: Integer;
  out Place: TPlace): Boolean; overload;
function Shift(const Target: TCurveDArray; const Back, Face: TPlace; const Distance: Integer;
  out Point: PPointD): Boolean; overload;
function MovePlace(const Target: TCurveDArray; const Place: TPlace; const Forward: Boolean;
  out Value: TPlace): Boolean; overload;
function NextPlace(const Target: TCurveDArray; const Place: TPlace; out Value: TPlace): Boolean; overload;
function NextPlace(const Target: TCurveDArray; const Place: TPlace): TPlace; overload;
function PrevPlace(const Target: TCurveDArray; const Place: TPlace; out Value: TPlace): Boolean; overload;
function PrevPlace(const Target: TCurveDArray; const Place: TPlace): TPlace; overload;
function LastPlace(const Target: TCurveDArray): TPlace; overload;
function NextPoint(const Target: TCurveDArray; const Back, Face: TPlace; const X: Extended;
  out Value: PPointD): Boolean; overload;
function PrevPoint(const Target: TCurveDArray; const Back, Face: TPlace; const X: Extended;
  out Value: PPointD): Boolean; overload;
function GetRange(const Target: TCurveDArray; const Back, Face: TPlace; const ArrayIndex: Integer;
  out Min, Max: Integer): Boolean; overload;

function Add(var Target: TPointDArray; const Value: TPointD; const MinDistance: Extended): Integer; overload;
function Add(var Target: TOverlapArray; const Value: TOverlap): Integer; overload;
function Delete(var Target: TOverlapArray; const Index: Integer): Boolean;

function JitCompiledCount: Integer;
function JitRejectedCount: Integer;
function JitLastReason: string;
procedure ResetJitCounters;

function MakeOverlap(const Point: TPointD; const Range: TRange; const AFormula, BFormula: Integer;
  const Step: Extended): TOverlap;

var
  ZeroPoint: TPointD = (X: 0; Y: 0);

implementation

uses
  {$IFDEF FPC}
  Math, Notifier, MemoryUtils, NumberConsts, ParseConsts, ParseErrors, ParseUtils,
  TextUtils, ThreadUtils, ValueUtils;
  {$ELSE}
  System.Math, Notifier, MemoryUtils, NumberConsts, ParseConsts, ParseErrors, ParseUtils,
  TextUtils, ThreadUtils, ValueUtils;
  {$ENDIF}

{$IFDEF FPC}
function GetTickCount: LongWord; inline;
begin
  Result := LongWord(SysUtils.GetTickCount64);
end;
{$ENDIF}

function TakeArrayRef(var Slot): Pointer;
begin
  {$IFDEF FPC}
  {$IFDEF CPU64}
  Result := Pointer(InterLockedExchange64(Int64(Slot), 0));
  {$ELSE}
  Result := Pointer(InterLockedExchange(LongInt(Slot), 0));
  {$ENDIF}
  {$ELSE}
  {$IFDEF CPU64BITS}
  Result := Pointer(AtomicExchange(NativeInt(Slot), 0));
  {$ELSE}
  Result := Pointer(AtomicExchange(Integer(Slot), 0));
  {$ENDIF}
  {$ENDIF}
end;

const
  EngineResolution = 1E-16;
  DefaultThreadCount = 2;
  DefaultThreadWorkTime = 5000;
  TurnsPerMillisecond = 500;
  DefaultQuality = 1;
  DefaultAutoquality = True;
  DefaultHighPrecision = False;
  DefaultMaxX = 5;
  DefaultMaxY = 5;
  DefaultOffset: TPointD = (X: 0; Y: 0);
  DefaultOverlapMaxDepth: array[TCoordinateSystem] of Integer = (100, 100);
  DefaultOverlapMaxTime: array[TCoordinateSystem] of Integer = (500, 500);
  MaxOverlapQueue = 256;
  DefaultMarkSpacing = 14;
  AngleVariableName = 'T';
  ValueVariableName = 'X';
  ExtremeVaryFactor = 5;
  ExtremeVoidFactor = 20;
  TurnShare = 1E-14;
  IncorrectColor = 0;

var
  JitCompiled: Integer = 0;
  JitRejected: Integer = 0;
  JitReason: string = '';

function Check(const Target: TScriptArray; const Index: Integer): Boolean;
begin
  Result := (Index >= Low(Target)) and (Index <= High(Target));
end;

function MakeRange(const AMin, AMax: Extended): TRange;
begin
  FillChar(Result, SizeOf(TRange), 0);
  with Result do
  begin
    Min := AMin;
    Max := AMax;
  end;
end;

function MakeRangeArray(const RangeArray: array of TRange): TRangeArray;
var
  I: Integer;
begin
  SetLength(Result, Length(RangeArray));
  for I := Low(Result) to High(Result) do Result[I] := RangeArray[I];
end;

function MakeRangeArray(const Range: TRange): TRangeArray;
begin
  Result := MakeRangeArray([Range]);
end;

function Add(var Target: TRangeArray; const Value: TRange): Integer;
begin
  Result := Length(Target);
  SetLength(Target, Result + 1);
  MemoryUtils.Add(Target, @Value, Result * SizeOf(TRange), SizeOf(TRange));
end;

procedure Add(var Target: TRangeArray; const Source: TRangeArray);
var
  I, J: Integer;
begin
  I := Length(Target);
  J := Length(Source);
  SetLength(Target, I + J);
  CopyMemory(PAnsiChar(Target) + I * SizeOf(TRange), Source, J * SizeOf(TRange));
end;

function Inside(const Target: Extended; const Range: TRange; const Epsilon: Extended): Boolean;
begin
  Result := AboveOrEqual(Target, Range.Min, Epsilon) and BelowOrEqual(Target, Range.Max, Epsilon);
end;

function RangeCompare(const AIndex, BIndex: Integer; const Target: Pointer;
  const Data: Pointer = nil): {$IFDEF FPC}Types{$ELSE}{$IFDEF DELPHI_XE7}System.Types{$ELSE}Types{$ENDIF}{$ENDIF}.TValueRelationship;
var
  RangeArray: TRangeArray absolute Target;
begin
  Result := CompareValue(RangeArray[AIndex].Min, RangeArray[BIndex].Min);
end;

procedure RangeExchange(const AIndex, BIndex: Integer; const Target: Pointer; const Data: Pointer = nil);
var
  Range: TRange;
  RangeArray: TRangeArray absolute Target;
begin
  Range := RangeArray[AIndex];
  RangeArray[AIndex] := RangeArray[BIndex];
  RangeArray[BIndex] := Range;
end;

procedure Sort(var Target: TRangeArray);
begin
  QSort(Target, Low(Target), High(Target), RangeCompare, RangeExchange);
end;

function MakePlace(const AArrayIndex, AIndex: Integer): TPlace;
begin
  FillChar(Result, SizeOf(TPlace), 0);
  with Result do
  begin
    ArrayIndex := AArrayIndex;
    Index := AIndex;
  end;
end;

function Empty(const Back, Face: TPlace): Boolean;
begin
  Result := (Face.ArrayIndex < Back.ArrayIndex) or ((Face.ArrayIndex = Back.ArrayIndex) and
    (Face.Index <= Back.Index));
end;

function Check(const Target: TCurveDArray; const Place: TPlace): Boolean;
begin
  Result := Check(Target, Place.ArrayIndex, Place.Index);
end;

function Shift(const Target: TCurveDArray; const Back, Face: TPlace; const Distance: Integer;
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

function Shift(const Target: TCurveDArray; const Back, Face: TPlace; const Distance: Integer;
  out Point: PPointD): Boolean;
var
  Place: TPlace;
begin
  Result := Shift(Target, Back, Face, Distance, Place);
  if Result then Point := @Target[Place.ArrayIndex, Place.Index];
end;

function MovePlace(const Target: TCurveDArray; const Place: TPlace; const Forward: Boolean;
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

function NextPlace(const Target: TCurveDArray; const Place: TPlace; out Value: TPlace): Boolean;
begin
  Result := MovePlace(Target, Place, True, Value);
end;

function NextPlace(const Target: TCurveDArray; const Place: TPlace): TPlace;
begin
  if not NextPlace(Target, Place, Result) then Result := Place;
end;

function PrevPlace(const Target: TCurveDArray; const Place: TPlace; out Value: TPlace): Boolean;
begin
  Result := MovePlace(Target, Place, False, Value);
end;

function PrevPlace(const Target: TCurveDArray; const Place: TPlace): TPlace;
begin
  if not PrevPlace(Target, Place, Result) then Result := Place;
end;

function LastPlace(const Target: TCurveDArray): TPlace;
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

function NextPoint(const Target: TCurveDArray; const Back, Face: TPlace; const X: Extended;
  out Value: PPointD): Boolean;
var
  I: Integer;
begin
  I := 0;
  Value := nil;
  while Shift(Target, Back, Face, I, Value) and Below(Value.X, X) do Inc(I);
  Result := Assigned(Value);
end;

function PrevPoint(const Target: TCurveDArray; const Back, Face: TPlace; const X: Extended;
  out Value: PPointD): Boolean;
var
  I: Integer;
  Point: PPointD;
begin
  I := 0;
  Value := nil;
  while Shift(Target, Back, Face, I, Point) and Below(Point.X, X) do
  begin
    Value := Point;
    Inc(I);
  end;
  Result := Assigned(Value);
end;

function GetRange(const Target: TCurveDArray; const Back, Face: TPlace; const ArrayIndex: Integer;
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

function Add(var Target: TPointDArray; const Value: TPointD; const MinDistance: Extended): Integer;
var
  I: Integer;
begin
  for I := Low(Target) to High(Target) do
    if BOE(DistanceOf(Target[I], Value), MinDistance) then
    begin
      Result := -1;
      Exit;
    end;
  Result := Length(Target);
  SetLength(Target, Result + 1);
  Add(Target, @Value, Result * SizeOf(TPointD), SizeOf(TPointD));
end;

function Add(var Target: TOverlapArray; const Value: TOverlap): Integer;
begin
  Result := Length(Target);
  SetLength(Target, Result + 1);
  MemoryUtils.Add(Target, @Value, Result * SizeOf(TOverlap), SizeOf(TOverlap));
end;

function Delete(var Target: TOverlapArray; const Index: Integer): Boolean;
var
  Size: Integer;
begin
  Size := Length(Target);
  Result := MemoryUtils.Delete(Target, Index * SizeOf(TOverlap), SizeOf(TOverlap), Size * SizeOf(TOverlap));
  if Result then SetLength(Target, Size - 1);
end;

function MakeOverlap(const Point: TPointD; const Range: TRange; const AFormula, BFormula: Integer;
  const Step: Extended): TOverlap;
begin
  FillChar(Result, SizeOf(TOverlap), 0);
  Result.Point := Point;
  Result.Range := Range;
  Result.AFormula := AFormula;
  Result.BFormula := BFormula;
  Result.Step := Step;
end;

{ TThreadList }

function TThreadList.GetItem(Index: Integer): TParseThread;
begin
  Result := TParseThread(inherited Items[Index]);
end;

procedure TThreadList.SetItem(Index: Integer; const Value: TParseThread);
begin
  inherited Items[Index] := TObject(Value);
end;

{ TFormulaList }

function TFormulaList.Add(const S: string; AVisible, ACorrect, ATracing: Boolean): Integer;
begin
  Result := AddObject(S, nil, AVisible, ACorrect, ATracing);
end;

function TFormulaList.AddObject(const S: string; AObject: TObject;
  AVisible, ACorrect, ATracing: Boolean): Integer;
begin
  Result := AddObject(S, AObject);
  if Result >= 0 then
  begin
    Visible[Result] := AVisible;
    Correct[Result] := ACorrect;
    Tracing[Result] := ATracing;
  end;
end;

function TFormulaList.AddObject(const S: string; AObject: TObject): Integer;
begin
  if IndexOf(S) < 0 then
    Result := inherited AddObject(S, AObject)
  else
    Result := -1;
end;

procedure TFormulaList.Clear;
var
  I: Integer;
begin
  if Assigned(FOnChanging) then FOnChanging;
  for I := 0 to Count - 1 do DeleteData(I);
  inherited;
end;

constructor TFormulaList.Create;
begin
  inherited;
  Delimiter := Pipe;
  QuoteChar := TextConsts.Quote;
end;

procedure TFormulaList.DataNeeded(const Index: Integer);
var
  FD: PFormulaData;
begin
  if not Assigned(Objects[Index]) then
  begin
    System.New(FD);
    ZeroMemory(FD, SizeOf(TFormulaData));
    Objects[Index] := TObject(FD);
  end;
end;

procedure TFormulaList.Delete(Index: Integer);
begin
  if Assigned(FOnChanging) then FOnChanging;
  if CheckIndex(Index) then DeleteData(Index);
  inherited;
end;

procedure TFormulaList.DeleteData(const Index: Integer);
var
  FD: PFormulaData;
begin
  FD := Data[Index];
  if Assigned(FD) then Dispose(FD);
end;

destructor TFormulaList.Destroy;
begin
  Clear;
  inherited;
end;

function TFormulaList.GetActive(const Index: Integer): Boolean;
begin
  Result := Visible[Index] and Correct[Index];
end;

function TFormulaList.GetActiveCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do if Active[I] then Inc(Result);
end;

function TFormulaList.GetCorrect(const Index: Integer): Boolean;
begin
  Result := Data[Index].Corrent;
end;

function TFormulaList.GetCorrectCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do if Correct[I] then Inc(Result);
end;

function TFormulaList.GetData(const Index: Integer): PFormulaData;
begin
  DataNeeded(Index);
  Result := PFormulaData(Objects[Index]);
end;

function TFormulaList.GetTracing(const Index: Integer): Boolean;
begin
  Result := Data[Index].Tracing;
end;

function TFormulaList.GetVisible(const Index: Integer): Boolean;
begin
  Result := Data[Index].Visible;
end;

function TFormulaList.GetVisibleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do if Visible[I] then Inc(Result);
end;

procedure TFormulaList.InsertItem(Index: Integer; const S: string; AObject: TObject);
begin
  if Assigned(FOnChanging) then FOnChanging;
  inherited;
  Visible[Index] := True;
  Correct[Index] := True;
  Tracing[Index] := True;
end;

procedure TFormulaList.SetCorrect(const Index: Integer; const Value: Boolean);
begin
  Data[Index].Corrent := Value;
end;

procedure TFormulaList.SetTracing(const Index: Integer; const Value: Boolean);
begin
  Data[Index].Tracing := Value;
end;

procedure TFormulaList.SetVisible(const Index: Integer; const Value: Boolean);
begin
  Data[Index].Visible := Value;
end;

{ TGraphThread }

procedure TGraphThread.Attach;
begin
  if Assigned(FParser) then
  begin
    FParser.BeginUpdate;
    try
      FParser.AddVariable(ValueVariableName + IntToHex(NativeInt(Self), 0), FLocalValue, False);
    finally
      FParser.EndUpdate;
      FParser.Notify(ntCompile, Self);
    end;
  end;
end;

procedure TGraphThread.Clear;
begin
  ClearJit;
  DeleteWorkData;
end;

constructor TGraphThread.Create(AOwner: TComponent);
begin
  inherited;
  FRedirectList := TList.Create;
  FRedirectCategory := GetRedirectCategory;
  FLocalValue.ValueType := vtExtended;
  WorkTime := DefaultThreadWorkTime;
end;

procedure TGraphThread.SetWorkTime(const Value: LongWord);
begin
  FWorkTime := Value;
  AbortTime := Value * 2;
end;

procedure TGraphThread.DeleteRedirect;
var
  I: Integer;
begin
  for I := FRedirectList.Count - 1 downto 0 do
    FParser.DeleteRedirect(NativeInt(FRedirectList[I]));
  FRedirectList.Clear;
end;

procedure TGraphThread.DeleteWorkData;
begin
end;

destructor TGraphThread.Destroy;
begin
  inherited;
  DeleteRedirect;
  DeleteWorkData;
  Detach;
end;

procedure TGraphThread.Detach;
begin
  Abort;
  if Assigned(FParser) then
  begin
    FParser.BeginUpdate;
    try
      FParser.DeleteVariable(FLocalValue);
    finally
      FParser.EndUpdate;
      FParser.Notify(ntCompile, Self);
    end;
  end;
end;

procedure TGraphThread.Done;
begin
  DeleteWorkData;
end;

function TGraphThread.GetFloat80: PExtended;
begin
  Result := @FLocalValue.Float80;
end;

function TGraphThread.GetGlobalFunction: TFunction2;
var
  I, J: Integer;
begin
  FillChar(Result, SizeOf(TFunction2), 0);
  J := 0;
  for I := Low(FParser.FData.FA) to High(FParser.FData.FA) do
    if (FParser.FData.FA[I].Method.MethodType = mtVariable) and
      (FParser.FData.FA[I].Method.Variable.Variable = FGlobalValue) then
      begin
        Result[J] := @FParser.FData.FA[I];
        if J >= Length(Result) - 1 then Break;
        Inc(J);
      end;
end;

function TGraphThread.GetEngine: TGraphEngine;
begin
  Result := TGraphEngine(Owner);
end;

function TGraphThread.GetLocalFunction: PFunction;
var
  I: Integer;
begin
  for I := Low(FParser.FData.FA) to High(FParser.FData.FA) do
    if (FParser.FData.FA[I].Method.MethodType = mtVariable) and
      (FParser.FData.FA[I].Method.Variable.Variable = @FLocalValue) then
      begin
        Result := @FParser.FData.FA[I];
        Exit;
      end;
  Result := nil;
end;

function JitCompiledCount: Integer;
begin
  Result := JitCompiled;
end;

function JitRejectedCount: Integer;
begin
  Result := JitRejected;
end;

function JitLastReason: string;
begin
  Result := JitReason;
end;

procedure ResetJitCounters;
begin
  JitCompiled := 0;
  JitRejected := 0;
  JitReason := '';
end;

procedure TGraphThread.ClearJit;
var
  I: Integer;
begin
  for I := Low(FJitArray) to High(FJitArray) do FJitArray[I].Code.Free;
  FJitArray := nil;
end;

procedure TGraphThread.CompileJit(const Script: TScript);
var
  I: Integer;
  Code: TJitScript;
begin
  if not FJitEnabled or not Assigned(Script) or not (FParser is TJitParser) then
    Exit;
  try
    Code := TJitParser(FParser).CompileScript(Script);
  except
    Code := nil;
  end;
  if not Assigned(Code) then
  begin
    if JitReason = '' then JitReason := 'compilation did not happen';
    AtomicIncrement(JitRejected);
    Exit;
  end;
  if not Code.Ready then
  begin
    if JitReason = '' then JitReason := Code.Reason;
    Code.Free;
    AtomicIncrement(JitRejected);
    Exit;
  end;
  AtomicIncrement(JitCompiled);
  I := Length(FJitArray);
  SetLength(FJitArray, I + 1);
  FJitArray[I].Script := Script;
  FJitArray[I].Code := Code;
end;

function TGraphThread.Evaluate(const Script: TScript): Extended;
var
  I: Integer;
begin
  for I := Low(FJitArray) to High(FJitArray) do
    if FJitArray[I].Script = Script then Exit(FJitArray[I].Code.Execute);
  Result := GetExtended(FParser.ExecuteScript(Script)^);
end;

function TGraphThread.ComputePolar(const Value: Extended; const Script: TScript): TPointD;
begin
  Result := PointAtAngle(ZeroPoint, Value, Evaluate(Script));
end;

function TGraphThread.ComputeRectangular(const Value: Extended; const Script: TScript): TPointD;
begin
  Result := PointD(Value, Evaluate(Script));
end;

function TGraphThread.LocalizeMethod(var Index: NativeInt; const Header: PScriptHeader;
  const ItemHeader: PItemHeader; const Item: PScriptItem; const P: Pointer): Boolean;
var
  Handle: PNativeInt absolute P;
  AFunction: PFunction;
begin
  case Item.Code of
    NumberCode: Inc(Index, SizeOf(TCode) + SizeOf(TScriptNumber));
    FunctionCode:
      begin
        Inc(Index, SizeOf(TCode) + SizeOf(TScriptFunction));
        AFunction := FParser.GetFunction(Item.ScriptFunction.Handle);
        if Assigned(AFunction) and (AFunction.Method.MethodType = mtVariable) and
          (AFunction.Method.Variable.Variable = FGlobalValue) then
            Item.ScriptFunction.Handle := Handle^;
      end;
    StringCode: Inc(Index, SizeOf(TCode) + SizeOf(TScriptString) + Item.ScriptString.Size);
    ScriptCode, ParameterCode:
      begin
        ParseScript(Index + SizeOf(TCode), LocalizeMethod, P);
        Inc(Index, SizeOf(TCode) + Item.Script.Header.ScriptSize);
      end;
  else
    raise Error(ScriptError);
  end;
  Result := True;
end;

procedure TGraphThread.SetParser(const Value: TParser);
begin
  if FParser <> Value then
  begin
    Detach;
    FParser := Value;
    Attach;
  end;
end;

{ TParseThread }

procedure TParseThread.Clear;
begin
  inherited;
  CrossGraph.Types.Delete(FPointArray);
  FScript := nil;
  FRangeArray := nil;
end;

constructor TParseThread.Create(AOwner: TComponent);
begin
  inherited;
  Priority := tpHigher;
  FLocalValue.ValueType := vtExtended;
end;

procedure TParseThread.DeleteWorkData;
begin
  FWorkData.MapArray := nil;
end;

destructor TParseThread.Destroy;
begin
  inherited;
  CrossGraph.Types.Delete(FPointArray);
  FScript := nil;
  FRangeArray := nil;
end;

function TParseThread.Map(const Range: TRange; const Space: Extended): TRangeArray;
var
  I, J, Count: Integer;
  RangeArray: TRangeArray;
begin
  Result := nil;
  if Above(Space, FStep, FEpsilon) then
  begin
    if Map(RangeArray, Range, Space) then
      Add(RangeArray, MakeRange(Range.Min - Space, Range.Max + Space));
    try
      if Assigned(RangeArray) then
      begin
        Sort(RangeArray);
        Count := Length(RangeArray);
        I := Count - 1;
        J := Low(RangeArray);
        if Below(RangeArray[J].Min, Range.Min) then
          RangeArray[J].Min := Range.Min;
        if Above(RangeArray[I].Max, Range.Max) then
          RangeArray[I].Max := Range.Max;
        for I := J + 1 to Count do
          if I > Count - 1 then
            Add(Result, MakeRange(RangeArray[J].Min, RangeArray[I - 1].Max))
          else
            if Above(RangeArray[I].Min, RangeArray[I - 1].Max) then
            begin
              Add(Result, MakeRange(RangeArray[J].Min, RangeArray[I - 1].Max));
              J := I;
            end;
      end;
    finally
      RangeArray := nil;
    end;
  end
  else
    Add(Result, MakeRange(Range.Min, Range.Max));
end;

function TParseThread.Map(var MapArray: TRangeArray; const Range: TRange; const Space: Extended): Boolean;
var
  Value, Focus: Extended;
  L, R: Boolean;
begin
  Result := not Stopped;
  if Result then
  begin
    Value := Range.Max - Range.Min;
    Focus := Range.Min + Value / 2;
    if Above(Value, Space) then
    begin
      L := Map(MapArray, MakeRange(Range.Min, Focus), Space);
      R := Map(MapArray, MakeRange(Focus, Range.Max), Space);
      Result := L and R;
      if not Result then
      begin
        if L then Add(MapArray, MakeRange(Range.Min - Space, Focus + Space));
        if R then Add(MapArray, MakeRange(Focus - Space, Range.Max + Space));
      end;
    end
    else begin
      Float80^ := Focus;
      Result := FExamine(FCompute(Float80^, FScript));
    end;
  end;
end;

function TParseThread.Push(const Range: TRange): Integer;
begin
  inherited;
  Result := Add(FRangeArray, Range);
end;

procedure TParseThread.SetScript(const Value: TScript);
var
  I, J: Integer;
  AFunction, BFunction: PFunction;
  Function2: TFunction2;
begin
  if FScript <> Value then
  begin
    DeleteRedirect;
    FScript := Copy(Value);
    FParser.SetRedirectCategory(FScript, FRedirectCategory);
    BFunction := GetLocalFunction;
    if Assigned(BFunction) and ParseScript(NativeInt(FScript), LocalizeMethod, @BFunction.Method.Variable.Handle) then
    begin
      Function2 := GetGlobalFunction;
      for I := Low(Function2) to High(Function2) do
      begin
        AFunction := Function2[I];
        if Assigned(AFunction) then
        begin
          J := FParser.CreateRedirect;
          repeat
            if FParser.SetRedirect(J, FRedirectCategory, AFunction.Method.Variable.Handle, BFunction.Method.Variable.Handle) then
            begin
              FRedirectList.Add(Pointer(J));
              Break;
            end;
            FParser.DeleteRedirect(J);
          until True;
        end;
      end;
    end
    else
      FScript := nil;
    CompileJit(FScript);
  end;
end;

procedure TParseThread.Work;
type
  TPair = record
    Prev: TPointD;
    HasPrev: Boolean;
    Next: TPointD;
    Flag: Boolean;
    Cursor: TPoint;
    HasCursor: Boolean;
    Skip: TPointD;
    HasSkip: Boolean;
  end;

const
  RectangularMapRatio = 2;
  PolarMapMinSpace = 5;
  PolarMapMaxSpace = 100000;
  MinShift: array[TCoordinateSystem] of Integer = (-10, -2);
  MaxShift: array[TCoordinateSystem] of Integer = (10, 2);
  MaxDistance = 2;

var
  FromTime: LongWord;
  I, J, Index, Shift: Integer;
  Move, Prev: Extended;
  K: TGapType;
  Pair: TPair;

  function Overtime: Boolean;
  begin
    Result := GetTickCount - FromTime > FWorkTime;
  end;

  procedure MakeMove;
  var
    Distance: Extended;
  begin
    if FAutoquality then
      if Shift < 0 then
        Distance := -Move * (Shift - 1)
      else
        if Shift > 0 then
          Distance := Move / (Shift + 1)
        else
          Distance := Move
    else
      Distance := Move;
    Float80^ := Prev + Distance;
    if Below(FMinStep, Distance, FEpsilon) then FMinStep := Distance;
  end;

  function Apart: Boolean;
  var
    ACursor: TPoint;
  begin
    ACursor := PointI(FPointToCursor(Pair.Next));
    Result := not (Pair.HasCursor and (ACursor.X = Pair.Cursor.X) and (ACursor.Y = Pair.Cursor.Y));
    if Result then
    begin
      Pair.Cursor := ACursor;
      Pair.HasCursor := True;
    end;
  end;

  procedure FlushSkip;
  begin
    if Pair.HasSkip then
    begin
      CrossGraph.Types.Add(FPointArray, Pair.Skip, Index);
      Pair.HasSkip := False;
    end;
  end;

  function IncreaseQuality: Boolean;

    function Scatter: Boolean;
    begin
      Result := Pair.HasPrev and
        Above(DistanceOf(FPointToCursor(Pair.Prev), FPointToCursor(Pair.Next)), MaxDistance, FEpsilon);
    end;

  begin
    Result := (Shift >= 0) and (Shift < MaxShift[FCS]) and (Pair.Flag or Scatter);
    if Result then
    begin
      Inc(Shift);
      MakeMove;
    end;
  end;

  function DecreaseQuality: Boolean;

    function Overlap: Boolean;
    var
      ACursor, BCursor: TPoint;
    begin
      Result := Pair.HasPrev;
      if Result then
      begin
        ACursor := PointI(FPointToCursor(Pair.Prev));
        BCursor := PointI(FPointToCursor(Pair.Next));
        Result := (ACursor.X = BCursor.X) and (ACursor.Y = BCursor.Y);
      end;
    end;

  begin
    Result := (Shift <= 0) and (Shift > MinShift[FCS]) and not Pair.Flag and Overlap;
    if Result then
    begin
      Dec(Shift);
      MakeMove;
    end;
  end;

begin
  inherited;
  ParseBreak := StopFlag;
  ParseLoopLeft := NativeInt(FWorkTime) * TurnsPerMillisecond;
  FromTime := GetTickCount;
  FillChar(FGap, SizeOf(TGap), 0);
  FMinStep := FStep;
  if Above(FStep, 0, FEpsilon) and Assigned(FScript) and Assigned(FRangeArray) then
  begin
    K := gtBack;
    I := Low(FRangeArray);
    while not Stopped and not Overtime and (I < Length(FRangeArray)) do
    begin
      FWorkData.MapArray := nil;
      try
        case FCS of
          csRectangular:
            begin
              Move := FStep;
              FWorkData.MapArray := Map(FRangeArray[I], Move * RectangularMapRatio);
            end;
        else
          Move := FracSize(FMaxX);
          if Above(Move, 0) then
          begin
            Move := FStep / Move;
            FWorkData.MapArray := Map(FRangeArray[I], Move * EnsureRange(1 + 1 / FMaxX, PolarMapMinSpace, PolarMapMaxSpace));
          end
          else begin
            Move := FStep;
            FWorkData.MapArray := MakeRangeArray(FRangeArray[I]);
          end;
        end;
        J := 0;
        while not Stopped and not Overtime and (J < Length(FWorkData.MapArray)) do
        begin
          Index := CrossGraph.Types.New(FPointArray);
          Shift := 0;
          FillChar(Pair, SizeOf(TPair), 0);
          Float80^ := FWorkData.MapArray[J].Min;
          Prev := Float80^;
          while not Stopped and not Overtime and Below(Float80^, FWorkData.MapArray[J].Max, FEpsilon) do
          begin
            Pair.Next := FCompute(Float80^, FScript);
            if FAutoquality and not Pair.Flag and (IncreaseQuality or DecreaseQuality) then
              Continue;
            FGap[K] := not FExamine(Pair.Next);
            if FGap[K] then
            begin
              FlushSkip;
              Index := CrossGraph.Types.New(FPointArray);
              Pair.HasPrev := False;
              Pair.HasCursor := False;
            end
            else begin
              if Apart then
              begin
                CrossGraph.Types.Add(FPointArray, Pair.Next, Index);
                Pair.HasSkip := False;
              end
              else begin
                Pair.Skip := Pair.Next;
                Pair.HasSkip := True;
              end;
              Pair.Prev := Pair.Next;
              Pair.HasPrev := True;
            end;
            Pair.Flag := FGap[K] or ((Length(FPointArray) = 0) or Check(FPointArray, Index) and
              (Length(FPointArray[Index]) = 0));
            if Pair.Flag then Shift := MaxShift[FCS];
            if K = Low(TGapType) then K := High(TGapType);
            Prev := Float80^;
            MakeMove;
            if FAutoquality and not Pair.Flag then
            begin
              if Shift < 0 then Inc(Shift);
              if Shift > 0 then Dec(Shift);
            end;
          end;
          FlushSkip;
          Inc(J);
        end;
        Index := Length(FPointArray);
        if (Index > 0) and not Assigned(FPointArray[Index - 1]) then
          SetLength(FPointArray, Index - 1);
      finally
        FWorkData.MapArray := nil;
      end;
      Inc(I);
    end;
  end;
end;

{ TOverlapThread }

procedure TOverlapThread.Clear;
begin
  inherited;
  FPrepared := False;
  ParseUtils.Delete(FSA);
  FOverlapArray := nil;
  FRangeArray := nil;
end;

destructor TOverlapThread.Destroy;
begin
  inherited;
  ParseUtils.Delete(FSA);
  FOverlapArray := nil;
  FMediateArray := nil;
  FResultArray := nil;
  FSiblingArray := nil;
  FRangeArray := nil;
end;

procedure TOverlapThread.Done;
begin
  inherited;
  if Engine.Active then
  begin
    Pointer(FExchange.OverlapArray) := TakeArrayRef(FOverlapArray);
    FMediateArray := nil;
    FResultArray := nil;
    FSiblingArray := nil;
    Engine.ResultReady(rkOverlap);
  end;
  Clear;
end;

function TOverlapThread.GetDistance: Extended;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(FRangeArray) to High(FRangeArray) do
    Result := Result + FRangeArray[I].Max - FRangeArray[I].Min;
end;

procedure TOverlapThread.SetSA(const Value: TScriptArray);
var
  I, J, K: Integer;
  AFunction, BFunction: PFunction;
  Function2: TFunction2;
  Script: TScript;
begin
  if FSA <> Value then
  begin
    DeleteRedirect;
    ParseUtils.Delete(FSA);
    BFunction := GetLocalFunction;
    Function2 := GetGlobalFunction;
    for I := Low(Value) to High(Value) do
    begin
      Script := Copy(Value[I]);
      try
        FParser.SetRedirectCategory(Script, FRedirectCategory);
        if Assigned(BFunction) and ParseScript(NativeInt(Script), LocalizeMethod, @BFunction.Method.Variable.Handle) then
        begin
          for J := Low(Function2) to High(Function2) do
          begin
            AFunction := Function2[J];
            if Assigned(AFunction) then
            begin
              K := FParser.CreateRedirect;
              if FParser.SetRedirect(K, FRedirectCategory, AFunction.Method.Variable.Handle, BFunction.Method.Variable.Handle) then
                FRedirectList.Add(Pointer(K));
            end;
          end;
          AddScript(FSA, Script);
          CompileJit(FSA[High(FSA)]);
        end;
      finally
        Script := nil;
      end;
    end;
  end;
end;

procedure TOverlapThread.Work;
type
  TVertex = record
    Point: TPointD;
    Argument: Extended;
    Good: Boolean;
  end;
  TVertexArray = array of TVertex;

const
  GridSide = 128;
  MinimumEdge = 1E-6;
  TouchShare = 1E-2;

var
  FromTime: LongWord;
  I, J, K, L, N, X, Y, FirstX, LastX, FirstY, LastY, AEnd, BEnd: Integer;
  A, B: POverlap;
  Overlap: TOverlap;
  Point: TPointD;
  TraceArray: array of TVertexArray;
  Start, Item, Mark: array of Integer;
  Gap: array of Double;
  GapPoint: array of TPointD;
  GapMate: array of Integer;
  Crossed: array of Boolean;
  Close: array of Double;
  Same: array of Boolean;
  Pending: TOverlapArray;
  PendingAt: array of Integer;
  Order: array of Integer;
  Kept: array of Boolean;
  Crowded: Boolean;
  Span, Chord, Pixel, Bound: Double;
  Near, Middle: TPointD;
  Area: TRectD;
  CellX, CellY: Extended;
  Generation: Integer;

  function Overtime: Boolean;
  begin
    Result := (FMaxTime > 0) and (GetTickCount - FromTime > LongWord(FMaxTime));
  end;

  function Calc(const Value: Extended; const Formula: Integer; out APoint: TPointD): Boolean;
  begin
    Float80^ := Value;
    APoint := FCompute(Float80^, FSA[FFormula.Data[Formula].ScriptIndex]);
    Result := FExamine(APoint);
  end;

  function Least(const AValue, BValue: Extended): Extended;
  begin
    {$IFDEF FPC}
    Result := Math.Min(AValue, BValue);
    {$ELSE}
    Result := System.Math.Min(AValue, BValue);
    {$ENDIF}
  end;

  function Most(const AValue, BValue: Extended): Extended;
  begin
    {$IFDEF FPC}
    Result := Math.Max(AValue, BValue);
    {$ELSE}
    Result := System.Math.Max(AValue, BValue);
    {$ENDIF}
  end;

  function Trace(const Formula: Integer): TVertexArray;
  var
    M, N: Integer;
    Value: Extended;
  begin
    Result := nil;
    N := 0;
    for M := Low(FRangeArray) to High(FRangeArray) do
    begin
      Value := FRangeArray[M].Min;
      while not Stopped and not Overtime and BelowOrEqual(Value, FRangeArray[M].Max, FEpsilon) do
      begin
        if N >= Length(Result) then SetLength(Result, N + 4096);
        Result[N].Argument := Value;
        Result[N].Good := Calc(Value, Formula, Result[N].Point);
        Inc(N);
        Value := Value + FStep;
      end;
      if (N > 0) and Above(FRangeArray[M].Max, Result[N - 1].Argument, FEpsilon) then
      begin
        if N >= Length(Result) then SetLength(Result, N + 1);
        Result[N].Argument := FRangeArray[M].Max;
        Result[N].Good := Calc(FRangeArray[M].Max, Formula, Result[N].Point);
        Inc(N);
      end;
    end;
    SetLength(Result, N);
  end;

  function CellOf(const Value, Least, Size: Extended): Integer;
  begin
    if Size <= 0 then Exit(0);
    Result := Trunc((Value - Least) / Size);
    if Result < 0 then Result := 0;
    if Result > GridSide - 1 then Result := GridSide - 1;
  end;

  procedure Bounds(const Trace: TVertexArray; const M: Integer; out FirstX, LastX, FirstY, LastY: Integer);
  begin
    FirstX := CellOf(Least(Trace[M].Point.X, Trace[M + 1].Point.X), Area.Left, CellX);
    LastX := CellOf(Most(Trace[M].Point.X, Trace[M + 1].Point.X), Area.Left, CellX);
    FirstY := CellOf(Least(Trace[M].Point.Y, Trace[M + 1].Point.Y), Area.Top, CellY);
    LastY := CellOf(Most(Trace[M].Point.Y, Trace[M + 1].Point.Y), Area.Top, CellY);
  end;

  function Frame(const ATrace, BTrace: TVertexArray): TRectD;

    procedure Take(const Trace: TVertexArray; var First: Boolean);
    var
      M: Integer;
    begin
      for M := Low(Trace) to High(Trace) do
      begin
        if not Trace[M].Good then Continue;
        if First then
        begin
          Result.Left := Trace[M].Point.X;
          Result.Right := Trace[M].Point.X;
          Result.Top := Trace[M].Point.Y;
          Result.Bottom := Trace[M].Point.Y;
          First := False;
          Continue;
        end;
        if Trace[M].Point.X < Result.Left then Result.Left := Trace[M].Point.X;
        if Trace[M].Point.X > Result.Right then
          Result.Right := Trace[M].Point.X;
        if Trace[M].Point.Y < Result.Top then Result.Top := Trace[M].Point.Y;
        if Trace[M].Point.Y > Result.Bottom then
          Result.Bottom := Trace[M].Point.Y;
      end;
    end;

  var
    First: Boolean;
  begin
    Result.Left := 0;
    Result.Right := 0;
    Result.Top := 0;
    Result.Bottom := 0;
    First := True;
    Take(ATrace, First);
    Take(BTrace, First);
  end;

  procedure Spread(const Trace: TVertexArray);
  var
    M, X, Y, FirstX, LastX, FirstY, LastY: Integer;
  begin
    SetLength(Start, GridSide * GridSide + 1);
    for M := Low(Start) to High(Start) do Start[M] := 0;
    for M := 0 to Length(Trace) - 2 do
    begin
      if not (Trace[M].Good and Trace[M + 1].Good) then Continue;
      Bounds(Trace, M, FirstX, LastX, FirstY, LastY);
      for X := FirstX to LastX do
        for Y := FirstY to LastY do Inc(Start[Y * GridSide + X + 1]);
    end;
    for M := Low(Start) + 1 to High(Start) do
      Start[M] := Start[M] + Start[M - 1];
    SetLength(Item, Start[High(Start)]);
    for M := 0 to Length(Trace) - 2 do
    begin
      if not (Trace[M].Good and Trace[M + 1].Good) then Continue;
      Bounds(Trace, M, FirstX, LastX, FirstY, LastY);
      for X := FirstX to LastX do
        for Y := FirstY to LastY do
        begin
          Item[Start[Y * GridSide + X]] := M;
          Inc(Start[Y * GridSide + X]);
        end;
    end;
    for M := High(Start) downto Low(Start) + 1 do Start[M] := Start[M - 1];
    Start[Low(Start)] := 0;
  end;

  function Aside(const APoint, BPoint, CPoint, DPoint: TPointD): Extended;
  var
    AGap, BGap: Extended;
  begin
    AGap := Most(Least(APoint.X, BPoint.X) - Most(CPoint.X, DPoint.X), Least(CPoint.X, DPoint.X) - Most(APoint.X, BPoint.X));
    BGap := Most(Least(APoint.Y, BPoint.Y) - Most(CPoint.Y, DPoint.Y), Least(CPoint.Y, DPoint.Y) - Most(APoint.Y, BPoint.Y));
    Result := Most(Most(AGap, 0), Most(BGap, 0));
  end;

  procedure Refine(const AFormula, BFormula: Integer; AMin, AMax, BMin, BMax: Extended; var Value: TPointD);

    function Chords(const AFrom, ATo, BFrom, BTo: Extended; out Cross: TPointD): Boolean;
    var
      APoint, BPoint, CPoint, DPoint: TPointD;
    begin
      Result := Calc(AFrom, AFormula, APoint) and Calc(ATo, AFormula, BPoint) and
        Calc(BFrom, BFormula, CPoint) and Calc(BTo, BFormula, DPoint) and
        SegmentsCross(APoint, BPoint, CPoint, DPoint, Cross);
    end;

  var
    M: Integer;
    AMid, BMid: Extended;
    Cross: TPointD;
  begin
    for M := 1 to FMaxDepth do
    begin
      if Stopped or Overtime then Break;
      AMid := (AMin + AMax) / 2;
      BMid := (BMin + BMax) / 2;
      if Chords(AMin, AMid, BMin, BMid, Cross) then
      begin
        AMax := AMid;
        BMax := BMid;
      end
      else
        if Chords(AMin, AMid, BMid, BMax, Cross) then
        begin
          AMax := AMid;
          BMin := BMid;
        end
        else
          if Chords(AMid, AMax, BMin, BMid, Cross) then
          begin
            AMin := AMid;
            BMax := BMid;
          end
          else
            if Chords(AMid, AMax, BMid, BMax, Cross) then
            begin
              AMin := AMid;
              BMin := BMid;
            end
            else
              Break;
      Value := Cross;
    end;
  end;

  function Approach(const AFormula, BFormula: Integer; AMin, AMax, BMin, BMax: Extended;
    var Value: TPointD): Double;

    function Reach(const Value: Extended; const Formula: Integer; const CPoint, DPoint: TPointD;
      out Found: TPointD): Double;
    var
      APoint, Near: TPointD;
    begin
      Found := CPoint;
      if not Calc(Value, Formula, APoint) then Exit(Infinity);
      Result := NearestOnSegment(APoint, CPoint, DPoint, Near);
      Found.X := (APoint.X + Near.X) / 2;
      Found.Y := (APoint.Y + Near.Y) / 2;
    end;

    function Narrow(var Min, Max: Extended; const Formula: Integer; const CPoint, DPoint: TPointD;
      out Spot: TPointD): Double;
    var
      M: Integer;
      One, Two: Extended;
    begin
      for M := 1 to FMaxDepth do
      begin
        if Stopped or Overtime then Break;
        One := Min + (Max - Min) / 3;
        Two := Max - (Max - Min) / 3;
        if Reach(One, Formula, CPoint, DPoint, Spot) <= Reach(Two, Formula, CPoint, DPoint, Spot) then
          Max := Two
        else
          Min := One;
      end;
      Result := Reach((Min + Max) / 2, Formula, CPoint, DPoint, Spot);
    end;

  var
    CPoint, DPoint: TPointD;
  begin
    if not (Calc(BMin, BFormula, CPoint) and Calc(BMax, BFormula, DPoint)) then
      Exit(Infinity);
    Result := Narrow(AMin, AMax, AFormula, CPoint, DPoint, Value);
  end;

  function Ahead(const A, B: TOverlap): Boolean;
  begin
    if A.AFormula <> B.AFormula then Exit(A.AFormula < B.AFormula);
    if A.BFormula <> B.BFormula then Exit(A.BFormula < B.BFormula);
    Result := A.Argument < B.Argument;
  end;

  procedure Runs;
  var
    M, N, P: Integer;
    Walk, Edge: Extended;
    Item: TSame;
  begin
    if Pixel <= 0 then Exit;
    Edge := Pixel * Least(FSize.cx, FSize.cy) / 10;
    M := Low(Close);
    while M <= High(Close) do
    begin
      if Close[M] >= Pixel then
      begin
        Inc(M);
        Continue;
      end;
      N := M;
      Walk := 0;
      while (N <= High(Close)) and (Close[N] < Pixel) do
      begin
        if N < High(TraceArray[I]) then
          Walk := Walk + CrossGraph.Geometry.DistanceOf(TraceArray[I][N].Point, TraceArray[I][N + 1].Point);
        Inc(N);
      end;
      if Walk >= Edge then
      begin
        for P := M to N - 1 do Same[P] := True;
        Item.Range := MakeRange(TraceArray[I][M].Argument, TraceArray[I][N - 1].Argument);
        Item.Back := TraceArray[I][M].Point;
        Item.Face := TraceArray[I][N - 1].Point;
        Item.AFormula := I;
        Item.BFormula := J;
        SetLength(FSameArray, Length(FSameArray) + 1);
        FSameArray[High(FSameArray)] := Item;
      end;
      M := N;
    end;
  end;

begin
  inherited;
  FromTime := GetTickCount;
  FTotal := 0;
  FSameArray := nil;
  if (FSize.cx > 0) and (FSize.cy > 0) then
    Pixel := (2 * FMaxX / FSize.cx + 2 * FMaxY / FSize.cy) / 2
  else
    Pixel := 0;
  if Above(FStep, 0, FEpsilon) and Assigned(FSA) and Assigned(FRangeArray) then
  begin
    SetLength(TraceArray, FFormula.Count);
    for I := 0 to FFormula.Count - 1 do
      if FFormula.Active[I] and Check(FSA, FFormula.Data[I].ScriptIndex) then
        TraceArray[I] := Trace(I);
    Generation := 0;
    for I := 0 to FFormula.Count - 1 do if Assigned(TraceArray[I]) then
      for J := I + 1 to FFormula.Count - 1 do if Assigned(TraceArray[J]) then
      begin
        if Stopped or Overtime then Break;
        Area := Frame(TraceArray[I], TraceArray[J]);
        CellX := (Area.Right - Area.Left) / GridSide;
        CellY := (Area.Bottom - Area.Top) / GridSide;
        Spread(TraceArray[J]);
        SetLength(Mark, Length(TraceArray[J]));
        for K := Low(Mark) to High(Mark) do Mark[K] := 0;
        SetLength(Gap, Length(TraceArray[I]));
        SetLength(GapPoint, Length(TraceArray[I]));
        SetLength(GapMate, Length(TraceArray[I]));
        SetLength(Crossed, Length(TraceArray[I]));
        SetLength(Close, Length(TraceArray[I]));
        SetLength(Same, Length(TraceArray[I]));
        Pending := nil;
        SetLength(PendingAt, 0);
        for K := Low(Gap) to High(Gap) do
        begin
          Gap[K] := Infinity;
          Close[K] := Infinity;
          Crossed[K] := False;
          Same[K] := False;
        end;
        for K := 0 to Length(TraceArray[I]) - 2 do
        begin
          if Stopped or Overtime then Break;
          if not (TraceArray[I][K].Good and TraceArray[I][K + 1].Good) then
            Continue;
          Inc(Generation);
          Bounds(TraceArray[I], K, FirstX, LastX, FirstY, LastY);
          if FirstX > 0 then Dec(FirstX);
          if LastX < GridSide - 1 then Inc(LastX);
          if FirstY > 0 then Dec(FirstY);
          if LastY < GridSide - 1 then Inc(LastY);
          Chord := CrossGraph.Geometry.DistanceOf(TraceArray[I][K].Point, TraceArray[I][K + 1].Point);
          for X := FirstX to LastX do for Y := FirstY to LastY do
            for N := Start[Y * GridSide + X] to Start[Y * GridSide + X + 1] - 1 do
            begin
              L := Item[N];
              if Mark[L] = Generation then Continue;
              Mark[L] := Generation;
              if not (TraceArray[J][L].Good and TraceArray[J][L + 1].Good) then
                Continue;
              if Aside(TraceArray[I][K].Point, TraceArray[I][K + 1].Point, TraceArray[J][L].Point, TraceArray[J][L + 1].Point) > Chord then
                Continue;
              Middle.X := (TraceArray[I][K].Point.X + TraceArray[I][K + 1].Point.X) / 2;
              Middle.Y := (TraceArray[I][K].Point.Y + TraceArray[I][K + 1].Point.Y) / 2;
              Span := NearestOnSegment(Middle, TraceArray[J][L].Point, TraceArray[J][L + 1].Point, Near);
              if Span < Close[K] then Close[K] := Span;
              if not SegmentsCross(TraceArray[I][K].Point, TraceArray[I][K + 1].Point, TraceArray[J][L].Point,
                TraceArray[J][L + 1].Point, Point) then
                begin
                  Span := SegmentsGap(TraceArray[I][K].Point, TraceArray[I][K + 1].Point, TraceArray[J][L].Point,
                    TraceArray[J][L + 1].Point, Near);
                  if Span < Gap[K] then
                  begin
                    Gap[K] := Span;
                    GapPoint[K] := Near;
                    GapMate[K] := L;
                  end;
                  Continue;
                end;
              if FHighPrecision then
                Refine(
                  I,
                  J,
                  TraceArray[I][K].Argument,
                  TraceArray[I][K + 1].Argument,
                  TraceArray[J][L].Argument,
                  TraceArray[J][L + 1].Argument,
                  Point
                );
              if not Examine(Point) then Continue;
              Overlap := MakeOverlap(Point, MakeRange(TraceArray[I][K].Argument, TraceArray[I][K + 1].Argument),
                I, J, FStep);
              if FCS = csRectangular then
                Overlap.Argument := Point.X
              else
                Overlap.Argument := TraceArray[I][K].Argument;
              Overlap.AAngle := TraceArray[I][K].Argument;
              Overlap.BAngle := TraceArray[J][L].Argument;
              Add(Pending, Overlap);
              SetLength(PendingAt, Length(Pending));
              PendingAt[High(PendingAt)] := K;
              Crossed[K] := True;
                          end;
        end;
        Runs;
        for N := Low(Pending) to High(Pending) do
        begin
          if Same[PendingAt[N]] then Continue;
          Inc(FTotal);
          if Length(FOverlapArray) < MaxOverlapQueue then
            Add(FOverlapArray, Pending[N]);
        end;
        for K := Low(Gap) + 1 to High(Gap) - 1 do
        begin
          if Stopped or Overtime then Break;
          if Same[K] then Continue;
          if Crossed[K - 1] or Crossed[K] or Crossed[K + 1] then Continue;
          if IsInfinite(Gap[K - 1]) or IsInfinite(Gap[K + 1]) then Continue;
          Chord := CrossGraph.Geometry.DistanceOf(TraceArray[I][K].Point, TraceArray[I][K + 1].Point);
          if Gap[K] > Chord then Continue;
          if (Gap[K] * (1 + MinimumEdge) >= Gap[K - 1]) or (Gap[K] > Gap[K + 1]) then
            Continue;
          Point := GapPoint[K];
          L := GapMate[K];
          AEnd := K + 2;
          if AEnd > High(TraceArray[I]) then AEnd := High(TraceArray[I]);
          BEnd := L + 2;
          if BEnd > High(TraceArray[J]) then BEnd := High(TraceArray[J]);
          Span := Approach(I, J, TraceArray[I][K].Argument, TraceArray[I][AEnd].Argument, TraceArray[J][L].Argument,
            TraceArray[J][BEnd].Argument, Point);
          if Span > Chord * TouchShare then Continue;
          if not Examine(Point) then Continue;
          Overlap := MakeOverlap(Point, MakeRange(TraceArray[I][K].Argument, TraceArray[I][K + 1].Argument),
            I, J, FStep);
          if FCS = csRectangular then
            Overlap.Argument := Point.X
          else
            Overlap.Argument := TraceArray[I][K].Argument;
          Overlap.AAngle := TraceArray[I][K].Argument;
          Overlap.BAngle := TraceArray[J][L].Argument;
          Inc(FTotal);
          if Length(FOverlapArray) < MaxOverlapQueue then
            Add(FOverlapArray, Overlap);
        end;
      end;
    TraceArray := nil;
  end;
  for I := Low(FOverlapArray) to High(FOverlapArray) do
    for J := Low(FOverlapArray) to High(FOverlapArray) do if I <> J then
    begin
      A := @FOverlapArray[I];
      B := @FOverlapArray[J];
      if (A.AFormula >= 0) and (A.AFormula = B.AFormula) and (A.BFormula >= 0) and
        (A.BFormula = B.BFormula) then
          if BOE(CrossGraph.Geometry.DistanceOf(A.Point, B.Point), (A.Step + B.Step) / 2) and
            (Above(A.Step, B.Step) or (Equal(A.Step, B.Step) and (I > J))) then
            begin
              A.AFormula := -1;
              A.BFormula := -1;
            end;
    end;
  for I := High(FOverlapArray) downto Low(FOverlapArray) do
    if (FOverlapArray[I].AFormula < 0) or (FOverlapArray[I].BFormula < 0) then
      Delete(FOverlapArray, I);
  if (FMarkSpacing > 0) and (Pixel > 0) and (Length(FOverlapArray) > 1) then
  begin
    Bound := FMarkSpacing * Pixel;
    SetLength(Order, Length(FOverlapArray));
    for I := Low(Order) to High(Order) do Order[I] := I;
    for I := Low(Order) + 1 to High(Order) do
    begin
      N := Order[I];
      J := I - 1;
      while (J >= Low(Order)) and Ahead(FOverlapArray[N], FOverlapArray[Order[J]]) do
      begin
        Order[J + 1] := Order[J];
        Dec(J);
      end;
      Order[J + 1] := N;
    end;
    SetLength(Kept, Length(FOverlapArray));
    for I := Low(Kept) to High(Kept) do Kept[I] := False;
    for I := Low(Order) to High(Order) do
    begin
      A := @FOverlapArray[Order[I]];
      Crowded := False;
      for J := Low(Order) to I - 1 do
      begin
        if not Kept[Order[J]] then Continue;
        B := @FOverlapArray[Order[J]];
        if (A.AFormula <> B.AFormula) or (A.BFormula <> B.BFormula) then
          Continue;
        if CrossGraph.Geometry.DistanceOf(A.Point, B.Point) < Bound then
        begin
          Crowded := True;
          Break;
        end;
      end;
      Kept[Order[I]] := not Crowded;
    end;
    for I := High(FOverlapArray) downto Low(FOverlapArray) do
      if not Kept[I] then Delete(FOverlapArray, I);
  end;
end;

{ TExtremeThread }

procedure TExtremeThread.Clear;
begin
  inherited;
  FPrepared := False;
  CrossGraph.Types.Delete(FMaxArray);
  CrossGraph.Types.Delete(FMinArray);
end;

procedure TExtremeThread.DeleteWorkData;
begin
  FWorkData.MinArray := nil;
  FWorkData.MaxArray := nil;
  FWorkData.PointArray := nil;
end;

destructor TExtremeThread.Destroy;
begin
  inherited;
  CrossGraph.Types.Delete(FMaxArray);
  CrossGraph.Types.Delete(FMinArray);
end;

procedure TExtremeThread.Done;
begin
  inherited;
  if not Aborted and Engine.Active then
  begin
    Pointer(FExchange.MaxArray) := TakeArrayRef(FMaxArray);
    Pointer(FExchange.MinArray) := TakeArrayRef(FMinArray);
    Engine.ResultReady(rkExtreme);
  end;
  Clear;
end;

procedure TExtremeThread.Work;
var
  Value, Back, Face, Grain: Extended;
  I, J, K, L, M: Integer;
  Data: PFormulaData;
  Point: TPointD;
  FromTime: LongWord;

  function Overtime: Boolean;
  begin
    Result := GetTickCount - FromTime > FWorkTime;
  end;

begin
  inherited;
  FromTime := GetTickCount;
  for I := 0 to FFormula.Count - 1 do if FFormula.Active[I] then
  begin
    if Stopped then Break;
    Data := FFormula.Data[I];
    if Assigned(Data) then
    begin
      FWorkData.MinArray := nil;
      FWorkData.MaxArray := nil;
      if Check(FEntireArray, Data.EntireBack) and Check(FEntireArray, Data.EntireFace) then
        try
          for J := Data.EntireBack.ArrayIndex to Data.EntireFace.ArrayIndex do
          begin
            if Stopped or Overtime then Break;
            if GetRange(FEntireArray, Data.EntireBack, Data.EntireFace, J, L, M) then
              for K := L + 1 to M - 1 do
              begin
                if Stopped or Overtime then Break;
                Point := FEntireArray[J, K];
                if FCS = csRectangular then
                begin
                  Value := Point.Y;
                  Back := FEntireArray[J, K - 1].Y;
                  Face := FEntireArray[J, K + 1].Y;
                end
                else begin
                  Value := DistanceOf(ZeroPoint, Point);
                  Back := DistanceOf(ZeroPoint, FEntireArray[J, K - 1]);
                  Face := DistanceOf(ZeroPoint, FEntireArray[J, K + 1]);
                end;
                Grain := FEpsilon + Abs(Value) * TurnShare;
                if AboveOrEqual(Value, Back, Grain) and AboveOrEqual(Value, Face, Grain) and (Above(Value, Back, Grain) or
                  Above(Value, Face, Grain)) then
                    Add(FWorkData.MaxArray, Point, FStep);
                if BelowOrEqual(Value, Back, Grain) and BelowOrEqual(Value, Face, Grain) and (Below(Value, Back, Grain) or
                  Below(Value, Face, Grain)) then
                    Add(FWorkData.MinArray, Point, FStep);
              end;
          end;
          if Stopped then Break;
          FWorkData.PointArray := nil;
          try
            M := -1;
            for L := Low(FWorkData.MaxArray) to High(FWorkData.MaxArray) do
            begin
              if Stopped or Overtime then Break;
              if M < 0 then
              begin
                M := L;
                Continue;
              end;
              if BelowOrEqual(CrossGraph.Geometry.DistanceOf(FWorkData.MaxArray[M], FWorkData.MaxArray[L]),
                FVoidRadius) then
                begin
                  case FCS of
                    csRectangular:
                      if Below(FWorkData.MaxArray[M].Y, FWorkData.MaxArray[L].Y, FEpsilon) then
                        M := L;
                  else
                    if Below(DistanceOf(ZeroPoint, FWorkData.MaxArray[M]), DistanceOf(ZeroPoint, FWorkData.MaxArray[L]),
                      FEpsilon) then
                        M := L;
                  end;
                  Continue;
                end;
              Add(FWorkData.PointArray, FWorkData.MaxArray[M], FVoidRadius);
              M := L;
            end;
            if M >= 0 then
              Add(FWorkData.PointArray, FWorkData.MaxArray[M], FVoidRadius);
            if Stopped then Break;
            CrossGraph.Types.Add(FMaxArray, FWorkData.PointArray);
            FWorkData.PointArray := nil;
            M := -1;
            for L := Low(FWorkData.MinArray) to High(FWorkData.MinArray) do
            begin
              if Stopped or Overtime then Break;
              if M < 0 then
              begin
                M := L;
                Continue;
              end;
              if BelowOrEqual(CrossGraph.Geometry.DistanceOf(FWorkData.MinArray[M], FWorkData.MinArray[L]),
                FVoidRadius) then
                begin
                  case FCS of
                    csRectangular:
                      if Above(FWorkData.MinArray[M].Y, FWorkData.MinArray[L].Y, FEpsilon) then
                        M := L;
                  else
                    if Above(DistanceOf(ZeroPoint, FWorkData.MinArray[M]), DistanceOf(ZeroPoint, FWorkData.MinArray[L]),
                      FEpsilon) then
                        M := L;
                  end;
                  Continue;
                end;
              Add(FWorkData.PointArray, FWorkData.MinArray[M], FVoidRadius);
              M := L;
            end;
            if M >= 0 then
              Add(FWorkData.PointArray, FWorkData.MinArray[M], FVoidRadius);
            if Stopped then Break;
            CrossGraph.Types.Add(FMinArray, FWorkData.PointArray);
          finally
            FWorkData.PointArray := nil;
          end;
        finally
          FWorkData.MaxArray := nil;
          FWorkData.MinArray := nil;
        end;
      if I < FFormula.Count - 1 then
      begin
        CrossGraph.Types.New(FMaxArray);
        CrossGraph.Types.New(FMinArray);
      end;
      if I > 0 then
      begin
        Data.MaxBack := NextPlace(FMaxArray, FFormula.Data[I - 1].MaxFace);
        Data.MinBack := NextPlace(FMinArray, FFormula.Data[I - 1].MinFace);
      end
      else begin
        Data.MaxBack := MakePlace(0, 0);
        Data.MinBack := MakePlace(0, 0);
      end;
      Data.MaxFace := LastPlace(FMaxArray);
      Data.MinFace := LastPlace(FMinArray);
    end;
  end;
end;

constructor TGraphEngine.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);
  FActive := True;
  FAutoquality := DefaultAutoquality;
  FCS := csRectangular;
  FEpsilon := EngineResolution;
  FHighPrecision := DefaultHighPrecision;
  FJitEnabled := True;
  FMaxX := DefaultMaxX;
  FMaxY := DefaultMaxY;
  FMarkSpacing := DefaultMarkSpacing;
  FOffset := DefaultOffset;
  FOverlap := True;
  FExtreme := True;
  FPolarMaxAngle := Angle360;
  FQuality := DefaultQuality;
  FSize.cx := 1;
  FSize.cy := 1;
  FThreadWorkTime := DefaultThreadWorkTime;
  FOverlapMaxDepth[csRectangular] := DefaultOverlapMaxDepth[csRectangular];
  FOverlapMaxDepth[csPolar] := DefaultOverlapMaxDepth[csPolar];
  FOverlapMaxTime[csRectangular] := DefaultOverlapMaxTime[csRectangular];
  FOverlapMaxTime[csPolar] := DefaultOverlapMaxTime[csPolar];
  FCompute[csRectangular] := ComputeRectangular;
  FCompute[csPolar] := ComputePolar;
  FFormula := TFormulaList.Create;
  FThreadList := TThreadList.Create;
  FOverlapThread := TOverlapThread.Create(Self);
  FExtremeThread := TExtremeThread.Create(Self);
  FFormula.OnChanging := FormulaChanging;
  FGlobalValue.ValueType := vtExtended;
  FOwnParser := True;
  FParser := TJitParser.Create(Self);
  for I := Low(THandle2) to High(THandle2) do
  begin
    FParser.FData.FA[TJitParser(FParser).AndHandle[I]].Priority := MakePriority(fpLower, pcTotal);
    FParser.FData.FA[TJitParser(FParser).NotHandle[I]].Priority := MakePriority(fpLower, pcTotal);
    FParser.FData.FA[TJitParser(FParser).OrHandle[I]].Priority := MakePriority(fpLower, pcTotal);
    FParser.FData.FA[TJitParser(FParser).XorHandle[I]].Priority := MakePriority(fpLower, pcTotal);
  end;
  TJitParser(FParser).Cached := False;
  Attach;
  FOverlapThread.Parser := FParser;
  FExtremeThread.Parser := FParser;
  ThreadCount := DefaultThreadCount;
end;

destructor TGraphEngine.Destroy;
begin
  FActive := False;
  FFormula.OnChanging := nil;
  Abort;
  FThreadList.Free;
  FOverlapThread.Free;
  FExtremeThread.Free;
  Detach;
  FFormula.Free;
  ParseUtils.Delete(FSA);
  CrossGraph.Types.Delete(FEntireArray);
  CrossGraph.Types.Delete(FMaxArray);
  CrossGraph.Types.Delete(FMinArray);
  inherited;
end;

procedure TGraphEngine.Attach;
begin
  if not Assigned(FParser) then Exit;
  FParser.IgnoreType[icFunction] := True;
  FParser.BeginUpdate;
  try
    FParser.AddVariable(AngleVariableName, FGlobalValue, False);
    FParser.AddVariable(ValueVariableName, FGlobalValue, False);
  finally
    FParser.EndUpdate;
    FParser.Notify(ntCompile, Self);
  end;
end;

procedure TGraphEngine.Detach;
begin
  if not Assigned(FParser) then Exit;
  FParser.BeginUpdate;
  try
    FParser.DeleteVariable(FGlobalValue);
  finally
    FParser.EndUpdate;
    FParser.Notify(ntCompile, Self);
  end;
end;

procedure TGraphEngine.SetParser(const Value: TParser);
var
  I: Integer;
begin
  if FParser = Value then Exit;
  Detach;
  if FOwnParser then
  begin
    FParser.Free;
    FOwnParser := False;
  end;
  FParser := Value;
  Attach;
  FOverlapThread.Parser := FParser;
  FExtremeThread.Parser := FParser;
  for I := 0 to FThreadList.Count - 1 do FThreadList[I].Parser := FParser;
end;

procedure TGraphEngine.Abort;
var
  I: Integer;
begin
  for I := 0 to FThreadList.Count - 1 do FThreadList[I].Abort;
  FOverlapThread.Abort;
  FExtremeThread.Abort;
end;

procedure TGraphEngine.StartOverlap;
begin
  if FOverlap and Assigned(FOverlapThread) and FOverlapThread.Prepared then
    FOverlapThread.Start;
end;

procedure TGraphEngine.StartExtreme;
begin
  if FExtreme and Assigned(FExtremeThread) and FExtremeThread.Prepared then
    FExtremeThread.Start;
end;

procedure TGraphEngine.Stop;
var
  I: Integer;
begin
  for I := 0 to FThreadList.Count - 1 do FThreadList[I].Abort;
  FOverlapThread.Stop;
  FExtremeThread.Stop;
end;

function TGraphEngine.WaitFor(const AThread: TThread; const Time: LongWord): Boolean;
begin
  Result := not AThread.Active or AThread.WaitFor(Time);
  if not Result then AThread.Abort;
end;

function TGraphEngine.GetBusy: Boolean;

  function Working: Boolean;
  var
    I: Integer;
  begin
    for I := 0 to FThreadList.Count - 1 do
      if FThreadList[I].Started then Exit(True);
    Result := False;
  end;

begin
  Result := Working or (not Assigned(FOverlapThread) or FOverlapThread.Started or (FOverlap and
    FOverlapThread.Prepared)) or (not Assigned(FExtremeThread) or FExtremeThread.Started or (FExtreme and
    FExtremeThread.Prepared));
end;

function TGraphEngine.GetThreadCount: Integer;
begin
  Result := FThreadList.Count;
end;

procedure TGraphEngine.SetThreadCount(const Value: Integer);
var
  I, J: Integer;
begin
  if FThreadList.Count = Value then Exit;
  if Value <= FThreadList.Count then
  begin
    FThreadList.Count := Value;
    Exit;
  end;
  FParser.BeginUpdate;
  try
    J := FThreadList.Count;
    FThreadList.Count := Value;
    for I := J to FThreadList.Count - 1 do
    begin
      FThreadList[I] := TParseThread.Create(Self);
      FThreadList[I].WorkTime := FThreadWorkTime;
      FThreadList[I].Parser := FParser;
    end;
  finally
    FParser.EndUpdate;
    FParser.Notify(ntCompile, Self);
  end;
  FParser.Prepare;
end;

procedure TGraphEngine.SetThreadWorkTime(const Value: LongWord);
var
  I: Integer;
begin
  if FThreadWorkTime = Value then Exit;
  FThreadWorkTime := Value;
  for I := 0 to FThreadList.Count - 1 do FThreadList[I].WorkTime := Value;
end;

function TGraphEngine.GetOverlapMaxDepth: Integer;
begin
  Result := FOverlapMaxDepth[FCS];
end;

function TGraphEngine.GetOverlapTotal: Integer;
begin
  if Assigned(FOverlapThread) then
    Result := FOverlapThread.Total
  else
    Result := 0;
end;

function TGraphEngine.GetSameArray: TSameArray;
begin
  if Assigned(FOverlapThread) then
    Result := FOverlapThread.SameArray
  else
    Result := nil;
end;

procedure TGraphEngine.SetOverlapMaxDepth(const Value: Integer);
begin
  FOverlapMaxDepth[FCS] := Value;
end;

function TGraphEngine.GetOverlapMaxTime: Integer;
begin
  Result := FOverlapMaxTime[FCS];
end;

procedure TGraphEngine.SetOverlapMaxTime(const Value: Integer);
begin
  FOverlapMaxTime[FCS] := Value;
end;

function TGraphEngine.XToCursor(const X: Extended): Extended;
begin
  Result := FCenter.X + (FOffset.X + X) * FCenter.X / FMaxX;
end;

function TGraphEngine.XToPoint(const X: Extended): Extended;
begin
  Result := X * FMaxX / FCenter.X - (FMaxX + FOffset.X);
end;

function TGraphEngine.YToCursor(const Y: Extended): Extended;
begin
  Result := FCenter.Y - (FOffset.Y + Y) * FCenter.Y / FMaxY;
end;

function TGraphEngine.YToPoint(const Y: Extended): Extended;
begin
  Result := (FMaxY - FOffset.Y) - Y * FMaxY / FCenter.Y;
end;

function TGraphEngine.PointToCursor(const Point: TPointD): TPointD;
begin
  Result.X := XToCursor(Point.X);
  Result.Y := YToCursor(Point.Y);
end;

function TGraphEngine.CursorToPoint(const Point: TPointD): TPointD;
begin
  Result.X := XToPoint(Point.X);
  Result.Y := YToPoint(Point.Y);
end;

function TGraphEngine.Examine(const Point: TPointD): Boolean;
begin
  Result := not IsNan(Point.X) and not IsInfinite(Point.X) and not IsNan(Point.Y) and not IsInfinite(Point.Y) and
    AboveOrEqual(Point.X, FMin.X, FEpsilon) and BelowOrEqual(Point.X, FMax.X, FEpsilon) and
    AboveOrEqual(Point.Y, FMin.Y, FEpsilon) and BelowOrEqual(Point.Y, FMax.Y, FEpsilon);
end;

function TGraphEngine.ComputePolar(const Value: Extended; const Script: TScript): TPointD;
begin
  FGlobalValue.Float80 := Value;
  ParseLoopLeft := NativeInt(FThreadWorkTime) * TurnsPerMillisecond;
  Result := PointAtAngle(ZeroPoint, Value, GetExtended(FParser.ExecuteScript(Script)^));
end;

function TGraphEngine.ComputeRectangular(const Value: Extended; const Script: TScript): TPointD;
begin
  FGlobalValue.Float80 := Value;
  ParseLoopLeft := NativeInt(FThreadWorkTime) * TurnsPerMillisecond;
  Result := PointD(Value, GetExtended(FParser.ExecuteScript(Script)^));
end;

function TGraphEngine.GetDisplay: TDisplay;
var
  XA, YA, XB, YB: Boolean;
begin
  XA := AboveOrEqual(FMin.X, 0, FEpsilon);
  YA := AboveOrEqual(FMin.Y, 0, FEpsilon);
  XB := BelowOrEqual(FMax.X, 0, FEpsilon);
  YB := BelowOrEqual(FMax.Y, 0, FEpsilon);
  if XA and YA then
  begin
    Result.QuarterKind := qkA;
    if Equal(FMin.Y, 0) then
      Result.Range.Min := 0
    else
      Result.Range.Min := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMin.Y));
    if Equal(FMin.X, 0) then
      Result.Range.Max := Angle90
    else
      Result.Range.Max := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMax.Y));
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, FMin);
    Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMax);
  end
  else if XB and YA then
  begin
    Result.QuarterKind := qkB;
    if Equal(FMax.X, 0) then
      Result.Range.Min := Angle90
    else
      Result.Range.Min := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMax.Y));
    if Equal(FMin.Y, 0) then
      Result.Range.Max := Pi
    else
      Result.Range.Max := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMin.Y));
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, PointD(FMax.X, FMin.Y));
    Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMin.X, FMax.Y));
  end
  else if YB and XB then
  begin
    Result.QuarterKind := qkC;
    if Equal(FMax.Y, 0) then
      Result.Range.Min := Pi
    else
      Result.Range.Min := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMax.Y));
    if Equal(FMax.X, 0) then
      Result.Range.Max := Pi + Angle90
    else
      Result.Range.Max := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMin.Y));
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, FMax);
    Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMin);
  end
  else if XA and YB then
  begin
    Result.QuarterKind := qkD;
    if Equal(FMin.X, 0) then
      Result.Range.Min := Pi + Angle90
    else
      Result.Range.Min := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMin.Y));
    if Equal(FMax.Y, 0) then
      Result.Range.Max := Angle360
    else
      Result.Range.Max := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMax.Y));
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, PointD(FMin.X, FMax.Y));
    Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMax.X, FMin.Y));
  end
  else if YA then
  begin
    Result.QuarterKind := qkAB;
    if Equal(FMin.Y, 0) then
    begin
      Result.Range.Min := 0;
      Result.Range.Max := Pi;
    end
    else begin
      Result.Range.Min := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMin.Y));
      Result.Range.Max := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMin.Y));
    end;
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, PointD(0, FMin.Y));
    if Above(Abs(FMax.X), Abs(FMin.X), FEpsilon) then
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMax)
    else
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMin.X, FMax.Y));
  end
  else if XB then
  begin
    Result.QuarterKind := qkBC;
    if Equal(FMax.X, 0) then
    begin
      Result.Range.Min := Angle90;
      Result.Range.Max := Pi + Angle90;
    end
    else begin
      Result.Range.Min := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMax.Y));
      Result.Range.Max := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMin.Y));
    end;
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, PointD(FMax.X, 0));
    if Above(Abs(FMax.Y), Abs(FMin.Y), FEpsilon) then
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMin.X, FMax.Y))
    else
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMin);
  end
  else if YB then
  begin
    Result.QuarterKind := qkCD;
    if Equal(FMax.Y, 0) then
    begin
      Result.Range.Min := Pi;
      Result.Range.Max := Angle360;
    end
    else begin
      Result.Range.Min := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMax.Y));
      Result.Range.Max := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMax.X, FMax.Y));
    end;
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, PointD(0, FMax.Y));
    if Above(Abs(FMax.X), Abs(FMin.X), FEpsilon) then
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMax.X, FMin.Y))
    else
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMin);
  end
  else if XA then
  begin
    Result.QuarterKind := qkDA;
    if Equal(FMin.X, 0) then
    begin
      Result.Range.Min := Pi + Angle90;
      Result.Range.Max := Angle360 + Angle90;
    end
    else begin
      Result.Range.Min := Angle360 - VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMin.Y));
      Result.Range.Max := VertexAngle(PointD(FMaxX, 0), ZeroPoint, PointD(FMin.X, FMax.Y));
    end;
    Result.FromCenter[dtMin] := DistanceOf(ZeroPoint, PointD(FMin.X, 0));
    if Above(Abs(FMax.Y), Abs(FMin.Y), FEpsilon) then
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMax)
    else
      Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMax.X, FMin.Y));
  end
  else begin
    Result.QuarterKind := qkABCD;
    Result.Range := WholeRange;
    Result.FromCenter[dtMin] := 0;
    XA := Above(Abs(FMax.X), Abs(FMin.X), FEpsilon);
    YA := Above(Abs(FMax.Y), Abs(FMin.Y), FEpsilon);
    if XA then
      if YA then
        Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMax)
      else
          Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMax.X, FMin.Y))
    else
      if YA then
        Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, PointD(FMin.X, FMax.Y))
      else
          Result.FromCenter[dtMax] := DistanceOf(ZeroPoint, FMin);
  end;
end;

function TGraphEngine.GetPolarRangeArray: TRangeArray;
var
  Display: TDisplay;
  Angle: Extended;
begin
  Result := nil;
  Display := GetDisplay;
  case Display.QuarterKind of
    qkA, qkB:
      begin
        Angle := 0;
        while Below(Angle, FPolarMaxAngle) do
        begin
          Add(Result, MakeRange(Display.Range.Min + Angle, Display.Range.Max + Angle));
          Add(Result, MakeRange(Display.Range.Min + Angle + Pi, Display.Range.Max + Angle + Pi));
          Angle := Angle + Angle360;
        end;
      end;
    qkC, qkD:
      begin
        Angle := 0;
        while Below(Angle, FPolarMaxAngle) do
        begin
          Add(Result, MakeRange(Display.Range.Min + Angle, Display.Range.Max + Angle));
          Add(Result, MakeRange(Display.Range.Min + Angle - Pi, Display.Range.Max + Angle - Pi));
          Angle := Angle + Angle360;
        end;
      end;
  else
    Add(Result, MakeRange(0, FPolarMaxAngle));
  end;
end;

function TGraphEngine.PointCount(const Segment: PExtended): Extended;
begin
  case FCS of
    csRectangular: Result := FSize.cx;
  else
    if Assigned(Segment) then
      Result := Segment^ * (FSize.cx + FSize.cy) / 2
    else
      Result := Angle360 * (FSize.cx + FSize.cy) / 2;
  end;
end;

procedure TGraphEngine.Prepare;
var
  Resolution: Extended;
begin
  if FSize.cx <= 0 then FSize.cx := 1;
  if FSize.cy <= 0 then FSize.cy := 1;
  FCenter := PointD(FSize.cx / 2, FSize.cy / 2);
  FMin := PointD(-FMaxX - FOffset.X, -FMaxY - FOffset.Y);
  FMax := PointD(FMaxX - FOffset.X, FMaxY - FOffset.Y);
  FXFactor := FCenter.X / FMaxX;
  FYFactor := FCenter.Y / FMaxY;
  Resolution := DistanceOf(CursorToPoint(PointD(0, 0)), CursorToPoint(PointD(1, 1)));
  if FExtremeVaryRadius <= 0 then
    FExtremeVaryRadius := ExtremeVaryFactor * Resolution;
  if FExtremeVoidRadius <= 0 then
    FExtremeVoidRadius := ExtremeVoidFactor * Resolution;
end;

procedure TGraphEngine.Capture;
var
  I, J, Prior: Integer;
  Source: TCurveDArray;
begin
  for I := 0 to FThreadList.Count - 1 do
  begin
    Source := FThreadList[I].PointArray;
    Prior := -1;
    for J := I - 1 downto 0 do
      if Assigned(FThreadList[J].PointArray) then
      begin
        Prior := J;
        Break;
      end;
    for J := Low(Source) to High(Source) do
    begin
      if (J > Low(Source)) or FThreadList[I].Gap[gtBack] or ((Prior >= 0) and (((I - Prior) > 1) or
        FThreadList[Prior].Gap[gtFace])) then
          CrossGraph.Types.New(FEntireArray);
      CrossGraph.Types.Add(FEntireArray, Source, J);
    end;
    Source := nil;
  end;
  for I := 0 to FThreadList.Count - 1 do FThreadList[I].Clear;
end;

procedure TGraphEngine.ParseRange(const Script: TScript; const RangeArray: TRangeArray; const Step: Extended;
  const MinStep: PExtended);
var
  I, J, K: Integer;
  FromTime: LongWord;
  Count, Start: Extended;
  AThread: TParseThread;
  Overtime: Boolean;
begin
  for I := Low(RangeArray) to High(RangeArray) do
  begin
    Count := (RangeArray[I].Max - RangeArray[I].Min) / FThreadList.Count;
    for J := 0 to FThreadList.Count - 1 do
      if FThreadList[J].Active then
      begin
        FThreadList[J].Stop;
        FThreadList[J].WaitFor(FThreadList[J].AbortTime);
      end;
    for J := 0 to FThreadList.Count - 1 do FThreadList[J].Clear;
    for J := 0 to FThreadList.Count - 1 do
    begin
      AThread := FThreadList[J];
      AThread.WorkTime := FThreadWorkTime;
      AThread.GlobalValue := @FGlobalValue;
      Start := RangeArray[I].Min + J * Count;
      AThread.Push(MakeRange(Start, Start + Count));
      AThread.Step := Step;
      AThread.Display := GetDisplay;
      AThread.Script := Copy(Script);
      AThread.Epsilon := FEpsilon;
      AThread.Autoquality := FAutoquality;
      AThread.CS := FCS;
      AThread.MaxX := FMaxX;
      AThread.MaxY := FMaxY;
      AThread.JitEnabled := FJitEnabled;
      if FCS = csPolar then
        AThread.Compute := AThread.ComputePolar
      else
        AThread.Compute := AThread.ComputeRectangular;
      AThread.PointToCursor := PointToCursor;
      AThread.CursorToPoint := CursorToPoint;
      AThread.Examine := Examine;
      if not AThread.Start then
      begin
        AThread.Stop;
        AThread.WaitFor(AThread.AbortTime);
        AThread.Start;
      end;
    end;
    FromTime := GetTickCount;
    for J := 0 to FThreadList.Count - 1 do
    begin
      AThread := FThreadList[J];
      K := AThread.WorkTime + FromTime - GetTickCount;
      if K > 0 then
        Overtime := not WaitFor(AThread, K)
      else
        Overtime := not WaitFor(AThread, 0);
      if Assigned(MinStep) and not Overtime and Above(MinStep^, AThread.MinStep, FEpsilon) then
        MinStep^ := AThread.MinStep;
    end;
    for J := 0 to FThreadList.Count - 1 do
      if FThreadList[J].Active then
      begin
        FThreadList[J].Stop;
        FThreadList[J].WaitFor(FThreadList[J].AbortTime);
      end;
    Capture;
  end;
end;

procedure TGraphEngine.Clear;
begin
  Abort;
  FExchange.OverlapArray := nil;
  FExchange.MaxArray := nil;
  FExchange.MinArray := nil;
  ParseUtils.Delete(FSA);
  CrossGraph.Types.Delete(FEntireArray);
  FOverlapArray := nil;
  CrossGraph.Types.Delete(FMaxArray);
  CrossGraph.Types.Delete(FMinArray);
  FFormula.Clear;
end;

procedure TGraphEngine.Parse;
begin
  if FParsing then Exit;
  FParsing := True;
  try
    DoParse;
  finally
    FParsing := False;
  end;
end;

procedure TGraphEngine.DoParse;
var
  I, J, Prior: Integer;
  Script: TScript;
  Step: Extended;
  Data: PFormulaData;
begin
  Abort;
  FOverlapThread.Clear;
  FExtremeThread.Clear;
  ParseUtils.Delete(FSA);
  CrossGraph.Types.Delete(FEntireArray);
  FOverlapArray := nil;
  CrossGraph.Types.Delete(FMaxArray);
  CrossGraph.Types.Delete(FMinArray);
  FErrorMessage := '';
  ParseLoopLeft := NativeInt(FThreadWorkTime) * TurnsPerMillisecond;
  Prior := 0;
  for I := 0 to FFormula.Count - 1 do if FFormula.Correct[I] then
  begin
    try
      try
        FParser.StringToScript(FFormula[I], Script);
        FParser.ExecuteScript(Script);
      except
        on E: Exception do
        begin
          FErrorMessage := E.Message;
          FFormula.Data[I].Color := IncorrectColor;
          FFormula.Visible[I] := False;
          FFormula.Correct[I] := False;
          Continue;
        end;
      end;
      FFormula.Data[I].ScriptIndex := AddScript(FSA, Script);
    finally
      Script := nil;
    end;
    for J := 0 to FThreadList.Count - 1 do FThreadList[J].RangeArray := nil;
    case FCS of
      csRectangular:
        begin
          FOverlapThread.RangeArray := MakeRangeArray(MakeRange(FMin.X, FMax.X));
          Step := (FMaxX + FMaxY) / PointCount / FQuality;
          ParseRange(FSA[FFormula.Data[I].ScriptIndex], FOverlapThread.RangeArray, Step, @Step);
          if I = 0 then
          begin
            FOverlapThread.Step := Step;
            FExtremeThread.Step := Step;
          end
          else begin
            if Above(FOverlapThread.Step, Step) then
              FOverlapThread.Step := Step;
            if Above(FExtremeThread.Step, Step) then
              FExtremeThread.Step := Step;
          end;
        end
    else
      FOverlapThread.RangeArray := GetPolarRangeArray;
      if Assigned(FOverlapThread.RangeArray) then
      begin
        Step := FOverlapThread.Distance / Length(FOverlapThread.RangeArray);
        Step := (FMaxX + FMaxY) * Step / PointCount(@Step) / FQuality;
        ParseRange(FSA[FFormula.Data[I].ScriptIndex], FOverlapThread.RangeArray, Step, @Step);
        if I = 0 then
        begin
          FOverlapThread.Step := Step;
          FExtremeThread.Step := Step;
        end
        else begin
          if Above(FOverlapThread.Step, Step) then FOverlapThread.Step := Step;
          if Above(FExtremeThread.Step, Step) then FExtremeThread.Step := Step;
        end;
      end;
    end;
    Data := FFormula.Data[I];
    if I > 0 then
      Data.EntireBack := NextPlace(FEntireArray, FFormula.Data[Prior].EntireFace)
    else
      Data.EntireBack := MakePlace(0, 0);
    if I < FFormula.Count - 1 then CrossGraph.Types.New(FEntireArray);
    Data.EntireFace := LastPlace(FEntireArray);
    Prior := I;
  end;
  if Assigned(FSA) and Assigned(FOverlapThread.RangeArray) then
  begin
    FOverlapThread.GlobalValue := @FGlobalValue;
    FOverlapThread.OverlapArray := nil;
    FOverlapThread.Exchange := @FExchange;
    FOverlapThread.JitEnabled := FJitEnabled;
    FOverlapThread.SA := FSA;
    FOverlapThread.Min := FMin.Y;
    FOverlapThread.Max := FMax.Y;
    FOverlapThread.PolarMaxAngle := FPolarMaxAngle;
    FOverlapThread.CS := FCS;
    FOverlapThread.MaxX := FMaxX;
    FOverlapThread.MaxY := FMaxY;
    FOverlapThread.Size := FSize;
    FOverlapThread.MarkSpacing := FMarkSpacing;
    FOverlapThread.HighPrecision := FHighPrecision;
    FOverlapThread.MaxDepth := FOverlapMaxDepth[FCS];
    FOverlapThread.MaxTime := FOverlapMaxTime[FCS];
    FOverlapThread.Formula := FFormula;
    FOverlapThread.Epsilon := FEpsilon;
    if FCS = csPolar then
      FOverlapThread.Compute := FOverlapThread.ComputePolar
    else
      FOverlapThread.Compute := FOverlapThread.ComputeRectangular;
    FOverlapThread.Examine := Examine;
    FOverlapThread.Prepared := True;
    if FOverlap then FOverlapThread.Start;
  end;
  if Assigned(FEntireArray) then
  begin
    FExtremeThread.Exchange := @FExchange;
    FExtremeThread.VaryRadius := FExtremeVaryRadius;
    if FMarkSpacing > 0 then
      FExtremeThread.VoidRadius := FMarkSpacing * DistanceOf(CursorToPoint(PointD(0, 0)), CursorToPoint(PointD(1, 0)))
    else
      FExtremeThread.VoidRadius := FExtremeVoidRadius;
    FExtremeThread.Min := FMin;
    FExtremeThread.Max := FMax;
    FExtremeThread.CS := FCS;
    FExtremeThread.MaxX := FMaxX;
    FExtremeThread.MaxY := FMaxY;
    FExtremeThread.Epsilon := FEpsilon;
    FExtremeThread.EntireArray := FEntireArray;
    FExtremeThread.Formula := FFormula;
    FExtremeThread.Prepared := True;
    if FExtreme then FExtremeThread.Start;
  end;
end;

function TGraphEngine.GetOverlapArray: TOverlapArray;
begin
  TakeOverlap;
  Result := FOverlapArray;
end;

function TGraphEngine.GetMaxArray: TCurveDArray;
begin
  TakeExtreme;
  Result := FMaxArray;
end;

function TGraphEngine.GetMinArray: TCurveDArray;
begin
  TakeExtreme;
  Result := FMinArray;
end;

procedure TGraphEngine.TakeOverlap;
begin
  if not Assigned(FExchange.OverlapArray) then Exit;
  Pointer(FOverlapArray) := TakeArrayRef(FExchange.OverlapArray);
end;

procedure TGraphEngine.TakeExtreme;
begin
  if Assigned(FExchange.MaxArray) then
    Pointer(FMaxArray) := TakeArrayRef(FExchange.MaxArray);
  if not Assigned(FExchange.MinArray) then Exit;
  Pointer(FMinArray) := TakeArrayRef(FExchange.MinArray);
end;

procedure TGraphEngine.FormulaChanging;
begin
  Abort;
end;

procedure TGraphEngine.ResultReady(const Kind: TResultKind);
begin
  if Assigned(FOnResultReady) then FOnResultReady(Self, Kind);
end;

end.
