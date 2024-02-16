#
# Matter_Plugin_Fan.be - implements the behavior for fans
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

#@ solidify:Matter_Plugin_Fan,weak

class Matter_Plugin_Fan : Matter_Plugin_Device
  static var TYPE = "fan"                       	# name of the plug-in in json
  static var DISPLAY_NAME = "Fan"                   # display name of the plug-in
  static var ARG  = "fan"                       	# additional argument name (or empty if none)
  static var ARG_TYPE = / x -> int(x)               # function to convert argument to the right type
  static var ARG_HINT = "Relay<x> number"
  static var CLUSTERS  = matter.consolidate_clusters(_class, {
    # 0x001D: inherited                             # Descriptor Cluster 9.5 p.453
    # 0x0003: inherited                             # Identify 1.2 p.16
    # 0x0004: inherited                             # Groups 1.3 p.21
    # 0x0005: inherited                             # Scenes 1.4 p.30 - no writable
    0x0202: [0,5,7,0xA,0xB,0xD,0xE,0x17],           # Window Covering 5.3 p.289
  })
  static var TYPES = { 0x0202: 2 }                  # New data model format and notation

  var tasmota_fan_index                         	# Fan number in Tasmota (zero based)
  var shadow_fan_pos
  var shadow_fan_target
  var shadow_fan_direction                      	# 1=opening -1=closing 0=not moving TODO
  var shadow_fan_inverted                       	# 1=same as matter 0=matter must invert

  #############################################################
  # parse_configuration
  #
  # Parse configuration map
  def parse_configuration(config)
    self.tasmota_fan_index = config.find(self.ARG #-'relay'-#)
    if self.tasmota_fan_index == nil     self.tasmota_fan_index = 0   end
    self.shadow_fan_inverted = -1
  end

  #############################################################
  # Update inverted set
  #
  # Update "inverted" flag from Status 13
  def update_inverted()
    # get the min/max tilt values
    if (self.shadow_fan_inverted == -1)
      var r_st13 = tasmota.cmd("Status 13", true)     # issue `Status 13`
      if r_st13.contains('StatusSHT')
        r_st13 = r_st13['StatusSHT']        # skip root
        var d = r_st13.find("SHT"+str(self.tasmota_fan_index), {}).find('Opt')
        # tasmota.log("MTR: opt: "+str(d))
        if d != nil
          self.shadow_fan_inverted = int(d[size(d)-1])  # inverted is at the most right character
          # tasmota.log("MTR: Inverted flag: "+str(self.shadow_fan_inverted))
        end
      end
    end
  end

  #############################################################
  # Update shadow
  #
  def update_shadow()
    if !self.VIRTUAL
      self.update_inverted()
      var sp = tasmota.cmd("FanPosition" + str(self.tasmota_fan_index + 1), true)
      if sp
        self.parse_sensors(sp)
      end
    end
    super(self).update_shadow()
  end

  #############################################################
  # read an attribute
  #
  def read_attribute(session, ctx, tlv_solo)
    var TLV = matter.TLV
    var cluster = ctx.cluster
    var attribute = ctx.attribute
    var matter_position

    # ====================================================================================================
	# ZCL_FAN_CONTROL_CLUSTER_ID = 0x0202
	# Matter 1.2 4.4 Fan Control Cluster p.257
	# Rev4 --> Change conformance for FanModeSequenceEnum
	
    if   cluster == 0x0202              # ========== Fan Control 4.4.p.257 ==========
      self.update_shadow_lazy()
      self.update_inverted()
      if   attribute == 0x0000          #  ---------- FanMode Type / INT8U ----------
        return tlv_solo.set(TLV.U1, 0)  # 0 = Off

      elif attribute == 0x0001          #  ---------- FanModeSequence / INT8U
        return tlv_solo.set(TLV.U1, 0)	# 0 = OffLowMedHigh
		
      elif attribute == 0x0002          #  ---------- PercentSetting / INT8U
        return tlv_solo.set(TLV.U1, 0)	# 0
		
      elif attribute == 0x0003          #  ---------- PercentCurrent / INT8U
        return tlv_solo.set(TLV.U1, 0)	# 0

      end

    end
    return super(self).read_attribute(session, ctx, tlv_solo)
  end

  #############################################################
  # Invoke a command
  #
  # returns a TLV object if successful, contains the response
  #   or an `int` to indicate a status
  def invoke_request(session, val, ctx)
    import light
    var TLV = matter.TLV
    var cluster = ctx.cluster
    var command = ctx.command

    # ====================================================================================================
    if   cluster == 0x0202              # ========== Fan Control 4.4 p.264 ==========
      self.update_shadow_lazy()
      if   command == 0x0000            # ---------- Step ----------
	  
	# Fields
	# 0 Direction StepDirectionEnum Increase
	# Direction Field --> This field SHALL indicate whether the fan speed increases or decreases to the next step value.
    
		# StepDirectionEnum Type
		# Value Name Summary Conformance
		# 0 Increase Step moves in increasing direction
		# 1 Decrease Step moves in decreasing direction
		  
        # TODO tasmota.cmd("FanStopOpen"+str(self.tasmota_fan_index+1), true)
        self.update_shadow()
        return true
      end


    else
      return super(self).invoke_request(session, val, ctx)
    end

  end

  #############################################################
  # parse sensor
  #
  # parse the output from `FanPosition`
  # Ex: `{"Fan1":{"Position":50,"Direction":0,"Target":50,"Tilt":30}}`
  def parse_sensors(payload)
    var k = "Fan" + str(self.tasmota_fan_index + 1)
    if payload.contains(k)
      var v = payload[k]
      # tasmota.log(format("MTR: getting fan values(%i): %s", self.endpoint, str(v)), 2)
      # Position
      var val_pos = v.find("Position")
      if val_pos != nil
        if val_pos != self.shadow_fan_pos
          self.attribute_updated(0x0202, 0x000E)   # CurrentPositionLiftPercent100ths
        end
        self.shadow_fan_pos = val_pos
      end
      # Direction
      var val_dir = v.find("Direction")
      if val_dir != nil
        if val_dir != self.shadow_fan_direction
          self.attribute_updated(0x0202, 0x000A)   # OperationalStatus
        end
        self.shadow_fan_direction = val_dir
      end
      # Target
      var val_target = v.find("Target")
      if val_target != nil
        if val_target != self.shadow_fan_target
          self.attribute_updated(0x0202, 0x000B)   # TargetPositionLiftPercent100ths
        end
        self.shadow_fan_target = val_target
      end
      #
    end
  end

end
matter.Plugin_Fan = Matter_Plugin_Fan
