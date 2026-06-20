/*
 * ChipGhost signal generator -- Arduino Uno test fixture
 *
 * Drives known digital signals so the ChipGhost analyzer (a Mega 2560 running
 * the gillham SUMP firmware) has real traffic to capture, and sigrok/PulseView
 * has something to decode. This verifies the host capture pipeline end to end
 * before the ECP5 gateware is on hardware.
 *
 * Outputs:
 *   D1 (TX0) -- hardware UART, 9600 8N1, prints "ChipGhost\n" every 30 ms.
 *               Decode with sigrok's UART decoder -> readable text.
 *   D9       -- 1 kHz square wave via tone() (frequency/period reference).
 *   D8       -- ~2 Hz square wave (slow, easy-to-see channel).
 *
 * Wiring to the Mega 2560 analyzer (capture pins D22-D29):
 *   Uno D1  -> Mega D22   (UART)
 *   Uno D9  -> Mega D23   (1 kHz)
 *   Uno D8  -> Mega D24   (2 Hz)
 *   Uno GND -> Mega GND   (REQUIRED -- common ground)
 *
 * Both boards are 5V logic: connect directly, no level shifting.
 * Note: D1 is the UART TX pin. If a sketch upload ever fails, pull the D1
 * jumper during upload (the bootloader uses D0/D1), then reconnect.
 */

const uint8_t PIN_SLOW = 8;   // ~2 Hz square
const uint8_t PIN_TONE = 9;   // 1 kHz square (tone() / background timer)

unsigned long lastUart = 0;
unsigned long lastSlow = 0;
bool slowState = false;

void setup() {
  Serial.begin(9600);        // UART out on D1
  pinMode(PIN_SLOW, OUTPUT);
  tone(PIN_TONE, 1000);      // continuous 1 kHz on D9
}

void loop() {
  unsigned long now = millis();

  // UART burst every 30 ms (string is ~10 ms at 9600 baud).
  if (now - lastUart >= 30) {
    lastUart = now;
    Serial.print("ChipGhost\n");
  }

  // 2 Hz square wave: toggle every 250 ms.
  if (now - lastSlow >= 250) {
    lastSlow = now;
    slowState = !slowState;
    digitalWrite(PIN_SLOW, slowState);
  }
}
