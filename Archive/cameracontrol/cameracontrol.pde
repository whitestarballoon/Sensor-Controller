#define CamLEDPin 5
#define CamPWRPin 6
#define CamFuncPin 7

void setup() {  
  pinMode(CamLEDPin, INPUT);
  delay(3000);
  camrecordon();
  delay(30000);
  camrecordoff();
}

void loop() {

}



void camrecordon(){    
  digitalWrite(CamPWRPin, HIGH);
  while (CamLEDPin != HIGH)  {
  }
  digitalWrite(CamPWRPin, LOW); 
  
  digitalWrite(CamFuncPin,HIGH);
  while (CamLEDPin != LOW)  {
  } 
  while (CamLEDPin != HIGH)  {//blink1
  }
  while (CamLEDPin != LOW)  {
  } 
  while (CamLEDPin != HIGH)  {//blink2
  }
  while (CamLEDPin != LOW)  {
  }    
    while (CamLEDPin != HIGH)  {//blink3
  }
  while (CamLEDPin != LOW)  {
  }
  digitalWrite(CamFuncPin,LOW);
}

void camrecordoff(){

  int donesave = 0;
  digitalWrite(CamFuncPin,HIGH);
  while (CamLEDPin != HIGH)  {
  }
  digitalWrite(CamFuncPin,LOW);
  do {
    int recordcheck = millis()+1000;
    while ((CamLEDPin == HIGH) || (recordcheck >= millis())){ 
    }
    if (recordcheck >= millis())
    {
      donesave = 1;
    }
  }  
  while (donesave != 1);
  digitalWrite(CamPWRPin, HIGH);
  while (CamLEDPin != LOW)  {
  }
  digitalWrite(CamPWRPin, LOW); 
}




