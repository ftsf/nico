#? replace(sub = "\t", by = " ")

# import std/lenientops
import std/random
import std/tables
import nico

# https://gist.github.com/emanuel-sanabria-developer/5793377
# Converts an HSL color value to RGB. Conversion formula
# adapted from http://en.wikipedia.org/wiki/HSL_color_space.
proc hsl2rgb( h8, s8, l8: int ): tuple =
	let h = h8 / 255
	let s = s8 / 255
	let l = l8 / 255
	var r, g, b: float

	if s == 0:
		r = l; g = l; b = l # achromatic
	else:
		proc hue2rgb( p, q, t: float ): float =
			var t = t
			if t < 0: t += 1
			if t > 1: t -= 1
			if t < 1 / 6: return p + ( q - p ) * 6 * t
			if t < 1 / 2: return q
			if t < 2 / 3: return p + ( q - p ) * ( 2 / 3 - t ) * 6
			return p

		let q = if l < 0.5: l * (1 + s) else: l + s - l * s
		let p = 2 * l - q
		r = hue2rgb( p, q, h + 1 / 3 )
		g = hue2rgb( p, q, h)
		b = hue2rgb( p, q, h - 1 / 3 )

	return ( r * 255, g * 255, b * 255 )

proc loadPaletteFire( color: range[ 0 .. 4 ] ): Palette =
	proc transferFunc( value: int ): int =
		return min( 255, value * 2 )
		# return int( sqrt( value / 255 ) * 255 )

	var offset {.global.} = 0
	var r, g, b: float
	for i in 0 .. 255:
		case color
		of 0: # white - yellow - red
			( r, g, b ) = hsl2rgb( int( i / 3 ), 255, transferFunc( i ) )
		of 1: # white - yellow - green
			( r, g, b ) = hsl2rgb( int( 1 * 255 / 3 - i / 3 ), 255, transferFunc( i ) )
		of 2: # white - turquoise - blue
			( r, g, b ) = hsl2rgb( int( 2 * 255 / 3 - i / 3 ), 255, transferFunc( i ) )
		of 3: # white - magenta - red
			( r, g, b ) = hsl2rgb( int( 3 * 255 / 3 - i / 3 ), 255, transferFunc( i ) )
		of 4: # color cycle
			# ( r, g, b ) = hsl2rgb( int( ( i + offset ) / 3 ) mod 256, 255, transferFunc( i ) )
			( r, g, b ) = hsl2rgb( int( offset / 3 ) mod 256, 255, transferFunc( i ) )
		result.data[ i ] = ( r.uint8, g.uint8, b.uint8 )
	result.size = 256
	offset += 1

proc keyPressed( keycode: Keycode ): bool =
	var previousKeys {.global.} = initTable[ Keycode, bool ]()
	let isKeyPressed = key( keycode )
	result = isKeyPressed and not previousKeys.getOrDefault( keycode )
	previousKeys[ keycode ] = isKeyPressed

proc gameInit() =
	# setVSync( false )
	# echo getVSync()
	# cls()
	fps( 20 )
	setPalette( loadPaletteFire( 0 ) )
	loadMusic( 0, "fire_1.ogg" )
	music( 15, 0 ) # Needs to be rendered at 60 fps with the default audioBufferSize.
	setAudioBufferSize( 1024 * 2 * 60 div fps() ) # So we adjust it to our needs.
	setColor( 255 )
	printc( "KEYS:", screenWidth / 2, screenHeight / 3, 5 )
	printc( "S C M P", screenWidth / 2, 2 * screenHeight / 3, 5 )

proc gameUpdate( dt: Pfloat ) =
	discard

const
	width = 160
	# width = 1200
	height = 90
	# height = 125
	scale = 3

proc gameDraw() =
	var frame {.global.}: int32 = -1
	var fireArray {.global.}: array[ width, uint8 ]
	var randomizeFire {.global.}: bool = true

	frame += 1

	# Toggle sound playback with s key:
	if keyPressed( K_s ):
		if getMusic( 15 ) == -1:
			music( 15, 0 )
			printc( "SND ON", screenWidth / 2, screenHeight / 2, 5 )
		else:
			music( 15, -1 )
			printc( "SND OFF", screenWidth / 2, screenHeight / 2, 5 )

	# Cycle fire color with c key:
	var fireColor {.global.} = 0
	if keyPressed( K_c ):
		fireColor = ( fireColor + 1 ) mod 5
		setPalette( loadPaletteFire( fireColor ) )
		const colors = [ "ORANGE", "GREEN", "BLUE", "MAGENTA", "CYCLE" ]
		printc( colors[ fireColor ], screenWidth / 2, screenHeight / 2, 5 )

	if fireColor == 4:
		setPalette( loadPaletteFire( 4 ) )

	# Toggle message displaying with m key:
	var showMessage {.global.}:bool = false
	if keyPressed( K_m ):
		showMessage = not showMessage

	# Randomize fire every other frame.
	if randomizeFire:
		randomizeFire = false
		for x in 0 ..< screenWidth:
			fireArray[ x ] = rand( 255 ).uint8
	else:
		randomizeFire = not key( K_p ) # Pause fire with p key.

	const border = 5

	for x in border ..< screenWidth - border:
		pset( x, screenHeight - 2, fireArray[ x ] )
		pset( x, screenHeight - 1, fireArray[ x ] )

	if showMessage:
		const message = [ "", "", "HAPPY", "NEW", "YEAR", "2024", ":-)", ]
		if frame mod ( fps() * 2 ) == 0:
			setColor( 255 )
			printc( message[ ( frame div ( fps() * 2 ) ) mod len( message ) ],
				screenWidth / 2, screenHeight / 2, 5 )

	# https://lodev.org/cgtutor/fire.html
	for y in 0 ..< screenHeight - 2:
		for x in 1 ..< screenWidth - 1:
			let color = ( pget( x - 1, y + 1 ) + pget( x, y + 1 )  + pget( x + 1, y + 1 ) +
				pget( x, y + 2 ) ) / 4.1
			pset( x, y, color.int )

	for x in border ..< screenWidth - border:
		pset( x, screenHeight - 2, 255 )
		pset( x, screenHeight - 1, 0 )

nico.init( "nico", "test" )

fixedSize( true )
integerScale( true )
nico.createWindow( "fire", width, height + 2, scale )
nico.run( gameInit, gameUpdate, gameDraw )
