/*
 Test control of 808 keychain camera 
*/
 
void init_camera_ports(void)
   {
    /* port 8 -- power on/off -- pulse high 1 sec */ 
    /* port 9 -- shoot -- active low -- if pulse more than 1 sec will do video */
    /* port 10 -- read status of LED on camera */
    

    pinMode(8, OUTPUT);
    pinMode(9, OUTPUT); 
    pinMode(10, INPUT); 

    digitalWrite(8, LOW); /* camera assumed OFF at start */
    digitalWrite(9, HIGH); /* Shutter takes active low pulse */
   }
 
int power_on_off(void) 
  {
   int response = 0;
   
   digitalWrite(8, HIGH); /* begin to turn on */
   delay(500);
   
   /* see if LED has power */
   response = digitalRead(10);   
   
   delay(600);
   digitalWrite(8, LOW); /* end the pulse */
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
   response = digitalRead(10); 
 
   if (response)
     {
      /* the camera is definitely on, but presumably busy,
         taking either a still picture or a video.  If video,
        it will be HIGH for a LONG time, so don't wait, just
        return FALSE.
      */
      return 0;  
     }  
   
   digitalWrite(9, LOW); /* try to take a picture */
   delay(400);
   digitalWrite(9, HIGH); /* end the "shoot" pulse */
   
   Serial.println("#2");

   delay(100);   /* wait a moment... */

   /* see if LED has gone OFF */
   response = digitalRead(10);   

   if (response)   /* should be HIGH while taking picture */
     {
      Serial.println("#3");
      while (digitalRead(10))  /* stays HIGH while taking picture */
        {
         /* should put in a "deadman" clock in here */ 
        }
      return 1;  
     }
   Serial.println("#4");
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
   response = digitalRead(10); 
 
   if (response)
     {
      /* the camera is definitely on, but presumably busy,
         taking either a still picture or a video.  If video,
        it will be HIGH for a LONG time, so don't wait, just
        return FALSE.
      */
      return 0;  
     }  
   
   digitalWrite(9, LOW); /* try to take a picture */
   delay(400);
      
   /* see if LED has gone OFF */
   response = digitalRead(10);   
   
   delay(1800);   /* for video need a 2 second pulse */
   digitalWrite(9, HIGH); /* end the "shoot" pulse */
   
   /* LED pulses 3 times briefly, then goes off while taking video */
   /* delay here to skip the pulses, then check the LED state again */
   delay(1800);  /* this gets us to 4 seconds so far... */
   response = digitalRead(10); 
   
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
   int response = 0;

   /* If the camera is OFF, it needs to be turned on first.    
      Unfortunately, the LED sense line is ambiguous -- it is LOW
      both when OFF and when on and ready to ake a picture.
      Therefore, the only way to know the camera is already on is
      to try to take a still picture, and interpret the LED sense 
      results.
   */
    
   /* see if LED is already OFF (line should be HIGH) */
   response = digitalRead(10); 
 
   if (!response)
     {
      /* something went wrong */ 
      return 0;  
     }  
   
   digitalWrite(9, LOW); /* shut down video with another short pulse */
   delay(400);
   digitalWrite(9, HIGH); /* end the "stop video" pulse */
   
   /* wait a moment... */
   delay (200);
   
   /* see if LED has gone back ON */
   response = digitalRead(10);   
   
   if (response)   /* should be LOW because LED went back on */
     {
      return 1;   /* presumably video is shooting, assuming camera not
                     otherwise dead */
     }

   /* if the line never dropped LOW, something didn't work,
      maybe hung up */  
   return 0;  
  }  
 
 
void setup() 
  {
   init_camera_ports(); 
   Serial.begin(9600); 
  
   if (!(digitalRead(10)))
     {
      Serial.println("Power LED starts LOW as expected");
     }
   else
     {
      Serial.println("Power LED HIGH!!!");
     }  

   if (power_on_off())
     {
      Serial.println("Camera Should be ON");
      delay(2000);
      Serial.println("Take a still picture...");
      if (take_still_pic())
        {
         Serial.println("Successful still picture.");
         delay(1000); 
         Serial.println("Now try to take a video for about 1 minute...");
         if (start_video())
           {
            delay(60000);   /* wait one minute */ 
            Serial.println("Try to shut off video...");
            if (stop_video())
              {
               Serial.println("Successful video.");
               delay(2000); 

               Serial.println("Try to shut down the camera...");
               if (power_on_off())
                 {
                  Serial.println("Successful power down.");
                 }  
               else
                 {
                  Serial.println("Power down failed.");
                 } 
              }
            else
              {
               Serial.println("Video did not shut down as expected.");
              }  
           } 
         else
           {
            Serial.println("Video did not start as expected.");
           }  
        }
      else
        {
         Serial.println("Camera is either off or busy, perhaps taking");
         Serial.println("another picture or video.");
        }
     }
   else
     {
      Serial.println("No Dice -- power didn't come on.");
     }  
     
   /* wait 5 seconds */
   delay(5000);  
   Serial.println("Done with tests.");
  }
 
 
 
 void loop() 
   {
   }
