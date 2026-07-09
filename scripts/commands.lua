-- Add command to start profiling
commands.add_command("muluna-profile", "Start recording profiler timings", function(command)
    debugadapter.start_profile()
    game.print("Profiler started")
end)

-- Add command to stop profiling
commands.add_command("muluna-stop-profile", "Stop recording profiler timings and save to script_output", function(command)
    debugadapter.stop_profile()
    game.print("Profiler stopped and saved")
end)