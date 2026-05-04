// =====================================================================
//  live/chains.scd  --  CHAINS / SEQUENCES LIVE (API ultra-courte)
//
//  ATTENTION SC -- noter la notation des appels :
//
//    NE MARCHE PAS  : ~ch.drop.()  ou  ~cc.drop.()
//      -> SC passe l'event ~ch comme 1er arg, et les vrais args sont
//         PERDUS (test empirique sur SC 3.14.1).
//      -> Pour les fonctions sans args (~ch[\drop]), l'effet visible
//         peut etre OK, MAIS pour celles avec args (~ch[\buildup].(8))
//         l'arg est silencieusement perdu.
//
//    MARCHE BIEN    : ~ch[\drop].()                  (notation indexee)
//                     ~chDrop.()                     (variable env directe)
//
//  ~ch                              // dict catalogue
//  ~ch[\intro], [\drop], [\breakdown], [\buildup], [\outro]
//  ~ch[\techno], [\acid], [\dubstep], [\trance], [\dnb], [\hiphop], [\world]
//  ~ch[\stop], [\custom]
//  ~ch[\full][\intro2drop], [\dropToBreak], [\outroFade]
//  ~ch[\list].()
//
//  RACCOURCIS env (API utilisateur primaire) :
//    ~chIntro, ~chDrop, ~chBreakdown, ~chBuildup, ~chOutro
//    ~chTechno, ~chAcid, ~chDubstep, ~chTrance, ~chDnb, ~chHiphop, ~chWorld
//    ~chStop, ~chCustom
//    ~chIntro2drop, ~chDropToBreak, ~chOutroFade
//    ~chList
//    ~cc -- alias env directe vers le dict (toujours valable pour
//           inspecter, mais pour APPELS utiliser les ~chXxx)
//
//  Tous les wrappers gardes par ~helper !? { ... }.
//
//  PREREQUIS : engine + palette/rhythm/sequences.scd + live/mixer.scd
//              charges (ou setupAll).
// =====================================================================

