#######################################################################
# Partition Wizard for ESP32 - ESP32C3 - ESP32S2
#
# use : `import partition_wizard`
#
# Provides low-level objects and a Web UI
# rm Partition_Wizard.tapp; zip Partition_Wizard.tapp -j -0 Partition_Wizard/autoexec.be Partition_Wizard/partition_wizard.be
#######################################################################

var biowin_ui = module('biowin_ui')

#################################################################################
# Partition_wizard_UI
#
# WebUI for the partition manager
#################################################################################
class BioWINUi
 
  def init()
    import persist

    if persist.find("factory_migrate") == true
      # remove marker to avoid bootloop if something goes wrong
      tasmota.log("UPL: Resuming after step 1", 2)
      persist.remove("factory_migrate")
      persist.save()     
    end
  end

  # create a method for adding a button to the main menu
  # the button 'Partition Wizard' redirects to '/part_wiz?'
  def web_add_config_button()
    import webserver

    webserver.content_send(
      "<form id=but_part_mgr style='display: block;' action='biowin' method='get'><button>BioWIN Module Configuration</button></form><p></p>")
  end

  #######################################################################
  # Display the complete page
  #######################################################################
  def page_biowin_mgr()
    import webserver
    import persist

    if !webserver.check_privileged_access() return nil end

    webserver.content_start("BioWIN Configuration")           #- title of the web page -#
    webserver.content_send_style()                  #- send standard Tasmota styles -#

    var pin = nil

    webserver.content_send("<p><form id=biowin_ui style='display: block;' action='/biowin' method='post'>")

    webserver.content_send("<tr><td style='width:120px'><b>RX pin</b></td><td style='width:180px'>")
    # webserver.content_send(format("<tr><td><b>Port</b></td><td>"))
    webserver.content_send(format("<input type='number' min='0' name='pin' value='%i'>", persist.biowin_pin))

    webserver.content_send("<button name='biowinapply' class='button bgrn'>Apply</button>")
    
    webserver.content_send("</form></p>")

    webserver.content_button(webserver.BUTTON_CONFIGURATION) #- button back to management page -#

    webserver.content_stop()                        #- end of web page -#
  end


def page_biowin_ctl()
    import webserver
    import persist

    var pin = -1

    if webserver.has_arg("biowinapply")

        pin = int(webserver.arg("pin"))
        if pin < 1 || pin > 65535
            pin = 6454 
        end
    end

    persist.biowin_pin = pin
    persist.save()

    print("Got PIN!")
    print(pin)

    webserver.redirect("/cn?")
end



  #- ---------------------------------------------------------------------- -#
  # respond to web_add_handler() event to register web listeners
  #- ---------------------------------------------------------------------- -#
  #- this is called at Tasmota start-up, as soon as Wifi/Eth is up and web server running -#
  def web_add_handler()
    import webserver

    #- we need to register a closure, not just a function, that captures the current instance -#
    webserver.on("/biowin", / -> self.page_biowin_mgr(), webserver.HTTP_GET)
    webserver.on("/biowin", / -> self.page_biowin_ctl(), webserver.HTTP_POST)
  end
end


biowin_ui.BioWINUi = BioWINUi


#- create and register driver in Tasmota -#
if tasmota
  var biowin_ui_instance = biowin_ui.BioWINUi()
  tasmota.add_driver(biowin_ui_instance)

  ## can be removed if put in 'autoexec.bat'
  biowin_ui_instance.web_add_handler()
end

return biowin_ui

#- Example

import partition

# read
p = partition.Partition()
print(p)

-#
