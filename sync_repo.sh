#!/bin/bash
PROGNAME=$(basename $0)
VERSION="0.1"
BLU="\033[1;34m"
RED="\033[1;31m"
NRM="\033[0m"

export DBGFLAG=0   # 0 = normal execution, non-0 = Debug

function log()
{
    if test $DBGFLAG -eq 0; then
        echo -e "EXECUTING: ${*}"
        echo -e "${BLU}${*}${NRM}"
    else
        echo -e "Debug Selection: ${BLU}${*}${NRM}"
    fi

    return $DBGFLAG
}
function show_progress()
{
    echo -e "${BLU}${*}${NRM}"
}

function error()
{
	echo -e "${RED}${*}${NRM}"
}

function exit_error()
{
        echo "${PROGNAME}: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

function usage()
{
cat <<-EOM
Usage: `basename $0`

OPTIONS:
 -a,  --auto            Autmatically proceeds without user input. Will delete target directory
 -ur, --urepo           Upstream repo name   (from)
 -dr, --drepo           Downstream repo name (to)(defaults same as upstream)
 -sp,  --source-project Source Project name in Github public or IBM (openbmc) 
 -tp,  --target-project Target Project name in Github public or IBM (openbmc)
 -b,  --branch          set repo branch in target (default 920.10)
 -up, --upstream-url    upstream url (from github.com or github.ibm.com)
 -dn, --downstream-url  downstream url (to github.com or github.ibm.com)
 -bp, --base-path       location where clones will be created (default /esw/san5/<user name>)
 -ud, --update-repo     if exists update / refresh downstream target repo 
 -c,  --curl-config     <path>/<curl_config> file example: /esw/san5/`whoami`/curl_config_ibm
 -h,  --help            Display help/usage statement

examples: 
#`basename $0` -p openbmc 

EOM
}

#----------- MAIN -------------------------
AUTO="";
SKIP_CLONE="";
UPSTREAM_REPO_NAME="";
DOWNSTREAM_REPO_NAME="";
UPDATE_DOWNSTREAM_REPO=0;
CURL_CONFIG=""
BRANCH=920.10
USER=`whoami`
BASE_PATH=/esw/san5/$USER


if  test -f $BASE_PATH/sync_repo.cfg ; then
    . ${BASE_PATH}/sync_repo.cfg
fi


cd $BASE_PATH
show_progress "Location: $BASE_PATH"


while [ $# -gt 0 ]; do
	case $1 in
    -a | --auto )
			AUTO=1; shift;;
		-ur | --urepo )
			shift; UPSTREAM_REPO_NAME=$1; shift;;
    -dr | --drepo )
			shift; DOWNSTREAM_REPO_NAME=$1; shift;;
		-sp | --source-project )
			shift; S_PROJECT=$1; shift;;		
    -tp | --target-project )
			shift; T_PROJECT=$1; shift;;
		-b | --branch )
			shift; BRANCH=$1; shift;;
		-up | --upstream-url )
			shift; UPSTREAM_URL=$1; shift;;
		-dn | --downstream-url )
			shift; DOWNSTREAM_URL=$1; shift;;
    -bp | --base-path )      
			shift; 
      BASE_PATH=$1; shift;;
    -ud | --update-repo )
			shift; UPDATE_DOWNST/REAM_REPO=1; shift;;
    -c | --curl-config )
			shift; CURL_CONFIG=$1; shift;;
		-h | --help )
			usage;:
			exit 1;;
    *)
      error "Invalid option:$1"
      usage;:
      exit_error "Invalid option:$1"
	esac
done

if [ -z $BASE_PATH ] || [ ! -d $BASE_PATH ]; then
   error "Invalid path:[$BASE_PATH] Set using option -bp <path>"
   usage
   exit_error "ERROR EXECUTING: MAIN LINE:$LINENO"
fi

if [ -z $S_PROJECT ]; then
   error "source project is not set. Set using option -sp <project name>"
   usage
   exit_error "ERROR EXECUTING: MAIN LINE:$LINENO"
fi
if [ -z $T_PROJECT ]; then
   error "target project is not set. Set using option -tp <project name>"
   usage
   exit_error "ERROR EXECUTING: MAIN LINE:$LINENO"
fi

if [ -z $UPSTREAM_REPO_NAME ]; then
    error "upstream repo name is not set. Set using option -ur <repo name>"
    usage
    exit_error "ERROR EXECUTING: MAIN LINE:$LINENO"
fi
if [ -z $DOWNSTREAM_REPO_NAME ]; then
    DOWNSTREAM_REPO_NAME=$UPSTREAM_REPO_NAME
