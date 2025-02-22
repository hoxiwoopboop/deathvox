function i_hate_lua(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

function ElementSpawnEnemyGroup:spawn_groups()
	local dv_spawngroups = {
		-- Normal
		"normal_solopistol",
		"normal_soloshot",
		"normal_solorevolver",
		"normal_solosmg",
		"normal_revolvergroup",
		"normal_shotgroup",
		"normal_smggroup",
		"normal_copcombo",
		"normal_ARswat",
		"normal_swatcombo",
		"normal_shieldbasicpistol",
		"normal_shieldbasic",
		"normal_rookiepair",
		"normal_rookie",
		
		"hard_smggroup",
		"hard_copcombo",
		"hard_medicgroup",
		"hard_revolvermedic",
		"hard_argroupranged",
		"hard_lightgroup",
		"hard_flankswat",
		"hard_mixgroup",
		"hard_shieldlight",
		"hard_shieldsmg",
		"hard_shieldheavy",
		"hard_taser",
		"hard_rookiemedic",
		"hard_rookiecombo",
		"hard_rookieshotgun",
		
		"vhard_lightARranged",
		"vhard_lightARcharge",
		"vhard_lightARchargeMed",
		"vhard_lightARflankMed",
		"vhard_lightmixcharge",
		"vhard_lightmixchargeMed",
		"vhard_lightmixflankMed",
		"vhard_mixARcharge",
		"vhard_mixbothcharge",
		"vhard_mixheavybothcharge",
		"vhard_taserARgroup",
		"vhard_tasershotgroup",
		"vhard_shieldlightgroup",
		"vhard_shieldheavyARgroup",
		"vhard_shieldheavyshotgroup",
		"vhard_bullsolo",
		"vhard_hrtmedic",
		"vhard_hrttaser",

		"ovk_mixARcharge",
		"ovk_mixheavyARcharge",
		"ovk_comboARcharge",
		"ovk_mixcombocharge",
		"ovk_mixcombomediccharge",
		"ovk_mixshotcharge",
		"ovk_shotcombomedicflank",
		"ovk_arcombomedicflank",
		"ovk_heavycombocharge",
		"ovk_lightcomboflank",
		"ovk_shieldcombo",
		"ovk_shieldshot",
		"ovk_tazerAR",
		"ovk_tazershot",
		"ovk_tazermedic",
		"ovk_greendozer",
		"ovk_blackdozer",
		"ovk_greenknight",
		"ovk_blackknight",
		"ovk_spoocpair",
		"ovk_vetmed",
		"ovk_hrtvetmix",
		"ovk_hrttaser",
		
		"mh_group_1",
		"mh_group_2_std",
		"mh_group_2_med",
		"mh_group_3_std",
		"mh_group_3_med",
		"mh_group_4_std",
		"mh_group_4_med",
		"mh_group_5_std",
		"mh_group_5_med",
		"mh_whitedozer",
		"mh_blackpaladin",
		"mh_greenpaladin",
		"mh_takedown",
		"mh_castle",
		"mh_taserpair",
		"mh_spoocpair",
		"mh_partners",
		"mh_vetmed",
		"mh_hrtvetmix",
		"mh_hrttaser",

		"dw_group_1",
		"dw_group_2_std",
		"dw_group_2_med",
		"dw_group_3_std",
		"dw_group_3_med",
		"dw_group_4_std",
		"dw_group_4_med",
		"dw_group_5_std",
		"dw_group_5_med",
		"dw_skullpaladin",
		"dw_blackball",
		"dw_greeneye",
		"dw_takedowner",
		"dw_spoocpair",
		"dw_citadel",
		"dw_vetmed",
		"dw_hrtvetmix",
		"dw_spooctrio",
		"dw_hrttaser",

		"cd_group_1",
		"cd_group_2_std",
		"cd_group_2_med",
		"cd_group_3_std",
		"cd_group_3_med",
		"cd_group_4_std",
		"cd_group_4_med",
		"cd_group_5_std",
		"cd_group_5_med",
		"gorgon",
		"atlas",
		"chimera",
		"zeus",
		"janus",
		"epeius",
		"damocles",
		"caduceus",
		"atropos",
		"aegeas",
		"recovery_unit",
		"too_group",
		"styx",
		"recon",
		"hoplon"
	}
	dv_spawngroups = i_hate_lua(dv_spawngroups)
	
	local opt = self._values.preferred_spawn_groups
	
	local has_regular_enemies = nil
	
	if opt then
		for name, name2 in pairs(opt) do
			if name2 == "tac_swat_rifle_flank" or name2 == "tac_bull_rush" then
				--log("fuck yes")
				has_regular_enemies = true
			end
		end
		
		if not has_regular_enemies then
			--log("i hate this")
			return self._values.preferred_spawn_groups
		else
			for cat_name, team in pairs(tweak_data.group_ai.enemy_spawn_groups) do
				if cat_name ~= "Phalanx" then
					table.insert(opt, cat_name)
				end
			end
			
			return opt
		end
	else
		opt = {}
	
		for cat_name, team in pairs(tweak_data.group_ai.enemy_spawn_groups) do
			if dv_spawngroups[cat_name] then
				if cat_name ~= "Phalanx" then
					table.insert(opt, cat_name)
				end
			end
		end
	end
	
	return opt
end