
//Includes
#include <avr/wdt.h>
#include <avr/pgmspace.h>
#include <stdarg.h>
#include <string.h>
#include <XBee.h>
#include <WSWire.h>

//Defines
#define cloud_LEDPIN 11    //for cloud sensor detector
#define SDAL_PIN 4  //whitestar I2C bus data line
#define SCLL_PIN 5  //whitestar I2C bus clock line
#define xbeereset 4 // fio pin 4 to reset xbee
#define HUMID_ANALOGPIN 7     //for humidity sensors output
#define cloud_ANALOGPIN 6    //for cloud sensors output

// Workaround for http://gcc.gnu.org/bugzilla/show_bug.cgi?id=34734
#undef PROGMEM
#define PROGMEM __attribute__((section(".progmem.data")))

// Camera PINS
#define CAMSWITCH 7 //  camera control pin
const int MY_I2C_ADDRESS = 0xA;  //my address  0x14
const int GROUNDSUPPORT = 0x7; //ground support boards address
unsigned long debugtime = 0;

/* ----- Variables support polling SHARP GP2Y1010AU0F dust sensor --- */
#define TOOBIG_ULONG 0xFFFFD8F0  /* constant is the unsigned long limit - 10000 */
unsigned long last_microsec, sched_microsec, CamTimer, autoCamTimer;
static unsigned int cloud_sum, runsum;
static int runct, errorcount;
static uint16_t freshcloud, freshtemp, freshhumid, externalTemp = 30; //set to room temp for testing REMOVE BEFORE FLIGHT
int CamState = 0, recording = 0;

byte printx=0;
unsigned int wakecnt; //counts the number of times the system has gone through global loop after waking up

//Random Variables
boolean DEBUG = 0;// 1 enable 0 disable
const boolean DEBUGOVERVIEW = 0;
unsigned long looptime; 
volatile boolean f_wdt=1; //watchdog global 
int loop_time = 0, sleep_time, isb_command;  // command given by da boss

/*
FIO with Series 2 (ZigBee) XBee Radios only
 Receives I/O samples from a remote radio.
 The remote radio must have IR > 0 and at least one digital or analog input enabled.
 The XBee *** coordinator *** should be connected to this Arduino.
 */
// empirical calibration of thermistor curve -- log(R) vs. deg C
#define COEFF_XSQ   1.173974
#define COEFF_X   -44.498088
#define COEFF_K   335.674531

// Predetermined value of reference resistor in actual circuit 
#define R_REF     98600.0

XBee xbee = XBee();
ZBRxIoSampleResponse ioSample = ZBRxIoSampleResponse();

void debug(char *str, ...);

void newdelay(int time)
{
  unsigned long start; 
  start = millis();
  while (millis() <= start+time){
  }
}

/* ------- I2C Parsing  ------- */
void receiveEvent(int howMany)
{
  while (Wire.available() > 0)
  {
    isb_command = Wire.read();
  } 

  if (1 == DEBUG)
  {
    debug(PSTR("i2crx: %d"),isb_command);
  }
  switch (isb_command) 
  { //toggle debuging mostly enable it

  case 0x1:
    { 
      if (1 == DEBUG) 
      {
        debug(PSTR("debug off"));
        DEBUG = 0;
      }
      else
      {
        if (0 == DEBUG)
        {
          DEBUG = 1;
          debug(PSTR("debug on"));
        }
      }
      break;
    }  
  case 0xE:
    { //record camera for 5 min
      if (1 == DEBUGOVERVIEW)
      {
        debug(PSTR("CMD:CAM5"));
      }
      autoCamTimer= millis()+300000;
      recording=2;
      CamState=10;
      break;
    }

  case 0xC:
    { //start camera record on command
      if (1 == DEBUGOVERVIEW)
      {
        debug(PSTR("CMD:CAM ON"));
      }
      CamState=10;
      recording=1;
      break;
    }

  case 0xD:
    {  //stop camera on command
      if (1 == DEBUGOVERVIEW)
      {
        debug(PSTR("CMD:CAM OFF"));
      }
      CamState=0;
      break;
    }
  }

}//end receiveEvent()


void requestEvent()
{    
  byte reply_data[2];
  
  if (1 == DEBUGOVERVIEW)
  {
    //debug(PSTR("i2c requested: %d"),isb_command);
  }
  switch (isb_command) 
  { //toggle debuging mostly enable it
  case 0x4:
    { //humidty sensor
      reply_data[0] = (byte) (freshhumid / 256);
      reply_data[1] = (byte) (freshhumid % 256);
      Wire.write(reply_data,2);
      if (1 == DEBUGOVERVIEW)
      {
        debug(PSTR("Sent RelHumid: %d Hex: %x and %x"),freshhumid,(int)reply_data[0],(int)reply_data[1]); 
      }
      break;
    }  //end humidty case

  case 0xA:
    {//xbee temp sensor
      reply_data[0] = (byte) (freshtemp / 256);
      reply_data[1] = (byte) (freshtemp % 256);
      Wire.write(reply_data,2);
      if (1 == DEBUGOVERVIEW)
      {
        debug(PSTR("Sent Temp: %d TS: %d and %d"),freshtemp,(int)reply_data[0],(int)reply_data[1]);
      }
      break;
    }//end xbee temp sensor case

  case 0x9:
    {//particulate sensor  
      reply_data[0] = (byte) (freshcloud / 256);
      reply_data[1] = (byte) (freshcloud % 256);
      Wire.write(reply_data,2);
      if (1 == DEBUGOVERVIEW)
      {
        debug(PSTR("Sent Cloud: %d and %d"),(int)reply_data[0],(int)reply_data[1]); 
      }
      break;
    }//end particulate sensor case

  default :
    if (1 == DEBUG)
    {
      debug(PSTR("fail"));
    }
    reply_data[0] = (byte)255;
    reply_data[1] = (byte)255;
    Wire.write(reply_data,2);
    break; 

  }//end switch isb_command
} //end requestEvent()

