const socket = io();

const instruments = [
  { id: "violin1", name: "Violin 1" },
  { id: "violin2", name: "Violin 2" },
  { id: "viola", name: "Viola" },
  { id: "cello", name: "Cello" }
];

let instrumentIndex = 0;
let currentInstrument = instruments[instrumentIndex].id;
let octaveShift = 0;

let macros = {
  x: 0.5,
  y: 0.5,
  space: 0.35
};

let targetX = macros.x;
let targetY = macros.y;
let targetSpace = macros.space;

const activeNotes = {};
const mouseNotes = {};
const midiNotes = {};

const keyMap = {
  a: 60, w: 61, s: 62, e: 63, d: 64,
  f: 65, t: 66, g: 67, y: 68, h: 69,
  u: 70, j: 71, k: 72
};

function updateInstrumentUI() {
  const inst = instruments[instrumentIndex];
  currentInstrument = inst.id;
  document.body.dataset.instrument = inst.id;
  document.getElementById("currentInstrument").innerText = inst.name;
}

function switchInstrument(direction) {
  const heldKeys = Object.keys(activeNotes);

  stopAllActiveNotes();

  instrumentIndex =
    (instrumentIndex + direction + instruments.length) % instruments.length;

  updateInstrumentUI();

  heldKeys.forEach((key) => {
    playNoteForKey(key);
  });
}

function nextInstrument() {
  switchInstrument(1);
}

function previousInstrument() {
  switchInstrument(-1);
}

function sendControl(name, value) {
  socket.emit("control", { name, value });
}

function sendMacroControls() {
  const aggressive = macros.x;
  const bright = macros.y;
  const space = macros.space;

  const brightCurve = Math.pow(bright, 1.45);
  const spaceCurve = Math.pow(space, 0.75);

  const bowForce = 0.45 + aggressive * 0.65;
  const bowVel = 0.55 + aggressive * 0.42;
  const bowNoise = 0.015 + aggressive * 0.075;
  const satDrive = 0.003 + aggressive * 0.040;
  const vibDepth = 0.002 + aggressive * 0.014;

  const lpf = 2200 + brightCurve * 5000;
  const bowNoiseFreq = 1000 + brightCurve * 4200;
  const oscSpread = 0.04 + brightCurve * 0.14;

  const amp = 0.16 + brightCurve * 0.06;
  const velocity = 0.38 + brightCurve * 0.48;

  const reverbMix = 0.30 + spaceCurve * 0.70;
  const reverbRoom = 0.45 + spaceCurve * 0.52;
  const reverbDamp = 0.60 - spaceCurve * 0.35;

  sendControl("bowForce", bowForce);
  sendControl("bowVel", bowVel);
  sendControl("bowNoise", bowNoise);
  sendControl("satDrive", satDrive);
  sendControl("vibDepth", vibDepth);

  sendControl("lpf", lpf);
  sendControl("bowNoiseFreq", bowNoiseFreq);
  sendControl("oscSpread", oscSpread);

  sendControl("amp", amp);
  sendControl("velocity", velocity);

  sendControl("reverbMix", reverbMix);
  sendControl("reverbRoom", reverbRoom);
  sendControl("reverbDamp", reverbDamp);
}

const xyPad = document.getElementById("xyPad");
const xyDot = document.getElementById("xyDot");
const spaceHalo = document.getElementById("spaceHalo");
const spaceGlow = document.querySelector(".spaceGlow");
const spaceInnerRing = document.getElementById("spaceInnerRing");

function updateVisuals() {
  xyDot.style.left = macros.x * 100 + "%";
  xyDot.style.top = (1 - macros.y) * 100 + "%";

  spaceHalo.style.left = macros.x * 100 + "%";
  spaceHalo.style.top = (1 - macros.y) * 100 + "%";

  const value = macros.space;

  spaceGlow.style.opacity = 0.18 + value * 0.58;
  spaceGlow.style.transform = `scale(${0.75 + value * 1.45})`;

  spaceInnerRing.style.transform = `scale(${0.65 + value * 0.55})`;
  spaceInnerRing.style.opacity = 0.35 + value * 0.65;
}

let xyAnimationFrame = null;
let spaceAnimationFrame = null;

function smoothXYUpdate() {
  macros.x += (targetX - macros.x) * 0.22;
  macros.y += (targetY - macros.y) * 0.22;

  if (
    Math.abs(targetX - macros.x) < 0.001 &&
    Math.abs(targetY - macros.y) < 0.001
  ) {
    macros.x = targetX;
    macros.y = targetY;
    xyAnimationFrame = null;

    updateVisuals();
    sendMacroControls();
    return;
  } else {
    xyAnimationFrame = requestAnimationFrame(smoothXYUpdate);
  }

  updateVisuals();
  sendMacroControls();
}

