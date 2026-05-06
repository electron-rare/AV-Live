// =====================================================================
//  01_live.scd  --  TABLEAU DE BORD LIVE  (Cmd+Entree par bloc)
//
//  PREREQUIS :
//    1. 00_load.scd > Cmd+Entree sur "CHARGER TOUT"
//    2. Attends le boot serveur + ~check OK
//    3. Reviens ici, Cmd+Entree sur n'importe quel bloc
//
//  API LIVE (wrappers env directs ~xxx -- jamais ~dict.key.()) :
//    ~kk   kicks       ~kk.(\techno)         ~kPat / ~kTim / ~kList
//    ~mm   melodies    ~mm.(50)              ~mLong / ~mXlong / ~mEpic / ~mRnd / ~mGen
//    ~ff   fx presets  ~ff.(\dub)            ~fxDrop / ~fxVcfOn / ~fxLfo / ~fxCut
//    ~cc   chains      ~chDrop.()            ~chIntro / ~chBuildup / ~chIntro2drop
//    ~p    patterns    ~pKit.(\dub)          ~pGenre.(\trance138) / ~pHat / ~pClap
//
//  IMPORTANT : la notation `~dict.key.(args)` NE MARCHE PAS en SC --
//  SC passe l'event ~dict comme 1er arg et perd les vrais args (test
//  empirique sur SC 3.14.1, cf Dictionary.sc:549). De plus certaines
//  cles courtes ou collisionnant avec methodes Object/Server (s/t/p/e/l,
//  set/send/next/prev/tap...) plantent carrement.
//  Solutions : wrappers env directs (~kPat, ~mLong...) ou notation
//  indexee (~k[\pat].(\amen), ~m[\long].(15)).
//  Renommages internes : .p -> .pat, .t -> .tim, .s -> .short,
//  .l -> .long, .x -> .xlong, .e -> .epic, .r -> .rnd, .next -> .nx,
//  .prev -> .pv, .send -> .snd, .set -> .st, .tap -> .tp.
// =====================================================================


// =====================================================================
//  [0]  CHARGEMENT COMPLET (1 seul Cmd+Entree -- engine + boot + live)
//       Auto-detecte ~base depuis le chemin de ce fichier.
// =====================================================================
(
~base = if (thisProcess.nowExecutingPath.notNil) {
    thisProcess.nowExecutingPath.dirname ++ "/"
} {
    "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/"
};
(~base ++ "live/_load.scd").load;
)


// =====================================================================
//  [1]  KICKS  -- ~kk
// =====================================================================
( ~kk.(\techno); )            // 4/4 + rond
( ~kk.(\gabber); )            // dense + distordu
( ~kk.(\dub); )               // one-drop + sub
( ~kk.(\dubstep); )           // half-time + 808
( ~kk.(\trance); )            // 4/4 punchy
( ~kk.(\hardstyle); )         // hardstyle distordu
( ~kk.(\amen); )              // amen break
( ~kk.(\dnb); )               // drum'n'bass
( ~kk.(\jungle); )            // jungle rapid
( ~kk.(\house); )             // house 4/4 + 909
( ~kk.(\detroit); )           // detroit + 909
( ~kk.(\phonk); )             // half-time + 808
( ~kk.(\afro); )              // afrobeat
( ~kk.(\garage); )            // 2-step
( ~kk.(\triphop); )           // lazy boomy
( ~kk.(\footwork); )          // 160 BPM triple
( ~kk.(\minimal); )           // 1 kick / mesure
( ~kk.(\electro); )           // electro syncope

// patterns / timbres seuls (variables env directes, pas ~k.pat !)
( ~kPat.(\amen); )
( ~kPat.(\dense); )
( ~kPat.(\off); )             // silence kick
( ~kTim.(\808); )
( ~kTim.(\909); )
( ~kTim.(\distorded); )
( ~kList.(); )


// =====================================================================
//  [2]  MELODIES  -- ~mm + wrappers env directs ~mXxx
// =====================================================================
// short (32 steps, 78 dispos)
( ~mm.(1); )                  // applique m1
( ~mm.(50); )                 // applique m50
( ~mRnd.(); )                 // random short

