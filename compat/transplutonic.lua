if mods["transplutonic"] then
    local rro = require("lib.remove-replace-object")
    rro.replace_name(data.raw["recipe"]["interstellar-science-pack"].ingredients,"uranium-235","plutonium-239")
end
