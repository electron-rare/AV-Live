// =====================================================================
//  boot.scd  --  Entry point auto-executable for sclang CLI
//
//  00_load.scd is split into ~32 IDE-friendly top-level blocks
//  (Cmd+Enter per block in SCIDE), which means it does NOT auto-run
//  when sclang is launched with `sclang 00_load.scd`. This file wraps
//  the actual boot sequence in ONE single top-level block so the
//  launcher (or any `sclang boot.scd` invocation) brings the engine
//  + palette + live wrappers + tracks + web bridge up automatically.
//
//  Execution order :
//    1. derive ~base from this file's location
//    2. .load live/_load.scd  (which itself loads engine, synth, fx,
//       palette, setup, ~setupAll, tracks/_index, web_bridge, then
//       starts the Pdef sequencers)
//
//  Usage :
//    sclang /path/to/AV-Live/sound_algo/boot.scd
//      OR (in IDE)
//    Cmd+Enter on this block.
// =====================================================================
(
~base = (thisProcess.nowExecutingPath !? { |p| p.dirname ++ "/" })
        ?? { File.getcwd ++ "/" };

("[boot] ~base = " ++ ~base).postln;

(~base ++ "live/_load.scd").load;
)
