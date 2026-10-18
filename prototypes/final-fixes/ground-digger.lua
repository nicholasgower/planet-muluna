local rro = Muluna.rro

-- PlanetsLib generates the shared "<drill>-ground-digger" prototypes and assigns
-- muluna-regolith-digging when a digger is built on Muluna. The only Muluna-specific
-- data left to add is the "digging result" tooltip on each participating mining drill.
local config = PlanetsLib.constants.ground_diggers["muluna"]
for _, info in pairs(config and config.diggers or {}) do
    local drill = data.raw["mining-drill"][info.drill]
    if drill then
        drill.custom_tooltip_fields = drill.custom_tooltip_fields or {}
        rro.soft_insert(drill.custom_tooltip_fields, {
            name = {"tooltip.digging-result-drill-on-X", "[planet=muluna]"},
            value = "[item=muluna-lunar-regolith]",
        })
    end
end
