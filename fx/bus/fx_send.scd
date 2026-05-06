// =====================================================================
//  fx/bus/fx_send.scd  --  SynthDef \fxSend
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\fxSend, {
    arg srcBus = 0, dstBus, amount = 0.3;
    var sig = In.ar(srcBus, 2);
    Out.ar(dstBus, sig * amount);
}).add;
)