// long (64 steps, 30 dispos)
( ~mLong.(1); )
( ~mLong.(15); )
( ~mRndLong.(); )

// xlong (96 steps, 15 dispos)
( ~mXlong.(1); )
( ~mRndXlong.(); )

// epic (128 steps, 10 dispos)
( ~mEpic.(2); )
( ~mRndEpic.(); )

// par genre
( ~mGen.(\acid); )
( ~mGen.(\trance); )
( ~mGen.(\detroit); )
( ~mGen.(\dnb); )
( ~mGen.(\dub); )
( ~mGen.(\oriental); )
( ~mGen.(\synthwave); )
( ~mGen.(\phonk); )

// navigation
( ~mNx.(); )                  // melodie suivante
( ~mPv.(); )                  // precedente

// instrument melody
( ~mInst.(\warmPad); )
( ~mInst.(\pluck); )
( ~mInst.(\stab); )
( ~mInst.(\saw3); )
( ~mInst.(\fmBell); )
( ~mInst.(\supersaw); )
( ~mInst.(\rhodes); )
( ~mInst.(\guzheng); )
( ~mInst.(\koto); )
( ~mInst.(\handpan); )

// harmonie
( ~mHarm.(\third); )          // tierce automatique
( ~mHarm.(\fifth); )
( ~mHarm.(\counter); )
( ~mHarm.(\bassline); )
( ~mHarm.(\dubBass); )
( ~mHarm.(\arp); )
( ~mHarm.(\chord); )
( ~mHarm.(\tranceLayer); )
( ~mHarm.(\cinematic); )
( ~mHarm.(\off); )

( ~mHarmInst.(\subBoom); )
( ~mHarmInst.(\warmPad); )

// tweaks rapides
( ~mAmp.(0.18); )
( ~mCut.(2500); )
( ~mCut.(8000); )
( ~mDrive.(2.5); )
( ~mOff.(); )                 // melody muette
( ~mList.(); )


// =====================================================================
//  [3]  FX  -- ~ff + wrappers env directs ~fxXxx
// =====================================================================
// presets (10)
( ~ff.(\dub); )
( ~ff.(\space); )
( ~ff.(\trance); )
( ~ff.(\dubstep); )
( ~ff.(\retro); )
( ~ff.(\industrial); )
( ~ff.(\dream); )
( ~ff.(\cosmic); )
( ~ff.(\drone); )
( ~ff.(\dry); )

// sends individuels
( ~fxSnd.(\rev, 0.4); )
( ~fxSnd.(\dly, 0.3); )
( ~fxSnd.(\shim, 0.5); )
( ~fxSt.(\rev, \mix, 0.7); )
( ~fxSt.(\dly, \delayTime, 0.5); )

// freeze reverb
( ~fxFreeze.(1); )
( ~fxFreeze.(0); )

// tricks scéniques
( ~fxDrop.(); )                       // build silence -> snareFill -> blast
( ~fxBreakdown.(8); )                 // kill rythmique progressif sur dur s
( ~fxBuildup.(8); )                   // crescendo (riser + fade in + sweep up)
( ~fxGlitch.(2); )                    // bitcrush + stutter + delay courte
( ~fxStutter.(8, 1); )                // gate amp à rateHz pendant dur s
( ~fxFreezeR.(4); )                   // reverb freeze + cut sec, retour apres dur
( ~fxTapeStop.(2); )                  // ralenti tempo expo -> stop Pdef (dur s)
( ~fxTapeStart.(2); )                 // RELANCE apres tapeStop : tempo 0.01 -> courant
( ~fxTapeStart.(2, 2.8); )            // idem mais cible 150 BPM (TempoClock = BPM/60)
( ~fxPlayAll.(); )                    // relance instantanee de tous les Pdef sequenceurs
( ~fxTapeRev.(4); )                   // riser inverse + filter sweep + freeze rev
( ~fxHandsUp.(); )                    // mute kick + boost lead + delay courte + clap
( ~fxJumpCut.(0.5); )                 // silence sec dur s puis reprend tout
( ~fxBitCrush.(6, 6000, 1); )         // bitcrush master (bits, sr, dur)
( ~fxRing.(200, 1); )                 // ring modulator master (freq, dur)
( ~fxShift.(100, 1); )                // freq shifter master (hz, dur)
( ~fxGran.(2); )                      // freeze granulaire master pendant dur s

