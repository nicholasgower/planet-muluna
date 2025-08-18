if Muluna.rro.safe_get(settings.startup["disable-muluna-music"],{"value"}) == false then
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
    local tracks = {
        {
            track_type = "hero-track",
            sound = {
                filename = "Anthem",
                volume = 0.5
            }
        },
        {
            track_type = "interlude",
            sound = {
                filename = "Storm",
                volume = 0.5
            }
        },
        {
            track_type = "interlude",
            sound = {
                filename = "Muluna-33",
                volume = 0.5
            }
        },
        {
            track_type = "interlude",
            sound = {
                filename = "Handcrafted",
                volume = 0.5
            }
        },
        {
            
            sound = {
                filename = "Cryo-Lab",
                volume = 0.5
            }
        },
        {
            
            sound = {
                filename = "Eclipse",
                volume = 0.5
            }
        },
        {
            sound = {
                filename = "Factory-FourFour",
                volume = 0.5
            }
        },
        {
            sound = {
                filename = "01010213",
                volume = 0.5
            }
        },
    }
    for _,track in pairs(tracks) do
        track = Muluna.rro.merge({
            name = "muluna-music-" .. track.sound.filename,
            type = "ambient-sound",
            planet = "muluna",
            
        },track)
        if not track.track_type then track.track_type = "main-track" end
        if track.track_type ~= "hero-track" then track.weight = 10 end
        track.sound.filename = "__muluna-graphics__/sound/music-fluidnatalie/" .. track.sound.filename
        if track.track_type == "interlude" then track.sound.filename = track.sound.filename .. "-interlude" end
        track.sound.filename = track.sound.filename .. ".ogg"
        data:extend{track}
    end
end

PlanetsLib.borrow_music("space-platform", data.raw["planet"]["muluna"],
    {track_types = {"main-track"},
    modifier_function = function(track) track.weight = track.weight / 32 end})
