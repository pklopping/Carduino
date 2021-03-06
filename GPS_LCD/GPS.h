#ifndef GPS_H
#define GPS_H
#define BUFFSIZE 90

#include <Arduino.h>
#include <SD.h>
#include "constants.h"
#include <SoftwareSerial.h>

class GPS {

public:
	static bool hasLock; // current fix state
	static char currTime[5]; //current timestring from the GPS hhmmss.ddd
	static float currSpeed; //current speed from GPS in knots
	static float currHeading; //current heading from GPS
	static bool speedIsBlank;

	GPS();
	static int setupSD();
	static int createLog();
	static void configureGpsSerial();
	static void readGPS();

private:
	static uint8_t i;
	static char buffer[BUFFSIZE];
	static uint8_t bufferidx;
	static bool gotGPRMC;    //true if current data is a GPRMC strinng
	static File logfile;
	static SoftwareSerial gpsSerial;
	static uint8_t parseHex(char);
	static void setSpeed(char *);
	static void setHeading(char *);
	static void checkForBlankSpeed(char*);
	static char* parseGPSString(int, char*);
	static char* substr(char*, int, int);
};

#endif
