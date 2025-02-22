local tmp_vec1 = Vector3()

function CopLogicIdle._turn_by_spin(data, my_data, spin)
	local diff_index = tweak_data:difficulty_to_index(Global.game_settings.difficulty)
	local mook_units = {
		"security",
		"security_undominatable",
		"cop",
		"cop_scared",
		"cop_female",
		"gensec",
		"fbi",
		"swat",
		"heavy_swat",
		"fbi_swat",
		"fbi_heavy_swat",
		"city_swat",
		"gangster",
		"biker",
		"mobster",
		"bolivian",
		"bolivian_indoors",
		"medic",
		"taser",
		"deathvox_guard",
		"deathvox_heavyar",
		"deathvox_heavyshot",
		"deathvox_lightar",
		"deathvox_lightshot",
		"deathvox_medic",
		"deathvox_shield",
		"deathvox_taser",
		"deathvox_cloaker",
		"deathvox_sniper_assault",
		"deathvox_greendozer",
		"deathvox_blackdozer",
		"deathvox_lmgdozer",
		"deathvox_medicdozer",
		"deathvox_grenadier"
	}
	local is_mook = nil
	for _, name in ipairs(mook_units) do
		if data.unit:base()._tweak_table == name then
			is_mook = true
		end
	end
	
	local speed = nil
	
	if data.is_converted or data.unit:in_slot(16) or data.unit:base()._tweak_table == "sniper" then
		speed = 2.5
	elseif diff_index == 8 and is_mook then
		speed = 1.75
	elseif diff_index == 6 and is_mook or diff_index == 7 and is_mook then
		speed = 1.5
	elseif diff_index <= 5 and is_mook then
		speed = 1.25
	else
		speed = 1
	end
	
	local new_action_data = {
		body_part = 2,
		type = "turn",
		angle = spin,
		speed = speed or 1
	}
	
	my_data.turning = data.unit:brain():action_request(new_action_data)

	if my_data.turning then
		return true
	end
end

