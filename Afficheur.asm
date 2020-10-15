;.dseg	;data segment de 512 sur atmega48
data7:
	.db "Counter YT v1.02" ; ,04 si impair
	.db $04,00 
data19:
	.db "No pulse.       " ; ,04 si impair
	.db $04,00
data20:
	.db "Set to Default  " ; ,04 si impair
	.db $04,00
data32:
	.db "Waiting...      " ; ,04 si impair
	.db $04,00
data34:
	.db "Gate 10000s"  ,04; si impair
	;.db $04,00 
data37:
	.db "Gate 1000s" ; ,04 si impair
	.db $04,00
data40:
	.db "Last Frequency =" ; ,04 si impair
	.db $04,00
hexa:

.db		$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$41,$42,$43,$44,$45,$46

;******************************************reset afficheur*********************************
;******************************************************************************************
reset_afficheur:	;sous routine pour initialiser l'afficheur pour la premieres fois.
		ldi r16, $03 ;$30     ;ici Je force l'afficheur à être sur 8 bits.
        out portc, r16	;en lui envoyant la commande 3x
        rcall enable	;MET 1 SUR LA BROCHE E
	  					;il faut le forcer en 8 bits avant. Pourquoi ??? Pour quand on reset!
		ldi r16,$03    	;Si on est en mode 4 bit... on envois 2 trame de 4 bits. Quand on reset
        out portc, r16	;entre les 2 trames, la seconde reçu n'est pas la bonne et l'afficheur écrit
        rcall enable	;n'importe quoi.

		ldi r16,$03		;Il faut le forcer au moin 3 fois de suite pour éléminerle problème.
        out portc, r16
        rcall enable

		ldi r16,$02     ;Ici avec cette commande, on passe en 4 bits. NOW
        out portc, r16	
        rcall enable	

		ldi r16,$02 ;EN ECRITURE, 4 BITS, NOMBRE DE LIGNES 1=2 LIGNES... (28)
	    out portc, r16
	    rcall enable 
		rcall tempo2ms
		ldi r16,$08 
	    out portc, r16
	    rcall enable

	    ldi r16,$00     ;DISPLAY ON, CURSEUR OFF (0c)
        out portc, r16
        rcall enable
        ldi r16,$0c
        out portc, r16
        rcall enable

        ldi r16,$00     ;SET MODE, INCREMENTE, DISPLAY FREEZE (06)
        out portc,r16
        rcall enable
        ldi r16,$06
        out portc,r16
        rcall enable
		rcall videecran	;ici vedeecran est en sous routine car ça sert souvent.
		ret

;********************************** enable ********************
enable: cbi portc,5		;met RS à 0 pour une commande
        sbi portc,4		;met E a 1 pour valider (enable)
        rcall tempo2ms    	;2ms. La boucle enable est plus longue que celle de ecris qui est de 50us
        cbi portc,4		;selon les datasheets enable = 1.64ms et 40us pour ecris.
        ret

;********************************* ecris **********************
ecris:  sbi portc,5		;mer RS à 1 pour une donnée
        sbi portc,4    	;met E a 1 pour valider (enable)          
        rcall t50us		;BOUCLE DE TEMPS 50us
		cbi portc,4
        ret

;************************** videecran ****************************************
videecran:
        ldi r16,$00     ;CLS	(01)
        out portc,r16
        rcall enable
        ldi r16,$01     ;CLS
        out portc,r16
        rcall enable
		ret

;************************** posi1 **********************************
posi1:  ldi temp,$08	;80, c0, 94, d4 sont les positions du debut des lignes de l'afficheur
       	out portc,r16
        rcall enable
        ldi temp,$00
       	out portc,r16
        rcall enable
        ret

;************************** posi2 ***********************************
posi2:  ldi r16,$0c  	;c0
       	out portc,r16
        rcall enable
        ldi r16,$00
       	out portc,r16
        rcall enable
        ret

