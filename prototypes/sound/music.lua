if settings.startup["disable-muluna-music"].value == false then
    -- data:extend{
    --     {
    --     name = "muluna-sandy-boys-beth-cohens",
    --     type = "ambient-sound",
    --     track_type = "main-track",
    --     planet = "muluna",
    --     sound = {
    --         filename = "__muluna-graphics__/sound/music/1 - Sandy Boys Beth Cohen's [aiqbWEikr4w].ogg",
    --         volume = 0.5,
    --     }
    -- }
    -- }  
end

PlanetsLib.borrow_music("space-platform", data.raw["planet"]["muluna"])

