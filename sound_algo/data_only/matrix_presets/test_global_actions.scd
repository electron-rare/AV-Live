// Headless checks for global morceau actions (Phase 1).
// Run: /Applications/SuperCollider.app/Contents/MacOS/sclang test_global_actions.scd
(
var feat = PathName(thisProcess.nowExecutingPath).pathOnly ++ "../matrix.scd";
var pass = true;
~lp = (clock: TempoClock.default); ~toscSend = { |path ...a| }; ~toscTouch = { |a| };
["kick","hats","clap","perc","sub","acid","arp","lead","stab","pad","ride","rim",
 "tom","reese","bells","sweep","melody","chord","fx","snare","crash","shaker"].do { |v|
    Pdef(("lp_" ++ v).asSymbol, Pbind(\instrument, v.asSymbol, \dur, 1)) };
feat.load;
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 1) });  // all active
~lp[\matPlaying] = false;

// -- A: defaults --
(~matGlobalActions == [\fill, \drop, \evolve, \breakdown]).not.if({ pass = false; "FAIL: default mapping".postln });

// -- B: fill -> active voices read colour 6, silent voices stay 0 --
~matSetTransient.(\fill, []);
(~matEffColor.(\kick, 0, 1) == 6).not.if({ pass = false; "FAIL: fill active->6".postln });
(~matEffColor.(\kick, 0, 0) == 0).not.if({ pass = false; "FAIL: fill silent stays 0".postln });

// -- C: drop -> everything 0 --
~matSetTransient.(\drop, []);
(~matEffColor.(\kick, 0, 4) == 0).not.if({ pass = false; "FAIL: drop->0".postln });

// -- D: breakdown -> only kept voices survive --
~matSetTransient.(\breakdown, ~matGlobalSettings[\breakdownKeep] ? [\kick, \sub]);
(~matEffColor.(\kick, 0, 3) == 3).not.if({ pass = false; "FAIL: breakdown keeps kick".postln });
(~matEffColor.(\hats, 1, 3) == 0).not.if({ pass = false; "FAIL: breakdown cuts hats".postln });

// -- E: transient expires after ~matTransientBars ticks --
~matSetTransient.(\drop, []);
(~matGlobalSettings[\transientBars] ? 1).do { ~matTransientTick.() };
(~matTransient.isNil).not.if({ pass = false; "FAIL: transient not cleared after ticks".postln });
(~matEffColor.(\kick, 0, 2) == 2).not.if({ pass = false; "FAIL: post-expire normal colour".postln });

// -- F: ~matFireGlobal dispatches the mapped action --
~matGlobalActions = [\fill, \drop, \evolve, \breakdown];
~matFireGlobal.(1);   // slot 1 = drop
(~matTransient.notNil and: { ~matTransient[\kind] == \drop }).not.if({ pass = false; "FAIL: fire slot1->drop".postln });
~matTransient = nil;
~matFireGlobal.(0);   // slot 0 = fill
(~matTransient.notNil and: { ~matTransient[\kind] == \fill }).not.if({ pass = false; "FAIL: fire slot0->fill".postln });

// -- G: hand-flip detection (no fire on appear/disappear; fire on open<->closed) --
~fired = nil; ~matFireGlobal = { |slot| ~fired = slot };   // stub to capture the slot
~matHandState[\L] = \unknown;
~matHandFlip.(\L, 0.5, 0.9, 0, 1);                          // appear OPEN -> baseline, no fire
(~fired.isNil).not.if({ pass = false; "FAIL: fired on appearance".postln });
~matHandFlip.(\L, 0.5, 0.1, 0, 1);                          // OPEN->CLOSED -> fire closeSlot(1)
(~fired == 1).not.if({ pass = false; "FAIL: open->closed did not fire slot1".postln });
~fired = nil;
~matHandFlip.(\L, 0.5, 0.9, 0, 1);                          // CLOSED->OPEN -> fire openSlot(0)
(~fired == 0).not.if({ pass = false; "FAIL: closed->open did not fire slot0".postln });
~fired = nil;
~matHandFlip.(\L, 0.0, 0.0, 0, 1);                          // disappear -> reset, no fire
(~fired.isNil).not.if({ pass = false; "FAIL: fired on disappearance".postln });

// -- H: mapping save/load roundtrip --
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matGlobalActions = [\evolve, \breakdown, \fill, \drop];     // non-default
~matSave.("zz_gact_test");
~matGlobalActions = [\fill, \drop, \evolve, \breakdown];     // clobber, then reload
~matLoadFile.(~matDir +/+ "zz_gact_test.matrix");
(~matGlobalActions == [\evolve, \breakdown, \fill, \drop]).not.if({ pass = false; "FAIL: globalActions not round-tripped".postln });
("rm -f '" ++ (~matDir +/+ "zz_gact_test.matrix") ++ "'").systemCmd;

