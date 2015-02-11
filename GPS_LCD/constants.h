#ifndef CONSTANTS_H
#define CONSTANTS_H

// Set the pins used for the GPS shield
#define gpsChipPowerPin 4
#define gpsHasLockPin 5
#define gpsWritingToSDPin 6
#define chipSelect 10

// power saving modes
#define SLEEPDELAY 0    /* power-down time in seconds. Max 65535. Ignored if TURNOFFGPS == 0 */
#define TURNOFFGPS 0    /* set to 1 to enable powerdown of arduino and GPS. Ignored if SLEEPDELAY == 0 */
#define LOG_RMC_FIXONLY 0  /* set to 1 to only log to SD when GPD has a fix */

// what to log
#define LOG_RMC 1 // RMC-Recommended Minimum Specific GNSS Data, message 103,04
#define LOG_GGA 0 // GGA-Global Positioning System Fixed Data, message 103,00
#define LOG_GLL 0 // GLL-Geographic Position-Latitude/Longitude, message 103,01
#define LOG_GSA 0 // GSA-GNSS DOP and Active Satellites, message 103,02
#define LOG_GSV 0 // GSV-GNSS Satellites in View, message 103,03
#define LOG_VTG 0 // VTG-Course Over Ground and Ground Speed, message 103,05

// Set the GPSRATE to the baud rate of the GPS module. Mine is 4800
#define GPSRATE 4800

// #define GPS_TX_PIN 2
// #define GPS_RX_PIN 3
#define GPS_TX_PIN 50
#define GPS_RX_PIN 51

// Set the timezone
#define TIMEZONE -6

//Temp Sensor Bus
#define ONE_WIRE_BUS 24

//External Controls
#define SWITCH_UP 26 //Up means temp controlled
#define SWITCH_DOWN 27 //Down means remote controlled
#define RED_BUTTON 28
#define BLACK_BUTTON 29

//Lighting Controls
#define RED_CHANNEL 44
#define GREEN_CHANNEL 45
#define BLUE_CHANNEL 46

//Temperature
#define HOT 80
#define COLD 60

#define DEBUG_LIGHTS false
#define DEBUG_TEMPS false
#define DEBUG_GPS false

#endif