function smoothSpaceUpdate() {
  macros.space += (targetSpace - macros.space) * 0.18;

  if (Math.abs(targetSpace - macros.space) < 0.001) {
    macros.space = targetSpace;
    spaceAnimationFrame = null;

    updateVisuals();
    sendMacroControls();
    return;
  } else {
    spaceAnimationFrame = requestAnimationFrame(smoothSpaceUpdate);
  }

  updateVisuals();
  sendMacroControls();
}

function updateXY(event) {
  const rect = xyPad.getBoundingClientRect();

  let x = (event.clientX - rect.left) / rect.width;
  let y = (event.clientY - rect.top) / rect.height;

  x = Math.max(0, Math.min(1, x));
  y = Math.max(0, Math.min(1, y));

  targetX = x;
  targetY = 1 - y;

  if (!xyAnimationFrame) {
    xyAnimationFrame = requestAnimationFrame(smoothXYUpdate);
  }
}

let draggingXY = false;

xyPad.addEventListener("mousedown", (event) => {
  draggingXY = true;
  updateXY(event);
});

document.addEventListener("mousemove", (event) => {
  if (draggingXY) updateXY(event);
});

document.addEventListener("mouseup", () => {
  draggingXY = false;
});

xyPad.addEventListener("wheel", (event) => {
  event.preventDefault();

  const delta = Math.sign(event.deltaY) * Math.min(Math.abs(event.deltaY), 40);

  targetSpace -= delta * 0.0009;
  targetSpace = Math.max(0, Math.min(1, targetSpace));

  if (!spaceAnimationFrame) {
    spaceAnimationFrame = requestAnimationFrame(smoothSpaceUpdate);
  }
}, { passive: false });

xyPad.addEventListener("dblclick", () => {
  randomizePatch();
});

function randomizePatch() {
  const heldKeys = Object.keys(activeNotes);

  stopAllActiveNotes();

  instrumentIndex = Math.floor(Math.random() * instruments.length);
  updateInstrumentUI();

  targetX = Math.random();
  targetY = Math.random();
  targetSpace = Math.random();

  octaveShift = [-12, 0, 12][Math.floor(Math.random() * 3)];

  updateOctaveHighlight();

  if (!xyAnimationFrame) {
    xyAnimationFrame = requestAnimationFrame(smoothXYUpdate);
  }

  if (!spaceAnimationFrame) {
    spaceAnimationFrame = requestAnimationFrame(smoothSpaceUpdate);
  }

  heldKeys.forEach((key) => {
    playNoteForKey(key);
  });
}

function playNoteForKey(key) {
  const actualNote = keyMap[key] + octaveShift;
  const instrumentAtStart = currentInstrument;

  activeNotes[key] = {
    note: actualNote,
    instrument: instrumentAtStart
  };

  socket.emit("playNote", {
    note: actualNote,
    velocity: 0.38 + macros.y * 0.48,
    amp: 0.16 + macros.y * 0.06,
    instrument: instrumentAtStart
  });

  highlightMidi(actualNote, true);
}

function stopNoteForKey(key) {
  const active = activeNotes[key];
  if (!active) return;

  socket.emit("stopNote", {
    note: active.note,
    instrument: active.instrument
  });

  highlightMidi(active.note, false);
  delete activeNotes[key];
}

function stopAllMouseNotes() {
  Object.keys(mouseNotes).forEach((midi) => {
    stopMouseNote(Number(midi));
  });
}

function stopAllActiveNotes() {
  Object.keys(activeNotes).forEach(stopNoteForKey);
  stopAllMouseNotes();

  Object.keys(midiNotes).forEach((midi) => {
    midiNoteOff(Number(midi));
  });
}

document.addEventListener("keydown", (event) => {
  const key = event.key.toLowerCase();

  if (event.key === "ArrowRight") {
    event.preventDefault();
    if (!event.repeat) nextInstrument();
    return;
  }

  if (event.key === "ArrowLeft") {
    event.preventDefault();
    if (!event.repeat) previousInstrument();
    return;
  }

  if (event.key === "ArrowUp") {
    event.preventDefault();
    targetSpace = Math.min(1, targetSpace + 0.06);

    if (!spaceAnimationFrame) {
      spaceAnimationFrame = requestAnimationFrame(smoothSpaceUpdate);
    }

    return;
  }

  if (event.key === "ArrowDown") {
    event.preventDefault();
    targetSpace = Math.max(0, targetSpace - 0.06);

    if (!spaceAnimationFrame) {
      spaceAnimationFrame = requestAnimationFrame(smoothSpaceUpdate);
    }

    return;
  }

  if (event.code === "Space") {
    event.preventDefault();
    if (!event.repeat) randomizePatch();
    return;
  }

  if (key === "z") {
    stopAllActiveNotes();
    octaveShift = Math.max(octaveShift - 12, -36);
    updateOctaveHighlight();
    return;
  }

  if (key === "x") {
    stopAllActiveNotes();
    octaveShift = Math.min(octaveShift + 12, 36);
    updateOctaveHighlight();
    return;
  }

  if (!(key in keyMap)) return;
  if (activeNotes[key]) return;

  playNoteForKey(key);
});

