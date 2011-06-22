
//POWERWIRE 5v CAMERA RED
//GNDWIRE CAMERA GREEN
#define CAMPOWER 7 // Violet -- CAMPower
#define CAMMODE 8 // Brown -- Mode
#define CAMRECORD 9// Orange -- CAMRecord
#define CAMPOWER_LED 10 //yellow -- CAMPOWER_LED


void CameraSetup()
{
  // initialize pins for hign impedence
  pinMode(CAMPOWER, INPUT);
  pinMode(CAMMODE, INPUT);
  pinMode(CAMRECORD, INPUT);
  pinMode(CAMPOWER_LED, INPUT);
}

void PowerOff()
{
  Serial.println("Power Off");
  if ( isPowerOn() )
  {
    pinMode(CAMPOWER, OUTPUT);
    digitalWrite(CAMPOWER,HIGH);
    delay(200);
    digitalWrite(CAMPOWER,LOW);
    pinMode(CAMPOWER,INPUT);
  }
}

void PowerOn()
{
  Serial.println("Power On");
  if ( ! isPowerOn() )
  {
    pinMode(CAMPOWER, OUTPUT);
    digitalWrite(CAMPOWER,HIGH);
    delay(200);
    digitalWrite(CAMPOWER,LOW);
    pinMode(CAMPOWER,INPUT);
    
    delay(6000);
    // Change the mode to Video
    Serial.println("Change Mode");
    digitalWrite(CAMMODE,HIGH);
    pinMode(CAMMODE,OUTPUT);
    digitalWrite(CAMMODE,LOW);
    delay(200);
    digitalWrite(CAMMODE,HIGH);
    delay(4000);
    Serial.println("Press 2nd Time");
    digitalWrite(CAMMODE,LOW);
    delay(200);
    digitalWrite(CAMMODE,HIGH);
    pinMode(CAMMODE,INPUT);
    delay(3000); // Need to wait at least 3 sec before recording
  }
}


int isPowerOn()
{
  //return (digitalRead(CAMPOWER_LED) > 0);
  if (digitalRead(CAMPOWER_LED) > 0)
  {
    //Serial.println("Power is On");
    return true;
  } else {
    //Serial.println("Power is Off");
    return false;
  };
}

void ToggleRecord()
{
    // Press Record button
    Serial.println("Start Recording");
    digitalWrite(CAMRECORD,HIGH);
    pinMode(CAMRECORD,OUTPUT);
    digitalWrite(CAMRECORD,LOW);
    delay(200);
    digitalWrite(CAMRECORD,HIGH);
    pinMode(CAMRECORD,INPUT);
    delay(2000); // Need to wait at least 2 seconds before something else
}

int CAMCNT;

void setup() {     
  CameraSetup();

  Serial.begin(9600);
  CAMCNT = 300;  
  Serial.println("Initial Pause");
  delay(10000);
}


void loop() {

  CAMCNT++;
  
  if ( isPowerOn() )
    digitalWrite(13, HIGH);   // set the LED on
  else
  {
    digitalWrite(13, LOW);    // set the LED off
  }
  
  delay(100);   // wait for a 200 ms
  
  if ( CAMCNT > 300 ){
    CAMCNT = 0;
    if ( isPowerOn() )
    {
      Serial.println("Power was already on");
      PowerOff();
    }
    else
    {
      PowerOn();
      ToggleRecord();
      // Allow Power Off to stop the record function
    }
  }
  
}
