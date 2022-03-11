#!/bin/bash

# Packages must be listed in dependency order
packages=("nlmixr2data" "lotri" "rxode2" "nlmixr2est" "nlmixr2plot" "nlmixr2extra" "nlmixr2")

base_clone_url="git@github.com:nlmixr2/"
# for testthat
NOT_CRAN="true"

for current_dir in ${packages[@]}; do
  echo Starting $current_dir
  if [ ! -d ${current_dir} ]; then
    clone_url="${base_clone_url}${current_dir}.git"
    git clone "${clone_url}"
  fi
  if [ ! -d ${current_dir} ]; then
    echo "${clone_url}"
    exit 1
  fi
  (
    cd $current_dir
    git checkout main
    git pull
    # Clean up old files
    git clean -d -x -f
    # The 2>&1 redirects stderr to stdout
    # The tee copies stdout to a file and stdout
    R -e "devtools::install_local(force=TRUE)" 2>&1 | \
	tee ../outputs/${current_dir}_install.txt
    if [[ $? -ne 0 ]] ; then
      echo Error installing ${current_dir}
      exit 1
    fi
    if [ -d tests/testthat ]; then
      # The 2>&1 redirects stderr to stdout
      # The tee copies stdout to a file and stdout
      R -e "devtools::load_all();devtools::test()" 2>&1 | \
	tee ../outputs/${current_dir}_test.txt
      if [[ $? -ne 0 ]] ; then
        echo Crash while testing ${current_dir}
        echo Try R -g gdb then r at the prompt
        exit 1
      fi
    else
      echo "No test directory found (tests/testthat)"
    fi
  )
  echo Completed $current_dir
done
