#
# Matter_Plugin_Sensor_Pressure.be - implements the behavior for a Pressure Sensor
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

#@ solidify:Matter_Plugin_Sensor_Pressure,weak

class Matter_Plugin_Sensor_Pressure : Matter_Plugin_Sensor
  static var TYPE = "smoke"                        # name of the plug-in in json
  static var DISPLAY_NAME = "Smoke CO"             # display name of the plug-in
  static var JSON_NAME = "SmokeCO"                 # Name of the sensor attribute in JSON payloads
  static var UPDATE_COMMANDS = matter.UC_LIST(_class, "SmokeCO")
  static var CLUSTERS  = matter.consolidate_clusters(_class, {
    0x005C: [0,1,2,0xFFFC,0xFFFD],                 # Smoke CO Alarm
  })
  static var TYPES = { 0x0305: 1 }                 # Smoke CO Alarm, Initial Release

  #############################################################
  # Pre-process value
  #
  # This must be overriden.
  # This allows to convert the raw sensor value to the target one, typically int
  def pre_value(val)
    return val != nil ? int(val) : nil
  end

  #############################################################
  # Called when the value changed compared to shadow value
  #
  # This must be overriden.
  # This is where you call `self.attribute_updated(<cluster>, <attribute>)`
  def value_changed()
    self.attribute_updated(0x005C, 0x0000)
  end

  #############################################################
  # read an attribute
  #
  def read_attribute(session, ctx, tlv_solo)
    var TLV = matter.TLV
    var cluster = ctx.cluster
    var attribute = ctx.attribute

    # ====================================================================================================
    if   cluster == 0x005C              # ========== Pressure Measurement 2.4 p.98 ==========
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
matter.Plugin_Sensor_Pressure = Matter_Plugin_Sensor_Pressure
