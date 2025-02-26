var UPDATE_PERIOD = 0.05;


# TACAN: nav[1]
var nav1_back = 0;

var Tc               = props.globals.getNode("instrumentation/tacan");
var Vtc              = props.globals.getNode("instrumentation/nav[1]");
var Hsd              = props.globals.getNode("sim/model/AAE-AMX/instrumentation/hsd", 1);
var TcFreqs          = Tc.getNode("frequencies");
var TcTrueHdg        = Tc.getNode("indicated-bearing-true-deg");
var TcMagHdg         = Tc.getNode("indicated-mag-bearing-deg", 1);
var TcIdent          = Tc.getNode("ident");
var TcServ           = Tc.getNode("serviceable");
var TcXY             = Tc.getNode("frequencies/selected-channel[4]");
var VtcIdent         = Vtc.getNode("nav-id");
var VtcFromFlag      = Vtc.getNode("from-flag");
var VtcToFlag        = Vtc.getNode("to-flag");
var VtcHdgDeflection = Vtc.getNode("heading-needle-deflection");
var VtcRadialDeg     = Vtc.getNode("radials/selected-deg");
var HsdFromFlag      = Hsd.getNode("from-flag", 1);
var HsdToFlag        = Hsd.getNode("to-flag", 1);
var HsdCdiDeflection = Hsd.getNode("needle-deflection", 1);
var TcXYSwitch       = props.globals.getNode("sim/model/AAE-AMX/instrumentation/tacan/xy-switch", 1);
var TcModeSwitch     = props.globals.getNode("sim/model/AAE-AMX/instrumentation/tacan/mode", 1);
var TrueHdg          = props.globals.getNode("orientation/heading-deg");
var MagHdg           = props.globals.getNode("orientation/heading-magnetic-deg");
var MagDev           = props.globals.getNode("orientation/local-mag-dev", 1);

var mag_dev = 0;
var tc_mode = 0;

aircraft.data.add(VtcRadialDeg, TcModeSwitch);


# Compute local magnetic deviation.
var local_mag_deviation = func {
	var true = TrueHdg.getValue();
	var mag = MagHdg.getValue();
	mag_dev = geo.normdeg( mag - true );
	if ( mag_dev > 180 ) mag_dev -= 360;
	MagDev.setValue(mag_dev); 
}


# Set nav[1] so we can use radials from a TACAN station.
var nav1_freq_update = func {
	if ( tc_mode != 0 and tc_mode != 4 ) {
		var tacan_freq = getprop( "instrumentation/tacan/frequencies/selected-mhz" );
		var nav1_freq = getprop( "instrumentation/nav[1]/frequencies/selected-mhz" );
		var nav1_back = nav1_freq;
		setprop("instrumentation/nav[1]/frequencies/selected-mhz", tacan_freq);
	} else {
		setprop("instrumentation/nav[1]/frequencies/selected-mhz", nav1_back);
	}
}

var tacan_update = func {
	var tc_mode = TcModeSwitch.getValue();
	if ( tc_mode != 0 and tc_mode != 4 ) {

		# Get magnetic tacan bearing.
		var true_bearing = TcTrueHdg.getValue();
		var mag_bearing = geo.normdeg( true_bearing + mag_dev );
		if ( true_bearing != 0 ) {
			TcMagHdg.setDoubleValue( mag_bearing );
		} else {
			TcMagHdg.setDoubleValue(0);
		}

		# Get TACAN radials on HSD's Course Deviation Indicator.
		# CDI works with ils OR tacan OR vortac (which freq is tuned from the tacan panel).
		var tcnid = TcIdent.getValue();
		var vtcid = VtcIdent.getValue();
		if ( tcnid == vtcid ) {
			# We have a VORTAC.
			HsdFromFlag.setBoolValue(VtcFromFlag.getBoolValue());
			HsdToFlag.setBoolValue(VtcToFlag.getBoolValue());
			HsdCdiDeflection.setValue(VtcHdgDeflection.getValue());
		} else {
			# We have a legacy TACAN.
			var tcn_toflag = 1;
			var tcn_fromflag = 0;
			var tcn_bearing = TcMagHdg.getValue();
			var radial = VtcRadialDeg.getValue();
			var d = tcn_bearing - radial;
			if ( d > 180 ) { d -= 360 } elsif ( d < -180 ) { d += 360 }
			if ( d > 90 ) {
				d -= 180;
				tcn_toflag = 0;
				tcn_fromflag = 1;
			} elsif ( d < - 90 ) {
				d += 180;
				tcn_toflag = 0;
				tcn_fromflag = 1;
			}
			if ( d > 10 ) d = 10 ;
			if ( d < -10 ) d = -10 ;
			HsdFromFlag.setBoolValue(tcn_fromflag);
			HsdToFlag.setBoolValue(tcn_toflag);
			HsdCdiDeflection.setValue(d);
		}
	} else {
		TcMagHdg.setDoubleValue(0);
	}
}


