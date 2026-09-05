# Tests

Plain Lua 5.3 -- matches Q-SYS Designer's own embedded Lua version
(confirmed against Q-SYS Help, which points to the Lua 5.3 Reference
Manual), not 5.4. No test framework, no package manager, nothing to
install beyond a Lua interpreter, which matches how the rest of this repo
works.

```sh
Developer/tests/run.sh                 # syntax pass, then every test
Developer/tests/run.sh --syntax-only   # just luac -p over every source
```

Runs from any working directory. Override the interpreter with
`LUA=lua5.4 LUAC=luac5.4 ./run.sh` if you need to sanity-check against 5.4
instead, or the binaries are named differently.

## Why these tests exist at all

Plugins normally only run inside Q-SYS Designer, against a real processor or
one of the emulators in `Dolby CP Emulator/`. That makes the ordinary edit
loop slow and manual, and it means nothing catches a regression before it
reaches hardware. `Developer/host-emulator/qsys_stub.lua` stands in for the
host globals Q-SYS provides (`Controls`, `Timer`, `TcpSocket`, `Properties`,
`System`) so the same code can be driven from a terminal -- a different
target than `Dolby CP Emulator/`, which emulates the Dolby processors
themselves, not the Q-SYS Designer host.

This is not a substitute for testing in Designer. The stub models what the
plugins use, not what Q-SYS does, so it can only catch the class of bug that
lives in the plugin's own logic. Anything about real DSP behaviour, real
timing, or the actual Designer UI still has to be checked on the bench.

## Layout

| File | What it covers |
|---|---|
| `../host-emulator/qsys_stub.lua` | The fake Q-SYS host. Timers never fire on their own; tests advance them with `env.tick(n)`, so the poll loop can be stepped one iteration at a time. |
| `harness.lua` | Path resolution and the check counter. |
| `test_modules.lua` | The CPSeries class straight from `Developer/plugins/Dolby CPSeries Control/{models,protocol,commlib}.lua`: query framing per model, the readiness handshake, fader scaling, both format-list dialects, and the guards against bad wire data. |
| `test_dist_cpseries.lua` | The root CP Series distributable, both host passes. |
| `test_dist_fader.lua` | The root Dolby Fader distributable, both host passes, plus the dB to Dolby-scale mapping. |
| `test_dist_sweep.lua` | The root Dolby Sweep distributable, both host passes, the one-time init and a sweep tick. |
| `test_dist_flipflop.lua` | The root MultiFlip-Flop distributable, both host passes, the Exclusive interlock and `Toggle_N`. |
| `test_dist_subharmonic.lua` | The root SubharmonicSynth distributable, both host passes, the one-time init and the bypass routing. |
| `test_stress.lua` | Stress and fuzz pass over all five plugins, see below. |
| `wire_trace.lua` | Behavioural trace, see below. |

The `test_dist_*` files matter more than they look. A distributable is a
single-file build with the modules pasted inline, and a module inlined before
something it depends on still *compiles* — `luac -p` cannot see it. Only
running the file does, which is what these do.

## Stress and fuzz

`test_stress.lua` is the odd one out: where every other file pins down exact
values for known-good inputs, it hammers each plugin with volume, boundary
values and deliberate garbage, then asserts only what has to survive all of
it — nothing throws, nothing publishes a nil, and every value a plugin writes
stays inside the range it declares. The CP Series section is the important
one, since the wire is the only place in this repo where bytes from a device
nobody controls reach plugin code.

Two things about it are worth preserving if you extend it. It seeds
`math.random` with a fixed constant, so a failure is reproducible from the
same seed instead of vanishing on the next run. And several sections carry an
explicit anti-vacuity check — that the fuzz corpus actually reached the
parser, that the storm really did spend rounds bypassed, that multiple
flip-flop instances really are reachable with `Exclusive` off. Those exist
because an invariant nothing ever exercises passes for the wrong reason: the
corpus originally left CP 650 and CP 750 rejecting every line before it
reached their fader and format handlers, and the checks all passed anyway.

## Comparing two builds

`wire_trace.lua` loads a build, lets it construct its own socket, drives the
poll loop, and prints every byte the plugin puts on the wire plus the
resulting control state. It is deliberately blind to internal structure, so
two builds that print the same trace behave the same however they are
organised. That makes it the tool to reach for after a refactor:

```sh
cd Developer/tests
lua5.3 wire_trace.lua "../../Dolby CPSeries Control V3.0.qplug" > new.txt
lua5.3 wire_trace.lua /path/to/known-good.qplug                 > old.txt
diff old.txt new.txt
```

It takes an optional `--no-formlist`, which presses a format button before
the processor has reported its format list. That used to publish a nil format
name and crash the component on the plugin's own assert; `run.sh` runs it as
a regression check.

## Adding a test

Each file starts with the same three lines, then builds an environment and
drives it:

```lua
local test_dir = (arg[0]:match("^(.*)[/\\]") or ".")
package.path = test_dir .. "/?.lua;" .. test_dir .. "/../host-emulator/?.lua;" .. package.path
local h = require("harness")
local qsys = require("qsys_stub")

local env = qsys.install({
  controls   = qsys.CPSERIES_CONTROLS,
  selectors  = 8,
  properties = qsys.cpseries_properties("CP 850"),
})
assert(loadfile(h.DIST.cpseries))()      -- or require a module directly

h.check(DKNob ~= nil, "what this proves")
h.report()
```

`install()` clears the plugin globals first, so anything the modules expect to
find already defined has to be set up after that call, not before. Register
the new file in `run.sh`.
