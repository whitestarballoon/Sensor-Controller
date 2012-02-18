boolean DEBUG = 1;// 1 enable 0 disable
boolean SLEEPENABLE = 0;
//#define WATCHDOGENABLE
#include <avr/wdt.h>
#include <avr/sleep.h>
#include <avr/power.h>
#include <XBee.h>
#include <Wire.h>
/* define/reserve the pins */
#define cloud_LEDPIN 11    //for cloud sensor detector
#define SDAL_PIN 4  //whitestar I2C bus data line
#define SCLL_PIN 5  //whitestar I2C bus clock line
#define xbeereset 4 // fio pin 4 to reset xbee
#define HUMID_ANALOGPIN 7     //for humidity sensors output
#define cloud_ANALOGPIN 6    //for cloud sensors output

/* Camera PINS  */
#define CAMSWITCH 7 //      --control Camera power


unsigned long looptime; 
static int MY_I2C_ADDRESS = 0xA;  //my address  0x14
int isb_command;  // command given by da boss
/* ----- Variables support polling SHARP GP2Y1010AU0F dust sensor --- */
#define TOOBIG_ULONG 0xFFFFD8F0  /* constant is the unsigned long limit - 10000 */
unsigned long last_microsec;
unsigned long sched_microsec;
static unsigned int cloud_sum;
static unsigned int runsum;
static int runct;
static int errorcount;
static uint16_t freshcloud;
static uint16_t freshtemp;
static uint16_t freshhumid;
volatile boolean f_wdt=1; //watchdog global flag
int CamState = 0;
unsigned long CamTimer;
int recording = 0;
unsigned int wakecnt; //counts the number of times the system has gone through global loop after waking up
/*
FIO with Series 2 (ZigBee) XBee Radios only
 Receives I/O samples from a remote radio.
 The remote radio must have IR > 0 and at least one digital or analog input enabled.
 The XBee *** coordinator *** should be connected to the Arduino.
 */
// empirical calibration of thermistor curve -- log(R) vs. deg C
#define COEFF_XSQ   1.173974
#define COEFF_X   -44.498088
#define COEFF_K   335.674531

// Predetermined value of reference resistor in actual circuit 
#define R_REF     98600.0

XBee xbee = XBee();
ZBRxIoSampleResponse ioSample = ZBRxIoSampleResponse();

ISR(WDT_vect) {
  //****************************************************************  
  // Watchdog Interrupt Service is executed when watchdog times out 
  // without this the thing will just reset the program like a big jerk
  f_wdt=1;  // set global flag
}

void setup_watchdog(int ii) {
  //****************************************************************
  // 0=16ms, 1=32ms,2=64ms,3=128ms,4=250ms,5=500ms
  // 6=1 sec,7=2 sec, 8=4 sec, 9= 8sec

  byte bb;
  int ww;
  if (ii > 9 ) ii=9;
  bb=ii & 7;
  if (ii > 7) bb|= (1<<5);
  bb|= (1<<WDCE);
  ww=bb;
  Serial.println(ww);
  MCUSR &= ~(1<<WDRF);
  // start timed sequence
  WDTCSR |= (1<<WDCE) | (1<<WDE);
  // set new watchdog timeout value
  WDTCSR = bb;
  WDTCSR |= _BV(WDIE);

}


void newdelay(int time)
{
  unsigned long start; 
  start = millis();
  while (millis() <= start+time){
  }
}

void system_sleep() {  
  // set system into the sleep state 
  /* The 5 different modes are:
   *     SLEEP_MODE_IDLE         -the least power savings wakes on serial
   *     SLEEP_MODE_ADC          -cpu noise reduction mode
   *     SLEEP_MODE_PWR_SAVE
   *     SLEEP_MODE_STANDBY
   *     SLEEP_MODE_PWR_DOWN     -the most power savings */

  set_sleep_mode(SLEEP_MODE_PWR_DOWN); // sleep mode is set here

  sleep_enable();  // enables the sleep bit in the mcucr register so sleep is possible. just a safety pin

  //Turn OFF unused modules to pull even less power. 
  // not really necessary with  SLEEP_MODE_PWR_DOWN
  //power_adc_disable();
  // power_spi_disable();
  // power_timer0_disable();
  // power_timer1_disable();
  // power_timer2_disable();
  // power_twi_disable();

  sleep_mode();     // System sleeps here
  sleep_disable();  // System continues execution here when watchdog timed out 
  power_all_enable(); // Turn EVERYTHING back on.
}

/* ------- I2C stuff that needs to be done  ------- */
void receiveEvent(int howMany)
{
  while (Wire.available() > 0)
  {
    isb_command = Wire.receive();
  } 

  if (1 == DEBUG)
  {
    Serial.print( "i2cr ");
    Serial.println(isb_command);
  }
}//end receiveEvent()

