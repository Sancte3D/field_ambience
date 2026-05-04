// =====================================================================
// FIELD AMBIENCE v29-c
// Voice Leading + Crossfade + Air + Bass + Reverb Bus
// ---------------------------------------------------------------------
// Builds on v29-b:
//   + famAir:  sporadic high-register shimmer (sparse events)
//   + famBass: gentle root-of-chord support, low, soft, LPF'd
//   + Reverb bus: all voices send a share to a FreeVerb master
//   + ~verbSend parameter on each voice
// ---------------------------------------------------------------------
// Quick start:
//   1. Boot server   (s.boot)
//   2. Eval this file whole
//   3. Run           ~famStart.()
//   4. Open HTML panel as before
// =====================================================================

(
s.waitForBoot({

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// LAYER C -- Voice SynthDefs
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	// famCore: Stereo-FM voice, HiChord-inspired
	// v29-c: added verbOut + verbSend parameters for reverb bus routing
	SynthDef(\famCore, { |out = 0, verbOut = 0, verbSend = 0.15,
	                     freq = 440, amp = 0.25, decay = 3.0,
	                     modRatio = 3.5, modIndex = 2.5, pan = 0,
	                     detuneCents = 8, tremRate = 0.4, tremDepth = 0.08,
	                     delayTime = 0.28, delayFb = 0.35, delayMix = 0.25|
		var env, ampEnv, modEnv, mod1, mod2, car1, car2, sig, wet;
		var freqL, freqR;

		freqL = freq * (2 ** (detuneCents.neg / 1200));
		freqR = freq * (2 ** (detuneCents        / 1200));

		ampEnv = EnvGen.ar(
			Env.new([0, 1, 0], [0.015, decay], [2, -4]),
			doneAction: 2
		);
		modEnv = EnvGen.ar(
			Env.new([1, 0], [decay * 0.6], [-3])
		);
		env = SinOsc.kr(tremRate, 0, tremDepth, 1 - tremDepth);

		mod1 = SinOsc.ar(freqL * modRatio) * modEnv * modIndex * freqL;
		mod2 = SinOsc.ar(freqR * modRatio) * modEnv * modIndex * freqR;

		car1 = SinOsc.ar(freqL + mod1) * ampEnv * env;
		car2 = SinOsc.ar(freqR + mod2) * ampEnv * env;

		wet = CombC.ar(
			Mix.ar([car1, car2]) * 0.5,
			0.5, delayTime, delayTime * delayFb * 4
		);

		sig = [car1, car2] + (wet * delayMix);
		sig = sig * amp;
		sig = Balance2.ar(sig[0], sig[1], pan);

		Out.ar(out, sig);
		// v29-c: send a share to reverb bus
		Out.ar(verbOut, sig * verbSend);
	}).add;

	// famPad: Gate-controlled voice for HOLD/DRONE with crossfade.
	// v29-c: added verb send
	SynthDef(\famPad, { |out = 0, verbOut = 0, verbSend = 0.25,
	                    freq = 440, amp = 0.08, gate = 1,
	                    modRatio = 2.0, modIndex = 1.2, pan = 0,
	                    detuneCents = 10, attack = 1.5, release = 3.5,
	                    lfoRate = 0.23, lfoDepth = 0.12|
		var env, lfo, mod1, mod2, car1, car2, sig;
		var freqL, freqR;

		freqL = freq * (2 ** (detuneCents.neg / 1200));
		freqR = freq * (2 ** (detuneCents        / 1200));

		env = EnvGen.ar(
			Env.asr(attack, 1.0, release, [2, -4]),
			gate, doneAction: 2
		);
		lfo = SinOsc.kr(lfoRate, 0, lfoDepth, 1 - lfoDepth);

		mod1 = SinOsc.ar(freqL * modRatio) * modIndex * freqL;
		mod2 = SinOsc.ar(freqR * modRatio) * modIndex * freqR;

		car1 = SinOsc.ar(freqL + mod1) * env * lfo;
		car2 = SinOsc.ar(freqR + mod2) * env * lfo;

		sig = [car1, car2] * amp;
		sig = Balance2.ar(sig[0], sig[1], pan);

		Out.ar(out, sig);
		Out.ar(verbOut, sig * verbSend);
	}).add;

	// famAir: sporadic high-register shimmer. Sine with slow LFO, high-pass implicit by freq choice.
	// v29-c: triggered rarely (every 10-30s) for breathing glints.
	SynthDef(\famAir, { |out = 0, verbOut = 0, verbSend = 0.45,
	                    freq = 1760, amp = 0.04, decay = 4.5,
	                    pan = 0, detuneCents = 5, lfoRate = 0.15|
		var env, freqL, freqR, car1, car2, sig, wobble;

		freqL = freq * (2 ** (detuneCents.neg / 1200));
		freqR = freq * (2 ** (detuneCents        / 1200));

		// Long soft envelope, slow attack for shimmer-in-from-nowhere feel
		env = EnvGen.ar(
			Env.new([0, 1, 0], [0.8, decay], [2, -3]),
			doneAction: 2
		);

		// Very slow pitch wobble (0.15 Hz)
		wobble = SinOsc.kr(lfoRate, 0, 0.004, 1);

		car1 = SinOsc.ar(freqL * wobble) * env;
		car2 = SinOsc.ar(freqR * wobble) * env;

		sig = [car1, car2] * amp;
		sig = Balance2.ar(sig[0], sig[1], pan);

		Out.ar(out, sig);
		Out.ar(verbOut, sig * verbSend);
	}).add;

	// famBass: gentle root support. Low-pass filtered, soft.
	// v29-c: triggered on chord changes only. Not ego, just foundation.
	SynthDef(\famBass, { |out = 0, verbOut = 0, verbSend = 0.05,
	                     freq = 65, amp = 0.15, gate = 1,
	                     attack = 0.8, release = 2.5,
	                     lpCutoff = 450, lpRes = 0.3|
		var env, osc, sub, sig;

		env = EnvGen.ar(
			Env.asr(attack, 1.0, release, [2, -3]),
			gate, doneAction: 2
		);

		// Triangle + subtle sine sub, LPF'd
		osc = Mix.ar([
			LFTri.ar(freq) * 0.5,
			SinOsc.ar(freq * 0.5) * 0.3
		]);
		sig = RLPF.ar(osc, lpCutoff, lpRes);
		sig = sig * env * amp;
		// Mono out, centered (bass sits center always)
		sig = Pan2.ar(sig, 0);

		Out.ar(out, sig);
		Out.ar(verbOut, sig * verbSend);
	}).add;

	// famReverbMaster: runs on reverb bus, reads stereo input, applies FreeVerb, writes to main out.
	// v29-c: simple FreeVerb (vanilla SC, no sc3-plugins needed)
	SynthDef(\famReverbMaster, { |in = 0, out = 0,
	                              mix = 0.5, room = 0.68, damp = 0.4|
		var sig = In.ar(in, 2);
		sig = FreeVerb2.ar(sig[0], sig[1], mix, room, damp);
		Out.ar(out, sig);
	}).add;

	"famCore + famPad + famAir + famBass + famReverbMaster SynthDefs added.".postln;
	s.sync;

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// v29-c: Reverb bus + master synth
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	~famVerbBus = Bus.audio(s, 2);
	~famVerbSynth = nil;   // will be spawned in ~famStart

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// LAYER A -- Harmonic Brain
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	// Scale intervals from root (semitones). 7 church modes.
	~famScales = (
		ionian:     [0, 2, 4, 5, 7, 9, 11],   // major
		dorian:     [0, 2, 3, 5, 7, 9, 10],
		phrygian:   [0, 1, 3, 5, 7, 8, 10],
		lydian:     [0, 2, 4, 6, 7, 9, 11],
		mixolydian: [0, 2, 4, 5, 7, 9, 10],
		aeolian:    [0, 2, 3, 5, 7, 8, 10],   // natural minor
		locrian:    [0, 1, 3, 5, 6, 8, 10]
	);

	// Progression bank: degree sequences (1-indexed, 1 = tonic)
	~famProgressions = (
		\I_V_vi_IV:     [1, 5, 6, 4],
		\I_IV_V_I:      [1, 4, 5, 1],
		\i_VI_III_VII:  [1, 6, 3, 7],
		\i_iv_VI_V:     [1, 4, 6, 5]
	);
	~famProgKeys = [\I_V_vi_IV, \I_IV_V_I, \i_VI_III_VII, \i_iv_VI_V];

	// Harmonic Brain state
	~famKey           = 60;              // MIDI note of tonic (C4)
	~famMode          = \ionian;
	~famProg          = \I_V_vi_IV;
	~famProgAuto      = true;            // rotate progression every 8-16 bars
	~famProgStep      = 0;               // index into current progression
	~famBarLength     = 2;               // how many bars per chord
	~famBarCount      = 0;               // bars elapsed in current chord
	~famTotalBars     = 0;               // bars since start (for progression rotation)
	~famNextProgSwap  = rrand(8, 16);    // when to swap progression (if auto)

	// Get scale notes relative to a root MIDI note
	~famScaleNotes = { |rootMidi, modeKey, octaves = 2|
		var intervals = ~famScales[modeKey] ? ~famScales[\ionian];
		var notes = [];
		octaves.do { |oct|
			intervals.do { |iv|
				notes = notes.add(rootMidi + iv + (oct * 12));
			};
		};
		notes
	};

	// Build a chord on a given degree with EXTENSIONS (not just triad).
	// v29-a+ : inspired by HiChord. Defaults are maj9/min9/min11/6-9 style.
	// Returns MIDI notes. For a typical degree: [root, 3rd, 5th, 7th, 9th].
	~famChordAtDegree = { |rootMidi, modeKey, degree|
		var intervals = ~famScales[modeKey];
		var d = degree - 1;   // 0-indexed
		var pick = { |stepOffset|
			var idx = d + stepOffset;
			var wrap = idx.mod(7);
			var oct = (idx / 7).floor * 12;
			rootMidi + intervals[wrap] + oct
		};
		// Build a 5-note extended voicing: root, 3rd, 5th, 7th, 9th (scale-diatonic)
		// This is the key step that makes everything sound "big" instead of "plain triad".
		var r  = pick.(0);
		var t3 = pick.(2);
		var t5 = pick.(4);
		var t7 = pick.(6);
		var t9 = pick.(8);    // wraps one octave up -> real 9th
		[r, t3, t5, t7, t9]
	};

	// Triad-only version (for when we need just root/3rd/5th, e.g. bass picking)
	~famTriadAtDegree = { |rootMidi, modeKey, degree|
		var intervals = ~famScales[modeKey];
		var d = degree - 1;
		var pick = { |stepOffset|
			var idx = d + stepOffset;
			var wrap = idx.mod(7);
			var oct = (idx / 7).floor * 12;
			rootMidi + intervals[wrap] + oct
		};
		[pick.(0), pick.(2), pick.(4)]
	};

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// v29-b: VOICE LEADING
	// Inspired by HiChord's automatic voice leading.
	// When moving from one chord to another, pick the inversion of the
	// target chord that minimizes the total semitone movement of voices.
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	// Track the last-played chord for voice leading reference.
	~famLastVoicing = nil;   // array of MIDI notes as actually played last time
	~famVoiceCenter = 64;    // target center register for chords (C4 = 60, we aim slightly above)

	// Generate all candidate voicings of a chord:
	// all inversions × 3 octave shifts (−1, 0, +1 from base).
	~famChordCandidates = { |chordNotes|
		var cands = [];
		var size = chordNotes.size;
		// For each starting note (inversion), rebuild chord so that tone is lowest
		size.do { |startIdx|
			var inv = [];
			size.do { |i|
				var noteIdx = (startIdx + i).mod(size);
				var octShift = if((startIdx + i) >= size) { 12 } { 0 };
				inv = inv.add(chordNotes[noteIdx] + octShift);
			};
			// Try 3 octave placements
			[-12, 0, 12].do { |globalOct|
				cands = cands.add(inv.collect { |n| n + globalOct });
			};
		};
		cands
	};

	// Distance between two voicings: sum of pairwise semitone differences.
	// Uses the minimum-sum-pairing heuristic (for equal-size chords, direct match works well).
	~famVoicingDistance = { |v1, v2|
		var minSize = min(v1.size, v2.size);
		var total = 0;
		minSize.do { |i|
			total = total + (v1[i] - v2[i]).abs;
		};
		// Penalize voicings too far from center
		total = total + ((v2.mean - ~famVoiceCenter).abs * 0.3);
		total
	};

	// Main voice-leading function: given target chord (any voicing),
	// return the candidate voicing that is closest to the last played voicing.
	~famVoiceLead = { |targetChord|
		var candidates = ~famChordCandidates.(targetChord);
		var best, bestDist = 99999;
		if(~famLastVoicing.isNil) {
			// No previous voicing: pick the one closest to center
			candidates.do { |cand|
				var d = (cand.mean - ~famVoiceCenter).abs;
				if(d < bestDist) { bestDist = d; best = cand };
			};
		} {
			// Pick the one with smallest voice movement from last voicing
			candidates.do { |cand|
				var d = ~famVoicingDistance.(~famLastVoicing, cand);
				if(d < bestDist) { bestDist = d; best = cand };
			};
		};
		best ? targetChord
	};

	// Compute current chord based on brain state.
	// v29-b: voice-led -- returns the chord in the inversion closest to last play.
	// Also updates ~famLastVoicing so subsequent notes/motifs use this as reference.
	~famCurrentChord = {
		var prog = ~famProgressions[~famProg];
		var deg = prog[~famProgStep];
		var raw = ~famChordAtDegree.(~famKey, ~famMode, deg);
		var voiced = ~famVoiceLead.(raw);
		~famLastVoicing = voiced;   // remember for next call
		voiced
	};

	// Raw (non-voice-led) version when you need the chord in a known base form,
	// e.g. for display or analysis.
	~famCurrentChordRaw = {
		var prog = ~famProgressions[~famProg];
		var deg = prog[~famProgStep];
		~famChordAtDegree.(~famKey, ~famMode, deg)
	};

	// Compute allowed notes for phrases (chord tones + passing tones from scale)
	~famAllowedNotes = {
		var chord = ~famCurrentChord.();
		var scale = ~famScaleNotes.(~famKey, ~famMode, 2);
		chord ++ scale   // duplicates OK, chord tones will be preferred
	};

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// LAYER B -- Phrase Engine: Motifs + Mutations
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	// Motif = rhythm pattern + tonal shape.
	// v29-a+: Each motif returns a list of (noteIndex, duration, velocity).
	// Chord has 5 tones now: 0=root, 1=3rd, 2=5th, 3=7th, 4=9th.
	// Values >= 5 wrap one octave up (same tones, higher).
	~famMotifs = (
		\broken_up: {
			// Ascending triad, classic
			[[0, 0.5, 0.7], [1, 0.5, 0.65], [2, 0.5, 0.7]]
		},
		\broken_down: {
			[[2, 0.5, 0.7], [1, 0.5, 0.65], [0, 0.5, 0.75]]
		},
		\hopper: {
			[[0, 0.25, 0.7], [2, 0.25, 0.6], [1, 0.5, 0.75]]
		},
		\pulse_single: {
			[[0, 1.0, 0.8]]
		},
		\triplet: {
			[[0, 0.167, 0.7], [1, 0.167, 0.65], [2, 0.167, 0.7]]
		},
		\question: {
			[[1, 0.5, 0.75], [2, 0.5, 0.65]]
		},
		\answer: {
			[[2, 0.5, 0.7], [0, 0.5, 0.8]]
		},
		// v29-a+: Extension-aware motifs that use 9ths and 7ths
		\dreamy: {
			// Uses 9th (idx 4) for that HiChord-like sparkle
			[[4, 0.5, 0.6], [2, 0.5, 0.7], [0, 0.5, 0.75]]
		},
		\shimmering: {
			// Sus-like opening: root, 5th, 9th
			[[0, 0.33, 0.6], [2, 0.33, 0.6], [4, 0.66, 0.75]]
		},
		\cascade: {
			// Long descending arpeggio across all extensions
			[[4, 0.25, 0.5], [3, 0.25, 0.55], [2, 0.25, 0.6], [1, 0.25, 0.65], [0, 0.5, 0.7]]
		},
		\bell: {
			// Single tones with emphasis on chord color (7th, 9th)
			[[0, 0.75, 0.8], [4, 0.5, 0.5], [3, 0.5, 0.55]]
		},
		\rest: {
			[]   // silent motif
		}
	);
	~famMotifKeys = [\broken_up, \broken_down, \hopper, \pulse_single,
	                 \triplet, \question, \answer,
	                 \dreamy, \shimmering, \cascade, \bell, \rest];

	// Mutations: take a motif result and modify it
	~famMutations = (
		\identity:  { |m| m },
		\octave_up: { |m| m.collect { |n| [n[0] + 7, n[1], n[2]] } },   // shift note idx by ~octave
		\octave_down: { |m| m.collect { |n| [n[0] - 7, n[1], n[2]] } },
		\retrograde: { |m| m.reverse },
		\drop_first: { |m| if(m.size > 1) { m[1..] } { m } },
		\softer:    { |m| m.collect { |n| [n[0], n[1], n[2] * 0.7] } },
		\stretch:   { |m| m.collect { |n| [n[0], n[1] * 1.5, n[2]] } }
	);
	~famMutationKeys = [\identity, \octave_up, \octave_down, \retrograde,
	                    \drop_first, \softer, \stretch];

	// Pick a note value from chord tones using motif note index
	// v29-a+: Chord now has 5 tones (root, 3rd, 5th, 7th, 9th)
	// idx 0..4 picks chord tones, idx 5..9 same but one octave up, etc.
	~famPickNote = { |noteIdx, octaveShift = 0|
		var chord = ~famCurrentChord.();
		var chordSize = chord.size;   // 5 with extensions
		var base = noteIdx.mod(chordSize);
		var oct = (noteIdx / chordSize).floor;
		chord[base] + (oct * 12) + (octaveShift * 12)
	};

	// Play a motif with the current harmonic context
	~famPlayMotif = { |motifKey, mutationKey = \identity, baseOctave = 0, baseAmp = 1.0|
		var motif = ~famMotifs[motifKey].value;
		var mutated = ~famMutations[mutationKey].value(motif);
		var beatDur = 60 / ~famBPM;
		// v29-b: compute the voice-led chord ONCE at motif start, so all notes
		// within this motif use the same consistent voicing.
		var chord = ~famCurrentChord.();

		if(mutated.size > 0) {
			Task({
				var chordSize = chord.size;
				mutated.do { |noteSpec|
					var noteIdx = noteSpec[0];
					var dur = noteSpec[1];
					var vel = noteSpec[2] * baseAmp;
					var base = noteIdx.mod(chordSize);
					var oct = (noteIdx / chordSize).floor;
					var midi = chord[base] + (oct * 12) + (baseOctave * 12);
					var freq = midi.midicps;
					var modIdx = vel.linlin(0.3, 1.0, 1.5, 3.5);
					var decay = rrand(2.5, 4.5);

					Synth(\famCore, [
						\freq, freq,
						\amp, vel * 0.25,
						\decay, decay,
						\modIndex, modIdx,
						\pan, rrand(-0.15, 0.15),
						\verbOut, ~famVerbBus.index,
						\verbSend, 0.18
					]);

					(dur * beatDur).wait;
				};
			}).play;
		};
	};

	// Play a specific degree as a motif (triggered by note-cells from UI).
	// Degree can be 1..14 (above 7 wraps one octave up).
	// Always plays a motif based on the requested chord, regardless of progression.
	~famPlayDegree = { |degree, motifKey = \broken_up, mutationKey = \identity, octave = 0, amp = 1.0|
		// v29-b: Voice-led chord. Get raw chord, then pick inversion closest to last.
		var rawChord = ~famChordAtDegree.(~famKey, ~famMode, degree);
		var chord = ~famVoiceLead.(rawChord);
		var motif = ~famMotifs[motifKey].value;
		var mutated = ~famMutations[mutationKey].value(motif);
		var beatDur = 60 / ~famBPM;

		// Remember this voicing for next time
		~famLastVoicing = chord;

		if(mutated.size > 0) {
			Task({
				var chordSize = chord.size;
				mutated.do { |noteSpec|
					var noteIdx = noteSpec[0];
					var dur = noteSpec[1];
					var vel = noteSpec[2] * amp;
					var base = noteIdx.mod(chordSize);
					var oct  = (noteIdx / chordSize).floor;
					var midi = chord[base] + (oct * 12) + (octave * 12);
					var freq = midi.midicps;
					var modIdx = vel.linlin(0.3, 1.0, 1.5, 3.5);
					var decay = rrand(2.5, 4.5);

					Synth(\famCore, [
						\freq, freq,
						\amp, vel * 0.25,
						\decay, decay,
						\modIndex, modIdx,
						\pan, rrand(-0.15, 0.15),
						\verbOut, ~famVerbBus.index,
						\verbSend, 0.18
					]);
					(dur * beatDur).wait;
				};
			}).play;
		};
	};

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// AUTO-PLAY Task
	// Progression advances every BarLength bars.
	// Auto-plays motifs if ~famAutoPlay is true.
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	~famBPM       = 72;
	~famAutoPlay  = true;    // auto-generate motifs
	~famHold      = false;   // if true, progression pauses
	~famMood      = 0.5;     // 0..1, influences dens+vel+decay
	~famRunning   = false;
	~famBassEnabled = true;  // v29-c: bass support layer on by default
	~famEngineTask = nil;
	~famAutoMotifTask = nil;

	~famAdvanceProgression = {
		var prog;
		if(~famHold.not) {
			~famBarCount = ~famBarCount + 1;
			if(~famBarCount >= ~famBarLength) {
				~famBarCount = 0;
				prog = ~famProgressions[~famProg];
				~famProgStep = (~famProgStep + 1).mod(prog.size);
				~famTotalBars = ~famTotalBars + ~famBarLength;

				// Auto-swap progression every 8-16 bars
				if(~famProgAuto and: { ~famTotalBars >= ~famNextProgSwap }) {
					~famProg = ~famProgKeys.choose;
					~famTotalBars = 0;
					~famNextProgSwap = rrand(8, 16);
					~famProgStep = 0;
					("FAM progression -> " ++ ~famProg).postln;
				};

				("FAM bar: chord=" ++ prog[~famProgStep]
				 ++ " key=" ++ ~famKey ++ " mode=" ++ ~famMode).postln;
			};
		};
	};

	~famStart = {
		if(~famRunning.not) {
			~famRunning = true;

			// v29-c: spawn reverb master synth (tail so voices feed into it first)
			~famVerbSynth = Synth.tail(s, \famReverbMaster, [
				\in, ~famVerbBus.index,
				\out, 0,
				\mix, 0.5,
				\room, 0.72,
				\damp, 0.4
			]);

			// Bar-clock: ticks every bar (4 beats at current BPM)
			~famEngineTask = Task({
				loop {
					var barDur = (60 / ~famBPM) * 4;
					barDur.wait;
					~famAdvanceProgression.();
				};
			}).play;

			// Auto-motif task: plays motifs at phrase intervals
			~famAutoMotifTask = Task({
				loop {
					var pauseBeats, motifKey, mutationKey, oct, amp;
					var beatDur = 60 / ~famBPM;

					if(~famAutoPlay) {
						pauseBeats = rrand(2.0, 6.0) * (1.2 - ~famMood);
						(pauseBeats * beatDur).wait;

						if(0.2.coin.not) {
							motifKey = ~famMotifKeys.wchoose(
								[0.08, 0.06, 0.07, 0.05, 0.04, 0.05, 0.05,
								 0.14, 0.12, 0.10, 0.12, 0.12]
							);
							mutationKey = ~famMutationKeys.wchoose(
								[0.40, 0.10, 0.15, 0.05, 0.10, 0.10, 0.10]
							);
							oct = [-1, 0, 0, 0, 1].choose;
							amp = rrand(0.6, 1.0) * (0.5 + (~famMood * 0.5));
							~famPlayMotif.(motifKey, mutationKey, oct, amp);
						};
					} {
						beatDur.wait;
					};
				};
			}).play;

			// v29-c: Air task -- sporadic shimmer. Every 10-30 seconds one event.
			~famAirTask = Task({
				loop {
					var wait = rrand(10.0, 30.0) * (1.4 - ~famMood);   // more mood = more air
					wait.wait;
					if(~famRunning) {
						var scaleNotes = ~famScaleNotes.(~famKey, ~famMode, 1);
						// Pick high-register note: scale note + 2 octaves
						var noteMidi = scaleNotes.choose + 24;
						Synth(\famAir, [
							\freq, noteMidi.midicps,
							\verbOut, ~famVerbBus.index,
							\amp, rrand(0.025, 0.05) * (0.5 + (~famMood * 0.5)),
							\decay, rrand(3.5, 6.0),
							\pan, rrand(-0.6, 0.6),
							\verbSend, 0.55
						]);
					};
				};
			}).play;

			// v29-c: Bass task -- retriggers on bar changes (not per motif).
			// Uses ~famBassTrigger flag set by ~famAdvanceProgression.
			~famBassSynth = nil;
			~famBassTask = Task({
				loop {
					(60 / ~famBPM * 4).wait;   // wait one bar
					if(~famRunning and: { ~famBassEnabled }) {
						var rawChord = ~famCurrentChordRaw.();
						var bassMidi = rawChord[0] - 24;   // root, 2 octaves down
						// Release old bass synth, start new with attack
						if(~famBassSynth.notNil) { ~famBassSynth.release };
						~famBassSynth = Synth(\famBass, [
							\freq, bassMidi.midicps,
							\verbOut, ~famVerbBus.index,
							\amp, 0.12 * (0.6 + (~famMood * 0.4)),
							\gate, 1,
							\attack, 0.8,
							\release, 3.0,
							\lpCutoff, 450,
							\verbSend, 0.05
						]);
					};
				};
			}).play;

			"FAM started. Engine running (v29-c: Core + Pad + Air + Bass + Reverb).".postln;
			("  BPM=" ++ ~famBPM ++ "  Key=" ++ ~famKey
			 ++ "  Mode=" ++ ~famMode ++ "  Prog=" ++ ~famProg).postln;
		} {
			"FAM already running.".postln;
		};
	};

	~famStop = {
		~famRunning = false;
		if(~famEngineTask.notNil)    { ~famEngineTask.stop;    ~famEngineTask = nil };
		if(~famAutoMotifTask.notNil) { ~famAutoMotifTask.stop; ~famAutoMotifTask = nil };
		if(~famAirTask.notNil)       { ~famAirTask.stop;       ~famAirTask = nil };
		if(~famBassTask.notNil)      { ~famBassTask.stop;      ~famBassTask = nil };
		if(~famBassSynth.notNil)     { ~famBassSynth.release;  ~famBassSynth = nil };
		// Release held pad synths
		~famHeldSynths.do { |s| if(s.notNil) { s.release } };
		~famHeldSynths = [];
		// Stop reverb master
		if(~famVerbSynth.notNil) { ~famVerbSynth.free; ~famVerbSynth = nil };
		"FAM stopped.".postln;
	};

	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	// OSC Endpoints -- Interface for HTML Panel via Python Bridge
	// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	// Transport
	OSCdef(\famStart, { |msg| ~famStart.() }, "/fam/start");
	OSCdef(\famStop,  { |msg| ~famStop.()  }, "/fam/stop");
	OSCdef(\famAuto, { |msg|
		~famAutoPlay = (msg[1].asInteger > 0);
		("FAM autoplay: " ++ ~famAutoPlay).postln;
	}, "/fam/auto");

	// Note-Cells: trigger motif at a specific degree
	//   /fam/cell [degree, octave, amp]  (degree 1-7)
	OSCdef(\famCell, { |msg|
		var degree = msg[1].asInteger;
		var octave = (msg[2] ? 0).asInteger;
		var amp    = (msg[3] ? 1.0).asFloat;
		// Use a simple broken_up motif when cell is tapped
		~famPlayDegree.(degree, \broken_up, \identity, octave, amp);
		("FAM cell: degree=" ++ degree ++ " oct=" ++ octave).postln;
	}, "/fam/cell");

	// Cell-Hold: sustain a chord on degree with voice-leading and crossfade.
	// v29-b: New press of any cell fades out the previous held chord smoothly
	//        while the new voicing fades in using famPad synths.
	~famHeldSynths = [];    // array of currently-held famPad synths (for release)

	OSCdef(\famCellHold, { |msg|
		var degree = msg[1].asInteger;
		var on = (msg[2] ? 1).asInteger > 0;
		if(on) {
			// Release previous held synths (they'll fade out over their release time)
			~famHeldSynths.do { |s|
				if(s.notNil) { s.release };
			};
			~famHeldSynths = [];

			// Voice-led target chord
			{
				var rawChord = ~famChordAtDegree.(~famKey, ~famMode, degree);
				var chord = ~famVoiceLead.(rawChord);
				~famLastVoicing = chord;

				// Spawn a famPad synth per chord tone
				chord.do { |midi, i|
					var pan = (i - (chord.size / 2)) / (chord.size * 1.5);
					var synth = Synth(\famPad, [
						\freq,     midi.midicps,
						\amp,      0.08,
						\gate,     1,
						\pan,      pan,
						\modRatio, 2.0,
						\modIndex, 1.0 + 0.3.rand,
						\attack,   1.8,
						\release,  3.5,
						\verbOut,  ~famVerbBus.index,
						\verbSend, 0.28
					]);
					~famHeldSynths = ~famHeldSynths.add(synth);
				};
				("FAM hold: degree=" ++ degree ++ " chord=" ++ chord).postln;
			}.value;
		};
	}, "/fam/hold");

	// Cell-Hold release (when user lifts finger in HOLD mode).
	// v29-b: currently unused by panel; left as hook for future per-cell release.
	OSCdef(\famCellHoldOff, { |msg|
		~famHeldSynths.do { |s|
			if(s.notNil) { s.release };
		};
		~famHeldSynths = [];
	}, "/fam/holdoff");

	// Harmonic Brain controls
	OSCdef(\famKey, { |msg|
		~famKey = msg[1].asInteger.clip(36, 84);
		("FAM key: " ++ ~famKey).postln;
	}, "/fam/key");

	OSCdef(\famMode, { |msg|
		var idx = msg[1].asInteger.clip(0, 6);
		var modes = [\ionian, \dorian, \phrygian, \lydian,
		             \mixolydian, \aeolian, \locrian];
		~famMode = modes[idx];
		("FAM mode: " ++ ~famMode).postln;
	}, "/fam/mode");

	OSCdef(\famProg, { |msg|
		var idx = msg[1].asInteger;
		if(idx < 0) {
			~famProgAuto = true;
			("FAM progression: AUTO").postln;
		} {
			~famProgAuto = false;
			~famProg = ~famProgKeys[idx.clip(0, 3)];
			~famProgStep = 0;
			("FAM progression: " ++ ~famProg).postln;
		};
	}, "/fam/prog");

	OSCdef(\famTempo, { |msg|
		~famBPM = msg[1].asFloat.clip(40, 140);
		("FAM BPM: " ++ ~famBPM).postln;
	}, "/fam/tempo");

	OSCdef(\famMood, { |msg|
		~famMood = msg[1].asFloat.clip(0.0, 1.0);
	}, "/fam/mood");

	OSCdef(\famHoldFlag, { |msg|
		~famHold = (msg[1].asInteger > 0);
		("FAM hold: " ++ ~famHold).postln;
	}, "/fam/holdflag");

	// State-query endpoint: panel can poll current state
	OSCdef(\famQuery, { |msg|
		var prog = ~famProgressions[~famProg];
		var chord = ~famCurrentChord.();
		// Reply over OSC on /fam/state
		NetAddr("127.0.0.1", 57121).sendMsg("/fam/state",
			~famRunning.asInteger,
			~famAutoPlay.asInteger,
			~famKey,
			~famMode.asString,
			~famProg.asString,
			~famProgStep,
			prog[~famProgStep] ? 1,
			~famBPM,
			~famMood,
			~famHold.asInteger,
			chord[0] ? 0, chord[1] ? 0, chord[2] ? 0
		);
	}, "/fam/query");

	"".postln;
	"================================================================".postln;
	" FIELD AMBIENCE v29-c ready.".postln;
	"   + Voice Leading (smooth inversions between chord changes)".postln;
	"   + Extended voicings (R/3/5/7/9 as default)".postln;
	"   + Crossfade on HOLD mode (famPad gated synths)".postln;
	"   + famAir: sporadic high-register shimmer".postln;
	"   + famBass: gentle root support on bar changes".postln;
	"   + Reverb bus (FreeVerb) with per-voice send".postln;
	"".postln;
	"  ~famStart.()   to begin playing".postln;
	"  ~famStop.()    to stop".postln;
	"  ~famBassEnabled = false  to mute bass layer".postln;
	"".postln;
	" OSC port: 57120 (SC server)  Reply: 57121".postln;
	" Endpoints:  /fam/start  /fam/stop  /fam/auto".postln;
	"             /fam/cell  /fam/hold  /fam/holdoff  /fam/holdflag".postln;
	"             /fam/key   /fam/mode  /fam/prog".postln;
	"             /fam/tempo /fam/mood  /fam/query".postln;
	"================================================================".postln;
});
)
