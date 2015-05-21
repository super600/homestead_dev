#!/bin/bash

HOMESTEAD_CLI_VER=2.0.8

# Utils
function get_link {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		echo "$(readlink $*)"
	else
		echo "$(readlink -f $*)"
	fi
}

# Get Paths
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REAL_SOURCE_PATH=$DIR/$(basename ${BASH_SOURCE[0]})
if [ -L ${BASH_SOURCE[0]} ]; then
	REAL_SOURCE_PATH="$(get_link ${BASH_SOURCE[0]})"
	DIR="$( cd "$( dirname "$REAL_SOURCE_PATH" )" && pwd )"
fi

function homestead_path {
	if [ -n ${HOME+1} ]; then
		echo $HOME/.homestead
	else
		echo ${HOMEDRIVE}${HOMEPATH}/.homestead
	fi
}

THE_VAGRANT_DOTFILE_PATH=$(homestead_path)/.vagrant
export VAGRANT_DOTFILE_PATH=$THE_VAGRANT_DOTFILE_PATH

# Init variables
verbose=0
cli_install_path=/usr/local/bin/homestead
homestead_default_provider=virtualbox
homestead_config=$(homestead_path)/Homestead.yaml

# Load config
if [ -f $DIR/.config ]; then
	source $DIR/.config
fi

# Handle Commands
function print_usage {
	echo -e "Usage: $0 [OPTIONS] COMMAND [arg...]"
	echo -e
	echo -e "Commands:"
	echo -e "  init\t\tCreate a stub Homestead.yaml file."
	echo -e "  edit\t\tEdit the Homestead.yaml file."
	echo -e "  status\tGet the status of the Homestead machine."
	echo -e "  up\t\tStart the Homestead machine."
	echo -e "  provision\t\tUpdate Homestead config."
	echo -e "  ssh\t\tLogin to the Homestead machine via SSH."
	echo -e "  run CMD\tRun commands through the Homestead machine via SSH."
	echo -e "  suspend\tSuspend the Homestead machine."
	echo -e "  resume\tResume the suspended Homestead machine."
	echo -e "  halt\t\tHalt the Homestead machine."
	echo -e "  destroy\tDestroy the Homestead machine."
	echo -e "  update\tUpdate the Homestead machine image."
	echo -e "  install\tInstall to $(dirname $cli_install_path)"
	echo -e "  uninstall\tRemove from $(dirname $cli_install_path)"
	echo -e "  version\tShow version information."
	echo -e "  help\t\tPrint this usage info."
	echo -e
	echo -e "Options:"
	echo -e "  run:"
	echo -e "\t--provision\tRun the provisioners on the box."
	echo -e
}

function exec_vagrant {
	(cd $DIR &&
		eval $@
	)
}

[ $# -eq 0 ] && {
	print_usage
	exit 1
}

OPTIND=1
homestead_cmd=$1
shift

# CLI Commands
case "$homestead_cmd" in
init)
	if [ -d $(homestead_path) ]; then
		echo "Homestead has already been initialized."
		exit 1
	fi
	mkdir $(homestead_path)
	cp $DIR/src/stubs/Homestead.yaml $homestead_config
	cp $DIR/src/stubs/aliases $(homestead_path)/aliases
	echo "Creating Homestead.yaml file... ✔"
	echo "Homestead.yaml file created at:"$homestead_config
	;;
edit)
	function executable {
		if [[ "$OSTYPE" == "linux-gnu" ]]; then
			echo 'vi'
		elif [[ "$OSTYPE" == "darwin"* ]]; then
			echo 'open'
		else
			echo "Unsupported platform: "$OSTYPE
			exit 1
		fi
	}
	$(executable) $homestead_config
	exit $?
	;;
status)
	exec_vagrant vagrant status
	;;
up)
	with_provision=""
	while [[ $# > 1 ]]; do
		key="$1"
		case $key in
		--provision)
			with_provision=" --provision"
			shift
			;;
		esac
		shift
	done
	exec_vagrant vagrant up --provider=$homestead_default_provider $with_provision
	;;
provision)
	exec_vagrant vagrant provision
	;;
ssh)
	exec_vagrant VAGRANT_DOTFILE_PATH=${THE_VAGRANT_DOTFILE_PATH} vagrant ssh
	;;
run)
	if [ ! -z '$@' ]; then
		exec_vagrant VAGRANT_DOTFILE_PATH=${THE_VAGRANT_DOTFILE_PATH} vagrant ssh -c \"$@\"
	else
		echo "Usage: $0 run <SSH COMMAND HERE!>"
		exit 1
	fi
	;;
suspend)
	exec_vagrant vagrant suspend
	;;
resume)
	exec_vagrant vagrant resume
	;;
halt)
	exec_vagrant vagrant halt
	;;
destroy)
	destroy_force=false
	while getopts "f" opt; do
		case "$opt" in
		f)
			destroy_force=true
		;;
		esac
	done
	shift $((OPTIND-1))
	exec_vagrant vagrant destroy $([ "$destroy_force" == true ] && echo --force)
	;;
update)
	exec_vagrant vagrant box update
	;;
install)
	if [ -e $cli_install_path ]; then
		rm -rf $cli_install_path
	fi
	ln -sf "$REAL_SOURCE_PATH" $cli_install_path
	chmod a+x $cli_install_path
	echo "Homestead Bash CLI Installed! (link: ${cli_install_path})"

	if [ ! -e /usr/local/etc/bash_completion ]; then
		echo 'Optional:'
		echo '  Bash auto completion for Homestead Bash CLI.'
		echo '  Please install bash-completion first.'
		echo '     > brew install bash-completion'
	fi
	if [ ! -e $HOME/.bash_completion.d ]; then
		mkdir $HOME/.bash_completion.d
	fi
	if [ -d $HOME/.bash_completion.d ] && [ ! -L $HOME/.bash_completion.d ]; then
		ln -s $DIR/scripts/homestead_bash_completion $HOME/.bash_completion.d/homestead_bash
	fi
	if [ -e $HOME/.bash_completion.d/homestead_bash ]; then
		echo 'Homestead Bash Completion Installed! (link: ~/.bash_completion.d/homestead_bash)'
	fi
	;;
uninstall)
	if [ -e $cli_install_path  ]; then
		rm -rf $cli_install_path
	fi
	echo 'Homestead Bash CLI Uninstalled!'
	if [ ! -L $HOME/.bash_completion.d ]; then
		if [ -e $HOME/.bash_completion.d/homestead_bash ]; then
			rm -rf $HOME/.bash_completion.d/homestead_bash
			echo 'Homestead Bash Completion Uninstalled!'
		fi
	fi
	;;
update)
	exec_vagrant vagrant box update
	;;
version)
	echo -e "Homestead Bash CLI "$HOMESTEAD_CLI_VER
	echo -e " - Eric Shieh <me@ericshieh.com>"
	echo
	echo -e "vagrant box:"
	vagrant box list|grep homestead
	;;
help|list)
	print_usage
	exit 0
	;;
*)
	echo "Unknown command: "$homestead_cmd
	echo
	print_usage
	exit 1
	;;
esac


exit 0
