IDEAL
jumps
MODEL small
STACK 100h
DATASEG

	endg db 'endg.bmp',0

	starts db 'starts.bmp',0
	
	bannana db 'banana.bmp',0
	
	balloon db 'balloon.bmp',0
	
	blue db 'blue.bmp',0
	
	green db 'green.bmp',0
	
	background db 'btdmap.bmp',0
	
	movementmap db 'movement.bmp',0
	
	up_monkey db 'monkey.bmp',0
		
	arrow_pic  db 'arrow.bmp',0
	
	right_monkey db 'rmonkey.bmp',0
	
	left_monkey db 'lmonkey.bmp',0
	 
	down_monkey db 'dmonkey.bmp',0
	
	upright_monkey db 'urmonkey.bmp',0
	
	upleft_monkey db 'ulmonkey.bmp',0
	
	downright_monkey db 'drmonkey.bmp',0 
	
	downleft_monkey db 'dlmonkey.bmp',0
	
	zeropic db 'zero.bmp',0
	
	onepic db 'one.bmp',0
	
	twopic db 'two.bmp',0
	
	threepic db 'three.bmp',0
	
	fourpic db 'four.bmp',0
	
	fivepic db 'five.bmp',0
	
	sixpic db 'six.bmp',0
	
	sevenpic db 'seven.bmp',0
	
	eightpic db 'eight.bmp',0
	
	ninepic db 'nine.bmp',0
	
	filehandle dw ?
	
	Header db 54 dup (0)
	
	Palette db 256*4 dup (0)
	
	ScrLine db 320 dup (0)
	
	ErrorMsg db 'Error', 13, 10 ,'$'
	
	PressStart db 'Press S button to begin the round', 10 ,'$'
	
	pickhight dw ?
	
	pickwidth dw ?
	
	file dw ? 
	
	print_location dw ?
	
	Clock equ es:6Ch
	
	x dw 1 ;the first x pixel position I check
	y dw 1 ;the first y pixel position I check
	
	middle_y dw ?
	middle_x dw ?
	
	money dw 0300h
	life db 15d
	
	movearray dw 972 dup(0);the array of the movement addresses
	
	monkeys_array dw 280 dup(0) ;the array of all the print Monkey indexes. first word: index, second: picture, third:fire/not fire , fourth word: x start, fifth word: y start, sixth word: x end, seventh word: y end.
	arrow dw 200 dup(0) ;the array of all the arrows. first word: index, second word: index change, third word: type change (positive - 0 or negative - 1), fourth word: quadrant, firth word: index saver
	lastmonkeyprint dw offset monkeys_array
	lastarrow dw offset arrow
	first_arrow dw offset arrow
	create_arrow_address dw ?
	current_arrow dw ?
	balloon_offset dw ?
	monkey_counter dw 0
	arrow_counter dw 0
	create_number db 7d
	
	counter dw 0h ;the length of movearray
	save_counter dw 0h ;save the counter
	current_location dw 0h ;stores the index I print the balloon in
	
	LEFT_BUTTON dw 1 ;Left button status
	buy_monkey db 0
	
	balloon_structure db 550 dup(0) ;array that capable of storing 50 balloons at his max, each balloon takes 15 bytes
	balloon_buffer db 600 dup(0) ;technically 420
	balloon_buffer2 db 600 dup(0) ;technically 420
	balloon_buffer3 db 600 dup(0) ;technically 420
	speed db 4
	baloon_type db 1
	last dw offset balloon_structure
	last_active dw offset balloon_structure
	start_balloon dw offset balloon_structure
	ballon_time_counter db 25d
	active_ballons dw 0
	ballon_counter db 0
	
	save_ip dw ?
	save_ip2 dw ?
	
	deleted db 0
	
CODESEG
proc OpenFile
	; Open file
	mov ah, 3Dh
	xor al, al
	mov dx, [file]
	int 21h 
	jc openerror
	mov [filehandle], ax
	ret
	openerror:
		mov	ah, 59h
		int 21h
		mov dx, offset ErrorMsg
		mov ah, 9h
		int 21h
	ret
endp OpenFile 

proc ReadHeader
; Read BMP file header, 54 bytes
	mov ah,3fh
	mov bx, [filehandle]
	mov cx,54
	mov dx,offset Header
	int 21h
	ret
endp ReadHeader

proc ReadPalette
	; Read BMP file color palette, 256 colors * 4 bytes (400h)
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h
	ret
endp ReadPalette

proc CopyPal
	; Copy the colors palette to the video memory
	; The number of the first color should be sent to port 3C8h
	; The palette is sent to port 3C9h
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0
	; Copy starting color to port 3C8h
	out dx,al
	; Copy palette itself to port 3C9h
	inc dx
	PalLoop:
		; Note: Colors in a BMP file are saved as BGR values rather than RGB .
		mov al,[si+2] ; Get red value .
		shr al,2 ; Max. is 255, but video palette maximal
		; value is 63. Therefore dividing by 4.
		out dx,al ; Send it .
		mov al,[si+1] ; Get green value .
		shr al,2
		out dx,al ; Send it .
		mov al,[si] ; Get blue value .
		shr al,2
		out dx,al ; Send it .
		add si,4 ; Point to next color .
		; (There is a null chr. after every color.)
		loop PalLoop
	ret
endp CopyPal


proc CopyBitmap
	; BMP graphics are saved upside-down.
	; Read the graphic line by line
	; displaying the lines from bottom to top.
	mov ax, 0A000h
	mov es, ax
	mov cx,[pickhight]
	PrintBMPLoop :
		push cx
		mov dx, [print_location]
		; di = cx*320, point to the correct screen line
		mov di,cx
		shl cx,6
		shl di,8
		add di,cx
		add di,dx
		; Read one line
		mov ah,3fh
		mov cx,[pickwidth]
		mov dx,offset ScrLine
		int 21h
		; Copy one line into video memory
		cld ; Clear direction flag, for movsb
		mov cx,[pickwidth]
		dec cx ;skip the last col
		mov si,offset ScrLine
		rep movsb 
		pop cx
		loop PrintBMPLoop
	ret
endp CopyBitmap

