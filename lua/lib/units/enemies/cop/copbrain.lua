require("lib/units/enemies/cop/logics/CopLogicBase")
require("lib/units/enemies/cop/logics/CopLogicInactive")
require("lib/units/enemies/cop/logics/CopLogicIdle")
require("lib/units/enemies/cop/logics/CopLogicAttack")
require("lib/units/enemies/cop/logics/CopLogicIntimidated")
require("lib/units/enemies/cop/logics/CopLogicTravel")
require("lib/units/enemies/cop/logics/CopLogicArrest")
require("lib/units/enemies/cop/logics/CopLogicGuard")
require("lib/units/enemies/cop/logics/CopLogicFlee")
require("lib/units/enemies/cop/logics/CopLogicSniper")
require("lib/units/enemies/cop/logics/CopLogicTrade")
require("lib/units/enemies/cop/logics/CopLogicPhalanxMinion")
require("lib/units/enemies/cop/logics/CopLogicPhalanxVip")
require("lib/units/enemies/tank/logics/TankCopLogicAttack")
require("lib/units/enemies/shield/logics/ShieldLogicAttack")
require("lib/units/enemies/spooc/logics/SpoocLogicIdle")
require("lib/units/enemies/spooc/logics/SpoocLogicAttack")
require("lib/units/enemies/taser/logics/TaserLogicAttack")
local old_init = CopBrain.post_init
local logic_variants = {
	security = {
		idle = CopLogicIdle,
		attack = CopLogicAttack,
		travel = CopLogicTravel,
		inactive = CopLogicInactive,
		intimidated = CopLogicIntimidated,
		arrest = CopLogicArrest,
		guard = CopLogicGuard,
		flee = CopLogicFlee,
		sniper = CopLogicSniper,
		trade = CopLogicTrade,
		phalanx = CopLogicPhalanxMinion
	}
}
local security_variant = logic_variants.security
function CopBrain:post_init()
	CopBrain._logic_variants.deathvox_shield = clone(security_variant)
	CopBrain._logic_variants.deathvox_shield.intimidated = nil
	CopBrain._logic_variants.deathvox_shield.flee = nil
	
	CopBrain._logic_variants.deathvox_heavyar = clone(security_variant)
	CopBrain._logic_variants.deathvox_lightar = clone(security_variant)
	CopBrain._logic_variants.deathvox_medic = clone(security_variant)
	CopBrain._logic_variants.deathvox_guard = clone(security_variant)
	CopBrain._logic_variants.deathvox_gman = clone(security_variant)
	CopBrain._logic_variants.deathvox_lightshot = clone(security_variant)
	CopBrain._logic_variants.deathvox_heavyshot = clone(security_variant)
	
	CopBrain._logic_variants.deathvox_guarddozer = clone(security_variant)
	
	CopBrain._logic_variants.deathvox_taser = clone(security_variant)
	CopBrain._logic_variants.deathvox_taser.attack = TaserLogicAttack
	-- CopBrain._logic_variants.deathvox_taser.travel = TaserLogicTravel
	CopBrain._logic_variants.deathvox_sniper_assault = clone(security_variant)
	CopBrain._logic_variants.deathvox_sniper = clone(security_variant)
	CopBrain._logic_variants.deathvox_cloaker = clone(security_variant)
	CopBrain._logic_variants.deathvox_cloaker.idle = SpoocLogicIdle
	CopBrain._logic_variants.deathvox_cloaker.attack = SpoocLogicAttack
	-- CopBrain._logic_variants.deathvox_cloaker.travel = SpoocLogicTravel
	CopBrain._logic_variants.deathvox_grenadier = clone(security_variant)
	
	CopBrain._logic_variants.deathvox_greendozer = clone(security_variant)
	CopBrain._logic_variants.deathvox_blackdozer = clone(security_variant)
	CopBrain._logic_variants.deathvox_lmgdozer = clone(security_variant)
	CopBrain._logic_variants.deathvox_medicdozer = clone(security_variant)

	CopBrain._logic_variants.deathvox_cop_pistol = clone(security_variant)
	CopBrain._logic_variants.deathvox_cop_revolver = clone(security_variant)
	CopBrain._logic_variants.deathvox_cop_shotgun = clone(security_variant)
	CopBrain._logic_variants.deathvox_cop_smg = clone(security_variant)
	
	CopBrain._logic_variants.deathvox_fbi_hrt = clone(security_variant)
	CopBrain._logic_variants.deathvox_fbi_veteran = clone(security_variant)
	CopBrain._logic_variants.deathvox_fbi_rookie = clone(security_variant)

	old_init(self)
