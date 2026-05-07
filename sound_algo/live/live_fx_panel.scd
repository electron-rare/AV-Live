// =====================================================================
//  live_fx_panel.scd  --  PANNEAU FX LIVE (tout-en-un)
//
//  USAGE :
//    1. PREREQUIS -- evaluer les SETUP de :
//       - engine.scd  (charge avec CHARGER TOUT du 00_load.scd)
//       - fx_bus.scd  (Cmd+Entree sur le SETUP)
//       - live.scd    (Cmd+Entree sur le SETUP)
//    2. Lance une track ou les Pdef
//    3. Cmd+Entree sur n'importe quel bloc de ce panneau pour declencher l'effet
//
//  Toutes les commandes sont protegees par garde `~helper !? { ... }`
//  pour ne rien casser si un setup n'a pas ete evalue.
//
//  CATEGORIES :
//    [A] FX BUS DYNAMIQUE   (send / setFx / preset / freeze)
//    [B] LFO ASSIGNABLES    (sur n'importe quelle variable)
//    [C] VCF MASTER         (8 types + presets)
//    [D] TRICKS SCENIQUES   (drop / breakdown / buildup / stutter ...)
//    [E] FX MOMENTANES      (bitcrush / ringmod / freqshift / granfreeze ...)
//    [F] AUTO-PAN / TREMOLO
//    [G] FX SYNTHS ONESHOT  (riser / sweep / impact / crash / vinyl / gong ...)
//    [H] FILLS RYTHMIQUES   (snareFill / tomFill)
//    [I] MASTER COMP / SAT
//    [J] FX PAR GENRE       (combos prets a l'emploi)
//    [K] TAP TEMPO
//    [L] FX BUS DETAIL      (param par param par FX)
//    [M] STOP ALL FX        (reset global)
// =====================================================================



// =====================================================================
// [A] FX BUS DYNAMIQUE
//     ~send.(\fx, amount) | ~setFx.(\fx, key, val) | ~fxPreset.(\preset)
// =====================================================================

// --- Sends raccourcis (par bus) -----
( ~sendReverb   !? { ~sendReverb.(0.4)   }; )
( ~sendDelay    !? { ~sendDelay.(0.3)    }; )
( ~sendChorus   !? { ~sendChorus.(0.3)   }; )
( ~sendPhaser   !? { ~sendPhaser.(0.4)   }; )
( ~sendFlanger  !? { ~sendFlanger.(0.4)  }; )
( ~sendBitcrush !? { ~sendBitcrush.(0.4) }; )
( ~sendTape     !? { ~sendTape.(1.0)     }; )
( ~sendShimmer  !? { ~sendShimmer.(0.5)  }; )
( ~sendDist     !? { ~sendDist.(0.4)     }; )

// --- Sends par FX/key (si tu veux varier) -----
( ~send !? { ~send.(\rev,  0.4) }; )
( ~send !? { ~send.(\dly,  0.3) }; )
( ~send !? { ~send.(\chr,  0.3) }; )
( ~send !? { ~send.(\phs,  0.4) }; )
( ~send !? { ~send.(\flg,  0.4) }; )
( ~send !? { ~send.(\crsh, 0.4) }; )
( ~send !? { ~send.(\tape, 1.0) }; )
( ~send !? { ~send.(\shim, 0.5) }; )
( ~send !? { ~send.(\dist, 0.4) }; )

// --- Tout couper (sec) -----
( ~send !? {
    [\rev,\dly,\chr,\phs,\flg,\crsh,\tape,\shim,\dist].do { |k| ~send.(k, 0) };
}; )

// --- Reverb : mix max + room cathedrale -----
( ~setFx !? { ~setFx.(\rev, \mix,  0.7) }; )
( ~setFx !? { ~setFx.(\rev, \room, 0.97); ~setFx.(\rev, \damp, 0.1) }; )

// --- Reverb FREEZE on / off (drone infini) -----
( ~setFx !? { ~setFx.(\rev, \freeze, 1) }; )
( ~setFx !? { ~setFx.(\rev, \freeze, 0) }; )

// --- Crossfade entre 2 FX -----
( ~crossfadeFx !? { ~crossfadeFx.(\dly, \rev, 8) }; )
( ~crossfadeFx !? { ~crossfadeFx.(\dist, \shim, 4) }; )

// --- PRESETS FX (combo predefini sur le bus FX) -----
( ~fxPreset !? { ~fxPreset.(\dry)        }; )    // tout off
( ~fxPreset !? { ~fxPreset.(\dub)        }; )    // rev hall + delay long + tape
( ~fxPreset !? { ~fxPreset.(\space)      }; )    // shimmer + reverb + chorus
( ~fxPreset !? { ~fxPreset.(\trance)     }; )    // rev + delay 1/8 + chorus
( ~fxPreset !? { ~fxPreset.(\dubstep)    }; )    // dist + bitcrush + reverb
( ~fxPreset !? { ~fxPreset.(\retro)      }; )    // bitcrush + tape + chorus
( ~fxPreset !? { ~fxPreset.(\industrial) }; )    // dist + flanger + bitcrush
( ~fxPreset !? { ~fxPreset.(\dream)      }; )    // shimmer + reverb + chorus
( ~fxPreset !? { ~fxPreset.(\cosmic)     }; )    // phaser LFO + shimmer + reverb
( ~fxPreset !? { ~fxPreset.(\drone)      }; )    // reverb FROZEN + shimmer



// =====================================================================
// [B] LFO ASSIGNABLES (~lfoTo / ~lfoSync)
//     shape : \sin \tri \saw \sqr \rand \smoothRand \drunk \noise
// =====================================================================