proc CopyBitmapMonkey
	; BMP graphics are saved upside-down.
	; Read the graphic line by line
	; displaying the lines from bottom to top.
	mov ax, 0A000h
	mov es, ax
	mov cx,[pickhight]
	PrintBMPLoopMonkey :
		push cx
		mov dx, [print_location]
		; di = cx*320, point to the correct screen line
		mov di,cx
		shl cx,6
		shl di,8
		add di,cx
		add di,dx
		; Read one line
		mov ah,3fh
		mov cx,[pickwidth]
		mov dx,offset ScrLine
		int 21h
		; Copy one line into video memory
		cld ; Clear direction flag, for movsb
		mov cx,[pickwidth]
		dec cx ;skip the last col
		mov si,offset ScrLine
		rep_movsb_monkey:
			cmp [byte ptr ds:si],0h ;check if the pixel color is black. If so, don't show it on the screen
			je skip_color_monkey
			
			mov al,[ds:si]
			mov [es:di], al ;show the pixel on the screen
			
			skip_color_monkey:
				inc si
				inc di 
			loop rep_movsb_monkey
			
		pop cx
		loop PrintBMPLoopMonkey
	ret
endp CopyBitmapMonkey

proc CopyBitmapArrow
	; BMP graphics are saved upside-down.
	; Read the graphic line by line
	; displaying the lines from bottom to top.
	mov ax, 0A000h
	mov es, ax
	mov cx,[pickhight]
	PrintBMPLoop_arrow:
		push cx
		mov dx, [print_location]
		; di = cx*320, point to the correct screen line
		mov di,cx
		shl cx,6
		shl di,8
		add di,cx
		add di,dx
		; Read one line
		mov ah,3fh
		mov cx,[pickwidth]
		mov dx,offset ScrLine
		int 21h
		; Copy one line into video memory
		cld ; Clear direction flag, for movsb
		mov cx,[pickwidth]
		dec cx ;skip the last col
		mov si,offset ScrLine
		rep_movsb_arrow:
			cmp [byte ptr ds:si],0h ;check if the pixel color is black. If so, don't show it on the screen
			je skip_color_arrow
			
			cmp [deleted],1
			je print_color2
			
			cmp [byte ptr es:di], 00F9h ;if the arrow touches a balloon the balloon color is red
			jne blue_balloon
			
			;deletes the arrow if he touches a balloon
			push si
			push di
			call search_hit_balloon
			call delete_arrow
			pop di
			pop si
			jmp print_color2
			
			blue_balloon:
			cmp [byte ptr es:di], 00E8h
			jne green_balloon
			push si
			push di
			call search_hit_balloon
			call delete_arrow
			pop di
			pop si 
			jmp print_color2
			
			green_balloon:
			cmp [byte ptr es:di], 003Eh
			jne print_color2
			push si
			push di
			call search_hit_balloon
			call delete_arrow
			pop di
			pop si 
			
			print_color2:
			mov al,[ds:si]
			mov [es:di], al ;show the pixel on the screen
			
			skip_color_arrow:
				inc si
				inc di
			loop rep_movsb_arrow
			
		pop cx
		loop PrintBMPLoop_arrow
	
	exit_CopyBitmapArrow:
	ret
endp CopyBitmapArrow


proc CopyBitmapBalloon
	; Read the graphic line by line
	mov ax, 0A000h
	mov es, ax
	mov cx,[pickhight]
	mov si,[balloon_offset]
	PrintBMPLoopBalloon:
		push cx
		mov dx, [print_location]
		;di = cx*320, point to the correct screen line
		mov di,cx
		shl cx,6
		shl di,8
		add di,cx
		add di,dx ; add the offset of the print-start
		mov cx,[pickwidth]
		dec cx
		masking:
			cmp [byte ptr ds:si],0h ;check if the pixel color is black. If so, don't show it on the screen
			je skip_color
			
			mov al,[ds:si]
			mov [es:di], al ;show the pixel on the screen
			
			skip_color:
			inc si
			inc di
			loop masking
		pop cx
		loop PrintBMPLoopBalloon
	
	exit_CopyBitmapBalloon:
	ret
endp CopyBitmapBalloon



proc Read_Balloon
	mov cx,[pickhight]
	mov dx,offset balloon_buffer
	Read_Balloon_Loop: 
		push cx
		; Read one line
		mov ah,3fh
		mov cx,[pickwidth]
		int 21h ;ax stores the number of pixels that the inturupt read
		add dx,[pickwidth]
		dec dx ;20x20 is 0-19 pixels
		pop cx
		loop Read_Balloon_Loop
	ret
endp Read_Balloon

proc Read_Balloon2
	mov cx,[pickhight]
	mov dx,offset balloon_buffer2
	Read_Balloon_Loop2: 
		push cx
		; Read one line
		mov ah,3fh
		mov cx,[pickwidth]
		int 21h ;ax stores the number of pixels that the inturupt read
		add dx,[pickwidth]
		dec dx ;20x20 is 0-19 pixels
		pop cx
		loop Read_Balloon_Loop2
	ret
endp Read_Balloon2

proc Read_Balloon3
	mov cx,[pickhight]
	mov dx,offset balloon_buffer3
	Read_Balloon_Loop3: 
		push cx
		; Read one line
		mov ah,3fh
		mov cx,[pickwidth]
		int 21h ;ax stores the number of pixels that the inturupt read
		add dx,[pickwidth]
		dec dx ;20x20 is 0-19 pixels
		pop cx
		loop Read_Balloon_Loop3
	ret
endp Read_Balloon3

proc closefile near
     mov bx, [word ptr filehandle]
     mov ah,3eh
     int 21h
     jc error_closefil_12
     ret
     error_closefil_12:
     stc
     ret
endp
;----------------------------- all "picture" procs
proc picture ;Print a picture
	push si
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call CopyBitmap
		call CloseFile
	pop si
	ret
endp picture

proc Balloon_picture
	push si
	call CopyBitmapBalloon
		call CloseFile
	pop si
	ret
endp Balloon_picture

proc arrow_picture
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call CopyBitmapArrow
		call CloseFile
	ret
endp arrow_picture

