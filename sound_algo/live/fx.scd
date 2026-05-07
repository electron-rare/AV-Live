// =====================================================================
//  live/fx.scd  --  FX LIVE (API ultra-courte, wrappers consolides)
//
//  ATTENTION SC -- noter la notation des appels :
//
//    NE MARCHE PAS  : ~fx.preset.(\dub)
//      -> SC passe l'event ~fx comme 1er arg, et les vrais args sont
//         PERDUS (test empirique sur SC 3.14.1).
//
//    MARCHE BIEN    : ~fx[\preset].(\dub)            (notation indexee)
//                     ~fxPreset.(\dub)               (variable env directe)
//                     ~ff.(\dub)                     (alias env direct)
//
//  ~fx                              // dict catalogue
//  ~fx[\preset].(\dub|\trance|...)
//  ~fx[\snd].(\rev, 0.4)            // ~send (.send reservee)
//  ~fx[\st].(\dly, \delayTime, 0.5) // ~setFx (.set reservee)
//  ~fx[\tp].()                      // tap tempo (.tap reservee)
//  ~fx[\freeze].(0|1)
//  ~fx[\drop] / [\breakdown] / [\buildup]
//  ~fx[\glitch] / [\stutter] / [\freezeR]
//  ~fx[\tapeStop] / [\tapeRev] / [\handsUp] / [\jumpCut]
//  ~fx[\bitCrush] / [\ring] / [\shift] / [\gran]
//  ~fx[\vcf][\on], [\off], [\freq], [\q], [\sweep], [\preset]
//  ~fx[\lfo][\go] / [\stop][\go] / [\stop][\all]
//  ~fx[\cut] / [\rq] / [\drive]
//  ~fx[\comp][\go] / [\off]   ~fx[\sat][\go] / [\off]
//  ~fx[\list].()
//
//  RACCOURCIS env (API utilisateur primaire) :
//    ~fxPreset, ~fxSnd, ~fxSt, ~fxTp, ~fxFreeze
//    ~fxDrop, ~fxBreakdown, ~fxBuildup
//    ~fxGlitch, ~fxStutter, ~fxFreezeR
//    ~fxTapeStop, ~fxTapeRev, ~fxHandsUp, ~fxJumpCut
//    ~fxBitCrush, ~fxRing, ~fxShift, ~fxGran
//    ~fxVcfOn, ~fxVcfOff, ~fxVcfFreq, ~fxVcfQ, ~fxVcfSweep, ~fxVcfPreset
//    ~fxLfo, ~fxLfoStop, ~fxLfoStopAll
//    ~fxCut, ~fxRq, ~fxDrive
//    ~fxComp, ~fxCompOff, ~fxSat, ~fxSatOff
//    ~fxList
//    ~ff (= ~fxPreset)
//
//  TOUS les wrappers gardes par ~helper !? { ... } pour ne pas planter
//  si le helper sous-jacent n'est pas charge.
//
//  PREREQUIS : engine + live/fx_bus.scd + live/live.scd charges.
// =====================================================================