document.addEventListener("keyup", (event) => {
  const key = event.key.toLowerCase();
  if (!(key in keyMap)) return;
  stopNoteForKey(key);
});

let mouseIsDown = false;

function buildPianoKeyboard() {
  const keyboard = document.getElementById("pianoKeyboard");
  keyboard.innerHTML = "";

  const startMidi = 24;
  const octaves = 7;
  const totalWhiteKeys = octaves * 7;
  const whiteWidth = keyboard.clientWidth / totalWhiteKeys;
  const blackWidth = whiteWidth * 0.58;

  let whiteIndex = 0;

  for (let midi = startMidi; midi < startMidi + octaves * 12; midi++) {
    const note = midi % 12;
    const isBlack = [1, 3, 6, 8, 10].includes(note);

    const key = document.createElement("div");
    key.classList.add("pianoKey");
    key.dataset.midi = midi;

    if (!isBlack) {
      key.classList.add("whiteKey");
      key.style.left = whiteIndex * whiteWidth + "px";
      key.style.width = whiteWidth + "px";
      whiteIndex++;
    } else {
      key.classList.add("blackKey");
      key.style.width = blackWidth + "px";
      key.style.left = (whiteIndex * whiteWidth) - (blackWidth / 2) + "px";
    }

    key.addEventListener("mousedown", () => {
      mouseIsDown = true;
      stopAllMouseNotes();
      playMouseNote(midi);
    });

    key.addEventListener("mouseenter", () => {
      if (mouseIsDown) {
        stopAllMouseNotes();
        playMouseNote(midi);
      }
    });

    key.addEventListener("mouseup", () => {
      mouseIsDown = false;
      stopAllMouseNotes();
    });

    keyboard.appendChild(key);
  }

  updateOctaveHighlight();
}

document.addEventListener("mouseup", () => {
  mouseIsDown = false;
  stopAllMouseNotes();
});

function updateOctaveHighlight() {
  const octaveStart = 60 + octaveShift;
  const octaveEnd = octaveStart + 12;

  document.querySelectorAll(".pianoKey").forEach((key) => {
    const midi = Number(key.dataset.midi);

    if (midi >= octaveStart && midi <= octaveEnd) {
      key.classList.add("currentOctave");
    } else {
      key.classList.remove("currentOctave");
    }
  });
}

function playMouseNote(midi) {
  if (mouseNotes[midi]) return;

  mouseNotes[midi] = currentInstrument;

  socket.emit("playNote", {
    note: midi,
    velocity: 0.38 + macros.y * 0.48,
    amp: 0.16 + macros.y * 0.06,
    instrument: currentInstrument
  });

  highlightMidi(midi, true);
}

function stopMouseNote(midi) {
  if (!mouseNotes[midi]) return;

  socket.emit("stopNote", {
    note: midi,
    instrument: mouseNotes[midi]
  });

  delete mouseNotes[midi];
  highlightMidi(midi, false);
}

function highlightMidi(midi, state) {
  const key = document.querySelector('.pianoKey[data-midi="' + midi + '"]');
  if (!key) return;

  if (state) key.classList.add("active");
  else key.classList.remove("active");
}

function initMIDI() {
  if (!navigator.requestMIDIAccess) {
    console.log("Web MIDI not supported in this browser.");
    return;
  }

  navigator.requestMIDIAccess().then((midiAccess) => {
    console.log("MIDI ready.");

    for (const input of midiAccess.inputs.values()) {
      input.onmidimessage = handleMIDIMessage;
      console.log("MIDI input connected:", input.name);
    }

    midiAccess.onstatechange = () => {
      for (const input of midiAccess.inputs.values()) {
        input.onmidimessage = handleMIDIMessage;
      }
    };
  });
}

function handleMIDIMessage(message) {
  const [status, note, velocityRaw] = message.data;

  const command = status & 0xf0;
  const velocity = velocityRaw / 127;

  if (command === 0x90 && velocityRaw > 0) {
    midiNoteOn(note, velocity);
  }

  if (command === 0x80 || (command === 0x90 && velocityRaw === 0)) {
    midiNoteOff(note);
  }
}

function midiNoteOn(note, velocity) {
  if (midiNotes[note]) return;

  midiNotes[note] = currentInstrument;

  socket.emit("playNote", {
    note: note,
    velocity: velocity,
    amp: 0.10 + velocity * 0.18,
    instrument: currentInstrument
  });

  highlightMidi(note, true);
}

function midiNoteOff(note) {
  if (!midiNotes[note]) return;

  socket.emit("stopNote", {
    note: note,
    instrument: midiNotes[note]
  });

  delete midiNotes[note];
  highlightMidi(note, false);
}

window.addEventListener("resize", buildPianoKeyboard);

updateInstrumentUI();
buildPianoKeyboard();
updateVisuals();
sendMacroControls();
initMIDI();