# Tasmota BioWIN

This repository contains a Tasmota app for connecting to the application bus of certain Windhager heating systems. 

This project was started in 2021 and is based on information found in [this forum thread](https://www.haustechnikdialog.de/Forum/t/99932/Welcher-Bus-bei-FB-5210-Windhager).

For now it just published temperature data via MQTT. I will extend it to also include data about the boiler and burner when I get around to it.

## Overview
The application bus is not the internal LON-Bus, but connects the in-room control panel to the heating system. It is a single wire bus with about 12 volt for a logic high. It delivers power and a maximum of 50mA can be drawn. The communication itself is RS232 with a 1 byte checksum at the end.

Take care to use a voltage divider, RS232 interface or other means to not blow up the 3.3v input of your ESP board.

The ESP32 runs the awesome [Tasmota](https://tasmota.github.io/docs/) firmware and has a custom driver for the heating ystem written in [Berry](https://berry-lang.github.io/).

The source can be found in the [app](/app) folder.


## Usage

Download the Tasmota application from the [releases page](https://github.com/aJunk/tasmota-biowin/releases) and upload it to the filesystem. Restart the device.

By default pin 16 is used for receiving data. In the configuration menu you can find a new entry where you can set another pin if desired.

A MQTT-broker must be configured in the regular settings of Tasmota.

## License
This project is licensed under the GPLv3.

