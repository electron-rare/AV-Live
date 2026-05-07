// =====================================================================
//  fx.scd
//  FX oneshot : riser / sweep / impact / crash / vinyl
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur un bloc pour l'appliquer.
// =====================================================================

// =====================================================================

( Synth(\riser, [\dur, 4,  \startCutoff, 200, \endCutoff, 8000,  \amp, 0.25]); )
( Synth(\riser, [\dur, 8,  \startCutoff, 300, \endCutoff, 10000, \amp, 0.30]); )
( Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]); )

( Synth(\sweep, [\dur, 4, \startCutoff, 8000, \endCutoff, 200, \amp, 0.25]); )

( Synth(\impact, [\freq, 45, \decay, 1.5, \amp, 0.7]); )
( Synth(\impact, [\freq, 35, \decay, 2.5, \amp, 0.8]); )

( Synth(\crash, [\decay, 2.0, \amp, 0.3]); )
( Synth(\crash, [\decay, 4.0, \amp, 0.4]); )

( ~vinyl !? { ~vinyl.free }; ~vinyl = Synth(\vinyl, [\amp, 0.05]); "vinyl ON".postln; )
( ~vinyl !? { ~vinyl.free; ~vinyl = nil }; "vinyl OFF".postln; )



