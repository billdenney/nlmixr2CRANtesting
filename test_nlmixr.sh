#!/bin/bash

# Parse command line arguments (from https://unix.stackexchange.com/questions/129391/passing-named-arguments-to-shell-scripts)
while [ $# -gt 0 ]; do
  case "$1" in
    --valgrind=*)
      valgrind="${1#*=}"
      ;;
    --help=*)
      help="${1#*=}"
      ;;
    *)
      printf "****************************************\n"
      printf "* Error: Invalid argument.  Try --help *\n"
      printf "****************************************\n"
      exit 1
  esac
  shift
done

# Packages must be listed in dependency order and must be submodules
# in the "packages" directory of this git repo
packages=("dparser-R"
          "nlmixr2data" "lotri" \
          "rxode2parse"
          "nonmem2rx"
          "rxode2random" "rxode2et" "rxode2ll" "rxode2" \
          "nlmixr2est" "nlmixr2plot" "nlmixr2extra" "nlmixr2")

base_clone_url="git@github.com:nlmixr2/"
# for testthat
NOT_CRAN="true"

# Remove the old results and prepare for the new
git rm -f outputs/*txt
rm -fv outputs/*txt
mkdir -p outputs
mkdir -p packages

# Setup the testing reporter to show everything
reporter_setup="\
testthat::ProgressReporter$new(\
 show_praise=FALSE,\
 min_time=Inf,\
 update_interval=0,\
 verbose_skips=TRUE,\
 max_failures=Inf\
)"

# Install packages required for testing
R -e "install.packages('devtools');install.packages('tidyverse');install.packages('pkgdown')"

# Test everything
for current_dir in ${packages[@]}; do
  echo Starting $current_dir
  (
    cd packages
    if [ ! -d ${current_dir} ]; then
      clone_url="${base_clone_url}${current_dir}.git"
      git clone "${clone_url}"
    fi
    if [ ! -d ${current_dir} ]; then
      echo Failed cloning "${clone_url}"
      break
    fi
    cd $current_dir
    git fetch --all
    git reset --hard origin/main
    # Clean up old files
    git clean -d -x -f
    # The 2>&1 redirects stderr to stdout
    # The tee copies stdout to a file and stdout
    if [ -z ${valgrind+x} ]; then
      echo "Not using valgrind"
      R -e "devtools::install_local(force=TRUE)" 2>&1 | \
        tee ../../outputs/${current_dir}_install.txt
    else
      echo "Using valgrind"
      # docker run --rm wch1/r-debug RDvalgrind -d "valgrind --tool=memcheck --leak-check=full" \
      R -d "valgrind --tool=memcheck --leak-check=full" \
          -e "devtools::install_local(force=TRUE)" 2>&1 | \
          tee ../../outputs/${current_dir}_install_valgrind.txt
    fi
    if [[ $? -ne 0 ]] ; then
      echo Error installing ${current_dir}
      break
    fi
    if [ -d tests/testthat ]; then
      # The 2>&1 redirects stderr to stdout
      # The tee copies stdout to a file and stdout
      #R -e "devtools::load_all();devtools::test(reporter=${reporter_setup})" 2>&1 | \
      if [ -z ${valgrind+x} ]; then
        echo "Not using valgrind"
        R -e "devtools::load_all();devtools::test()" 2>&1 | \
          tee ../../outputs/${current_dir}_test.txt
      else
          # docker run --rm wch1/r-debug RDvalgrind -d "valgrind --tool=memcheck --leak-check=full" \
          R -d "valgrind --tool=memcheck --leak-check=full" \
            -e "devtools::load_all();devtools::test()" 2>&1 | \
            tee ../../outputs/${current_dir}_test_valgrind.txt
      fi
      if [[ $? -ne 0 ]] ; then
        echo Crash while testing ${current_dir}
        echo Try R -d gdb then r at the prompt
        break
      fi
    else
      echo "No test directory found (tests/testthat)"
    fi
    if [ -f "_pkgdown.yml" ]; then
      # build the pkdgown site to test that it succeeds
      R -e "devtools::load_all();pkgdown::build_site()" 2>&1 | \
        tee ../../outputs/${current_dir}_pkgdown.txt
    else
      echo "No pkgdown site found"
    fi
  )
  echo Completed $current_dir
done

# Push the updates:
git add outputs/*txt
#git commit -m "Testing update on $(date --iso-8601)"
#git push
