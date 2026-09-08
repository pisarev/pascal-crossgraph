{
  The shortest way to see what TGraph does.

  The form is assembled in code rather than in an .lfm, so the example does not
  depend on the version of the form format and opens in any environment. All
  the component needs is a parent, a size, the limits of the view and at least
  one formula; then Build.

  To build and run:

    lazbuild GettingStarted.lpi
    GettingStarted

  The crosspascal_graph package has to be installed in the environment; it
  brings crosspascal_parser and crosspascal_parserjit with it.
}
program GettingStarted;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

uses
  {$IFDEF FPC}
  { On Unix the thread driver has to come first: the component draws in a
    worker thread, and without this line the program fails at startup with
    runtime error 232. }
  {$IFDEF UNIX}cthreads,{$ENDIF}
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

  { The view: from -10 to 10 across, from -5 to 5 up and down. }
  Graph.MaxX := 10;
  Graph.MaxY := 5;
  { Add takes three flags: whether the curve is visible, whether the entry is
    checked, and whether the pointer walks along it. The walk is on for the
    first curve so that it can be seen at work. }
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
