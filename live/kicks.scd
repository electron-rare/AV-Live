// =====================================================================
//  live/kicks.scd  --  KICKS LIVE (API ultra-courte)
//
//  ATTENTION SC -- noter la notation des appels :
//
//    NE MARCHE PAS  : ~k.pat.(\amen)
//      -> SC passe l'event ~k comme 1er arg, et les vrais args sont
//         PERDUS (test empirique sur SC 3.14.1, cf Dictionary.sc:549).
//
//    MARCHE BIEN    : ~k[\pat].(\amen)         (notation indexee)
//                     ~kPat.(\amen)            (variable env directe)
//                     ~kk.(\techno)            (alias env direct)
//
//  ~k                               // dict : catalogue de toutes les
//                                   //         donnees + helpers
//  ~k[\pat].(\name|N)               // applique SEULEMENT un pattern
//  ~k[\tim].(\name|N)               // applique SEULEMENT un timbre
//  ~k[\go].(\name)                  // pattern + timbre + reload
//  ~k[\list].()                     // liste tout
//
//  RACCOURCIS env (API utilisateur primaire) :
//    ~kPat.(\amen)        | ~kTim.(\808)        | ~kk.(\techno) (combo)
//    ~kList.()
//
//  EXEMPLES :
//    ~kk.(\techno)        // 4/4 + rond
//    ~kk.(\gabber)        // dense + distordu
//    ~kPat.(\amen)        // juste le pattern amen-break
//    ~kTim.(\808)         // juste le timbre 808 boom
//    ~kPat.(7)            // pattern n°7
//
//  PREREQUIS : engine.scd evalue (defines ~kickSteps, ~kickFreq, etc.)
// =====================================================================