# TACAN mode switch
var set_tacan_mode = func(s) {
	var m = TcModeSwitch.getValue();
	if ( s == 1 and m < 5 ) {
		m += 1;
	} elsif ( s == -1 and m > 0 ) {
		m -= 1;
	}
	TcModeSwitch.setValue(m);
	if ( m == 0 or m == 5 ) {
		TcServ.setBoolValue(0);
	} else {
		TcServ.setBoolValue(1);
	}
}


# TACAN XY switch
var tacan_switch_init = func {
	if (TcXY.getValue() == "X") { TcXYSwitch.setValue( 0 ) } else { TcXYSwitch.setValue( 1 ) }
}

var tacan_XYtoggle = func {
	if ( TcXY.getValue() == "X" ) {
		TcXY.setValue( "Y" );
		TcXYSwitch.setValue( 1 );
	} else {
		TcXY.setValue( "X" );
		TcXYSwitch.setValue( 0 );
	}
}

# One key bindings for RIO's ecm display mode or Pilot's hsd depending on the current view name
var mode_ecm_nav = props.globals.getNode("sim/model/AAE-AMX/controls/rio-ecm-display/mode-ecm-nav");
var hsd_mode_nav = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/hsd-mode-nav");
var select_key_ecm_nav = func {
	var v = getprop("sim/current-view/name");
	if (v == "RIO View") {
		mode_ecm_nav.setBoolValue( ! mode_ecm_nav.getBoolValue());
	} elsif (v == "Cockpit View") {
		var h = hsd_mode_nav.getValue() + 1;
		if ( h == 2 ) { h = -1 }
		hsd_mode_nav.setValue( h )
	}
}

# Save fuel state ###############
var bingo      = props.globals.getNode("sim/model/AAE-AMX/controls/fuel/bingo", 1);
var fwd_lvl    = props.globals.getNode("consumables/fuel/tank[0]/level-lbs", 1); # fwd group 4700 lbs
var aft_lvl    = props.globals.getNode("consumables/fuel/tank[1]/level-lbs", 1); # aft group 4400 lbs
var Lbb_lvl    = props.globals.getNode("consumables/fuel/tank[2]/level-lbs", 1); # left beam box 1250 lbs
var Lsp_lvl    = props.globals.getNode("consumables/fuel/tank[3]/level-lbs", 1); # left sump tank 300 lbs
var Rbb_lvl    = props.globals.getNode("consumables/fuel/tank[4]/level-lbs", 1); # right beam box 1250 lbs
var Rsp_lvl    = props.globals.getNode("consumables/fuel/tank[5]/level-lbs", 1); # right sump tank 300 lbs
var Lw_lvl     = props.globals.getNode("consumables/fuel/tank[6]/level-lbs", 1); # left wing tank 2000 lbs
var Rw_lvl     = props.globals.getNode("consumables/fuel/tank[7]/level-lbs", 1); # right wing tank 2000 lbs
var Le_lvl     = props.globals.getNode("consumables/fuel/tank[8]/level-lbs", 1); # left external tank 2000 lbs
var Re_lvl     = props.globals.getNode("consumables/fuel/tank[9]/level-lbs", 1); # right external tank 2000 lbs
var fwd_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[0]/level-gal_us", 1);
var aft_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[1]/level-gal_us", 1);
var Lbb_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[2]/level-gal_us", 1);
var Lsp_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[3]/level-gal_us", 1);
var Rbb_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[4]/level-gal_us", 1);
var Rsp_lvl_gal_us    = props.globals.getNode("consumables/fuel/tank[5]/level-gal_us", 1);
var Lw_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[6]/level-gal_us", 1);
var Rw_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[7]/level-gal_us", 1);
var Le_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[8]/level-gal_us", 1);
var Re_lvl_gal_us     = props.globals.getNode("consumables/fuel/tank[9]/level-gal_us", 1);
aircraft.data.add(	bingo,
					fwd_lvl, aft_lvl, Lbb_lvl, Lsp_lvl, Rbb_lvl, Rsp_lvl, Lw_lvl,
					Rw_lvl, Le_lvl, Re_lvl,
					fwd_lvl_gal_us, aft_lvl_gal_us, Lbb_lvl_gal_us, Lsp_lvl_gal_us,
					Rbb_lvl_gal_us, Rsp_lvl_gal_us, Lw_lvl_gal_us, Rw_lvl_gal_us,
					Le_lvl_gal_us, Re_lvl_gal_us,
					"sim/model/AAE-AMX/systems/external-loads/station[2]/type",
					"sim/model/AAE-AMX/systems/external-loads/station[7]/type",
					"consumables/fuel/tank[8]/selected",
					"consumables/fuel/tank[9]/selected",
					"sim/model/AAE-AMX/systems/external-loads/external-tanks",
					"sim/weight[1]/weight-lb","sim/weight[6]/weight-lb"
				);



