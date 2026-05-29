---
name: arduino-cli
description: Compile, upload and manage Arduino sketches. Use when compiling or uploading Arduino code, managing boards/libraries, or working with .ino/.cpp hardware projects. Keywords: firmware, microcontroller, IoT, embedded, AVR, ESP32, Arduino.
---

# Arduino CLI Skill

## Quick Reference

```bash
arduino-cli version
```

### Setup

```bash
# Initialize platform index and update cores/libraries
arduino-cli core update-index
arduino-cli core search arduino          # search for boards
arduino-cli core install arduino:avr     # AVR (Uno, Nano, Mega)
arduino-cli core list --json             # see what's installed

# Third-party cores (ESP32):
arduino-cli core install esp32:esp32 -u https://espressif.github.io/arduino-esp32/package_esp32_index.json

# Platform manager (newer style):
arduino-cli core search espressif
```

### Compile & Upload

```bash
# Compile — must specify fqbn (fully qualified board name) and a directory with .ino or multiple sketches
arduino-cli compile --fqbn arduino:avr:uno /path/to/sketch/

# Single-file compile (e.g., for CI):
arduino-cli compile --fqbn arduino:avr:uno -i sketch.ino

# Upload to serial port:
arduino-cli upload -p /dev/ttyUSB0 --fqbn arduino:avr:uno /path/to/sketch/
arduino-cli upload -p /dev/ttyACM0 --fqbn esp32:esp32:esp32s3 /path/to/sketch/

# Upload with additional flags (verify after flash, baud rate):
arduino-cli upload --port /dev/ttyUSB0 --baud 115200 --verify --fqbn arduino:avr:uno /path/to/sketch/

# Compile then check where the hex goes (useful before upload):
arduino-cli compile -e --output-dir ./build-artifacts --fqbn arduino:avr:uno /path/to/sketch/
```

### Libraries

```bash
# Search libraries
arduino-cli lib search <keyword>
arduino-cli lib list                     # list installed
arduino-cli lib install <library-name>   # e.g., DHT sensor, ESP8266WiFi
```

### Monitor / Serial

```bash
arduino-cli monitor -p /dev/ttyUSB0 --port-speed 115200
```

## Common fqbn values

| Board | FQBN |
|---|---|
| Arduino Uno | `arduino:avr:uno` |
| Arduino Nano | `arduino:avr:nano` |
| Arduino Mega 2560 | `arduino:avr:mega` |
| ESP32 DevKit V1 | `esp32:esp32:esp32` |
| ESP32-S3 | `esp32:esp32:esp32s3` |
| STM32 | `stm32duino:stm32` |

## Workflow Tips

- Run `arduino-cli core list --format table` to verify installed boards at session start.
- Always specify `-p /dev/<port>` on the upload command; omitting it tries all ports which can hang or flash the wrong device.
- To see compiler output (useful for debugging missing symbols): append `--verbose`.