#include <OneWire.h>
#include <DallasTemperature.h>
 
// Data wire is plugged into pin 2 on the Arduino
#define ONE_WIRE_BUS 2

int redPin = 9;
int greenPin = 10;
int bluePin = 11;
int switchPin = 3;
int switchState = 0;
float currentTemp = 0;
float cold = 73;
float hot = 83;
 
// Setup a oneWire instance to communicate with any OneWire devices 
// (not just Maxim/Dallas temperature ICs)
OneWire oneWire(ONE_WIRE_BUS);
 
// Pass our oneWire reference to Dallas Temperature.
DallasTemperature sensors(&oneWire);
 
void setup(void)
{
  // start serial port
  //Serial.begin(9600);
  //Serial.println("Dallas Temperature IC Control Library Demo");

  // Start up the library
  sensors.begin();
  pinMode(switchPin, INPUT);
}
 
 
void loop(void)
{
  switchState = digitalRead(switchPin);
  if (switchState == HIGH) {
    //Serial.print(" Requesting temperatures...");
    sensors.requestTemperatures(); // Send the command to get temperatures
    //Serial.println("DONE");
    //Serial.print("Temperature for Device 1 is: ");
    currentTemp = sensors.getTempFByIndex(0);
  
    //Serial.print(currentTemp); // Why "byIndex"? 
    currentTemp = max(currentTemp, cold);
    currentTemp = min(currentTemp, hot);
    int currentColor = map(currentTemp, cold, hot, 0, 255);
    analogWrite(redPin, currentColor);
    analogWrite(bluePin, 255-currentColor);
  } else {
   pinMode(redPin, INPUT);
   pinMode(greenPin, INPUT);
   pinMode(bluePin, INPUT); 
  }
 
}
