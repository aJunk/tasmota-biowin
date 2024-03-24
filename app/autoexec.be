import sys
var wd = tasmota.wd
if size(wd) sys.path().push(wd) end

import biowin
import biowin_ui

if size(wd) sys.path().pop() end


meter = biowin.BioWINInterface()
tasmota.add_driver(meter)