# Accelerometer ###########
var g_curr  = props.globals.getNode("accelerations/pilot-g");
var g_max   = props.globals.getNode("sim/model/AAE-AMX/instrumentation/g-meter/g-max");
var g_min   = props.globals.getNode("sim/model/AAE-AMX/instrumentation/g-meter/g-min");
aircraft.data.add( g_min, g_max );
var GMaxMav = props.globals.getNode("sim/model/AAE-AMX/instrumentation/g-meter/g-max-mooving-average", 1);
GMaxMav.initNode(nil, 0);
var g_mva_vec     = [0,0,0,0,0];

var g_min_max = func {
	# Records g min, g max and 0.5 sec averaged max values. g_min_max(). Has to be
	# fired every 0.1 sec.
	var curr = g_curr.getValue();
	var max = g_max.getValue();
	var min = g_min.getValue();
	if ( curr >= max ) {
		g_max.setDoubleValue(curr);
	} elsif ( curr <= min ) {
		g_min.setDoubleValue(curr);
	}
	var g_max_mav = (g_mva_vec[0]+g_mva_vec[1]+g_mva_vec[2]+g_mva_vec[3]+g_mva_vec[4])/5;
	pop(g_mva_vec);
	g_mva_vec = [curr] ~ g_mva_vec;
	GMaxMav.setValue(g_max_mav);
}

# VDI #####################
var ticker = props.globals.getNode("sim/model/AAE-AMX/instrumentation/ticker", 1);
aircraft.data.add("sim/model/AAE-AMX/controls/VDI/brightness",
	"sim/model/AAE-AMX/controls/VDI/contrast",
	"sim/model/AAE-AMX/controls/VDI/on-off",
	"sim/hud/visibility[0]",
	"sim/hud/visibility[1]",
	"sim/model/AAE-AMX/controls/HSD/on-off",
	"sim/model/AAE-AMX/controls/pilots-displays/mode/aa-bt",
	"sim/model/AAE-AMX/controls/pilots-displays/mode/ag-bt",
	"sim/model/AAE-AMX/controls/pilots-displays/mode/cruise-bt",
	"sim/model/AAE-AMX/controls/pilots-displays/mode/ldg-bt",
	"sim/model/AAE-AMX/controls/pilots-displays/mode/to-bt",
	"sim/model/AAE-AMX/controls/pilots-displays/hsd-mode-nav");

var inc_ticker = func {
	# ticker used for VDI background continuous translation animation
	var tick = ticker.getValue();
	tick += 1 ;
	ticker.setDoubleValue(tick);
}

# Air Speed Indicator #####
aircraft.data.add("sim/model/AAE-AMX/instrumentation/airspeed-indicator/safe-speed-limit-bug");

# Radar Altimeter #########
aircraft.data.add("sim/model/AAE-AMX/instrumentation/radar-altimeter/limit-bug");

