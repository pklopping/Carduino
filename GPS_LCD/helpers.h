// read a Hex value and return the decimal equivalent
uint8_t parseHex(char c) {
  if (c < '0')
    return 0;
  if (c <= '9')
    return c - '0';
  if (c < 'A')
    return 0;
  if (c <= 'F')
    return (c - 'A')+10;
}

// blink out an error code
void error(uint8_t errno) {
/*
  if (SD.errorCode()) {
    putstring("SD error: ");
    Serial.print(card.errorCode(), HEX);
    Serial.print(',');
    Serial.println(card.errorData(), HEX);
  }
  */
  while(1) {
    for (i=0; i<errno; i++) {
      digitalWrite(led1Pin, HIGH);
      digitalWrite(led2Pin, HIGH);
      delay(100);
      digitalWrite(led1Pin, LOW);
      digitalWrite(led2Pin, LOW);
      delay(100);
    }
    for (; i<10; i++) {
      delay(200);
    }
  }
}

void sleep_sec(uint16_t x) {
  while (x--) {
     // set the WDT to wake us up!
    WDTCSR |= (1 << WDCE) | (1 << WDE); // enable watchdog & enable changing it
    WDTCSR = (1<< WDE) | (1 <<WDP2) | (1 << WDP1);
    WDTCSR |= (1<< WDIE);
    set_sleep_mode(SLEEP_MODE_PWR_DOWN);
 //   sleep_enable();
    sleep_mode();
//    sleep_disable();
  }
}

SIGNAL(WDT_vect) {
  WDTCSR |= (1 << WDCE) | (1 << WDE);
  WDTCSR = 0;
}

char* substr(char* arr, int begin, int len)
{
    char* res = new char[len];
    for (int i = 0; i < len; i++)
        res[i] = *(arr + begin + i);
    res[len] = 0;
    return res;
}

char* formattedTime(char *time) {
	String timeString = "";
	char *timeCharArray = "00:00";
	uint8_t hour = 0;
	uint8_t minute = 0;
	hour = hour + (10 * (time[0]-'0'));
	hour = hour + (time[1]-'0');
	hour = hour + TIMEZONE;
	if (hour < 0) {
		hour = hour+24;
	}
	minute = minute + (10 * (time[2]-'0'));
	minute = minute + (time[3]-'0');
  if (hour < 10) {
    timeString += '0';
  }
	timeString += String(hour);
	timeString += ":";
  if (minute < 10) {
    timeString += '0';
  }
	timeString += String(minute);
	//convert back to char array
	timeString.toCharArray(timeCharArray,6);
	return timeCharArray;
}

char* parseGPSString(int targetIndex, char *inputString) {
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

float getSpeed(char *gpsString) {
  float knots = atof(parseGPSString(7,gpsString));
  return knots*1.15077;
}

bool checkForBlankSpeed(char *gpsString) {
  char *speed = parseGPSString(7,gpsString);
  return (speed == "");
}

float getHeading(char *gpsString) {
  return atof(parseGPSString(8,gpsString));
}