// =====================================================================
//  examples/04_filter_lfo_vcf.scd  --  Filtres et modulations
//
//  TITRE       : LFO sur variables + VCF master en chaine
//  DUREE       : ~5 minutes
//  NIVEAU      : intermediaire
//  PREREQUIS   : CHARGER TOUT (00_load.scd) PUIS evaluer le SETUP
//                de live.scd (premier bloc top-level "(...)" du fichier)
//
//  CONCEPTS
//    - ~lfoTo modulation par LFO d'une variable d'environnement
//      (rebuild les Pdef en boucle)
//    - VCF master : un Synth qui filtre tout le bus 0 avant le
//      master limiter. Reproduit un SH-101, MS-20, Moog, formant...
//
//  Si tu vois "~lfoTo is not defined", c'est que live.scd n'a pas
//  ete charge -- ouvre live.scd et evalue son SETUP.
// =====================================================================


// --- [etape 0] Verification ----------------------------------------
(
if (~lfoTo.isNil) {
    "!!! live.scd pas charge -- ouvre live.scd et evalue son SETUP".postln;
} {
    "live.scd OK".postln;
};
)


// --- [etape 1] Demarrer un beat techno minimal ---------------------
(
~kickAmp = 0.55; ~hatAmp = 0.18; ~acidAmp = 0.32; ~melodyAmp = 0.16;
~melodyInst = \saw3;
~reload.value;
[\kickSeq, \hatSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).play };
"beat lance -- pret pour les LFO".postln;
)


// --- [etape 2] LFO sin sur le cutoff de la melodie ------------------
//   ~lfoTo.(\param, rateHz, depth, shape, center)
//     param   = nom de variable d'environnement (sans tilde)
//     rate    = Hz (0.5 = lent, 4 = rapide)
//     depth   = amplitude de modulation (additionnee a center)
//     shape   = \sin \tri \saw \sqr \rand \smoothRand \drunk \noise
//     center  = valeur centrale (autour de laquelle le LFO oscille)
( ~lfoTo.(\melodyCutoff, 0.5, 1500, \sin, 2500); )
//  -- la melodie respire (cutoff oscille entre 1000 et 4000 Hz).
//  Laisser tourner 30s.


// --- [etape 3] LFO sqr sur l'ampli acid (gate rythmique) ------------
//   shape \sqr cree un gate on/off rapide => effet trance gate.
( ~lfoTo.(\acidAmp, 4, 0.4, \sqr, 0.5); )


// --- [etape 4] LFO drunk sur le BPM (subtile derive) ----------------
//   shape \drunk fait un random walk lent (jamais de saut brutal).
( ~lfoTo.(\bpm, 0.1, 8, \drunk, 132); )
//  -- BPM oscille entre 124 et 140 lentement.


// --- [etape 5] STOP les LFO un par un ------------------------------
( ~lfoStopVar.(\melodyCutoff); )
( ~lfoStopVar.(\acidAmp); )
( ~lfoStopVar.(\bpm); )
//  ou TOUT couper d'un coup :
// ( ~lfoStopAllVars.(); )


// --- [etape 6] VCF master Moog -- filtre tout le mix ----------------
//   ~vcfOn.(\type, freq, q)
//     types : \moog \ms20 \ladder \formant \comb \hpf \bpf \notch
( ~vcfOn.(\moog, 800, 0.4); )
//  -- on entend une coupure douce ; tout le mix est plus sombre.


// --- [etape 7] Sweep automatique du cutoff (8s) --------------------
//   ~vcfSweep.(fromHz, toHz, dur, curve)
( ~vcfSweep.(8000, 200, 8); )
//  -- fait une descente filtre 8000 -> 200 Hz sur 8s. Effet "filter close".


// --- [etape 8] Couper le VCF (signal redevient brillant) ------------
( ~vcfOff.(); )


// --- [etape 9] VCF formant -- voyelle 'a' --------------------------
//   Pour le formant, freq = INDICE de voyelle (0=a 1=e 2=i 3=o 4=u),
//   q = resonance (0.05 a 1).
( ~vcfOn.(\formant, 0, 0.3); )       // 'a' large

// changer en voyelle 'i' (plus aigue)
( ~vcfSet.(\vowel, 2); )

// arreter
( ~vcfOff.(); )


// --- [etape 10] Preset VCF acid (Moog 600Hz, q tres haute) ---------
( ~vcfPreset.(\acid); )

// preset deep, dub, bright, dark, formantA-U
( ~vcfPreset.(\dub); )
( ~vcfPreset.(\bright); )
( ~vcfOff.(); )


// --- [etape 11] STOP global -----------------------------------------
(
~lfoStopAllVars.();
~vcfOff.();
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