end

CopBrain._NET_EVENTS = {
	stopped_seeing_client_peaceful = 11,
	detected_client_peaceful_verified = 10,
	detected_client_peaceful = 9,
	client_no_longer_verified = 8,
	detected_suspected_client = 7,
	stopped_suspecting_client = 6,
	suspecting_client_verified = 5,
	suspecting_client = 4,
	detected_client = 3,
	stopped_seeing_client = 2,
	seeing_client = 1
}

function CopBrain:sync_net_event(event_id, peer)
	local peer_id = peer:id()
	local peer_unit = managers.criminals:character_unit_by_peer_id(peer_id)

	if not peer_unit then
		return
	end

	if event_id == self._NET_EVENTS.seeing_client then
		managers.groupai:state():on_criminal_suspicion_progress(peer_unit, self._unit, 1, peer_id)
	elseif event_id == self._NET_EVENTS.stopped_seeing_client then
		managers.groupai:state():on_criminal_suspicion_progress(peer_unit, self._unit, false, peer_id)
	elseif event_id == self._NET_EVENTS.detected_client then
		managers.groupai:state():on_criminal_suspicion_progress(peer_unit, self._unit, true, peer_id)

		self._unit:movement():set_cool(false, managers.groupai:state().analyse_giveaway(self._unit:base()._tweak_table, peer_unit))

		local att_obj_data = CopLogicBase.identify_attention_obj_instant(self._logic_data, peer_unit:key())

		if att_obj_data and att_obj_data.criminal_record then
			managers.groupai:state():criminal_spotted(peer_unit)
		end
	elseif event_id == self._NET_EVENTS.detected_client_peaceful or event_id == self._NET_EVENTS.detected_client_peaceful_verified then
		local t = self._logic_data.t
		local att_u_key = peer_unit:key()
		local att_obj_data = self._logic_data.detected_attention_objects[att_u_key]

		if att_obj_data then
			if not att_obj_data.client_peaceful_detection then
				mvector3.set(att_obj_data.verified_pos, att_obj_data.m_head_pos)

				att_obj_data.verified_dis = mvector3.distance(self._unit:movement():m_head_pos(), att_obj_data.m_head_pos)

				if not att_obj_data.identified then
					att_obj_data.identified = true
					att_obj_data.identified_t = t
					att_obj_data.notice_progress = nil
					att_obj_data.prev_notice_chk_t = nil
				elseif att_obj_data.uncover_progress then
					att_obj_data.uncover_progress = nil
				end
			end
		else
			local attention_info = managers.groupai:state():get_AI_attention_objects_by_filter(self._logic_data.SO_access_str)[att_u_key]

			if attention_info then
				local settings = attention_info.handler:get_attention(self._logic_data.SO_access, nil, nil, self._logic_data.team)

				if settings then
					att_obj_data = CopLogicBase._create_detected_attention_object_data(t, self._unit, att_u_key, attention_info, settings)
					att_obj_data.identified = true
					att_obj_data.identified_t = t
					att_obj_data.notice_progress = nil
					att_obj_data.prev_notice_chk_t = nil

					self._logic_data.detected_attention_objects[att_u_key] = att_obj_data
				end
			end
		end

		if att_obj_data then
			att_obj_data.client_peaceful_detection = true

			if event_id == self._NET_EVENTS.detected_client_peaceful_verified then
				att_obj_data.verified = true
			end
		end
	elseif event_id == self._NET_EVENTS.suspecting_client or event_id == self._NET_EVENTS.suspecting_client_verified then
		local t = self._logic_data.t
		local att_u_key = peer_unit:key()
		local att_obj_data = self._logic_data.detected_attention_objects[att_u_key]

		if att_obj_data then
			if not att_obj_data.client_casing_suspicion then
				mvector3.set(att_obj_data.verified_pos, att_obj_data.m_head_pos)

				att_obj_data.verified_dis = mvector3.distance(self._unit:movement():m_head_pos(), att_obj_data.m_head_pos)

				if not att_obj_data.identified then
					att_obj_data.identified = true
					att_obj_data.identified_t = t
					att_obj_data.notice_progress = nil
					att_obj_data.prev_notice_chk_t = nil
				elseif att_obj_data.uncover_progress then
					att_obj_data.uncover_progress = nil
				end
			end
		else
			local attention_info = managers.groupai:state():get_AI_attention_objects_by_filter(self._logic_data.SO_access_str)[att_u_key]

			if attention_info then
				local settings = attention_info.handler:get_attention(self._logic_data.SO_access, nil, nil, self._logic_data.team)

				if settings then
					att_obj_data = CopLogicBase._create_detected_attention_object_data(t, self._unit, att_u_key, attention_info, settings)
					att_obj_data.identified = true
					att_obj_data.identified_t = t
					att_obj_data.notice_progress = nil
					att_obj_data.prev_notice_chk_t = nil

					self._logic_data.detected_attention_objects[att_u_key] = att_obj_data
				end
			end
		end

		if att_obj_data then
			if not att_obj_data.client_casing_suspicion then
				att_obj_data.client_casing_suspicion = true

				managers.groupai:state():on_criminal_suspicion_progress(peer_unit, self._unit, 1, peer_id)
			end

			if event_id == self._NET_EVENTS.suspecting_client_verified then
				att_obj_data.verified = true
			end
		end
	elseif event_id == self._NET_EVENTS.client_no_longer_verified then
		local att_obj_data = self._logic_data.detected_attention_objects[peer_unit:key()]

		if att_obj_data then
			att_obj_data.verified = nil
		end
	elseif event_id == self._NET_EVENTS.stopped_suspecting_client or event_id == self._NET_EVENTS.stopped_seeing_client_peaceful then
		if event_id == self._NET_EVENTS.stopped_suspecting_client then
			managers.groupai:state():on_criminal_suspicion_progress(peer_unit, self._unit, false, peer_id)
		end

		local att_obj_data = self._logic_data.detected_attention_objects[peer_unit:key()]

		if att_obj_data then
			att_obj_data.handler:remove_listener("detect_" .. tostring(self._logic_data.key))

			self._logic_data.detected_attention_objects[peer_unit:key()] = nil

			local my_data = self._logic_data.internal_data

			if self._logic_data.attention_obj and self._logic_data.attention_obj.u_key == peer_unit:key() then
				CopLogicBase._set_attention_obj(self._logic_data, nil, nil)

				if my_data then
					if my_data.firing or my_data.firing_on_client then
						self._unit:movement():set_allow_fire(false)

						my_data.firing = nil
						my_data.firing_on_client = nil
					end
				end
			end

			if my_data and my_data.arrest_targets then
				my_data.arrest_targets[peer_unit:key()] = nil
			end

			local set_attention = self._unit:movement():attention()

			if set_attention and set_attention.u_key == peer_unit:key() then
				self._unit:movement():set_attention()
			end
		end
	elseif event_id == self._NET_EVENTS.detected_suspected_client then
		managers.groupai:state():on_criminal_suspicion_progress(peer_unit, self._unit, true, peer_id)

		local att_obj_data = self._logic_data.detected_attention_objects[peer_unit:key()]

		if att_obj_data then
			att_obj_data.client_casing_suspicion = nil
			att_obj_data.client_casing_detected = true
		end
	end
