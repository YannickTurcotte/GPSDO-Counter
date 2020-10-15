;
;
;Serial routine

.equ   baud=9600		;Baud rate 
.equ   fosc=10000000	;Crystal frequency 

USART_Init:
		in temp, pinb	;check si jumper sur pb3. Si oui on est a 4800 au lieu de 9600
		andi temp, 0b00001000
		cpi temp, 0
		breq onesta4800
		ldi r17, high(fosc/(16*baud)-1) 
		ldi r16, low(fosc/(16*baud)-1) 
		rjmp setbaudrate 
 onesta4800:
		ldi r17, high(fosc/(16*4800)-1) 
		ldi r16, low(fosc/(16*4800)-1)
setbaudrate:    
		STORE UBRR0H, r17 
		STORE UBRR0L, r16 
		ldi r16, (1<<RXEN0)|(1<<TXEN0) |(0<<RXCIE0)	; Enable receiver and transmitter, interrupt rx disabled
		STORE UCSR0B,r16 
		ldi r16, (0<<USBS0)|(3<<UCSZ00)				; Set frame format: 8data, 1stop bit 
		STORE UCSR0C,r16
		ldi temp, $02
		call tx
		call nextline
		ldi temp, $03
		call tx
		ret 

RX: ; Wait for data to be received
		load r17,UCSR0A		 
		sbrs r17,RXC0			;This flag bit is set when there are unread data in the receive buffer and cleared when the receive buffer is empty. 1 = unread
		rjmp RX					;donc loop ici jusqu'au temps que rxc0 vaut 1
		lds r16, UDR0			; Get and return received data from buffer 
		ret 

TX: ; Wait for empty transmit buffer 
		load r17,UCSR0A         ;Load into R17 from SRAM UCSR0A. The UDRE0 Flag indicates if the transmit buffer (UDR0) is ready to receive new data. If UDRE0 is one,
		sbrs r17,UDRE0         ;the buffer is empty, and therefore ready to be written.. Skip next instruction If Bit Register is set 
		rjmp TX 
		STORE UDR0,r16		   ; Put data (r0) into buffer, sends the data 
		ret 

checkgpgga:	;$GPGGA pour neo 6m MAIS GNGGA sur neo 8M Donc je regarde pour seulement GGA
		wdr
		rcall rx
		cpi temp, $47	;G
		brne checkgpgga
		rcall rx
		cpi temp, $47	;G
		brne checkgpgga
		rcall rx
		cpi temp, $41	;A
		brne checkgpgga
;ici on a detecter $GPGGA on doit rammaser le nombre de satellite
		clr r18
kjkj:		;on compte 7 virgules. Ensuite on lit le nombre de satellites.
		rcall rx
		cpi temp, $2C	;,
		brne kjkj
		inc r18
		cpi r18, $07
		brne kjkj		;compte 7 virgules
;ici s'en vienne les 2 nombres ascii. Exemple 31, 32 pour 12.
		rcall rx
		sts satelliteh, temp
		rcall rx
		sts satellitel, temp		;ici le nombre de satellites est en ascii dans satelliteh:satellitel  exemple 31:32 pour afficher 12.
		ret

;dois comparer si on a plus que 3 sat et allumer le led sinon le fermer..
		lds temp, satelliteh
		subi temp, $30
		lsl temp
		lsl temp
		lsl temp
		lsl temp
		lds r17, satellitel
		subi r17, $30
		add temp, r17
		cpi temp, $3
		brge onallumeleled2
		;sinon on ferme le led
		load temp, portd
		cbr temp, 0b10000000
		out portd, temp
		ret
onallumeleled2:
		load temp, portd
		sbr temp, 0b10000000
		out portd, temp
		ret


affichesatellite2:
		load r16, UCSR0A	;regarde si ya de quoi qui a �t� recu par le serial
		sbrs r16, RXC0
		ret					;rxc0 est a 0 on a rien recu
		rcall checkgpgga	;on ramasse le nombre de satellite
		rcall posisat
		ldi temp, $53		; S
		rcall afficheascii
		call tx
		ldi temp, $3d		; =
		rcall afficheascii
		call tx
		lds temp, satelliteh
		rcall afficheascii
		call tx
		lds temp, satellitel
		rcall afficheascii
		call tx

