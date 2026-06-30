// Headless checks for ~matNames disk persistence + ~matWrapStep queued load.
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang test_matnames.scd
(
var feat = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../matrix.scd";
var pass = true, dir, nm;
~lp = (clock: TempoClock.default); ~toscSend = { |path ...a| }; ~toscTouch = { |a| };
["kick","hats","clap","perc","sub","acid","arp","lead","stab","pad","ride","rim",
 "tom","reese","bells","sweep","melody","chord","fx","snare","crash","shaker"].do { |v|
    Pdef(("lp_" ++ v).asSymbol, Pbind(\instrument, v.asSymbol, \dur, 1)) };
feat.load;

// -- Part A: a .matrix on disk in ~matDir is listed even with an empty Set --
dir = ~matDir; ("mkdir -p '" ++ dir ++ "'").systemCmd;
File.use(dir +/+ "zz_persist_test.matrix", "w", { |f| f.write("('grid':[])") });
~matSavedNames = Set.new;                      // simulate a fresh boot (no in-memory saves)
nm = ~matNames.(dir);
nm.includes(\zz_persist_test).not.if({ pass = false; "FAIL: ~matNames missed disk file".postln });
("rm -f '" ++ (dir +/+ "zz_persist_test.matrix") ++ "'").systemCmd;

// -- Part B: ~matWrapStep applies a queued load and clears the queue --
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~matQueuedLoad = "techno_drive_live";
~matWrapStep.();
(~matQueuedLoad.isNil).not.if({ pass = false; "FAIL: queue not cleared after wrap".postln });
(~lp[\matrix].flatten.sum == 0).if({ pass = false; "FAIL: queued preset not loaded".postln });

pass.if({ "MATNAMES PASS".postln }, { "MATNAMES FAIL".postln });
0.exit;
)
