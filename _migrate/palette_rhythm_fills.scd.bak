// =====================================================================
//  fills.scd
//  Helpers rythmiques : ~snareFill / ~tomFill
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur le bloc pour l'appliquer.
//  Compatible avec .load (un seul bloc top-level).
// =====================================================================

(
// --- Snare fill (8 hits sur 1s, accelerando d'amp) -----------------
~snareFill = { |hits = 8, dur = 1, ampStart = 0.3, ampEnd = 0.5|
    Routine({
        hits.do { |k|
            var a = ampStart + ((ampEnd - ampStart) * (k / hits.max(1)));
            Synth(\snare, [\amp, a, \decay, 0.06, \freq, 200 + (k * 10)]);
            (dur / hits).wait;
        };
    }).play;
};

// --- Tom fill (descente sur 4 toms) -------------------------------
~tomFill = {
    Routine({
        [180, 140, 110, 85].do { |f|
            Synth(\tom, [\freq, f, \decay, 0.25, \amp, 0.5]);
            0.15.wait;
        };
    }).play;
};

"helpers ~snareFill / ~tomFill prets".postln;
)

// Exemples manuels (Cmd+Entree, ne PAS evaluer au .load) :
   ( ~snareFill.value; )                  // fill standard 8 hits / 1s
   ( ~snareFill.(16, 2, 0.2, 0.55); )     // fill long accelerando
   ( ~tomFill.value; )                    // descente 4 toms
