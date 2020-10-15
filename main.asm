;Counter YT
.Org $0000
.include "int_atmega328p.inc"

;définition des régistres.
.def temp =R16	
.def temp2=r17

;memoire
.equ comptel = $100				;flag. Si = 1 = ca compte
.equ compteh = $101
.equ GateTime = $104			;1 = default = 1000s
.equ frequence_1 = $109
.equ frequence_2 = $10a
.equ frequence_3 = $10b
.equ frequence_4 = $10c
.equ frequence_5 = $10d
.equ byte = $121
.equ frebcd1 = $127
.equ frebcd2 = $126
.equ frebcd3 = $125
.equ frebcd4 = $124
.equ frebcd5 = $123
.equ frebcd6 = $122
.equ pwmphase6h = $12b
.equ pwmphase6l= $12c
.equ echantillon_timel = $12e
.equ echantillon_timeh = $12f
.equ eeprompointer = $134
.equ satelliteh = $136
.equ satellitel = $137
.equ affichesatelliteflag = $138
.equ heureh= $220
.equ heurel= $221
.equ minuteh= $222
.equ minutel= $223
.equ secondeh= $224
.equ secondel= $225
.equ ledcompteurflag = $227
.equ ledcompteurflag2 = $228
;memoire lattitute longitude
.equ gga = $240 ; ne rien mettre en haut de 240 car la string que je garde est assez longue. 40 bytes ou plus

.eseg 
;.db $98,$E9 ;genere un fichier eeprom lors de la compilation avec les valeurs de .eseg
.db $84,$CA
.CSEG	;code segment. 
.include "m328pdef.inc"		;instruction jmp utiliser pour interrupt
.include "macros.inc"
.include "afficheur.asm"
.include "math.inc"
.include "eeprom.asm"
.include "serial.asm"

;********************************* RESET *******************************************
;***********************************************************************************
RESET:	ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp 

;init memory to 0
		rcall ClearAllMemory ;dans math
		rcall WDT_off	;doit mettre a off selon datasheet pour protection. Peut s'enabler tout seul.
		rcall ClrAllRegister
;break
;direction des ports
		ldi temp, 0b00010011
		out ddrb, temp	;port b en sortie pour pwm et un led pb0. PB4 en sortie avec 0v pour detection avec pb5 en entree(jumper)
		com temp
		out portb,temp	;met les pull up sur les entrées et met 0v sur les sorties. Le LED sur pb0 warming est off
		ser temp
		out ddrc, temp	;afficheur portc en sortie
		ldi temp, 0b11100010
		out ddrd, temp	;en entree (int0,1) pd1, pd5,6,7 en sortie
		com temp		;inverse temp pour activer les pullup sur pd0,2,3,4 et mettre pd1,5,6,7 a 0
		out portd, temp	;pull up 
		clr temp
		out portc, temp	;afficheur tous les broches du port C a 0
;ferme le led warming et active le sharing led
		rcall WarmingLedPulse
;interrupt *************************************************************************
		ldi temp, (0<<int0)|(0<<int1)	;active int1 push button seulement pour commencer. 
		out EIMSK,temp		;active int1 dans External Interrupt Mask Register – EIMSK
		ldi temp, (1<<ISC01)|(1<<ISC00)|(1<<ISC11)|(0<<ISC10)	;falling edge les 2
		sts eicra, temp
;initialisation du pointeur de eeprom
		ldi temp, $02	;on commence a ecrire a l'adresse 2. On garde 0,1 pour le pwm config
		sts eeprompointer, temp
;init flag
		;tous les flags sont a 0 par ClrAllMemory
;init serial uart
		RCALL USART_Init
;init afficheur
		rcall reset_afficheur
		rcall videecran
		rcall posi1
		ldi r31,high(data7*2)  		;"counter yt 1.01"    Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
		ldi r30,low(data7*2)		;cette addresse se retrouve dans le registe Z. Qui est constitué en fait
		rcall message
		rcall nextline
		rcall tempo5s
		rcall videecran

