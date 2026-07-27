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
reaches hardware. `qsys_stub.lua` stands in for the host globals Q-SYS
provides (`Controls`, `Timer`, `TcpSocket`, `Properties`, `System`) so the
same code can be driven from a terminal.

This is not a substitute for testing in Designer. The stub models what the
plugins use, not what Q-SYS does, so it can only catch the class of bug that
lives in the plugin's own logic. Anything about real DSP behaviour, real
timing, or the actual Designer UI still has to be checked on the bench.

## Layout

| File | What it covers |
|---|---|
| `qsys_stub.lua` | The fake Q-SYS host. Timers never fire on their own; tests advance them with `env.tick(n)`, so the poll loop can be stepped one iteration at a time. |
| `harness.lua` | Path resolution and the check counter. |
| `test_modules.lua` | The CPSeries class straight from `Developer/Modules`: query framing per model, the readiness handshake, fader scaling, both format-list dialects, and the guards against bad wire data. |
| `test_plugin_defs.lua` | The `Get*` callbacks in `Developer/plugins`, including the nil-props case Q-SYS triggers during plugin registration. |
| `test_dist_cpseries.lua` | The root CP Series distributable, both host passes. |
| `test_dist_fader.lua` | The root Dolby Fader distributable, both host passes, plus the dB to Dolby-scale mapping. |
| `wire_trace.lua` | Behavioural trace, see below. |

The two `test_dist_*` files matter more than they look. A distributable is a
single-file build with the modules pasted inline, and a module inlined before
something it depends on still *compiles* — `luac -p` cannot see it. Only
running the file does, which is what these do.

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
package.path = (arg[0]:match("^(.*)[/\\]") or ".") .. "/?.lua;" .. package.path
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