// --- LFO sin sur cutoff melody (rate 0.5Hz, depth 1500, center 2500) -----
( ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.5, 1500, \sin, 2500) }; )

// --- LFO triangle slow sur cutoff acid -----
( ~lfoTo !? { ~lfoTo.(\acidCutoff, 0.25, 800, \tri, 1000) }; )

// --- LFO saw rising (montee progressive) sur cutoff melody -----
( ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 2500, \saw, 3000) }; )

// --- LFO sqr asymetrique (pulseWidth=0.3) sur kickAmp -> rythmique -----
( ~lfoTo !? { ~lfoTo.(\kickAmp, 2, 0.2, \sqr, 0.5, true, 0.3) }; )

// --- LFO random (sample-and-hold) sur amp acid -----
( ~lfoTo !? { ~lfoTo.(\acidAmp, 4, 0.15, \rand, 0.32) }; )

// --- LFO smooth random sur amp harmony -----
( ~lfoTo !? { ~lfoTo.(\harmonyAmp, 0.3, 0.08, \smoothRand, 0.14) }; )

// --- LFO drunken walk sur drive melody -----
( ~lfoTo !? { ~lfoTo.(\melodyDrive, 0.1, 0.8, \drunk, 1.2) }; )

// --- LFO noise pure (chaos) sur Rq melody -----
( ~lfoTo !? { ~lfoTo.(\melodyRq, 5, 0.2, \noise, 0.3) }; )

// --- LFO sin sur wobbleRate (bass design en wobble) -----
( ~lfoTo !? { ~lfoTo.(\melodyWobbleRate, 0.1, 4, \sin, 6) }; )

// --- LFO SYNC TEMPO : 1 cycle complet sur N beats -----
( ~lfoSync !? { ~lfoSync.(\melodyCutoff, 4,    1500, \sin, 2500) }; )    // 4 beats
( ~lfoSync !? { ~lfoSync.(\acidCutoff,   8,    600,  \sin, 800)  }; )    // 8 beats
( ~lfoSync !? { ~lfoSync.(\melodyAmp,    0.25, 0.1,  \tri, 0.16) }; )    // 1/4 beat = 16eme

// --- Stop UN LFO precis -----
( ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) }; )
( ~lfoStopVar !? { ~lfoStopVar.(\acidCutoff)   }; )
( ~lfoStopVar !? { ~lfoStopVar.(\kickAmp)      }; )

// --- Stop tous les LFO de variables (~xxx) -----
( ~lfoStopAllVars !? { ~lfoStopAllVars.() }; )

// --- Stop TOUT (LFO vars + LFO FX) -----
( ~lfoStopEverything !? { ~lfoStopEverything.() }; )

// --- Liste les LFO actifs -----
( ~lfoList !? { ~lfoList.() }; )

// --- LFO sur PARAM FX (sur le bus FX, different de ~lfoTo) -----
( ~lfo !? { ~lfo.(\dly,  \feedback, 0.1,  0.2,  0.85, \sin) }; )
( ~lfo !? { ~lfo.(\rev,  \mix,      0.05, 0.1,  0.7,  \tri) }; )
( ~lfo !? { ~lfo.(\crsh, \bits,     0.2,  4,    12,   \sqr) }; )
( ~lfo !? { ~lfo.(\phs,  \rate,     0.02, 0.1,  1.5,  \sin) }; )
( ~lfo !? { ~lfo.(\shim, \shimmer,  0.1,  0.2,  0.8,  \rand) }; )

// --- Stop un LFO FX precis -----
( ~lfoStop !? { ~lfoStop.(\dly, \feedback) }; )

// --- Stop tous les LFO FX (sans toucher aux LFO vars) -----
( ~lfoStopAll !? { ~lfoStopAll.() }; )



// =====================================================================
// [C] VCF MASTER (filtre insere sur tout le mix)
//     types : \moog \ms20 \ladder \formant \comb \hpf \bpf \notch
// =====================================================================

// --- Activation par type -----
( ~vcfOn !? { ~vcfOn.(\moog,    800,  0.7) }; )    // 4-pole vintage
( ~vcfOn !? { ~vcfOn.(\ms20,    900,  0.6) }; )    // Sallen-Key agressif
( ~vcfOn !? { ~vcfOn.(\ladder,  900,  0.5) }; )    // 24 dB/oct
( ~vcfOn !? { ~vcfOn.(\formant, 0,    0.15) }; )   // freq=vowel index 0..4
( ~vcfOn !? { ~vcfOn.(\comb,    220,  1.5) }; )    // resonator
( ~vcfOn !? { ~vcfOn.(\hpf,     400,  0.5) }; )    // HPF resonant
( ~vcfOn !? { ~vcfOn.(\bpf,     1200, 0.4) }; )    // BPF resonant
( ~vcfOn !? { ~vcfOn.(\notch,   1000, 0.3) }; )    // BRF (anti-bande)

// --- Set un parametre du VCF actif -----
( ~vcfSet !? { ~vcfSet.(\freq, 1500) }; )
( ~vcfSet !? { ~vcfSet.(\freq, 350)  }; )
( ~vcfSet !? { ~vcfSet.(\mix,  0.8)  }; )

// --- Sweep automatique du cutoff -----
( ~vcfSweep !? { ~vcfSweep.(200,  5000, 4) }; )    // up 4s
( ~vcfSweep !? { ~vcfSweep.(8000, 200,  4) }; )    // down 4s
( ~vcfSweep !? { ~vcfSweep.(400,  6000, 8, \exp) }; )

