/* dust_sensor1 -- test function to read SHARP GP2Y1010AU0F dust sensor */


#include "WProgram.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* 12/5/2010 Gary L. Flispart (GLF) for LVL1 */

/* ----- functions to support polling SHARP GP2Y1010AU0F dust sensor --- */

/* pins to use on Arduino (or Diavolino) */
#define DUST_ANALOGPIN 5
#define LED_DIGITALPIN 3

/* specified LED pulse is 320 microseconds, with 10 ms cycle time */
#define DELAY1_MUSECS  280
#define DELAY2_MUSECS   40
#define OFF_MUSECS    9680


static int dust_100ms;
static int runsum;
static int runct;

void init_dust_sensor(void)
  {
   pinMode(LED_DIGITALPIN,OUTPUT);
   
   runsum = 0;    
   runct = 0;
   dust_100ms = 0;
  }
  
int watch_dust_sensor(void)
  {
   int val;
   
   /* This follows MFR specs, takes 320 us to read and waits to fill 10 ms */
   digitalWrite(LED_DIGITALPIN,LOW); /* power on the LED */
   delayMicroseconds(DELAY1_MUSECS);

   runsum += analogRead(DUST_ANALOGPIN); /* read the dust value via pin 5 on the sensor */

   delayMicroseconds(DELAY2_MUSECS);
   digitalWrite(LED_DIGITALPIN,HIGH); /* turn the LED off */
   delayMicroseconds(OFF_MUSECS);

   /* smooth out random variations by summing 10 readings */   
   runct++;
   if (runct >= 10)
     {
      dust_100ms = runsum;
      runct = 0;
      runsum = 0;
      return 1;
     }
   return 0;  
  }

int read_dust_sensor(void)
  {
   /* get latest available (100 ms min) sum of 10 readings */
   return dust_100ms;
  }


/* ---------- main body of program -------------- */

void setup()
  {
   init_dust_sensor();
   Serial.begin(9600);
  }
 
void loop()
  {
   /* this style allows processing an arbitrary event loop 
      doing other things while also maintaining dust sensor */
    if (watch_dust_sensor())  /* takes 10 ms to look, returns TRUE
                                 every 10th look */
     {
      Serial.println(read_dust_sensor()); /* sum of 10 raw readings */
     } 
  }