;************************** posisat *************************
posisat:  
		ldi temp,$08	;94		;positionne sur les 3 dernier digit de la premiere ligne pour afficher les sattelite
       	out portc,r16
        rcall enable
        ldi temp,$0C
       	out portc,r16
        rcall enable
        ret

;************************* espace ***************************
espace:		;écris un espace (20 en ascii)
		ldi temp, $20		;space
		rcall afficheascii
		ret

;************************* Efface Ligne**********************
effaceligne:
		push temp
		ldi temp2, 16
effaceligne2:
		push temp2
		ldi temp, $20
		rcall afficheascii
		pop temp2
		dec temp2
		brne effaceligne2
		pop temp
		ret

;************************* affiche ascii **********************************
afficheascii:	;affiche un nombre qui est dans temp. Ce nombre doit etre déja en ascii
				;si $41 est dans temp, un A sera affiché.
		push temp
		mov r17, temp   ;pour séparer les 4 msb des 4 lsb dans r21 et r22
		swap temp
		andi temp, $0f	;04 se retrouve dans temp
		andi r17, $0f	;01 se retrouve dans r17
		out portc, temp
		rcall ecris
		out portc, r17
		rcall ecris
		pop temp
		ret
;*************************** affichenombre *******************************************
affichenombre: 	;affiche un nombre DCB. Exemple si 0x17 est dans temp. 17 sera affiché
				;donc 17 = 30 + 10 (31) + 30 + 70 (37)
				;Si $09 est dans temp seulement 9 sera affiché (pas de 0)
		push temp
		sts byte, temp		;ici on met en mémoire le registre 16 à l'emplacement $60
plushaut:
		ldi r17, 0x03		;add 30 au chiffre pour le rendre ascii
		out portc, r17
		rcall ecris
		lds temp, byte
		ldi r17, 0b11110000    ;pour séparer les 4 msb des 4 lsb
		and temp, r17
		swap temp
		out portc, temp
		rcall ecris	
affichenombre2:	;ecris juste un chiffre. si 02 est dans byte 2 va etre affiché.
		ldi r17, 0x03		;add 30 au chiffre pour le rendre ascii
		out portc, r17
		rcall ecris
		lds temp, byte
		ldi r17, 0b00001111    ;pour séparer les 4 msb des 4 lsb
		and temp, r17
		out portc, temp
		rcall ecris
		pop temp
		ret

;*************************** affichemsb ******************************************
affichemsb:					;affiche le msb d'un nombre de 0 a 9 si 45 est dans temp 4 sera affiché
		push temp
		sts byte, temp
		ldi r17, 0x03		;add 30 au chiffre pour le rendre ascii
		out portc, r17
		rcall ecris
		lds temp, byte
		ldi r17, 0b11110000    ;pour séparer les 4 msb des 4 lsb
		and temp, r17
		swap temp
		out portc, temp
		rcall ecris
		pop temp
		ret

;*************************** affichemlsb ******************************************
affichelsb:					;affiche le lsb d'un nombre de 0 a 9 si 45 est dans temp 5 sera affiché
		push temp
		sts byte, temp
		ldi r17, 0x03		;add 30 au chiffre pour le rendre ascii
		out portc, r17
		rcall ecris
		lds temp, byte
		ldi r17, 0b00001111    ;pour séparer les 4 msb des 4 lsb
		and temp, r17
		out portc, temp
		rcall ecris
		pop temp
		ret

;***************************** message ****************************************
message:
		lpm				;lpm = load program memory. Le contenu de l'adresse pointé par Z se retrouve dans R0
		mov temp, r0	;comparons r0 avec 04 pour vois si le message est à la fin
		cpi temp, $04
		breq finmessage
		mov temp, r0  	;Il faut séparer la valeur lu, exemple:(41) en 40 et 10 pour envoyer à l'afficheur
		call tx
		mov r17, r0	
		swap temp
		andi temp,$0F
		andi r17, $0F
		out portc, temp	;on envois la valeur haute en premier exemple: A = 41 donc (40)
		rcall ecris
		out portc, r17	;et la valeur basse. Exemple A=41 donc (10)
		rcall ecris
		adiw ZH:ZL,1	;incremente zh,zl et va relire l'addresse suivante
		rjmp message	
