import webserver
import string
import mqtt

import crypto

var CRC_INIT=0xd5
var POLYNOMIAL=0x00


var STATE_IDLE     = 1
var STATE_SYNCING  = 2
var STATE_SYNCED   = 3
var STATE_DELIM_1  = 4
var STATE_COMPLETE = 5

var lkp_tbl = bytes("00F7B94E25D29C6B4ABDF3046F98D62194632DDAB14608FFDE296790FB0C42B57F88C6315AADE31435C28C7B10E7A95EEB1C52A5CE397780A15618EF84733DCAFE0947B0DB2C6295B4430DFA916628DF6A9DD3244FB8F60120D7996E05F2BC4B817638CFA4531DEACB3C7285EE1957A015E2AC5B30C7897E5FA8E6117A8DC334AB5C12E58E7937C0E11658AFC4337D8A3FC886711AEDA3547582CC3B50A7E91ED4236D9AF10648BF9E6927D0BB4C02F540B7F90E6592DC2B0AFDB3442FD8966155A2EC1B7087C93E1FE8A6513ACD8374C136788FE4135DAA8B7C32C5AE5917E02ADD93640FF8B6416097D92E45B2FC0BBE4907F09B6C22D5F4034DBAD126689F")

var biowin_module = module("biowin")



def crc8(bts)
    var crc = 0x00
    for i : 0..(bts.size()-1)
        var data = bts[i] ^ crc
        crc = lkp_tbl[data]
    end

    return crc
end

