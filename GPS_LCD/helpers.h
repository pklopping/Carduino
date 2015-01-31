
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
      digitalWrite(gpsHasLockPin, HIGH);
      digitalWrite(gpsWritingToSDPin, HIGH);
      delay(100);
      digitalWrite(gpsHasLockPin, LOW);
      digitalWrite(gpsWritingToSDPin, LOW);
      delay(100);
    }
    for (; i<10; i++) {
      delay(200);
    }
  }
}

SIGNAL(WDT_vect) {
  WDTCSR |= (1 << WDCE) | (1 << WDE);
  WDTCSR = 0;
}

char* formattedTime(char *time) {
	String timeString = "";
	char *timeCharArray = "00:00";
	int hour = 0;
	int minute = 0;
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
