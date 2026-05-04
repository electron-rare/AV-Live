// =====================================================================
//  live/melodies.scd  --  MELODIES LIVE (API ultra-courte)
//
//  ATTENTION SC -- noter la notation des appels :
//
//    NE MARCHE PAS  : ~m.short.(50)
//      -> SC passe l'event ~m comme 1er arg, et les vrais args sont
//         PERDUS (test empirique sur SC 3.14.1).
//
//    MARCHE BIEN    : ~m[\short].(50)              (notation indexee)
//                     ~mShort.(50)                 (variable env directe)
//                     ~mm.(50)                     (alias env direct)
//
//  ~m                              // dict catalogue
//  ~m[\short].(N)                  // applique m{N}    (32 pas, 1..78)
//  ~m[\long].(N)                   // applique ml{N}   (64 pas, 1..30)
//  ~m[\xlong].(N)                  // applique mxl{N}  (96 pas, 1..15)
//  ~m[\epic].(N)                   // applique mepic{N}(128 pas, 1..10)
//  ~m[\rnd][\short].() etc.
//  ~m[\gen].(\acid|\trance|...)    // random par genre
//  ~m[\nx].() / ~m[\pv].()         // next/prev
//  ~m[\inst].(\warmPad)            // change ~melodyInst + reload
//  ~m[\harm][\go].(\third)         // ~enableHarmony
//  ~m[\harm][\inst].(\warmPad)     // change ~harmonyInst
//  ~m[\amp] / [\cut] / [\drive] / [\off]
//  ~m[\list].()
//
//  RACCOURCIS env (API utilisateur primaire) :
//    ~mShort, ~mLong, ~mXlong, ~mEpic
//    ~mRnd, ~mRndLong, ~mRndXlong, ~mRndEpic
//    ~mGen, ~mNx, ~mPv
//    ~mInst, ~mHarm, ~mHarmInst
//    ~mAmp, ~mCut, ~mDrive, ~mOff
//    ~mList
//    ~mm  (= ~mShort, alias court)
//
//  EXEMPLES :
//    ~mm.(29)          // melodie acid m29
//    ~mLong.(15)       // melodie longue ml15
//    ~mGen.(\trance)   // random dans le genre trance
//    ~mHarm.(\third)   // ajoute la 2e voix en tierce
//    ~mNx.()           // melodie suivante
//
//  NOTE : noms reserves Object/Server (`s` = Server.default, `next`,
//  `prev`...) ne marcheraient pas comme cles d'Event SC pseudo-method.
//  Mais comme on N'UTILISE PAS la pseudo-method (~m.key.()), les noms
//  des cles dans ~m peuvent rester courts (\short, \long, \nx, \pv).
//  Les renommages c->cur etc. sont quand meme appliques pour clarte.
//
//  PREREQUIS : engine + palette/melodies/* + palette/harmonics/* charges.
// =====================================================================