;dois comparer si on a plus que 3 sat et allumer le led sinon le fermer..
		lds temp, satelliteh
		subi temp, $30
		lsl temp
		lsl temp
		lsl temp
		lsl temp
		lds r17, satellitel
		subi r17, $30
		add temp, r17
		cpi temp, $3
		brge onallumeleled22
		;sinon on ferme le led
		cbi portd, 7
		ret
onallumeleled22:
		sbi portd, 7
		ret

;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
;*********************************************************************************************************************
;$GPGGA,hhmmss.ss,llll.ll,a,yyyyy.yy,a,x,xx,x.x,x.x,M,x.x,M,x.x,xxxx*hh
afficheheureposition:
;affiche heure pour 10 secondes
		rcall videecran
		load r16, UCSR0A	;regarde si ya de quoi qui a �t� recu par le serial
		sbrs r16, RXC0		;skip if bit in register is set
		ret					;rxc0 est a 0 on a rien recu pas de signal
		ldi r26, 10
afseconde:
		rcall checkgpggahp	;ramasse les valeur (heure)
		rcall posi1
		rcall nextline
		lds temp, heureh
		rcall afficheascii
		call tx
		lds temp, heurel
		rcall afficheascii
		call tx
		ldi temp, $3A		; :
		rcall afficheascii
		call tx
		lds temp, minuteh
		rcall afficheascii
		call tx
		lds temp, minutel
		rcall afficheascii
		call tx
		ldi temp, $3A		; :
		rcall afficheascii
		call tx
		lds temp, secondeh
		rcall afficheascii
		call tx
		lds temp, secondel
		rcall afficheascii
		call tx
		rcall espace
		call espaceserial
		ldi temp, $55	;U
		rcall afficheascii
		call tx
		ldi temp, $54	;T
		rcall afficheascii
		call tx
		ldi temp, $43	;C
		rcall afficheascii
		call tx
attendprochaineseconde:
		load r16, UCSR0A	;regarde si ya de quoi qui a �t� recu par le serial
		sbrs r16, RXC0		;skip if bit in register is set
		rjmp attendprochaineseconde				;rxc0 est a 0 on a rien recu
		dec r26
		brne afseconde
;le temps vien d'etre afficher 10 seconde maintenant latitude et longitude
		rcall videecran
		call nextline
		ldi r26, 10 ;pour 10 seconde
debutdeaffichagelatitudelongitude:
;affiche position pour 10 secondes
		rcall ramassegga	;ramasse la string gga au complet incluant l'heure
		rcall posi1
		rcall nextline
		ldi zh, high(gga)	;adresse de RAM $240 dans Z
		ldi Zl, low(gga)
		ldi r18, 2	;on passe 2 virgule pour se rendre a la latitude. On passe par dessus l'heure
aflatitude:	
		ld	r0, z+			;charge r0 avec le contenu de l'adresse que pointe z
		mov temp, r0	;
		cpi temp, $2c	;compare avec virgule
		brne aflatitude
		dec r18
		brne aflatitude
;debut latitude
		ld	r0, z+			;4
		mov temp, r0	;
		rcall afficheascii
		call tx
		ld	r0, z+			;6
		mov temp, r0	;
		rcall afficheascii
		call tx
		ldi temp, $27	;`
		rcall afficheascii
		call tx
suitelatitude:
		ld	r0, z+			;
		mov temp, r0	;compare avec virgule.... pourquoi ? parce que dans diff�rent module il n'y a pas toujours le meme nombres de chiffre apres le point.
		cpi temp, $2c ;,
		breq emisphere
		rcall afficheascii
		call tx
		rjmp suitelatitude
emisphere:
		rcall espace
		rcall espaceserial
		ld	r0, z+			;on ecris N ou S
		mov temp, r0	;
		rcall afficheascii
		call tx
		rcall posi2
		call nextline
		ld	r0, z+		;passe virgule
		ld	r0, z+	
		mov temp, r0	;
		rcall afficheascii		;0
		call tx
		ld	r0, z+	
		mov temp, r0
		rcall afficheascii		;7
		call tx
		ld	r0, z+	
		mov temp, r0
		rcall afficheascii		;2
		call tx
		ldi temp, $27			;`
		rcall afficheascii
		call tx	
