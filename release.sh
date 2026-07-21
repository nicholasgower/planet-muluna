#!/bin/bash

dir=$(dirname "$scriptpath")
cd "$dir" || exit


git archive --prefix=planet-muluna_2.2.102/ -o planet-muluna_2.2.102.zip HEAD
