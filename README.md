# GPSDO-Counter
Frequency counter. Need 1 pps pulse. Gate is 1000 seconds or 10000 seconds

My gpsdo is also a frequency counter. If you already have a gpsdo and need a counter, this is for you.
I did this modification for Paul. He was looking for a counter to his gpsdo (Lars version)
If you want more information, this is his blog: http://www.paulvdiyblogs.net/2020/07/a-high-precision-10mhz-gps-disciplined.html

# Lest's start
Now our counter. We need my gpsdo schematic here:
https://www.instructables.com/GPSDO-YT-10-Mhz-Lcd-2x16-With-LED/


You can send the pin 3 to a rx uart 9600 8 1 for monitoring.
You can install the display if you need to.
Led are supported execpt RUN led. this one stay off.

When pd4 (pin 6) is high = 1000s gate  (By default, internal pull up is enabled)
When pd4 (pin6) is low = 10000s gate

If you change toggle pd4 while counting. The count is stopped et restart with the choosen gate time.

Enjoy