# Lighting ################
aircraft.data.add(
	"sim/model/AAE-AMX/controls/lighting/hook-bypass",
	"controls/lighting/instruments-norm",
	"controls/lighting/panel-norm",
	"sim/model/AAE-AMX/controls/lighting/anti-collision-switch",
	"sim/model/AAE-AMX/controls/lighting/position-flash-switch",
	"sim/model/AAE-AMX/controls/lighting/position-wing-switch");

# HSD #####################
var hsd_mode_node = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/hsd-mode-nav");


# Afterburners FX counter #
var burner = 0;
var BurnerN = props.globals.getNode("sim/model/AAE-AMX/fx/burner", 1);
BurnerN.setValue(burner);


# AFCS ####################

# Commons vars:
var Mach = props.globals.getNode("velocities/mach");
var mach = 0;

# Filters
var PitchPidPGain = props.globals.getNode("sim/model/AAE-AMX/systems/afcs/pitch-pid-pgain", 1);
var PitchPidDGain = props.globals.getNode("sim/model/AAE-AMX/systems/afcs/pitch-pid-dgain", 1);
var VsPidPGain    = props.globals.getNode("sim/model/AAE-AMX/systems/afcs/vs-pid-pgain", 1);
var pgain = 0;

var afcs_filters = func {
	var f_mach = mach + 0.01;
	var p_gain = -0.008 / ( f_mach * f_mach * f_mach * f_mach * 1.2);
	if ( p_gain < -0.04 ) p_gain = -0.04;
	var d_gain = 0.4 * ( 2.5 - ( mach * 2 ));
	PitchPidPGain.setValue(p_gain);
	PitchPidDGain.setValue(d_gain);
	VsPidPGain.setValue(p_gain/10);
}


# Drag Computation
var Drag       = props.globals.getNode("sim/model/AAE-AMX/systems/fdm/drag");
var GearPos    = props.globals.getNode("gear/gear[1]/position-norm");
var SpeedBrake = props.globals.getNode("controls/flight/speedbrake", 1);
var AB         = props.globals.getNode("engines/engine/afterburner", 1);

var sb_i = 0.2;

controls.stepSpoilers = func(s) {
	var sb = SpeedBrake.getValue();
	if ( s == 1 ) {
		sb += sb_i;
		if ( sb > 1 ) { sb = 1 }
		SpeedBrake.setValue(sb);
	} elsif ( s == -1 ) {
		sb -= sb_i;
		if ( sb < 0 ) { sb = 0 }
		SpeedBrake.setValue(sb);
	}
}

var compute_drag = func {
	var gearpos = GearPos.getValue();
	var ab = AB.getValue();
	var gear_drag = 0;
	if ( gearpos > 0.8 ) {
		gear_drag = mach * 0.5;
	}
	if ( mach <= 1 ) {
		Drag.setValue(mach);
	} elsif (mach <= 1.3) {
		Drag.setValue(((math.sin((mach * 11)-0.6) * 0.5) + 1 - ( ab * 2 )) + gear_drag );
	} else {
		Drag.setValue((math.sin((mach * 0.7)+0.25) * 1.6) - ( ab * 1.5));
	}
}


# Send basic instruments data over MP for backseaters.
var InstrString = props.globals.getNode("sim/multiplay/generic/string[1]", 1);
var InstrString2 = props.globals.getNode("sim/multiplay/generic/string[2]", 1);
var IAS = props.globals.getNode("instrumentation/airspeed-indicator/indicated-speed-kt");
var FuelTotal = props.globals.getNode("sim/model/AAE-AMX/instrumentation/fuel-gauges/total");
var TcBearing = props.globals.getNode("instrumentation/tacan/indicated-mag-bearing-deg");
var TcInRange = props.globals.getNode("instrumentation/tacan/in-range");
var TcRange = props.globals.getNode("instrumentation/tacan/indicated-distance-nm");
var RangeRadar2       = props.globals.getNode("instrumentation/radar/radar2-range");

var SteerModeAwl = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/steer/awl-bt");
var SteerModeDest = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/steer/dest-bt");
var SteerModeMan = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/steer/man-bt");
var SteerModeTcn = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/steer/tacan-bt");
var SteerModeVec = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/steer/vec-bt");
var SteerModeCode = props.globals.getNode("sim/model/AAE-AMX/controls/pilots-displays/steer-submode-code");