end

function CopBrain:on_nav_link_unregistered(element_id)
	if self._logic_data.pathing_results then
		local failed_search_ids = nil

		for path_name, path in pairs(self._logic_data.pathing_results) do
			if type(path) == "table" and path[1] and type(path[1]) ~= "table" then
				for i, nav_point in ipairs(path) do
					if not nav_point.x and nav_point.script_data and nav_point:script_data().element._id == element_id then
						failed_search_ids = failed_search_ids or {}
						failed_search_ids[path_name] = true

						break
					end
				end
			end
		end

		if failed_search_ids then
			for search_id, _ in pairs(failed_search_ids) do
				self._logic_data.pathing_results[search_id] = "failed"
			end
		end
	end

	local paths = self._current_logic._get_all_paths and self._current_logic._get_all_paths(self._logic_data)

	if not paths then
		return
	end

	local verified_paths = {}

	for path_name, path in pairs(paths) do
		local path_is_ok = true

		for i, nav_point in ipairs(path) do
			if not nav_point.x and nav_point.script_data and nav_point:script_data().element._id == element_id then
				path_is_ok = false

				break
			end
		end

		if path_is_ok then
			verified_paths[path_name] = path
		end
	end

	self._current_logic._set_verified_paths(self._logic_data, verified_paths)