(
~fx = ();

// --- PRESETS FX (dub/space/trance/...) ------------------------------
~fx[\preset] = { |name = \dry|
    ~fxPreset !? { ~fxPreset.(name) };
};

// --- SEND / SET sur un bus FX --------------------------------------
~fx[\snd] = { |fxName, amount = 0.3|
    ~send !? { ~send.(fxName, amount) };
};
~fx[\st] = { |fxName, param, value|
    ~setFx !? { ~setFx.(fxName, param, value) };
};

// --- FREEZE reverb permanent / TAP tempo ---------------------------
~fx[\freeze] = { |on = 1|
    ~setFx !? { ~setFx.(\rev, \freeze, on) };
    ("[fx.freeze] " ++ on).postln;
};
~fx[\tp] = { ~tap !? { ~tap.() } };

// --- DROP / BREAKDOWN / BUILDUP ------------------------------------
~fx[\drop]      = { |dur = 4|  ~drop      !? { ~drop.(dur) } };
~fx[\breakdown] = { |dur = 8|  ~breakdown !? { ~breakdown.(dur) } };
~fx[\buildup]   = { |dur = 8|  ~buildup   !? { ~buildup.(dur) } };

// --- TRICKS scéniques ----------------------------------------------
~fx[\glitch]    = { |dur = 2|     ~glitch     !? { ~glitch.(dur) } };
~fx[\stutter]   = { |rate = 8, dur = 1| ~stutter !? { ~stutter.(rate, dur) } };
~fx[\freezeR]   = { |dur = 4|     ~freeze     !? { ~freeze.(dur) } };
~fx[\tapeStop]  = { |dur = 2|     ~tapeStop   !? { ~tapeStop.(dur) } };
~fx[\tapeStart] = { |dur = 2, t|  ~tapeStart  !? { ~tapeStart.(dur, t) } };
~fx[\playAll]   = {               ~playAll    !? { ~playAll.() } };
~fx[\tapeRev]   = { |dur = 4|     ~tapeReverse!? { ~tapeReverse.(dur) } };
~fx[\handsUp]   = {               ~handsUp    !? { ~handsUp.() } };
~fx[\jumpCut]   = { |dur = 0.5|   ~jumpCut    !? { ~jumpCut.(dur) } };
~fx[\bitCrush]  = { |bits = 6, sr = 6000, dur = 1| ~bitCrushNow !? { ~bitCrushNow.(bits, sr, dur) } };
~fx[\ring]      = { |freq = 200, dur = 1| ~ringMod   !? { ~ringMod.(freq, dur) } };
~fx[\shift]     = { |hz = 100, dur = 1|   ~freqShift !? { ~freqShift.(hz, dur) } };
~fx[\gran]      = { |dur = 2|             ~granFreeze!? { ~granFreeze.(dur) } };

// --- VCF (filtre live tout-source) ---------------------------------
~fx[\vcf] = ();
~fx[\vcf][\on]    = { |type = \moog, freq = 1500, q = 0.5|
    ~vcfOn !? { ~vcfOn.(type, freq, q) };
};
~fx[\vcf][\off]   = { ~vcfOff !? { ~vcfOff.() } };
~fx[\vcf][\freq]  = { |hz = 1500|  ~vcfSet !? { ~vcfSet.(\freq, hz) } };
~fx[\vcf][\q]     = { |val = 0.5|  ~vcfSet !? { ~vcfSet.(\q, val) } };
~fx[\vcf][\sweep] = { |from = 200, to = 5000, dur = 4|
    ~vcfSweep !? { ~vcfSweep.(from, to, dur) };
};
~fx[\vcf][\preset] = { |preset = \acid|
    ~vcfPreset !? { ~vcfPreset.(preset) };
};

// --- LFO sur n'importe quelle variable ~xxx ------------------------
~fx[\lfo] = ();
~fx[\lfo][\go] = { |paramName, rate = 0.5, depth = 0.3, shape = \sin, center = nil|
    ~lfoTo !? { ~lfoTo.(paramName, rate, depth, shape, center) };
};
~fx[\lfo][\stop] = ();
~fx[\lfo][\stop][\go]  = { |paramName| ~lfoStopVar     !? { ~lfoStopVar.(paramName) } };
~fx[\lfo][\stop][\all] = {             ~lfoStopAllVars !? { ~lfoStopAllVars.() } };

// --- SHORTCUTS cutoff / rq / drive par voie ------------------------
~fx[\cut] = { |voie = \mel, hz = 2000|
    var v = voie.asSymbol;
    if (v == \mel or: { v == \melody }) {
        ~melodyCutoff = hz; ~reload !? { ~reload.value };
        ("[fx.cut] melody " ++ hz ++ "Hz").postln;
    } { if (v == \acid) {
        ~acidCutoff = hz; ~reload !? { ~reload.value };
        ("[fx.cut] acid " ++ hz ++ "Hz").postln;
    } { ("[fx.cut] voie inconnue : " ++ v ++ " (utilise \\mel ou \\acid)").postln } };
};
~fx[\rq] = { |voie = \mel, val = 0.5|
    var v = voie.asSymbol;
    if (v == \mel or: { v == \melody }) {
        ~melodyRq = val; ~reload !? { ~reload.value };
        ("[fx.rq] melody " ++ val).postln;
    } { if (v == \acid) {
        ~acidRq = val; ~reload !? { ~reload.value };
        ("[fx.rq] acid " ++ val).postln;
    } { ("[fx.rq] voie inconnue : " ++ v).postln } };
};
~fx[\drive] = { |voie = \mel, val = 1.5|
    var v = voie.asSymbol;
    if (v == \mel or: { v == \melody }) {
        ~melodyDrive = val; ~reload !? { ~reload.value };
        ("[fx.drive] melody " ++ val).postln;
    } { if (v == \acid) {
        ~acidDrive = val; ~reload !? { ~reload.value };
        ("[fx.drive] acid " ++ val).postln;
    } { ("[fx.drive] voie inconnue : " ++ v).postln } };
};

// --- COMP / SAT master ---------------------------------------------
~fx[\comp] = ();
~fx[\comp][\go]  = { |preset = \glue|        ~compOn  !? { ~compOn.(preset) } };
~fx[\comp][\off] = {                         ~compOff !? { ~compOff.() } };
~fx[\sat]  = ();
~fx[\sat][\go]   = { |mode = \tanh, amount = 1.5|
    var modeNum = switch (mode.asSymbol, \tanh, 0, \softclip, 1, \fold, 2, 0);
    ~satOn !? { ~satOn.(amount, modeNum) };
};
~fx[\sat][\off]  = {                         ~satOff !? { ~satOff.() } };

// --- LISTE -----------------------------------------------------------
~fx[\list] = {
    "=== ~fx -- FX LIVE ===".postln;
    "  presets  : dry / dub / space / trance / dubstep / retro /".postln;
    "             industrial / dream / cosmic / drone".postln;
    "  bus      : rev / dly / chr / phs / flg / crsh / tape / shim / dist".postln;
    "  tricks   : drop / breakdown / buildup / glitch / stutter / freezeR /".postln;
    "             tapeStop / tapeRev / handsUp / jumpCut / bitCrush / ring /".postln;
    "             shift / gran".postln;
    "  vcf      : on / off / freq / q / sweep / preset".postln;
    "  lfo      : ~fxLfo.(\\param,rate,depth) | ~fxLfoStop.(\\p) | ~fxLfoStopAll.()".postln;
    "  voie cut : ~fxCut.(\\mel|\\acid, hz)".postln;
    "  comp/sat : ~fxComp.(\\glue) | ~fxSat.(\\tanh, 1.5)".postln;
};

// --- API utilisateur : variables d'env top-level --------------------
// SUPPRIME : ~fxPreset etait redefinie ici en wrapper de ~fx[\preset],
// mais ~fx[\preset] appelle DEJA ~fxPreset -> RECURSION INFINIE.
// Cause de la fuite RAM 40GB+ historique. ~fxPreset reste celui de
// fx_bus.scd (vraie implementation). ~ff l'alias court reste plus bas.
// ~fxPreset = { |name = \dry| ~fx[\preset].(name) };  // SUPPRIME
~fxSnd       = { |fxName, amount = 0.3| ~fx[\snd].(fxName, amount) };
~fxSt        = { |fxName, param, value| ~fx[\st].(fxName, param, value) };
~fxTp        = { ~fx[\tp].() };
~fxFreeze    = { |on = 1| ~fx[\freeze].(on) };
~fxDrop      = { |dur = 4| ~fx[\drop].(dur) };
~fxBreakdown = { |dur = 8| ~fx[\breakdown].(dur) };
~fxBuildup   = { |dur = 8| ~fx[\buildup].(dur) };
~fxGlitch    = { |dur = 2| ~fx[\glitch].(dur) };
~fxStutter   = { |rate = 8, dur = 1| ~fx[\stutter].(rate, dur) };
~fxFreezeR   = { |dur = 4| ~fx[\freezeR].(dur) };
~fxTapeStop  = { |dur = 2| ~fx[\tapeStop].(dur) };
~fxTapeStart = { |dur = 2, t| ~fx[\tapeStart].(dur, t) };
~fxPlayAll   = { ~fx[\playAll].() };
~fxTapeRev   = { |dur = 4| ~fx[\tapeRev].(dur) };
~fxHandsUp   = { ~fx[\handsUp].() };
~fxJumpCut   = { |dur = 0.5| ~fx[\jumpCut].(dur) };
~fxBitCrush  = { |bits = 6, sr = 6000, dur = 1| ~fx[\bitCrush].(bits, sr, dur) };
~fxRing      = { |freq = 200, dur = 1| ~fx[\ring].(freq, dur) };
~fxShift     = { |hz = 100, dur = 1| ~fx[\shift].(hz, dur) };
~fxGran      = { |dur = 2| ~fx[\gran].(dur) };
~fxVcfOn     = { |type = \moog, freq = 1500, q = 0.5| ~fx[\vcf][\on].(type, freq, q) };
~fxVcfOff    = { ~fx[\vcf][\off].() };
~fxVcfFreq   = { |hz = 1500| ~fx[\vcf][\freq].(hz) };
~fxVcfQ      = { |val = 0.5| ~fx[\vcf][\q].(val) };
~fxVcfSweep  = { |from = 200, to = 5000, dur = 4| ~fx[\vcf][\sweep].(from, to, dur) };
~fxVcfPreset = { |preset = \acid| ~fx[\vcf][\preset].(preset) };
~fxLfo       = { |paramName, rate = 0.5, depth = 0.3, shape = \sin, center = nil|
    ~fx[\lfo][\go].(paramName, rate, depth, shape, center) };
~fxLfoStop    = { |paramName| ~fx[\lfo][\stop][\go].(paramName) };
~fxLfoStopAll = { ~fx[\lfo][\stop][\all].() };
~fxCut       = { |voie = \mel, hz = 2000| ~fx[\cut].(voie, hz) };
~fxRq        = { |voie = \mel, val = 0.5| ~fx[\rq].(voie, val) };
~fxDrive     = { |voie = \mel, val = 1.5| ~fx[\drive].(voie, val) };
~fxComp      = { |preset = \glue| ~fx[\comp][\go].(preset) };
~fxCompOff   = { ~fx[\comp][\off].() };
~fxSat       = { |mode = \tanh, amount = 1.5| ~fx[\sat][\go].(mode, amount) };
~fxSatOff    = { ~fx[\sat][\off].() };
~fxList      = { ~fx[\list].() };
~ff          = { |name = \dry| ~fxPreset.(name) };  // alias court

"=== ~fx pret -- ~ff.(\\dub) | ~fxDrop.() | ~fxVcfPreset.(\\acid) | ~fxList.() ===".postln;
)