instruments_data_export = func {
	# Air Speed indicator.
	var ias            = sprintf( "%01.1f", IAS.getValue());
	# Mach
	var s_mach         = sprintf( "%01.1f", mach);
	# Fuel Totalizer.
	var fuel_total     = sprintf( "%01.0f", FuelTotal.getValue());
	# BDHI.
	var tc_mode        = TcModeSwitch.getValue();
	if ( TcBearing.getValue() != nil ) {
		var tc_bearing  = sprintf( "%01.1f", TcBearing.getValue());
	} else {
		var tc_bearing  = "0.00";
	}
	var tc_in_range    = TcInRange.getValue() ? 1 : 0;
	var tc_range       = sprintf( "%01.1f", TcRange.getValue());
	# Steer Submode Code
	steer_mode_code = SteerModeCode.getValue();
	# CDI
	var cdi = sprintf( "%01.2f", HsdCdiDeflection.getValue());
	var radial = VtcRadialDeg.getValue();

	var l_s = [ias, s_mach, fuel_total, tc_mode, tc_bearing, tc_in_range, tc_range, steer_mode_code, cdi, radial];
	var str = "";
	foreach( s ; l_s ) {
		str = str ~ s ~ ";";
	}

	InstrString.setValue(str);

	InstrString2.setValue(sprintf( "%01.0f", RangeRadar2.getValue()));

}


# Main loop ###############
var cnt = 0;

var main_loop = func {
	cnt += 1;
	# done each 0.05 sec.
	mach = Mach.getValue();
	awg_9.rdr_loop();
	var a = cnt / 2;

	burner +=1;
	if ( burner == 3 ) { burner = 0 }
	BurnerN.setValue(burner);

	if ( ( a ) == int( a )) {
		# done each 0.1 sec, cnt even.
		inc_ticker();
		tacan_update();
		amx_hud.update_hud();
		g_min_max();
		amx_chronograph.update_chrono();
		if (( cnt == 6 ) or ( cnt == 12 )) {
			# done each 0.3 sec.
			amx.fuel_update();
			if ( cnt == 12 ) {
				# done each 0.6 sec.
				local_mag_deviation();
				nav1_freq_update();
				cnt = 0;
			}
		}
	} else {
		# done each 0.1 sec, cnt odd.
		awg_9.hud_nearest_tgt();
		instruments_data_export();
		if (( cnt == 5 ) or ( cnt == 11 )) {
			# done each 0.3 sec.
			afcs_filters();
			compute_drag();
			#if ( cnt == 11 ) {
				# done each 0.6 sec.

			#}
		}
	}
	settimer(main_loop, UPDATE_PERIOD);
}


# Init ####################
var init = func {
	print("Initializing AAE-AMX Systems");
	aircraft.data.load();
	amx.ext_loads_init();
	amx.init_fuel_system();
	ticker.setDoubleValue(0);
	local_mag_deviation();
	tacan_switch_init();
	radardist.init();
	awg_9.init();
	an_arc_182v.init();
	an_arc_159v1.init();
	setprop("controls/switches/radar_init", 0);
	# properties to be stored
	foreach (var f_tc; TcFreqs.getChildren()) {
		aircraft.data.add(f_tc);
	}
	# launch
	settimer(main_loop, 0.5);
}

setlistener("sim/signals/fdm-initialized", init);

setlistener("sim/signals/reinit", func (reinit) {
	if (reinit.getValue()) {
		amx.internal_save_fuel();
	} else {
		settimer(func { amx.internal_restore_fuel() }, 0.6);
	}		
});

# Miscelaneous definitions and tools ############

# warning lights medium speed flasher
# -----------------------------------
aircraft.light.new("sim/model/AAE-AMX/lighting/warn-medium-lights-switch", [0.3, 0.2]);
setprop("sim/model/AAE-AMX/lighting/warn-medium-lights-switch/enabled", 1);


# Old Fashioned Radio Button Selectors
# -----------------------------------
# Where group is the parent node that contains the radio state nodes as children.

sel_displays_main_mode = func(group, which) {
	foreach (var n; props.globals.getNode(group).getChildren()) {
		n.setBoolValue(n.getName() == which);
	}
}

