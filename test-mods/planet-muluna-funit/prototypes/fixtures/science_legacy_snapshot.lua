-- Frozen compatibility snapshot of the legacy progress technology list.
--
-- This copy must not be updated when LEGACY_PROGRESS_TECHNOLOGIES in
-- lib/exploration-science.lua changes. It records the technologies that the
-- algorithm was expected to keep declaring as exploration progress at the time
-- the dynamic discovery work landed.
local results = require("lib.results")

local SUITE = "science"

local LEGACY_PROGRESS_SNAPSHOT = {
  "electrochemical-science-pack",
  "cerysian-science-pack",
  "janus-time-science-pack",
  "slp-sunpack",
  "nanite-science-pack",
  "battlefield-science-pack",
  "compression-science-pack",
  "omnia-omnite-processing",
  "igrys-mineral-science",
  "rubia-progression-stage1B",
  "quantum-science-pack",
  "ring-science-pack",
  "anomaly-science-pack",
  "tiberium-mechanical-research",
  "moshine-tech-ai-trainer",
  "pelagos-science-pack",
  "carnal-science-pack",
  "foliax-welcome",
  "arboric-science-pack",
  "planetaris-compression-science",
  "athletic-science-pack",
  "linox-technology_linox-supercomputer",
  "lead-and-gold-tech",
  "s6x-void-science-pack",
  "apicultural-science-pack",
  "vanadium-science-pack",
  "planet-crucible-science-pack",
  "planetaris-bioengineering-science-pack",
  "velora-science-pack",
  "halo-science-pack",
  "abacayba_ominous_science_pack_tech",
  "environment-research-center",
  "s6x-iridescent-science-pack",
  "rabbasca-warpfield-science-pack",
  -- Appended conditionally when panglia_planet is installed.
  "cloning-vat-technology",
}

results.check(SUITE, "science-discovery-legacy-progress-snapshot", function()
  local mod_data = data.raw["mod-data"]["muluna-interstellar-science-pack-conditions"]
  assert(mod_data and mod_data.data, "interstellar conditions mod-data is missing")
  local conditions = mod_data.data

  local grouped = {}
  for _, group in ipairs(conditions.packs or {}) do
    for _, technology_name in ipairs(group.technologies or {}) do
      grouped[technology_name] = true
    end
  end

  for _, technology_name in ipairs(LEGACY_PROGRESS_SNAPSHOT) do
    if data.raw["technology"][technology_name] then
      assert(
        grouped[technology_name],
        "existing legacy progress technology is not declared exploration progress: " .. technology_name
      )
    end
  end
end)