fi

show_progress "downstream repo: $DOWNSTREAM_REPO_NAME"

if [ -z $UPSTREAM_URL ]; then
    UPSTREAM_URL=github.com
    show_progress "Setting upstream to $UPSTREAM_URL"
fi
if [ -z $DOWNSTREAM_URL ]; then
    DOWNSTREAM_URL=github.ibm.com
    show_progress "Setting downstream to $DOWNSTREAM_URL"
fi 


DOWNSTREAM_CLONE_PROJECT_REPO="git@$DOWNSTREAM_URL:$T_PROJECT/$DOWNSTREAM_REPO_NAME"
UPSTREAM_CLONE_PROJECT_REPO="git@$UPSTREAM_URL:$S_PROJECT/$UPSTREAM_REPO_NAME"

show_progress "checking upstream existence of $UPSTREAM_CLONE_PROJECT_REPO"
git ls-remote  $UPSTREAM_CLONE_PROJECT_REPO &> /dev/null
if [ $? -ne 0 ]; then
    error "upstream repo $UPSTREAM_CLONE_PROJECT_REPO does not exists"
    exit_error "ERROR EXECUTING: MAIN LINE:$LINENO"
fi

show_progress "checking downstream existence of $DOWNSTREAM_CLONE_PROJECT_REPO"
git ls-remote $DOWNSTREAM_CLONE_PROJECT_REPO &> /dev/null
if [ $? -eq 0 ]; then
    show_progress "downstream repo $DOWNSTREAM_CLONE_PROJECT_REPO exists"
    if [ $UPDATE_DOWNSTREAM_REPO -eq 0 ]; then
        error "update option is off. Use option -ud to allow refresh"
        exit_error "ERROR EXECUTING: MAIN LINE:$LINENO"
    fi
    show_progress "update option is on. Refresh repo"
else
    show_progress "CREATING REMOTE REPO: $DOWNSTREAM_CLONE_PROJECT_REPO"
    curl -s -K $CURL_CONFIG -d "{\"name\":\"$DOWNSTREAM_REPO_NAME\"}" > /dev/null
fi

if [ -e $BASE_PATH/$DOWNSTREAM_REPO_NAME ]; then 
    error "local directory $BASE_PATH/$DOWNSTREAM_REPO_NAME exists. "
    error "ERROR EXECUTING: MAIN LINE:$LINENO"
        show_progress "AUTO=$AUTO"
        if [ $AUTO ]; then
                choice=$AUTO
        else
                echo -e "Hit c continue d delete and continue ;  All else exits: \c "
                read  choice
        fi
	if [ $choice = "d" ]; then
		rm -rf $BASE_PATH/$DOWNSTREAM_REPO_NAME
	elif [ $choice = "c" ]; then
		SKIP_CLONE=1;
    cd  $BASE_PATH/${DOWNSTREAM_REPO_NAME}
    show_progress "Location:  $BASE_PATH/${DOWNSTREAM_REPO_NAME}"
	else
    exit_error "$LINENO: You chose to exit, value selected: $choice"
	fi
fi

if [ ! $SKIP_CLONE ]; then
    mkdir $BASE_PATH/${DOWNSTREAM_REPO_NAME}

    if [ ! -e $BASE_PATH/$DOWNSTREAM_REPO_NAME ]; then
        error "$BASE_PATH/$DOWNSTREAM_REPO_NAME does not exist"
        error "ERROR EXECUTING: MAIN LINE:$LINENO"
    fi

    cd  $BASE_PATH/${DOWNSTREAM_REPO_NAME}
    show_progress "Location:  $BASE_PATH/${DOWNSTREAM_REPO_NAME}"
    git init
    git remote add downstream "$DOWNSTREAM_CLONE_PROJECT_REPO".git
    git status
fi

REMOTE_LIST=`git remote`
echo $REMOTE_LIST
echo `expr "$REMOTE_LIST" : '.*\(downstream\)'`

check_remote=`expr "$REMOTE_LIST" : '.*\(upstream\)'`
echo $check_remote
if [ -z $check_remote ]; then 
    git remote add upstream "$UPSTREAM_CLONE_PROJECT_REPO".git
fi
check_remote=`expr "$REMOTE_LIST" : '.*\(downstream\)'`
echo $check_remote
if [ -z $check_remote ]; then 
    git remote add upstream "$DOWNSTREAM_CLONE_PROJECT_REPO".git
fi

git fetch upstream
git merge upstream/master
git push -u downstream master









