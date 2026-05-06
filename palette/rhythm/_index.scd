// =====================================================================
//  palette/rhythm/_index.scd  --  Auto-glob loader recursif
//
//  Charge UNIQUEMENT les fichiers helpers/fonctions au boot :
//    - fills/    (~snareFill / ~tomFill : helpers, pas de mutation d'etat)
//    - sequences/ (~seqPlay / ~seqIntro / ~seqDrop / ... : helpers)
//
//  Les sous-dossiers drum_kits/, patterns_genre/, kicks/ et percussions/
//  contiennent des PRESETS INTERACTIFS (mutent ~kickSteps / ~hatSteps /...
//  + appellent ~reload). Les charger au boot serait destructif :
//  le dernier preset chargé ecraserait tous les patterns.
//  -> Ces dossiers sont evalues manuellement (Cmd+Entree dans l'IDE).
// =====================================================================
(
var dir = thisProcess.nowExecutingPath.dirname;
[ "fills", "sequences" ].do { |sub|
    PathName(dir +/+ sub).deepFiles
        .select { |f| f.extension == "scd" }
        .sort   { |a, b| a.fullPath < b.fullPath }
        .do     { |f| f.fullPath.load };
};
"=== palette/rhythm loaded (fills + sequences) ===".postln;
)