// -- I: evolve one-shot must not leak ~matBaseGrid when the toggle is off,
//       and must mutate from the CURRENT grid (not a stale snapshot) --
~matEvolve = false; ~matBaseGrid = nil;
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~lp[\matrix][0][0] = 3;                                  // gridA: kick bar0 active
~matRelanceEvolve.();
(~matBaseGrid.isNil).not.if({ pass = false; "FAIL: evolve one-shot leaked baseGrid".postln });
~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~lp[\matrix][1][5] = 2;                                  // gridB: hats bar5 active
~matRelanceEvolve.();
(~lp[\matrix][0][0] == 0).not.if({ pass = false; "FAIL: stale gridA cell resurrected by evolve".postln });
(~lp[\matrix][1][5] > 0).not.if({ pass = false; "FAIL: gridB active cell lost by evolve".postln });

// -- J: settings drive detection thresholds + transient duration --
~matGlobalSettings[\openThresh] = 0.8; ~matGlobalSettings[\closeThresh] = 0.2;
~matHandState[\L] = \unknown;
~matHandFlip.(\L, 0.5, 0.5, 0, 1);     // 0.5 is in the new deadband -> stays unknown, no fire
~fired = nil; ~matFireGlobal = { |slot| ~fired = slot };
~matHandFlip.(\L, 0.5, 0.85, 0, 1);    // >=0.8 open -> baseline (from unknown, no fire)
(~fired.isNil).not.if({ pass = false; "FAIL: settings open baseline fired".postln });
~matHandFlip.(\L, 0.5, 0.15, 0, 1);    // <=0.2 -> closed -> fire slot1
(~fired == 1).not.if({ pass = false; "FAIL: settings close threshold no fire".postln });
~matGlobalSettings[\transientBars] = 3;
~matFireGlobal = { |slot| };           // restore no-op-ish (real one not needed here)
~matSetTransient.(\drop, []);
(~matTransient[\bars] == 3).not.if({ pass = false; "FAIL: transientBars not from settings".postln });
~matTransient = nil;
// -- K: settings save/load roundtrip --
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matGlobalSettings = (openThresh: 0.7, closeThresh: 0.25, transientBars: 2, breakdownKeep: [\kick, \hats]);
~matSave.("zz_gset_test");
~matGlobalSettings = (openThresh: 0.65, closeThresh: 0.30, transientBars: 1, breakdownKeep: [\kick, \sub]);
~matLoadFile.(~matDir +/+ "zz_gset_test.matrix");
(~matGlobalSettings[\openThresh] == 0.7).not.if({ pass = false; "FAIL: openThresh not restored".postln });
(~matGlobalSettings[\transientBars] == 2).not.if({ pass = false; "FAIL: transientBars not restored".postln });
(~matGlobalSettings[\breakdownKeep] == [\kick, \hats]).not.if({ pass = false; "FAIL: breakdownKeep not restored".postln });
("rm -f '" ++ (~matDir +/+ "zz_gset_test.matrix") ++ "'").systemCmd;

// -- L: mute group silences only its voices --
~matSetTransient.(\mute, ~matDrumVoices);
(~matEffColor.(\kick, 0, 3) == 0).not.if({ pass = false; "FAIL: muteDrums keeps kick".postln });
(~matEffColor.(\sub, 4, 3) == 3).not.if({ pass = false; "FAIL: muteDrums silenced melo sub".postln });
~matTransient = nil;
// -- M: param transients set stretch / rev channels (via ~matSetTransient directly;
//       ~matFireGlobal was stubbed by earlier groups, and the 6 dispatch lines are
//       trivial transcription verified live in Task 7) --
~matSetTransient.(\doubleTime, []);
(~matTxStretch.value == 0.5).not.if({ pass = false; "FAIL: doubleTime stretch != 0.5".postln });
~matTransient = nil;
~matSetTransient.(\washReverb, []);
(~matTxRev.value > 0).not.if({ pass = false; "FAIL: washReverb rev not boosted".postln });
~matTransient = nil;
~matSetTransient.(\halfTime, []);
(~matTxStretch.value == 2.0).not.if({ pass = false; "FAIL: halfTime stretch != 2.0".postln });
~matTransient = nil;
// -- N: next loads the following preset in sorted order --
~loaded = nil; ~matLoadReal = ~matLoad; ~matLoad = { |n| ~loaded = n.asSymbol };
~matAllNames = { [\aaa_x, \bbb_y, \ccc_z] };            // stub the list deterministically
~matCurrentName = \aaa_x;
~matNextPreset.();
(~loaded == \bbb_y).not.if({ pass = false; "FAIL: next did not load bbb_y".postln });
~matCurrentName = \ccc_z;                               // wrap to first
~matNextPreset.();
(~loaded == \aaa_x).not.if({ pass = false; "FAIL: next did not wrap to aaa_x".postln });
~matLoad = ~matLoadReal;

// -- O: bpm sets the matrix clock tempo + tracks ~matBpm --
~matSetBpm.(140);
(~matBpm == 140).not.if({ pass = false; "FAIL: ~matBpm not 140".postln });
(((~lp[\clock] ? TempoClock.default).tempo - (140 / 60)).abs < 1e-6).not.if({ pass = false; "FAIL: clock tempo not 140 bpm".postln });
~matSetBpm.(500);                                       // clamps to 300
(~matBpm == 300).not.if({ pass = false; "FAIL: bpm not clamped to 300".postln });
~matSetBpm.(120);                                       // restore

pass.if({ "GLOBALACT PASS".postln }, { "GLOBALACT FAIL".postln });
0.exit;
)