;initialise le pwm 16 bits pour regler mon ocxo a 10mhz pile
		ldi temp,$FF		;set le top			*******************  TOUJOURS LOADER VALEUR H EN PREMIER sinon fonctionne pas. J'ai chercher longtemps sacrement lol
		sts icr1h, temp		;					*******************  TOUJOURS LOADER VALEUR H EN PREMIER
		ldi temp, $FF		;FFFF = 65535 pour 16 bit de resolution.
		sts icr1l, temp
		ldi temp, (1<<COM1A1)|(1<<WGM11)|(0<<WGM10)	;mode 14 fast pwm top = ICR1
		sts tccr1a, temp
		ldi temp, (1<<WGM12)|(1<<WGM13)|(1<<CS10)	;no prescaler   -----> 0<<CS10=off  1<<CS10=on
		sts tccr1b, temp
		ldi temp, $84	;ffff = 100 7fff = 50%
		sts ocr1ah, temp
		ldi temp, $1d		
		sts ocr1al, temp
;*********************************************************************************************************************************
;PUSH  BUTTON et EEPROM ***********************************************************************************************************
;*********************************************************************************************************************************
;Sonde le push button, si pushbutton est enfonce = reset eeprom par valeur default 
		sbic pind, pd3		;(Skip if Bit in I/O Register is Cleared)
		rjmp ButtonNotPressed			
		rcall videecran		;push button est appuyé = reset default
		rcall posi1
		ldi r31,high(data20*2)  	;Set to default                Ici on va chercher l'addresse mémoire ou se retrouve le data à afficher.
		ldi r30,low(data20*2)		;cette addresse se retrouve dans le registe Z. Qui est constitué en fait du registre R31 et R30. Z est en fait 16 bits de long.								
		rcall message				;dans message, on affiche ce que pointe Z "ceci est un test"
		call nextline
		rcall effaceeeprom
		rcall tempo5s
ButtonNotPressed:	

;compteurs
;*********************************************************************************************************************************
;**************************************************** compteurs timer0 ***********************************************************
;*********************************************************************************************************************************
ytyt:
;overflow du timer0
		ldi temp, (1<<TOIE0)	;active interupt overflow
		sts timsk0, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		clr temp	
		out tcnt0, temp		;met le compteur a 0 au cas
watchdogsetup:	;active int watchdog 1 secondes. Si le gps pulse manque un pulse. Le watchdow timeout et on passe en mode selfrunning
		wdr		;Au debut je croyais que 1 seconde serait trop court car on a seulement un wdr a chaque seconde. Après test, aucun probleme, J'imagine que le watchdog est un peu plus lent.
		ldi temp, (1<<WDCE)|(1<<WDE) ;toujours envoyé ces 2 valeurs en premier, ensuite en dedans de 4 clock nous pouvons changer le registre
		sts	WDTCSR,temp
		ldi temp, (0<<WDE)|(1<<WDIE)|(0<<wdp3)|(1<<wdp2)|(1<<wdp1)|(0<<wdp0) ;enable watchdog 1s. interrupt seulement pas de reset
		sts WDTCSR,temp


;***********************************************************************************************************************************
;***********************************************************************************************************************************
;***************************************************        Run      ***************************************************************
;***********************************************************************************************************************************
runmodeprep1:
		rcall videecran
runmodeprep:
		rcall CheckForTimeGate
		lds temp, GateTime
		cpi temp, 1
		brne Gate10ks
		rjmp Gate1ks
Gate10ks:
		rcall affichegate10000s	;Gate 10000s on lcd and serial
		rcall espace
		rcall virguleserial
		rcall affichesatellite2
		rcall virguleserial
		ldi temp,$10	;1000
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		ldi temp,$27
		sts echantillon_timeh,temp
		rjmp Retour_en_mode_interrupt

