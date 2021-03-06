#include "GPS.h"
#include "GPSConfig.h"
#include <SoftwareSerial.h>
#include <String.h>
#include <avr/sleep.h>

uint8_t GPS::bufferidx = 0;
char GPS::buffer[BUFFSIZE];
bool GPS::hasLock = false; // current fix state
char GPS::currTime[5]; //current timestring from the GPS hhmmss.ddd
float GPS::currSpeed = 0.0; //current speed from GPS in knots
float GPS::currHeading = 0.0; //current heading from GPS
bool GPS::speedIsBlank = true;
File GPS::logfile;
bool GPS::gotGPRMC;
SoftwareSerial GPS::gpsSerial = SoftwareSerial(GPS_TX_PIN, GPS_RX_PIN);

GPS::GPS() {
	//do init
	WDTCSR |= (1 << WDCE) | (1 << WDE);
	WDTCSR = 0;
	configureGpsSerial();
	pinMode(gpsHasLockPin, OUTPUT);
	pinMode(gpsWritingToSDPin, OUTPUT);
	pinMode(gpsChipPowerPin, OUTPUT);
	digitalWrite(gpsChipPowerPin, LOW); //Turn on GPS chip
}

int GPS::setupSD() {
	// see if the card is present and can be initialized:
	if (!SD.begin(chipSelect)) {
		if (DEBUG_GPS)
			Serial.println("Card init. failed!");
		return(1);
	}
	return 0;
}

int GPS::createLog() {
	strcpy(buffer, "");
	for (int8_t i = 0; i < 1000; i++) {
		// create if does not exist, do not open existing, write, sync after write
		sprintf(buffer, "LOG%03d.TXT", i);
		if (DEBUG_SD){
			Serial.print("Trying: ");
			Serial.println(buffer);
		}
		if (! SD.exists(buffer)) {
			if (DEBUG_SD){
				Serial.println("Using ");
				Serial.println(buffer);
			}
			break;
		}
	}
	logfile = SD.open(buffer, FILE_WRITE);
	if( ! logfile ) {
		if (DEBUG_GPS) {
			Serial.print("Couldnt create ");
			Serial.println(buffer);
		}
		return(3);
	}
	if (DEBUG_GPS) {
		Serial.print("Writing to ");
		Serial.println(buffer);
	}
	return 0;
}

void GPS::configureGpsSerial() {
	// connect to the GPS at the desired rate
	gpsSerial.begin(GPSRATE);

	gpsSerial.print(SERIAL_SET);
	delay(250);
	//Whoops, looks like I need to tell it to turn off this other junk
	gpsSerial.print(DDM_OFF);
	delay(250);
	gpsSerial.print(GGA_OFF);
	delay(250);
	gpsSerial.print(GLL_OFF);
	delay(250);
	gpsSerial.print(GSA_OFF);
	delay(250);
	gpsSerial.print(GSV_OFF);
	delay(250);
	gpsSerial.print(RMC_ON);
	delay(250);
	gpsSerial.print(VTG_OFF);
	delay(250);
	gpsSerial.print(WAAS_OFF);
	delay(250);

	if (DEBUG_GPS)
		Serial.println("GPS Ready!");
}

/*
	setSpeed examines the current GPRMC sentence and pulls out the speed
	The GPRMC sentence shows velocity in knots, but we want it in MPH, so we convert it.
*/
void GPS::setSpeed(char *gpsString) {
	//Grab the seventh position of the sentence, convert it to a float, and convert knots to mph
	currSpeed = atof(parseGPSString(7,gpsString))*1.15077;
}

/*
	setHeading examines the GPRMC sentence and pulls out the heading
*/
void GPS::setHeading(char *gpsString) {
	currHeading = atof(parseGPSString(8,gpsString));
}

void GPS::readGPS() {
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
			if (DEBUG_GPS)
				Serial.print('*');
			bufferidx = 0;
			return;
		}
		// get checksum
		sum = parseHex(buffer[bufferidx-3]) * 16;
		sum += parseHex(buffer[bufferidx-2]);

		// check checksum
		for (int i=1; i < (bufferidx-4); i++) {
			sum ^= buffer[i];
		}
		if (sum != 0) {
			//putstring_nl("Cxsum mismatch");
			if (DEBUG_GPS)
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
			for (int i = 0; i < 6; i++) {
				currTime[i] = p[i];
			}
			p = strchr(p, ',')+1;       // skip to 3rd item

			if (p[0] == 'V') {
				digitalWrite(gpsHasLockPin, LOW);
				hasLock = false;
			} else {
				digitalWrite(gpsHasLockPin, HIGH);
				hasLock = true;
			}
		}

		if (gotGPRMC && hasLock) {
			checkForBlankSpeed(buffer);
			setSpeed(buffer);
			setHeading(buffer);
		}

		if (LOG_RMC_FIXONLY) {
			if (!hasLock) {
				Serial.print('_');
				bufferidx = 0;
				return;
			}
		}
		// rad. lets log it!
		if (DEBUG_GPS) {
			Serial.print(buffer);    //first, write it to the serial monitor
			Serial.print('#');
		}
		if (gotGPRMC)      //If we have a GPRMC string
		{
			// Bill Greiman - need to write bufferidx + 1 bytes to getCR/LF
			bufferidx++;

			digitalWrite(gpsWritingToSDPin, HIGH);      // Turn on LED 2 (indicates write to SD)

			logfile.write((uint8_t *) buffer, bufferidx);    //write the string to the SD file
			logfile.flush();
			/*
			if( != bufferidx) {
			   putstring_nl("can't write!");
			   error(4);
			}
			*/

			digitalWrite(gpsWritingToSDPin, LOW);    //turn off LED2 (write to SD is finished)

			bufferidx = 0;    //reset buffer pointer

			return;
		}//if (gotGPRMC)

	}
	bufferidx++;
	if (bufferidx == BUFFSIZE-1) {
		if (DEBUG_GPS)
			Serial.print('!');
		bufferidx = 0;
	}
}

// read a Hex value and return the decimal equivalent
uint8_t GPS::parseHex(char c) {
  if (c < '0')
    return 0;
  if (c <= '9')
    return c - '0';
  if (c < 'A')
    return 0;
  if (c <= 'F')
    return (c - 'A')+10;
}

char* GPS::parseGPSString(int targetIndex, char *inputString) {
  //Sometimes I hate strings in C, so here's a workaround!
  String inputCopy = String(inputString);
  int currentIndex = 0;
  int strIndex = 0;
  int delimIndex = 0;
  char ret[100];
  while (inputCopy.indexOf(',') != -1) {
    delimIndex = inputCopy.indexOf(',');
    String field = inputCopy.substring(0,delimIndex);
    // Serial.println(field);
    if (currentIndex == targetIndex) {
      field.toCharArray(ret,100);
      return ret;
    }
    inputCopy = inputCopy.substring(delimIndex+1);
    currentIndex = currentIndex + 1;
  }
  return "ERR";
}

char* GPS::substr(char* arr, int begin, int len)
{
    char* res = new char[len];
    for (int j = 0; j < len; j++)
        res[j] = *(arr + begin + j);
    res[len] = 0;
    return res;
}

void GPS::checkForBlankSpeed(char *gpsString) {
  char *speed = parseGPSString(7,gpsString);
  speedIsBlank = (speed == "");
}