proc monkey_picture
	push si
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call CopyBitmapMonkey
		call CloseFile
	pop si
	ret
endp monkey_picture
;----------------------------start specs of images


proc set_ballon_spec ;set the properties of the Balloon
	mov [pickhight],24
	mov [pickwidth],24
	mov [file], offset balloon
	mov [balloon_offset], offset Balloon_Buffer
	ret
endp set_ballon_spec

proc set_blue_spec
	mov [pickhight],24
	mov [pickwidth],24
	mov [file],offset blue
	mov [balloon_offset], offset Balloon_Buffer2
	ret
endp set_blue_spec

proc set_green_spec
	mov [pickhight],24
	mov [pickwidth],24
	mov [file],offset green
	mov [balloon_offset], offset Balloon_Buffer3
	ret
endp set_green_spec

proc set_end_spec
	mov [pickhight],100
	mov [pickwidth],160
	mov [file],offset endg
	mov [print_location],16050d
	ret
endp set_end_spec

proc set_start_spec
	mov [pickhight],200
	mov [pickwidth],320
	mov [print_location],0
	mov [file], offset starts
	ret
endp set_start_spec

proc set_background_spec ;set the properties of the BG
	mov [pickhight],200
	mov [pickwidth],320
	mov [print_location],0
	mov [file], offset background
	ret
endp set_background_spec

proc set_banana_spec
	mov [pickhight],24
	mov [pickwidth],24
	mov [file], offset bannana
	mov [print_location],0
	ret
endp set_banana_spec

proc set_monkey_spec
	mov [pickhight],24
	mov [pickwidth],24
	ret
endp set_monkey_spec

proc  set_arrow_spec
	mov [pickhight],16
	mov [pickwidth],16
	mov [file], offset arrow_pic
	ret
endp set_arrow_spec


proc firstmap ;set the properties of the movement map
	mov [file], offset movementmap
	mov [pickhight], 200d
	mov	[pickwidth],320d
	call picture
	ret
endp firstmap

	
;----------------------------end specs of images

proc frameclock
	push ax
	push cx
	push es
	
	mov ax, 40h
	mov es, ax
	mov ax, [Clock]
	FirstTick :
		cmp ax, [Clock]
		je FirstTick
		; count 0.055 sec
		mov cx, 1h ; 1x0.055sec
	DelayLoop:
		mov ax, [Clock]
		Tick :
			cmp ax, [Clock]
			je Tick
			loop DelayLoop
	
	pop es
	pop cx
	pop ax
	ret
endp frameclock

;------------------------------------Start of - One time use functions at the start of the game


proc get_first_black
	mov bh,0h
	mov cx,[x]
	not_black:
		mov dx,[y]
		mov ah,0Dh
		int 10h ; return al the pixel value read
		inc [y]
		cmp al, 0 ;check if the pixel is black
		jne not_black
	
	dec [y]
	ret
endp get_first_black


proc balloonroadarray
	pop [save_ip]
	mov si, offset movearray
	movecases:
		
		inc [counter]
		push [x]
		push [y]
		mov ax,320d
		mul [y]
		add ax, [x]
		mov [si],ax ;move to the array the address of the pixel
		
		caseright:
			add [x],1
			call getcolor
			cmp al,0
			je prevpixel
		
		caseleft:
			sub [x],2
			call getcolor
			cmp al,0
			je prevpixel
		
		casedown:
			add [x],1
			add [y],1
			call getcolor
			cmp al,0
			je prevpixel
		
		caseup:
			sub [y], 2; in the last case it must be black unless it's at the end of the road
			call getcolor
			cmp al,0
			je prevpixel
			jmp exitloop
		
		prevpixel:
		
			pop dx ;y of the prev pixel
			pop cx ;x of the prev pixel
			mov bh,0
			mov al,4h
			mov ah,0Ch
			int 10h
			add si,2
			jmp movecases
			
	exitloop:
		push [save_ip]
	ret
endp balloonroadarray
;------------------------------------The end of "One time use functions at the start of the game"



;------------------------------------ start of General procs
proc getcolor
	mov bh,0h
	mov cx,[x]
	mov dx,[y]
	mov ah,0Dh
	int 10h
	ret
endp getcolor



proc check_if_buy_monkey	
	cmp [buy_monkey],1
	je exitcheck_input
	
	in al, 64h
	cmp al,10b ;wait for data
	je exitcheck_input
	
	in al,60h
	
	cmp al,32h ;M
	jne exitcheck_input
	
	cmp [monkey_counter],19
	je exitcheck_input

	mov [buy_monkey],1

	exitcheck_input:
		
	ret
endp check_if_buy_monkey



proc create_monkey
	cmp [buy_monkey],0
	je exit_create_monkey
	
	cmp [monkey_counter],19
	je exit_create_monkey
	
	cmp [money],0300h
	jb exit_create_monkey
	
	mov ax,3h 
	int 33h ;checks mouse status
	
	cmp [LEFT_BUTTON], bx
	jne exit_create_monkey
	
	shr cx,1
	mov ax, 320d
	push dx
	mul dx
	pop dx
	add ax, cx ;calculate the print location of the monkey
	inc [monkey_counter]
	
	call setmonkeys_array
	call setradius
	add [lastmonkeyprint], 14d
	
	sub [byte offset money+1],3d ;each monkey costs 30 bannanas
	mov [buy_monkey],0
	
	exit_create_monkey:
		
	ret
endp create_monkey


proc print_all_monkeys
	push si
	mov si, offset monkeys_array
	call set_monkey_spec
	loop_print_all_monkeys:
		cmp [word si],0
		je skip_print_monkey
			
			mov ax, [si]
			mov [print_location], ax ;index
			mov ax, [si+2] ;picture
			mov [file], ax
			call monkey_picture
			
			add si, 14
		jmp loop_print_all_monkeys
	
	skip_print_monkey:
		pop si
	ret
endp print_all_monkeys


proc setmonkeys_array
	mov di, [lastmonkeyprint]
	mov [di], ax
	mov [word  di+2], offset up_monkey
	mov [word di+4],0 ;at the start the monkey is able to fire. 0-able, 1-doesn't able.
	ret
endp setmonkeys_array


