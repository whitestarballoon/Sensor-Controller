White Star Internal Sensor Controller Arduino Project

Purpose:
	Hi.  This code's purpose is to collect sensor data when requested. 
	A request comes over I2C bus from the Flight Computer to begin the
	sensor collection batch run, and then this code polls all the sensors
	and sends back the data to the Flight Computer.

Contents:
	• internalsensorboard - the actual arduino code project folder
	• XBee - the arduino library for xbee communications


NOTE:  You must install the XBee library files into the appropriate
	place for arduino libraries.   I can't remember where that is.

Arduino Hardware:

	This has been intended to run on the Arduino FIO board, make sure to
	choose that model in the Board menu when compiling and uploading.  
	The White Star schematics for this board that the FIO is plugged 
	into are available on Github at:
	https://github.com/whitestarballoon/Sensor-Controller THERE IS NO 
	ACCESS TO THE HARDWARE RESET BUTTON.  To reset the White
	Star Sensor Controller FIO board, use RealTerm on the com port, and
	toggle the RTS line. FIO RUNS ON 3.3v - Analog measurements read 
	0 to 3.3v as 0-1024.
	
Connected Devices:
	• I2C Bus - Full of other devices that talk all the time.  Hard to
	  get a word in edgewise.
	• XBee in the XBee Socket - Connects wirelessly to an XBee up in the
	  tippy top of the Balloon.  VERY CRITICAL SCIENCE.  This will not be
	  connected while programming, it interferes with the ability to program. 
	  A user must be present to insert it AFTER loading code, and REMOVE it
	  before loading code again.
	• Cloud Sensor - Sparkfun Dust Particle Sensor
	• Humidity Sensor - HIH-???? Analog humidity sensor, outputs 0.6 to
	  3.6v.
	• Temperature sensors - TMP100s or TMP101s on the I2C bus
	• Go Pro Hero HD Camera - single logic line hold down starts the 
	  recording sequence, and a longer holddown stops it.

Scientific Concerns:

Frost Detection
	Frost will kill a balloon by adding weight.  To detect if this is
	happening, we must very precisely know the dew point and frost point. 
	To find those very precisely we must do the following things:
	• Measure Humidity and Temperature at the same time (or really quickly
	  after one another)
	• Compensate the humidity reading with the manufacuturer's instructions
	  based on temperature

Cloud Detection
	Clouds might also contribute to the downing of a balloon.  To detect
	clouds of ice crystals, we have a Sparkfun Dust Sensor that uses
	reflected infrared light to detect cloud particles.  The dust sensor
	outputs an analog voltage proportional to the amount of light reflected
	off the particles that go through the detector.  Several readings should
	be averaged over a short time.

Thanks,
Dan Bowen
Project Lead
White Star Balloon Project
Louisville KY 
2012
dan@whitestarballoon.org