Gate1ks:
		rcall affichegate1000s	;Gate 1000s on lcd and serial
		rcall espace
		rcall espace
		rcall virguleserial
		rcall affichesatellite2
		rcall virguleserial
		ldi temp,$e8	;1000
		sts echantillon_timel, temp	;nombre de seconde a echantilloner
		ldi temp,$03
		sts echantillon_timeh,temp
		rjmp Retour_en_mode_interrupt

;*********************************************************   CheckForTimeGate*************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
CheckForTimeGate: ; grab if pd4 is 0 or 1
		sbis pind, pd4	;si jumper is on saute la ligne
		rjmp willbe10000
		ldi temp, 1
		sts GateTime, temp			;By default GateTime will be 1 by pull up
		ret
willbe10000:
		clr temp
		sts GateTime, temp			;With switch to gnd Gatetime will be 0
		ret


;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   TIM0_OVF *    ***************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
TIM0_OVF:	;viens ici a APRES chaque 256 clock a l'aide le int overflow
;			In normal operation the	Timer/Counter Overflow Flag (TOV0) will be set in the same timer clock cycle as the TCNT0 becomes zero
;Important: Si le dernier pulse arrive dans cette interruption. Celui ci sera fait apres. DOnc le sample aura 4,5,6 tic de trop.
;Je n'ai aucun moyen de corriger ca. Par chance, Vu que je roule a 10 mhz pile, si le dernier pulse n'arrive pas dedans, il n'arrivera donc jamais dedans.
;Et si il arrive toujours dedans, il va etre toujours dedans. Dans ce cas je changerai ou ajouterai une boucle de temps au depart.
;Apres test le dernier pulse arrive a 00 en phase 2,4,5,6 et a 80 a 1 et 2.
;Reponse. Il vient ici avant le dernier latch car le compteur est parti a 7,8 tic en retard, Donc il vient ici 7-8 tic avant la fin. Quand le compteur est arreté dans l'interruption latch. Il est rendu a 0 a ce moment.
;En aucun cas l'interruption latch peut arriver en même temps que un timer overflow pour cette raison.
		ldi temp, $ff
		cp xl, temp			;tcnt0 monte a FF et retourne a 0. Un intterruption survien et on arrive ici. 
		cpc xh, temp		;On incremente x et regarde si le registre x est rendu plein, compare a $FFFF
		breq incy			;x est incrementé de 1 a chaque 256 clock. quand x = FFFF on monte y de 1 (ca prend un clk et ffff monte a 10000) et on remet x a 0.
		adiw xh:xl, $01		;monte de 1 le registre x de 16 bit: X vaut (FFFF+1) x $100 = $10,00,00 1000000 (6 zero)
