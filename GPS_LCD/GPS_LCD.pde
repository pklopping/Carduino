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
int backLight = 49;    // pin 13 will control the backlight
float currTemp;

SimpleTimer timer;

void setup() {
  Serial.begin(9600);
  Serial.println("\r\nGPSlogger");
  GPS::GPS();
  // make sure that the default chip select pin is set to
  // output, even if you don't use it:
  pinMode(53, OUTPUT);
  digitalWrite(53,HIGH);

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
  GPS::readGPS();
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
  if (!GPS::hasLock) {
    lcd.setCursor(0,0);
    lcd.print(" Acquiring Lock");
  } else {
    //Display MPH
    if (GPS::speedIsBlank) {
      lcd.setCursor(0,0);
      lcd.print("Acquiring Speed");
    } else {
      lcd.setCursor(4,0);
      lcd.print(GPS::currSpeed);
      lcd.print("mph");

      //Display Heading
      lcd.setCursor(13,0);
      if (GPS::currHeading<100) {
        lcd.print("0");
        if (GPS::currHeading < 10) {
          lcd.print("0");
        }
      }
      lcd.print(GPS::currHeading);
    }
  }
  // ----- LINE 2 -----

  //Display Time
  lcd.setCursor(5,1);
  lcd.print(formattedTime(GPS::currTime));
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