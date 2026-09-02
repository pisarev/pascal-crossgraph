{ ************************************************************************** }
{                                                                            }
{ GettingStarted - the shortest CrossGraph program there is                   }
{                                                                            }
{ Copyright © 2026 Yuriy Pisarev (ypisareff@outlook.com)                     }
{                                                                            }
{ ************************************************************************** }

program GettingStarted;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  {$IFDEF FPC}
  Interfaces, Forms, Controls, Graphics, Classes,
  {$ELSE}
  Vcl.Forms, Vcl.Controls, Vcl.Graphics, System.Classes,
  {$ENDIF}
  CrossGraph;

type
  TMainForm = class(TForm)
  public
    Graph: TGraph;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); override;
  end;

constructor TMainForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited CreateNew(AOwner, Dummy);
  Caption := 'CrossGraph - getting started';
  Width := 720;
  Height := 520;
  Position := poScreenCenter;
  Graph := TGraph.Create(Self);
  Graph.Parent := Self;
  Graph.Align := alClient;
  Graph.MaxX := 10;
  Graph.MaxY := 5;
  Graph.Formula.Add('sin(x)', True, True, True);
  Graph.Formula.Add('x*x/10 - 3', True, True, False);
  Graph.Tracing := True;
  Graph.Build;
end;

var
  MainForm: TMainForm;

begin
  Application.Initialize;
  MainForm := TMainForm.CreateNew(Application);
  MainForm.Show;
  Application.Run;
end.