proc setradius ;fix!!!- I need to start the radius from the middle of the monkey or from the end
	cmp cx,30d
	ja skip_x
		
		mov [word di+6],0d
		jmp skip_x_2
		
	skip_x:
	
	mov [di+6], cx
	sub [word di+6],30d ;the x of the start
	
	skip_x_2:
	
	cmp dx, 30d
	ja skip_y
	
	mov [word di+8],0d
	jmp  skip_y_2
	
	skip_y:
	
	mov [word di+8], dx 
	sub [word di+8], 30d ; the y of the start
	
	skip_y_2:
	
	cmp cx,266
	jb skip_x_end
	
		mov [word di+10],320d
		jmp  skip_x_2_end
		
	skip_x_end:
		mov [di+10], cx
		add [word di+10], 54d;the x of the end
	
	skip_x_2_end:
	cmp dx,146d
	jb skip_y_2_end
	
	mov [word di+12],200d
	jmp  skip_y_2_end_2
	
	skip_y_2_end:
	
	mov [di+12], dx
	add [word di+12], 54d ;the y of the end
	
	skip_y_2_end_2:
	
	ret
endp setradius


proc check_if_in_radius
	cmp [active_ballons],0
	je exit_check_if_in_radius
	cmp [monkey_counter],0
	je exit_check_if_in_radius
	
	mov si, [start_balloon]
	mov cx, [active_ballons]
	loop_check_if_in_radius:
		push cx
		push si
		cmp [byte si],1
		jne next_balloon
		mov bx, offset monkeys_array
		mov cx, [monkey_counter]
		go_to_next_monkey:
			push cx
			push bx
			push di
			
			cmp [word bx+4],1 ;did monkey shoot?
			je exit_go_to_next_monkey
			
			mov di, [word si+1] ;balloon index
			mov ax, [di]
			
			mov cx, 320d
			xor dx,dx
			div cx
			
			;Points to the middle of the Balloon
			add dx,12d
			add ax,12d
			
			cmp dx,[word bx+6]
			jb exit_go_to_next_monkey
			cmp dx,[word bx+10]
			ja exit_go_to_next_monkey
			cmp ax, [word bx+8] 
			jb exit_go_to_next_monkey
			cmp ax, [word bx+12]
			ja exit_go_to_next_monkey
			
			;ax= balloon's y 
			;dx= balloon's x
			;[bx+6]=radius's x start
			;[bx+8]=radius's y start
			;[bx+10]=radius's x end
			;[bx+12]=radius's y end
			
			
			;saving x and y.
			mov [x], dx
			mov [y], ax
				
			call find_arrow_place ;finds place to create a new arrow in the arrow-array.
			call arrow_start ;calculate the first index of the arrow, puts the index saver and turn shoot switch - on (of the monkey).
			call calculate_index_change ;calculate the index change and the slope. puts the monkey picture for the location of the balloon.
			
			exit_go_to_next_monkey:
				pop di
				pop bx
				add bx,14 ;next Monkey
				pop cx
			loop go_to_next_monkey
			
		next_balloon:
		pop si
		mov si, [word si+7] ;next Balloon
		pop cx
		loop loop_check_if_in_radius
	
	exit_check_if_in_radius:
	ret
endp check_if_in_radius

	
proc half_y ;returns the radius's y middle.
	;[y] - balloon's y
	mov ax, [bx+12]
	sub ax,42d
	mov [middle_y], ax
	ret
endp half_y


proc half_x ;returns the radius's x middle.
	;[x] - balloon's x
	mov ax, [bx+10]
	sub ax,42d
	mov [middle_x], ax
	ret
endp half_x

proc calc_slope1 ;the index change of the arrow- version2.
	mov di,ax
	mov ax,bx
	xor dx,dx
	
	div di
	add ax,320d
	mov [si+2], ax
	ret
endp calc_slope1

proc calc_slope2 ;the index change of the arrow- version2.
	xor dx,dx
	div bx
	mul cx
	inc ax
	mov [si+2],ax
	ret
endp calc_slope2

proc calculate_index_change ;first word: index, second word: index change, third word: type change (positive - 0 or negative - 1), fourth word: picture, firth word: index saver
	
	pop [save_ip]
	push di
	
	call check_angle ;finds quadrant, puts monkey picture, and negative/positive
	mov cx,320d
	
	cmp [word si+6],1 ;quadrant1
	jne quadrant2
	
	
	mov bx,[x]
	sub bx, [middle_x]
	
	mov ax, [middle_y]
	sub ax,[y]
	cmp bx,0 
	je exit_calculate_index_change
	cmp ax,bx
	jb skip_1
	
	;y bigger than x
	xor dx,dx
	div bx ;divide y/x
	mul cx ;y*320
	dec ax ;dec x (1)
	;shl ax,1
	mov [word si+2], ax
	jmp exit_calculate_index_change
	
	skip_1:
	;x bigger than y
	mov di,ax ;di=y
	mov ax,bx ;ax=x
	xor dx,dx
	
	div di ;divide x/y
	mov di,ax ;di= x/y
	mov ax,320d
	sub ax,di ;ax=320-x/y
	;shl ax,1
	mov [si+2], ax
	jmp exit_calculate_index_change
	
	quadrant2:
	cmp [word si+6],2 ;quadrant2
	jne quadrant3
	
	mov bx, [middle_x]
	sub bx,[x]
	
	mov ax, [middle_y]
	sub ax,[y]
	cmp bx,0 
	je exit_calculate_index_change
	cmp ax,bx
	jb skip_2
	
	xor dx,dx
	div bx
	mul cx
	inc ax
	;shl ax,1
	mov [si+2],ax
	
	jmp exit_calculate_index_change
	skip_2:
	mov di,ax
	mov ax,bx
	xor dx,dx
	
	div di
	mov di,ax
	mov ax,320d
	add ax,di
	;shl ax,1
	mov [si+2], ax
	jmp exit_calculate_index_change
	
	quadrant3:
	cmp [word si+6],3 ;quadrant3
	jne quadrant4
	
	mov ax,[y]
	sub ax,[middle_y]
	
	mov bx,[middle_x]
	sub bx,[x]
	cmp bx,0 
	je exit_calculate_index_change
	cmp ax,bx
	jb skip_3
	xor dx,dx
	div bx
	mul cx
	dec ax
	;shl ax,1
	mov [si+2],ax
	jmp exit_calculate_index_change
	skip_3:
	mov di,ax
	mov ax,bx
	xor dx,dx
	
	div di
	mov di, ax
	mov ax,320d
	sub ax,di
	;shl ax,1
	mov [si+2], ax
	jmp exit_calculate_index_change
	
	quadrant4:
	cmp [word si+6],4 ;quadrant4
	jne exit_calculate_index_change
	
	mov ax, [y]
	sub ax,[middle_y]
	
	mov bx,[x]
	sub bx,[middle_x]
	cmp bx,0 
	je exit_calculate_index_change
	cmp ax,bx
	jb skip_4
	xor dx,dx
	div bx
	mul cx
	inc ax
	;shl ax,1
	mov [si+2],ax
	jmp exit_calculate_index_change
	skip_4:
	mov di,ax
	mov ax,bx
	xor dx,dx
	
	div di
	mov di,ax
	mov ax,320d
	add ax,di
	;shl ax,1
	mov [si+2], ax
	
	exit_calculate_index_change:
		mov ax, [create_arrow_address]
		cmp ax, [lastarrow]
		jne not_last_arrow3
		
		add [lastarrow], 10 ;only if the new arrow is at the "end" of the current arrow array.
		;else, skip.
		
		not_last_arrow3:
		cmp ax, [first_arrow]
		ja not_last_arrow
		cmp [arrow_counter],1
		je not_last_arrow
		mov si,ax
		call search_first_arrow2
		not_last_arrow:
			pop di
			push [save_ip]
	ret