// VCF master
( ~fxVcfOn.(\moog, 800, 0.5); )
( ~fxVcfOn.(\ladder, 1500, 0.7); )
( ~fxVcfOn.(\formant, 1, 0.3); )      // voyelle 'a'
( ~fxVcfFreq.(2000); )
( ~fxVcfQ.(0.6); )
( ~fxVcfSweep.(8000, 200, 8); )
( ~fxVcfPreset.(\acid); )
( ~fxVcfOff.(); )

// LFO
( ~fxLfo.(\melodyCutoff, 0.5, 1500); )
( ~fxLfo.(\acidAmp, 4, 0.4); )
( ~fxLfo.(\kickAmp, 0.3, 0.3); )
( ~fxLfoStop.(\melodyCutoff); )
( ~fxLfoStopAll.(); )

// shortcuts cutoff/RQ/drive par voie
( ~fxCut.(\mel, 5000); )
( ~fxCut.(\acid, 1500); )
( ~fxRq.(\mel, 0.4); )
( ~fxDrive.(\mel, 2.0); )

// master comp / saturation
( ~fxComp.(\glue); )
( ~fxComp.(\punch); )
( ~fxComp.(\pump); )
( ~fxCompOff.(); )
( ~fxSat.(\tanh, 1.5); )
( ~fxSat.(\softclip, 1.2); )
( ~fxSatOff.(); )

( ~fxList.(); )


// =====================================================================
//  [4]  CHAINS  -- wrappers env directs ~chXxx (jamais ~cc.key.()!)
// =====================================================================
( ~chIntro.(); )              // sequence intro montante
( ~chDrop.(); )               // drop sec
( ~chBreakdown.(); )
( ~chBuildup.(8); )           // crescendo trance 8 mesures
( ~chOutro.(); )

// loops par genre
( ~chTechno.(4); )
( ~chAcid.(); )
( ~chDubstep.(); )
( ~chTrance.(); )
( ~chDnb.(4); )
( ~chHiphop.(8); )
( ~chWorld.(); )

// combos prêts
( ~chIntro2drop.(4, 4); )            // intro -> buildup -> drop
( ~chDropToBreak.(8); )              // drop -> breakdown -> drop
( ~chOutroFade.(12); )               // outro + masterFadeOut

// stop chain en cours
( ~chStop.(); )
( ~chList.(); )


// =====================================================================
//  [5]  PATTERNS rythmiques  -- wrappers env directs ~pXxx
// =====================================================================
// kits complets (16 dispos)
( ~pKit.(\techno); )
( ~pKit.(\dubstep); )
( ~pKit.(\dnb); )
( ~pKit.(\trap); )
( ~pKit.(\house); )
( ~pKit.(\hardstyle); )
( ~pKit.(\jungle); )
( ~pKit.(\phonk); )
( ~pKit.(\industrial); )
( ~pKit.(\hardcore); )
( ~pKit.(\detroitDeep); )
( ~pKit.(\lofiHipHop); )
( ~pKit.(\tribalWorld); )

// genres rythmiques (20 dispos)
( ~pGenre.(\hardTechno); )
( ~pGenre.(\acidHouse); )
( ~pGenre.(\trance138); )
( ~pGenre.(\psyTrance); )
( ~pGenre.(\liquidDnB); )
( ~pGenre.(\neurofunk); )
( ~pGenre.(\jungle165); )
( ~pGenre.(\futureBass); )
( ~pGenre.(\deepHouse); )
( ~pGenre.(\techHouse); )
( ~pGenre.(\industrialV2); )
( ~pGenre.(\breakcore); )
( ~pGenre.(\footwork); )
( ~pGenre.(\idm); )
( ~pGenre.(\glitchHop); )

