// Réception du pont Hantek → OSC → SC
// Lance d'abord ./hantek_to_osc.py dans un terminal
//
// Variables globales mises à jour à ~50 Hz :
//   ~hPk1, ~hRms1  (CH1 peak / RMS, 0..1)
//   ~hPk2, ~hRms2  (CH2 peak / RMS, 0..1)

(
~hPk1 = 0; ~hRms1 = 0; ~hPk2 = 0; ~hRms2 = 0;

OSCdef(\hantek, { |msg|
    ~hPk1  = msg[1]; ~hRms1 = msg[2];
    ~hPk2  = msg[3]; ~hRms2 = msg[4];
}, '/scope');

// Démo : un sinus dont la fréquence suit CH1, l'amplitude suit CH2
SynthDef(\hantekVoice, {
    Out.ar(0, SinOsc.ar(\freq.kr(220) * 2, 0, \amp.kr(0.1)).dup);
}).add;

s.waitForBoot {
    ~v = Synth(\hantekVoice);
    ~poll = Routine({
        loop {
            ~v.set(
                \freq, ~hPk1.linlin(0, 1, 80, 1200),
                \amp,  ~hRms2.linlin(0, 1, 0, 0.4)
            );
            0.02.wait;
        }
    }).play;
};

// Stop:  ~poll.stop; ~v.free;
)