end

function CopBrain:convert_to_criminal(mastermind_criminal)
	if self._alert_listen_key then
		managers.groupai:state():remove_alert_listener(self._alert_listen_key)
	else
		self._alert_listen_key = "CopBrain" .. tostring(self._unit:key())
	end

	local alert_listen_filter = managers.groupai:state():get_unit_type_filter("combatant")
	local alert_types = {
		explosion = true,
		fire = true,
		aggression = true,
		bullet = true
	}

	managers.groupai:state():add_alert_listener(self._alert_listen_key, callback(self, self, "on_alert"), alert_listen_filter, alert_types, self._unit:movement():m_head_pos())

	self._logic_data.is_converted = true
	self._logic_data.group = nil
	local mover_col_body = self._unit:body("mover_blocker")

	mover_col_body:set_enabled(false)

	local attention_preset = PlayerMovement._create_attention_setting_from_descriptor(self, tweak_data.attention.settings.team_enemy_cbt, "team_enemy_cbt")

	self._attention_handler:override_attention("enemy_team_cbt", attention_preset)

	local health_multiplier = 1
	local damage_multiplier = 1

	if alive(mastermind_criminal) then
		health_multiplier = health_multiplier * (mastermind_criminal:base():upgrade_value("player", "convert_enemies_health_multiplier") or 1)
		health_multiplier = health_multiplier * (mastermind_criminal:base():upgrade_value("player", "passive_convert_enemies_health_multiplier") or 1)
		damage_multiplier = damage_multiplier * (mastermind_criminal:base():upgrade_value("player", "convert_enemies_damage_multiplier") or 1)
		damage_multiplier = damage_multiplier * (mastermind_criminal:base():upgrade_value("player", "passive_convert_enemies_damage_multiplier") or 1)
	else
		health_multiplier = health_multiplier * managers.player:upgrade_value("player", "convert_enemies_health_multiplier", 1)
		health_multiplier = health_multiplier * managers.player:upgrade_value("player", "passive_convert_enemies_health_multiplier", 1)
		damage_multiplier = damage_multiplier * managers.player:upgrade_value("player", "convert_enemies_damage_multiplier", 1)
		damage_multiplier = damage_multiplier * managers.player:upgrade_value("player", "passive_convert_enemies_damage_multiplier", 1)
	end

	self._unit:character_damage():convert_to_criminal(health_multiplier)

	self._logic_data.attention_obj = nil

	CopLogicBase._destroy_all_detected_attention_object_data(self._logic_data)

	self._SO_access = managers.navigation:convert_access_flag(tweak_data.character.russian.access)
	self._logic_data.SO_access = self._SO_access
	self._logic_data.SO_access_str = tweak_data.character.russian.access
	self._slotmask_enemies = managers.slot:get_mask("enemies")
	self._logic_data.enemy_slotmask = self._slotmask_enemies
	local equipped_w_selection = self._unit:inventory():equipped_selection()

	if equipped_w_selection then
		self._unit:inventory():remove_selection(equipped_w_selection, true)
	end

	local weap_name = self._unit:base():default_weapon_name()

	self._unit:movement():add_weapons()
	if self._unit:inventory():is_selection_available(1) then
		self._unit:inventory():equip_selection(1, true)
	elseif self._unit:inventory():is_selection_available(2) then
		self._unit:inventory():equip_selection(2, true)
	end
	local weapon_unit = self._unit:inventory():equipped_unit()

	weapon_unit:base():add_damage_multiplier(damage_multiplier)
	self:set_objective(nil)
	self:set_logic("idle", nil)

	self._logic_data.objective_complete_clbk = callback(managers.groupai:state(), managers.groupai:state(), "on_criminal_objective_complete")
	self._logic_data.objective_failed_clbk = callback(managers.groupai:state(), managers.groupai:state(), "on_criminal_objective_failed")

	managers.groupai:state():on_criminal_jobless(self._unit)
	self._unit:base():set_slot(self._unit, 16)
	self._unit:movement():set_stance("hos")

	local action_data = {
		variant = "stand",
		body_part = 1,
		type = "act"
	}

	self._unit:brain():action_request(action_data)
	self._unit:sound():say("cn1", true, nil)
	managers.network:session():send_to_peers_synched("sync_unit_converted", self._unit)