nextline2:
		ld	r0, z+				;on affiche le reste jusqua la virgule.
		mov temp, r0
		cpi temp, $2c
		breq nextlinefini
		rcall afficheascii
		call tx
		rjmp nextline2
nextlinefini:
		rcall espace
		rcall espaceserial
		ld	r0, z+				;W ou E
		mov temp, r0
		rcall afficheascii
		call tx
		call nextline
		dec r26					;decremene 26 et on recommence sinon fini
		brne debutdeaffichagelatitudelongitude2
		ret

debutdeaffichagelatitudelongitude2:
	rjmp debutdeaffichagelatitudelongitude

;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
checkgpggahp:	;$GPGGA pour neo 6m MAIS GNGGA sur neo 8M Donc je regarde pour seulement GGA
;checkgga heure position et store dans memoire heure et position
;$xxGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
		wdr
		rcall rx
		cpi temp, $47	;G
		brne checkgpggahp
		rcall rx
		cpi temp, $47	;G
		brne checkgpggahp
		rcall rx
		cpi temp, $41	;A
		brne checkgpggahp
		;ici on a detecter $GPGGA on doit rammaser le nombre de satellite
		clr r18
kjkj1:		;on compte 1 virgules.
		rcall rx
		cpi temp, $2C	;,
		brne kjkj1
		inc r18
		cpi r18, $01
		brne kjkj1		;compte 1 virgules
		;ici s'en vienne les 6 nombres ascii. Exemple 31, 32 pour 12.
		rcall rx
		sts heureh, temp
		rcall rx
		sts heurel, temp		;
		rcall rx
		sts minuteh, temp
		rcall rx
		sts minutel, temp		;
		rcall rx
		sts secondeh, temp
		rcall rx
		sts secondel, temp		;
		ret


;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
;****************************************************************************************************************************************************************************************
ramassegga:	;$ramasse toute la string de gga. et la met dans $240 +
		wdr
		rcall rx
		cpi temp, $47	;G
		brne ramassegga
		rcall rx
		cpi temp, $47	;G
		brne ramassegga
		rcall rx
		cpi temp, $41	;A
		brne ramassegga
		;	rcall rx ;passe la virgule
		;ici on a detecter $GPGGA on doit rammaser la string
		ldi zh, high(gga)		;adresse de RAM $240 dans Z
		ldi Zl, low(gga)
prochainbytes:	
		rcall rx
		mov r0,temp
		st z+, R0							;R0 dans ce que pointe Z ici $240 en montant
		cpi temp, $24			;regarde si rx recoit $. Si oui = veut dire qu'on a ramasser gga au complet
		breq donegga
		rjmp prochainbytes
donegga:
		ret