void debug(char *str, ...)
{ 
    while (millis() < debugtime ){ 
      //wait before you do this again
    }
  char lstr[32];
  int chars;
  va_list args;
   va_start(args, str);
   lstr[0]='S';
   chars = vsnprintf_P(lstr+1, 31, str, args);
   if ( chars >= 31 ) lstr[31]=0; 
   va_end (args);
    Wire.beginTransmission(GROUNDSUPPORT);
    Wire.write(lstr);
    Wire.endTransmission();	
  
  
	debugtime = millis()+random(100,300);
}


/* ---------- Sensor stuff -------------- */
// ------ Cloud Sensor -------
void init_cloud_sensor(void)
{
  pinMode(cloud_LEDPIN,OUTPUT);
  sched_microsec = 0;

}

int watch_cloud_sensor(int num_rdgs_in_ct)
{
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
    debug(PSTR("cr %d %d"),runct,data);
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
    debug(PSTR("c %d"),cloud_sum);
  }
  return (cloud_sum);
}

// ------ Humidity Sensor -------

int read_humid_sensor(int temp)
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
      debug(PSTR("hr %d %d"),hi,data);
    }
  } 
  //integer, quantised value
  int qval = htotal/10; 
  //float, calculates sensor voltage based on full scale ADC sensitivity
  float Vs = (qval*0.00322265625);
  //RHs is the sensor relative humidity, calculated using Vs
  float RHs = ((Vs-0.528)/0.02046);
  //RHt is the true, temperature adjusted relative humidity
  float RHt  = RHs/(1.0546-0.00216*temp);
  //cast to int RelHum for output. It will truncate, not round.
  int  RelHum = (int) RHt;
  if (1 == DEBUG)
  {
    debug(PSTR("hd %d"),RelHum);
  }
  return (RelHum);
}

// ------ XBee remote analog temperature Sensor -------

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
        debug(PSTR("I/O: %x%x"),ioSample.getRemoteAddress64().getMsb(),ioSample.getRemoteAddress64().getLsb());  

        if (ioSample.containsAnalog()) {
          debug(PSTR("analog:"));
          // read analog inputs
          for (int i = 0; i <= 4; i++) {
            if (ioSample.isAnalogEnabled(i)) {
              debug(PSTR("A (AI%d) is %d"),i,ioSample.getAnalog(i));
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
        debug(PSTR(" ui0 : %d ui1 : %d"),uiAvalue0,uiAvalue1);
      }


    } 
    else {
      if (1 == DEBUG)
      {
        debug(PSTR("XBee ERROR: %x"),xbee.getResponse().getApiId(), HEX);
      }
    }    
  } 
  else if (xbee.getResponse().isError()) {
    if (1 == DEBUG)
    {
      debug(PSTR("XBee Error. "));  
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
    debug(PSTR("TError Count: %d"),errorcount);
    debug(PSTR("T Realtemp: %d"),realtemp);
  }
  if( 10 == errorcount)
  {
    if (1 == DEBUG)
    {
      debug(PSTR("10 errors"));

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

  // no double to string
  if (1 == DEBUG)
  {
    debug(PSTR("RDG T: %d RDG V: %d Deg C: %d"),(int)(tval),(int)(vval),(int)(temp));
  }
  
  return (int)(temp);
}

/* ---------- Camera CONTROLS -------------------  */

void CameraSetup()
{
  // initialize pins for high impedence
  pinMode(CAMSWITCH,INPUT);
  digitalWrite(CAMSWITCH,HIGH);
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
    CamState = 20;
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
  if ( 2 == recording && millis() >= autoCamTimer )
  {	
    CamState = 0;
    recording = 0;
  }

}

void setup()
{
  wdt_enable(WDTO_8S);
  delay(2000);
  Serial.begin(57600);
  Serial.print("Startup");
  loop_time = 0;
  wdt_reset(); //reset watchdog each run.
  
  //Initially join the bus as slave device with address 0xA sensor board
  Wire.begin(MY_I2C_ADDRESS);
  //register receive event
  Wire.onReceive(receiveEvent);
  // register request event  
  Wire.onRequest(requestEvent);
  
  Serial.println(" Sensor Ctrlr Start");
  wdt_reset();
  CameraSetup();
  wdt_reset();
  errorcount = 0;
  xbee.begin(9600);
  //debug(PSTR("XBee"));
  wdt_reset();
  Serial.println("Setup complete");
} //end setup()

void loop()
{
  wdt_reset(); //reset watchdog each run.
  CameraState();
  loop_time = millis();
   while (millis() - loop_time > 30000){
      //reordered so temp comes before humidity for maths purposes
      freshcloud = read_cloud_sensor();
      newdelay(10);
      freshtemp = read_temp();
      newdelay(10);
      freshhumid = read_humid_sensor(externalTemp);
      newdelay(10);
      wdt_reset();
      Serial.print(".");
    }
}