// elements isoles (noms reels : voir ~pList.())
( ~pHat.(\off2); )            // offbeat 8th
( ~pHat.(\eighth); )
( ~pHat.(\sixteen); )
( ~pHat.(\shuffle); )
( ~pHat.(\off); )
( ~pSnare.(\two4); )
( ~pSnare.(\ghost); )
( ~pSnare.(\roll); )
( ~pSnare.(\off); )
( ~pClap.(\two4); )
( ~pClap.(\offbeat); )
( ~pClap.(\trance); )
( ~pClap.(\dub); )
( ~pClap.(\off); )
( ~pPerc.(\rim); )
( ~pPerc.(\tom); )
( ~pPerc.(\cowbell); )
( ~pPerc.(\openHat); )
( ~pPerc.(\off); )

( ~pList.(); )


// =====================================================================
//  [6]  MIXER  -- ~setVol / ~mute / ~mixPreset
// =====================================================================
( ~setVol.(\kick, 1.0); )
( ~setVol.(\acid, 0.7); )
( ~setVol.(\melody, 0.5); )
( ~masterVol.(0.5); )         // multiplicateur global
( ~masterVol.(1.0); )         // retour normal
( ~masterFade.(0.3, 4); )     // fade master vers 0.3 en 4s
( ~masterFadeOut.(8); )       // fade out + stop Pdef

( ~mute.(\acid); )
( ~unmute.(\acid); )
( ~solo.(\melody); )
( ~unsolo.(); )
( ~mixReset.(); )

( ~mixPreset.(\drumsHeavy); )
( ~mixPreset.(\melodicLead); )
( ~mixPreset.(\acidFocus); )
( ~mixPreset.(\breakdown); )
( ~mixPreset.(\drop); )
( ~mixPreset.(\dub); )
( ~mixPreset.(\trance); )
( ~mixPreset.(\hardcore); )

( ~saveMix.(\verseA); )
( ~loadMix.(\verseA); )
( ~mixShow.(); )


// =====================================================================
//  [7]  SCENES  -- snapshot / recall
// =====================================================================
( ~saveScene.(\drop1); )
( ~saveScene.(\verseA); )
( ~saveScene.(\breakdown); )
( ~loadScene.(\drop1); )
( ~listScenes.(); )


// =====================================================================
//  [8]  JUMP  -- ~jumpTo dans n'importe quelle section
// =====================================================================
( ~jumpTo.('A', 'minimal_kick_t5_sub_melody_pad'); )
( ~jumpTo.('A', 'acid_rave_kick_t1_melody_lead_variations'); )
( ~jumpTo.('B', 'kick_4_4_acid_ouvre_kick_t1_melody_pluck'); )
( ~jumpTo.('E', 'drop_1_growl_dubstep'); )
( ~jumpTo.('F', 'trance_uplifter_138_bpm'); )
( ~jumpTo.('W', 'dub_techno_120_bpm'); )


// =====================================================================
//  [9]  STATUS / TEARDOWN
// =====================================================================
( ~check.(); )                // rapport detaille
( ~teardown.(); )             // arret propre + free


// =====================================================================
//  [10]  PLAY -- demarrer les sequenceurs
// =====================================================================
(
TempoClock.default.tempo = (~bpm ? 128) / 60;
~kickSteps    = (~kickSteps   ? (1!16));
~hatSteps     = (~hatSteps    ? (0!16));
~snareSteps   = (~snareSteps  ? (0!16));
~clapSteps    = (~clapSteps   ? (0!16));
~percSteps    = (~percSteps   ? (0!16));
~acidNotes    = (~acidNotes   ? (0!16));
~melodyNotes  = (~melodyNotes ? (0!32));
~harmonyNotes = (~harmonyNotes ? (0!32));
~reload.value;
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).play };
"=== PLAY ===".postln;
)


// --- STOP -- coupe les Pdef (garde l'engine) -------------------------
(
[\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
 \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
"=== STOP ===".postln;
)