endp calculate_index_change 


proc search_first_arrow2
	push si
	mov si, [first_arrow]
	sub si,10d
	loop_search_first_arrow2:
		cmp [word si],0
		jne exit_search_first_arrow2
		sub si,10d
		jmp loop_search_first_arrow2
		
	exit_search_first_arrow2:
		mov [first_arrow],si
	pop si
	ret
endp search_first_arrow2


proc check_angle
	
	call half_y ;like: Yf-(Yf-Ys)/2 = (Yf+Ys)/2 or Yf-42
	call half_x ;like: Xf-(Xf-Xs)/2 = (Xf+Xs)/2 or Xf-42
	mov si, [create_arrow_address]
	
	mov ax, [x] ;balloon's x
	cmp ax,[middle_x]
	je option2
	
	mov ax,[y] ;balloon's y
	cmp ax,[middle_y]
	je search_y
	jmp x_and_y_not_equal
	
	search_y:
	mov ax,[x]
	cmp ax, [middle_x]
	ja shoot_right
	
	;shoot_left
	mov [word si+4], 1 ;negative
	mov [word si+2], 2d
	mov [word bx+2], offset left_monkey ;set monkey picture
	
	jmp exit_check_angle
	
	shoot_right:	
		mov [word bx+2], offset right_monkey ;set monkey picture
		mov [word si+2],2d
		mov [word si+4], 0 ;positive
		jmp exit_check_angle
	
	option2:
		mov ax,[y]
		cmp ax,[middle_y]
		ja shoot_down
		
		;shoot_up
		mov [word bx+2], offset up_monkey ;set monkey picture
		mov [word si+4], 1 ;negative
		mov [word si+2],640d
		jmp exit_check_angle
		
		shoot_down:
			mov [word si+2], 640d
			mov [word bx+2], offset down_monkey ;set monkey picture
			mov [word si+4], 0 ;positive
			jmp exit_check_angle
	
	x_and_y_not_equal:
		mov ax,[x] 
		cmp ax,[middle_x]
		ja shoot_right_direction
		
		;shoot left direction
		mov ax,[y]
		cmp ax,[middle_y]
		ja shoot_down_left
		
		;shoot up left
		mov [word si+4], 1 ;negative
		mov [word si+6],2 ;quadrant
		mov [word bx+2], offset  upleft_monkey ;set monkey picture
		jmp exit_check_angle
		
		shoot_down_left:
			mov [word bx+2], offset downleft_monkey ;set monkey picture
			mov [word si+6],3 ;quadrant
			mov [word si+4],0
			jmp exit_check_angle
		
		shoot_right_direction:
			;shoot right direction
			mov ax,[y]
			cmp ax,[middle_y]
			ja shoot_down_right
			
			;shoot up-right
			mov [word bx+2], offset  upright_monkey;set monkey picture
			mov [word si+6],1 ;quadrant
			mov [word si+4],1
			jmp exit_check_angle
			
			shoot_down_right:
					mov [word bx+2], offset downright_monkey;set monkey picture
					mov [word si+6],4 ;quadrant
					mov [word si+4],0 ;positive
					
	exit_check_angle:
	ret
endp check_angle ;problem!- the proc checks the location by the balloon index, not from the middle, so the monkey may shoot at the "wrong" direction.


proc find_arrow_place ;finds place in arrow-array to create the new arrow.
	push si
	mov si,offset arrow
	loop_find_arrow_place:
		cmp [word si],0
		je exit_find_arrow_place
		
		add si,10d
		jmp loop_find_arrow_place
		
	exit_find_arrow_place:
	
	mov [create_arrow_address], si
	pop si
	ret
endp find_arrow_place


proc search_monkey ;search monkey by it's index
	push cx
	mov si, offset monkeys_array
	mov cx,[monkey_counter]
	loop_arrow_start:
		cmp [si], ax
		je exit_loop_arrow_start
		add si,14d
		loop loop_arrow_start
	
	exit_loop_arrow_start:
	pop cx
	ret
endp search_monkey

