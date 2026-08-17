{ ************************************************************************** }
{                                                                            }
{ EngineStress                                                               }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                      }
{                                                                            }
{ ************************************************************************** }

{
  Reproducing the failure that shows up in the plugin as an empty plot or a
  crash on the first build. One engine serves every run, as in the panel, while
  the formulas change and a recomputation starts without waiting for the
  previous one. That is how the main thread lands in Capture while the parsing
  threads are still writing their arrays.

  A failure is a run with no points at all for a valid formula, or an exception.
}

program EngineStress;

{$APPTYPE CONSOLE}
{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

uses
  {$IFDEF FPC}
  {$IFDEF UNIX}cthreads,{$ENDIF}
  { Built with -dNOFORMS: the base Thread then does not pull in Forms and no
    widgetset is needed. Without the flag Interfaces is pulled in.
    GetTickCount64 and Sleep come from SysUtils and are portable, so the Windows
    unit is no longer needed. }
  {$IFNDEF NOFORMS}Interfaces,{$ENDIF} SysUtils, Math, Classes, Types,
  {$ELSE}
  Winapi.Windows, System.SysUtils, System.Math, System.Classes, System.Types,
  {$ENDIF}
  CrossVision.Geometry.Types, CrossGraph.Types, CrossGraph.Engine;

{$IFDEF FPC}
function GetTickCount: LongWord;
begin
  Result := LongWord(SysUtils.GetTickCount64);
end;
{$ENDIF}

const
  CanvasSide = 600;
  WaitLimit = 8000;
  PollStep = 2;
  Rounds = 200;

type
  TWaiter = class
    Ready: Boolean;
    procedure Handle(Sender: TObject; const Kind: TResultKind);
  end;

procedure TWaiter.Handle(Sender: TObject; const Kind: TResultKind);
begin
  if Kind = rkOverlap then Ready := True;
end;

var
  Engine: TGraphEngine;
  Waiter: TWaiter;
  Formulas: array[0 .. 3] of string = (
    'Sin(X)',
    'Cos(X)/2',
    'Sin(X*3)/2',
    'X*X/8-2'
  );

// The number of points over all curves: exactly what the panel shows under the plot.
function PointCount: Integer;
var
  A: TCurveDArray;
  I: Integer;
begin
  Result := 0;
  A := Engine.EntireArray;
  for I := Low(A) to High(A) do Inc(Result, Length(A[I]));
end;

{
  Checking the formula boundaries: the end of each has to be non-empty, and the
  start of the next one has to come strictly after the previous end, with no
  overlap.
}
function RangeFault: string;
var
  A: TCurveDArray;
  Back, Face, Prev: TPlace;
  I: Integer;
  Started: Boolean;
begin
  Result := '';
  A := Engine.EntireArray;
  Started := False;
  Prev := MakePlace(-1, -1);
  for I := 0 to Engine.Formula.Count - 1 do
  begin
    if not Engine.Formula.Correct[I] then Continue;
    Back := Engine.Formula.Data[I].EntireBack;
    Face := Engine.Formula.Data[I].EntireFace;
    if (Face.ArrayIndex < Low(A)) or (Face.ArrayIndex > High(A)) or (Face.Index < 0) then
      Exit(Format(' EMPTY BOUNDARY: formula %d end %d.%d', [I, Face.ArrayIndex, Face.Index]));
    if Started and ((Back.ArrayIndex < Prev.ArrayIndex) or ((Back.ArrayIndex = Prev.ArrayIndex) and
      (Back.Index <= Prev.Index))) then
        Exit(Format(' BOUNDARIES OVERLAP: formula %d start %d.%d, previous end %d.%d',
          [I, Back.ArrayIndex, Back.Index, Prev.ArrayIndex, Prev.Index]));
    Prev := Face;
    Started := True;
  end;
end;

var
  I, Empty, Broken, Lost, Torn, Points, Pieces, Nudge: Integer;
  Start: Cardinal;
  Note: string;

begin
  Empty := 0;
  Broken := 0;
  Waiter := TWaiter.Create;
  Engine := TGraphEngine.Create(nil);
  try
    Engine.OnResultReady := Waiter.Handle;
    Engine.Size := TSize.Create(CanvasSide, CanvasSide);
    Engine.CS := csRectangular;
    Engine.MaxX := 10;
    Engine.MaxY := 10;
    Engine.Overlap := True;
    Engine.Extreme := True;
    Engine.Quality := 18;
    for I := 1 to Rounds do
    begin
      Note := '';
      Points := 0;
      try
        {
          Changing formulas without waiting for the previous computation - the
          page does exactly this when it sends a build right after a resize.
        }
        Engine.Formula.Clear;
        Engine.Formula.Add(Formulas[I mod 2], True, True, True);
        Engine.Formula.Add(Formulas[2 + I mod 2], True, True, True);
        Waiter.Ready := False;
        Engine.Prepare;
        Engine.Parse;
        {
          Some runs are kicked again almost at once: rebuilding on the move is
          the state in which the failure is caught.
        }
        Nudge := I mod 3;
        if Nudge > 0 then
        begin
          Sleep(Nudge);
          Engine.Formula.Clear;
          Engine.Formula.Add(Formulas[I mod 2], True, True, True);
          Engine.Formula.Add(Formulas[2 + I mod 2], True, True, True);
          Waiter.Ready := False;
          Engine.Prepare;
          Engine.Parse;
        end;
        Start := GetTickCount;
        while Engine.Busy and (GetTickCount - Start < WaitLimit) do
          Sleep(PollStep);
        Points := PointCount;
      except
        on E: Exception do
        begin
          Inc(Broken);
          Note := ' EXCEPTION ' + E.ClassName + ': ' + E.Message;
        end;
      end;
      {
        Two formulas have to give at least two pieces. One piece means the
        parsing thread for the second formula never started: it is still counted
        as alive from the previous formula, and Start on a live thread silently
        does nothing.
      }
      Pieces := Length(Engine.EntireArray);
      if (Note = '') and (Points = 0) then
      begin
        Inc(Empty);
        Note := ' EMPTY';
      end
      else if (Note = '') and (Pieces < 2) then
      begin
        Inc(Lost);
        Note := ' A FORMULA WAS LOST';
      end
      else if Note = '' then
      begin
        {
          The formula boundaries in the shared array of curves have to be
          non-empty and strictly consecutive. An empty end means the formula will
          not be drawn; an overlap means it takes its neighbour curves.
        }
        Note := RangeFault;
        if Note <> '' then Inc(Torn);
      end;
      if Note <> '' then
        Writeln(Format('run %3d: points %6d, pieces %d%s', [I, Points, Pieces, Note]));
    end;
  finally
    Engine.Free;
    Waiter.Free;
  end;
  Writeln(Format('TOTAL: runs %d, empty %d, formula lost %d, boundaries broken %d, exceptions %d',
    [Rounds, Empty, Lost, Torn, Broken]));
  if Empty + Lost + Torn + Broken > 0 then Halt(1);
end.
