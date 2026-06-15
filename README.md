
Quattro Formaggi

Overview

Quattro Formaggi is a web-based expressive string quartet instrument that combines a browser-based user interface with a SuperCollider synthesis engine.

The project allows users to perform and shape the sound of four string instruments (Violin I, Violin II, Viola and Cello) through an interactive Mood Pad, piano keyboard, computer keyboard and MIDI controller support.

The browser interface is built with HTML, CSS and JavaScript, while SuperCollider is used as the real-time sound synthesis engine. Communication between the browser and SuperCollider is handled through Node.js and OSC.

⸻

Features

* Four string instruments:
    * Violin I
    * Violin II
    * Viola
    * Cello
* Interactive Mood Pad
    * Bright ↔ Dark
    * Soft ↔ Aggressive
* Real-time sound shaping
* Piano Roll Interface
* Computer Keyboard Performance
* MIDI Keyboard Support
* Random Patch Generator
* Real-time Reverb Control
* Instrument Switching
* Octave Switching
* Browser ↔ SuperCollider Communication using OSC

⸻

Technologies Used

* HTML
* CSS
* JavaScript
* Node.js
* Socket.IO
* OSC
* SuperCollider

⸻

Architecture

Browser Interface (HTML/CSS/JavaScript)

↓

Node.js Server

↓

OSC Communication

↓

SuperCollider Synthesis Engine

↓

Audio Output

⸻

Sound Design

The synthesis engine is implemented in SuperCollider and is based on physically inspired bowed string modelling using DWGBowed.

Additional processing includes:

* Resonance modelling
* Bow noise modelling
* Vibrato
* Stereo spreading
* Saturation
* Reverb
* Dynamic filtering

Each instrument has its own preset configuration to emulate different string quartet roles.



Controls

Action	Control
Play Notes	Computer Keyboard
Play Notes	Piano Roll
Play Notes	MIDI Keyboard
Change Instrument	Left / Right Arrow
Change Reverb	Up / Down Arrow
Change Octave	Z / X
Randomize Patch	Space
Randomize Patch	Double Click Mood Pad
Shape Sound	Mood Pad
Control Reverb	Mouse Wheel

⸻

Future Improvements

* Preset Saving and Loading
* MIDI Visual Feedback
* Session Recording
* Additional String Models

⸻

MAHDI TAJOBY 
POLITECNICO DI MILANO - ACTAM 2025
