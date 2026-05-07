// =====================================================================
//  auto_layer.scd  --  Layering automatique de timbres
//
//  Pour chaque note jouee par melody/harmony/acid, un layer secondaire
//  est joue en parallele a une amplitude reduite. Donne du corps et
//  de l'epaisseur sans toucher aux scores existants.
//
//  USAGE :
//    ~setAutoLayer.(true)          -> active toutes les couches
//    ~layerMelodyInst = \warmPad   -> override le timbre du layer melody
//    ~layerMelodyAmp = 0.3         -> volume relatif (0..1)
//    ~layerMelodyOctave = -1       -> offset octave (-2..+2)
//
//  Le layer reuse le meme score que le canal principal (\midinote etc.)
//  mais avec un instrument different. Pdef(\xxxLayer) tournent en
//  parallele de Pdef(\xxxSeq).
//
// =====================================================================

(
~autoLayerOn       = ~autoLayerOn       ? false;
~layerMelodyInst   = ~layerMelodyInst   ? \warmPad;
~layerMelodyAmp    = ~layerMelodyAmp    ? 0.30;
~layerMelodyOctave = ~layerMelodyOctave ? -1;
~layerHarmonyInst  = ~layerHarmonyInst  ? \choir;
~layerHarmonyAmp   = ~layerHarmonyAmp   ? 0.25;
~layerAcidInst     = ~layerAcidInst     ? \sub_boom;
~layerAcidAmp      = ~layerAcidAmp      ? 0.20;
~layerAcidOctave   = ~layerAcidOctave   ? -1;

~setAutoLayer = { |b|
    ~autoLayerOn = b;
    if (b) {
        // Cree les Pdef de layer en mirroir des Pdef principaux
        Pdef(\melodyLayer, Pbind(
            \instrument, Pfunc { ~layerMelodyInst },
            \dur,        0.25,
            \timingOffset, ~hTime.value,
            \type,       Pseq(~melodyNotes.collect { |n| if(n > 0) {\note} {\rest} }, inf),
            \midinote,   Pseq(~melodyNotes.collect { |n|
                if(n > 0) { n + (12 * ~layerMelodyOctave) } { 60 }
            }, inf) + ~hDet.value,
            \attack,     Pfunc { ~melodyAttack * 1.5 },  // un peu plus mou
            \release,    Pfunc { ~melodyRelease * 1.3 },
            \cutoff,     Pfunc { ~melodyCutoff * 0.7 },  // plus assourdi
            \amp,        Pfunc { ~melodyAmp * ~layerMelodyAmp } * ~hVel.value,
            \pan,        Pfunc { (~melodyPan ? 0).neg * 0.5 },  // pan oppose attenue
            \scBus,      ~scBus.index,
            \scAmt,      Pfunc { ~leadScAmt * 1.2 },
        ));
        Pdef(\harmonyLayer, Pbind(
            \instrument, Pfunc { ~layerHarmonyInst },
            \dur,        Pfunc { ~harmonyDur ? 0.25 },
            \timingOffset, ~hTime.value,
            \type,       Pseq(~harmonyNotes.collect { |n| if(n > 0) {\note} {\rest} }, inf),
            \midinote,   Pseq(~harmonyNotes.collect { |n| if(n > 0) {n} {60} }, inf) + ~hDet.value,
            \attack,     Pfunc { ~harmonyAttack * 1.5 },
            \release,    Pfunc { ~harmonyRelease * 1.3 },
            \amp,        Pfunc { ~harmonyAmp * ~layerHarmonyAmp } * ~hVel.value,
            \scBus,      ~scBus.index,
            \scAmt,      Pfunc { ~leadScAmt * 1.2 },
        ));
        Pdef(\acidLayer, Pbind(
            \instrument, Pfunc { ~layerAcidInst },
            \dur,        0.25,
            \timingOffset, ~hTime.value,
            \midinote,   Pseq(~acidNotes.collect { |n| n + (12 * ~layerAcidOctave) }, inf),
            \amp,        Pfunc { ~acidAmp * ~layerAcidAmp } * ~hVel.value,
            \scBus,      ~scBus.index,
            \scAmt,      Pfunc { ~acidScAmt * 1.5 },
        ));
        Pdef(\melodyLayer).play;
        Pdef(\harmonyLayer).play;
        Pdef(\acidLayer).play;
        "[auto_layer] ON -- 3 layers en parallele".postln;
    } {
        Pdef(\melodyLayer).stop;
        Pdef(\harmonyLayer).stop;
        Pdef(\acidLayer).stop;
        "[auto_layer] OFF".postln;
    };
};

"[auto_layer] loaded - ~setAutoLayer.(true) to enable".postln;
)