// --- PRESETS VCF -----
( ~vcfPreset !? { ~vcfPreset.(\acid)     }; )      // moog 600 q=0.85
( ~vcfPreset !? { ~vcfPreset.(\dub)      }; )      // ladder 900 q=0.5
( ~vcfPreset !? { ~vcfPreset.(\deep)     }; )      // moog 400 q=0.4
( ~vcfPreset !? { ~vcfPreset.(\bright)   }; )      // bpf 3500 q=0.4
( ~vcfPreset !? { ~vcfPreset.(\dark)     }; )      // moog 250 q=0.3
( ~vcfPreset !? { ~vcfPreset.(\formantA) }; )
( ~vcfPreset !? { ~vcfPreset.(\formantE) }; )
( ~vcfPreset !? { ~vcfPreset.(\formantI) }; )
( ~vcfPreset !? { ~vcfPreset.(\formantO) }; )
( ~vcfPreset !? { ~vcfPreset.(\formantU) }; )

// --- VCF off -----
( ~vcfOff !? { ~vcfOff.() }; )



// =====================================================================
// [D] TRICKS SCENIQUES (~drop / ~breakdown / ~buildup / ~stutter ...)
// =====================================================================

// --- DROP : silence -> fill -> freeze -> blast -----
( ~drop !? { ~drop.(4) }; )                        // build 4s
( ~drop !? { ~drop.(8) }; )                        // build 8s

// --- BREAKDOWN progressif -----
( ~breakdown !? { ~breakdown.(8) }; )
( ~breakdown !? { ~breakdown.(16) }; )

// --- BUILDUP crescendo (riser + filterSweepUp) -----
( ~buildup !? { ~buildup.(8)  }; )
( ~buildup !? { ~buildup.(16) }; )

// --- HANDS UP : sub mute + lead boost + delay courte -----
( ~handsUp !? { ~handsUp.() }; )

// --- STUTTER master (gate rythmique sur amps) -----
( ~stutter !? { ~stutter.(8,  1)   }; )            // 8Hz pendant 1s
( ~stutter !? { ~stutter.(16, 0.5) }; )            // 16Hz pendant 0.5s
( ~stutter !? { ~stutter.(4,  2)   }; )            // 4Hz pendant 2s

// --- GLITCH : bitcrush + stutter + delay courte -----
( ~glitch !? { ~glitch.(2) }; )
( ~glitch !? { ~glitch.(4) }; )

// --- FREEZE : reverb freeze + cut sec -----
( ~freeze !? { ~freeze.(4) }; )
( ~freeze !? { ~freeze.(8) }; )

// --- REVERB TAIL : kill all + reverb send max + queue dur s -----
( ~reverbTail !? { ~reverbTail.(4) }; )
( ~reverbTail !? { ~reverbTail.(8) }; )

// --- TAPE STOP : ralenti tempo puis stop -----
( ~tapeStop !? { ~tapeStop.(2) }; )
( ~tapeStop !? { ~tapeStop.(4) }; )

// --- TAPE REVERSE : sweep + freeze -----
( ~tapeReverse !? { ~tapeReverse.(2) }; )
( ~tapeReverse !? { ~tapeReverse.(4) }; )

// --- JUMP CUT : silence sec dur s puis reprend -----
( ~jumpCut !? { ~jumpCut.(0.5) }; )
( ~jumpCut !? { ~jumpCut.(1)   }; )
( ~jumpCut !? { ~jumpCut.(2)   }; )

// --- SWAP scene A -> scene B (necessite ~scene) -----
( ~swap !? { ~swap.(\sceneA, \sceneB, 4) }; )

// --- CHOKE : coupe la rythmique / lead -----
( ~chokePerc !? { ~chokePerc.() }; )
( ~chokeLead !? { ~chokeLead.() }; )

// --- ENV one-shot sur une var (attack/sustain/release) -----
( ~envTo !? { ~envTo.(\melodyCutoff, 0.5, 1.0, 2.0, 6000, 1500) }; )

// --- ENV burst percussif sur une var -----
( ~envBurst !? { ~envBurst.(\acidCutoff, 4000, 0.3) }; )

// --- ENV sweep (monte/descend lineaire ou expo) -----
( ~envSweep !? { ~envSweep.(\melodyCutoff, 200, 6000, 4, \exp) }; )
( ~envSweep !? { ~envSweep.(\melodyCutoff, 6000, 200, 4, \exp) }; )

// --- Filter sweep raccourcis -----
( ~filterSweepUp   !? { ~filterSweepUp.(4)   }; )
( ~filterSweepDown !? { ~filterSweepDown.(4) }; )

// --- AMP DUCK momentane sur tous les amps -----
( ~ampDuck !? { ~ampDuck.(0.3, 0.7) }; )
( ~ampDuck !? { ~ampDuck.(0.6, 0.5) }; )

// --- Sidechain dynamique (kick -> cible) -----
( ~scTrigger !? { ~scTrigger.(\kick, \acid,    0.85) }; )
( ~scTrigger !? { ~scTrigger.(\kick, \melody,  0.6)  }; )
( ~scTrigger !? { ~scTrigger.(\kick, \harmony, 0.6)  }; )
( ~scTrigger !? { ~scTrigger.(\kick, \master,  0.7)  }; )

// --- SC auto global (pompe sur tout le mix) -----
( ~scAuto !? { ~scAuto.(0.7) }; )

// --- SC off -----
( ~scOff !? { ~scOff.() }; )