void requestEvent()
{    
  byte reply_data[2];
  if (1 == DEBUG)
  {
    Serial.print("itc ");
    Serial.println(isb_command);
  }



  switch (isb_command) 
  { //toggle debuging mostly enable it

  case 0x1:
    { 
      if (1 == DEBUG) 
      {
        DEBUG = 0;
      }
      else
      {
        if (0 == DEBUG)
        {
          debugsetup();
          DEBUG = 1;
        }
      }
      break;
    }  


  case 0x2:
    { //toggle sleepmode
      break;
    }
  case 0x4:
    { //humidty sensor
      reply_data[0] = (byte) (freshhumid / 256);
      reply_data[1] = (byte) (freshhumid % 256);
      Wire.send(reply_data,2);
      if (1 == DEBUG)
      {
        Serial.print("H ");
        Serial.println(freshhumid);
      }
      break;
    }  //end humidty case

  case 0xA:
    {//xbee temp sensor
      reply_data[0] = (byte) (freshtemp / 256);
      reply_data[1] = (byte) (freshtemp % 256);
      Wire.send(reply_data,2);
      if (1 == DEBUG)
      {
        Serial.print("x ");
        Serial.println(freshtemp);
      }
      break;
    }//end xbee temp sensor case

  case 0xE:
    { //record camera for 5 min
      if (1 == DEBUG)
      {
        Serial.println("CMD CAMERA 5 Min Record");
      }
      	CamTimer= millis()+300000;
	recording=2;
	CamState=10;
      	break;
    }

  case 0xC:
    { //start camera record on command
      if (1 == DEBUG)
      {
        Serial.println("CMD CAMERA ON");
      }
      CamState=10;
	recording=1;
      break;
    }

  case 0xD:
    {  //stop camera on command
      if (1 == DEBUG)
      {
        Serial.println("CMD CAMERA OFF");
      }
      CamState=0;
      break;
    }

  case 0x9:
    {//particulate sensor  
      reply_data[0] = (byte) (freshcloud / 256);
      reply_data[1] = (byte) (freshcloud % 256);
      Wire.send(reply_data,2);
      if (1 == DEBUG)
      {
        Serial.print("c ");
        Serial.println(freshcloud);
      }
      break;
    }//end particulate sensor case


  default :
    if (1 == DEBUG)
    {
      Serial.println("fail");
    }
    reply_data[0] = (byte)255;
    reply_data[1] = (byte)255;
    Wire.send(reply_data,2);
    break; 

  }//end switch isb_command
} //end requestEvent()






/* ---------- Sensor stuff -------------- */

void init_cloud_sensor(void)
{
  pinMode(cloud_LEDPIN,OUTPUT);
  sched_microsec = 0;

}

int watch_cloud_sensor(int num_rdgs_in_ct)
{

  int val;
  /* enforce 10 ms delay between pulses, but only delay if needed */
  while (micros() < sched_microsec)  /* wait until next pulse scheduled */
  {
  }

  /* done waiting -- set up the next 10 ms schedule */
  sched_microsec = micros() + 10000; 

  /* if microsecond clock is about to wrap around (once per 70 minutes),
   avoid hangup by not scheduling within 10 ms of limit value */

  if (sched_microsec >= TOOBIG_ULONG)
  {
    sched_microsec = 0;  /* waits a little longer but avoid hangup 
     as long integer wraps around */

  }

  /* Ready now to actually send pulse to sensor */
  //   specified LED pulse is 320 microseconds, with 10 ms cycle time
  digitalWrite(cloud_LEDPIN,LOW); /* power on the LED */
  delayMicroseconds(280);
  int data = analogRead(cloud_ANALOGPIN); /* read the cloud value via pin 6 on the sensor */
  delayMicroseconds(40);
  digitalWrite(cloud_LEDPIN,HIGH); /* turn the LED off */
  if (1 == DEBUG)
  {
    Serial.print("cr ");
    Serial.print(runct);
    Serial.print(" ");
    Serial.println(data);
  }
  runsum += data;

  /* smooth out random variations by summing "num_rdgs_in_ct" readings */
  runct++;
  if (runct >= num_rdgs_in_ct)
  {
    cloud_sum = (runsum/runct);
    runct = 0;
    runsum = 0;
    return 1;
  }
  return 0;  
}

int read_cloud_sensor(void)
{
  runsum = 0;    
  runct = 0;
  cloud_sum = 0;
  boolean bcloud;
  do  /* takes 10 ms to look, returns TRUE every 10th look (if parameter 10) */
  {    
    bcloud = watch_cloud_sensor(10);    
  }  
  while (!bcloud);
  /* get latest available (100 ms min) sum of 10 readings */

  if (1 == DEBUG)
  {
    Serial.print("c ");
    Serial.println(cloud_sum);
  }
  return (cloud_sum);
}