function CopLogicIdle._get_priority_attention(data, attention_objects, reaction_func)
	reaction_func = reaction_func or CopLogicIdle._chk_reaction_to_attention_object
	local best_target, best_target_priority_slot, best_target_priority, best_target_reaction = nil
	local forced_attention_data = managers.groupai:state():force_attention_data(data.unit)

	if forced_attention_data then
		if data.attention_obj and data.attention_obj.unit == forced_attention_data.unit then
			return data.attention_obj, 1, AIAttentionObject.REACT_SHOOT
		end

		local forced_attention_object = managers.groupai:state():get_AI_attention_object_by_unit(forced_attention_data.unit)

		if forced_attention_object then
			for u_key, attention_info in pairs(forced_attention_object) do
				if not forced_attention_data.ignore_vis_blockers then
					local vis_ray = World:raycast("ray", data.unit:movement():m_head_pos(), attention_info.handler:get_detection_m_pos(), "slot_mask", data.visibility_slotmask, "ray_type", "ai_vision")

					if not vis_ray or vis_ray.unit:key() == u_key or not vis_ray.unit:visible() then
						best_target = CopLogicBase._create_detected_attention_object_data(data.t, data.unit, u_key, attention_info, attention_info.handler:get_attention(data.SO_access), true)
						best_target.verified = true
					end
				else
					best_target = CopLogicBase._create_detected_attention_object_data(data.t, data.unit, u_key, attention_info, attention_info.handler:get_attention(data.SO_access), true)
				end
			end
		else
			Application:error("[CopLogicIdle._get_priority_attention] No attention object available for unit", inspect(forced_attention_data))
		end

		if best_target then
			return best_target, 1, AIAttentionObject.REACT_SHOOT
		end
	end
	
	local has_assault_reaction_target = nil

	for u_key, attention_data in pairs(attention_objects) do
		local att_unit = attention_data.unit
		local crim_record = attention_data.criminal_record

		if not attention_data.identified then
			-- Nothing
		elseif attention_data.pause_expire_t then
			if attention_data.pause_expire_t < data.t then
				if not attention_data.settings.attract_chance or math.random() < attention_data.settings.attract_chance then
					attention_data.pause_expire_t = nil
				else
					debug_pause_unit(data.unit, "[ CopLogicIdle._get_priority_attention] skipping attraction")

					attention_data.pause_expire_t = data.t + math.lerp(attention_data.settings.pause[1], attention_data.settings.pause[2], math.random())
				end
			end
		elseif attention_data.stare_expire_t and attention_data.stare_expire_t < data.t then
			if attention_data.settings.pause then
				attention_data.stare_expire_t = nil
				attention_data.pause_expire_t = data.t + math.lerp(attention_data.settings.pause[1], attention_data.settings.pause[2], math.random())
			end
		else
			local distance = attention_data.dis
			local reaction = reaction_func(data, attention_data, not CopLogicAttack._can_move(data))

			if data.cool and AIAttentionObject.REACT_SCARED <= reaction then
				data.unit:movement():set_cool(false, managers.groupai:state().analyse_giveaway(data.unit:base()._tweak_table, att_unit))
			end

			local reaction_too_mild = nil
			
			if not reaction or best_target_reaction and reaction < best_target_reaction then
				reaction_too_mild = true
			elseif distance < 150 and reaction == AIAttentionObject.REACT_IDLE then
				reaction_too_mild = true
			end

			if not reaction_too_mild then
				local alert_dt = attention_data.alert_t and data.t - attention_data.alert_t or 10000
				local dmg_dt = attention_data.dmg_t and data.t - attention_data.dmg_t or 10000
				local status = crim_record and crim_record.status
				local nr_enemies = crim_record and crim_record.engaged_force

				local weight_mul = attention_data.settings.weight_mul

				if attention_data.is_local_player then
					if not att_unit:movement():current_state()._moving and att_unit:movement():current_state():ducking() then
						weight_mul = (weight_mul or 1) * managers.player:upgrade_value("player", "stand_still_crouch_camouflage_bonus", 1)
					end

					if managers.player:has_activate_temporary_upgrade("temporary", "chico_injector") and managers.player:upgrade_value("player", "chico_preferred_target", false) then
						weight_mul = (weight_mul or 1) * 1000
					end

					if _G.IS_VR and tweak_data.vr.long_range_damage_reduction_distance[1] < distance then
						local mul = math.clamp(distance / tweak_data.vr.long_range_damage_reduction_distance[2] / 2, 0, 1) + 1
						weight_mul = (weight_mul or 1) * mul
					end
				elseif att_unit:base() and att_unit:base().upgrade_value then
					if att_unit:movement() and not att_unit:movement()._move_data and att_unit:movement()._pose_code and att_unit:movement()._pose_code == 2 then
						weight_mul = (weight_mul or 1) * (att_unit:base():upgrade_value("player", "stand_still_crouch_camouflage_bonus") or 1)
					end

					if att_unit:base().has_activate_temporary_upgrade and att_unit:base():has_activate_temporary_upgrade("temporary", "chico_injector") and att_unit:base():upgrade_value("player", "chico_preferred_target") then
						weight_mul = (weight_mul or 1) * 1000
					end

					if att_unit:movement().is_vr and att_unit:movement():is_vr() and tweak_data.vr.long_range_damage_reduction_distance[1] < distance then
						local mul = math.clamp(distance / tweak_data.vr.long_range_damage_reduction_distance[2] / 2, 0, 1) + 1
						weight_mul = (weight_mul or 1) * mul
					end
				end

				if weight_mul and weight_mul ~= 1 then
					weight_mul = 1 / weight_mul
					alert_dt = alert_dt and alert_dt * weight_mul
					dmg_dt = dmg_dt and dmg_dt * weight_mul
					distance = distance * weight_mul
				end
				
				local diff_index = tweak_data:difficulty_to_index(Global.game_settings.difficulty)
				local near_threshold = data.internal_data.weapon_range and data.internal_data.weapon_range.optimal or 1500
				local too_close_threshold = data.internal_data.weapon_range and data.internal_data.weapon_range.close or 250
				local assault_reaction = reaction == AIAttentionObject.REACT_SPECIAL_ATTACK
				local visible = attention_data.verified or attention_data.nearly_visible
				local near = distance < near_threshold
				local too_near = distance < too_close_threshold and math.abs(attention_data.m_pos.z - data.m_pos.z) < 250
				local free_status = status == "electrified" or status == nil
				local has_damaged = dmg_dt < 5
				local reviving = nil
				local focus_enemy = attention_data
				local human_chk = attention_data.is_husk_player or attention_data.is_local_player
				local human_current_target_chk = data.attention_obj and data.attention_obj.is_husk_player or data.attention_obj and data.attention_obj.is_local_player
				local old_enemy = nil
				local old_enemy_murder = nil
				
				if not data.unit:in_slot(16) and focus_enemy and focus_enemy.is_local_player or not data.unit:in_slot(16) and focus_enemy and focus_enemy.is_husk_player then
					local anim_data = att_unit:anim_data()
					if focus_enemy.is_local_player then
						local e_movement_state = att_unit:movement():current_state()

						if e_movement_state:_is_reloading() or e_movement_state:_interacting() or e_movement_state:is_equipping() then
							pantsdownchk = true
							--log("MURDER TIME, WOO")
						end
					else
						local e_anim_data = att_unit:anim_data()

						if not (e_anim_data.move or e_anim_data.idle) or e_anim_data.reload then
							pantsdownchk = true
							--log("MURDER TIME, WOO")
						end
					end
				end
				
				if data.tactics and data.tactics.tunnel then
					if attention_data.acquire_t and human_chk and attention_data.verified and data.attention_obj and data.attention_obj.verified and AIAttentionObject.REACT_AIM <= data.attention_obj.reaction and AIAttentionObject.REACT_AIM <= reaction and data.attention_obj.u_key == u_key and human_att_obj_chk and free_status then
						old_enemy_tunnel = true
					end
				end
				
				if attention_data.acquire_t and attention_data.verified and data.attention_obj and data.attention_obj.verified and AIAttentionObject.REACT_COMBAT <= data.attention_obj.reaction and AIAttentionObject.REACT_COMBAT <= reaction and data.attention_obj.u_key == u_key then
					old_enemy = true
				end

				local target_priority = distance
				local target_priority_slot = nil
				
				if visible then
					local justtunnel = data.tactics and data.tactics.tunnel
					local justharass = data.tactics and data.tactics.harass
					local aimed_at = CopLogicIdle.chk_am_i_aimed_at(data, attention_data, attention_data.aimed_at and 0.95 or 0.985)
					attention_data.aimed_at = aimed_at
					
					if distance < 250 then
						target_priority_slot = 1
					elseif too_near then
						target_priority_slot = 2
					elseif near then
						target_priority_slot = 4
					else
						target_priority_slot = 6
					end
					
					if justtunnel and human_chk and not human_current_target_chk then
						target_priority_slot = 1
					end

					if has_damaged then
						target_priority_slot = target_priority_slot - 2
					end
					
					if attention_data.aimed_at then
						target_priority_slot = target_priority_slot - 1
					end
					
					if old_enemy and not justtunnel then
						target_priority_slot = target_priority_slot - 1
					end
					
					if not justtunnel and nr_enemies then
						if nr_enemies < 4 then
							target_priority_slot = target_priority_slot - 1
						elseif nr_enemies > 17 then
							target_priority_slot = target_priority_slot + 4
						elseif nr_enemies > 13 then
							target_priority_slot = target_priority_slot + 3
						elseif nr_enemies > 8 then
							target_priority_slot = target_priority_slot + 2
						elseif nr_enemies > 4 then
							target_priority_slot = target_priority_slot + 1
						end
					end
					
					if diff_index > 5 and status and status == "electrified" then
						target_priority_slot = target_priority_slot - 2
					elseif not free_status and not justtunnel or pantsdownchk and not justharass then
						target_priority_slot = target_priority_slot + 4
					end
					
					target_priority_slot = math.clamp(target_priority_slot, 1, 10)
				else
					target_priority_slot = 10
					if not free_status and not justtunnel or pantsdownchk and not justharass then
						target_priority_slot = target_priority_slot + 10
					end
				end
				
				if visible then
					
					if old_enemy_tunnel and data.tactics and data.tactics.tunnel then
						target_priority_slot = 1
					end
					
					if data.tactics and data.tactics.harass and pantsdownchk then
						target_priority_slot = 1
					end
						
					if assault_reaction then
						has_assault_reaction_target = true
					end
					
				end

				if AIAttentionObject.REACT_COMBAT > reaction or data.tactics and data.tactics.tunnel and not old_enemy_tunnel and not human_chk or not assault_reaction and has_assault_reaction_target then
					target_priority_slot = 20 + target_priority_slot + math.max(0, AIAttentionObject.REACT_COMBAT - reaction)
				end

				if target_priority_slot then
					local best = false

					if not best_target then
						best = true
					elseif target_priority_slot < best_target_priority_slot then
						best = true
					elseif target_priority_slot == best_target_priority_slot and target_priority < best_target_priority then
						best = true
					end

					if best then
						best_target = attention_data
						best_target_reaction = reaction
						best_target_priority_slot = target_priority_slot
						best_target_priority = target_priority
					end
				end
			end
		end
	end

	return best_target, best_target_priority_slot, best_target_reaction