class BioWINInterface: Driver

    var ser 
    var buf
    var tick

    var packet

    var sync

    var yyyy
    var mm
    var dd
    var hh
    var mi
    var ss

    var state

    var msg_parsers

    #==== heater values

    var temp_ist_aussen
    var temp_ist_vor
    var temp_ist_rueck
    var temp_ist_boiler
    var temp_ist_raum
    var temp_soll_raum

    var ctrl_kessel

    var updated
    var values_good

    def parser_temp_ist(data)
        print("TEMP IST: " + data.tostring())
        self.temp_ist_aussen = real(data.geti(0, -2)/100.0)
        self.temp_ist_vor = real(data.geti(2, -2)/100.0)
        self.temp_ist_rueck = real(data.geti(4, -2)/100.0)
        self.temp_ist_boiler = real(data.geti(6, -2)/100.0)
    end
    def parser_temp_soll(data)
        print("TEMP SOLL: " + data.tostring())
    end
    def parser_brenner(data)
        print("BRENNER: " + data.tostring())
    end
    def parser_kessel(data)
        print("KESSEL: " + data.tostring())
    end
    def parser_pumpen(data)
        print("PUMPEN: " + data.tostring())
    end
    def parser_temp_bd_md(data)
        print("TMP RAUM: " + data.tostring())
        self.temp_ist_raum = real(data.geti(2, -2)/100.0)
        self.temp_soll_raum = real(data.geti(4, -2)/100.0)
    end

    def handle_message(pkt)
        if pkt[0] == 0x92
            # First nine bytes are command
            var f = self.msg_parsers.find(pkt[0..8])
            if f 
                f(pkt[9..-1])
                self.updated = true
            end
        elif pkt[0] == 0x9b
            # First ten bytes are command
            var f = self.msg_parsers.find(pkt[0..9])
            if f 
                f(pkt[10..-1])
                self.updated = true
            end
        end

        if self.temp_ist_aussen != nil &&
                self.temp_ist_vor != nil &&
                self.temp_ist_rueck != nil &&
                self.temp_ist_boiler != nil &&
                self.temp_ist_raum != nil &&
                self.temp_soll_raum != nil
            self.values_good = true
            return nil
        end

    end

    def run(inp)
       # ======= RECEIVER STATE MACHINE ======

        if self.state == STATE_IDLE
            if inp == 0x10
                self.state = STATE_SYNCING
            end
        elif self.state == STATE_SYNCING
            if inp == 0x02
                self.state = STATE_SYNCED
            else
                self.state = STATE_IDLE
            end
        elif self.state == STATE_SYNCED
            if inp == 0x10
                self.state = STATE_DELIM_1
            else
                self.buf.add(inp)
            end
        elif self.state == STATE_DELIM_1
            if inp == 0x10
                self.state = STATE_SYNCED
                self.buf.add(0x10)
            elif inp == 0x03
                self.state = STATE_COMPLETE

            end
        end

        if self.state == STATE_COMPLETE
            var crc = crc8(self.buf[0..-2])
            if crc != self.buf[-1]
                print("CRC mismatch!")
                print(crc)
                print(self.buf[-1])
            else
                self.handle_message(self.buf[0..-2])
            end

            self.buf.clear()
            self.state = STATE_IDLE
        end
    end

    def every_100ms()
        if !self.ser 
            print('Serial crashed!')
            return nil
        end 

        var tbuf = bytes()

        if self.ser.available()
            tbuf = self.ser.read()
        end

        for i : 0..(tbuf.size()-1)
            self.run(tbuf[i])
        end

    end

    def every_second()
        self.mqtt()
    end


    def init()
        import persist

        var pin = nil
        if persist.find("biowin_pin") == true
            pin = persist.biowin_pin
        else
            pin = 16
        end

        self.ser = serial(pin, -1, 4800, serial.SERIAL_8N1)
        self.buf = bytes()
        self.tick = 0

        self.state = STATE_IDLE

        self.msg_parsers = map()
        self.msg_parsers[bytes("92057F03026708220A")] = / a -> self.parser_temp_ist(a)
        self.msg_parsers[bytes("92057F03026708240C")] = / a -> self.parser_temp_soll(a)
        self.msg_parsers[bytes("92007F030267080204")] = / a -> self.parser_brenner(a)
        self.msg_parsers[bytes("92007F030267080305")] = / a -> self.parser_kessel(a)
        self.msg_parsers[bytes("92057F030267082006")] = / a -> self.parser_pumpen(a)
        self.msg_parsers[bytes("9B7F050283F70006210A")] = / a -> self.parser_temp_bd_md(a)

        self.temp_ist_aussen = nil
        self.temp_ist_vor = nil
        self.temp_ist_rueck = nil
        self.temp_ist_boiler = nil
        self.temp_ist_raum = nil
        self.temp_soll_raum = nil
    
        self.ctrl_kessel = nil
    
        self.updated = false
        self.values_good = false

        self.ser.flush()

    end

    def deinit()
    end

    def web_sensor()
        var msg = string.format(
             "{s}Outside temperature{m}%.2f degC{e}"..
             "{s}Inside temperature{m}%.2f degC{e}"..
             "{s}Heating temperature (pre){m}%.2f degC{e}"..
             "{s}Heating temperature (post){m}%.2f degC{e}"..
             "{s}Boiler temperature{m}%.2f degC{e}",
             self.temp_ist_aussen,self.temp_ist_raum, self.temp_ist_vor, self.temp_ist_rueck, self.temp_ist_boiler)
            tasmota.web_send_decimal(msg)
            
            msg = string.format(
                "{s}Inside set temperature{m}%.2f degC{e}",
                self.temp_soll_raum)
            tasmota.web_send_decimal(msg)
    end

    def mqtt()
        if !self.ser return nil end  #- exit if not initialized -#

        if !self.values_good || !self.updated
            return nil
        end

        var temp_string = string.format("{\"current\":"..
            "{"..
                "\"outside\":%.2f,"..
                "\"inside\":%.2f,"..
                "\"supply\":%.2f,"..
                "\"return\":%.2f,"..
                "\"boiler\":%.2f"..
            "}"..
        "}",
            self.temp_ist_aussen,self.temp_ist_raum, self.temp_ist_vor, self.temp_ist_rueck, self.temp_ist_boiler)

        var msg = string.format("{\"HeatingUnit\":"..
            "{"..
                "\"time\":%s,"..
                "\"data\":{"..
                    "\"temperature\":%s"..
                "}"..
            "}"..
        "}", tasmota.rtc(), temp_string)

        var split = string.split(msg, "\'")
        msg = split[0]
        if split.size() > 1
          for i: 1 .. (split.size()-1)
            msg += "\"" + split[i]
          end
        end

        mqtt.publish("HeatingUnit", msg)

        self.updated = false
    end

end


biowin_module.BioWINInterface = BioWINInterface

return biowin_module