int read_humid_sensor(void)
{ //get the humidity
  int htotal = 0;
  int data;
  for (int hi=0; hi <= 9; hi++)
  {
    data = analogRead(HUMID_ANALOGPIN);
    //total += analogRead(HUMID_ANALOGPIN);
    htotal += data;
    newdelay(10);
    if (1 == DEBUG)
    {
      Serial.print("hr ");
      Serial.print(hi);
      Serial.print(" ");
      Serial.println(data);
    }
  } 
  int RelHum = htotal/10;
  if (1 == DEBUG)
  {
    Serial.print("hd ");
    Serial.println(RelHum);
  }
  return (RelHum);
}



int read_temp()
{
  uint16_t uiAvalue0 = 0;
  uint16_t uiAvalue1 = 0;
  int realtemp;

  //attempt to read a packet    
  xbee.readPacket();

  if (xbee.getResponse().isAvailable()) {
    // got something

    if (xbee.getResponse().getApiId() == ZB_IO_SAMPLE_RESPONSE) {
      xbee.getResponse().getZBRxIoSampleResponse(ioSample);

      if (1 == DEBUG)
      {
        Serial.print("I/O: ");
        Serial.print(ioSample.getRemoteAddress64().getMsb(), HEX);  
        Serial.print(ioSample.getRemoteAddress64().getLsb(), HEX);  
        Serial.println("");

        if (ioSample.containsAnalog()) {
          Serial.println("a");
          // read analog inputs
          for (int i = 0; i <= 4; i++) {
            if (ioSample.isAnalogEnabled(i)) {
              Serial.print("A (AI");
              Serial.print(i, DEC);
              Serial.print(") is ");
              Serial.println(ioSample.getAnalog(i), DEC);
            }
          }
        }
      }

      if (ioSample.isAnalogEnabled(1) ) //get AREF
      {
        uiAvalue0 = ioSample.getAnalog(1);
      }

      if (ioSample.isAnalogEnabled(2) ) //get Analog temperature
      {
        uiAvalue1 = ioSample.getAnalog(2);
      }

      if (1 == DEBUG)
      { 
        Serial.print(" ui0 : ");
        Serial.println (uiAvalue0);
        Serial.print(" ui1 : ");
        Serial.println (uiAvalue1);
      }


    } 
    else {
      if (1 == DEBUG)
      {
        Serial.print("ER: ");
        Serial.println(xbee.getResponse().getApiId(), HEX);
      }
    }    
  } 
  else if (xbee.getResponse().isError()) {
    if (1 == DEBUG)
    {
      Serial.println("XError. ");  
    }
  }

  realtemp = eval_therm(uiAvalue1,uiAvalue0);
  if (127 == realtemp)
  {
    errorcount++;
  }
  else
  {
    errorcount = 0;
  }
  if (1 == DEBUG)
  {
    Serial.print("TEC: ");
    Serial.println(errorcount);
    Serial.print("TSD: ");
    Serial.println(realtemp);
  }
  if( 10 == errorcount)
  {
    if (1 == DEBUG)
    {
      Serial.println("10 errors");

    }
    digitalWrite(xbeereset,HIGH);
    newdelay(2);
    errorcount = 0;
  }
  return realtemp;
}

int eval_therm(unsigned int tval, unsigned int vval)
{
  /*12/12/2010 by GLF for LVL1 White Star Ballon Group
   (0 - 1.8 V) and other for divider battery voltage
   (also (0 - 1.8V) -- intended for input to XBee board  
   Calculation method uses thermistor voltage relative to
   battery, so the 10-bit integer analog readouts work 
   regardless of A-D range (Arduino 5V, XBee 1.8V)   
   */
  int deg_c;
  double rtherm;
  double temp;
  double log_r;

  /* NOTE:  by design force output to fit within 8 bit integers
   -128 to 126 degrees C  -  if error, 127 C
   battery voltage should ALWAYS be > thermistor voltage
   if not, keep from overflowing in calculations */
  if (vval <= tval)
  {
    return 127;    
  }   

  // convert thermistor and voltage readings to thermistor resistance
  rtherm = (((double)vval / (double)tval) - 1.0) * R_REF;
  // calculate temperature within 1 degree Celsius from thermistor resistance
  log_r = log(rtherm);
  temp = ((COEFF_XSQ * log_r * log_r)  +
    (COEFF_X * log_r)            +
    COEFF_K);
  if ((temp < -127.4) || temp > (126.4))       
  {
    return 127;  /* error */
  } 

  if (1 == DEBUG)
  {
    Serial.print("RDG T: ");
    Serial.print(tval);
    Serial.print(" RDG V: ");
    Serial.print(vval);
    Serial.print(" Deg C: ");
    Serial.println(temp);
  }
  return (int)(temp);
}