// --- COMBOS sceniques -----
( ~breakdown !? { ~breakdown.(8); }; ~buildup !? { ~buildup.(8); }; ~drop !? { ~drop.(2); }; )
( ~vcfPreset !? { ~vcfPreset.(\acid) }; ~lfoSync !? { ~lfoSync.(\acidCutoff, 8, 600, \sin, 800) }; )
( ~scAuto !? { ~scAuto.(0.7) }; ~compOn !? { ~compOn.(\pump) }; ~satOn !? { ~satOn.(1.5) }; )



// =====================================================================
// [E] FX MOMENTANES (~bitCrushNow / ~ringMod / ~freqShift / ~granFreeze ...)
// =====================================================================

// --- SLIP TIME (pitch master sur dur s) -----
( ~slipTime !? { ~slipTime.(0.5,  1)   }; )       // -1 octave 1s
( ~slipTime !? { ~slipTime.(2.0,  0.5) }; )       // +1 octave 0.5s
( ~slipTime !? { ~slipTime.(0.75, 2)   }; )       // -3st 2s

// --- BITCRUSH momentane -----
( ~bitCrushNow !? { ~bitCrushNow.(4, 4000, 1) }; )
( ~bitCrushNow !? { ~bitCrushNow.(6, 8000, 2) }; )
( ~bitCrushNow !? { ~bitCrushNow.(3, 3000, 0.5) }; )

// --- RING MOD momentane -----
( ~ringMod !? { ~ringMod.(150, 1) }; )
( ~ringMod !? { ~ringMod.(300, 2) }; )
( ~ringMod !? { ~ringMod.(50,  0.5) }; )

// --- FREQ SHIFT momentane -----
( ~freqShift !? { ~freqShift.(50,   1) }; )
( ~freqShift !? { ~freqShift.(-100, 2) }; )
( ~freqShift !? { ~freqShift.(200,  0.5) }; )

// --- GRAN FREEZE momentane -----
( ~granFreeze !? { ~granFreeze.(2) }; )
( ~granFreeze !? { ~granFreeze.(4) }; )

// --- SCRATCH (vinyl-like) -----
( ~scratch !? { ~scratch.(1,  0.3) }; )
( ~scratch !? { ~scratch.(-1, 0.5) }; )

// --- BEAT REPEAT (gate stutter rythmique) -----
( ~repeat !? { ~repeat.(8,  1) }; )
( ~repeat !? { ~repeat.(16, 0.5) }; )
( ~repeat !? { ~repeat.(4,  2) }; )



// =====================================================================
// [F] AUTO-PAN / TREMOLO (par voix)
// =====================================================================

// --- AUTOPAN par voix (sur ~xxxPan) -----
( ~autoPan !? { ~autoPan.(\melody,  0.5, 0.8) }; )
( ~autoPan !? { ~autoPan.(\acid,    0.3, 0.6) }; )
( ~autoPan !? { ~autoPan.(\harmony, 0.2, 1.0) }; )

// --- TREMOLO par voix (LFO sur ~xxxAmp) -----
( ~tremolo !? { ~tremolo.(\melody,  5, 0.5) }; )
( ~tremolo !? { ~tremolo.(\acid,    8, 0.4) }; )
( ~tremolo !? { ~tremolo.(\harmony, 3, 0.6) }; )

// --- Stop l'auto-fx d'une voie -----
( ~stopAutoFx !? { ~stopAutoFx.(\melody)  }; )
( ~stopAutoFx !? { ~stopAutoFx.(\acid)    }; )
( ~stopAutoFx !? { ~stopAutoFx.(\harmony) }; )

// --- AUTOPAN / TREMOLO en SEND (sur le bus FX, voix indep) -----
( ~addFx !? { ~addFx.(\autopan, [\rate, 0.5, \depth, 1]) }; ~send !? { ~send.(\autopan, 1.0) }; )
( ~addFx !? { ~addFx.(\trem,    [\rate, 6,   \depth, 0.7]) }; ~send !? { ~send.(\trem, 1.0) }; )



// =====================================================================
// [G] FX SYNTHS ONESHOT (riser / sweep / impact / crash / vinyl / gong ...)
// =====================================================================

// --- RISER (montee filtree) -----
( Synth(\riser, [\dur, 4,  \startCutoff, 200, \endCutoff, 8000,  \amp, 0.25]); )
( Synth(\riser, [\dur, 8,  \startCutoff, 300, \endCutoff, 10000, \amp, 0.30]); )
( Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]); )

// --- SWEEP (descente filtree) -----
( Synth(\sweep, [\dur, 4, \startCutoff, 8000,  \endCutoff, 200, \amp, 0.25]); )
( Synth(\sweep, [\dur, 8, \startCutoff, 12000, \endCutoff, 200, \amp, 0.35]); )

// --- IMPACT (sub-boom de drop) -----
( Synth(\impact, [\freq, 45, \decay, 1.5, \amp, 0.7]); )
( Synth(\impact, [\freq, 35, \decay, 2.5, \amp, 0.8]); )
( Synth(\impact, [\freq, 25, \decay, 4,   \amp, 0.9]); )       // gabber

// --- CRASH (cymbale crash) -----
( Synth(\crash, [\decay, 2.0, \amp, 0.3]); )
( Synth(\crash, [\decay, 4.0, \amp, 0.4]); )
( Synth(\crash, [\decay, 6.0, \amp, 0.5]); )

// --- GONG (asia, decay long) -----
( Synth(\gong, [\freq, 50, \decay, 8,  \amp, 0.5]); )
( Synth(\gong, [\freq, 40, \decay, 12, \amp, 0.6]); )
( Synth(\gong, [\freq, 25, \decay, 30, \amp, 0.95]); )         // drone doom

