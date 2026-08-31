# Contributing

Thanks for taking the time. One person maintains this, so the process is short.

## Reporting a problem

Open an issue. What helps:

- what you drew and what came out - a screenshot says more than a paragraph;
- the coordinate system, the view range and the formula, if there is one;
- compiler and platform: Delphi or FPC, which version, 32 or 64 bit.

## Sending a change

Building is described in the README. Note that this repository is not
self-contained: it expects a pascal-mathparser checkout beside it.

- keep one change about one thing;
- match the surrounding code - this is Object Pascal in the house style;
- run the tests in tests/ and put in the pull request what you ran and what it
  printed.

## Terms

By opening a pull request you agree that your contribution is licensed to
the project owner under the MIT licence, and that the owner may relicense
the project, including your contribution, under different terms in the
future.

You keep the copyright to what you wrote. This is a licence grant, not a
transfer: it exists so the project can change its licence later without
tracking down everyone who ever sent a patch.