/* ---------- Camera CONTROLS -------------------  */

void CameraSetup()
{
  // initialize pins for high impedence
  pinMode(CAMSWITCH,INPUT);
}


void CameraState()
{
//camera off	
	if ( 0 == CamState )
	{
		pinMode(CAMSWITCH,OUTPUT);
		digitalWrite(CAMSWITCH,LOW);
		CamTimer= millis() + 250;
		CamState = 1;
	}
	if ( 1 == CamState && millis() >= CamTimer )
	{
		pinMode(CAMSWITCH,INPUT);
		CamTimer= millis() + 3000;
		CamState = 2;
	}
	if ( 2 == CamState && millis() >= CamTimer )
	{
		pinMode(CAMSWITCH,OUTPUT);
		digitalWrite(CAMSWITCH,LOW);
		CamTimer= millis() + 3000;
		CamState = 3;
	}
	if ( 3 == CamState && millis() >= CamTimer )
	{
		pinMode(CAMSWITCH,INPUT);
		CamState = 0;
		recording = 0;
	}	
//Camera on
	if ( 10 == CamState )
	{
		pinMode(CAMSWITCH,OUTPUT);
		digitalWrite(CAMSWITCH,LOW);
		CamTimer= millis() + 250;
		CamState = 11;
	}
	if ( 11 == CamState && millis() >= CamTimer )
	{
		pinMode(CAMSWITCH,INPUT);
		CamTimer= millis() + 3000;
		CamState = 12;
	}
	if ( 12 == CamState && millis() >= CamTimer )
	{
		pinMode(CAMSWITCH,OUTPUT);
		digitalWrite(CAMSWITCH,LOW);
		CamTimer= millis() + 250;
		CamState = 13;
	}
	if ( 13 == CamState && millis() >= CamTimer )
	{
		pinMode(CAMSWITCH,INPUT);
		CamTimer= millis() + 3000;
		CamState = 20;
	}
// Cam Recording for 5
	if ( 2 == recording && millis() >= CamTimer )
	{	
		CamState = 0;
	}
	
}


/* ---------- main body of program -------------- */

void debugsetup()
{
  Serial.begin(9600);
  Serial.println("Controller Started");
  Serial.println("XBee Started");
}

void setup()
{

  init_cloud_sensor();
  //Initially join the bus as slave device with address 0xA sensor board
  Wire.begin(MY_I2C_ADDRESS);
  //register receive event
  Wire.onReceive(receiveEvent);
  // register request event  
  Wire.onRequest(requestEvent);
  CameraSetup();
  errorcount = 0;
  xbee.begin(9600);
  looptime = 0; 
#ifdef WATCHDOGENABLE 
  setup_watchdog(9);
#endif
} //end setup()


void loop()
{
#ifdef WATCHDOGENABLE 
  if (f_wdt==1) {  // wait for timed out watchdog / flag is set when a watchdog timeout occurs
    f_wdt=0;       // reset flag
  }
#endif

CameraState;
  while (millis() >= looptime)
  {
    freshcloud = read_cloud_sensor();
    newdelay(10);
    freshhumid = read_humid_sensor();
    newdelay(10);
    freshtemp = read_temp();
    newdelay(10);
    looptime = millis()+30000;


    if (1 == DEBUG)
    {

      Serial.println("");
      Serial.println("**");
      byte sample_data[2];
      int sample;

      Serial.print("CS: ");
      Serial.println(freshcloud);
      sample_data[0] = (byte) (freshcloud / 256);
      sample_data[1] = (byte) (freshcloud % 256);
      Serial.print("CS: "); 
      Serial.print((int)sample_data[0]); 
      Serial.print(" and "); 
      Serial.println((int)sample_data[1]); 
      newdelay(1);

      Serial.print("H: ");
      Serial.println(freshhumid);
      sample_data[0] = (byte) (freshhumid / 256);
      sample_data[1] = (byte) (freshhumid % 256);
      Serial.print("HS: "); 
      Serial.print((int)sample_data[0]); 
      Serial.print(" and "); 
      Serial.println((int)sample_data[1]); 
      newdelay(1);

      Serial.print("T: ");
      Serial.println(freshtemp);
      sample_data[0] = (byte) (freshtemp / 256);
      sample_data[1] = (byte) (freshtemp % 256);
      Serial.print("TS: "); 
      Serial.print((int)sample_data[0]); 
      Serial.print(" and "); 
      Serial.println((int)sample_data[1]); 
      newdelay(1);
    }
  }
if( 0 == recording ){
if  ( 1 == SLEEPENABLE )
{
Serial.println("Going to sleep");
  system_sleep();  //go to sleep 
}
}
}//end loop()