(
~ch = ();

// --- SECTIONS de track ---------------------------------------------
~ch[\intro]     = {              ~seqIntro     !? { ~seqIntro.() } };
~ch[\drop]      = {              ~seqDrop      !? { ~seqDrop.() } };
~ch[\breakdown] = {              ~seqBreakdown !? { ~seqBreakdown.() } };
~ch[\buildup]   = { |bars = 8|   ~seqBuildup   !? { ~seqBuildup.(bars) } };
~ch[\outro]     = {              ~seqOutro     !? { ~seqOutro.() } };

// --- LOOPS / EVOLUTIONS par genre ----------------------------------
~ch[\techno]    = { |repeats = 4| ~seqTechnoLoop  !? { ~seqTechnoLoop.(repeats) } };
~ch[\acid]      = {               ~seqAcidEvolve  !? { ~seqAcidEvolve.() } };
~ch[\dubstep]   = {               ~seqDubstepDrop !? { ~seqDubstepDrop.() } };
~ch[\trance]    = {               ~seqTrance16    !? { ~seqTrance16.() } };
~ch[\dnb]       = { |repeats = 4| ~seqDnBSwitch   !? { ~seqDnBSwitch.(repeats) } };
~ch[\hiphop]    = { |repeats = 8| ~seqHipHopLoop  !? { ~seqHipHopLoop.(repeats) } };
~ch[\world]     = {               ~seqWorldEvolve !? { ~seqWorldEvolve.() } };

// --- STOP / CUSTOM --------------------------------------------------
~ch[\stop]      = { ~seqStop !? { ~seqStop.() } };
~ch[\custom]    = { |actions| ~seqPlay !? { ~seqPlay.(actions) } };

// --- COMBOS pre-faits (enchaines) -----------------------------------
~ch[\full] = ();

~ch[\full][\intro2drop] = { |introDur = 4, buildDur = 4|
    Routine({
        ~seqIntro   !? { ~seqIntro.() };
        introDur.wait;
        ~seqBuildup !? { ~seqBuildup.(buildDur) };
        (buildDur * ~stepDur ? 0.25).wait;
        ~seqDrop    !? { ~seqDrop.() };
    }).play(TempoClock.default);
    "[ch.full.intro2drop] intro -> buildup -> drop".postln;
};

~ch[\full][\dropToBreak] = { |breakDur = 8|
    Routine({
        ~seqDrop      !? { ~seqDrop.() };
        4.wait;
        ~seqBreakdown !? { ~seqBreakdown.() };
        breakDur.wait;
        ~seqDrop      !? { ~seqDrop.() };
    }).play(TempoClock.default);
    "[ch.full.dropToBreak] drop -> break -> drop".postln;
};

~ch[\full][\outroFade] = { |dur = 12|
    ~seqOutro      !? { ~seqOutro.() };
    ~masterFadeOut !? { ~masterFadeOut.(dur) };
    ("[ch.full.outroFade] outro + fade " ++ dur ++ "s").postln;
};

// --- LISTE ----------------------------------------------------------
~ch[\list] = {
    "=== ~ch -- CHAINS / SEQUENCES ===".postln;
    "  sections : ~chIntro / ~chDrop / ~chBreakdown / ~chBuildup / ~chOutro".postln;
    "  loops    : ~chTechno / ~chAcid / ~chDubstep / ~chTrance / ~chDnb / ~chHiphop / ~chWorld".postln;
    "  stop     : ~chStop.()".postln;
    "  custom   : ~chCustom.([[N, action], ...])".postln;
    "  combos   : ~chIntro2drop.(4,4) | ~chDropToBreak.() | ~chOutroFade.(12)".postln;
};

// --- API utilisateur : variables d'env top-level --------------------
~chIntro     = { ~ch[\intro].() };
~chDrop      = { ~ch[\drop].() };
~chBreakdown = { ~ch[\breakdown].() };
~chBuildup   = { |bars = 8| ~ch[\buildup].(bars) };
~chOutro     = { ~ch[\outro].() };
~chTechno    = { |repeats = 4| ~ch[\techno].(repeats) };
~chAcid      = { ~ch[\acid].() };
~chDubstep   = { ~ch[\dubstep].() };
~chTrance    = { ~ch[\trance].() };
~chDnb       = { |repeats = 4| ~ch[\dnb].(repeats) };
~chHiphop    = { |repeats = 8| ~ch[\hiphop].(repeats) };
~chWorld     = { ~ch[\world].() };
~chStop      = { ~ch[\stop].() };
~chCustom    = { |actions| ~ch[\custom].(actions) };
~chIntro2drop  = { |introDur = 4, buildDur = 4| ~ch[\full][\intro2drop].(introDur, buildDur) };
~chDropToBreak = { |breakDur = 8| ~ch[\full][\dropToBreak].(breakDur) };
~chOutroFade   = { |dur = 12| ~ch[\full][\outroFade].(dur) };
~chList      = { ~ch[\list].() };

// --- ALIAS court (catalogue, pour inspection) -----------------------
~cc = ~ch;     // ~cc[\drop].() encore valable, mais prefere ~chDrop.()

"=== ~ch pret -- ~chDrop.() | ~chTechno.(4) | ~chIntro2drop.() | ~chList.() ===".postln;
)



// =====================================================================
//  EXEMPLES (Cmd+Entree)
// =====================================================================

// --- sections ---
// ( ~chIntro.(); )
// ( ~chDrop.(); )
// ( ~chBreakdown.(); )
// ( ~chBuildup.(8); )
// ( ~chOutro.(); )

// --- loops par genre ---
// ( ~chTechno.(4); )
// ( ~chAcid.(); )
// ( ~chDubstep.(); )
// ( ~chTrance.(); )
// ( ~chDnb.(4); )
// ( ~chHiphop.(8); )
// ( ~chWorld.(); )

// --- stop ---
// ( ~chStop.(); )

// --- combos pré-faits ---
// ( ~chIntro2drop.(4, 4); )
// ( ~chDropToBreak.(8); )
// ( ~chOutroFade.(12); )

// --- custom (chaine arbitraire) ---
// ( ~chCustom.([
//     [ 16, { ~kickSteps = [1,0,0,0]!4.flat; ~reload.value } ],
//     [ 16, { ~kickSteps = [1,0,1,0]!4.flat; ~reload.value } ],
//     [ 16, { ~kickSteps = (0!16); ~reload.value } ]
// ]); )

// --- liste ---
// ( ~chList.(); )
