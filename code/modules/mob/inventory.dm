#define is_valid_hand_index(index) ((index > 0) && (index <= held_items.len))

//These procs handle putting s tuff in your hand. It's probably best to use these rather than setting l_hand = ...etc
//as they handle all relevant stuff like adding it to the player's screen and updating their overlays.

//Returns the thing in our active hand
/mob/proc/get_held_item_by_index(index)
	if(!is_valid_hand_index(index)) return null

	return held_items[index]

/mob/proc/find_held_item_by_type(type) //Returns the list index
	if(!held_items.len) return 0

	for(var/i = 1 to held_items.len)
		if(istype(held_items[i], type))
			return i

	return 0

/mob/proc/is_holding_item(item)
	return held_items.Find(item)

/mob/proc/find_empty_hand_index()
	for(var/i = 1 to held_items.len)
		if(!held_items[i])
			return i

	return 0

/mob/proc/empty_hand_indexes_amount()
	. = 0

	for(var/i = 1 to held_items.len) //Go through all hand slots, increase return value by 1 for each empty slot
		if(!held_items[i])
			.++

/mob/proc/get_active_hand()
	return get_held_item_by_index(active_hand)

/mob/proc/get_held_item_ui_location(index)
	if(!is_valid_hand_index(index)) return

	var/x_offset = -(index % 2) //Index is 1 -> one unit to the left
	var/y_offset = round((index-1) / 2) //Two slots per row, then go higher. Rounded down

	return "CENTER[x_offset ? x_offset : ""]:16,SOUTH[y_offset ? "+[y_offset]" : ""]:5"

	/*
	switch(index)
		if(1) return "CENTER-1:16,SOUTH:5"
		if(2)return "CENTER:16,SOUTH:5"
		if(3) return "CENTER-1:16,SOUTH+1:5"
		if(4) return "CENTER:16,SOUTH+1:5"
	*/

/mob/proc/get_direction_by_index(index)
	if(index % 2 == GRASP_RIGHT_HAND)
		return "right_hand"
	else
		return "left_hand"

/mob/proc/get_index_limb_name(var/index)
	if(!index) index = active_hand

	switch(index)
		if(GRASP_LEFT_HAND) return "left hand"
		if(GRASP_RIGHT_HAND) return "right hand"
		else return "hand"

/mob/proc/get_item_offset_by_index(index) //Return a list with x and y offsets depending on index. Example: list("x"=5, "y"=4)
	return list()

// Get the organ of the active hand
/mob/proc/get_active_hand_organ()
	if(!istype(src, /mob/living/carbon)) return
	if (hasorgans(src))
		var/datum/organ/external/temp = find_organ_by_grasp_index(active_hand)
		return temp

/mob/proc/find_organ_by_grasp_index(index)
	return

//Returns the thing in our inactive hand
/mob/proc/get_inactive_hand()
	return get_held_item_by_index(get_inactive_hand_index())

// Because there's several different places it's stored.
/mob/proc/get_multitool(var/if_active=0)
	return null

/mob/proc/get_inactive_hand_index()
	var/new_index = active_hand - 1

	if(new_index < 1)
		new_index = held_items.len

	return new_index

/mob/proc/swap_hand()
	if(++active_hand > held_items.len)
		active_hand = 1

	if(!hud_used) return

	for(var/obj/screen/inventory/hand_hud_object in hud_used.hand_hud_objects)
		if(active_hand == hand_hud_object.hand_index)
			hand_hud_object.icon_state = "hand_active"
		else
			hand_hud_object.icon_state = "hand_inactive"

	return

/mob/proc/activate_hand(var/selhand)
	active_hand = selhand

	if(!hud_used) return

	for(var/obj/screen/inventory/hand_hud_object in hud_used.hand_hud_objects)
		if(active_hand == hand_hud_object.hand_index)
			hand_hud_object.icon_state = "hand_active"
		else
			hand_hud_object.icon_state = "hand_inactive"

/mob/proc/put_in_hand(index, obj/item/W)
	if(!is_valid_hand_index(index) || !is_valid_hand_index(active_hand))
		return 0

	if(!put_in_hand_check(W, index))
		return 0

	if(!held_items[index])
		if(W.prepickup(src))
			return 0
		W.loc = src
		held_items[index] = W
		W.layer = 20
		W.pixel_x = initial(W.pixel_x)
		W.pixel_y = initial(W.pixel_y)
		W.equipped(src, null, index)

		if(client)	client.screen |= W
		if(pulling == W) stop_pulling()

		update_inv_hand(index)
		W.pickup(src)
		return 1

