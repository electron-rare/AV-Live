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
~matSetTransient.(\breakdown, ~matBreakdownKeep);
(~matEffColor.(\kick, 0, 3) == 3).not.if({ pass = false; "FAIL: breakdown keeps kick".postln });
(~matEffColor.(\hats, 1, 3) == 0).not.if({ pass = false; "FAIL: breakdown cuts hats".postln });

// -- E: transient expires after ~matTransientBars ticks --
~matSetTransient.(\drop, []);
~matTransientBars.do { ~matTransientTick.() };
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

pass.if({ "GLOBALACT PASS".postln }, { "GLOBALACT FAIL".postln });
0.exit;
)