sel_displays_sub_mode = func(group, which) {
	foreach (var n; props.globals.getNode(group).getChildren()) {
		n.setBoolValue(n.getName() == which);
	}
	var steer_mode_code = 0;
	if ( SteerModeDest.getBoolValue() ) { steer_mode_code = 1 }
	elsif ( SteerModeMan.getBoolValue() ) { steer_mode_code = 2 }
	elsif ( SteerModeTcn.getBoolValue() ) { steer_mode_code = 3 }
	elsif ( SteerModeVec.getBoolValue() ) { steer_mode_code = 4 }
	SteerModeCode.setValue(steer_mode_code);
}





# ILS: nav[0]
# -----------
var ils_freq         = props.globals.getNode("instrumentation/nav[0]/frequencies");
var ils_freq_sel     = ils_freq.getNode("selected-mhz", 1);
var ils_freq_sel_fmt = ils_freq.getNode("selected-mhz-fmt", 1);
var ils_btn          = props.globals.getNode("sim/model/AAE-AMX/AAE-AMX-nav/selector-ils");


# update selected-mhz with translated decimals
var nav0_freq_update = func {
	var test = getprop("instrumentation/nav[0]/frequencies/selected-mhz");
	if (! test) {
		setprop("sim/model/AAE-AMX/instrumentation/nav[0]/frequencies/freq-whole", 0);
	} else {
		setprop("sim/model/AAE-AMX/instrumentation/nav[0]/frequencies/freq-whole", test * 100);
	}
}


# TACAN: nav[1]
# ------------- 
var nav1_back = 0;
setlistener( "instrumentation/tacan/switch-position", func {nav1_freq_update();} );

var tc              = props.globals.getNode("instrumentation/tacan/");
var tc_sw_pos       = tc.getNode("switch-position");
var tc_freq         = tc.getNode("frequencies");
var tc_true_hdg     = props.globals.getNode("instrumentation/tacan/indicated-bearing-true-deg");
var tc_mag_hdg      = props.globals.getNode("sim/model/AAE-AMX/instrumentation/tacan/indicated-bearing-mag-deg");
var tcn_btn         = props.globals.getNode("instrumentation/tacan/switch-position");
var heading_offset  = props.globals.getNode("instrumentation/heading-indicator-fg/offset-deg");
var tcn_ident       = props.globals.getNode("instrumentation/tacan/ident");
var vtc_ident       = props.globals.getNode("instrumentation/nav[1]/nav-id");
var from_flag       = props.globals.getNode("sim/model/AAE-AMX/instrumentation/cdi/from-flag");
var to_flag         = props.globals.getNode("sim/model/AAE-AMX/instrumentation/cdi/to-flag");
var cdi_deflection  = props.globals.getNode("sim/model/AAE-AMX/instrumentation/cdi/needle-deflection");
var vtc_from_flag   = props.globals.getNode("instrumentation/nav[1]/from-flag");
var vtc_to_flag     = props.globals.getNode("instrumentation/nav[1]/to-flag");
var vtc_deflection  = props.globals.getNode("instrumentation/nav[1]/heading-needle-deflection");
var course_radial   = props.globals.getNode("instrumentation/nav[1]/radials/selected-deg");

var tacan_offset_apply = func {
	tcn            = tcn_btn.getValue();
	var hdg_offset = heading_offset.getValue();
	var true_hdg   = tc_true_hdg.getValue();
	if ( true_hdg and ( tcn == 1) ) {
		var new_mag_hdg = hdg_offset + true_hdg;
		tc_mag_hdg.setDoubleValue( geo.normdeg( new_mag_hdg ) );
	} else {
		tc_mag_hdg.setDoubleValue( 0 );
	}
}

var nav1_freq_update = func {
	if ( tc_sw_pos.getValue() == 1 ) {
		#print("nav1_freq_updat etc_sw_pos = 1");
		var tacan_freq = getprop( "instrumentation/tacan/frequencies/selected-mhz" );
		var nav1_freq = getprop( "instrumentation/nav[1]/frequencies/selected-mhz" );
		var nav1_back = nav1_freq;
		setprop("instrumentation/nav[1]/frequencies/selected-mhz", tacan_freq);
	} else {
	setprop("instrumentation/nav[1]/frequencies/selected-mhz", nav1_back);
	}
}

