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

Delphi 13, or Free Pascal **3.2.2 and newer** - the stable compiler a normal
install brings. The parser next door has always built with 3.2.2; the plotting
engine does now as well, checked by building and running the battery on it:
149 checks and a 200-run stress pass on Free Pascal 3.2.2 with Lazarus 3.6.0.

Two things used to stand in the way, and both are gone. `CrossVision.Geometry`
sorted points with an anonymous comparer, and function references arrived only
in 3.3.1; the sort is now written out in the same unit, which is what that unit
needs - it is the one place that leans on nothing but the RTL. `CrossGraph.Engine` counted compiled scripts with
`AtomicIncrement`, which 3.2.2 does not have; it uses `InterlockedIncrement`,
as the parser does.

## Building

```
pwsh -File ci\check-windows.ps1
```

That builds and runs everything: the component on win32 and win64 under Delphi,
and the engine headless under FPC. On Linux use `tests/build_linux.sh` - the
engine needs no display there either.

```bash
tests/build_linux.sh
```

## Putting the component on the palette

`packages/lazarus/crosspascal_graph.lpk` is a design-time package as well as a
runtime one. Open it in Lazarus and press `Install`: the IDE rebuilds itself and
`TGraph` appears on the `Samples` page of the component palette, ready to be
dropped on a form.

The parser and the accelerator next door come along on their own: this package
requires them, so installing this one is enough. They carry components of their
own - eleven of them, listed in the parser's README - and those appear on the
same page.

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