end

function CopLogicIdle.on_alert(data, alert_data)
	local alert_type = alert_data[1]
	local alert_unit = alert_data[5]

	if CopLogicBase._chk_alert_obstructed(data.unit:movement():m_head_pos(), alert_data) then
		return
	end

	local was_cool = data.cool

	if CopLogicBase.is_alert_aggressive(alert_type) then
		data.unit:movement():set_cool(false, managers.groupai:state().analyse_giveaway(data.unit:base()._tweak_table, alert_data[5], alert_data))
	end
	
	local was_cool_alert_chk = alert_type == "footstep" or alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" or alert_type == "vo_cbt" or alert_type == "vo_intimidate" or alert_type == "vo_distress"
	
	if alert_unit and alive(alert_unit) and alert_unit:in_slot(data.enemy_slotmask) then
		local att_obj_data, is_new = CopLogicBase.identify_attention_obj_instant(data, alert_unit:key())

		if not att_obj_data then
			return
		end

		if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
			att_obj_data.alert_t = TimerManager:game():time()
		end

		local action_data = nil

		--if is_new and (not data.char_tweak.allowed_poses or data.char_tweak.allowed_poses.stand) and AIAttentionObject.REACT_SURPRISED <= att_obj_data.reaction and data.unit:anim_data().idle and not data.unit:movement():chk_action_forbidden("walk") then
		--	action_data = {
		--		variant = "surprised",
		--		body_part = 1,
		--		type = "act"
		--	}

		--	data.unit:brain():action_request(action_data)
		--end

		--if not action_data and alert_type == "bullet" and data.logic.should_duck_on_alert(data, alert_data) then
			--action_data = CopLogicAttack._chk_request_action_crouch(data)
		--end

		if att_obj_data.criminal_record then
			managers.groupai:state():criminal_spotted(alert_unit)

			if alert_type == "bullet" or alert_type == "aggression" or alert_type == "explosion" then
				managers.groupai:state():report_aggression(alert_unit)
			end
		end
	elseif was_cool and was_cool_alert_chk then
		local attention_obj = alert_unit and alert_unit:brain() and alert_unit:brain()._logic_data.attention_obj

		if attention_obj then
			slot6, slot7 = CopLogicBase.identify_attention_obj_instant(data, attention_obj.u_key)
		end
	end
