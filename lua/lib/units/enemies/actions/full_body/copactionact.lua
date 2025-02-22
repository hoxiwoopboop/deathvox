CopActionAct._act_redirects.script = {
	"attached_collar_enter",
	"suppressed_reaction",
	"surprised",
	"hands_up",
	"hands_back",
	"tied",
	"stand_tied",
	"tied_all_in_one",
	"drop",
	"panic",
	"idle",
	"halt",
	"stand",
	"crouch",
	"revive",
	"untie",
	"arrest",
	"arrest_call",
	"gesture_stop",
	"sabotage_device_low",
	"sabotage_device_mid",
	"sabotage_device_high",
	"so_civ_dummy_act_loop",
	"dizzy",
	"cmd_get_up",
	"cmd_stop",
	"cmd_down",
	"cmd_gogo",
	"cmd_point"
}

local init_original = CopActionAct.init
function CopActionAct:init(action_desc, common_data)
	if action_desc.align_sync and action_desc.body_part ~= 1 then --no need to sync alignments for non-full body actions, causes teleporting for a frame anyway
		action_desc.align_sync = nil
	end

	return init_original(self, action_desc, common_data)
end