end

function CopBrain:clbk_pathing_results(search_id, path)
    self:_add_pathing_result(search_id, path)
end

function CopBrain:clbk_alarm_pager(ignore_this, data)
	local pager_data = self._alarm_pager_data
	local clbk_id = pager_data.pager_clbk_id
	pager_data.pager_clbk_id = nil

	if not managers.groupai:state():whisper_mode() then
		self:end_alarm_pager()

		return
	end

	if pager_data.nr_calls_made == 0 then
		if managers.groupai:state():is_ecm_jammer_active("pager") and not self._unit:unit_data().ignore_ecm_for_pager then
			self:end_alarm_pager()
			self:begin_alarm_pager(true)

			return
		end

		self._unit:sound():stop()

		if self._unit:character_damage():dead() then
			self._unit:sound():corpse_play(self:_get_radio_id("dsp_radio_query_1"), nil, true)
		else
			self._unit:sound():play(self:_get_radio_id("dsp_radio_query_1"), nil, true)
		end

		self._unit:interaction():set_tweak_data("corpse_alarm_pager")
		self._unit:interaction():set_active(true, true)
	elseif pager_data.nr_calls_made < pager_data.total_nr_calls then
		self._unit:sound():stop()

		if self._unit:character_damage():dead() then
			self._unit:sound():corpse_play(self:_get_radio_id("dsp_radio_reminder_1"), nil, true)
		else
			self._unit:sound():play(self:_get_radio_id("dsp_radio_reminder_1"), nil, true)
		end
	elseif pager_data.nr_calls_made == pager_data.total_nr_calls then
		self._unit:interaction():set_active(false, true)
		managers.groupai:state():on_police_called("alarm_pager_not_answered")
		self._unit:sound():stop()

		if self._unit:character_damage():dead() then
			self._unit:sound():corpse_play("pln_alm_any_any", nil, true)
		else
			self._unit:sound():play("pln_alm_any_any", nil, true)
		end

		self:end_alarm_pager()
	end

	if pager_data.nr_calls_made == pager_data.total_nr_calls - 1 then
		self._unit:interaction():set_outline_flash_state(true, true)
	end

	pager_data.nr_calls_made = pager_data.nr_calls_made + 1

	if pager_data.nr_calls_made <= pager_data.total_nr_calls then
		local duration_settings = tweak_data.player.alarm_pager.call_duration[math.min(#tweak_data.player.alarm_pager.call_duration, pager_data.nr_calls_made)]
		local call_delay = math.lerp(duration_settings[1], duration_settings[2], math.random())
		self._alarm_pager_data.pager_clbk_id = clbk_id

		managers.enemy:add_delayed_clbk(self._alarm_pager_data.pager_clbk_id, callback(self, self, "clbk_alarm_pager"), TimerManager:game():time() + call_delay)
	end
end
	
	
function CopBrain:on_suppressed(state)
    self._logic_data.is_suppressed = state or nil

	if self._current_logic.on_suppressed_state then
		self._current_logic.on_suppressed_state(self._logic_data)

		if self._logic_data.char_tweak.chatter.suppress then
		    local roll = math.rand(1, 100)
			local chance_heeeeelpp = 50
			if roll <= chance_heeeeelpp then
                self._unit:sound():say("hlp", true) 
			else --hopefully some variety here now
                self._unit:sound():say("lk3a", true) 
			end
        end
	end
end