// =====================================================================
//  EXEMPLES (Cmd+Entree)
// =====================================================================

// --- presets prets ---
// ( ~ff.(\dub); )
// ( ~ff.(\trance); )
// ( ~ff.(\dubstep); )
// ( ~ff.(\space); )
// ( ~ff.(\dry); )

// --- send / set manuel ---
// ( ~fxSnd.(\rev, 0.4); )
// ( ~fxSnd.(\dly, 0.3); )
// ( ~fxSt.(\dly, \delayTime, 0.375); )
// ( ~fxSt.(\rev, \room, 0.95); )

// --- freeze reverb ---
// ( ~fxFreeze.(1); ~fxSnd.(\rev, 0.6); )
// ( ~fxFreeze.(0); )

// --- drop / breakdown / buildup ---
// ( ~fxDrop.(); )
// ( ~fxBreakdown.(8); )
// ( ~fxBuildup.(8); )

// --- tricks scéniques ---
// ( ~fxGlitch.(2); )
// ( ~fxStutter.(8, 1); )
// ( ~fxFreezeR.(4); )
// ( ~fxTapeStop.(2); )
// ( ~fxTapeRev.(4); )
// ( ~fxHandsUp.(); )
// ( ~fxJumpCut.(0.5); )
// ( ~fxBitCrush.(4, 4000, 1); )
// ( ~fxRing.(200, 1); )
// ( ~fxShift.(100, 1); )
// ( ~fxGran.(2); )

// --- VCF live ---
// ( ~fxVcfPreset.(\acid); )
// ( ~fxVcfPreset.(\dub); )
// ( ~fxVcfOn.(\moog, 800, 0.7); )
// ( ~fxVcfFreq.(1200); )
// ( ~fxVcfQ.(0.6); )
// ( ~fxVcfSweep.(200, 4000, 6); )
// ( ~fxVcfOff.(); )

// --- LFO sur var ---
// ( ~fxLfo.(\melodyCutoff, 0.2, 800, \sin, 1500); )
// ( ~fxLfoStop.(\melodyCutoff); )
// ( ~fxLfoStopAll.(); )

// --- shortcuts par voie ---
// ( ~fxCut.(\mel, 1200); )
// ( ~fxCut.(\acid, 600); )
// ( ~fxRq.(\mel, 0.7); )
// ( ~fxDrive.(\acid, 3.0); )

// --- comp / sat master ---
// ( ~fxComp.(\glue); )
// ( ~fxCompOff.(); )
// ( ~fxSat.(\tanh, 2.0); )
// ( ~fxSatOff.(); )

// --- liste ---
// ( ~fxList.(); )
