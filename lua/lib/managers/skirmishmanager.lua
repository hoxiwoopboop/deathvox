local on_start_assault_original = SkirmishManager.on_start_assault
function SkirmishManager:on_start_assault()
	if not self._set_first_assault then
		local diff = "normal"
		local job_id_index = tweak_data.narrative:get_index_from_job_id(managers.job:current_job_id())
		local level_id_index = tweak_data.levels:get_index_from_level_id(Global.game_settings.level_id)
		local difficulty_index = tweak_data:difficulty_to_index(diff)
		local one_down = Global.game_settings.one_down and true or false		
		Global.game_settings.difficulty = diff
		tweak_data:set_difficulty(diff)

		if managers.network then
			managers.network:session():send_to_peers("sync_game_settings", job_id_index, level_id_index, difficulty_index, one_down)
		end

		self._set_first_assault = true
	end

	on_start_assault_original(self)
end

Hooks:PreHook(SkirmishManager, "on_end_assault", "SkirmishMod_IncreaseDifficulty", function(self)
	local wave_number = self:current_wave_number() + 1
	local difficulty = {
		"normal", --1
		"hard", --2
		"overkill", --3
		"overkill_145", --4
		"overkill_145", --5
		"easy_wish", --6
		"overkill_290", --7
		"overkill_290", --8
		"sm_wish", --9
		"sm_wish"
	}
	if difficulty[wave_number] then
		local duff = difficulty[wave_number]
		local job_id_index = tweak_data.narrative:get_index_from_job_id(managers.job:current_job_id())
		local level_id_index = tweak_data.levels:get_index_from_level_id(Global.game_settings.level_id)
		local difficulty_index = tweak_data:difficulty_to_index(duff)
		local one_down = Global.game_settings.one_down and true or false		
		Global.game_settings.difficulty = duff
		tweak_data:set_difficulty(duff)

		if managers.network then
			managers.network:session():send_to_peers("sync_game_settings", job_id_index, level_id_index, difficulty_index, one_down)
		end
	end
end)
