#!/bin/bash

# Packages must be listed in dependency order and must be submodules
# in the "packages" directory of this git repo
packages=("nlmixr2data" "lotri" "rxode2" "nlmixr2est" "nlmixr2plot" "nlmixr2extra" "nlmixr2")

base_clone_url="git@github.com:nlmixr2/"
# for testthat
NOT_CRAN="true"

# Update everything
git submodule update --recursive --remote
git commit -am "submodules updated"

# Remove the old results and prepare for the new
git rm outputs/*txt
mkdir -p outputs

for current_dir in ${packages[@]}; do
  echo Starting $current_dir
  (
    cd packages/$current_dir
    # Clean up old files
    git clean -d -x -f
    # The 2>&1 redirects stderr to stdout
    # The tee copies stdout to a file and stdout
    R -e "devtools::install_local(force=TRUE)" 2>&1 | \
	tee ../../outputs/${current_dir}_install.txt
    if [[ $? -ne 0 ]] ; then
      echo Error installing ${current_dir}
      break
    fi
    if [ -d tests/testthat ]; then
      # The 2>&1 redirects stderr to stdout
      # The tee copies stdout to a file and stdout
      R -e "devtools::load_all();devtools::test()" 2>&1 | \
	tee ../../outputs/${current_dir}_test.txt
      if [[ $? -ne 0 ]] ; then
        echo Crash while testing ${current_dir}
        echo Try R -g gdb then r at the prompt
        break
      fi
    else
      echo "No test directory found (tests/testthat)"
    fi
  )
  echo Completed $current_dir
done

# Push the updates:
git add outputs/*txt
#git commit -m "Testing update on $(date --iso-8601)"
#git push
