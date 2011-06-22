#define DEBUG 0// 1 enable 0 disable
int camledpin = 10; /* port 10 -- read status of LED on camera */
int camctrl = 9; /* port 9 -- shoot -- active low -- if pulse more than 1 sec will do video */
int campwr = 8; /* port 8 -- power on/off -- pulse high 1 sec */

void newdelay(int time)
{
  unsigned long start; 
  start = millis();
  while (millis() == start+time){
  }
}


void init_camera_ports(void)
{
  pinMode(campwr, OUTPUT);
  pinMode(camctrl, OUTPUT); 
  pinMode(camledpin, INPUT); 

  digitalWrite(campwr, LOW); /* camera assumed OFF at start */
  digitalWrite(camctrl, HIGH); /* Shutter takes active low pulse */
}


int power_on_off(void) 
{
  int response = 0;

  digitalWrite(campwr, HIGH); /* begin to turn on */
  newdelay(500);

  /* see if LED has power */
  response = digitalRead(camledpin);   

  newdelay(600);
  digitalWrite(campwr, LOW); /* end the pulse */
}

int take_still_pic(void)
{
  int response = 0;

  /* If the camera is OFF, it needs to be turned on first.    
   Unfortunately, the LED sense line is ambiguous -- it is LOW
   both when OFF and when on and ready to ake a picture.
   Therefore, the only way to know the camera is already on is
   to try to take a still picture, and interpret the LED sense 
   results.
   */

  /* see if LED is already OFF */
  response = digitalRead(camledpin); 

  if (response)
  {
    /* the camera is definitely on, but presumably busy,
     taking either a still picture or a video.  If video,
     it will be HIGH for a LONG time, so don't wait, just
     return FALSE.
     */
    return 0;  
  }  


  digitalWrite(camctrl, LOW); /* try to take a picture */

  newdelay(400);
  digitalWrite(camctrl, HIGH); /* end the "shoot" pulse */
  if (DEBUG == 1){
    Serial.println("#2");
  }
  newdelay(100);   /* wait a moment... */

  /* see if LED has gone OFF */
  response = digitalRead(camledpin);  

  if (response)   /* should be HIGH while taking picture */
  {
    if (DEBUG == 1){
      Serial.println("#3");
    }
    while (digitalRead(camledpin))  /* stays HIGH while taking picture */
    {
      /* should put in a "deadman" clock in here */
    }
    return 1;  
  }
  if (DEBUG == 1){
    Serial.println("#4");
  }
  return 0;  
}  


int start_video(void)
{
  int response = 0;

  /* If the camera is OFF, it needs to be turned on first.    
   Unfortunately, the LED sense line is ambiguous -- it is LOW
   both when OFF and when on and ready to ake a picture.
   Therefore, the only way to know the camera is already on is
   to try to take a still picture, and interpret the LED sense 
   results.
   */

  /* see if LED is already OFF */
  response = digitalRead(camledpin); 

  if (response)
  {
    /* the camera is definitely on, but presumably busy,
     taking either a still picture or a video.  If video,
     it will be HIGH for a LONG time, so don't wait, just
     return FALSE.
     */
    return 0;  
  }  

  digitalWrite(camctrl, LOW); /* try to take a picture */
  newdelay(400);

  /* see if LED has gone OFF */
  response = digitalRead(camledpin);   

  newdelay(1800);   /* for video need a 2 second pulse */
  digitalWrite(camctrl, HIGH); /* end the "shoot" pulse */

  /* LED pulses 3 times briefly, then goes off while taking video */
  /* delay here to skip the pulses, then check the LED state again */
  newdelay(1800);  /* this gets us to 4 seconds so far... */
  response = digitalRead(camledpin); 

  if (response)   /* should be HIGH while taking video */
  {
    return 1;   /* presumably video is shooting, assuming camera not
     otherwise locked up */
  }

  /* if the line never went HIGH, something didn't work,
   maybe power timed out (idle for 30 seconds?) */
  return 0;  
}  


int stop_video(void)
{
  /* If the camera is OFF, it needs to be turned on first.    
   Unfortunately, the LED sense line is ambiguous -- it is LOW
   both when OFF and when on and ready to ake a picture.
   Therefore, the only way to know the camera is already on is
   to try to take a still picture, and interpret the LED sense 
   results.
   */
  if (!digitalRead(camledpin))  // see if LED is already OFF (line should be HIGH)
  {
    /* something went wrong */
    return 0;  
  }  

  digitalWrite(camctrl, LOW); // shut down video with another short pulse
  newdelay(400);
  digitalWrite(camctrl, HIGH); // end the "stop video" pulse

  newdelay(200);  // wait a moment...

  // see if LED has gone back ON  
  if (digitalRead(camledpin))   // should be LOW because LED went back on
  {
    return 1;   // presumably video is shooting, assuming camera not otherwise dead
  }

  /* if the line never dropped LOW, something didn't work,
   maybe hung up */
  return 0;  
}  


void camerastuff() 
{
  init_camera_ports(); 
  if (DEBUG == 1){
    Serial.begin(9600); 


    if (!(digitalRead(camledpin)))
    {
      Serial.println("Power LED starts LOW as expected");
    }
    else
    {
      Serial.println("Power LED HIGH!!!");
    }  
  }
  if (power_on_off())
  {
    if (DEBUG == 1){
      Serial.println("Camera Should be ON");
      newdelay(2000);
      Serial.println("Take a still picture...");
    }
    newdelay(10);
    if (take_still_pic())
    {
      if (DEBUG == 1){
        Serial.println("Successful still picture.");
        newdelay(1000); 
      }
      newdelay(10);
      if (start_video()) // Serial.println("Now try to take a video for about 1 minute...");
      {
        newdelay(60000);   /* wait one minute */
        if (DEBUG == 1){
          Serial.println("Try to shut off video...");
        }
        if (stop_video())
        {
          if (DEBUG == 1){
            Serial.println("Successful video.");
            newdelay(2000); 

            Serial.println("Try to shut down the camera...");
          }
          newdelay(10);
          if (power_on_off())
          {
            if (DEBUG == 1){
              Serial.println("Successful power down.");
            }
          }  
          else
          {
            if (DEBUG == 1){
              Serial.println("Power down failed.");
            }    
          } 
        }
        else
        {
          if (DEBUG == 1){
            Serial.println("Video did not shut down as expected.");
          }
        }  
      } 
      else
      {
        if (DEBUG == 1){
          Serial.println("Video did not start as expected.");
        }  
      }
    }
    else
    {
      if (DEBUG == 1){
        Serial.println("Camera is either off or busy, perhaps taking");
        Serial.println("another picture or video.");
      }
    }
  }
  else
  {
    if (DEBUG == 1){
      Serial.println("No Dice -- power didn't come on.");
    }
  }  
  if (DEBUG == 1){
    /* wait 5 seconds */
    newdelay(5000);  
    Serial.println("Done with tests.");
  }
}

void setup()
{
}

void loop() 
{
}