// --- VINYL (crackle continu) on / off -----
( ~vinyl !? { ~vinyl.free }; ~vinyl = Synth(\vinyl, [\amp, 0.05]); "vinyl ON".postln; )
( ~vinyl !? { ~vinyl.free }; ~vinyl = Synth(\vinyl, [\amp, 0.10]); "vinyl ON normal".postln; )
( ~vinyl !? { ~vinyl.free }; ~vinyl = Synth(\vinyl, [\amp, 0.15]); "vinyl ON fort".postln; )
( ~vinyl !? { ~vinyl.free; ~vinyl = nil }; "vinyl OFF".postln; )

// --- TAIKO / TOM / SNARE / CLAP / KICKS one-shots -----
( Synth(\taiko, [\freq, 80, \decay, 0.6, \amp, 0.5]); )
( Synth(\tom,   [\freq, 120, \decay, 0.3, \amp, 0.5]); )
( Synth(\snare, [\amp, 0.5, \decay, 0.06, \freq, 220]); )
( Synth(\clap,  [\amp, 0.4, \decay, 0.3]); )
( Synth(\kick808,    [\freq, 35, \decay, 1.2, \amp, 0.7]); )
( Synth(\kickGabber, [\amp, 0.7]); )

// --- Cowbell, guzheng (asian) -----
( Synth(\cowbell,  [\freq, 800, \decay, 0.2, \amp, 0.4]); )
( Synth(\guzheng,  [\freq, 220, \amp, 0.18, \release, 1.0]); )

// --- SCRATCH SynthDef direct -----
( Synth(\scratch, [\dur, 0.2, \freq, 1000, \sweepDir, 1,  \amp, 0.4]); )
( Synth(\scratch, [\dur, 0.3, \freq, 800,  \sweepDir, -1, \amp, 0.4]); )



// =====================================================================
// [H] FILLS RYTHMIQUES
// =====================================================================

// --- Snare fill standard (8 hits / 1s) -----
( ~snareFill !? { ~snareFill.value }; )

// --- Snare fill long accelerando (16 hits / 2s) -----
( ~snareFill !? { ~snareFill.(16, 2, 0.2, 0.55) }; )

// --- Snare fill court rapide (32 hits / 1s -- roll) -----
( ~snareFill !? { ~snareFill.(32, 1, 0.15, 0.6) }; )

// --- Snare fill epique (32 hits / 16s, build) -----
( ~snareFill !? { ~snareFill.(32, 16, 0.2, 0.55) }; )

// --- Tom fill standard (descente 4 toms) -----
( ~tomFill !? { ~tomFill.value }; )



// =====================================================================
// [I] MASTER COMP / SAT
// =====================================================================

// --- Compresseur ON par preset -----
( ~compOn !? { ~compOn.(\soft)  }; )           // glue tres leger
( ~compOn !? { ~compOn.(\glue)  }; )           // glue (default)
( ~compOn !? { ~compOn.(\punch) }; )           // attack rapide
( ~compOn !? { ~compOn.(\pump)  }; )           // sidechain-style

// --- Compresseur OFF -----
( ~compOff !? { ~compOff.() }; )

// --- Saturation ON par mode -----
( ~satOn !? { ~satOn.(1.5, 0) }; )             // tanh doux
( ~satOn !? { ~satOn.(2.0, 0) }; )             // tanh fort
( ~satOn !? { ~satOn.(2.0, 1) }; )             // softclip
( ~satOn !? { ~satOn.(1.8, 2) }; )             // fold (extreme)

// --- Saturation OFF -----
( ~satOff !? { ~satOff.() }; )



// =====================================================================
// [J] FX PAR GENRE (combos prets a l'emploi -- palette/fx_genre.scd)
//     Chaque bloc = transition / signature scenique complete
// =====================================================================

// --- TRANCE BUILD-UP : snare roll + riser long + impact (16s) -----
(
~snareFill !? {
    Synth(\riser, [\dur, 16, \startCutoff, 400, \endCutoff, 12000, \amp, 0.35]);
    ~snareFill.(32, 16, 0.2, 0.55);
    fork {
        16.wait;
        Synth(\impact, [\freq, 35, \decay, 3, \amp, 0.7]);
        Synth(\crash, [\decay, 4, \amp, 0.4]);
    };
    "=== TRANCE BUILD 16s ===".postln;
};
)

// --- DUBSTEP DROP : impact + crash + riser court (4s) -----
(
Synth(\riser, [\dur, 4, \startCutoff, 500, \endCutoff, 11000, \amp, 0.4]);
fork {
    4.wait;
    Synth(\impact, [\freq, 30, \decay, 3.5, \amp, 0.85]);
    Synth(\crash, [\decay, 3, \amp, 0.5]);
};
"=== DUBSTEP DROP 4s ===".postln;
)

// --- HARDCORE GABBER DROP : impact massif + double crash -----
(
Synth(\impact, [\freq, 25, \decay, 4, \amp, 0.9]);
Synth(\crash, [\decay, 5, \amp, 0.6]);
fork { 0.5.wait; Synth(\crash, [\decay, 3, \amp, 0.4]); };
"=== HARDCORE DROP ===".postln;
)

// --- DnB BUILD : snare roll accelerando + drop (4s) -----
(
~snareFill !? {
    ~snareFill.(16, 4, 0.3, 0.6);
    fork {
        4.wait;
        Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.65]);
    };
    "=== DnB BUILD 4s ===".postln;
};
)

// --- ASIAN CINEMATIC : gong cascade descendant -----
(
[40, 50, 60, 70].do { |f, i|
    fork { (i * 0.8).wait; Synth(\gong, [\freq, f, \decay, 8 - (i * 0.5), \amp, 0.45]); };
};
"=== GONG CASCADE 3s ===".postln;
)

