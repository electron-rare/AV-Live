// =====================================================================
//  e2e_03_reload_guards.scd
//  Verifie les guards ajoutes a ~reload (engine.scd:498-516) :
//  Quand ~kickSteps / ~melodyNotes / etc. sont nil ou vides, ~reload
//  doit auto-defaulter sans planter (Pseq sur nil/empty plante sinon).
// =====================================================================

"=== e2e_03_reload_guards ===".postln;

~base = "/Users/electron/Documents/Projets_Creatifs/sound_algo-refonte-v2/";
~testCount = 0;
~testFailed = 0;

~assert = { |label, cond, info|
    ~testCount = ~testCount + 1;
    if (cond) {
        ("  [OK] " ++ label).postln;
    } {
        ~testFailed = ~testFailed + 1;
        ("  [FAIL] " ++ label ++ if (info.notNil) { " : " ++ info } { "" }).postln;
    };
};

~report = {
    ("== " ++ ~testCount ++ " tests, " ++ ~testFailed ++ " failed ==").postln;
    if (~testFailed > 0) { 1.exit } { 0.exit };
};

~runReload = {
    var crashed = false, msg = nil;
    try { ~reload.value } { |e| crashed = true; msg = e.errorString };
    [crashed, msg];
};

s = Server.internal;
s.waitForBoot({
    Routine({
        var r;
        s.sync;
        try { (~base ++ "engine.scd").load } { |e| ("engine err: " ++ e.errorString).postln };
        2.wait;
        s.sync;

        ~assert.("~reload defini", ~reload.notNil);

        // --- Test 1 : nil ---
        ~kickSteps    = nil; ~hatSteps     = nil;
        ~snareSteps   = nil; ~clapSteps    = nil;
        ~percSteps    = nil; ~acidNotes    = nil;
        ~acidAccents  = nil; ~acidSlides   = nil;
        ~melodyNotes  = nil; ~harmonyNotes = nil;

        r = ~runReload.value;
        ~assert.("~reload survive a nil", r[0].not, r[1]);
        ~assert.("~kickSteps default apres reload",    ~kickSteps.notNil    and: { ~kickSteps.size > 0 });
        ~assert.("~melodyNotes default apres reload",  ~melodyNotes.notNil  and: { ~melodyNotes.size > 0 });
        ~assert.("~harmonyNotes default apres reload", ~harmonyNotes.notNil and: { ~harmonyNotes.size > 0 });
        ~assert.("~acidNotes default apres reload",    ~acidNotes.notNil    and: { ~acidNotes.size > 0 });

        // --- Test 2 : empty array ---
        ~kickSteps   = [];
        ~melodyNotes = [];
        ~acidNotes   = [];
        r = ~runReload.value;
        ~assert.("~reload survive a [] ", r[0].not, r[1]);
        ~assert.("~kickSteps refilled apres []",   ~kickSteps.size > 0);
        ~assert.("~melodyNotes refilled apres []", ~melodyNotes.size > 0);
        ~assert.("~acidNotes refilled apres []",   ~acidNotes.size > 0);

        ~report.value;
    }).play;
}, 15, { "boot timeout".postln; 1.exit });
