s.boot;

(
s.waitForBoot({

    SynthDef(\stringQuartetVoice, {
        |out = 0, reverbBus = 0, freq = 440, amp = 0.1, gate = 1, velocity = 0.7,
        bowVel = 0.55, bowForce = 0.9, bowPos = 0.12,
        dwgC1 = 0.25, dwgC3 = 30, impZ = 0.55, fB = 2,
        supportAmp = 0.25, sineAmp = 0.12, subAmp = 0.0,
        detune = 0.004,
        attack = 0.08, decay = 0.12, sustain = 0.8, release = 0.6,
        lpf = 5000, hpf = 120, lpfKeyTrack = 0.4,
        bodyFreq = 2000, bodyRq = 0.35, bodyAmp = 0.6, bodyTilt = 0,
        vibSpeed = 5, vibDepth = 0.01, vibRand = 0.3, vibOnset = 0.25,
        bowNoise = 0.035, bowAttack = 0.045, bowNoiseFreq = 3200,
        bowBodyMix = 0.6, satDrive = 0.02, oscSpread = 0.15, pan = 0|

        var vel, pressure, env, signal, signalL, signalR, outGain;
        var vibDepthEnv, vibLFO, drift, micropitch, freqMod;
        var core1, core2, sine, sub, coreMono, coreDiff;
        var noise, noise1, noise2, attackNoise, attackEnv, noiseDirect, noiseThruBody;
        var lpfFinal, hpfVel, body1, body2, body3, bodyMix;
        var bodyTiltHi, bodyTiltLo, ampInstab, spread, stereo;

        vel = velocity.clip(0.01, 1);
        pressure = vel.linlin(0, 1, 0.60, 1.25);
        spread = oscSpread * vel.linlin(0, 1, 0.70, 1.15);

        vibDepthEnv = EnvGen.kr(Env([0, 0, 1], [vibOnset * 0.3, vibOnset * 0.7]));

        vibLFO = SinOsc.kr(
            vibSpeed * LFNoise1.kr(vibRand * 2).range(0.90, 1.10),
            0,
            vibDepth * vibDepthEnv * vel.linlin(0, 1, 0.50, 1.15),
            1
        );

        drift = LFNoise2.kr(0.22).range(0.999, 1.001);
        micropitch = LFNoise2.kr(0.6).range(-0.0004, 0.0004);
        freqMod = freq * vibLFO * drift * (1 + micropitch);

        core1 = DWGBowed.ar(
            freqMod,
            bowVel * vel.linlin(0, 1, 0.78, 1.12),
            bowForce * pressure,
            gate,
            bowPos,
            release,
            dwgC1,
            dwgC3,
            impZ,
            fB
        );

        core2 = DWGBowed.ar(
            freqMod * (1 + detune),
            bowVel * 0.86,
            bowForce * pressure * 0.75,
            gate,
            bowPos * 1.12,
            release,
            dwgC1,
            dwgC3 * 1.08,
            impZ,
            fB
        ) * supportAmp;

        sine = SinOsc.ar(freqMod) * sineAmp * vel.linlin(0, 1, 1.12, 0.88);
        sub = SinOsc.ar(freqMod * 0.5) * subAmp;

        coreMono = core1 + core2 + sine + sub;
        coreDiff = (core1 - core2) * spread;

        noise1 = BPF.ar(WhiteNoise.ar(1), bowNoiseFreq + (freq * 0.30), 0.45);
        noise2 = BPF.ar(WhiteNoise.ar(1), (bowNoiseFreq * 0.28) + (freq * 0.25), 0.70);

        noise = ((noise1 * 0.42) + (noise2 * 0.58))
        * bowNoise
        * pressure
        * LFNoise2.kr(2.0).range(0.75, 1.15);

        attackEnv = EnvGen.kr(Env.perc(0.010, 0.18));
        attackNoise = BPF.ar(WhiteNoise.ar(1), (bowNoiseFreq * 0.8) + (freq * 0.35), 0.40);
        attackNoise = attackNoise * bowAttack * vel * attackEnv;

        noiseDirect = (noise + attackNoise) * (1 - bowBodyMix);
        noiseThruBody = (noise + attackNoise) * bowBodyMix;

        signal = coreMono + noiseDirect;

        hpfVel = hpf * vel.linlin(0, 1, 1.10, 0.70);
        signal = HPF.ar(signal, hpfVel);

        lpfFinal = lpf * vel.linlin(0, 1, 0.10, 0.60);
        lpfFinal = lpfFinal * (freq / 261.63).pow(lpfKeyTrack);
        lpfFinal = lpfFinal.clip(80, 16000);

        signal = LPF.ar(signal, lpfFinal);

        bodyTiltHi = bodyTilt.linlin(-1, 1, 0.30, 1.50);
        bodyTiltLo = bodyTilt.linlin(-1, 1, 1.50, 0.30);

        body1 = Resonz.ar(signal + noiseThruBody, bodyFreq, bodyRq) * bodyTiltHi;
        body2 = Resonz.ar(signal + noiseThruBody, bodyFreq * 0.22, bodyRq * 1.3) * 0.65;
        body3 = Resonz.ar(signal + noiseThruBody, bodyFreq * 0.11, bodyRq * 1.7) * 0.45 * bodyTiltLo;

        bodyMix = (body1 + body2 + body3) * bodyAmp * pressure;
        signal = signal + bodyMix;

        ampInstab = LFNoise2.kr(2.5).range(0.97, 1.03);
        signal = signal * ampInstab;

        env = EnvGen.kr(
            Env.adsr(
                attack * vel.linlin(0, 1, 1.40, 0.60),
                decay,
                sustain,
                release * vel.linlin(0, 1, 1.00, 0.30)
            ),
            gate,
            doneAction: 2
        );

        signal = signal * env;
        signal = (signal * (1 + (satDrive * vel * 0.8))).tanh;

        outGain = amp * vel.linlin(0, 1, 0.4, 0.90);
        signal = LeakDC.ar(signal) * outGain;
        signal = LPF.ar(signal, 12000);
        signal = Limiter.ar(signal, 0.95);

        coreDiff = coreDiff * env * outGain;
        signalL = signal + coreDiff;
        signalR = signal - coreDiff;

        stereo = Balance2.ar(signalL, signalR, pan);

        Out.ar(out, stereo);
        Out.ar(reverbBus, stereo * 0.35);
    }).add;


    SynthDef(\masterReverb, {
        |inBus = 0, out = 0, mix = 0.35, room = 0.92, damp = 0.35|

        var input, wet;

        input = In.ar(inBus, 2);

        wet = FreeVerb2.ar(
            input[0],
            input[1],
            mix,
            room,
            damp
        );

        Out.ar(out, wet);
    }).add;


    s.sync;


    ~reverbBus = Bus.audio(s, 2);

    ~reverbSynth = Synth(
        \masterReverb,
        [
            \inBus, ~reverbBus,
            \mix, 0.35,
            \room, 0.92,
            \damp, 0.35
        ]
    );


    ~stringPresets = (
        violin1: (
            bowVel: 1.00, bowForce: 0.70, bowPos: 0.08,
            dwgC1: 0.22, dwgC3: 34, impZ: 0.55, fB: 2.0,
            supportAmp: 0.20, sineAmp: 0.09, subAmp: 0.0,
            detune: 0.003,
            attack: 0.060, decay: 0.10, sustain: 0.86, release: 0.48,
            lpf: 4800, hpf: 130, lpfKeyTrack: 0.30,
            bodyFreq: 3000, bodyRq: 0.24, bodyAmp: 0.45, bodyTilt: 0.40,
            vibSpeed: 5.5, vibDepth: 0.0095, vibRand: 0.35, vibOnset: 0.24,
            bowNoise: 0.030, bowAttack: 0.040, bowNoiseFreq: 3900,
            bowBodyMix: 0.60,
            satDrive: 0.008,
            oscSpread: 0.16,
            pan: -0.40
        ),

        violin2: (
            bowVel: 0.80, bowForce: 0.78, bowPos: 0.10,
            dwgC1: 0.25, dwgC3: 29, impZ: 0.58, fB: 2.0,
            supportAmp: 0.22, sineAmp: 0.12, subAmp: 0.0,
            detune: 0.004,
            attack: 0.080, decay: 0.13, sustain: 0.80, release: 0.65,
            lpf: 4000, hpf: 100, lpfKeyTrack: 0.32,
            bodyFreq: 2500, bodyRq: 0.28, bodyAmp: 0.55, bodyTilt: 0.30,
            vibSpeed: 5.0, vibDepth: 0.01, vibRand: 0.35, vibOnset: 0.30,
            bowNoise: 0.04, bowAttack: 0.050, bowNoiseFreq: 3400,
            bowBodyMix: 0.65,
            satDrive: 0.012,
            oscSpread: 0.14,
            pan: -0.30
        ),

        viola: (
            bowVel: 0.50, bowForce: 0.88, bowPos: 0.13,
            dwgC1: 0.32, dwgC3: 21, impZ: 0.68, fB: 2.2,
            supportAmp: 0.26, sineAmp: 0.20, subAmp: 0.03,
            detune: 0.006,
            attack: 0.125, decay: 0.18, sustain: 0.72, release: 1.00,
            lpf: 3000, hpf: 70, lpfKeyTrack: 0.42,
            bodyFreq: 1050, bodyRq: 0.42, bodyAmp: 0.90, bodyTilt: -0.55,
            vibSpeed: 4.5, vibDepth: 0.0115, vibRand: 0.42, vibOnset: 0.36,
            bowNoise: 0.05, bowAttack: 0.060, bowNoiseFreq: 2800,
            bowBodyMix: 0.72,
            satDrive: 0.016,
            oscSpread: 0.09,
            pan: 0.15
        ),

        cello: (
            bowVel: 0.40, bowForce: 1.05, bowPos: 0.16,
            dwgC1: 0.42, dwgC3: 14, impZ: 0.82, fB: 2.5,
            supportAmp: 0.28, sineAmp: 0.28, subAmp: 0.18,
            detune: 0.0065,
            attack: 0.200, decay: 0.26, sustain: 0.62, release: 1.40,
            lpf: 2100, hpf: 40, lpfKeyTrack: 0.50,
            bodyFreq: 420, bodyRq: 0.55, bodyAmp: 1.75, bodyTilt: -0.90,
            vibSpeed: 3.8, vibDepth: 0.0145, vibRand: 0.50, vibOnset: 0.44,
            bowNoise: 0.052, bowAttack: 0.070, bowNoiseFreq: 2200,
            bowBodyMix: 0.78,
            satDrive: 0.020,
            oscSpread: 0.045,
            pan: 0.40
        )
    );


    ~webNotes = Dictionary.new;
    ~midiNotes = Dictionary.new;

    ~instrumentOrder = [\violin1, \violin2, \viola, \cello];
    ~midiInstrument = \violin1;

    ~webControls = (
        amp: 0.15,
        velocity: 0.8,

        bowForce: 1.0,
        bowVel: 0.7,
        vibDepth: 0.01,
        lpf: 4500,

        bowNoise: 0.04,
        bowNoiseFreq: 3200,
        satDrive: 0.02,
        oscSpread: 0.12,

        reverbMix: 0.35,
        reverbRoom: 0.92,
        reverbDamp: 0.35
    );


    ~makeStringSynth = { |note, velocity, amp, instrument, noteKey, dict|
        var freq, synth, preset, args;

        freq = note.midicps;

        preset = ~stringPresets[instrument].copy;

        preset[\bowForce] = ~webControls[\bowForce];
        preset[\bowVel] = ~webControls[\bowVel];
        preset[\vibDepth] = ~webControls[\vibDepth];
        preset[\lpf] = ~webControls[\lpf];

        preset[\bowNoise] = ~webControls[\bowNoise];
        preset[\bowNoiseFreq] = ~webControls[\bowNoiseFreq];
        preset[\satDrive] = ~webControls[\satDrive];
        preset[\oscSpread] = ~webControls[\oscSpread];

        args = [];

        preset.keysValuesDo { |key, value|
            args = args.add(key).add(value);
        };

        args = args ++ [
            \freq, freq,
            \amp, amp,
            \velocity, velocity,
            \reverbBus, ~reverbBus
        ];

        synth = Synth(\stringQuartetVoice, args);
        dict[noteKey] = synth;

        synth;
    };


    MIDIClient.init;
    MIDIIn.connectAll;

    MIDIFunc.noteOn({ |vel, note, chan, src|
        var velocity, amp, instrument, noteKey, oldSynth;

        velocity = (vel / 127).clip(0.01, 1);
        amp = 0.10 + (velocity * 0.18);
        instrument = ~midiInstrument;

        noteKey = "midi_" ++ note.asString;

        oldSynth = ~midiNotes[noteKey];
        if(oldSynth.notNil) {
            oldSynth.set(\gate, 0);
            ~midiNotes.removeAt(noteKey);
        };

        ~makeStringSynth.value(note, velocity, amp, instrument, noteKey, ~midiNotes);

        ("MIDI NOTE STARTED: " ++ noteKey ++ " | " ++ instrument ++ " | velocity: " ++ velocity).postln;

    });

    MIDIFunc.noteOff({ |vel, note, chan, src|
        var noteKey, synth;

        noteKey = "midi_" ++ note.asString;
        synth = ~midiNotes[noteKey];

        if(synth.notNil) {
            synth.set(\gate, 0);
            ~midiNotes.removeAt(noteKey);
            ("MIDI NOTE STOPPED: " ++ noteKey).postln;
        };

    });


    OSCdef(\control, { |msg|
        var name, value;

        name = msg[1].asSymbol;
        value = msg[2];

        if(name == \midiInstrument) {
            ~midiInstrument = ~instrumentOrder[value.asInteger.clip(0, 3)];
            ("MIDI INSTRUMENT SET TO: " ++ ~midiInstrument).postln;
        } {
            ~webControls[name] = value;

            if(name == \reverbMix) {
                ~reverbSynth.set(\mix, value);
            } {
                if(name == \reverbRoom) {
                    ~reverbSynth.set(\room, value);
                } {
                    if(name == \reverbDamp) {
                        ~reverbSynth.set(\damp, value);
                    } {
                        ~webNotes.keysValuesDo { |key, synth|
                            synth.set(name, value);
                        };

                        ~midiNotes.keysValuesDo { |key, synth|
                            synth.set(name, value);
                        };
                    };
                };
            };

            ("CONTROL RECEIVED: " ++ name ++ " = " ++ value ++ " | active web notes: " ++ ~webNotes.size ++ " | active midi notes: " ++ ~midiNotes.size).postln;
        };

    }, '/control');


    OSCdef(\playNote, { |msg|
        var note, velocity, amp, instrument, noteKey;

        note = msg[1];
        velocity = msg[2];
        amp = msg[3];
        instrument = msg[4].asSymbol;

        noteKey = instrument.asString ++ "_" ++ note.asString;

        ~makeStringSynth.value(note, velocity, amp, instrument, noteKey, ~webNotes);

        ("NOTE STARTED: " ++ noteKey ++ " | active notes: " ++ ~webNotes.size).postln;

    }, '/playNote');


    OSCdef(\stopNote, { |msg|
        var note, instrument, noteKey, synth;

        note = msg[1];
        instrument = msg[2].asSymbol;

        noteKey = instrument.asString ++ "_" ++ note.asString;

        synth = ~webNotes[noteKey];

        if(synth.notNil) {
            synth.set(\gate, 0);
            ~webNotes.removeAt(noteKey);
            ("NOTE STOPPED: " ++ noteKey ++ " | active notes: " ++ ~webNotes.size).postln;
        } {
            ("NOTE NOT FOUND: " ++ noteKey).postln;
        };

    }, '/stopNote');


    CmdPeriod.doOnce({
        ~webNotes.clear;
        ~midiNotes.clear;
        "Stopped all web and MIDI notes.".postln;
    });


    "String quartet engine loaded and ready with MIDI support.".postln;
});
)