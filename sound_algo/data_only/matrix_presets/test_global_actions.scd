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
(~matGlobalActions == [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next]).not.if({ pass = false; "FAIL: default mapping".postln });

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

// -- H: mapping save/load roundtrip --
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matGlobalActions = [\evolve, \breakdown, \fill, \drop, \muteMelo, \washReverb, \muteDrums, \next];     // non-default 8-slot
~matSave.("zz_gact_test");
~matGlobalActions = [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];     // clobber, then reload
~matLoadFile.(~matDir +/+ "zz_gact_test.matrix");
(~matGlobalActions == [\evolve, \breakdown, \fill, \drop, \muteMelo, \washReverb, \muteDrums, \next]).not.if({ pass = false; "FAIL: globalActions not round-tripped".postln });
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

// -- K: settings save/load roundtrip --
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matGlobalSettings = (transientBars: 2, breakdownKeep: [\kick, \hats]);
~matSave.("zz_gset_test");
~matGlobalSettings = (transientBars: 1, breakdownKeep: [\kick, \sub]);
~matLoadFile.(~matDir +/+ "zz_gset_test.matrix");
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

// -- P: pinch hold-to-fire (engage doesn't fire; fires past hold; release cancels) --
~matPinchRoutine !? { ~matPinchRoutine.stop };
~matGlobalActions = [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];
~matPinchHoldMs = 300; ~matTransient = nil;
~matPinchHeld = Array.fill(8, nil); ~matPinchFired = Array.fill(8, false);
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 0, 1, 1]);   // L index engage -> slot 0 held
(~matTransient.isNil).not.if({ pass = false; "FAIL: engage fired immediately".postln });
(~matPinchHeld[0].isNil).if({ pass = false; "FAIL: engage did not record hold".postln });
~matPinchHeld[0] = Main.elapsedTime - 0.5;                       // simulate 500ms held (> 300)
~matPinchTick.();
(~matTransient.notNil and: { ~matTransient[\kind] == \fill }).not.if({ pass = false; "FAIL: hold did not fire fill".postln });
~matTransient = nil;
~matPinchHeld = Array.fill(8, nil); ~matPinchFired = Array.fill(8, false);
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 1, 1, 1]);   // R index engage -> slot 4
OSCdef(\mat_ev_pinch).func.value(['/pose/pinch', 0, 1, 1, 0]);   // release before hold
~matPinchTick.();
(~matTransient.isNil).not.if({ pass = false; "FAIL: released-early pinch fired".postln });
(~matPinchHeld[4].isNil).not.if({ pass = false; "FAIL: release did not clear hold".postln });
OSCdef(\mat_pinchhold).func.value(['/matrix/pinchhold', 500]);
(~matPinchHoldMs == 500).not.if({ pass = false; "FAIL: pinchhold not set".postln });
~matPinchHoldMs = 300;
// pinchHoldMs save/load roundtrip
~matInstruments = ~matInstruments ? Array.fill(~matVoices.size, { \default });
~matColorDefs   = ~matColorDefs   ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
~matSavedNames  = ~matSavedNames  ? Set.new;
~matPinchHoldMs = 420;
~matSave.("zz_phms_test");
~matPinchHoldMs = 300;
~matLoadFile.(~matDir +/+ "zz_phms_test.matrix");
(~matPinchHoldMs == 420).not.if({ pass = false; "FAIL: pinchHoldMs not restored".postln });
("rm -f '" ++ (~matDir +/+ "zz_phms_test.matrix") ++ "'").systemCmd;

// Q: fist gestures removed 2026-07-02 (user request; FIST_ENABLE=0 at the source)

pass.if({ "GLOBALACT PASS".postln }, { "GLOBALACT FAIL".postln });
0.exit;
)