end

function CopLogicIdle.damage_clbk(data, damage_info)
	local enemy = damage_info.attacker_unit
	local enemy_data = nil
	data.t = TimerManager:game():time()
	if enemy and enemy:in_slot(data.enemy_slotmask) then
		local my_data = data.internal_data
		local enemy_key = enemy:key()
		enemy_data = data.detected_attention_objects[enemy_key]
		local t = data.t

		if enemy_data then

			enemy_data.dmg_t = t
			enemy_data.alert_t = t
			enemy_data.notice_delay = nil

			if not enemy_data.identified then
				enemy_data.identified = true
				enemy_data.identified_t = t
				enemy_data.notice_progress = nil
				enemy_data.prev_notice_chk_t = nil

				if enemy_data.settings.notice_clbk then
					enemy_data.settings.notice_clbk(data.unit, true)
				end

				data.logic.on_attention_obj_identified(data, enemy_key, enemy_data)
			end
		else
			local attention_info = managers.groupai:state():get_AI_attention_objects_by_filter(data.SO_access_str)[enemy_key]

			if attention_info then
				local settings = attention_info.handler:get_attention(data.SO_access, nil, nil, data.team)

				if settings then
					enemy_data = CopLogicBase._create_detected_attention_object_data(data.t, data.unit, enemy_key, attention_info, settings)
					enemy_data.dmg_t = t
					enemy_data.alert_t = t
					enemy_data.identified = true
					enemy_data.identified_t = t
					enemy_data.notice_progress = nil
					enemy_data.prev_notice_chk_t = nil

					if enemy_data.settings.notice_clbk then
						enemy_data.settings.notice_clbk(data.unit, true)
					end

					data.detected_attention_objects[enemy_key] = enemy_data

					data.logic.on_attention_obj_identified(data, enemy_key, enemy_data)
				end
			end
		end
	end

	if enemy_data and enemy_data.criminal_record then
		managers.groupai:state():criminal_spotted(enemy)
		managers.groupai:state():report_aggression(enemy)
	end
