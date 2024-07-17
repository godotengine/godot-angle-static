#!/bin/bash

# The need for the custom steps has been found empirically, by multiple build attempts.
# The commands to run and their arguments have been obtained from the various Meson build scripts.
# Some can (or even must) be run locally at the Mesa repo, then resulting files are copied.
# Others, due to the sheer size of the generated files, are instead run at the Godot build system;
# this script will only copy the needed scripts and data files from Mesa.

check_error() {
    if [ $? -ne 0 ]; then echo "Error!" && exit 1; fi
}

run_custom_steps_at_source() {
    run_step() {
        local P_SCRIPT_PLUS_ARGS=$1
        local P_REDIR_TARGET=$2

        echo "Custom step: $P_SCRIPT_PLUS_ARGS"

        local OUTDIR=$GODOT_DIR/godot-angle/
        mkdir -p $OUTDIR
        check_error
        pushd ./angle > /dev/null
        check_error
        eval "local COMMAND=\"$P_SCRIPT_PLUS_ARGS\""
        if [ ! -z "$P_REDIR_TARGET" ]; then
            eval "TARGET=\"$P_REDIR_TARGET\""
            python3 $COMMAND > $TARGET
        else
            python3 $COMMAND
        fi
        check_error
        popd > /dev/null
        check_error
    }

    run_step 'src/commit_id.py gen $OUTDIR/angle_commit.h'
    run_step 'src/program_serialize_data_version.py $OUTDIR/ANGLEShaderProgramVersion.h ../file_list'
}

GODOT_DIR=$(pwd)

if [ -d ./godot-angle ]; then
    echo "Clearing godot-angle/"
    find ./godot-angle -mindepth 1 -type d | xargs rm -rf
fi

run_custom_steps_at_source

if [ -d ./godot-patches ]; then
    echo "Applying patches"
    find ./godot-patches -name '*.diff' -exec git apply {} \;
fi