//Puts the item into your left hand if possible and calls all necessary triggers/updates. returns 1 on success.
/mob/proc/put_in_l_hand(var/obj/item/W)
	return put_in_hand(GRASP_LEFT_HAND, W)

//Puts the item into your right hand if possible and calls all necessary triggers/updates. returns 1 on success.
/mob/proc/put_in_r_hand(var/obj/item/W)
	return put_in_hand(GRASP_RIGHT_HAND, W)

/mob/proc/put_in_hand_check(var/obj/item/W)
	if(lying) //&& !(W.flags & ABSTRACT))
		return 0

	if(!isitem(W))
		return 0

	if(W.flags & MUSTTWOHAND)
		if(!W.wield(src, 1))
			to_chat(src, "You need both hands to pick up \the [W].")
			return 0

	return 1

//Puts the item into our active hand if possible. returns 1 on success.
/mob/proc/put_in_active_hand(var/obj/item/W)
	return put_in_hand(active_hand, W)

//Puts the item into our inactive hand if possible. returns 1 on success.
/mob/proc/put_in_inactive_hand(var/obj/item/W)
	return put_in_hand(get_inactive_hand_index(), W)

//Puts the item our active hand if possible. Failing that it tries our inactive hand. Returns 1 on success.
//If both fail it drops it on the floor and returns 0.
//This is probably the main one you need to know :)
/mob/proc/put_in_hands(var/obj/item/W)
	if(!W)		return 0
	if(put_in_active_hand(W))
		return 1
	else if(put_in_inactive_hand(W))
		return 1
	else
		W.loc = get_turf(src)
		W.layer = initial(W.layer)
		W.dropped()
		return 0

/mob/proc/set_hand_amount(new_amount)
	if(new_amount < held_items.len) //Decrease hand amount - drop items held in hands which will no longer exist!
		for(var/i = (new_amount+1) to held_items.len)
			var/obj/item/I = held_items[i]

			if(I)
				drop_item(I, force_drop = 1)
	if(new_amount < active_hand)
		active_hand = new_amount //Don't update the HUD - it'll be redrawn anyways

	held_items.len = new_amount

	if(hud_used)
		hud_used.update_hand_icons()

/mob/proc/drop_item_v()		//this is dumb.
	if(stat == CONSCIOUS && isturf(loc))
		return drop_item()
	return 0


/mob/proc/drop_from_inventory(var/obj/item/W)
	if(W)
		if(client)	client.screen -= W
		u_equip(W,1)
		if(!W) return 1 // self destroying objects (tk, grabs)
		W.layer = initial(W.layer)
		W.forceMove(loc)

		//W.dropped(src)
		//update_icons() // Redundant as u_equip will handle updating the specific overlay
		return 1
	return 0

// Drops all and only equipped items, including items in hand
/mob/proc/drop_all()
	for (var/obj/item/I in get_all_slots())
		drop_from_inventory(I)


//Drops the item in our hand - you can specify an item and a location to drop to

/mob/proc/drop_item(var/obj/item/to_drop, var/atom/Target, force_drop = 0) //Set force_drop to 1 to force the item to drop (even if it can't be dropped normally)

	if(!candrop) //can't drop items while etheral
		return 0

	if(!to_drop) //if we're not told to drop something specific
		to_drop = get_active_hand() //drop what we're currently holding

	if(!istype(to_drop)) //still nothing to drop?
		return 0 //bail

	if((to_drop.cant_drop > 0) && !force_drop)
		return 0

	if(!Target)
		Target = src.loc

	remove_from_mob(to_drop) //clean out any refs

	if(!to_drop)
		return 0

	to_drop.forceMove(Target) //calls the Entered procs
	if(ismob(Target))
		var/mob/M = Target
		if(iscarbon(M))
			var/mob/living/carbon/C = M
			C.stomach_contents.Add(to_drop)

	to_drop.dropped(src)

	if(to_drop && to_drop.loc)
		return 1
	return 0

/mob/proc/drop_hands(var/atom/Target, force_drop = 0) //drops both items
	for(var/obj/item/I in held_items)
		drop_item(I, Target, force_drop = force_drop)