proc search_hit_balloon
	mov si, [start_balloon]
	mov bx,320d
	loop_search_hit_balloon:
		push si
		cmp [byte si],0
		je not_this_balloon
		
		mov si, [word si+1]
		mov ax,[si] ;balloon index
		xor dx,dx
		div bx
		
		mov [x], dx ;balloon's x
		mov [y], ax ;balloon's y
		
		mov ax,di
		xor dx,dx
		div bx
		
		cmp ax,[y]
		jb not_this_balloon
		
		add [y],24d
		cmp ax,[y]
		ja not_this_balloon
		
		cmp dx,[x]
		jb not_this_balloon
		
		add [x],24d
		cmp dx,[x]
		ja not_this_balloon
		
		pop bx
		call delete_balloon
		mov [deleted],1
		
		mov al,[byte offset money]
		cmp al,9d
		je add_asarot
		
		inc [byte offset money] ;יחידות
		jmp exit_search_hit_balloon
		
		add_asarot:
			inc [byte offset money+1] ;עשרות
			mov [byte offset money],0
			jmp exit_search_hit_balloon
		
		not_this_balloon:
		pop si
		mov si, [word si+7]
		cmp si,0FFFFh
		jne loop_search_hit_balloon
		
	exit_search_hit_balloon:
	ret
endp search_hit_balloon

proc arrow_start ;sets the start index of the arrow.
	push bx
	
	mov [word bx+4],1 ; so the next time this monkey won't be able to shoot
	
	mov ax, [word bx]
	
	mov bx, [create_arrow_address]
	mov [bx+8], ax ;save the start- const
	add ax,3852d ;middle of the monkey
	mov [bx], ax 
	
	pop bx
	inc [arrow_counter]
			
	ret
endp arrow_start


proc delete_arrow
	push si
	
	mov si,[current_arrow]
	cmp si, [first_arrow]
	ja not_first_arrow
	
	cmp [arrow_counter],1
	je not_first_arrow
	
	call search_first_arrow
	
	not_first_arrow:
	cmp [arrow_counter],1
	je not_first_arrow2
	
	add si,10d
	cmp si, [lastarrow]
	jne not_first_arrow2
	
	call search_last_arrow
	
	not_first_arrow2:
		mov si, [current_arrow]
		mov [word si],0
		mov ax, [si+8] ;monkey id
		call search_monkey 
		mov [word si+4],0 ;so the monkey will be able to fire another dart
		dec [arrow_counter]
		
	pop si
	ret
endp delete_arrow

proc search_last_arrow
	push si
	push ax
	
	mov si, [lastarrow]
	sub si,10d
	mov ax,[first_arrow]
	loop_search_last_arrow:
		cmp [lastarrow],ax
		jbe problem2
		cmp [word si],0
		jne exit_search_last_arrow
		sub si,10d
		jmp search_last_arrow
	
	problem2:
	inc ax
	exit_search_last_arrow:
	mov [lastarrow],si
	
	pop ax
	pop si
	ret
endp search_last_arrow

proc search_first_arrow
	push si
	push ax
	
	add si,10d ;next arrow
	mov ax,[lastarrow]
	loop_search_first_arrow:
		cmp [first_arrow],ax
		jae problem
		
		cmp [word si],0
		jne exit_search_first_arrow
		
		add si,10d
		jmp loop_search_first_arrow
	
	problem:
		inc ax
		
	exit_search_first_arrow:
		mov [first_arrow],si
		pop ax
		pop si
	ret
endp search_first_arrow

;------------------------------------ end of General procs


;------------------------------------start of all-time procs

proc balloonindexprint ;prints a balloon at one index each time
	cmp [word ptr si+9],0 ;counter=0 means the balloon reached the end of the course
	jne still_active

	cmp [byte si+4],1
	jne two_life
		dec [life]
		push bx
		mov bx,si
		call delete_balloon
		pop bx
		jmp exit_balloonindexprint
	two_life:
		cmp [byte si+4],2
		jne three_life
		cmp [life],2
		jae regular_life
		mov [life],0
		jmp skip_regular_life
		regular_life:
		sub [life],2
		skip_regular_life:
		push bx
		mov bx,si
		call delete_balloon
		pop bx
		jmp exit_balloonindexprint
	three_life:
		cmp [life],3
		jae regular_life2
		mov [life],0
		jmp skip_regular_life2
		regular_life2:
		sub [life],3
		skip_regular_life2:
		push bx
		mov bx,si
		call delete_balloon
		pop bx
		jmp exit_balloonindexprint
	
	still_active:
		mov di, [word ptr si+1] ;holds the address of the location in movearray
		mov ax, [di]
		mov [print_location], ax ;gets the value of si address - the offset I need to print the balloon in
		cmp [word ptr si+9],1 ;if its the last index don't print the balloon
		je skip
		
		cmp [byte si+4],1
		jne type_2
			call set_ballon_spec
			call Balloon_picture
			jmp skip
		
		type_2:
			cmp [byte si+4],2
			jne type_3
			call set_blue_spec
			call Balloon_picture
			jmp skip
		
		type_3:
			call set_green_spec
			call Balloon_picture
		
		skip:
			mov ax, [si+3] ;speed
			xor ah,ah
			add [word ptr si+1],ax
			;sub [word ptr si+1],ax ;increase the index of the movearray by the speed for each balloon
			dec [word ptr si+9] ;the specific balloon counter
	
	exit_balloonindexprint:
	ret
endp balloonindexprint
;------------------------------------End of all-time procs

proc search_last
	loop_search_last:
		cmp [byte bx],1 ;Alive
		je exit_search_last
		sub bx,11d
		jmp loop_search_last
	exit_search_last:
	ret
endp search_last

proc balloon_generator
	mov al, [create_number]
	cmp [ballon_counter], al ;49 is the max amount of balloons I create, starts from 0
	je skip_balloon_generator
	cmp [ballon_time_counter],25d ;I want to create balloon only after the prev one moves 20 pixels from the BEGINING
	jne skip_balloon_generator
	
	mov [ballon_time_counter],0
	push ax
	push bx
	
	mov si, [last]
	mov [last_active], si
	cmp si, [start_balloon]
	je skip_next_of_prev

	mov bx, [word ptr si+5] ;my prev
	mov [bx+7], si ;set the next of the previous balloon to the current balloon
	
	skip_next_of_prev:
	
	mov [byte ptr si],1h ;Active
	
	mov [word ptr si+1], offset movearray ;movement index
	;add [word ptr si+1],1938d
	
	mov bl, [byte ptr speed]	
	mov [si+3], bl ;speed
	
	mov bl, [baloon_type]
	mov [si+4], bl ;balloon type
	
	
	cmp si, [start_balloon]
	jne skip_prev
		
		mov [word ptr si+5], 0FFFFh ;The first balloon has no prev balloon
		
	skip_prev:
		mov [word ptr si+16], si ;the prev of the next balloon I will generate is me
		mov [word ptr si+7], 0FFFFh 
		
		mov bx, [save_counter]
		mov [word ptr si+9], bx
		
		inc [active_ballons]
		inc [ballon_counter]
		add [last],11
		
		pop bx
		pop ax
		
	skip_balloon_generator:
	inc [ballon_time_counter]
	ret 
