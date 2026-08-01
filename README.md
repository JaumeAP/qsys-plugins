Plugins for QSYS
================
### Dolby Fader
Command component that emulates Dolby CP Processors fader (0.0 to 10.0)
### Dolby CPSeries Control 
Component that controls All CP Dolby Processors from CP650 to CP950A
### Dolby Sweep
Dolby Sweep Tone Generator
### Multi-Flipflop
Multiple FlipFlop in one component. Adds two things the stock Q-SYS
Flip-Flop doesn't have: `Exclusive` (only one instance active at a time
across the whole component) and `State` (a direct Boolean output per
instance, not just Set/Reset/Toggle triggers)
### SubharmonicSynth
Bass enhancement / subharmonic-style boost for LFE/Sub channels
### CP Series Emulator
Fakes a Dolby CP650/CP750/CP850/CP950/CP950A processor over TCP, for bench-testing Dolby CPSeries Control without hardware
### StateTrigger
Inverse of Multi-Flipflop: fires a Trigger pulse whenever a Boolean State input changes. `Channels` property (1-256, same convention as Multi-Flipflop's InputCount / Gain's Multi-Channel) for N independent State/Out pairs in one instance. `Detection` property (On/Off/Both, default Both) selects which direction fires: On = rising edge only, Off = falling edge only, Both = either direction
### DolbyKnobTest
Scratch/test plugin, not for production. A single native Knob control (`GainDb`, `ControlUnit="dB"`, -90 to 10) -- no external dependency, no runtime logic