//TODO: phase out this proc
/mob/proc/before_take_item(var/obj/item/W)	//TODO: what is this?
	W.loc = null
	W.layer = initial(W.layer)
	u_equip(W,0)
	update_icons()
	return


/mob/proc/u_equip(var/obj/item/W as obj, dropped = 1)
	if(!W) return 0
	var/success = 0

	var/index = is_holding_item(W)
	if(index)
		held_items[index] = null
		success = 1
		update_inv_hand(index)
	else if (W == back)
		back = null
		success = 1
		update_inv_back()
	else if (W == wear_mask)
		wear_mask = null
		success = 1
		update_inv_wear_mask()
	else
		return 0

	if(success)
		if(client)
			client.screen -= W
		if(dropped)
			W.loc = loc
			W.dropped(src)
		if(W)
			W.layer = initial(W.layer)
	return 1


//Attemps to remove an object on a mob.  Will not move it to another area or such, just removes from the mob.
/mob/proc/remove_from_mob(var/obj/O)
	src.u_equip(O,1)
	if (src.client)
		src.client.screen -= O
	if(!O) return
	O.layer = initial(O.layer)
	O.screen_loc = null
	return 1

/mob/proc/get_all_slots()
	return list(wear_mask, back) + held_items

//everything on the mob that it isn't holding
/mob/proc/get_equipped_items()
	var/list/equipped = get_all_slots()
	equipped -= list(get_active_hand(), get_inactive_hand())
	return equipped

//everything on the mob that is not in its pockets, hands and belt.
/mob/proc/get_clothing_items()
	var/list/equipped = get_all_slots()
	equipped -= list(get_active_hand(), get_inactive_hand())
	return equipped

/mob/living/carbon/human/proc/equip_if_possible(obj/item/W, slot, act_on_fail = EQUIP_FAILACTION_DELETE) // since byond doesn't seem to have pointers, this seems like the best way to do this :/
	//warning: icky code
	var/equipped = 0
	switch(slot)
		if(slot_back)
			if(!src.back)
				src.back = W
				equipped = 1
		if(slot_wear_mask)
			if(!src.wear_mask)
				src.wear_mask = W
				equipped = 1
		if(slot_handcuffed)
			if(!src.handcuffed)
				src.handcuffed = W
				equipped = 1
		if(slot_belt)
			if(!src.belt && src.w_uniform)
				src.belt = W
				equipped = 1
		if(slot_wear_id)
			if(!src.wear_id && src.w_uniform)
				src.wear_id = W
				equipped = 1
		if(slot_ears)
			if(!src.ears)
				src.ears = W
				equipped = 1
		if(slot_glasses)
			if(!src.glasses)
				src.glasses = W
				equipped = 1
		if(slot_gloves)
			if(!src.gloves)
				src.gloves = W
				equipped = 1
		if(slot_head)
			if(!src.head)
				src.head = W
				equipped = 1
		if(slot_shoes)
			if(!src.shoes)
				src.shoes = W
				equipped = 1
		if(slot_wear_suit)
			if(!src.wear_suit)
				src.wear_suit = W
				equipped = 1
		if(slot_w_uniform)
			if(!src.w_uniform)
				src.w_uniform = W
				equipped = 1
		if(slot_l_store)
			if(!src.l_store && src.w_uniform)
				src.l_store = W
				equipped = 1
		if(slot_r_store)
			if(!src.r_store && src.w_uniform)
				src.r_store = W
				equipped = 1
		if(slot_s_store)
			if(!src.s_store && src.wear_suit)
				src.s_store = W
				equipped = 1
		if(slot_in_backpack)
			if (src.back && istype(src.back, /obj/item/weapon/storage/backpack))
				var/obj/item/weapon/storage/backpack/B = src.back
				if(B.contents.len < B.storage_slots && W.w_class <= B.fits_max_w_class)
					W.loc = B
					equipped = 1

	if(equipped)
		W.layer = 20
		if(src.back && W.loc != src.back)
			W.loc = src
	else
		switch(act_on_fail)
			if(EQUIP_FAILACTION_DELETE)
				qdel(W)
				W = null
			if(EQUIP_FAILACTION_DROP)
				W.loc=get_turf(src) // I think.
	return equipped

/mob/proc/get_id_card()
	for(var/obj/item/I in src.get_all_slots())
		. = I.GetID()
		if(.)
			break
