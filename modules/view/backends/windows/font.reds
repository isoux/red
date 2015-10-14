Red/System [
	Title:	"Windows fonts management"
	Author: "Nenad Rakocevic"
	File: 	%font.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

make-font: func [
	hWnd    [handle!]
	face    [red-object!]
	values  [red-value!]
	return: [handle!]
	/local
		font [red-object!]
		int	 [red-integer!]
		value	[red-value!]
		bool	[red-logic!]
		style	[red-word!]
		str		[red-string!]
		blk		[red-block!]
		weight	[integer!]
		height	[integer!]
		angle	[integer!]
		quality [integer!]
		len		[integer!]
		name	[c-string!]
		italic? [logic!]
		under?	[logic!]
		strike? [logic!]
		hFont	[handle!]
][
	font: as red-object! values + FACE_OBJ_FONT
	values: object/get-values font
	
	int: as red-integer! values + FONT_OBJ_SIZE
	height: either TYPE_OF(int) <> TYPE_INTEGER [0][
		int/value * log-pixels-y / 72
	]
	
	int: as red-integer! values + FONT_OBJ_ANGLE
	angle: either TYPE_OF(int) = TYPE_INTEGER [int/value * 10][0]	;-- in tenth of degrees
	
	value: values + FONT_OBJ_ANTI-ALIAS?
	switch TYPE_OF(value) [
		TYPE_LOGIC [
			bool: as red-logic! value
			quality: either bool/value [4][0]			;-- ANTIALIASED_QUALITY
		]
		TYPE_WORD [
			style: as red-word! value
			either ClearType = symbol/resolve style/symbol [
				quality: 5								;-- CLEARTYPE_QUALITY
			][
				quality: 0
				;fire error ?
			]
		]
		default [quality: 0]							;-- DEFAULT_QUALITY
	]
	
	str: as red-string! values + FONT_OBJ_NAME
	name: either TYPE_OF(str) = TYPE_STRING [unicode/to-utf16 str][null]
	
	style: as red-word! values + FONT_OBJ_STYLE
	len: switch TYPE_OF(style) [
		TYPE_BLOCK [
			blk: as red-block! style
			style: as red-word! block/rs-head blk
			len: block/rs-length? blk
		]
		TYPE_WORD  [1]
		default	   [0]
	]
	
	italic?: no
	under?:  no
	strike?: no
	weight:	 0

	loop len [
		sym: symbol/resolve style/symbol
		case [
			sym = _bold	 	 [weight:  700]
			sym = _italic	 [italic?: yes]
			sym = _underline [under?:  yes]
			sym = _strike	 [strike?: yes]
		]
		style: style + 1
	]
	
	hFont: CreateFont
		height
		0												;-- nWidth
		0												;-- nEscapement
		angle											;-- nOrientation
		weight
		as-integer italic?
		as-integer under?
		as-integer strike?
		1												;-- DEFAULT_CHARSET
		0												;-- OUT_DEFAULT_PRECIS
		0												;-- CLIP_DEFAULT_PRECIS
		quality
		0												;-- DEFAULT_PITCH
		name
	
	blk: block/make-at as red-block! values + FONT_OBJ_STATE 2
	integer/make-in blk as-integer hFont
	
	blk: block/make-at as red-block! values + FONT_OBJ_PARENT 4
	block/rs-append blk as red-value! face
		
	hFont
]

set-font: func [
	hWnd   [handle!]
	face   [red-object!]
	values [red-value!]
	/local
		font  [red-object!]
		state [red-block!]
		int	  [red-integer!]
		hFont [handle!]
][
	font: as red-object! values + FACE_OBJ_FONT
	if TYPE_OF(font) <> TYPE_OBJECT [
		SendMessage hWnd WM_SETFONT as-integer default-font 1
		exit
	]
	state: as red-block! (object/get-values font) + FONT_OBJ_STATE
	
	hFont: as handle! either TYPE_OF(state) = TYPE_BLOCK [
		int: as red-integer! block/rs-head state
		int/value
	][
		make-font hWnd face values
	]
	SendMessage hWnd WM_SETFONT as-integer hFont 1
]