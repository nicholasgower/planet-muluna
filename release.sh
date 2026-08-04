#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_2.2.105/ -o planet-muluna_2.2.105.zip HEAD
