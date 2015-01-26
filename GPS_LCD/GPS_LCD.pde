//Needed hacks to the arduino library
/*
  define MEGA_SOFT_SPI as 1 (originally 0) in Sd2Card.h
*/

#include <SD.h>
#include <math.h>
#include <avr/sleep.h>
#include "constants.h"
#include "GPSconfig.h"
#include "helpers.h"
#include <SoftwareSerial.h>
//Other Libraries
#include <SimpleTimer.h>
//Temp Sensor Stuff
#include <OneWire.h>
#include <DallasTemperature.h>
//LCD stuff
#include <LiquidCrystal.h>


SoftwareSerial gpsSerial =  SoftwareSerial(GPS_TX_PIN, GPS_RX_PIN);

// Set up the Temp Sensor
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);


#define BUFFSIZE 90
char buffer[BUFFSIZE];
char *currTime; //current timestring from the GPS hhmmss.ddd
bool speedIsBlank;
float currSpeed; //current speed from GPS in knots
float currHeading; //current heading from GPS
float currTemp;
uint8_t bufferidx = 0;
bool fix = false; // current fix data
bool gotGPRMC;    //true if current data is a GPRMC strinng
File logfile;

//LCD 
LiquidCrystal lcd(42, 41, 40, 35, 34, 33, 32);
int backLight = 49;    // pin 13 will control the backlight

SimpleTimer timer;

void setup() {
  WDTCSR |= (1 << WDCE) | (1 << WDE);
  WDTCSR = 0;
  Serial.begin(9600);
  Serial.println("\r\nGPSlogger");
  pinMode(led1Pin, OUTPUT);
  pinMode(led2Pin, OUTPUT);
  pinMode(powerPin, OUTPUT);
  digitalWrite(powerPin, LOW);

  // make sure that the default chip select pin is set to
  // output, even if you don't use it:
  pinMode(53, OUTPUT);
  digitalWrite(53,HIGH);
  
  // see if the card is present and can be initialized:
  if (!SD.begin(chipSelect)) {
    Serial.println("Card init. failed!");
    error(1);
  }

  strcpy(buffer, "GPSLOG00.TXT");
  for (i = 0; i < 100; i++) {
    buffer[6] = '0' + i/10;
    buffer[7] = '0' + i%10;
    // create if does not exist, do not open existing, write, sync after write
    if (! SD.exists(buffer)) {
      break;
    }
  }

  logfile = SD.open(buffer, FILE_WRITE);
  if( ! logfile ) {
    Serial.print("Couldnt create "); Serial.println(buffer);
    error(3);
  }
  Serial.print("Writing to "); Serial.println(buffer);
  
  // connect to the GPS at the desired rate
  gpsSerial.begin(GPSRATE);
  
  Serial.println("Ready!");
  
  gpsSerial.print(SERIAL_SET);
  delay(250);

  //Whoops, looks like I need to tell it to turn off this other junk
  gpsSerial.print(DDM_OFF);
  gpsSerial.print(GGA_OFF);
  gpsSerial.print(GLL_OFF);
  gpsSerial.print(GSA_OFF);
  gpsSerial.print(GSV_OFF);
  gpsSerial.print(VTG_OFF);
  gpsSerial.print(WAAS_OFF);
  gpsSerial.print(RMC_ON);
  delay(250);

  //Configure the LCD
  pinMode(backLight, OUTPUT);
  digitalWrite(backLight, HIGH); // turn backlight on. Replace 'HIGH' with 'LOW' to turn it off.
  lcd.begin(16,2);              // columns, rows.  use 16,2 for a 16x2 LCD, etc.

  //Show a welcome message on the LCD
  lcd.clear();                  // start with a blank screen
  lcd.setCursor(0,0);           // set cursor to column 0, row 0 (the first row)
  lcd.print("    Welcome");    // change this text to whatever you like. keep it clean.
  lcd.setCursor(0,1);           // set cursor to column 0, row 1
  lcd.print("Starting System");

  //Setup time for updating the LCD
  timer.setInterval(1000,updateLCD);
  timer.setInterval(5000,getTemperature);
  //Temp Sensor Stuff
  sensors.begin();
}

void loop() {
  readGPS();
  timer.run();
}

void getTemperature(){
  Serial.print(" Requesting temperatures...");
  sensors.requestTemperatures(); // Send the command to get temperatures
  Serial.println("DONE");

  Serial.print("Temperature for Device 1 is: ");
  currTemp = sensors.getTempFByIndex(0);
  Serial.print(currTemp); //index 0 assumes only one temp sesnor on bus
  Serial.print('\n');
}

