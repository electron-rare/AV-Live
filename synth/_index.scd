// =====================================================================
//  synth/_index.scd  --  Auto-glob loader pour tous les SynthDef
//
//  Charge recursivement chaque .scd des sous-dossiers (drums/, bass/,
//  lead/, pad/, world/, master/). Ajouter un nouveau Synth = juste
//  creer le fichier, pas besoin de modifier ce loader.
// =====================================================================
(
PathName(thisProcess.nowExecutingPath.dirname).deepFiles
    .select { |f| f.extension == "scd"
            and: { f.fileName != "_index.scd" } }
    .sort   { |a, b| a.fullPath < b.fullPath }
    .do     { |f| f.fullPath.load };
"=== synth/ loaded ===".postln;
)
