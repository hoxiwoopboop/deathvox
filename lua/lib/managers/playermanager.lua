Hooks:PostHook(PlayerManager,"_internal_load","deathvox_on_internal_load",function(self)
	if Network:is_server() then 
		deathvox:SyncOptionsToClients()
	else
		deathvox:ResetSessionSettings()
	end
	Hooks:Call("TCD_OnGameStarted")
end)

function PlayerManager:_chk_fellow_crimin_proximity(unit)
	local players_nearby = 0
		
	local criminals = World:find_units_quick(unit, "sphere", unit:position(), 1500, managers.slot:get_mask("criminals_no_deployables"))

	for _, criminal in ipairs(criminals) do
		players_nearby = players_nearby + 1
	end
		
	if players_nearby <= 0 then
		--log("uhohstinky")
	end
		
	return players_nearby
end

if deathvox:IsTotalCrackdownEnabled() then

	function PlayerManager:check_equipment_placement_valid(player, equipment)
		local equipment_data = managers.player:equipment_data_by_name(equipment)

		if not equipment_data then
			return false
		end

		if equipment_data.equipment == "trip_mine" or equipment_data.equipment == "ecm_jammer" then
			return player:equipment():valid_look_at_placement(tweak_data.equipments[equipment_data.equipment]) and true or false
		elseif equipment_data.equipment == "sentry_gun" or equipment_data.equipment == "ammo_bag" or equipment_data.equipment == "sentry_gun_silent" or equipment_data.equipment == "doctor_bag" or equipment_data.equipment == "first_aid_kit" or equipment_data.equipment == "bodybags_bag" then
			local result,revivable_unit = player:equipment():valid_shape_placement(equipment_data.equipment, tweak_data.equipments[equipment_data.equipment])
			return result and true or false,revivable_unit
		elseif equipment_data.equipment == "armor_kit" then
			return player:equipment():valid_shape_placement(equipment_data.equipment,tweak_data.equipments[equipment_data.equipment]) and true or false
		end

		return player:equipment():valid_placement(tweak_data.equipments[equipment_data.equipment]) and true or false
	end
	
	function PlayerManager:damage_reduction_skill_multiplier(damage_type)
		local multiplier = 1
		multiplier = multiplier * self:temporary_upgrade_value("temporary", "dmg_dampener_outnumbered", 1)
		multiplier = multiplier * self:temporary_upgrade_value("temporary", "dmg_dampener_outnumbered_strong", 1)
		multiplier = multiplier * self:temporary_upgrade_value("temporary", "dmg_dampener_close_contact", 1)
		multiplier = multiplier * self:temporary_upgrade_value("temporary", "revived_damage_resist", 1)
		multiplier = multiplier * self:upgrade_value("player", "damage_dampener", 1)
		multiplier = multiplier * self:upgrade_value("player", "health_damage_reduction", 1)
		multiplier = multiplier * self:temporary_upgrade_value("temporary", "first_aid_damage_reduction", 1)
		multiplier = multiplier * self:temporary_upgrade_value("temporary", "revive_damage_reduction", 1)
		multiplier = multiplier * self:get_hostage_bonus_multiplier("damage_dampener")
		multiplier = multiplier * self._properties:get_property("revive_damage_reduction", 1)
		multiplier = multiplier * self._temporary_properties:get_property("revived_damage_reduction", 1)
		if self:get_property("armor_plates_active") then 
			--this is the only change atm
			multiplier = multiplier * tweak_data.upgrades.armor_plates_dmg_reduction
		end
		local dmg_red_mul = self:team_upgrade_value("damage_dampener", "team_damage_reduction", 1)


		if self:has_category_upgrade("player", "passive_damage_reduction") then
			local health_ratio = self:player_unit():character_damage():health_ratio()
			local min_ratio = self:upgrade_value("player", "passive_damage_reduction")

			if health_ratio < min_ratio then
				dmg_red_mul = dmg_red_mul - (1 - dmg_red_mul)
			end
		end

		multiplier = multiplier * dmg_red_mul

		if damage_type == "melee" then
			multiplier = multiplier * managers.player:upgrade_value("player", "melee_damage_dampener", 1)
		end

		local current_state = self:get_current_state()

		if current_state and current_state:_interacting() then
			multiplier = multiplier * managers.player:upgrade_value("player", "interacting_damage_multiplier", 1)
		end


		return multiplier
	end

	Hooks:PostHook(PlayerManager,"check_skills","deathvox_check_cd_skills",function(self)
		if self:has_category_upgrade("player","melee_hit_speed_boost") then 	
			Hooks:Add("OnPlayerMeleeHit","cd_proc_butterfly_bee_aced",
				function(hit_unit,col_ray,action_data,defense_data,t)
					if hit_unit and not managers.enemy:is_civilian(hit_unit) then 
						managers.player:activate_temporary_property("float_butterfly_movement_speed_multiplier",unpack(managers.player:upgrade_value("player","melee_hit_speed_boost",{0,0})))
					end
				end
			)
		end
		
		if self:has_category_upgrade("player","escape_plan") then 
			Hooks:Add("OnPlayerShieldBroken","cd_proc_escape_plan",
				function(player_unit)
					if alive(player_unit) then 
						local movement = player_unit:movement()
						
						local escape_plan_data = managers.player:upgrade_value("player","escape_plan",{0,0,0,0})
						local stamina_restored_percent = escape_plan_data[1]
						local sprint_speed_bonus = escape_plan_data[2]
						local escape_plan_duration = escape_plan_data[3]
						local move_speed_bonus = escape_plan_data[4]
						movement:_change_stamina(movement:_max_stamina() * stamina_restored_percent)
						self:activate_temporary_property("escape_plan_speed_bonus",escape_plan_duration,{sprint_speed_bonus,move_speed_bonus})
					end
				end
			)
		end
		
		if self:has_category_upgrade("saw","consecutive_damage_bonus") then 
			self:set_property("rolling_cutter_aced_stacks",0)
			
			Hooks:Register("OnProcRollingCutterBasic")
			Hooks:Add("OnProcRollingCutterBasic","AddToRollingCutterStacks",
				function(stack_add)
					stack_add = stack_add or 1
					local rolling_cutter_data = self:upgrade_value("saw","consecutive_damage_bonus",{0,0,0})
					
					self:add_to_property("rolling_cutter_aced_stacks",stack_add)
					
					managers.enemy:remove_delayed_clbk("rolling_cutter_stacks_expire",true)
					managers.enemy:add_delayed_clbk("rolling_cutter_stacks_expire",
						function()
							self:set_property("rolling_cutter_aced_stacks",0)
						end,
						Application:time() + rolling_cutter_data[3]
					)
				end
			)
		end
	
		if self:has_category_upgrade("heavy","collateral_damage") then 
			self._message_system:register(Message.OnWeaponFired,"proc_collateral_damage",
				function(weapon_unit,result)
				
					--this is called on any weapon firing,
					--so this needs checks to make sure that the weapon class is heavy
					--and that the user_unit is the player
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = weapon_unit and weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("heavy") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					
					local collateral_damage_data = self:upgrade_value("heavy","collateral_damage",{0,0})
					local damage_mul = collateral_damage_data[1]
					local radius = collateral_damage_data[2]
					
					--do stuff here
					
						--works on miss
						--does not hit civs
				end
			)
		end
		
		if self:has_category_upgrade("heavy","death_grips_stacks") then
			self:set_property("current_death_grips_stacks",0)
			self._message_system:register(Message.OnEnemyKilled,"proc_death_grips",
				function(weapon_unit,variant,killed_unit)
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = weapon_unit and weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("heavy") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					local death_grips_data = self:upgrade_value("heavy","death_grips_stacks",{0,0})
					self:set_property("current_death_grips_stacks",math.min(self:get_property("current_death_grips_stacks") + 1,death_grips_data[2]))
					managers.enemy:remove_delayed_clbk("death_grips_stacks_expire",true)
					managers.enemy:add_delayed_clbk("death_grips_stacks_expire",
						function()
							self:set_property("current_death_grips_stacks",0)
						end,
						Application:time() + death_grips_data[1]
					)
				end
			)
		end
		
		if self:has_category_upgrade("heavy","lead_farmer") then 
			self:set_property("current_lead_farmer_stacks",0)
			self._message_system:register(Message.OnEnemyKilled,"proc_lead_farmer",
				function(weapon_unit,variant,killed_unit)
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = weapon_unit and weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("heavy") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					self:add_to_property("current_lead_farmer_stacks",1)
				end
			)
			
			Hooks:Add("OnPlayerReloadComplete","on_player_reloaded_consume_lead_farmer",
				--Message.OnPlayerReload is called when reload STARTS, which is before the reload mul is calculated.
				--so it's pretty useless to reset stacks from that message event.
				function(weapon_unit)
					local weapon_base = weapon_unit and weapon_unit:base()
					if weapon_base and weapon_base:is_weapon_class("heavy") then 
						managers.player:set_property("current_lead_farmer_stacks",0)
					end
				end
			)
		end
		
		if self:has_category_upgrade("class_shotgun","shell_games_reload_bonus") then
			self:set_property("shell_games_rounds_loaded",0)
		end
		if self:has_category_upgrade("weapon", "making_miracles_basic") then
			self:set_property("making_miracles_stacks",0)
			self._message_system:register(Message.OnHeadShot,"proc_making_miracles_basic",
				function()
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon = player:inventory():equipped_unit():base()
					if not weapon:is_weapon_class("rapidfire") then 
						return
					end
					
					self:add_to_property("making_miracles_stacks",1) --add one stack
					managers.enemy:remove_delayed_clbk("making_miracles_stack_expire",true) --reset timer if active
					managers.enemy:add_delayed_clbk("making_miracles_stack_expire", --add 4-second removal timer for stacks
						function()
							self:set_property("making_miracles_stacks",0)
						end,
						Application:time() + self:upgrade_value("weapon","making_miracles_basic",{0,0})[2]
					)
				end
			)
		else
			self._message_system:unregister(Message.OnLethalHeadShot,"proc_making_miracles_basic")
		end
		
		if self:has_category_upgrade("weapon","making_miracles_aced") then 
			self._message_system:register(Message.OnLethalHeadShot,"proc_making_miracles_aced",
				function(attack_data)
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = attack_data and attack_data.weapon_unit and attack_data.weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("rapidfire") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					
					self:add_to_property("making_miracles_stacks",1)
				end
			)
	else
		self._message_system:unregister(Message.OnLethalHeadShot,"proc_making_miracles_aced")
	end
		self:set_property("current_point_and_click_stacks",0)
		if self:has_category_upgrade("player","point_and_click_stacks") then 
		
		
			Hooks:Add("TCD_OnGameStarted","OnGameStart_CreatePACElement",function() --check_skills() is called before the hud is created so it must instead call on an event
			
				--create buff-specific hud element; todo create a buffmanager class to handle this
				--this is temporary until more of the core systems are done, and then i can dedicate more time 
				--to creating a buff tracker system + hud elements 
				--		-offy
				local hudtemp = managers.hud and managers.hud._hud_temp and managers.hud._hud_temp._hud_panel
				if hudtemp and alive(hudtemp) then
					local trackerhud = hudtemp:panel({
						name = "point_and_click_tracker",
						w = 100,
						h = 100
					})
					trackerhud:set_position((hudtemp:w() - trackerhud:w()) / 2,450)
					local debug_trackerhud = trackerhud:rect({
						name = "debug",
						color = Color.red,
						visible = false,
						alpha = 0.1
					})
					local icon_size = 64
					local icon_x,icon_y = 6,11 --bullseye
					local skill_atlas = "guis/textures/pd2/skilltree/icons_atlas"
					local skill_atlas_2 = "guis/textures/pd2/skilltree_2/icons_atlas_2"
					local perkdeck_atlas = "guis/textures/pd2/specialization/icons_atlas"	

					local icon = trackerhud:bitmap({
						name = "icon",
						texture = skill_atlas_2,
						texture_rect = {icon_x * 80,icon_y * 80,80,80},
						alpha = 0.9,
--						x = (trackerhud:w() - icon_size) / 2,
--						y = 0,
						w = icon_size,
						h = icon_size
					})
					icon:set_center(trackerhud:w()/2,trackerhud:h()/2)
					local stack_count = trackerhud:text({
						name = "text",
						text = "0",
						font = tweak_data.hud.medium_font,
						font_size = 16,
						align = "center",
						color = Color.white,
						vertical = "bottom"
					})
					local function check_point_and_click_stacks(t,dt)
						if alive(stack_count) then 
							stack_count:set_text(self:get_property("current_point_and_click_stacks",0))
							if managers.enemy:is_clbk_registered("point_and_click_on_shot_missed") and alive(icon) then 
								icon:set_color(Color(math.sin(t * 300 * math.pi),0,0))
							else
								icon:set_color(Color.white)
							end
						end
					end
					BeardLib:AddUpdater("update_tcd_buffs_hud",check_point_and_click_stacks,false)
				end
			end)
			self._message_system:register(Message.OnEnemyShot,"proc_point_and_click",function(unit,attack_data)
				local player = self:local_player()
				if not alive(player) then 
					return
				end
				local weapon_base = attack_data and attack_data.weapon_unit and attack_data.weapon_unit:base()
				if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("precision") then 
					if weapon_base._setup.user_unit ~= player then 
						return
					end
				else
					return
				end
				self:add_to_property("current_point_and_click_stacks",self:upgrade_value("player","point_and_click_stacks",0))
			end)
			if self:has_category_upgrade("player","point_and_click_stack_from_kill") then 
				self._message_system:register(Message.OnEnemyKilled,"proc_investment_returns_basic",function(weapon_unit,variant,killed_unit)
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = weapon_unit and weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("precision") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					self:add_to_property("current_point_and_click_stacks",self:upgrade_value("player","point_and_click_stack_from_kill",0))
				end)
			else
				self._message_system:unregister(Message.OnEnemyKilled,"proc_investment_returns_basic")
			end
			
			if self:has_category_upgrade("player","point_and_click_stack_from_headshot_kill") then 
				self._message_system:register(Message.OnLethalHeadShot,"proc_investment_returns_aced",function(attack_data)
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = attack_data and attack_data.weapon_unit and attack_data.weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("precision") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					self:add_to_property("current_point_and_click_stacks",self:upgrade_value("player","point_and_click_stack_from_headshot_kill",0))
				end)
			else
				self._message_system:unregister(Message.OnLethalHeadShot,"proc_investment_returns_aced")
			end
			
			if self:has_category_upgrade("player","point_and_click_stack_mulligan") then 
				self._message_system:register(Message.OnEnemyKilled,"proc_mulligan_reprieve",function(weapon_unit,variant,killed_unit)
					local player = self:local_player()
					if not alive(player) then 
						return
					end
					local weapon_base = weapon_unit and weapon_unit:base()
					if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("precision") then 
						if weapon_base._setup.user_unit ~= player then 
							return
						end
					else
						return
					end
					
					managers.enemy:remove_delayed_clbk("point_and_click_on_shot_missed",true)
				end)
			else
				self._message_system:unregister(Message.OnEnemyKilled,"proc_mulligan_reprieve")
			end
			
			self._message_system:register(Message.OnWeaponFired,"clear_point_and_click_stacks",function(weapon_unit,result)
				if result and result.hit_enemy then
					return
				end
				
				local player = self:local_player()
				if not alive(player) then 
					return
				end
				
				local weapon_base = weapon_unit and weapon_unit:base()
				if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("precision") then 
					if weapon_base._setup.user_unit ~= player then 
						return
					end
				else
					return
				end
				
				if (self:get_property("current_point_and_click_stacks",0) > 0) and not managers.enemy:is_clbk_registered("point_and_click_on_shot_missed") then 
					managers.enemy:add_delayed_clbk("point_and_click_on_shot_missed",callback(self,self,"set_property","current_point_and_click_stacks",0),
						Application:time() + self:upgrade_value("player","point_and_click_stack_mulligan",0)
					)
				end
			end)
		else
			self._message_system:unregister(Message.OnEnemyShot,"proc_point_and_click")
			self._message_system:unregister(Message.OnWeaponFired,"clear_point_and_click_stacks")
		end
		
		if self:has_category_upgrade("weapon","magic_bullet") then 
			self._message_system:register(Message.OnLethalHeadShot,"proc_magic_bullet",function(attack_data)
				local player = self:local_player()
				if not alive(player) then 
					return
				end
				local weapon_base = attack_data.weapon_unit and attack_data.weapon_unit:base()
				if weapon_base and weapon_base._setup and weapon_base._setup.user_unit and weapon_base:is_weapon_class("precision") then 
					if weapon_base._setup.user_unit ~= player then 
						return
					end
				else
					return
				end
				
				if not weapon_base:ammo_full() then 
					local magic_bullet_level = self:upgrade_level("weapon","magic_bullet",0)
					local clip_current = weapon_base:get_ammo_remaining_in_clip()
					local clip_max = weapon_base:get_ammo_max_per_clip()
					local weapon_index = self:equipped_weapon_index()
					if (magic_bullet_level == 2) and (clip_current < clip_max) then
						weapon_base:set_ammo_remaining_in_clip(math.min(clip_max,clip_current + self:upgrade_value("weapon","magic_bullet",0)))
					end
					weapon_base:add_ammo_to_pool(self:upgrade_value("weapon","magic_bullet",0),self:equipped_weapon_index())
					managers.hud:set_ammo_amount(weapon_index, weapon_base:ammo_info())
					player:sound():play("pickup_ammo")
				end
			end)
		else
			self._message_system:unregister(Message.OnLethalHeadShot,"proc_magic_bullet")
		end
		
	end)
	
	function PlayerManager:movement_speed_multiplier(speed_state, bonus_multiplier, upgrade_level, health_ratio)
		local multiplier = 1
		local armor_penalty = self:mod_movement_penalty(self:body_armor_value("movement", upgrade_level, 1))
		multiplier = multiplier + armor_penalty - 1

		if bonus_multiplier then
			multiplier = multiplier + bonus_multiplier - 1
		end

		multiplier = multiplier + self:get_temporary_property("float_butterfly_movement_speed_multiplier",0)
		
		local escape_plan_status = self:get_temporary_property("escape_plan_speed_bonus",false)
		local escape_plan_sprint_bonus = 0
		local escape_plan_movement_bonus = 0

		if escape_plan_status and type(escape_plan_status) == "table" then 
			escape_plan_sprint_bonus = escape_plan_status[1] or escape_plan_sprint_bonus
			escape_plan_movement_bonus = escape_plan_status[2] or escape_plan_movement_bonus
		end
		
		if speed_state then
			multiplier = multiplier + self:upgrade_value("player", speed_state .. "_speed_multiplier", 1) - 1
			
			if speed_state == "run" then 
				multiplier = multiplier + escape_plan_sprint_bonus
			end
		end
		multiplier = multiplier + escape_plan_movement_bonus

		multiplier = multiplier + self:get_hostage_bonus_multiplier("speed") - 1
		multiplier = multiplier + self:upgrade_value("player", "movement_speed_multiplier", 1) - 1

		if self:num_local_minions() > 0 then
			multiplier = multiplier + self:upgrade_value("player", "minion_master_speed_multiplier", 1) - 1
		end

		if self:has_category_upgrade("player", "secured_bags_speed_multiplier") then
			local bags = 0
			bags = bags + (managers.loot:get_secured_mandatory_bags_amount() or 0)
			bags = bags + (managers.loot:get_secured_bonus_bags_amount() or 0)
			multiplier = multiplier + bags * (self:upgrade_value("player", "secured_bags_speed_multiplier", 1) - 1)
		end

		if managers.player:has_activate_temporary_upgrade("temporary", "berserker_damage_multiplier") then
			multiplier = multiplier * (tweak_data.upgrades.berserker_movement_speed_multiplier or 1)
		end

		if health_ratio then
			local damage_health_ratio = self:get_damage_health_ratio(health_ratio, "movement_speed")
			multiplier = multiplier * (1 + managers.player:upgrade_value("player", "movement_speed_damage_health_ratio_multiplier", 0) * damage_health_ratio)
		end

		local damage_speed_multiplier = managers.player:temporary_upgrade_value("temporary", "damage_speed_multiplier", managers.player:temporary_upgrade_value("temporary", "team_damage_speed_multiplier_received", 1))
		multiplier = multiplier * damage_speed_multiplier
		return multiplier
	end


end