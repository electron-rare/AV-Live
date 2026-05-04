// =====================================================================
//  scenes.scd  --  Save / Recall scenes (snapshot etat global)
//
//  Capture l'etat des variables (~kickAmp, ~melodyNotes, ~melodyInst, etc.)
//  dans un dictionnaire. Recall = restaure tout + reload Pdef.
//
//  USAGE :
//    1. Cmd+Entree sur SETUP (charge les helpers)
//    2. Pendant qu'une track tourne, Cmd+Entree sur SAVE -> nom au choix
//    3. Plus tard, Cmd+Entree sur RECALL -> reapplique tout
// =====================================================================


// --- SETUP -- definit ~scenes (Dictionary global) + helpers --------
(
~scenes = ~scenes ?? { Dictionary.new };

// Liste des cles d'etat a snapshotter
~sceneKeys = [
    \bpm,
    \kickSteps, \kickAmp, \kickFreq, \kickPitchAmt, \kickDecay, \kickDrive, \kickClick,
    \hatSteps, \hatAmp,
    \snareSteps, \snareAmp, \snareFreq, \snareNoiseAmt, \snareDecay,
    \clapSteps, \clapAmp,
    \percSteps, \percAmp, \percInst, \tomFreq, \cowbellFreq,
    \acidNotes, \acidAccents, \acidSlides,
    \acidCutoff, \acidRq, \acidCutoffEnv, \acidDrive, \acidAmp,
    \melodyNotes, \melodyInst, \melodyBoost,
    \melodyCutoff, \melodyRq, \melodyAmp, \melodyDrive,
    \melodyAttack, \melodyRelease,
    \melodySawAmt, \melodyDetune,
    \melodyWobbleRate, \melodyWobbleDepth, \melodyWobbleShape, \melodySubAmt,
    \harmonyInst, \harmonyNotes, \harmonyAmp, \harmonyDur,
    \harmonyCutoff, \harmonyRq, \harmonyAttack, \harmonyDecay,
    \harmonySustain, \harmonyRelease, \harmonyDrive,
    \harmonySawAmt, \harmonyDetune,
    \acidScAmt, \leadScAmt, \kickScShape,
];

// Sauvegarde l'etat courant sous un nom
~saveScene = { |name|
    var scene = Dictionary.new;
    ~sceneKeys.do { |k|
        var val = currentEnvironment[k];
        if (val.notNil) { scene.put(k, val) };
    };
    scene.put(\bpm, TempoClock.default.tempo * 60);
    ~scenes.put(name, scene);
    ("[scene saved] " ++ name ++ " -- " ++ scene.size ++ " keys").postln;
};

// Recharge un scene par nom
~loadScene = { |name|
    var scene = ~scenes[name];
    if (scene.isNil) {
        ("!! scene '" ++ name ++ "' inexistante. Disponibles : " ++
            ~scenes.keys.asArray).postln;
    } {
        scene.keysValuesDo { |k, v|
            if (k == \bpm) {
                TempoClock.default.tempo = v / 60;
            } {
                currentEnvironment.put(k, v);
            };
        };
        ~reload.value;
        ("[scene loaded] " ++ name).postln;
    };
};

// Liste des scenes
~listScenes = {
    "=== SCENES ===".postln;
    if (~scenes.size == 0) {
        "  (aucune scene sauvegardee)".postln;
    } {
        ~scenes.keysValuesDo { |k, v|
            ("  " ++ k ++ " (" ++ v.size ++ " keys)").postln;
        };
    };
};

// Supprime un scene
~deleteScene = { |name|
    if (~scenes.includesKey(name)) {
        ~scenes.removeAt(name);
        ("[scene deleted] " ++ name).postln;
    } { ("scene '" ++ name ++ "' inexistante").postln };
};

// Sauvegarde toutes les scenes sur disque (en JSON-like)
~saveScenesToDisk = { |path|
    var p = path ?? { ~base ++ "scenes_saved.scd" };
    var f = File(p, "w");
    f.write("// Scenes sauvegardees " ++ Date.localtime.asString ++ "\n");
    f.write("(\n~scenes = ~scenes ?? { Dictionary.new };\n");
    ~scenes.keysValuesDo { |name, scene|
        f.write("~scenes.put('" ++ name ++ "', Dictionary[\n");
        scene.keysValuesDo { |k, v|
            f.write("    '" ++ k ++ "' -> " ++ v.asCompileString ++ ",\n");
        };
        f.write("]);\n");
    };
    f.write(")\n");
    f.close;
    ("[scenes saved to] " ++ p).postln;
};

// Recharge depuis disque
~loadScenesFromDisk = { |path|
    var p = path ?? { ~base ++ "scenes_saved.scd" };
    if (File.exists(p)) {
        p.load;
        ("[scenes loaded from] " ++ p).postln;
    } { ("Pas de fichier " ++ p).postln };
};

"=== ~saveScene / ~loadScene / ~listScenes / ~deleteScene prets ===".postln;
)


// =====================================================================
//  EXEMPLES D'USAGE -- Cmd+Entree pendant qu'une track tourne
// =====================================================================

// --- Sauvegarder l'etat courant -----------------------------------
( ~saveScene.(\drop1); )
( ~saveScene.(\verseA); )
( ~saveScene.(\breakdown); )
( ~saveScene.(\dropFinal); )
( ~saveScene.(\favorite); )

// --- Rappeler une scene -------------------------------------------
( ~loadScene.(\drop1); )
( ~loadScene.(\breakdown); )
( ~loadScene.(\favorite); )

// --- Lister scenes / supprimer ------------------------------------
( ~listScenes.value; )
( ~deleteScene.(\favorite); )

// --- Persistence sur disque ---------------------------------------
( ~saveScenesToDisk.value; )       // sauvegarde dans scenes_saved.scd
( ~loadScenesFromDisk.value; )     // recharge depuis scenes_saved.scd