(
~m = ();

// --- etat courant : kind + numero (pour ~m[\nx] / ~m[\pv]) ----------
~m[\cur] = ( kind: \short, n: 1 );

// --- helper interne ------------------------------------------------
~m[\apply] = { |kind, n|
    var prefix, max, key, notes;
    prefix = switch (kind,
        \short, "m",
        \long,  "ml",
        \xlong, "mxl",
        \epic,  "mepic",
        "m"
    );
    max = switch (kind, \short, 78, \long, 30, \xlong, 15, \epic, 10, 78);
    n = ((n - 1).mod(max)) + 1;
    key = (prefix ++ n).asSymbol;
    notes = currentEnvironment[key];
    if (notes.notNil and: { notes.isArray }) {
        ~melodyNotes = notes.copy;
        ~reload !? { ~reload.value };
        ~m[\cur] = ( kind: kind, n: n );
        ("[m." ++ kind ++ "] " ++ key).postln;
    } {
        ("[m] melodie " ++ key ++ " inconnue (charge palette/melodies ?)").postln;
    };
};

~m[\short] = { |n = 1| ~m[\apply].(\short, n) };
~m[\long]  = { |n = 1| ~m[\apply].(\long,  n) };
~m[\xlong] = { |n = 1| ~m[\apply].(\xlong, n) };
~m[\epic]  = { |n = 1| ~m[\apply].(\epic,  n) };

~m[\rnd] = ();
~m[\rnd][\short] = { ~m[\apply].(\short, 78.rand + 1) };
~m[\rnd][\long]  = { ~randomLong  !? { ~randomLong.()  }; ~m[\cur] = ( kind: \long,  n: 1 ) };
~m[\rnd][\xlong] = { ~randomXLong !? { ~randomXLong.() }; ~m[\cur] = ( kind: \xlong, n: 1 ) };
~m[\rnd][\epic]  = { ~randomEpic  !? { ~randomEpic.()  }; ~m[\cur] = ( kind: \epic,  n: 1 ) };
~m[\rnd][\value] = { ~m[\apply].(\short, 78.rand + 1) };

~m[\gen] = { |genre = \acid|
    ~melodyByGenre !? { ~melodyByGenre.(genre) };
};

~m[\nx] = { ~m[\apply].(~m[\cur][\kind], ~m[\cur][\n] + 1) };
~m[\pv] = { ~m[\apply].(~m[\cur][\kind], ~m[\cur][\n] - 1) };

~m[\inst] = { |inst = \lead|
    ~melodyInst = inst;
    ~reload !? { ~reload.value };
    ("[m.inst] ~melodyInst = " ++ inst).postln;
};

~m[\harm] = ();
~m[\harm][\go] = { |preset = \off|
    ~enableHarmony !? { ~enableHarmony.(preset) };
    ("[m.harm] " ++ preset).postln;
};
~m[\harm][\inst] = { |inst = \pad|
    ~harmonyInst = inst;
    ~reload !? { ~reload.value };
    ("[m.harm.inst] ~harmonyInst = " ++ inst).postln;
};

~m[\amp] = { |val = 0.16|
    ~melodyAmp = val.clip(0, 1);
    ~reload !? { ~reload.value };
    ("[m.amp] " ++ ~melodyAmp).postln;
};
~m[\cut] = { |hz = 2400|
    ~melodyCutoff = hz.clip(20, 20000);
    ~reload !? { ~reload.value };
    ("[m.cut] " ++ ~melodyCutoff ++ "Hz").postln;
};
~m[\drive] = { |val = 1.2|
    ~melodyDrive = val.max(0.1);
    ~reload !? { ~reload.value };
    ("[m.drive] " ++ ~melodyDrive).postln;
};
~m[\off] = {
    ~melodyAmp = 0;
    ~reload !? { ~reload.value };
    "[m.off] melody silencieuse".postln;
};

~m[\list] = {
    "=== ~m -- MELODIES ===".postln;
    ("  courant : " ++ ~m[\cur][\kind] ++ " #" ++ ~m[\cur][\n]).postln;
    "  ranges  : short 1..78 / long 1..30 / xlong 1..15 / epic 1..10".postln;
    if (~melodyBank.notNil) {
        "  genres  : ".post; ~melodyBank.keys.asArray.sort.postln;
    } { "  genres  : (~melodyBank non charge)".postln };
    "  USAGE   : ~mm.(29) | ~mLong.(15) | ~mGen.(\\trance) | ~mNx.()".postln;
};

// --- API utilisateur : variables d'env top-level --------------------
~mShort    = { |n = 1| ~m[\apply].(\short, n) };
~mLong     = { |n = 1| ~m[\apply].(\long,  n) };
~mXlong    = { |n = 1| ~m[\apply].(\xlong, n) };
~mEpic     = { |n = 1| ~m[\apply].(\epic,  n) };
~mRnd      = { ~m[\apply].(\short, 78.rand + 1) };
~mRndLong  = { ~randomLong  !? { ~randomLong.()  }; ~m[\cur] = ( kind: \long,  n: 1 ) };
~mRndXlong = { ~randomXLong !? { ~randomXLong.() }; ~m[\cur] = ( kind: \xlong, n: 1 ) };
~mRndEpic  = { ~randomEpic  !? { ~randomEpic.()  }; ~m[\cur] = ( kind: \epic,  n: 1 ) };
~mGen      = { |genre = \acid| ~melodyByGenre !? { ~melodyByGenre.(genre) } };
~mNx       = { ~m[\apply].(~m[\cur][\kind], ~m[\cur][\n] + 1) };
~mPv       = { ~m[\apply].(~m[\cur][\kind], ~m[\cur][\n] - 1) };
~mInst     = { |inst = \lead| ~m[\inst].(inst) };
~mHarm     = { |preset = \off| ~m[\harm][\go].(preset) };
~mHarmInst = { |inst = \pad|   ~m[\harm][\inst].(inst) };
~mAmp      = { |val = 0.16|    ~m[\amp].(val) };
~mCut      = { |hz = 2400|     ~m[\cut].(hz) };
~mDrive    = { |val = 1.2|     ~m[\drive].(val) };
~mOff      = { ~m[\off].() };
~mList     = { ~m[\list].() };
~mm        = { |n = 1| ~m[\apply].(\short, n) };  // alias court

"=== ~m pret -- ~mm.(29) | ~mLong.(15) | ~mGen.(\\trance) | ~mList.() ===".postln;
)



// =====================================================================
//  EXEMPLES (Cmd+Entree pour appliquer)
// =====================================================================

// --- short / long / xlong / epic par numero ---
// ( ~mm.(29); )                // m29 (acid classique)
// ( ~mm.(50); )                // m50
// ( ~mLong.(15); )             // ml15 (long 64 pas)
// ( ~mXlong.(5); )             // mxl5 (xlong 96 pas)
// ( ~mEpic.(1); )              // mepic1 (epic 128 pas)

// --- random ---
// ( ~mRnd.(); )                // short random
// ( ~mRndLong.(); )            // long random
// ( ~mRndXlong.(); )           // xlong random
// ( ~mRndEpic.(); )            // epic random

// --- random par genre ---
// ( ~mGen.(\acid); )
// ( ~mGen.(\trance); )
// ( ~mGen.(\dub); )
// ( ~mGen.(\detroit); )
// ( ~mGen.(\oriental); )

// --- navigation ---
// ( ~mNx.(); )                 // suivante
// ( ~mPv.(); )                 // precedente

// --- timbre / harmonie ---
 ( ~mInst.(\warmPad); )
 ( ~mInst.(\pluck); )
 ( ~mInst.(\stab); )
// ( ~mHarm.(\third); )         // tierce
 ( ~mHarm.(\fifth); )         // quinte
// ( ~mHarm.(\counter); )
// ( ~mHarm.(\off); )
// ( ~mHarmInst.(\warmPad); )

// --- reglages live ---
 ( ~mAmp.(0.2); )
 ( ~mCut.(1200); )
 ( ~mDrive.(2.0); )
 ( ~mOff.(); )                // mute melodie

// --- liste ---
// ( ~mList.(); )
