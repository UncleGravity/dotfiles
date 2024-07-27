local function entry(st)
	if st.old then
		-- Restore the old layout and preview settings
		Tab.layout, st.old = st.old, nil
		ya.app_emit("preview_config", {
			max_width = 600,
			max_height = 900,
		})
	else
		st.old = Tab.layout
		Tab.layout = function(self)
			self._chunks = ui.Layout()
				:direction(ui.Layout.HORIZONTAL)
				:constraints({
					ui.Constraint.Percentage(0),
					ui.Constraint.Percentage(0),
					ui.Constraint.Percentage(100),
				})
				:split(self._area)
		end
		-- Change the preview settings to full width
		ya.app_emit("preview_config", {
			max_width = 1920,  -- Set to a large value to simulate full width
			max_height = 1080, -- Set to a large value to simulate full height
		})
	end
	ya.app_emit("resize", {})
end

return { entry = entry }