;		46`19.81427 m. N

;***************************************************************************************
SendSpeed1000serial:
		lds temp, frebcd6		;j'affiche:        1 00 00 00 0.0 00
		cpi temp, 0
		brne aldo1000serial				;si frebcd6 = 0 on affiche un espace a place
		rcall espaceserial
		rjmp yahoo1000serial
aldo1000serial:
		lds temp, frebcd6
		rcall affichenombreSeriallow
yahoo1000serial:
		lds temp, frebcd5
		rcall affichenombreSerial
		lds temp, frebcd4
		rcall affichenombreSerial
		lds temp, frebcd3
		rcall affichenombreSerial
		lds temp, frebcd2
		rcall affichenombreSerialhigh
		ldi temp, $2e			;.
		rcall tx
		lds temp, frebcd2
		rcall affichenombreSeriallow
		lds temp, frebcd1
		rcall affichenombreSerial
		rcall espaceserial
		ldi temp, $48			;H
		rcall tx
		ldi temp, $7a
		rcall tx				;z
		call nextline
		ret
;***************************************************************************************
SendSpeed10000serial:
		lds temp, frebcd6 ;10
		andi temp, $F0 ;00
		cpi temp, 0
		brne aldoserial
		rcall espaceserial						
		rjmp yahooserial
aldoserial:
		lds temp, frebcd6	
		rcall affichenombreSerialhigh
yahooserial:
		lds temp, frebcd6	
		rcall affichenombreSeriallow
		lds temp, frebcd5
		rcall affichenombreSerial
		lds temp, frebcd4
		rcall affichenombreSerial
		lds temp, frebcd3
		rcall affichenombreSerial
		ldi temp, $2e			;.
		rcall tx
		lds temp, frebcd2
		rcall affichenombreSerial
		lds temp, frebcd1
		rcall affichenombreSerial
		rcall espaceserial
		ldi temp, $48			;H
		rcall tx
		ldi temp, $7a
		rcall tx				;z
		call nextline
		ret
;**********************************************************************************************
affichenombreSerial: 	;affiche un nombre DCB. Exemple si 0x17 est dans temp. 17 sera affich� sur port serie
		push temp		;17	;On additionne 30 sur lsb et msb donc 17 = 31 + 37
		swap temp		;71
		andi temp, $0F	;1
		subi temp, -$30 ;31
		rcall tx
		pop temp ;17
		andi temp, $0F
		subi temp, -$30 ;31
		rcall tx
		ret
;***************************************************************************************
affichenombreSerialhigh: 	;affiche un nombre DCB. Exemple si 0x17 est dans temp. 17 sera affich� sur port serie
		swap temp		;71
		andi temp, $0F	;1
		subi temp, -$30 ;31
		rcall tx
		ret
affichenombreSeriallow:
		andi temp, $0F
		subi temp, -$30 ;31
		rcall tx
		ret
;***************************************************************************************
messageserial:
		lpm				;lpm = load program memory. Le contenu de l'adresse point� par Z se retrouve dans R0
		mov temp, r0	;comparons r0 avec 04 pour vois si le message est � la fin
		cpi temp, $04
		breq finmessageserial
		mov temp, r0  	;Il faut s�parer la valeur lu, exemple:(41) en 40 et 10 pour envoyer � l'afficheur
		rcall tx
		adiw ZH:ZL,1	;incremente zh,zl et va relire l'addresse suivante
		rjmp messageserial
finmessageserial:
		ret
;***************************************************************************************
virguleserial:
		ldi temp, $2c		;,
		rcall tx
		ret
;***************************************************************************************
nextline:
		ldi temp, $d
		rcall tx
		ldi temp, $A
		rcall tx
		ret
;***************************************************************************************
espaceserial:
		push temp
		ldi temp, $20
		call tx
		pop temp
		ret

;**************************** affichememoireserial *************************************
;affiche le contenu tel quel. exemple si $3a est dans temp 3a sera afficher
affichememoireserial:
		push temp
		push temp
		swap temp		;exemple 3A
		andi temp, $0f	;on garde le  3
		ldi r31,high(hexa*2) ;pointe l'addresse le la database dans R0
		ldi r30,low(hexa*2)	; l'addresse de m�moire;
		add ZL, temp		;augmente l'adresse pour pointer le bon chiffre (r31 et r30 constitue zh et zl)
		brcc okpasdedepassementqserial	;(branch if carry est 0) si le carry est a 1 (il y a une retenue) = plus que FF on incr�mente donc zh. Sinon il passe et laisse zl normal
		inc zh
okpasdedepassementqserial:
		lpm
		mov temp,r0
		rcall tx
		pop temp
		andi temp, $0f	;on garde le  3
		ldi r31,high(hexa*2) ;pointe l'addresse le la database dans R0
		ldi r30,low(hexa*2)	; l'addresse de m�moire;
		add ZL, temp		;augmente l'adresse pour pointer le bon chiffre (r31 et r30 constitue zl et zh)
		brcc okpasdedepassement7qserial	;(branch if carry est 0) si le carry est a 1 (il y a une retenue) = plus que FF on incr�mente donc zh. Sinon il passe et laisse zl normal
		inc zh
okpasdedepassement7qserial:
		lpm
		mov temp,r0
		rcall tx	;3 est afficher
		pop temp
		ret