(
~k = ();

// --- 25 patterns kick (16 steps chacun) -----------------------------
~k[\patterns] = (
    \four:    [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ],
    \techno:  [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0 ],
    \gabber:  [ 1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0 ],
    \dembow:  [ 1,0,0,1, 0,0,1,0, 1,0,0,1, 0,0,1,0 ],
    \half:    [ 1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ],
    \break:   [ 1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0 ],
    \triplet: [ 1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,1 ],
    \minimal: [ 1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 ],
    \ghost:   [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0 ],
    \synco:   [ 1,0,1,0, 1,0,0,1, 1,0,1,0, 1,0,1,1 ],
    \dnb:     [ 1,0,0,1, 0,0,0,0, 0,0,1,0, 0,0,1,0 ],
    \amen:    [ 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 ],
    \dense:   [ 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1 ],
    \hardstyle:[1,0,0,0, 1,0,0,1, 1,0,0,0, 1,1,0,0 ],
    \trance:  [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,1 ],
    \house:   [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ],
    \electro: [ 1,0,0,1, 0,0,0,0, 1,0,0,0, 0,0,1,0 ],
    \triphop: [ 1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0 ],
    \jungle:  [ 1,0,0,1, 0,1,0,0, 1,0,0,1, 0,1,0,0 ],
    \dub:     [ 0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ],
    \afro:    [ 1,0,0,1, 0,1,0,0, 1,0,1,0, 0,1,0,0 ],
    \garage:  [ 1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0 ],
    \footwork:[ 1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0 ],
    \off:     (0 ! 16),
);

// --- 12 timbres kick (params SynthDef) ------------------------------
~k[\timbres] = (
    \rond:    (freq: 55, pitchAmt: 3.0, decay: 0.32, drive: 1.3, click: 0.2),
    \sub:     (freq: 42, pitchAmt: 2.0, decay: 0.50, drive: 1.0, click: 0.05),
    \punchy:  (freq: 65, pitchAmt: 4.0, decay: 0.18, drive: 1.8, click: 0.45),
    \distorded:(freq:60, pitchAmt: 5.0, decay: 0.28, drive: 3.5, click: 0.30),
    \click:   (freq: 70, pitchAmt: 2.5, decay: 0.10, drive: 1.0, click: 0.60),
    \boomy:   (freq: 50, pitchAmt: 6.0, decay: 0.40, drive: 1.5, click: 0.10),
    \clap:    (freq: 90, pitchAmt: 1.5, decay: 0.08, drive: 1.2, click: 0.50),
    \909:     (freq: 60, pitchAmt: 3.5, decay: 0.45, drive: 1.4, click: 0.15),
    \808:     (freq: 38, pitchAmt: 1.8, decay: 0.65, drive: 1.0, click: 0.05),
    \gabberT: (freq: 65, pitchAmt: 5.5, decay: 0.22, drive: 4.5, click: 0.50),
    \breakcore:(freq:80, pitchAmt: 2.0, decay: 0.06, drive: 2.5, click: 0.70),
    \dubT:    (freq: 40, pitchAmt: 1.5, decay: 0.80, drive: 1.0, click: 0.02),
);

// --- Combos pre-mappes (1 nom = pattern + timbre + reload) ----------
~k[\combos] = (
    \techno:    [\techno,    \rond],
    \gabber:    [\gabber,    \gabberT],
    \dub:       [\dub,       \dubT],
    \dubstep:   [\half,      \808],
    \trance:    [\trance,    \punchy],
    \hardstyle: [\hardstyle, \distorded],
    \dnb:       [\dnb,       \punchy],
    \amen:      [\amen,      \punchy],
    \jungle:    [\jungle,    \click],
    \house:     [\house,     \909],
    \electro:   [\electro,   \click],
    \detroit:   [\four,      \909],
    \minimal:   [\minimal,   \rond],
    \phonk:     [\half,      \808],
    \afro:      [\afro,      \rond],
    \garage:    [\garage,    \rond],
    \triphop:   [\triphop,   \boomy],
    \footwork:  [\footwork,  \punchy],
);

// --- Fonctions stockees dans le dict (appelees via ~k[\key].(args)) -
//  Signatures normales (PAS de `self`) -- jamais appelees en pseudo-
//  method (`.key`) sur l'event `~k`.

~k[\pat] = { |name|
    var p = if (name.isInteger) {
        ~k[\patterns].values[(name - 1).clip(0, ~k[\patterns].size - 1)];
    } { ~k[\patterns][name] };
    if (p.isNil) {
        ("[k] pattern '" ++ name ++ "' inconnu. Liste : " ++ ~k[\patterns].keys.asArray).postln;
    } {
        ~kickSteps = p.copy;
        ~reload.value;
        ("[k.pat] " ++ name).postln;
    };
};

~k[\tim] = { |name|
    var t = if (name.isInteger) {
        ~k[\timbres].values[(name - 1).clip(0, ~k[\timbres].size - 1)];
    } { ~k[\timbres][name] };
    if (t.isNil) {
        ("[k] timbre '" ++ name ++ "' inconnu. Liste : " ++ ~k[\timbres].keys.asArray).postln;
    } {
        ~kickFreq     = t[\freq];
        ~kickPitchAmt = t[\pitchAmt];
        ~kickDecay    = t[\decay];
        ~kickDrive    = t[\drive];
        ~kickClick    = t[\click];
        ~reload.value;
        ("[k.tim] " ++ name).postln;
    };
};

~k[\go] = { |name|
    var c = ~k[\combos][name];
    if (c.isNil) {
        ~k[\pat].(name);
    } {
        ~k[\pat].(c[0]);
        ~k[\tim].(c[1]);
        ("[k] combo " ++ name ++ " (" ++ c[0] ++ "+" ++ c[1] ++ ")").postln;
    };
};

~k[\list] = {
    "=== ~k -- KICKS ===".postln;
    "  combos : ".post; ~k[\combos].keys.asArray.sort.postln;
    "  patterns : ".post; ~k[\patterns].keys.asArray.sort.postln;
    "  timbres  : ".post; ~k[\timbres].keys.asArray.sort.postln;
    "  USAGE : ~kk.(\\techno) | ~kPat.(\\amen) | ~kTim.(\\808)".postln;
};

// --- API utilisateur : variables d'env top-level --------------------
//  Ces wrappers acceptent les vrais args correctement.
~kPat  = { |name| ~k[\pat].(name) };
~kTim  = { |name| ~k[\tim].(name) };
~kGo   = { |name| ~k[\go].(name) };
~kList = { ~k[\list].() };
~kk    = { |name| ~k[\go].(name) };   // alias court

"=== ~k pret -- ~kk.(\\techno) | ~kPat.(\\amen) | ~kTim.(\\808) | ~kList.() ===".postln;
)


// =====================================================================
//  EXEMPLES (Cmd+Entree pour appliquer)
// =====================================================================

--- combos prets ---
( ~kk.(\techno); )
( ~kk.(\gabber); )
( ~kk.(\dub); )
( ~kk.(\trance); )
( ~kk.(\amen); )
( ~kk.(\hardstyle); )
( ~kk.(\dnb); )
( ~kk.(\phonk); )
( ~kk.(\detroit); )

--- pattern seul ---
( ~kPat.(\amen); )
( ~kPat.(\dense); )
( ~kPat.(\off); )            // silence

--- timbre seul ---
( ~kTim.(\808); )
( ~kTim.(\909); )
( ~kTim.(\distorded); )

--- accès direct par index ---
( ~kPat.(7); )   // pattern n°7
( ~kTim.(3); )   // timbre n°3

--- liste tout ---
( ~kList.(); )