/*
  This function updates the data on the LCD
*/
void updateLCD() {
  //Show a welcome message on the LCD
  // lcd.setCursor(0,0);
  // lcd.print("----------------");
  // lcd.setCursor(0,1);
  // lcd.print("----------------");
  lcd.clear();

  // ----- LINE 1 -----

  // Display Fix or not
  if (!fix) {
    lcd.setCursor(0,0);
    lcd.print(" Acquiring Lock");
  } else {
    //Display MPH
    if (speedIsBlank) {
      lcd.setCursor(0,0);
      lcd.print("Acquiring Speed");
    } else {
      lcd.setCursor(4,0);
      lcd.print(currSpeed);
      lcd.print("mph");

      //Display Heading
      lcd.setCursor(13,0);
      if (currHeading<100) {
        lcd.print("0");
        if (currHeading < 10) {
          lcd.print("0");
        }
      }
      lcd.print(currHeading);
    }
  }
  // ----- LINE 2 -----

  //Display Time
  lcd.setCursor(5,1);
  lcd.print(formattedTime(currTime));
  //Display Temp
  lcd.setCursor(13,1);
  if (currTemp<100) {
    lcd.print("0");
    if (currTemp<10){
      lcd.print("0");
    }
  }
  lcd.print(round(currTemp));


}

/*
  This function reads from teh GPS unit and writes to the SD card.
*/
void readGPS() {
  //Serial.println(Serial.available(), DEC);
  char c;
  uint8_t sum;

  // read one 'line'
  if (!gpsSerial.available()) {
    // Serial.print("GPS Not Available\n");
    return;
  }
  c = gpsSerial.read();
  //Serial.write(c);
  if (bufferidx == 0) {
    while (c != '$')
      c = gpsSerial.read(); // wait till we get a $
  }
  buffer[bufferidx] = c;

  //Serial.write(c);
  if (c == '\n') {
    //putstring_nl("EOL");
    //Serial.print(buffer);
    buffer[bufferidx+1] = 0; // terminate it

    if (buffer[bufferidx-4] != '*') {
      // no checksum?
      Serial.print('*');
      bufferidx = 0;
      return;
    }
    // get checksum
    sum = parseHex(buffer[bufferidx-3]) * 16;
    sum += parseHex(buffer[bufferidx-2]);

    // check checksum
    for (i=1; i < (bufferidx-4); i++) {
      sum ^= buffer[i];
    }
    if (sum != 0) {
      //putstring_nl("Cxsum mismatch");
      Serial.print('~');
      bufferidx = 0;
      return;
    }
    // got good data!

    gotGPRMC = strstr(buffer, "GPRMC");
    if (gotGPRMC) {
      // find out if we got a fix
      char *p = buffer;
      p = strchr(p, ',')+1; //Should have current time?
      currTime = substr(p,0,6);
      p = strchr(p, ',')+1;       // skip to 3rd item
      
      if (p[0] == 'V') {
        digitalWrite(led1Pin, LOW);
        fix = false;
      } else {
        digitalWrite(led1Pin, HIGH);
        fix = true;
      }
    }

    if (fix) {
      speedIsBlank = checkForBlankSpeed(buffer);
      currSpeed = getSpeed(buffer);
      currHeading = getHeading(buffer);
    }

    if (LOG_RMC_FIXONLY) {
      if (!fix) {
        Serial.print('_');
        bufferidx = 0;
        return;
      }
    }
    // rad. lets log it!
    
    Serial.print(buffer);    //first, write it to the serial monitor
    Serial.print('#');
    
    if (gotGPRMC)      //If we have a GPRMC string
    {
      // Bill Greiman - need to write bufferidx + 1 bytes to getCR/LF
      bufferidx++;

      digitalWrite(led2Pin, HIGH);      // Turn on LED 2 (indicates write to SD)

      logfile.write((uint8_t *) buffer, bufferidx);    //write the string to the SD file
      logfile.flush();
      /*
      if( != bufferidx) {
         putstring_nl("can't write!");
         error(4);
      }
      */

      digitalWrite(led2Pin, LOW);    //turn off LED2 (write to SD is finished)

      bufferidx = 0;    //reset buffer pointer

      if (fix) {  //(don't sleep if there's no fix)
        
        if ((TURNOFFGPS) && (SLEEPDELAY)) {      // turn off GPS module? 
        
          digitalWrite(powerPin, HIGH);  //turn off GPS

          delay(100);  //wait for serial monitor write to finish
          sleep_sec(SLEEPDELAY);  //turn off CPU

          digitalWrite(powerPin, LOW);  //turn on GPS
        } //if (TURNOFFGPS) 
       
      } //if (fix)
      
      return;
    }//if (gotGPRMC)
    
  }
  bufferidx++;
  if (bufferidx == BUFFSIZE-1) {
     Serial.print('!');
     bufferidx = 0;
  }

}