endp balloon_generator


proc delete_balloon
	cmp [word bx+9],0
	je dont_dec_level
	
	cmp [byte bx+4],1
	jne exit_delete_balloon2
	
	dont_dec_level:
	cmp bx, [start_balloon]
	jne not_start
		
		;for the last balloon there is no next
		cmp [active_ballons],1
		jne start_version2
		
		add [start_balloon], 11d ;if I have only one balloon the "start_balloon" must be 11 higher than the prev
		jmp exit_delete_balloon
		
		start_version2:
		mov ax, [word ptr bx+7] ;next of the current
		mov [start_balloon], ax ;the start now is the next of the current balloon
		push di
		mov di, ax
		mov [word di+5], 0FFFFh ;The first balloon has no prev
		pop di
		jmp exit_delete_balloon
		
	not_start:
		cmp bx,[last_active]
		je last_balloon
		
		push di
		mov di, [word bx+7] ;my next
		mov ax, [word bx+5] ;my prev
		mov [di+5], ax ;the prev of the next is now my prev
		
		mov di, [word bx+5] ;my prev
		mov ax, [word bx+7] ;my next
		mov [di+7], ax ;the next of the prev is now my next
		pop di
		jmp exit_delete_balloon
	
	last_balloon:
		push di
		push ax
		mov di,[word bx+5] ;my prev
		mov [last_active], di
		mov [word di+7],0FFFFh
		mov di, [last]
		mov ax, [word bx+5] ;my prev
		mov [di+5],ax ;the prev of the next baloon who isn't created yet is my prev
		pop ax
		pop di
		
	exit_delete_balloon:	
		mov [byte ptr bx],0
		dec [active_ballons]
		jmp exit_delete_balloon3
	exit_delete_balloon2:
		dec [byte ptr bx+4]
	exit_delete_balloon3:
	ret
endp delete_balloon


proc balloon_speed
	cmp [speed],2
	jne faster
	
	regular_speed:
		shr [counter],1
		jmp exit_balloon_speed
	
	faster:
		mov ax, [counter]
		mov bx,5d
		xor bh,bh
		xor dx,dx
		div bx
	exit_balloon_speed:
	ret
endp balloon_speed


proc print_all_balloons
	cmp [active_ballons],0
	je exit_print_balloon
	
	mov si, [start_balloon]
	print_balloon:
		
		mov ax, [word ptr si+1] ;this address stores the movearray index address
		mov [current_location], ax ;the place I want to print the balloon
		mov ax,[word ptr si+9];current balloon counter
		call balloonindexprint ;print one balloon at the specific balloon index 
		cmp [word ptr si+7], 0FFFFh ;if "next" equals to -1 it means the loop reach the last balloon it needs to print
		je exit_print_balloon
		
		mov si, [word ptr si+7]
		jmp print_balloon
	
	exit_print_balloon:
	ret
endp print_all_balloons



proc print_all_arrows
	cmp [arrow_counter],0
	je skip_print_all_arrows
	
	mov si, [first_arrow]
	mov ax, [lastarrow]
	;the max arrow that can be fired is 20.
	
	sub ax, [first_arrow]
	mov cx,10d
	xor dx,dx
	div cx 
	mov cx,ax
	
	call set_arrow_spec
	loop_print_all_arrows:
		push cx
		mov ax, [si]
		cmp [word si],0
		je skip_add_index
		
		mov [current_arrow],si
		call board_frame
		
		
		cmp [word si],0 ;there is no arrow at this spot in the array
		je skip_add_index
		
		mov [save_ip],si
		mov [print_location], ax ;the place I print the arrow in
		call arrow_picture  
		mov si,[save_ip]
		
		mov [deleted],0
		
		cmp [word si],0
		je skip_add_index
		
		mov bx, [si+2] ;index change
		mov ax, [si+4]  ;negative/positive 
		cmp ax,1 ;negative
		jne add_index
		
		;sub index
		sub [si],bx ;[si]=index
		jmp skip_add_index ;571
		
		add_index:
			add [si], bx
			
		skip_add_index:
			add si,10d
			pop cx
		loop loop_print_all_arrows
	jmp skip_print_all_arrows
	
	skip_print_all_arrows:
		ret
endp print_all_arrows


proc board_frame
	push ax
	push dx
	push bx
	
	mov si,[current_arrow]
	
	;ax stores the arrow index
	xor dx,dx
	mov bx,320d
	div bx
	
	y_1:
		cmp ax, 6 ;border
		ja y_2
		push si
		call delete_arrow
		pop si
		jmp exit_board_frame
	
	y_2:
		cmp ax,194d ;border
		jb x_1
		push si
		call delete_arrow
		pop si
		jmp exit_board_frame
	
	x_1:
		cmp dx, 5 ;border
		ja x_2
		push si
		call delete_arrow
		pop si
		jmp exit_board_frame
	x_2:
		cmp dx, 316d ;border
		jb exit_board_frame
		push si
		call delete_arrow
		pop si
		
	exit_board_frame:
		pop bx
		pop dx
		pop ax
		
	ret
endp board_frame


proc reset_arrow_array
	push si
	push cx
	
	mov si, offset arrow
	mov cx,200d
	loop_reset_arrow:
		mov [word si],0
		add si,2d
		loop loop_reset_arrow
	
	pop cx
	pop si
	ret
endp reset_arrow_array

proc reset_monkey_aray
	push si
	push cx
	
	mov si, offset monkeys_array
	mov cx,19d
	loop_reset_monkey_aray:
		mov [word si+4],0
		loop loop_reset_monkey_aray

	pop cx
	pop si
	ret