var tacan_XYtoggle = func {
	var xy_sign = tc_freq.getNode("selected-channel[4]");
	var s = xy_sign.getValue();
	if ( s == "X" ) {
		xy_sign.setValue( "Y" );
	} else {
		xy_sign.setValue( "X" );
	}
}

var tacan_tenth_adjust = func {
	var tenths = getprop( "instrumentation/tacan/frequencies/selected-channel[2]" );
	var hundreds = getprop( "instrumentation/tacan/frequencies/selected-channel[1]" );
	var value = (10 * tenths) + (100 * hundreds);
	var adjust = arg[0];
	var new_value = value + adjust;
	var new_hundreds = int(new_value/100);
	var new_tenths = (new_value - (new_hundreds*100))/10;
	setprop( "instrumentation/tacan/frequencies/selected-channel[1]", new_hundreds );
	setprop( "instrumentation/tacan/frequencies/selected-channel[2]", new_tenths );
}

# TACAN on HSI's Course Deviation Indicator
# -----------------------------------------------------
# CDI works with ils OR tacan OR vortac (which freq is tuned from the tacan panel)
var compas_card_dev_indicator = func {
	var tcn = tcn_btn.getValue();
	if ( tcn ) {
		var tcnid = tcn_ident.getValue();
		var vtcid = vtc_ident.getValue();
		if ( tcnid == vtcid ) {
			# we have a VORTAC
			from_flag.setBoolValue(vtc_from_flag.getBoolValue());
			to_flag.setBoolValue(vtc_to_flag.getBoolValue());
			cdi_deflection.setValue(vtc_deflection.getValue());
		} else {
			# we have a legacy TACAN
			var tcn_toflag = 1;
			var tcn_fromflag = 0;
			var tcn_bearing = tc_mag_hdg.getValue();
			var radial = course_radial.getValue();
			var delt = tcn_bearing - radial;
			if ( delt > 180 ) {
				delt -= 360;				
			} elsif ( delt < -180 ) {
				delt += 360;				
			}
			if ( delt > 90 ) {
				delt -= 180;
				tcn_toflag = 0;
				tcn_fromflag = 1;
			} elsif ( delt < - 90 ) {
				delt += 180;
				tcn_toflag = 0;
				tcn_fromflag = 1;
			}
			if ( delt > 10 ) { delt = 10 };
			if ( delt < -10 ) { delt = -10 };
			from_flag.setBoolValue(tcn_fromflag);
			to_flag.setBoolValue(tcn_toflag);
			cdi_deflection.setValue(delt);
		}
	}
}

# AN/ARC-186: VHF voice on comm[0] and homing on nav[2]
# -----------------------------------------------------

var nav2_selected_mhz = props.globals.getNode("instrumentation/nav[2]/frequencies/selected-mhz", 1);
var comm0_selected_mhz = props.globals.getNode("instrumentation/comm[0]/frequencies/selected-mhz", 1);
var vhf = props.globals.getNode("sim/model/AAE-AMX/instrumentation/vhf");
var vhf_mode = vhf.getNode("mode");
var vhf_selector = vhf.getNode("selector");
var vhf_load_state = vhf.getNode("load-state");
var vhf_preset = vhf.getNode("selected-preset");
var vhf_presets = vhf.getNode("presets");
var vhf_fqs = vhf.getNode("frequencies");
var vhf_fqs10 = vhf_fqs.getNode("alt-selected-mhz-x10");
var vhf_fqs1 = vhf_fqs.getNode("alt-selected-mhz-x1");
var vhf_fqs01 = vhf_fqs.getNode("alt-selected-mhz-x01");
var vhf_fqs0001 = vhf_fqs.getNode("alt-selected-mhz-x0001");

aircraft.data.add(vhf_preset);

# Displays nav[2] selected-mhz on the VHF radio set.
var alt_freq_update = func {
	var freq  = nav2_selected_mhz.getValue();
	if (freq == nil) { freq = 0; }	
	var freq10 = int(freq / 10);
	var freq1 = int(freq) - (freq10 * 10);
	var resr = rounding25((freq - int(freq)) * 1000);
	var freq01 = int(resr / 100);
	var freq0001 = ((resr / 100) - freq01) * 100;
	vhf_fqs10.setValue( freq10 );
	vhf_fqs1.setValue( freq1 );
	vhf_fqs01.setValue( freq01 );
	vhf_fqs0001.setValue( freq0001 );
}

