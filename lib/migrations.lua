-- Lua migration registry.
--
-- Factorio normally runs the files in `migrations/` when a save is loaded with
-- an older mod version (or when a mod is added to a save, which also happens
-- after the mod was removed and added back). Each file registers its body here
-- during `control.lua` parsing so the FUnit re-add test can replay the same
-- functions with an empty storage table. The engine's own run of the file only
-- calls the body when `game` is available.
--
-- Keep this list in sync with the `.lua` files in `migrations/`; the FUnit
-- re-add suite fails if a registered migration is missing.
local modules = {
  "1_39_thruster-fuel-techs",
  "1_40_fluid-voiding-tech",
  "aa_new_tech_tree",
  "add_telescopes_to_storage_telescopes_on_surface",
  "disable_wind",
  "enable-interstellar-science-tech",
  "existing_save",
  "fix-burner-roboport-connections",
  "fix-players_walking_on_muluna-inconsistency",
  "fix_broken_telescopes",
  "fluid-barreling",
  "ground-digger-recipe",
  "lunar_rock",
  "muluna-2-resources_",
  "muluna-2",
  "muluna-steam-crusher-tech",
  "nav-beacon-2",
  "nav-beacon",
  "new_cliffs",
  "new_cliffs_autoplace",
  "new_resources",
  "new_resources_bz",
  "new_resources_cupric",
  "new_resources_uranium",
  "no-rocks-fix",
  "water-saving-wood-cultivation",
}

for _, name in ipairs(modules) do
  require("migrations." .. name)
end

Muluna.migration_order = modules

return modules
