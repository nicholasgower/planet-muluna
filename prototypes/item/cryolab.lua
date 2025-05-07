if data.raw["lab"]["biolab"] then
    local cryolab=table.deepcopy(data.raw["item"]["biolab"])

    cryolab.name="cryolab"
    cryolab.place_result= "cryolab"

    cryolab.icons = {
        {
            icon="__muluna-graphics__/graphics/photometric-lab/photometric-lab-icon.png",
            icon_size=64,
            scale=0.25,
            --tint = {r=0.7,g=0.7,b=1}
        },
        
    }
    cryolab.default_import_location = "muluna"
    data:extend{cryolab}
end
