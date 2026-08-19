# pascal-crossgraph - plotting for Object Pascal

A plotting engine and a visual component that draw what
[MathParser](https://github.com/pisarev/pascal-mathparser) computes. Formulas go
in as text, curves come out - with the discontinuities, the intersections and
the extrema found for you.

See it working: the
[live demo](https://pisarev.github.io/mathparser-live/demo/) draws the same
formulas, and the values behind the curves come from the parser this component
uses, compiled to WebAssembly. The drawing itself, the intersections and the
extrema are written again in JavaScript there - this engine is native code and
does not run in a browser. Treat the demo as a look at the formulas, not as
proof that the two agree point for point.

The engine is where the work happens: it samples the curve, refines
intersections, finds extrema, and does all of it on worker threads. The
component is a thin layer over it that turns curves into pixels. Nothing in the
engine knows what a canvas is, which is why it builds and runs headless.

## What is in here

| | |
|---|---|
| `src/CrossGraph.Engine.pas` | the computing part: sampling, intersections, extrema, threads |
| `src/CrossGraph.pas` | the component: a canvas, a view, a palette, mouse and keyboard |
| `src/CrossGraph.Surface.pas` | surfaces z = f(x, y) and their contour lines |
| `src/CrossGraph.Geometry.pas` | angles, slopes and the intersection of two lines |
| `src/CrossGraph.Types.pas` | points, curves and pixels |
| `src/CrossVision.Geometry*.pas` | plain computational geometry, no dependencies beyond the RTL |
| `src/Numeration.pas` | names for intersection points: A, B, C and on into AA |
| `tests/` | the regression, the drawing test, the stress bench and the benchmark |
| `packages/lazarus/` | the Lazarus package; expects a `pascal-mathparser` checkout next to this repository |
| `ci/check-windows.ps1` | the build matrix |

## It needs the parser next to it

This repository is not self-contained. It expects a checkout of
`pascal-mathparser` beside it:

```
somewhere/
  pascal-mathparser/
  pascal-crossgraph/
```

If the parser lives elsewhere, point at it with `PARSER_SRC` and `PARSER_JIT`.
The plotting engine itself is found through `GRAPH_SRC`, and the Delphi folder
through `BDS_BIN`.

## What it needs

Delphi **10.2 Tokyo and newer**, or Free Pascal **3.2.2 and newer** - the stable
compiler a normal install brings. The parser next door has always built with
3.2.2; the plotting engine does now as well, checked by building and running the
battery on it: 149 checks and a 200-run stress pass on Free Pascal 3.2.2 with
Lazarus 3.6.0.

The Delphi side is measured rather than assumed: before a release all eight
units of the engine are compiled one at a time on six installations - 10.2
Tokyo, 10.3 Rio, 10.4 Sydney, 11 Alexandria, 12 Athens and 13. Anything older
than 10.2 is untested and not claimed.

Two things used to stand in the way, and both are gone. `CrossVision.Geometry`
sorted points with an anonymous comparer, and function references arrived only
in 3.3.1; the sort is now written out in the same unit, which is what that unit
needs - it is the one place that leans on nothing but the RTL. `CrossGraph.Engine` counted compiled scripts with
`AtomicIncrement`, which 3.2.2 does not have; it uses `InterlockedIncrement`,
as the parser does.

## Installation

### From nothing

Two checkouts, side by side, and the parser goes first because this one is
written against it:

```
mkdir %USERPROFILE%\Desktop\Plot
cd /d %USERPROFILE%\Desktop\Plot
git clone https://github.com/pisarev/pascal-mathparser.git
git clone https://github.com/pisarev/pascal-crossgraph.git
cd pascal-crossgraph
```

The commands below are for `cmd`; where PowerShell needs something else it is
said on the spot.

#### The whole matrix, by script

```
set FPC_EXE=C:\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.exe
powershell -ExecutionPolicy Bypass -File ci\check-windows.ps1
```

The commands are for the PowerShell that ships with Windows; nothing here needs
PowerShell 7. `-ExecutionPolicy Bypass` is what lets a downloaded script run
under the default policy, and it holds for that one run only.

That builds and runs everything: the component on win32 and win64 under Delphi,
and the engine headless under FPC. It ends with `MATRIX IS GREEN`.

`FPC_EXE` is worth setting even though the script looks for `fpc` on the path: a
normal Lazarus install does not put it there, and without it the run ends
`MATRIX IS INCOMPLETE: 1 step(s) skipped` with a non-zero code - honest, but not
what you wanted. The path above is where Lazarus keeps its own compiler.

On Linux the engine needs no display either:

```bash
tests/build_linux.sh
```

#### With Delphi, by hand

Nothing has to be installed: the engine and the component are units, and what
they need is a search path. Both repositories go on it, and so do the include
files - `dcc64` does not take the unit path for an include path the way the IDE
does.

```
mkdir out
dcc64 -B -Q -U"src;..\pascal-mathparser\src;..\pascal-mathparser\jit" -I"src;..\pascal-mathparser\src" -Eout -NS"System;System.Win;Winapi;Vcl" tests\EngineTests.dpr
out\EngineTests.exe
```

That is the regression battery, and it prints `TOTAL: checks 158, failures 0`.
Point the same switches at your own program to use the library from code.

Keep the quotes in PowerShell: the switches carry semicolons, and unquoted they
are read as command separators before the compiler sees them. `dcc64` is not on
the path by default either - it lives in the `bin` folder of the installation,
and `rsvars.bat` there puts it on the path of the current prompt.

#### With Lazarus, by hand

The package builds from a configuration of its own, which leaves your installed
Lazarus exactly as it was:

```
mkdir lazpcp
"C:\lazarus\lazbuild.exe" --pcp=%CD%\lazpcp packages\lazarus\crosspascal_graph.lpk
```

The parser packages next door come along on their own: this one requires them.

### Putting the component on the palette

`packages/lazarus/crosspascal_graph.lpk` is a design-time package as well as a
runtime one. Open it in Lazarus and press `Install`: the IDE rebuilds itself and
`TGraph` appears on the `Samples` page of the component palette, ready to be
dropped on a form.

The parser and the accelerator next door come along here too, and they carry
components of their own - eleven of them, listed in the parser's README - which
appear on the same page.

## The engine without a screen

`-dNOFORMS` keeps Forms out of the base thread unit and `-dNOGRAPHICS` keeps
Graphics out of the blob manager. With both, the engine compiles and runs with
nothing but the RTL - no LCL, no widgetset, no display. That is not a claim, it
is a step of the matrix: `EngineTests` and `EngineStress` are built exactly that
way.

The component is a different matter: it draws, so it needs the VCL on Delphi or
the LCL on Lazarus.

## What the tests cover

| test | what it holds to account |
|---|---|
| `GraphTests` | intersections and extrema against the analytic answer, discontinuities, slice navigation |
| `DrawTests` | the curve is actually drawn - in its own colour, on both drawing paths |
| `EngineTests` | intersections with no form, no window and no message queue |
| `EngineStress` | changing formulas without waiting for the previous computation |
| `EngineBench` | what machine code gives when sampling |

`GraphTests` compares against closed-form answers rather than against a previous
run: a test that agrees with yesterday's output agrees with yesterday's bugs too.

## Licence

MIT. See [LICENSE](LICENSE).
