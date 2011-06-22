/* dust_sensor2 -- test function to read SHARP GP2Y1010AU0F dust sensor */


#include "WProgram.h"

#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* 12/5/2010 Gary L. Flispart (GLF) for LVL1 */

/* ----- functions to support polling SHARP GP2Y1010AU0F dust sensor --- */

/* pins to use on Arduino (or Diavolino) */
#define DUST_ANALOGPIN 1
#define LED_DIGITALPIN 3

/* specified LED pulse is 320 microseconds, with 10 ms cycle time */
#define DELAY1_MUSECS  280
#define DELAY2_MUSECS   40
#define OFF_MUSECS    9680

/* the following constant is the unsigned long limit - 10000 */
#define TOOBIG_ULONG 0xFFFFD8F0  

static unsigned int dust_sum;
unsigned long last_microsec;
unsigned long sched_microsec;
static unsigned int runsum;
static int runct;

void init_dust_sensor(void)
  {
   pinMode(LED_DIGITALPIN,OUTPUT);
   
   sched_microsec = 0;
   runsum = 0;    
   runct = 0;
   dust_sum = 0;
  }
  
int watch_dust_sensor(int num_rdgs_in_ct)
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
   /* This follows MFR specs, takes 320 us to read and waits to fill 10 ms */
   digitalWrite(LED_DIGITALPIN,LOW); /* power on the LED */
   delayMicroseconds(DELAY1_MUSECS);

   runsum += analogRead(DUST_ANALOGPIN); /* read the dust value via pin 5 on the sensor */

   delayMicroseconds(DELAY2_MUSECS);
   digitalWrite(LED_DIGITALPIN,HIGH); /* turn the LED off */

   /* smooth out random variations by summing "num_rdgs_in_ct" readings */   
   runct++;
   if (runct >= num_rdgs_in_ct)
     {
      dust_sum = runsum;
      runct = 0;
      runsum = 0;
      return 1;
     }
   return 0;  
  }

unsigned int read_dust_sensor(void)
  {
   /* get latest available (100 ms min) sum of 10 readings */
   return dust_sum;
  }


/* ---------- main body of program -------------- */

void setup()
  {
   init_dust_sensor();
   Serial.begin(9600);
  }
 
 
void loop()
  {
   /* This design style allows processing an arbitrary event loop 
      doing other things while also maintaining dust sensor. 
      It is possible for one function (main event loop)
      to poll the dust sensor in background while another
      function calls read_dust_sensor() to get the latest 
      reading available without incurring any time delay or side 
      effects directly.  The parameter to watch-dust_sensor()
      sets up the number of readings summed before returning a 
      reading (averaging without dividing by n).
    */
    
    if (watch_dust_sensor(10))  /* takes 10 ms to look, returns TRUE
                                 every 10th look (if parameter 10) */
     {
         Serial.println(read_dust_sensor()); /* sum of 10 raw readings */
     } 
  }


