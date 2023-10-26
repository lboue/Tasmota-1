#
# Matter_Plugin_Sensor_SmokeCO.be - implements the behavior for a Pressure Sensor
#
# Copyright (C) 2023  Stephan Hadinger & Theo Arends
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import matter

# Matter plug-in for core behavior

#@ solidify:Matter_Plugin_Sensor_SmokeCO,weak

class Matter_Plugin_Sensor_SmokeCO : Matter_Plugin_Sensor
  static var TYPE = "smokeco"                        # name of the plug-in in json
  static var DISPLAY_NAME = "Smoke CO"             # display name of the plug-in
  static var JSON_NAME = "SmokeCO"                 # Name of the sensor attribute in JSON payloads
  static var UPDATE_COMMANDS = matter.UC_LIST(_class, "SmokeCO")
  static var CLUSTERS  = matter.consolidate_clusters(_class, {
    0x005C: [0,1,2,0xFFFC,0xFFFD],                 # Smoke CO Alarm
  })
  static var TYPES = { 0x0305: 1 }                 # Smoke CO Alarm, Initial Release

  var tasmota_switch_index                          # Switch number in Tasmota (one based)
  var shadow_smokeco

  #############################################################
  # Constructor
  def init(device, endpoint, config)
    super(self).init(device, endpoint, config)
    self.shadow_smokeco = false
  end

  #############################################################
  # parse_configuration
  #
  # Parse configuration map
  def parse_configuration(config)
    self.tasmota_switch_index = int(config.find(self.ARG #-'relay'-#, 1))
    if self.tasmota_switch_index <= 0    self.tasmota_switch_index = 1    end
  end

  #############################################################
  # Update shadow
  #
  def update_shadow()
    super(self).update_shadow()
    var switch_str = "Switch" + str(self.tasmota_switch_index)

    var j = tasmota.cmd("Status 8", true)
    if j != nil   j = j.find("StatusSNS") end
    if j != nil && j.contains(switch_str)
      var state = (j.find(switch_str) == "ON")

      if (self.shadow_smokeco != state)
        self.attribute_updated(0x005C, 0x0000)
      end
      self.shadow_smokeco = state
    end
  end

  #############################################################
  # read an attribute
  #
  def read_attribute(session, ctx, tlv_solo)
    var TLV = matter.TLV
    var cluster = ctx.cluster
    var attribute = ctx.attribute

    # ====================================================================================================
    if   cluster == 0x005C              # ========== Smoke CO Alarm ==========
      if   attribute == 0x0000          #  ---------- MeasuredValue / i16 ----------
        if self.shadow_value != nil
          return tlv_solo.set(TLV.I2, int(self.shadow_value))
        else
          return tlv_solo.set(TLV.NULL, nil)
        end
      elif attribute == 0x0001          #  ---------- SmokeState / i16 ----------
        return tlv_solo.set(TLV.I2, 500)
      elif attribute == 0x0002          #  ---------- COState / i16 ----------
        return tlv_solo.set(TLV.I2, 1500)
        
      elif attribute == 0x0003          #  ---------- BatteryAlert / i16 ----------
        return tlv_solo.set(TLV.I2, 1500)
      elif attribute == 0x0004          #  ---------- DeviceMuted / i16 ----------
        return tlv_solo.set(TLV.I2, 0)
   
      elif attribute == 0x0005          #  ---------- TestInProgress / bool ----------
        return tlv_solo.set(TLV.I2, false)
      elif attribute == 0x0006          #  ---------- HardwareFaultAlert / bool ----------
        return tlv_solo.set(TLV.I2, false)
      elif attribute == 0x0007          #  ---------- EndOfServiceAlert / i16 ----------
        return tlv_solo.set(TLV.I2, 0) # Device has not expired 
      elif attribute == 0x0008          #  ---------- DeviceMuted / i16 ----------
        return tlv_solo.set(TLV.I2, 1500)
      elif attribute == 0x0009          #  ---------- DeviceMuted / i16 ----------
        return tlv_solo.set(TLV.I2, 1500)

      elif attribute == 0x000A          #  ---------- ContaminationState / i16 ----------
        return tlv_solo.set(TLV.I2, 1500)
      elif attribute == 0x000B          #  ---------- SmokeSensitivityLevel / i16 ----------
        return tlv_solo.set(TLV.I2, 1500)
      elif attribute == 0x000C          #  ---------- ExpiryDate / epoch-s ----------
        return tlv_solo.set(TLV.I2, 1767225600)
        
      elif attribute == 0xFFFC          #  ---------- FeatureMap / map32 ----------
        # 0 SMOKE SmokeAlarm    Supports Smoke alarm
        # 1 CO COAlarm          Supports CO alarm
        return tlv_solo.set(TLV.U4, 0)    # 0 = Smoke alarm
      elif attribute == 0xFFFD          #  ---------- ClusterRevision / u2 ----------
        return tlv_solo.set(TLV.U4, 3)    # 3 = New data model format and notation
      end

    else
      return super(self).read_attribute(session, ctx, tlv_solo)
    end
  end

end
matter.Plugin_Sensor_Smokeco = Matter_Plugin_Sensor_SmokeCO
