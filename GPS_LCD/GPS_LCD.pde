//Needed hacks to the arduino library
/*
  define MEGA_SOFT_SPI as 1 (originally 0) in Sd2Card.h
*/

#include <math.h>
#include <SD.h>
#include "constants.h"
#include "helpers.h"
//Other Libraries
#include <SimpleTimer.h>
#include <GPS.h>
//Temp Sensor Stuff
#include <OneWire.h>
#include <DallasTemperature.h>
//LCD stuff
#include <LiquidCrystal.h>


// Set up the Temp Sensor
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

//LCD 
LiquidCrystal lcd(42, 41, 40, 35, 34, 33, 32);
float currTemp;
int8_t switchState; // 0 is off, -1 is down, 1 is up
bool switch_up; //Declare it once and reuse it
bool switch_down; //Declare it once and reuse it

SimpleTimer timer;

void setup() {
  Serial.begin(115200); //9600 is so ordinary
  Serial.println("\r\nGPSlogger");

  //INit the GPS class
  GPS::GPS();

  // make sure that the default chip select pin is set to
  // output, even if you don't use it:
  pinMode(53, OUTPUT);
  digitalWrite(53,HIGH);

  pinMode(SWITCH_UP, INPUT);
  pinMode(SWITCH_DOWN, INPUT);
  pinMode(RED_BUTTON, INPUT);
  pinMode(BLACK_BUTTON, INPUT);

  int err = 0;

  err = GPS::setupSD();
  if (err != 0) {
    error(err);
  }

  err = GPS::createLog();
  if (err != 0) {
    error(err);
  }

  //Configure the LCD
  lcd.begin(16,2);              // columns, rows.  use 16,2 for a 16x2 LCD, etc.

  //Show a welcome message on the LCD
  lcd.clear();                  // start with a blank screen
  lcd.setCursor(0,0);           // set cursor to column 0, row 0 (the first row)
  lcd.print("    Welcome");    // change this text to whatever you like. keep it clean.
  lcd.setCursor(0,1);           // set cursor to column 0, row 1
  lcd.print("Starting System");

  //Setup timers
  timer.setInterval(1000,updateLCD);
  timer.setInterval(500,updateLights);
  timer.setInterval(5000,getTemperature);
  //Temp Sensor Stuff
  sensors.begin();
}

void loop() {
  GPS::readGPS();
  timer.run();
}

void updateLights() {
  //Check for change in state
  switch_up = digitalRead(SWITCH_UP);
  switch_down = digitalRead(SWITCH_DOWN);
  if (switch_up)
    switchState = 1;
  else if (switch_down)
    switchState = -1;
  else
    switchState = 0;

  //Configure Pins
  switch (switchState) {
    case 0: //Off
    case 1: //Temp
      pinMode(RED_CHANNEL, OUTPUT);
      pinMode(GREEN_CHANNEL, OUTPUT);
      pinMode(BLUE_CHANNEL, OUTPUT);
      break;
    case -1: //Remote
      pinMode(RED_CHANNEL, INPUT);
      pinMode(GREEN_CHANNEL, INPUT);
      pinMode(BLUE_CHANNEL, INPUT);
      break;
  }

  setLightColors();
}

void setLightColors() {
  if (switchState == 1) {
    int tempTemp = currTemp;
    tempTemp = max(currTemp, COLD);
    tempTemp = min(tempTemp, HOT);
    uint8_t currentColor = map(tempTemp, COLD, HOT, 0, 255);
    analogWrite(RED_CHANNEL, currentColor);
    analogWrite(BLUE_CHANNEL, 255-currentColor);
  } else if (switchState == 0) {
    analogWrite(RED_CHANNEL, 0);
    analogWrite(GREEN_CHANNEL, 0);
    analogWrite(BLUE_CHANNEL, 0);
  } else {
    //Don't care, the pins are set as inputs. 
  }
}

void getTemperature(){
  if (DEBUG_TEMPS) {
    Serial.print(" Requesting temperatures...");
  }
  sensors.requestTemperatures(); // Send the command to get temperatures
  currTemp = sensors.getTempFByIndex(0);
  if (DEBUG_TEMPS) {
    Serial.println("DONE");
    Serial.print("Temperature for Device 1 is: ");
    Serial.print(currTemp); //index 0 assumes only one temp sesnor on bus
    Serial.print('\n');
  }
}

/*
  This function updates the data on the LCD
*/
void updateLCD() {
  lcd.clear();

  // ----- LINE 1 -----

  // Display Fix or not
  if (!GPS::hasLock) {
    lcd.setCursor(0,0);
    lcd.print(" Acquiring Lock");
  } else {
    //Display MPH
    if (GPS::speedIsBlank) {
      lcd.setCursor(0,0);
      lcd.print("Acquiring Speed");
    } else {
      lcd.setCursor(5,0);
      padLCDNumber(GPS::currSpeed, 2, ' ');
      lcd.print((int)GPS::currSpeed);
      lcd.print("mph");

      //Display Heading
      lcd.setCursor(13,0);
      padLCDNumber(GPS::currHeading, 2, '0');
      lcd.print(GPS::currHeading);
    }
  }
  // ----- LINE 2 -----

  //Display Time
  lcd.setCursor(6,1);
  lcd.print(formattedTime(GPS::currTime));
  //Display Temp
  lcd.setCursor(13,1);
  padLCDNumber(currTemp, 2, ' ');
  lcd.print(round(currTemp));

  //Display Switch Status
  lcd.setCursor(0,1);
  switch (switchState) {
    case 0:
      lcd.print("OFF");
      break;
    case 1:
      lcd.print("TMP");
      break;
    case -1:
      lcd.print("RMT");
      break;
  }
}

/*
  This method will pad a number on the LCD 
  leading_zeros is actually relative to a power of 10, 
  so 2 leading zeros would yeild 00 if the number is less than 10
  it's a litlte confusing, I know. I should put more thought into this variable name
*/
void padLCDNumber(float number, int8_t leading_zeros, char filler) {
  if (leading_zeros < 0)
    return;
  while (leading_zeros > 0) {
    if (number < pow(10, leading_zeros))
      lcd.print(filler);
    leading_zeros--;
  }
}