end

function CopLogicIdle._chk_relocate(data)
	local my_nav_seg = data.unit:movement():nav_tracker():nav_segment()
	local my_area = managers.groupai:state():get_area_from_nav_seg_id(data.unit:movement():nav_tracker():nav_segment())
	
	if data.objective and data.objective.type == "follow" then
		if data.is_converted then
			if TeamAILogicIdle._check_should_relocate(data, data.internal_data, data.objective) then
				data.objective.in_place = nil

				if data.name ~= "travel" then
					data.logic._exit(data.unit, "travel")
				end

				return true
			end

			return
		end

		if data.is_tied and data.objective.lose_track_dis and data.objective.lose_track_dis * data.objective.lose_track_dis < mvector3.distance_sq(data.m_pos, data.objective.follow_unit:movement():m_pos()) then
			data.brain:set_objective(nil)

			return true
		end

		local relocate = nil
		local follow_unit = data.objective.follow_unit
		local advance_pos = follow_unit:brain() and follow_unit:brain():is_advancing()
		local follow_unit_pos = advance_pos or follow_unit:movement():m_pos()

		--if data.objective.relocated_to and mvector3.equal(data.objective.relocated_to, follow_unit_pos) then
		--	return
		--end

		if 240 < mvector3.distance(data.m_pos, follow_unit_pos) then
			relocate = true
		end

		if not relocate then
			if data.unit:raycast("ray", data.unit:movement():m_head_pos(), follow_unit:movement():m_head_pos(), "slot_mask", managers.slot:get_mask("world_geometry", "vehicles", "enemy_shield_check"), "ignore_unit", follow_unit, "report") then
				relocate = true
			end
			
		end

		if relocate then
			data.objective.in_place = nil
			data.objective.nav_seg = follow_unit:movement():nav_tracker():nav_segment()
			data.objective.relocated_to = mvector3.copy(follow_unit_pos)

			if data.name ~= "travel" then
				data.logic._exit(data.unit, "travel")
			end

			return true
		end
	elseif data.objective and data.objective.type == "defend_area" or data.objective and data.objective.type == "hunt" then
		if not CopLogicAttack.is_available_for_assignment(data, data.objective) then
			return
		end
		
		local recon_group = data.objective and data.objective.grp_objective and data.objective.grp_objective.type == "recon_area"
		
		local current_assault_target_area = managers.groupai:state()._task_data.assault.target_areas and managers.groupai:state()._task_data.assault.target_areas[math.random(#managers.groupai:state()._task_data.assault.target_areas)] or nil
		
		if managers.groupai:state():chk_assault_active_atm() and not recon_group then
			local area = data.objective.area

			if area and not next(area.criminal.units) then
			
				if current_assault_target_area and area ~= current_assault_target_area and next(current_assault_target_area.criminal.units) then -- this code is so awful i am fully convinced it is self-aware
					--log("pog")
					data.objective.in_place = nil
					data.objective.area = current_assault_target_area
					data.objective.nav_seg = next(current_assault_target_area.nav_segs)
					data.objective.path_data = {
						{
							data.objective.nav_seg
						}
					}
					
					if data.name ~= "travel" then
						data.logic._exit(data.unit, "travel")
					end
					
					--log("im going")
						
					return true
				end
			
				local found_areas = {
					[area] = true
				}
				local areas_to_search = {
					area
				}
				local target_area = nil

				while next(areas_to_search) do
					local current_area = table.remove(areas_to_search)
						
					if next(current_area.criminal.units) then
						target_area = current_area

						break
					end

					for _, n_area in pairs(current_area.neighbours) do
						if not found_areas[n_area] then
							found_areas[n_area] = true

							table.insert(areas_to_search, n_area)
						end
					end
				end

				if target_area then
					data.objective.in_place = nil
					data.objective.area = target_area
					data.objective.nav_seg = next(target_area.nav_segs)
					data.objective.path_data = {
						{
							data.objective.nav_seg
						}
					}
					
					if data.name ~= "travel" then
						data.logic._exit(data.unit, "travel")
					end

					return true
				end
			end
		else
			local area = data.objective.area
			
			if area then
				if area.loot and next(area.loot) or area.hostages and next(area.hostages) or current_assault_target_area and area == current_assault_target_area then
					return
				else
					local found_areas = {
						[area] = true
					}
					local areas_to_search = {
						area
					}
					local target_area = nil

					while next(areas_to_search) do
						local current_area = table.remove(areas_to_search)
								
						if current_area.loot and next(current_area.loot) or current_area.hostages and next(current_area.hostages) then
							target_area = current_area

							break
						end

						for _, n_area in pairs(current_area.neighbours) do
							if not found_areas[n_area] then
								found_areas[n_area] = true

								table.insert(areas_to_search, n_area)
							end
						end
					end

					if target_area then
						data.objective.bagjob = target_area.loot or nil
						data.objective.hostagejob = target_area.hostages or nil
						data.objective.in_place = nil
						data.objective.area = target_area
						data.objective.nav_seg = next(target_area.nav_segs)
						data.objective.path_data = {
							{
								data.objective.nav_seg
							}
						}

						if data.name ~= "travel" then
							data.logic._exit(data.unit, "travel")
						end

						return true
					else
						if current_assault_target_area then
							if current_assault_target_area.criminal and current_assault_target_area.criminal.units and next(current_assault_target_area.criminal.units) or current_assault_target_area.loot and next(current_assault_target_area.loot) or current_assault_target_area.hostages and next(current_assault_target_area.hostages) then
								data.objective.bagjob = current_assault_target_area.loot or nil
								data.objective.hostagejob = current_assault_target_area.hostages or nil
								data.objective.in_place = nil
								data.objective.area = target_area
								data.objective.nav_seg = next(current_assault_target_area.nav_segs)
								data.objective.path_data = {
									{
										data.objective.nav_seg
									}
								}
								
								if data.name ~= "travel" then
									data.logic._exit(data.unit, "travel")
								end
											
								return true
							end
						end
					end
				end
			end
		end
	end
	
	return
end