// --- DUB TECHNO ECHO : clap dub avec delay -----
(
fork {
    5.do { |i|
        Synth(\clap, [\amp, 0.4 - (i * 0.06), \decay, 0.3]);
        0.4.wait;
    };
};
"=== DUB ECHO CLAP ===".postln;
)

// --- DETROIT FILTER SWEEP DOWN -----
( Synth(\sweep, [\dur, 8, \startCutoff, 12000, \endCutoff, 200, \amp, 0.35]); )

// --- INDUSTRIAL TENSION : sweep slow + drone vinyl (16s) -----
(
Synth(\sweep, [\dur, 16, \startCutoff, 8000, \endCutoff, 100, \amp, 0.4]);
~vinyl !? { ~vinyl.free };
~vinyl = Synth(\vinyl, [\amp, 0.12]);
fork { 16.wait; ~vinyl !? { ~vinyl.free; ~vinyl = nil }; };
"=== INDUSTRIAL TENSION 16s ===".postln;
)

// --- GLITCH IDM : scratch + impacts random -----
(
fork {
    8.do {
        if (0.6.coin) { Synth(\scratch, [\dur, rrand(0.1, 0.4), \freq, rrand(400, 2000),
                                          \sweepDir, [-1, 1].choose, \amp, 0.3]) };
        if (0.3.coin) { Synth(\impact, [\freq, rrand(40, 80), \decay, rrand(0.5, 1.5),
                                         \amp, 0.4]) };
        rrand(0.15, 0.5).wait;
    };
};
"=== GLITCH 8 hits 4s ===".postln;
)

// --- VOCAL TRANCE SWELL : riser + crash + impact (12s) -----
(
Synth(\riser, [\dur, 12, \startCutoff, 600, \endCutoff, 13000, \amp, 0.4]);
fork {
    12.wait;
    Synth(\impact, [\freq, 38, \decay, 3, \amp, 0.7]);
    Synth(\crash, [\decay, 5, \amp, 0.45]);
};
"=== VOCAL TRANCE SWELL 12s ===".postln;
)

// --- TRIBAL TOM ROLL DESCENDANT (taiko) -----
(
[180, 140, 110, 85, 70, 55, 40].do { |f, i|
    fork { (i * 0.12).wait; Synth(\taiko, [\freq, f, \decay, 0.6, \amp, 0.5]); };
};
"=== TRIBAL TOM ROLL ===".postln;
)

// --- DRONE DOOM : gong tres profond (30s) -----
(
Synth(\gong, [\freq, 25, \decay, 30, \amp, 0.95]);
fork { 5.wait; Synth(\gong, [\freq, 30, \decay, 25, \amp, 0.7]); };
"=== DRONE DOOM gong massif 30s ===".postln;
)

// --- HARDSTYLE BUILD : kick reverse + snare roll + impact (4s) -----
(
Synth(\sweep, [\dur, 4, \startCutoff, 200, \endCutoff, 8000, \amp, 0.45]);
fork {
    4.wait;
    Synth(\impact, [\freq, 30, \decay, 3.5, \amp, 0.85]);
    Synth(\kickGabber, [\amp, 0.7]);
};
"=== HARDSTYLE BUILD 4s ===".postln;
)

// --- PHONK : vinyl + cowbell + 808 sub -----
(
~vinyl !? { ~vinyl.free };
~vinyl = Synth(\vinyl, [\amp, 0.15]);
fork {
    4.do {
        Synth(\cowbell, [\freq, 800, \decay, 0.2, \amp, 0.4]);
        0.5.wait;
    };
    Synth(\kick808, [\freq, 35, \decay, 1.2, \amp, 0.7]);
};
"=== PHONK VINYL 2.5s ===".postln;
)

// --- FUTURE GARAGE : vocal-like swell + sub (6s) -----
(
Synth(\sweep, [\dur, 6, \startCutoff, 6000, \endCutoff, 800, \amp, 0.3]);
fork { 5.wait; Synth(\impact, [\freq, 40, \decay, 2.5, \amp, 0.55]); };
"=== FUTURE GARAGE SWELL 6s ===".postln;
)

// --- SCRATCH FX x4 -----
(
4.do { |i|
    fork {
        (i * 0.15).wait;
        Synth(\scratch, [\dur, 0.2, \freq, 800 + (i * 200),
                         \sweepDir, [-1, 1].choose, \amp, 0.4]);
    };
};
"=== SCRATCH x4 ===".postln;
)

// --- GLITCH STUTTER : impacts rapides random -----
(
fork {
    16.do { |i|
        Synth(\impact, [\freq, rrand(35, 60), \decay, 0.15, \amp, 0.4]);
        rrand(0.06, 0.15).wait;
    };
};
"=== GLITCH STUTTER 2s ===".postln;
)

// --- ASIAN MELODIC FILL (guzheng arpege descendant) -----
(
[79, 77, 75, 72, 70, 67, 65, 63, 60].do { |n, i|
    fork {
        (i * 0.15).wait;
        Synth(\guzheng, [\freq, n.midicps, \amp, 0.18, \release, 1.0]);
    };
};
"=== ASIAN GUZHENG FILL ===".postln;
)

// --- DROP CUT brutal : coupe tout + sweep down + impact (2s) -----
(
~reload !? {
    Routine({
        var oldKick = ~kickAmp; var oldHat = ~hatAmp; var oldClap = ~clapAmp;
        ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0; ~reload.value;
        Synth(\sweep, [\dur, 2, \startCutoff, 8000, \endCutoff, 200, \amp, 0.4]);
        2.wait;
        Synth(\impact, [\freq, 30, \decay, 3, \amp, 0.85]);
        Synth(\crash, [\decay, 3, \amp, 0.4]);
        ~kickAmp = oldKick; ~hatAmp = oldHat; ~clapAmp = oldClap; ~reload.value;
    }).play;
    "=== DROP CUT 2s ===".postln;
};
)



