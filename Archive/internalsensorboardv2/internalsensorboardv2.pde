#define DEBUG 0// 1 enable 0 disable

#include <XBee.h>
#include <Wire.h>
/* define/reserve the pins */
#define cloud_LEDPIN 11    //for cloud sensor detector
#define SDAL_PIN 4  //whitestar I2C bus data line
#define SCLL_PIN 5  //whitestar I2C bus clock line
#define xbeereset 4 // fio pin 4 to reset xbee
#define HUMID_ANALOGPIN 7     //for humidity sensors output
#define cloud_ANALOGPIN 6    //for cloud sensors output
static int MY_I2C_ADDRESS = 0xA;  //my address
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


/* ------- I2C stuff that needs to be done  ------- */

void receiveEvent(int howMany)
{
  while (Wire.available() > 0)
  {
    isb_command = Wire.receive();
  } 

  if (DEBUG == 1)
  {
    Serial.print( "i2cr ");
    Serial.println(isb_command);
  }
}//end receiveEvent()

void requestEvent()
{    
  byte reply_data[2];
  if (DEBUG == 1)
  {
    Serial.print("itc");
    Serial.println(isb_command);
  }

  switch (isb_command) 
  {
  case 0x4:
    { //humidty sensor
      reply_data[0] = (byte) (freshhumid / 256);
      reply_data[1] = (byte) (freshhumid % 256);
      Wire.send(reply_data,2);
      if (DEBUG == 1)
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
      if (DEBUG == 1)
      {
        Serial.print("x ");
        Serial.println(freshtemp);
      }
      break;
    }//end xbee temp sensor case

  case 0x9:
    {//particulate sensor  
      reply_data[0] = (byte) (freshcloud / 256);
      reply_data[1] = (byte) (freshcloud % 256);
      Wire.send(reply_data,2);
      if (DEBUG == 1)
      {
        Serial.print("c ");
        Serial.println(freshcloud);
      }
      break;
    }//end particulate sensor case


  default :
    if (DEBUG == 1)
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
  if (DEBUG == 1)
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

  if (DEBUG == 1)
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
    delay(10);
    if (DEBUG == 1)
    {
      Serial.print("hr ");
      Serial.print(hi);
      Serial.print(" ");
      Serial.println(data);
    }
  } 
  int RelHum = htotal/10;
  if (DEBUG == 1)
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

      if (DEBUG == 1)
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

      if (DEBUG == 1)
      { 
        Serial.print(" ui0 : ");
        Serial.println (uiAvalue0);
        Serial.print(" ui1 : ");
        Serial.println (uiAvalue1);
      }


    } 
    else {
      if (DEBUG == 1)
      {
        Serial.print("ER: ");
        Serial.println(xbee.getResponse().getApiId(), HEX);
      }
    }    
  } 
  else if (xbee.getResponse().isError()) {
    if (DEBUG == 1)
    {
      Serial.println("XError. ");  
    }
  }

  realtemp = eval_therm(uiAvalue1,uiAvalue0);
  if (realtemp == 127)
  {
    errorcount++;
  }
  else
  {
    errorcount = 0;
  }
  if (DEBUG == 1)
  {
    Serial.print("TEC: ");
    Serial.println(errorcount);
    Serial.print("TSD: ");
    Serial.println(realtemp);
  }
  if( errorcount == 10)
  {
      if (DEBUG == 1)
  {
    Serial.println("10 errors");

  }
    digitalWrite(xbeereset,HIGH);
    delay(2);
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

  if (DEBUG == 1)
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


/* ---------- main body of program -------------- */

void setup()
{
  init_cloud_sensor();
  //Initially join the bus as slave device with address 0xA sensor board
  Wire.begin(MY_I2C_ADDRESS);
  //register receive event
  Wire.onReceive(receiveEvent);
  // register request event  
  Wire.onRequest(requestEvent);
  errorcount = 0;
  xbee.begin(9600);
  // start soft serial
  //nss.begin(9600);
  if (DEBUG == 1)
  {
    Serial.begin(9600);
    Serial.println("Controller Started");
    Serial.println("XBee Started");
  }
} //end setup()


void loop()
{
  freshcloud = read_cloud_sensor();
  delay(10);
  freshhumid = read_humid_sensor();
  delay(10);
  freshtemp = read_temp();
  delay(10);
  if (DEBUG == 1)
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
    delay(1);

    Serial.print("H: ");
    Serial.println(freshhumid);
    sample_data[0] = (byte) (freshhumid / 256);
    sample_data[1] = (byte) (freshhumid % 256);
    Serial.print("HS: "); 
    Serial.print((int)sample_data[0]); 
    Serial.print(" and "); 
    Serial.println((int)sample_data[1]); 
    delay(1);

    Serial.print("T: ");
    Serial.println(freshtemp);
    sample_data[0] = (byte) (freshtemp / 256);
    sample_data[1] = (byte) (freshtemp % 256);
    Serial.print("TS: "); 
    Serial.print((int)sample_data[0]); 
    Serial.print(" and "); 
    Serial.println((int)sample_data[1]); 
    delay(1);
  }

  delay(30000);
}//end loop()









