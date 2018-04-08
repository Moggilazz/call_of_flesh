var/datum/subsystem/lighting/SSlighting

#define MC_AVERAGE(average, current) (0.8*(average) + 0.2*(current))

/datum/subsystem/lighting
	name = "Lighting"
	priority = 1
	wait = 5
	dynamic_wait = 1
	dwait_delta = 3
	//display = 5
	name = "lighting"
	//schedule_interval = LIGHTING_INTERVAL
	var/last_light_count = 0
	var/last_overlay_count = 0
	var/list/changed_lights = list()		//list of all datum/light_source that need updating
	var/changed_lights_workload = 0			//stats on the largest number of lights (max changed_lights.len)
	var/list/changed_turfs = list()			//list of all turfs which may have a different light level
	var/changed_turfs_workload = 0			//stats on the largest number of turfs changed (max changed_turfs.len)


/datum/subsystem/lighting/New()
	NEW_SS_GLOBAL(SSlighting)

	return ..()


/datum/subsystem/lighting/stat_entry()
	..("L:[round(changed_lights_workload,1)]|T:[round(changed_turfs_workload,1)]")


//Workhorse of lighting. It cycles through each light that needs updating. It updates their
//effects and then processes every turf in the queue, updating their lighting object's appearance
//Any light that returns 1 in check() deletes itself
//By using queues we are ensuring we don't perform more updates than are necessary
/datum/subsystem/lighting/fire()
	var/list/lighting_update_lights_old = lighting_update_lights //We use a different list so any additions to the update lists during a delay from //SCHECK don't cause things to be cut from the list without being updated.
	last_light_count = lighting_update_lights.len
	lighting_update_lights = null //Nulling it first because of http://www.byond.com/forum/?post=1854520
	lighting_update_lights = list()

	for(var/datum/light_source/L in lighting_update_lights_old)
		if(L.destroyed || L.check() || L.force_update)
			L.remove_lum()
			if(!L.destroyed)
				L.apply_lum()

		else if(L.vis_update)	//We smartly update only tiles that became (in) visible to use.
			L.smart_vis_update()

		L.vis_update = 0
		L.force_update = 0
		L.needs_update = 0

		//SCHECK

	var/list/lighting_update_overlays_old = lighting_update_overlays //Same as above.
	last_overlay_count = lighting_update_overlays.len
	lighting_update_overlays = null //Same as above
	lighting_update_overlays = list()

	for(var/atom/movable/lighting_overlay/O in lighting_update_overlays_old)
		O.update_overlay()
		O.needs_update = 0

		//SCHECK

//same as above except it attempts to shift ALL turfs in the world regardless of lighting_changed status
//Does not loop. Should be run prior to process() being called for the first time.
//Note: if we get additional z-levels at runtime (e.g. if the gateway thin ever gets finished) we can initialize specific
//z-levels with the z_level argument
/datum/subsystem/lighting/Initialize(timeofday, z_level)
	for(var/area/A in world)
		if (A.lighting_use_dynamic == DYNAMIC_LIGHTING_IFSTARLIGHT)
			if (config.starlight)
				A.SetDynamicLighting()



	for(var/thing in changed_lights)
		var/datum/light_source/LS = thing
		LS.check()
	changed_lights.Cut()

	var/z_start = 1
	var/z_finish = world.maxz
	if(z_level >= 1 && z_level <= world.maxz)
		z_level = round(z_level)
		z_start = z_level
		z_finish = z_level

	var/list/turfs_to_init = block(locate(1, 1, z_start), locate(world.maxx, world.maxy, z_finish))

	for(var/thing in turfs_to_init)
		var/turf/T = thing
		T.init_lighting()

	if(z_level)
		//we need to loop through to clear only shifted turfs from the list. or we will cause errors
		for(var/thing in changed_turfs)
			var/turf/T = thing
			if(T.z in z_start to z_finish)
				continue
			changed_turfs.Remove(thing)
	else
		changed_turfs.Cut()
	create_lighting_overlays()
	spawn(5)
		fire()
	..()

//Used to strip valid information from an existing instance and transfer it to the replacement. i.e. when a crash occurs
//It works by using spawn(-1) to transfer the data, if there is a runtime the data does not get transfered but the loop
//does not crash
/*
/datum/subsystem/lighting/Recover()
	if(!istype(SSlighting.changed_turfs))
		SSlighting.changed_turfs = list()
	if(!istype(SSlighting.changed_lights))
		SSlighting.changed_lights = list()

	for(var/thing in SSlighting.changed_lights)
		var/datum/light_source/LS = thing
		spawn(-1)			//so we don't crash the loop (inefficient)
			LS.check()

	for(var/thing in changed_turfs)
		var/turf/T = thing
		if(T.lighting_changed)
			spawn(-1)
				T.update_light()

	var/msg = "## DEBUG: [time2text(world.timeofday)] [name] subsystem restarted. Reports:\n"
	for(var/varname in SSlighting.vars)
		switch(varname)
			if("tag","bestF","type","parent_type","vars")	continue
			else
				var/varval1 = SSlighting.vars[varname]
				var/varval2 = vars[varname]
				if(istype(varval1,/list))
					varval1 = "/list([length(varval1)])"
					varval2 = "/list([length(varval2)])"
				msg += "\t [varname] = [varval1] -> [varval2]\n"
	world.log << msg
*/