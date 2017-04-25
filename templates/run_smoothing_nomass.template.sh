#!/bin/bash

# created by matthias.mengel@pik-potsdam.de

# get user and platform-specific variables like working_dir, pismcodedir,
# pism_exec and mpi command
source set_environment.sh

runname=`echo $PWD | awk -F/ '{print $NF}'`
codever=`echo $PWD | awk -F/ '{print $NF}' | awk -F_ '{print $1}'`
thisdir=`echo $PWD`
outdir=$working_dir/$runname
PISM_EXEC=$pism_exec

# get new pism code if fetch is argument
if [ "$1" = "fetch" ]
  then
  rsync -aCv $pismcode_dir/$codever/bin/pismr $outdir/bin/
  cd $pismcode_dir/$codever
  echo ------ `date` --- $RUNNAME ------                  >> $thisdir/log/versionInfo
  echo "commit $(git log --pretty=oneline --max-count=1)" >> $thisdir/log/versionInfo
  echo "branch $( git branch | grep \*)"                  >> $thisdir/log/versionInfo
  cd $thisdir
fi

NN=2  # default number of processors
if [ $# -gt 0 ] ; then  # if user says "exp.sh 8" then NN = 8
  NN="$1"
fi

###### use only MPI if job is submitted
if [ -n "${PISM_ON_CLUSTER:+1}" ]; then  # check if env var is set
  echo "This run was submitted, use MPI"
  PISM_MPIDO=$pism_mpi_do
else
  echo "This is interactive, skip use of MPI"
  PISM_MPIDO=""
  NN=""
fi

echo "PISM_MPIDO = $PISM_MPIDO"
PISM_DO="$PISM_MPIDO $NN $PISM_EXEC"

infile=$input_data_dir/{{input_file}}
atmfile=$infile
oceanfile=$input_data_dir/{{ocean_file}}
grid="{{grid}}"

######## SMOOTHING ########

###### output settings
start_year=100000
end_year=100200
extratm=0:10:1000000
timestm=0:1:1000000
snapstm=0:100:1000000
extra_opts="-extra_file extra -extra_split -extra_times $extratm -extra_vars {{extra_variables}}"
ts_opts="-ts_times $timestm -ts_vars {{timeseries_variables}} -ts_file timeseries_smoothing.nc"
snaps_opts="-save_file snapshots -save_times $snapstm -save_split -save_size medium"
output_opts="$extra_opts $snaps_opts $ts_opts"

###### boundary conditions
atm_opts="-surface simple -atmosphere given -atmosphere_given_file $infile"
ocean_opts="-ocean pik -meltfactor_pik 5e-3"
calv_opts="-calving ocean_kill -ocean_kill_file $infile"
bed_opts="-bed_def none -hydrology null"
subgl_opts="-subgl -no_subgl_basal_melt"

###### ice physics
basal_opts="-yield_stress mohr_coulomb -topg_to_phi 5,15,-1000,1000"
stress_opts="-stress_balance sia -sia_flow_law gpbld -sia_e {{ep['sia_e']}}"

###### technical
init_opts="-bootstrap -i $infile $grid -config my_pism_config.nc"
## netcdf4_parallel needs compilation with -DPism_USE_PARALLEL_NETCDF4=YES
run_opts="-ys $start_year -ye $end_year -pik -o smoothing.nc"

options="$init_opts $run_opts $atm_opts $ocean_opts $calv_opts $bed_opts $subgl_opts \
         $basal_opts $stress_opts $output_opts"

echo "### Smoothing options: ###"
echo $PISM_DO $options
cd $outdir
$PISM_DO $options

######## NO MASS ########

infile=smoothing.nc

end_year=200000
extratm=0:2000:1000000
timestm=0:100:1000000
snapstm=0:2000:1000000
extra_opts="-extra_file extra -extra_split -extra_times $extratm -extra_vars {{extra_variables}}"
ts_opts="-ts_times $timestm -ts_vars {{timeseries_variables}} -ts_file timeseries_no_mass.nc"
snaps_opts="-save_file snapshots -save_times $snapstm -save_split -save_size medium"
output_opts="$extra_opts $snaps_opts $ts_opts"


###### ice physics
stress_opts="-no_mass"

###### technical
init_opts="-i $infile -config my_pism_config.nc"
## netcdf4_parallel needs compilation with -DPism_USE_PARALLEL_NETCDF4=YES
run_opts="-ye $end_year -o_format netcdf4_parallel -pik -o no_mass.nc"

options="$init_opts $run_opts $atm_opts $ocean_opts $calv_opts $bed_opts $subgl_opts \
         $basal_opts $stress_opts $output_opts"

echo "### No-mass options: ###"
echo $PISM_DO $options
cd $outdir
$PISM_DO $options