endp reset_monkey_aray

proc clear_round
	cmp [life],0
	jne skip_reset_life
	mov [life],15d
	mov [baloon_type],1
	mov [create_number],7
	skip_reset_life:
	mov [last], offset balloon_structure
	mov [start_balloon], offset balloon_structure
	mov [active_ballons],0
	mov [ballon_counter],0
	mov [last_active], offset balloon_structure
	mov [ballon_time_counter],25d
	mov [lastarrow], offset arrow
	mov [first_arrow], offset arrow
	mov [arrow_counter],0
	mov [create_arrow_address], offset arrow
	mov [buy_monkey],0
	mov [deleted],0
	call reset_arrow_array
	call reset_monkey_aray
	
	ret
endp clear_round


proc Round
	pop [save_ip2]
	call clear_round
	call balloon_generator ;so at the first time the loop goes it won't be infinite loop since there is no "next"=0FFFFh.
	round_loop:
		cmp [life],0
		je exit_round_loop
		
		call frameclock ;timer
		call set_background_spec
		call picture
		
		call balloon_generator
		
		call print_all_balloons	;prints all the balloons in their indexes/positions
		call check_if_in_radius
		call print_all_arrows
		call print_all_monkeys
		
		mov ah,[create_number]
		cmp [ballon_counter], ah
		jne countinue_round
		
		;Only if all the balloons were already created and then there is only zero left I exit the round
		cmp [active_ballons],0 ;when the last balloon die the loop stops
		je exit_round_loop
		
		countinue_round:
		call check_if_buy_monkey
		call create_monkey
		call print_money
		jmp round_loop
		
	exit_round_loop:
		push [save_ip2]
	ret	
endp Round

proc check_number
	op0:
	cmp al,0
	jne op1
	mov [file],offset zeropic
	jmp exit_check_number
	
	op1:
	cmp al,1
	jne op2
	mov [file],offset onepic

	jmp exit_check_number
	
	op2:
	cmp al,2
	jne op3
	mov [file],offset twopic
	jmp exit_check_number
	
	op3:
	cmp al,3
	jne op4
	mov [file],offset threepic
	jmp exit_check_number
	
	op4:
	cmp al,4
	jne op5
	mov [file],offset fourpic
	jmp exit_check_number
	
	op5:
	cmp al,5
	jne op6
	mov [file],offset fivepic
	jmp exit_check_number
	
	op6:
	cmp al,6
	jne op7
	mov [file],offset sixpic
	jmp exit_check_number
	
	op7:
	cmp al,7
	jne op8
	mov [file],offset sevenpic
	jmp exit_check_number
	
	op8:
	cmp al,8
	jne op9
	mov [file], offset eightpic
	jmp exit_check_number
	
	op9:
	cmp al,9
	mov [file],offset ninepic
	exit_check_number:
	ret
endp check_number

proc print_money
	call set_banana_spec
	call monkey_picture
	
	mov [pickhight],24
	mov [pickwidth],24
	
	mov bx, offset money
	mov al, [byte offset money+1]
	cmp al,0
	je dont_print_asarot
	
	call check_number
	mov [print_location], 24
	call monkey_picture
	
	mov al, [byte offset money]
	call check_number
	mov [print_location], 40
	call monkey_picture
	jmp exit_print_money
	
	dont_print_asarot:
		mov al, [byte offset money]
		call check_number
		mov [print_location], 24
		call monkey_picture
		
	exit_print_money:
	ret
endp print_money


proc Read_Balloon_to_buffer
	call set_ballon_spec
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call Read_Balloon
	ret
endp Read_Balloon_to_buffer

proc Read_Balloon_to_buffer2
	call set_blue_spec
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call Read_Balloon2
	ret
endp Read_Balloon_to_buffer2

proc Read_Balloon_to_buffer3
	call set_green_spec
	call OpenFile
	call ReadHeader
	call ReadPalette
	call CopyPal
	call Read_Balloon3
	ret
endp Read_Balloon_to_buffer3

proc wait_for_start
	check_input:
	in al, 64h
	cmp al,10b ;wait for data
	je exitcheck_input2
	
	in al,60h
	
	cmp al,1Fh ;S
	jne check_input
	
	exitcheck_input2:
	ret
endp wait_for_start


proc end_game
	call set_end_spec
	call picture
	check_input2:
	in al, 64h
	cmp al,10b ;wait for data
	je check_input2
	
	in al,60h
	
	cmp al,1Eh ;Again
	je exitcheck_input3
	
	cmp al,12h ;Exit
	jne check_input2
	
	exitcheck_input3:
	ret
endp end_game


start:
	mov ax, @data
	mov ds, ax
	
	; Graphic mode
	mov ax, 13h
	int 10h
	
	;creating the movement array with this 3 following procs - this is onetime functions
	call firstmap ;draw the movement map
	call get_first_black	;gets the index of the road start
	call balloonroadarray ; create the movearray values
	call Read_Balloon_to_buffer;Reads the Balloon BMP into Balloon_Buffer so it doesn't need to repeat each time I print the Balloon
	call Read_Balloon_to_buffer2
	call Read_Balloon_to_buffer3
	;create counter saver address
	
	;call balloon_speed ;sets the balloon speed
	
	shr [counter],1
	mov ax,[counter]
	mov [save_counter], ax
	
	call set_start_spec
	call picture
	call wait_for_start
	
	mov ax,1 ;show mouse pointer
	int 33h
	
	game:
		call Round
		cmp [life],0
		je exit_game
		mov dx, offset PressStart
		mov ah, 9h
		int 21h
		cmp [baloon_type],3
		je dont_add
		inc [baloon_type]
		dont_add:
		cmp [create_number],49
		je dont_add_balloons
		add [create_number],7d
		dont_add_balloons:
		call wait_for_start
		jmp game
	
	exit_game:
	; Wait for key press
	call end_game
	cmp al,1Eh
	je game
	
	xor ax,ax
	mov ah,1
	int 21h
	
	;Back to text mode
	mov ah, 0
	mov al, 2
	int 10h
	
exit:
	mov ax, 4c00h
	int 21h
END start