// =====================================================================
// [K] TAP TEMPO (tap au moins 2 fois en rythme pour caler le delay)
// =====================================================================

// --- Tap (au moins 2 fois successifs) -----
( ~tap !? { ~tap.value }; )
( ~tap !? { ~tap.value }; )
( ~tap !? { ~tap.value }; )
( ~tap !? { ~tap.value }; )

// --- Reset du tap (efface l'historique) -----
( ~tapTempo !? { ~tapTempo[\last] = nil; "tap reset".postln }; )

// --- Set delayTime par division de tempo (sans tap) -----
( ~setFx !? { ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo / 4)  }; )    // 1/16
( ~setFx !? { ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo / 2)  }; )    // 1/8
( ~setFx !? { ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo)      }; )    // 1/4
( ~setFx !? { ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo * 0.75) }; )  // 1/4 dotted
( ~setFx !? { ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo * 2)  }; )    // 1/2

// --- Tempo en live (BPM direct) -----
( TempoClock.default.tempo = 110/60; )
( TempoClock.default.tempo = 132/60; )
( TempoClock.default.tempo = 145/60; )
( TempoClock.default.tempo = 174/60; )



// =====================================================================
// [L] FX BUS DETAIL (param par param par FX)
//     Pour chaque FX du bus, exposer les params principaux
// =====================================================================

// ---------- REVERB ----------
( ~setFx !? { ~setFx.(\rev, \mix,    0.4) }; )    // 0..1
( ~setFx !? { ~setFx.(\rev, \room,   0.5) }; )    // 0..1 (small room)
( ~setFx !? { ~setFx.(\rev, \room,   0.85) }; )   // hall
( ~setFx !? { ~setFx.(\rev, \room,   0.97) }; )   // cathedral
( ~setFx !? { ~setFx.(\rev, \damp,   0.6) }; )    // 0=brillant, 1=mat
( ~setFx !? { ~setFx.(\rev, \damp,   0.1) }; )    // tres brillant
( ~setFx !? { ~setFx.(\rev, \freeze, 1)   }; )
( ~setFx !? { ~setFx.(\rev, \freeze, 0)   }; )

// ---------- DELAY ----------
( ~setFx !? { ~setFx.(\dly, \delayTime, 0.375) }; )    // 1/8 a 120bpm
( ~setFx !? { ~setFx.(\dly, \delayTime, 0.5)   }; )    // 1/4
( ~setFx !? { ~setFx.(\dly, \delayTime, 0.25)  }; )    // 1/8 a 120
( ~setFx !? { ~setFx.(\dly, \feedback,  0.5)   }; )    // normal
( ~setFx !? { ~setFx.(\dly, \feedback,  0.85)  }; )    // self-oscillating
( ~setFx !? { ~setFx.(\dly, \feedback,  0.2)   }; )    // 2 echos
( ~setFx !? { ~setFx.(\dly, \mix,       0.5)   }; )
( ~setFx !? { ~setFx.(\dly, \color,     0.3)   }; )    // 0=tape dark, 1=clean

// ---------- CHORUS ----------
( ~setFx !? { ~setFx.(\chr, \rate,  0.4)   }; )
( ~setFx !? { ~setFx.(\chr, \rate,  1.5)   }; )       // rapide
( ~setFx !? { ~setFx.(\chr, \depth, 0.005) }; )       // subtil
( ~setFx !? { ~setFx.(\chr, \depth, 0.015) }; )       // large
( ~setFx !? { ~setFx.(\chr, \mix,   0.5)   }; )

// ---------- PHASER ----------
( ~setFx !? { ~setFx.(\phs, \rate,     0.3) }; )
( ~setFx !? { ~setFx.(\phs, \rate,     0.05) }; )     // tres slow
( ~setFx !? { ~setFx.(\phs, \depth,    0.7) }; )
( ~setFx !? { ~setFx.(\phs, \depth,    1.0) }; )
( ~setFx !? { ~setFx.(\phs, \feedback, 0.4) }; )
( ~setFx !? { ~setFx.(\phs, \feedback, 0.85) }; )     // self-osc
( ~setFx !? { ~setFx.(\phs, \mix,      0.5) }; )

// ---------- FLANGER ----------
( ~setFx !? { ~setFx.(\flg, \rate,     0.2) }; )
( ~setFx !? { ~setFx.(\flg, \rate,     0.05) }; )     // jet plane slow
( ~setFx !? { ~setFx.(\flg, \depth,    0.003) }; )
( ~setFx !? { ~setFx.(\flg, \depth,    0.008) }; )    // tres prononce
( ~setFx !? { ~setFx.(\flg, \feedback, 0.6) }; )
( ~setFx !? { ~setFx.(\flg, \feedback, 0.9) }; )      // metallic
( ~setFx !? { ~setFx.(\flg, \mix,      0.5) }; )

// ---------- BITCRUSH ----------
( ~setFx !? { ~setFx.(\crsh, \bits, 8)    }; )        // 8bit
( ~setFx !? { ~setFx.(\crsh, \bits, 4)    }; )        // 4bit
( ~setFx !? { ~setFx.(\crsh, \bits, 2)    }; )        // 2bit destroy
( ~setFx !? { ~setFx.(\crsh, \sampleRate, 8000)  }; ) // lo-fi
( ~setFx !? { ~setFx.(\crsh, \sampleRate, 4000)  }; ) // C64
( ~setFx !? { ~setFx.(\crsh, \sampleRate, 2000)  }; ) // gameboy
( ~setFx !? { ~setFx.(\crsh, \mix,    0.6) }; )

