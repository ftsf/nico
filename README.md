# NICO Game Framework

NICO is a simple game framework for the [Nim](http://nim-lang.org/) programming language inspired by the [PICO-8](http://www.lexaloffle.com/) API and built on top of SDL2.

## What it does:
 * 16 Color Bitmap Graphics (you can load a custom palette)
 * Fixed or flexible custom display resolution with pixel scaling
 * Sprite drawing, load png spritesheets (can load multiple and switch between them)
 * Tilemap drawing, import json from Tiled
 * Drawing primitives: pixels, lines, rectangles, circles, triangles
 * Input: Keyboard, Gamepad, Mouse
 * Sfx playback: load and play oggs, configurable number of mixer channels.
 * Music playback: load and play one streaming ogg at a time
 * Text drawing: load and draw fonts from png, supports variable width fonts.
 * Export animated gifs
 
## Installation
 * You will need to have the Nim compiler installed, as well as a working C compiler
 * Run ```nimble install nico```
 * You can now ```import nico``` in your project, see the examples. 
 
## Why should you use NICO?
 * It's fun and easy to use
 * Learn Nim the fun way! It's a great new statically typed programming language that compiles to C.
 * You can build for Windows, Linux, Mac, Android, and potentially other platforms.
 * Should I use NICO instead of PICO-8?
  * Unlikely, if you're trying to decide between them, go with PICO-8. If you've been using PICO-8 and making games with it and want to rewrite them in a new language or extend them in ways that PICO-8 can't, maybe consider NICO, although there are other options too.
 
## Future work:
 * API Documentation
 * Fully configurable inputs
 * More examples
 * Tests
 * Replace SDL2_mixer with a built in mixer with support for crossfading
 * Built-in chip synthesiser / integrate [NimSynth](https://github.com/ftsf/nimsynth)
 * Editing tools
 * Utility modules for common higher level tasks
 
## Games made using NICO:
 * [Vektor 2089](https://impbox.itch.io/vektor2089)
 * [Smalltrek](https://impbox.itch.io/smalltrek)
 * [Moving in](https://impbox.itch.io/moving-in)