finmessage:	
		ret

;****************************Boucle de temps*******************************
;pour 10MHZ
t50us:
        ldi  R18, $A6
LOOP0:  dec  R18
        brne LOOP0
        nop
        nop
		ret

tempo2ms: ;2ms a 10mhz
        ldi  R19, $21
LOOP0e: ldi  R18, $C9
LOOP1e: dec  R18
        brne LOOP1e
        dec  R19
        brne LOOP0e
		ret

tempo10ms:
        ldi  R17, $09
LOOP0m: ldi  R18, $BC
LOOP1m: ldi  R19, $C4
LOOP2m: dec  R19
        brne LOOP2m
        dec  R18
        brne LOOP1m
        dec  R17
        brne LOOP0m
		ret

tempo300ms:
        ldi  R17, $10
LOOP0f: ldi  R18, $F8
LOOP1f: ldi  R19, $FB
LOOP2f: dec  R19
        brne LOOP2f
        dec  R18
        brne LOOP1f
        dec  R17
        brne LOOP0f
		ret

tempo5s:
		ldi r31, $10
encoreplus:
		rcall tempo300ms
		wdr
		dec r31
		brne encoreplus
		ret


;*************************** affiche 10000 1000 **************************************
afficheGate10000s:
		rcall posi1
		ldi r31,high(data34*2)  	;0x7fff 10ks S=12
		ldi r30,low(data34*2)
		rcall message
		ret
afficheGate1000s:
		rcall posi1
		ldi r31,high(data37*2)  	;0x7fff 10ks S=12
		ldi r30,low(data37*2)
		rcall message
		ret


;**************************** affichememoire *************************************
;affiche le contenu tel quel. exemple si $3a est dans temp 3a sera afficher
affichememoire:
		push temp
		push temp
		swap temp		;exemple 3A
		andi temp, $0f	;on garde le  3
		ldi r31,high(hexa*2) ;pointe l'addresse le la database dans R0
		ldi r30,low(hexa*2)	; l'addresse de mémoire;
		add ZL, temp		;augmente l'adresse pour pointer le bon chiffre (r31 et r30 constitue zh et zl)
		brcc okpasdedepassementq	;(branch if carry est 0) si le carry est a 1 (il y a une retenue) = plus que FF on incrémente donc zh. Sinon il passe et laisse zl normal
		inc zh
okpasdedepassementq:
		lpm
		mov temp,r0
		rcall afficheascii	;3 est afficher
		pop temp
		andi temp, $0f	;on garde le  3
		ldi r31,high(hexa*2) ;pointe l'addresse le la database dans R0
		ldi r30,low(hexa*2)	; l'addresse de mémoire;
		add ZL, temp		;augmente l'adresse pour pointer le bon chiffre (r31 et r30 constitue zl et zh)
		brcc okpasdedepassement7q	;(branch if carry est 0) si le carry est a 1 (il y a une retenue) = plus que FF on incrémente donc zh. Sinon il passe et laisse zl normal
		inc zh
okpasdedepassement7q:
		lpm
		mov temp,r0
		rcall afficheascii	;3 est afficher
		pop temp
		ret

;***************************** Led ******************************************
;Led
WarmingLedPulse:
		cbi ddrb, 0		;on met la pin du led en entree pas de pull up. Comme ca, c'est le module gps qui drive le led.
		cbi portb, 0
		ret
SatLedOn:				;PD7
		sbi portd, 7
		ret
SatLedOff:
		cbi portd, 7
		ret
CounterLedOn:			;PD6
		sbi portd, 6
		ret
CounterLedOff:
		cbi portd, 6
		ret


