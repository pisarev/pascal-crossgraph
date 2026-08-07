# pascal-crossgraph - plotting for Object Pascal

A plotting engine and a visual component that draw what
[MathParser](https://github.com/pisarev/pascal-mathparser) computes. Formulas go
in as text, curves come out - with the discontinuities, the intersections and
the extrema found for you.

See it working: the
[live demo](https://pisarev.github.io/mathparser-live/demo/) draws with this
engine compiled to WebAssembly - the same intersections, extrema and report
you get from the component.

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

Delphi 13, or Free Pascal **3.3.1 and newer**. The parser next door builds with
3.2.2 as well; the plotting engine does not, and the reason is one line:
`CrossVision.Geometry` sorts points with an anonymous comparer, and function
references arrived in 3.3.1. On 3.2.2 the compiler stops with a syntax error in
the middle of that file, which reads like a broken source rather than a missing
feature - hence this paragraph, and hence `tests/build_linux.sh` saying so
itself before it tries.

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