;scan gatetime si la gate a changé on restart avec le nouveau gatetime
		lds temp, gatetime ;1
		push temp ;1
		rcall CheckForTimeGate ;0
		lds temp2, gatetime	;0
		pop temp ;1
		cp temp, temp2
		breq canapaschange
		rcall CounterLedOff
		rcall nextline
		sbi eifr, 1
		ldi temp, 0b00000010	;remove int1 flag pour etre encore plus sur. (je l'ai déja vu 2 fois de fille comme l'interrupt se faisait 2 fois.
		store eifr, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		ldi temp,0b00000001
		store TIFR0, temp		;annule timer l'overflow si il y a eu un
		rjmp onnettoie2
canapaschange:
;toggle led buffer
;ici je fais clignotter la led count. Si jamais le uC plante on s'en appercoit. La led est solid on ou off
;vitesse du clignottement: (1/10E6) x 256 x (256x4) = 26.21 ms ca toggle. Donc 26ms hi 26ms low. 26x2 = un cycle. 1/(26.21msx2) = 19.07 hz
		load temp, ledcompteurflag
		inc temp
		store ledcompteurflag, temp
		cpi temp, $ff
		brne onsenpasse
		load temp, ledcompteurflag2
		inc temp
		store ledcompteurflag2, temp
		cpi temp, $4
		brne onsenpasse
;toggle le led counter
		load temp, portd
		sbrs temp, 6
		rjmp onturnon
		load temp, portd
		cbr temp, 0b01000000
		out portd, temp
		clr temp
		sts ledcompteurflag, temp
		sts ledcompteurflag2, temp
		reti
onturnon:
		load temp, portd
		sbr temp, 0b01000000
		out portd, temp
		clr temp
		sts ledcompteurflag, temp
		sts ledcompteurflag2, temp
onsenpasse:
		reti

incy:						;y vaux (1,00,00,00)...
		adiw yh:yl, $01		;On monte y et on remet x a 0
		clr xl
		clr xh
		reti
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   Push button   ***************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
pushbutton:		;dans le mode warming up 15 minute. Push button génere aussi un interruption. On regarde ici si elle arrive derant le 15 minutes

		call nextline
;ici on veut afficher l'heure. On sait que le bouton a été appuyer dans le mode count. On doit donc tout rénitialiser car ici on bypass le reti. C'est pas évident de fonctionner ainsi
;mais j'ai pas le choix.
		wdr
		clr temp
		sts affichesatelliteflag, temp ;empeche le nombre de satellite de s'afficher. deja mis a 0 auparavent mais eu un bug que ca affichait.
;ferme le led warming car si le push button est appuyé plusieurs fois de suite lors du warming. Le les du pulse reste allumer car le push button genere 2 interruptions et le WAIT na pas le temps de
;fermer le led
		cbi ddrb, 0
		cbi portb, 0
;ferme le led counter
		load temp, portd
		cbr temp, 0b01000000
		out portd, temp
;affiche heure et position. (dure 20 secondes)
		rcall afficheheureposition ;se trouve dans serial
;affiche eeporom
		rcall affiche_eeprom ;(se trouve dans eeprom.asm)
		rcall seconde_tempo
		wdr	
;on doit tout rénitialiser car on revient ici par interruption push button quand on etait en train de compter. Donc on remet a 0 et on
;retourne à la phase ou nous etions
		sbi eifr, 1
		ldi temp, 0b00000010	;remove int1 flag pour etre encore plus sur. (je l'ai déja vu 2 fois de fille comme l'interrupt se faisait 2 fois.
		store eifr, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		clr temp	
		out tcnt0, temp		;remet le compteur a 0
		sts comptel, temp	;initialise le flag compte. Il part a 0
		sts compteh, temp
		rcall clrallregister
		ldi temp,0b00000001
		store TIFR0, temp		;annule timer l'overflow si il y a eu un
		sbi eifr, 1
		ldi temp, 0b00000010	;remove int1 flag pour etre encore plus sur. (je l'ai déja vu 2 fois de fille comme l'interrupt se faisait 2 fois.
		store eifr, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		ldi temp,0b00000001
		store TIFR0, temp		;annule timer l'overflow si il y a eu un
		rjmp onnettoie2

;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
;*********************************************************   Latch gate    ***************************************************************
;*****************************************************************************************************************************************
;*****************************************************************************************************************************************
Latch:
; Un pulse arrive chaque seconde. On calcul le nombre de hertz a l'aide du compteur 8bit en incrémentant le registre x et y.
; meme nombre de clock (operations) pour partir ou arreter le compteur pour que ca balance.
; un probleme peut survenir. Le compteur tcnt0 compte sans arret.
; si l'interruption arrive quand tcnt0 est a 254... il se créé un overflow pendant l'interruption. Par contre le flag reste en suspand et n'est pas pris en compte
; tout de suite car les int sont disable durant le traitement de celle ci.
; le comprteur est donc faussé car tcnt0 est additionné au total mais maintenant il vaut seulement 0 ou 1 car il a recommencé.
; par contre l'interruption en mémoire est executé aussitot sorti de cette interruption et les 256 clock de perdu sont additionné au prochain.
;***IMPORTANT** finalement l'overflow se gere comme un neuvieme bit qui vaut (256) $100. Simplement ajouter le tcnt0 + $100 quand le tov0 est a 1
; jai donc inclus du code pour gerer le bit overflow quand cela se produit
;*** important: J'ai lu apres dans le datasheet: tov0 peut etre considéré comme un 9iem bit!!! Plus facile de penser comme cela. il passe a 1 en meme temps qu'il passe tcnt0 a 0.

		lds r16, compteh ;compte est incrementé a chaque seconde
		lds r17, comptel
		lds r18, echantillon_timeh	;on echantillone combien de temps ???? C'est ici
		lds r19, echantillon_timel
		cp r17, r19
		cpc r16, r18
		breq off
		wdr	;reset watchdog et balance le depart et l'arret 16 cycles exactement juste apres l'interrupt. Tous les cycles sont important et doivent etre compte.
		ldi temp, (1<<CS00)	;start counter 8 bit
		out TCCR0B,temp

	;peux ajouter du code ici sans changer le resultat du count mais ne doit pas depasser 256 clock
	;pourquoi... parce que ici les interruption sont deactivé. Si ca prend plus que 256 clock le compteur tcnt0 va faire un ou plusieur overflow mais ne sera
	;pas pris en compte car il y a un buffer de seulement 1 interruption.

		lds zh, compteh
		lds zl, comptel
		adiw zh:zl, 1
		sts compteh, zh
		sts comptel, zl
		reti
off:
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		clr temp
		sts compteh, temp	;remet le compteur a 0
		sts comptel, temp
		wdr
		cli		;arrete tous les futurs interruptions

		load temp, portd
		cbr temp, 0b01000000
		out portd, temp

;ici on doit gerer la valeur de x et y qui s'est accumulé dans l'echantionnage
;(xh:xl x $100) + (yh:yl x $1000000) + le reste du compteur tcnt0 + overflow (256) si actif = nombre de clock écoulé total.

;r21:r20 x r23:r22 = r5:r4:r3:r2
		mov r21, xh	;x x 256
		mov r20, xl
		ldi r23, $01		;$100 = 256
		ldi r22 ,$00
		rcall mul16				;M1M:M1L x M2M:M2L = res4:res3:res2:res1 = r5:r4:r3:r2
		push r2		;conserve la reponse
		push r3
		push r4
		push r5
		push yh	;conservons y
		push yl
;y x 1000000
;* r23:r22:r21:r20 x  r19:r18:r17:r16   =  r27:r26:r25:r24:r23:r22:r21:r20	(seulement r24 a r20 se remplissent) r24 vaut 2 a 9 000 000 000hz
		rcall clrallregister	;clr toute les registre de 16 a 31
		pop yl
		pop yh
		mov r20, yl			;r32,r22,yh,yl
		mov r21, yh
		ldi r19, $01		;$01:00:00:00 = $10000000 x Y
		rcall mul32			;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
;additionons les 2
		pop r19			;reponse de x (x x 256)
		pop r18
		pop r17
		pop r16
		clr r25
		add	r20,r16		;Addition des octets de poids faible
		adc	r21,r17	
		adc	r22,r18	
		adc	r23,r19		;Addition des octets de poids fort avec retenue
		adc r24, r25	;conserve le carre dans r24 
		;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
;ajoutons tcnt0
		in r16, tcnt0	;r16 = tcnt0
		clr r17
		clr r18
		clr r19
		clr r25
		add	r20,r16		; Addition des octets de poids faible
		adc	r21,r17	
		adc	r22,r18	
		adc	r23,r19		;Addition des octets de poids fort avec retenue
		adc r24,r25
		;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
;test overflow bit
		sbis TIFR0, tov0	;skip if bit is set (bit overflow)  Si il y a eu overflow entre l'interrup et l'arret on ajoute 256
		rjmp fiou
		ldi temp, (1<<TOV0)	;annule l'overflow pending et la future interruption par le fait meme. Faire a la main car reti est bypassé.
		out tifr0, temp
		clr r16
		ldi r17,$01		;additionne 256
		clr r18
		clr r19
		clr r25
		add	r20,r16		;Addition des octets de poids faible
		adc	r21,r17	
		adc	r22,r18
		adc	r23,r19		;Addition des octets de poids fort avec retenue
		adc r24,r25
;reponse dans r27:r26:r25:r24:r23:r22:r21:r20
fiou:
		sts frequence_1, r20
		sts frequence_2, r21
		sts frequence_3, r22
		sts frequence_4, r23
		sts frequence_5, r24	;dans 10000 secondes r24 monte a 2

;stop: rjmp stop
;ici le nombre de hertz par seconde est dans la memoire frequence en HEX
;convertissons HEX to BDC
;	r20:r19:r18:r17:r16	    >>>   	r25:r24:r23:r22:r21
		lds r20, frequence_5
		lds r19, frequence_4
		lds r18, frequence_3
		lds r17, frequence_2
		lds r16, frequence_1
		rcall hex2bcdyt		;conversion bcd	;fonctionne bien pas de bug testé avec afficheur ca concorde.
		sts frebcd1, r21
		sts frebcd2, r22
		sts frebcd3, r23
		sts frebcd4, r24
		sts frebcd5, r25
		sts frebcd6, r26
;**************************************** On affiche ***********************************
		rcall posi2
		rcall effaceligne
		rcall posi2
		lds temp, GateTime
		cpi temp, $1
		brne displaymhz10000
;gate 1000 10000000.000  Hz
displaymhz1000:						;j'ai   01 00 00 00 00 00  ou  00 99 99 99 99 99
		rcall sendspeed1000serial
		lds temp, frebcd6		;j'affiche:        10000000.000
		cpi temp, 0
		brne aldo1000				;si frebcd6 = 0 on affiche un espace a place
		rcall espace			;
		rjmp yahoo1000
aldo1000:
		lds temp, frebcd6
		rcall affichelsb
yahoo1000:
		lds temp, frebcd5
		rcall affichenombre
		lds temp, frebcd4
		rcall affichenombre
		lds temp, frebcd3
		rcall affichenombre
		lds temp, frebcd2
		rcall affichemsb
		ldi temp, $2e		;point
		rcall afficheascii
		lds temp, frebcd2
		rcall affichelsb
		lds temp, frebcd1
		rcall affichenombre
		rcall espace
		rcall espace
		ldi temp, $48
		rcall afficheascii
		ldi temp, $7a
		rcall afficheascii
		rcall onnettoie

;gate 10000 10000000.0000 Hz
displaymhz10000:				;10 00 00 00 00 00   ou   09 00 00 00 00 00
		rcall sendspeed10000serial
		lds temp, frebcd6		;10.000,000,000,0
		andi temp, $F0
		cpi temp, 0
		brne aldo				
		rcall espace			
		rjmp yahoo
aldo:
		lds temp, frebcd6	
		rcall affichemsb
yahoo:
		lds temp, frebcd6	 
		rcall affichelsb
		lds temp, frebcd5 
		rcall affichenombre
		lds temp, frebcd4
		rcall affichenombre
		lds temp, frebcd3
		rcall affichenombre
		ldi temp, $2e		;point
		rcall afficheascii
		lds temp, frebcd2
		rcall affichenombre
		lds temp, frebcd1
		rcall affichenombre
		rcall espace
		ldi temp, $48		;H
		rcall afficheascii
		ldi temp, $7a		;z
		rcall afficheascii

onnettoie:
		rcall eepromwritebytes ;on conserve la valeur en eeprom
onnettoie2:
		rcall clrallregister
		out tcnt0, temp
		sts comptel, temp
		sts compteh, temp
		ldi	temp,low(RAMEND)
		out	SPL,temp			; Initialisation de la pile à   
		ldi	temp,high(RAMEND)	; l'adresse haute de la SRAM
		out	SPH,temp
		rjmp runmodeprep

;********************************************************************************************************************
;********************************************************************************************************************
;********************************************************************************************************************
watchdog_overflow:
	;le module gps a perdu son antenne ou a un faible signal. Nous devons rouler sans pulse gps.
	;a partir de ce moment nous ne devons plus changer le pwm
		cli
		wdr
;etein le led counter et sattelite forcement
		load temp, portd
		cbr temp, 0b11000000
		out portd, temp
		call posi1
		call nextline
		ldi r31,high(data19*2)  	;"No pulse"
		ldi r30,low(data19*2)
		call message
		call posi2
		call nextline
		ldi r31,high(data32*2)  	;"waiting"
		ldi r30,low(data32*2)
		rcall message
		call nextline
jsjs:
		rcall tempo5s
		ldi temp, (1<<TOV0)	;annule l'overflow pending et la future interruption par le fait meme. Faire a la main car reti est bypassé.
		out tifr0, temp
		ldi temp, (0<<CS00)	;stop counter 8 bit
		out TCCR0B,temp
		rcall clrallregister
		clr temp	
		out tcnt0, temp		;met le compteur a 0 au cas
		sts comptel, temp	;initialise le flag compte. Il repart a 0
		sts compteh, temp
;ici on dois attendre la detection d'un gps pulse. donc on loop ici et quand un pulse est detecté, on affiche la bonne phase et on repart la calibration

toujoursrien:
		wdr				;empeche un autre interrupt watchdog de survenir. Sinon le flag interrupt watchdog se met a 1 et un autre interrupt watchdog est excuté aussitot sei embarqué
		sbic pind, pd2
		rjmp toujoursrien
		rjmp runmodeprep1

;*******************************************************************************************************************
;*******************************************************************************************************************
;watchdog off vient du datasheet
WDT_off:
		cli
		wdr
		in r16, MCUSR
		andi r16, ~(1<<WDRF)
		out MCUSR, r16
		lds r16, WDTCSR
		ori r16, (1<<WDCE) | (1<<WDE)
		sts WDTCSR, r16
		ldi r16, (0<<WDE)
		sts WDTCSR, r16
		ret
;****************************************************************** retour en mode interrupt ************************************************************
;****************************************************************** retour en mode interrupt ************************************************************
;****************************************************************** retour en mode interrupt ************************************************************
Retour_en_mode_interrupt:
		ldi temp, (1<<int1)|(0<<int0)	;deactive int0 interrup gps pulse
		out EIMSK,temp					;deactive int0 dans External Interrupt Mask Register – EIMSK
		wdr
		in temp, MCUSR			;enleve le watchdog interrupt pending avant le sei.
		andi temp, ~(1<<WDRF)
		out MCUSR, r16	
		sei ;active les interrupt (watchdog seument pour senser le pulse)
		;boucle de temps pour laisser le voltage du pwm se stabilisé (condensabeur chargé) peut etre pas nécessaire mais pour 2 secondes rien ne presse
		rcall seconde_tempo
		wdr
		rcall seconde_tempo
		wdr
		; Add delay to always start count at the same place.
pasencorepret:	;;ici on attend un pulse et part tout de suite apres. le but est de balancer le pulse de la fin pour qu'il n'arrive pas en meme temps qu'un timer ovf
		sbic pind, PD2
		rjmp pasencorepret
		wdr
pasencorepret2:
		sbis pind, PD2
		rjmp pasencorepret2
		wdr		;viens tous juste des passer a 5v
		rcall clrallregister
		ldi temp, 0b00000011	;enleve les interrupt pending avant l'activation des interrupt
		store eifr,temp
		ldi temp, (1<<int1)|(1<<int0)	;active int0 interrup gps pulse   ---->1<<int1 = push button active
		out EIMSK,temp					;active int0 dans External Interrupt Mask Register – EIMSK
		wdr	
.include "NopLoop.asm"
;