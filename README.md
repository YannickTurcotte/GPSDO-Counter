# GPSDO-Counter
Frequency counter. Need 1 pulse per second. Gate is 1000 seconds or 10000 seconds.


My gpsdo is also a frequency counter. If you already have a gpsdo and need a counter, this is for you.
I did this modification for Paul. He was looking for a counter to his gpsdo (Lars version)
If you want more information, this is his blog: 

http://www.paulvdiyblogs.net/2020/10/monitoring-measuring-logging-gpsdo.html
http://www.paulvdiyblogs.net/2020/07/a-high-precision-10mhz-gps-disciplined.html

# Lest's start
Now our counter. We need my gpsdo schematic here:
https://www.instructables.com/GPSDO-YT-10-Mhz-Lcd-2x16-With-LED/

You do not need to have all the parts. Important are:
-10mhz clock in
-Capacitor on reset and button pd3 if used
-Capacitor between 0-5v
-An output to see the result---> Lcd, com port or both 

Programming need to have the same fusebit. But i suggest to enable the brown-out detector so fd instead ff--->FD, D9, E0


You can send the TX pin 3 to a rx uart 9600 8 1 for monitoring.
You can install the display if you need to.
Led are enabled except RUN led. this one stay off.

When pd4 (pin 6) is high = 1000s gate  (By default, internal pull up is enabled)
When pd4 (pin 6) is low = 10000s gate
If you change toggle pd4 while counting. The count is stopped et restart with the choosen gate time.

When pd3 (pin 5) is low, counting is stopped. UTC time wil be displayed following by the gps location for 10 seconds.
This feature isn't very important for the counter. But it was already coded in my gpsdo and i keep.

The nop loop is very important. It assure to take only one cycle to enter in an interrupt.
If you bypass the loop it will works. But the count will be +- .002 instead .001

If no pulse is detected. Counting stop and a message will be displayed.

Enjoy
