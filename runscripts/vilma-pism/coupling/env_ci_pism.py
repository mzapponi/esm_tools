def prepare_environment(config):
    environment_dict = {
            "TEST_IN_ENV": "testvar_in_env_exported_couple_in_pism",
            "SOLID_EARTH_TO_PISM": 1,
            "COUPLE_DIR": config["general"]["experiment_couple_dir"],
            #"SOLIDEARTH_grid": from names file,
            #"bedrock_change_name": from names file
            #"RUN_NUMBER_solidearth": from names file,
            "ice_bedrock_change_file": (
                config["general"]["experiment_couple_dir"] +
                "/bedrock_change.nc"
                ),
            "RESTART_DIR_pism": config["pism"]["experiment_restart_in_dir"],

            }

    print(environment_dict)
    return environment_dict





