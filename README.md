# NICO Game Framework
[![test](https://github.com/ftsf/nico/workflows/test/badge.svg)](https://github.com/ftsf/nico/actions)

NICO is a simple game framework for the [Nim](http://nim-lang.org/) programming language inspired by the [PICO-8](http://www.lexaloffle.com/) API and built on top of SDL2 or the web.

## What it does:
 * Paletted Bitmap Graphics (you can load a custom palette up to 256 colors)
 * Fixed or flexible custom display resolution with pixel scaling
 * Sprite drawing, load png spritesheets, specify tile size per sheet (can load multiple and switch between them)
 * Tilemap drawing, import json from Tiled
 * Drawing primitives: pixels, lines, rectangles, circles, triangles
 * Input: Keyboard, Gamepad, Mouse, Touch
 * Sfx playback: load and play ogg vorbis files, configurable number of mixer channels.
 * Built in chip synth
 * Music playback: stream ogg vorbis files.
 * Custom audio callback for generating your own sounds via code.
 * Text drawing: load and draw fonts from png, supports variable width fonts.
 * Export animated gifs

## Installation
 * You will need to have the Nim compiler installed
 * Run ```nimble install nico```
 * Run ```nicoboot <projectname>``` to create a new directory with an example base ready to start working with.
 * [You can watch a quick tutorial here](https://www.youtube.com/watch?v=czLI5XJFxYA&list=PLxLdEZg8DRwTIEzUpfaIcBqhsj09mLWHx&index=3)
 * Make sure you have the required dependency: [https://www.libsdl.org/download-2.0.php](SDL2) for native builds, no dependencies for web builds.
 * From your project directory run ```nimble runr``` to build and run the example as a native build.
 * From your project directory run ```nimble web``` to build for web.

## Learning
 * [API Documentation](../blob/master/API.md)
 * [Examples](../tree/master/examples/)

## Why should you use NICO?
 * It's fun and easy to use
 * Learn Nim the fun way! It's a great new statically typed programming language that compiles to C.
 * You can build for Web, Windows, Linux, Mac, Android, and potentially other platforms.

## Future work:
 * API Documentation
 * More examples
 * Tests
 * Utility modules for common higher level tasks
  * Browser to browser networking using WebRTC
  * Immediate mode GUI
  * 3D Utils and Rasterizer

## Games made using NICO:
 * [Vektor 2089](https://impbox.itch.io/vektor2089)
 * [Smalltrek](https://impbox.itch.io/smalltrek)
 * [Moving in](https://impbox.itch.io/moving-in)
 * [Cute Cats Daily](https://impbox.itch.io/cute-cats-daily)
 * [Super Netwalk Deluxe](https://impbox.itch.io/super-netwalk-deluxe)
