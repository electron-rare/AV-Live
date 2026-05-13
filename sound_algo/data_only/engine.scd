// =====================================================================
//  data_only/engine.scd  --  Engine MINIMAL pour le patch data-only.
//
//  N'utilise PAS sound_algo/engine.scd ni live/_load.scd : on veut une
//  base propre, ~2 secondes de boot, sans les 1099 SynthDefs de la
//  palette du systeme live principal.
//
//  Architecture :
//    sg = master group (synthdefs y vivent par defaut)
//    bus_reverb (audio bus 2ch) -> ~revSynth -> master
//    master FX rack : comp + limiter + master gain
//
//  Globals exposes :
//    ~doMaster, ~doRev          (Synths du FX rack)
//    ~doReverbBus               (Bus stereo pour les envois reverb)
//    ~doMasterGain (0..2)       (s'ajuste live via /control/doMaster)
// =====================================================================

(
"[data-only/engine] booting minimal engine...".postln;

// -- Reset Synths d'une eventuelle relance -------------------------
~doRev      !? { ~doRev.free };
~doMaster   !? { ~doMaster.free };
~doMasterGroup !? { ~doMasterGroup.free };

s.waitForBoot {
    var rate = s.sampleRate;

    // -- Bus reverb stereo --
    ~doReverbBus = ~doReverbBus ?? { Bus.audio(s, 2) };

    // -- SynthDefs du rack --
    SynthDef(\do_reverb, { |in, out=0, mix=0.45, room=0.85, damp=0.4|
        var dry  = In.ar(in, 2);
        var wet  = FreeVerb2.ar(dry[0], dry[1], 1.0, room, damp);
        Out.ar(out, dry + (wet * mix));
    }).add;

    SynthDef(\do_master, { |out=0, gain=1.0, ceil=0.95|
        var sig = In.ar(out, 2);
        // Compression douce sur le bus master
        sig = CompanderD.ar(sig, 0.6, 1.0, 1.0/2.5, 0.005, 0.12);
        sig = sig * gain.lag(0.05);
        // Limiteur final, prevention de clipping
        sig = Limiter.ar(sig, ceil, 0.005);
        ReplaceOut.ar(out, sig);
    }).add;

    // -- Group d'organisation --
    ~doMasterGroup = Group.new(s);

    s.sync;

    // -- Lance le rack FX --
    ~doRev    = Synth.tail(~doMasterGroup, \do_reverb,
        [\in, ~doReverbBus, \out, 0, \mix, 0.4]);
    ~doMaster = Synth.tail(~doMasterGroup, \do_master,
        [\out, 0, \gain, 1.0]);

    // -- Master gain control via OSC --
    OSCdef(\do_master_gain).free;
    OSCdef(\do_master_gain, { |msg|
        var g = msg[1].clip(0.0, 2.0);
        ~doMaster.set(\gain, g);
        ~doMasterGain = g;
    }, '/control/doMaster');
    ~doMasterGain = 1.0;

    "[data-only/engine] FX rack up (reverb + comp + limiter)".postln;
    ~doEngineReady = true;
};
)