// ---------- TAPE ----------
( ~setFx !? { ~setFx.(\tape, \drive,   1.5) }; )
( ~setFx !? { ~setFx.(\tape, \drive,   3.0) }; )      // saturated
( ~setFx !? { ~setFx.(\tape, \wow,     0.0015) }; )
( ~setFx !? { ~setFx.(\tape, \wow,     0.005) }; )    // wobble fort
( ~setFx !? { ~setFx.(\tape, \flutter, 0.0008) }; )
( ~setFx !? { ~setFx.(\tape, \flutter, 0.003) }; )
( ~setFx !? { ~setFx.(\tape, \mix,     1.0) }; )

// ---------- SHIMMER ----------
( ~setFx !? { ~setFx.(\shim, \shimmer, 0.5) }; )
( ~setFx !? { ~setFx.(\shim, \shimmer, 0.9) }; )      // octave-up tres present
( ~setFx !? { ~setFx.(\shim, \room,    0.92) }; )
( ~setFx !? { ~setFx.(\shim, \mix,     0.5) }; )

// ---------- DIST ----------
( ~setFx !? { ~setFx.(\dist, \drive, 3.0) }; )
( ~setFx !? { ~setFx.(\dist, \drive, 5.0) }; )        // industriel
( ~setFx !? { ~setFx.(\dist, \drive, 8.0) }; )        // wall of sound
( ~setFx !? { ~setFx.(\dist, \tone,  0.5) }; )        // 0=dark, 1=bright
( ~setFx !? { ~setFx.(\dist, \tone,  0.2) }; )
( ~setFx !? { ~setFx.(\dist, \tone,  0.8) }; )
( ~setFx !? { ~setFx.(\dist, \mix,   0.5) }; )

// ---------- FX additionnels (ajoutes via ~addFx) ----------
( ~addFx !? { ~addFx.(\ringmod, [\freq, 200, \mix, 0.5]) }; ~send !? { ~send.(\ringmod, 0.4) }; )
( ~addFx !? { ~addFx.(\fshift,  [\shift, 80])            }; ~send !? { ~send.(\fshift,  0.3) }; )
( ~addFx !? { ~addFx.(\gran,    [\grainDur, 0.15, \pitch, 0.5]) }; ~send !? { ~send.(\gran, 0.4) }; )
( ~addFx !? { ~addFx.(\comb,    [\freq, 220, \decay, 2]) }; ~send !? { ~send.(\comb,    0.4) }; )
( ~addFx !? { ~addFx.(\formant, [\vowel, 0])             }; ~send !? { ~send.(\formant, 0.5) }; )
( ~addFx !? { ~addFx.(\autoflt, [\rate, 0.3, \lo, 200, \hi, 4000]) }; ~send !? { ~send.(\autoflt, 0.5) }; )
( ~addFx !? { ~addFx.(\stut,    [\rate, 8, \dutyCycle, 0.5]) }; ~send !? { ~send.(\stut, 1.0) }; )
( ~addFx !? { ~addFx.(\reson,   [\freq, 220, \decay, 3]) }; ~send !? { ~send.(\reson,   0.5) }; )
( ~addFx !? { ~addFx.(\spring,  [\decay, 1.5])           }; ~send !? { ~send.(\spring,  0.4) }; )
( ~addFx !? { ~addFx.(\plate,   [\decay, 2.5, \damp, 0.3]) }; ~send !? { ~send.(\plate, 0.4) }; )



// =====================================================================
// [M] STOP ALL FX (reset global -- panique mode)
// =====================================================================

// --- Stop tous les LFO (vars + FX) -----
( ~lfoStopEverything !? { ~lfoStopEverything.() }; )

// --- VCF off -----
( ~vcfOff !? { ~vcfOff.() }; )

// --- Comp / Sat off -----
( ~compOff !? { ~compOff.() }; )
( ~satOff  !? { ~satOff.()  }; )

// --- Reset FX bus (tout coupe) -----
( ~fxPreset !? { ~fxPreset.(\dry) }; )

// --- Stop autoFx par voix -----
( ~stopAutoFx !? { ~stopAutoFx.(\melody);  }; )
( ~stopAutoFx !? { ~stopAutoFx.(\acid);    }; )
( ~stopAutoFx !? { ~stopAutoFx.(\harmony); }; )

// --- Sidechain off -----
( ~scOff !? { ~scOff.() }; )

// --- Vinyl off -----
( ~vinyl !? { ~vinyl.free; ~vinyl = nil }; "vinyl OFF".postln; )

// --- Unfreeze reverb (au cas ou) -----
( ~setFx !? { ~setFx.(\rev, \freeze, 0) }; )

// --- RESET TOTAL : combine tout ce qui precede -----
(
~lfoStopEverything !? { ~lfoStopEverything.() };
~vcfOff            !? { ~vcfOff.() };
~compOff           !? { ~compOff.() };
~satOff            !? { ~satOff.() };
~scOff             !? { ~scOff.() };
~stopAutoFx        !? { [\melody, \acid, \harmony].do { |t| ~stopAutoFx.(t) } };
~vinyl             !? { ~vinyl.free; ~vinyl = nil };
~setFx             !? { ~setFx.(\rev, \freeze, 0) };
~fxPreset          !? { ~fxPreset.(\dry) };
"=== FX RESET TOTAL ===".postln;
)