var rounding25 = func(n) {
	var a = int( n / 25 );
	var l = ( a + 0.5 ) * 25;
	n = (n >= l) ? ((a + 1) * 25) : (a * 25);
	return( n );
}


# Updates comm[0] and nav[2] selected-mhz property from the VHF dialed freq
var alt_freq_to_freq = func {
	var freq10 = vhf_fqs10.getValue();
	var freq1 = vhf_fqs1.getValue();
	var freq01 = vhf_fqs01.getValue();
	var freq0001 = vhf_fqs0001.getValue();
	var freq = ( freq10 * 10 ) + freq1 + ( freq01 / 10 ) + ( freq0001 / 1000 );
	nav2_selected_mhz.setValue( freq );
	comm0_selected_mhz.setValue( freq );
}

# Changes the selected freq on comm[0] and nav[2]
var change_preset = func {
	var presets = vhf.getNode("presets");
	var p = vhf_preset.getValue();
	if ( p == nil ) { p = 1; }
	var new_p = p + arg[0];
	if (arg[0] == 1 and new_p == 21 ) {
		new_p = 1;
	} elsif (arg[0] == -1 and new_p == 0 ) {
		new_p = 20;
	}
	vhf_preset.setValue( new_p );
	var f_data = "preset[" ~ new_p ~ "]";
	p_freq = vhf_presets.getNode(f_data);
	var f = p_freq.getValue();
	if ( f == nil ) { f = 0; }
	nav2_selected_mhz.setValue( f );
	comm0_selected_mhz.setValue( f );
	alt_freq_update();
}

# Saves displayed freq in the pressets memory
# load_state used for the load button animation
var load_freq = func {
	var mode = vhf_mode.getValue();
	var selector = vhf_selector.getValue();
	if ( mode == 1 and selector == 3 ) {
		# mode to TR, selector to MAN
		var to_load_freq = nav2_selected_mhz.getValue();
		var p = vhf_preset.getValue();
		var f = "preset[" ~ p ~ "]";
		var p_freq = vhf_presets.getNode(f);
		p_freq.setValue(to_load_freq);
		vhf_load_state.setValue(1);
		settimer(func { vhf_load_state.setValue(0) }, 0.5);
	}
}

# Init ####################
var freq_startup = func {
	## nav[0] - ILS
	nav0_freq_update();
	aircraft.data.add(ils_freq_sel);
	aircraft.data.add(ils_freq_sel_fmt);
	## nav[1] - TACAN
	foreach (var f_tc; tc_freq.getChildren()) {
		aircraft.data.add(f_tc);
	}
	## comm[0] and nav[2] - VHF
	change_preset(0);
	# add all the restored pressets to a new aircraft data file
	foreach (var p_freq; vhf_presets.getChildren()) {
		aircraft.data.add(p_freq);
	}
	## HSI
	aircraft.data.add("instrumentation/heading-indicator-fg/offset-deg",
		"instrumentation/nav[1]/radials/selected-deg");
}

# Homing deviations computing loop
var ac_hdg = props.globals.getNode("/orientation/heading-deg", 1);
var st_hdg = props.globals.getNode("instrumentation/nav[2]/heading-deg", 1);
var vhf_hdev = vhf.getNode("homing-deviation",1);

var nav2_homing_devs = func {
	var ahdg = ac_hdg.getValue();
	var shdg = st_hdg.getValue();
	if ( shdg != nil ) {
		var d = shdg - ahdg;
		while ( d > 180) d -= 360;
		while ( d < -180) d += 360;
		vhf_hdev.setDoubleValue(d);
	}
}

# Other navigation panels
# -----------------------

# AAE-AMX-nav-mode-selector panel:
# buttons indices: HARS=0, VLOCS=1, TISL=2, NAV-CRS=3, MAN=4, ILS=5, TCN=6
var nav_mode_selector = func(n) {
	if ( n == 5 ) {
		var n_state = ils_btn.getBoolValue();
		ils_btn.setBoolValue(!n_state);
		tcn_btn.setBoolValue(0);
	} elsif ( n == 6) {
		var n_state = tcn_btn.getBoolValue();
		tcn_btn.setBoolValue(!n_state);
		ils_btn.setBoolValue(0);
	}
}


