#!/bin/bash
#################################################################
# 
#  File: ciao-install
#
#  Description
#  Script to assist users in downloading, installing and patching
#  ciao.
#  Version 1.4
# 
#  Copyright (C) 2012 Smithsonian Astrophysical Observatory
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#################################################################

# these variables will be configured by the web page

SEGMENTS="sherpa chips tools prism obsvis contrib CALDB_main "
SYS=""

# Global variables
# The DEF_* Variables are over-written with values found in
# the CIAOINSTALLRC file. If that file does not exist,
# the DEF_* values are used.

DEF_DL_DIR="`pwd`"       # Default Download Directory
DL_DIR=""                # Download Directory
CL_DL_DIR=""             # Set if directory given on command line
DEF_INS_DIR="${HOME}"    # Default Install Directory
INS_DIR=""               # Install Directory
CL_INS_DIR=""            # Set if directory given on command line
CALDB_DIR="CIAO"         # CALDB Directory
DEF_RUN_SMOKE="y"        # run smoke tests after install
RUN_SMOKE=""
DEF_SYS="NONE"           # Default system
SYSTEM=""                # System to install (Linux, Linux64, osxl64, osx64)
BATCH="n"                # Batch mode (No prompts)
SILENT="n"               # Silent mode (No output Implies BATCH=y)
CONTROL_FILE="ciao-control" # Control file name
CONTROL_LOCATION="ftp://cxc.harvard.edu/pub/ciao4.5/all"

CIAO_INSTALLED="ciao_installed" # installed file name
TMPDIR="/tmp"            # Directory to write tmp files
TMPNAME="tmp-ciao-install-$$" # name of temporary files
MYDATE="`date +%y-%m-%d.%H.%M.%S`"
LOGFILE_NAME="ciao-install-${MYDATE}.log"
WORKFILE="${TMPDIR}/${TMPNAME}"  # Workfile name
EXITFILE="${WORKFILE}-exit"
LOGDIR="`pwd`"           # Directory to write logfile in
LOGFILE="${LOGDIR}/${LOGFILE_NAME}" # Install log file
CIAOINSTALLRC="${HOME}/.ciaoinstall.rc"  # Name of user defaults file
FORCE_INSTALL="n"        # Install even if CIAO exists?
CONFIG_OPT=""            # extra configure options
DOWNLOAD_ONLY="n"        # Should we only download files?
INSTALL_ONLY="n"         # Should we only install local file?
NOCALDB="n"              # set to y if CALDB area exists but is not writable
VERSION_STRING="ciao-install v1.4"
FORCE_FTP="n"            # force the use of ftp for downloads?
DELETE_TAR="n"           # Delete tar files after install
DEF_DELETE_TAR="n"       # Initial default for deleting tar files.

MD5SUM=""                # Location of md5 sum tool
MD5TYPE=""               # do we have md5 or md5sum
GTAR=""                  # Location of GNU tar
GUNZIP=""                # Location of GNU unzip
STARTDIR="`pwd`"         # Location where script is run from
FTPVERB=""               # Keep ftp quiet
MFTPVERB="1>/dev/null 2>&1" # Keep ftp on Mac quiet
WGETVERB="-q"            # Keep wget quiet

UPDATE_DEF="n"           # Flag to test if default has changed

SYSERR="OK"
USED_FILES=""            # list of temp files opened by function
CIAO_DIR="ciao-4.5"      # Base of CIAO from control file
DL_LOC=""                # Download location (base web address)
RET=""                   # Generic function returns.

# variables to handle the CALDB patch

declare -a EQV_LIST      # <segment> # a b c ..
                         # If any of the files for <segment> are installed,
                         # use the PATCH file and not the FILE file.

# Exit Codes

OK=0                      # No error
DL_DIR_DOES_NOT_EXIST=2   # Invalid download directory
INS_DIR_DOES_NOT_EXIST=3  # Invalid install directory
UNKNOWN_ARGUMENT=4        # Invalid command line argument
UNKNOWN_VERSION=5         # Unknown Version
UNKNOWN_FILE=6            # Unknown file
CALDB_NOT_FOUND=7         # User specified a CALDB directory that does not exist
INSUFFICIENT_SPACE=8      # Not enough disk space

count_arg()
{
    \echo $#
}

printline()
{
    if [ -f ${LOGFILE} ] ; then
	\echo $* >> ${LOGFILE}
    fi

    # if running in silent mode never print

    if [ "${SILENT}" == "n" ] ; then
	while [ "$#" -ne 0 ] ; do
	    \echo -n ${1}
	    shift
	    if [ "$#" -ne 0 ] ; then
		\echo -n " "
	    fi
	done
	\echo
    fi
}

printerror()
{
    # Prints out error message (printline checks for silent mode)
    # and exits if in batch mode.

    printline "ERROR: ${1}"
    if [ "${BATCH}" == "y" ] ; then
	exit ${2}
    fi
}

retn()
{
    # Return the n'th argument

    let n=${1}
    shift
    while (( $n > 1 ))
    do
        let n=$n-1
        shift
    done
    echo "${1}"
}

retnp()
{

    # Return all remaining arguments starting from n

    let n=${1}
    shift
    while (( ${n} > 1 ))
    do
        let n=${n}-1
        shift
    done
    echo $@
}

remove_element()
{
    rem="${1}"
    shift
    while [ "$#" -ne 0 ] ; do
	if [ "${1}" != "${rem}" ] ; then
	    \echo -n "${1}"
	    shift
	    if [ "$#" -ne 0 ] ; then
		\echo -n " "
	    fi
	fi
    done
    \echo
}

callexit()
{
    \rm -f ${EXITFILE}
    echo ${1} > ${EXITFILE}
    exit ${1}
}

ci_reset()
{
    while [ "$#" -ne 0 ] ; do
	\rm -f ${1}
	\touch ${1}
	if [ "x${USED_FILES}" != "x" ] ; then
	    USED_FILES="${USED_FILES} ${1}"
	else
	    USED_FILES="${1}"
	fi
	shift
    done
}

rmall()
{
    # remove all temp work files

    while [ "$#" -ne 0 ] ; do
	\rm -f ${1}
	shift
    done
    USED_FILES=""
}     

check_file()
{
    if [ -f "${1}/${2}" ] ; then
	if [ "${MD5SUM}" != "x" ] ; then
	    if [ "x${3}" != "x" ] && [ "x${3}" != "x0" ] ; then
		printline "Verifying file ${1}/${2}"
		check=`${MD5SUM} "${1}/${2}"`

                # md5 and md5sum have different outputs
		
		if [ "${MD5TYPE}" != "md5sum" ] ; then
		    let ipos=4
		else
		    let ipos=1
		fi
		check="`retn ${ipos} ${check}`"
		if [ "x${check}" != "x${3}" ] ; then
		    ret="FAIL"
		    \rm -f "${EXITFILE}"
		    \echo ${UNKNOWN_FILE} > ${EXITFILE}
		    printerror "md5sum mismatched ${check} vs ${3}" 1
		else
		    ret="OK"
		fi
	    else
		ret="OK"
	    fi
	else
	    ret="OK"
	fi
    else
	ret="FAIL"
	\rm -f "${EXITFILE}"
	\echo ${UNKNOWN_FILE} > ${EXITFILE}
	printerror "Unable to download ${2}" 1
    fi
    RET=${ret}
}

check_space()
{

    # check to see if we have enough disk space to perform the operation

    ret=0
    \cd "${1}"

    # to make sure we always get the correct format from df use the
    # -P (posix) switch. If the version of df does not understand -P
    # fall back to just -k
    space="`\df -P -k .`"
    if (( $? )) ; then
	space="`\df -k .`"
    fi
    let ispace="`retn 11 ${space}`"
    let nspace=${2}
    if (( ${ispace} < ${nspace} )) ; then
	printerror "Not enough space on ${1}. Requires: ${2} KB Space available: ${ispace} KB" ${INSUFFICIENT_SPACE}
	\rm -f ${EXITFILE}
	\echo ${INSUFFICIENT_SPACE} > "${EXITFILE}"
	exit ${INSUFFICIENT_SPACE}
    fi
    RET=${ret}
}

get_file()
{
    if [ "${INSTALL_ONLY}" != "y" ] ; then
	\cd "${DL_DIR}"
	if [ "x${4}" != "x" ] ; then
	    check_space "${DL_DIR}" "${4}"
	    if [ "${RET}" != "0" ] ; then
		exit ${RET}
	    fi
	fi
	
        # compute the size of the download
	
	if [ "x${4}" != "x" ] &&  [ "x${4}" != "x0" ] ; then
	    let size=${4}
	    if (( ${size} < 1000 )) ; then
		sizemsg=" (${4} Kb)"
	    elif (( ${size} < 1000000 )) ; then
		let r=${size}%1000
		let size=(${size}-${r})/1000 
		if (( ${r} > 499 )) ; then
		    let size=${size}+1
		fi
		sizemsg=" (${size} Mb)"
	    else
		let r=${size}%1000000
		let size=(${size}-${r})/1000000 
		if (( ${r} > 499999 )) ; then
		    let size=${size}+1
		fi
		sizemsg=" (${size} Gb)"	
	    fi
	else
	    sizemsg=""
	fi
	printline "Downloading file ${2}${sizemsg} to ${DL_DIR}"
	case  "${OSTYPE}" in 
	    darwin* | Darwin* )
		realsys="OSX" ;;
	    * )
		realsys="other" ;;
	esac

        # first try to download via wget

	if [ "${INSTALL_ONLY}" != "y" ] ; then
	    ret="OK"
	    if [ "${WGET}" != "x" ] && [ "${realsys}" != "OSX" ] ; then
		${WGET} "${WGETVERB}" "${1}/${2}"
		if [ ! -f "${2}" ] ; then
		    export WGETVERB="${WGETVERB} --no-passive-ftp"
		    ${WGET} "${WGETVERB}" "${1}/${2}"
		    if [ ! -f "${2}" ] ; then
			printerror "Unable to retrieve ${1}/${2}" 1
			ret="n"
		    fi
		fi
            # next try ftp
		
	    elif [ "${FTP}" != "x" ] ; then
		if [ "${realsys}" != "other" ] ; then
		    netrc="${WORKFILE}-netrc"
		    \echo "default" > ${netrc}
		    \echo "macdef" >> ${netrc}
		    \echo "init" >> ${netrc}
		    \echo "epsv4 off" >> ${netrc}
		    \echo "" >> ${netrc}
		    if [ "x${MFTPVERB}" != "x" ] ; then
			${FTP} -N ${netrc} -a ${1}/${2} 1>/dev/null 2>&1
		    else
			${FTP} -N ${netrc} -a ${1}/${2}
		    fi
		    if [ ! -f "${2}" ] ; then
			printerror "Unable to retrieve ${1}/${2}" 1
			ret="n"
		    fi
		    \rm -f ${netrc}
		else
		    ftpline="`echo ${1} | sed 'y-/- -'`"
		    ftpsys="`retn 2 ${ftpline}`"
		    Dir=""
		    let i=3
		    s="`retn $i ${ftpline}`"
		    while [ "x${s}" != "x" ]
		    do
			if [ "x${Dir}" != "x" ] ; then
			    Dir="${Dir}/${s}"
			else
			    Dir="${s}"
			fi
			i=${i}+1
			s="`retn ${i} ${ftpline}`"
			\rm -rf ${WORKFILE}-ftp
			\echo ${Dir} > ${WORKFILE}-ftp
		    done 
		    Dir="`cat ${WORKFILE}-ftp`"
		    \rm -rf ${WORKFILE}-ftp
		    File="`basename ${2}`"
		    ftpcmd="${WORKFILE}-ftp-commands"
		    \rm -f ${ftpcmd}
		    if [ "x${FTPVERB}" == "x-v" ] ; then
			\echo "verbose" >> ${ftpcmd}
			\echo "trace" >> ${ftpcmd}
		    fi
		    \echo "open  ${ftpsys}" >> ${ftpcmd}
		    \echo "cd ${Dir}" >> ${ftpcmd}
		    \echo "binary" >> ${ftpcmd}
		    \echo "get ${File}" >> ${ftpcmd}
		    \echo "bye" >> ${ftpcmd}
		    cipid="$$-${MYDATE}"
		    if [ -f "${HOME}/.netrc" ] ; then
			printline "Backing up ${HOME}/.netrc to ${HOME}/.netrc.ciao-install.${cipid}"
			\mv -f "${HOME}/.netrc" ${HOME}/.netrc.ciao-install.${cipid}
		    fi
		    \echo "machine ${ftpsys}" > "${HOME}/.netrc"
		    \echo "login    anonymous" >> "${HOME}/.netrc"
		    \echo "password ciao-install@cfa.harvard.edu" >> "${HOME}/.netrc"
		    ${FTP} < ${ftpcmd}
		    \rm -f "${HOME}/.netrc"
		    if [ -f "${HOME}/.netrc.ciao-install.${cipid}" ] ; then
			\mv "${HOME}/.netrc.ciao-install.${cipid}" "${HOME}/.netrc"
		    fi
		    \rm -f ${ftpcmd}
		    if [ ! -f "${2}" ] ; then
			printerror "Unable to retrieve ${1}/${2}" 1
			ret="n"
		    fi
		fi
	    else
		printerror "ftp and wget are unavailable. Unable to download." 1
		ret="n"
	    fi
	    check_file "${DL_DIR}" "${2}" "${3}"
	    retcf=${RET}
	    if [ "${retcf}" != "OK" ] ; then
		printerror "Bad Download. Please try again. If the problem continues please contact the CXC helpdesk.(cxchelp@head.cfa.harvard.edu)" ${UNKNOWN_FILE}
		callexit ${UNKNOWN_FILE}
	    fi
	else
	    ret="n"
	fi
    else
	printerror "${DL_DIR}/${2} is missing. Please download." ${UNKNOWN_FILE}
	callexit ${UNKNOWN_FILE}
    fi
    RET="${ret}"
}

get_input()
{

    # get user input. Use readline to make things nice (-e)

    read -e -p "${1}: " INPUT dummy
    \echo ${INPUT}
}

get_defaults()
{
    \rm -f ${WORKFILE}
    if [ -f "${CIAOINSTALLRC}" ] ; then
        # Remember bash shells out loops so we need to store
        # the results when a match is found.
	\cat "${CIAOINSTALLRC}" |
	while read var def dummy
	do
            if [ "x${var}" != "x" ] && \
		[ "x`\echo ${var} | grep ^#`" == "x" ] && \
		[ "x${def}" != "x" ] ; then
		if [ "${var}" == "${1}" ] ; then
                    \echo ${def} > ${WORKFILE}
		fi
            fi
	done

	if [ -f ${WORKFILE} ] ; then
            RCRET=`cat ${WORKFILE}`
            \rm -f ${WORKFILE}
	else
            RCRET="NONE"
	fi
    else
	RCRET="NONE"
    fi
    \echo ${RCRET}
}

get_all_defaults()
{
    ret=`get_defaults DL_DIR`
    if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	DEF_DL_DIR="${ret}"
    fi

    # if $ASCDS_INSTALL is set use $ASCDS_INSTALL/.. 
    # instead of the default.

    if [ "x${ASCDS_INSTALL}" != "x" ] ; then
	DEF_INS_DIR="`dirname ${ASCDS_INSTALL}`"
    else
	ret=`get_defaults INS_DIR`
	if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	    DEF_INS_DIR="${ret}"
	fi
    fi
    ret=`get_defaults CALDB_DIR`
    if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	DEF_CALDB_DIR="${ret}"
    fi
    ret=`get_defaults RUN_SMOKE`
    if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	DEF_RUN_SMOKE="${ret:0:1}"
    fi
    ret=`get_defaults DELETE_TAR`
    if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	DEF_DELETE_TAR="${ret:0:1}"
    fi
}

test_missing()
{
    if [ "$#" == "1" ] ; then
	\echo "OK"
    else
	if [ "x${1}" == "xn" ] || [ "x${1}" == "xCommand" ] || [ "x${2}" == "xCommand" ] ; then
	    \echo "n"
	else
            # there must be spaces in the path name to get here.
	    \echo "y"
	fi
    fi
}

test_command()
{

    # Pull off the last line from the output of 'which' because
    # Solaris can put extra junk on the which line

    var="`which ${1} 2>/dev/null`"
    savIFS=${IFS}
    IFS=$'\n'
    arr=( ${var} )
    IFS=${savIFS}
    tlen=${#arr[@]}
    if (( $tlen > 0 )) ; then
	results="${arr[(${tlen}-1)]}"
    else
	results=""
    fi

    if [ "x${results}" != "x" ] && [ "`test_missing ${results}`" == "OK" ] ; then 
	\echo "${results}"
    else
	\echo "n"
    fi
}

no_per()
{
    if [ "x${3}" == "xmkdir" ] ; then
	printline "The ${2} directory ${1} not found."
	printline "If this directory is correct, then in another window, you need to do:"
	printline "> sudo mkdir -p ${1} ; chown ${USER} ${1}"
    elif [ "x${3}" == "xchown" ] ; then
	printline "The ${2} directory ${1} exists but is not writable."
	printline "To use this directory, please change its write permissions. (This"
	printline "may be accomplished by running:"
        printline "> sudo chown ${USER} ${1}"
	printline "either in another window or before running ciao install.)"
    else
	printline "Unable to create ${2} directory ${1}."
	printline "To use this directory, please create it and change its write permissions."
	printline "(This may be accomplished by running:"
	printline "> sudo mkdir -p ${1} ; chown ${USER} ${1}"
	printline "either in another window or before running ciao install.)"
    fi
    if [ "${BATCH}" != "n" ] ; then
	exit ${UNKONWN_FILE}
    fi
}

get_dir()
{
    ansok="n"
    if [ ${BATCH} != "y" ] ; then
	printline "Directory ${1} doesn't not exist."
	until [ "${ansok}" == "y" ] ; do
	    ansok="y"
	    ans=`get_input "(R)e-enter (C)reate or (E)xit?"`
	    case ${ans}
		in
		R* | r* ) ANS="r" ;;
		C* | c* ) ANS="c" ;;
		E* | e* ) exit 0 ;;
		* ) ansok=n ;;
	    esac
	done
	if [ "${ANS}" == "c" ] ; then
	    \mkdir -p "${1}" 1>/dev/null 2>&1
	    if [ ! -d "${1}" ] ; then
		no_per "${1}" "${2}" "nocreate"
		ANS="r"
	    fi
	fi
    else
	printerror "Directory ${1} doesn't not exist." ${UNKNOWN_FILE}
    fi
}

expand_dir()
{
    if [ -d "${1}" ] ; then
	savepwd="`pwd`"
	cd "${1}"
	\echo "`pwd`"
	cd "${savepwd}"
    else
	\echo "${1}"
    fi
}

verify_tools()
{

    # see if we have GNU tar as tar

    istar=`test_command tar`

    if [ "x`${istar} --version 2>&1 | grep GNU`" != "x" ] || [ "x`${istar} --version 2>&1 | grep bsdtar`" != "x" ] ; then
	tarok="y"
    else
	tarok="n"
    fi

    if [ "${istar}" != "n" ] && [ "${tarok}" != "n" ] ; then
	    GTAR="${istar} xf"
    else
        # maybe GNU tar is called gtar
	
	isgtar=`test_command gtar`
	
	if [ "${isgtar}" != "n" ] && [ "x`${isgtar} --version 2>&1 | grep GNU`" != "x" ] ; then
	    GTAR="${isgtar} xf"
	elif [ "${istar}" != "n" ] ; then
	    printline "Warning: GNU tar NOT Found! Some smoke tests will fail with Sun tar"
	    printline "Also some files in the CALDB may not expand to their correct name."
	    GTAR="${istar} xf"
	else
	    printerror "gtar or tar not found!" ${UNKNOWN_FILE}
	    exit ${UNKNOWN_FILE}
	fi
    fi

    # see if we have gunzip
    
    isgzip=`test_command gunzip`
    if [ "${isgzip}" != "n" ] ; then
	GUNZIP="${isgzip} -c"
    elif [ "`test_command gzip`" != "n" ] ; then
        # if gzip exists use it with the -d option
	isgzip=`test_command gzip`
	GUNZIP="${isgzip} -d -c"
    else
        # we need gzip
	printerror "gzip not found!" ${UNKNOWN_FILE}
	exit ${UNKNOWN_FILE}
    fi
    
    # see if we have md5sum
    
    ismd5sum="`test_command md5sum`"
    if [ "${ismd5sum}" != "n" ] ; then
	MD5SUM="${ismd5sum}"
	MD5TYPE="md5sum"
    else
	
        # On solaris the command is md5
	
	ismd5sum="`test_command md5`"
	if [ "${ismd5sum}" != "n" ] ; then
	    MD5SUM="${ismd5sum}"
	    MD5TYPE="md5"
	else	
	    MD5SUM="x"
	    ND5TYPE="x"
	    printline "Warning md5sum NOT found. File verification will NOT be done."
	fi
    fi
    
    # see if we have ftp
    
    isftp="`test_command ftp`"
    if [ "${isftp}" != "n" ] ; then
	FTP="${isftp}"
    else
	FTP="x"
    fi
    
    # see if we have wget

    if [ "${FORCE_FTP}" != "y"  ] ; then
	iswget="`test_command wget`"
	if [ "${iswget}" != "n" ] ; then
	    WGET="${iswget}"
	else
	    WGET="x"
	fi
    else
	iswget="n"
	WGET="x"
    fi
    if [ "${WGET}" == "x" ] && [ "${FTP}" == "x" ] && [ "${INSTALL_ONLY}" != "y" ] ; then
	printerror "ftp or wget required for downloads" 1
	exit 1
    fi
}

get_download_area()
{
    # Over-ride default if command line switch used
    
    CL_DL_DIR="`\echo ${CL_DL_DIR}`"
    if [ "x${CL_DL_DIR}" != "x" ] ; then
	if [ "x${CL_DL_DIR}" != "x${DEF_DL_DIR}" ] ; then
	    UPDATE_DEF="y"
	    DEF_DL_DIR="${CL_DL_DIR}"
	fi
    fi
    
    # Prompt user if not in batch mode
    
    if [ "${BATCH}" != "y" ] ; then
	if [ "x${CL_DL_DIR}" == "x" ] ; then
	    if [ "${INSTALL_ONLY}" != "y" ] ; then
		prompt="Download directory for tar files (${DEF_DL_DIR})"
	    else
		prompt="Location of downloaded tar files (${DEF_DL_DIR})"
	    fi
	    DL_DIR=`get_input "${prompt}"`
	else
	    DL_DIR="${CL_DL_DIR}"
	fi
	if [ "${DL_DIR}" == "." ] || [ "${DL_DIR}" == "./" ] ; then
	    DL_DIR="`pwd`"
	fi
    else
	DL_DIR="${DEF_DL_DIR}"
    fi
    
    # this is to expand any use of ~
    
    DL_DIR="`\echo ${DL_DIR}`"
    
    # reset CL_DL_DIR in case input switch is invalid
    
    CL_DL_DIR=""
    
    # If a null string is entered, use default.
    
    if [ "x${DL_DIR}" == "x" ] ; then
	DL_DIR="${DEF_DL_DIR}"
    else
	UPDATE_DEF="y"
    fi
    
    # Validate download directory

    if [ "`replace_space X ${DL_DIR}`" != "X${DL_DIR}X" ] ; then
	if [ "${BATCH}" != "y" ] ; then
	    printline "ERROR: You cannot download CIAO to a directory that contains spaces."
	    STEP="1"
	else
	    printerror "You cannot download CIAO to a directory that contains spaces."
	    exit ${UNKNOWN_FILE}
	fi
    else
	if [ -d "${DL_DIR}" ] ; then
	    if [ -w "${DL_DIR}" ] || [ "${INSTALL_ONLY}" == "y" ] ; then
		STEP="2"
	    else
                # exists but is not writable
		if [ "${BATCH}" != "y" ] ; then
		    no_per "${DL_DIR}" "Download" "chown"
		    STEP="1"
		else
		    printerror "The download directory ${DL_DIR} is not writable." ${DL_DIR_DOES_NOT_EXIST}
		    exit ${DL_DIR_DOES_NOT_EXIST}
		fi
	    fi
	else
	    if [ "${BATCH}" != "y" ] ; then
		get_dir "${DL_DIR}" "Download"
		if [ ${ANS} == "c" ] ; then
		    DL_DIR=`expand_dir "${DL_DIR}"`
		    STEP="2"
		else
		    STEP="1"
		fi
	    else
		mkdir -p "${DL_DIR}"
		if [ ! -d "${DL_DIR}" ] ; then
		    printerror "The download directory ${DL_DIR} not found." ${DL_DIR_DOES_NOT_EXIST}
		    exit ${DL_DIR_DOES_NOT_EXIST}
		else
		    STEP="2"
		fi
	    fi
	fi
    fi
}

get_install_area()
{
    # Over-ride default if command line switch is used

    CL_INS_DIR="`\echo ${CL_INS_DIR}`"
    if [ "${DOWNLOAD_ONLY}" != "y" ] ; then
	if [ "x${CL_INS_DIR}" != "x" ] ; then
	    if [ "x${CL_INS_DIR}" != "x${DEF_INS_DIR}" ] ; then
		UPDATE_DEF="y"
		DEF_INS_DIR="${CL_INS_DIR}"
	    fi
	fi
	
        # Prompt user if not in batch mode
	
	if [ "${BATCH}" != "y" ] ; then
	    if [ "x${CL_INS_DIR}" == "x" ] ; then
		prompt="CIAO installation directory (${DEF_INS_DIR})"
		INS_DIR=`get_input "${prompt}"`
	    else
		INS_DIR=${CL_INS_DIR}
	    fi
	    if [ "${INS_DIR}" == "." ] || [ "${INS_DIR}" == "./" ] ; then
		INS_DIR="`pwd`"
	    fi
	else
	    INS_DIR="${DEF_INS_DIR}"
	fi
	
        # this is to expand any use of ~ or ../

	INS_DIR=`expand_dir "${INS_DIR}"`

        # reset CL_INS_DIR in case input is invalid
	
	CL_INS_DIR=""
	
        # If a null string is entered, use default.
	
	if [ "x${INS_DIR}" == "x" ] ; then
	    INS_DIR="${DEF_INS_DIR}"
	else
	    UPDATE_DEF="y"
	fi
	
        # Validate install directory

        # check if there is a space in the name
	if [ "`replace_space X ${INS_DIR}`" != "X${INS_DIR}X" ] ; then
	    if [ "${BATCH}" != "y" ] ; then
		printline "ERROR: You cannot install CIAO to a directory that contains spaces."
		STEP="3"
	    else
		printerror "You cannot install CIAO to a directory that contains spaces." ${INS_DIR_DOES_NOT_EXIST}
		exit ${INS_DIR_DOES_NOT_EXIST}
	    fi
	else
	    if [ -d "${INS_DIR}" ] ; then
		
                # does the ciao-4.x directory exist?
	    
		if [ -d "${INS_DIR}/${CIAO_DIR}" ] ; then
		    
                    # Yes it does now can we write in it?
		    
		    if [ -w "${INS_DIR}/${CIAO_DIR}" ] ; then
                        # good to go!
			STEP="4"
		    else
                        # We need write permission
			no_per  "${INS_DIR}/${CIAO_DIR}" "Installation" "chown"
			STEP="3"   # go back to step 3
		    fi
		else
		
                    # This is a new install of CIAO can we create the directory?
		
		    \mkdir -p "${INS_DIR}/${CIAO_DIR}" 1>/dev/null 2>&1
		    if [ -d "${INS_DIR}/${CIAO_DIR}" ] ; then
			
                        # good to go!
	
			STEP="4"
		    else
			no_per "${INS_DIR}/${CIAO_DIR}" "Installation" "mkdir"
			STEP="3"
		    fi
		fi #  if [ -d "${INS_DIR}/${CIAO_DIR}" ]
	    else
		if [ "${BATCH}" != "y" ] ; then
		    get_dir "${INS_DIR}" "Installation"
		    if [ ${ANS} == "c" ] ; then
			INS_DIR=`expand_dir "${INS_DIR}"`
			STEP="4"
		    else
			STEP="3"
		    fi
		else
		    mkdir -p "${INS_DIR}"
		    if [ ! -d "${INS_DIR}" ] ; then
			printerror "Cannot create ${INS_DIR}" ${INS_DIR_DOES_NOT_EXIST}
			exit ${INS_DIR_DOES_NOT_EXIST}
		    else
			STEP="4"
		    fi
		fi
	    fi # if [ -d "${INS_DIR}" ]
	fi # if [ "`replace_space X ${INS_DIR}`" != "${INS_DIR}" ]
    else
	STEP=4
    fi
}

run_smoke_tests()
{
    if [ "${BATCH}" == "n" ] && [ "${DOWNLOAD_ONLY}" != "y" ] && [ "${SYSERR}" == "OK" ] ; then
	ans=`get_input "Run smoke tests? (y|n) (${DEF_RUN_SMOKE:0:1})"`
	if [ "x${ans}" == "x" ] ; then
	    RUN_SMOKE="${DEF_RUN_SMOKE}"
	    STEP="5"
	else
	    UPDATE_DEF="y"
	    case ${ans} in
		y* | Y* ) RUN_SMOKE="y"
		    STEP="5" ;;
		n* | N* ) RUN_SMOKE="n"
		    STEP="5" ;;
		* ) STEP="4" ;;
	    esac
	fi
    else
	RUN_SMOKE="n"
	STEP="5"
    fi
}

delete_tar_files()
{
    if [ "${BATCH}" == "n" ] && [ "${DOWNLOAD_ONLY}" != "y" ] && [ "${SYSERR}" == "OK" ] && [ "${DELETE_TAR}" != "y" ] ; then
	ans=`get_input "Delete tar files after install? (y|n) (${DEF_DELETE_TAR:0:1})"`
	if [ "x${ans}" == "x" ] ; then
	    DELETE_TAR="${DEF_DELETE_TAR}"
	    STEP="6"
	else
	    UPDATE_DEF="y"
	    case ${ans} in
		y* | Y* ) DELETE_TAR="y"
		    STEP="6" ;;
		n* | N* ) DELETE_TAR="n"
		    STEP="6" ;;
		* ) STEP="5" ;;
	    esac
	fi
    else
	DELETE_TAR="${DEF_DELETE_TAR}"
	STEP="6"
    fi
}

replace_space()
{

# replaces empty space with ${1}

    char=${1}
    \echo -n "${char}"
    shift
    while [ "$#" -ne 0 ] ; do
	\echo -n ${1}
	shift
	\echo -n "${char}"
    done
    \echo
}

read_version()
{

    # get the versions of installed files
    
    \rm -f "${WORKFILE}"
    touch "${WORKFILE}"
    if [ -f "${INS_DIR}/${CIAO_DIR}/${INSTALLED_FILE}" ] ; then
	\cat "${INS_DIR}/${CIAO_DIR}/${INSTALLED_FILE}" |
	while read file_name dummy
	do
	    if [ "x${file_name}" != "x" ] ; then
		\echo "${file_name} " >> "${WORKFILE}"
	    fi
	done
    fi
    INSTALLED_LIST="`cat ${WORKFILE}`"
    \rm -f "${WORKFILE}"
}

build_dep()
{
    # build dependency list

    \rm -f "${WORKFILE}-bd"
    \echo "${SEGMENTS}" > "${WORKFILE}-bd"
    tmpseg="`replace_space X ${SEGMENTS}`"
    while [ "$#" -ne 0 ] ; do
	if [ "${1}" == "-" ] ; then
	    break
	else
            # add in segments not already there

	    if [ "x`\echo ${tmpseg} | grep X${1}X`" == "x" ] ; then
		SEGMENTS="${SEGMENTS} ${1}"
		tmpseg="${tmpseg}${1} "
		rm -f  "${WORKFILE}-bd"
		\echo "${SEGMENTS}" > "${WORKFILE}-bd"
	    fi
	fi
	shift
    done
    SEGMENTS="`cat ${WORKFILE}-bd`"
    \rm -f "${WORKFILE}-bd"
    \echo "${SEGMENTS}"
}

read_control()
{

    # get the latest control file

    \cd "${DL_DIR}"
    if [ "${INSTALL_ONLY}" != "y" ] ; then
	if [ -f "${CONTROL_FILE}" ] ; then
	    \mv -f "${CONTROL_FILE}" "${CONTROL_FILE}.bak"
	fi
	get_file "${CONTROL_LOCATION}" "${CONTROL_FILE}" "0" "1"
	ret=${RET}
	if [ "${ret}" != "OK" ] ; then
	    if [ -f "${CONTROL_FILE}.bak" ] ; then
		printline "Cannot download ${CONTROL_FILE}. Using existing file."
		\mv -f "${CONTROL_FILE}.bak" "${CONTROL_FILE}"
	    else
		printerror "Cannot download control file ${CONTROL_FILE}" ${UNKNOWN_ARGUMENT}
		exit ${UNKNOWN_ARGUMENT}
	    fi
	fi
    else
	if [ ! -f "${CONTROL_FILE}" ] ; then
	    printerror "CIAO control file ${DL_DIR}/${CONTROL_FILE} is missing. Cannot install." ${UNKNOWN_ARGUMENT}
	    exit ${UNKNOWN_ARGUMENT}
	fi
    fi

    # Read the control file to see whats available
    
    wfbase="${WORKFILE}-BASE"
    ci_reset ${wfbase} ${newseg}
    
    if [ -f "${DL_DIR}/${CONTROL_FILE}" ] ; then
	var=`cat "${DL_DIR}/${CONTROL_FILE}"`
	savIFS=${IFS}
	IFS=$'\n'
	arr=( ${var} )
	IFS=${savIFS}
	tlen=${#arr[@]}
	n=0;
	tmpsubset=""
	subsetlen=-1;
	while [ ${n} -lt ${tlen} ] ; do
	    tag="`retn 1 ${arr[$n]}`"

            # the second argument is always used so to save processing
            # it is assigned it's own variable.
	    v1="`retn 2 ${arr[$n]}`"

            # only process non-blank non-comment lines

	    if [ "x${tag}" != "x" ] && [ "x${tag}" != "x#" ] ; then
		case ${tag} in
		    BASE )
			\echo ${v1} >> ${wfbase}
			CIAO_DIR="${v1}"
			export CIAO_DIR
                        # See if we are installing over a different system

			if [ -f "${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}" ] ; then
			    coretest="`grep bin-core ${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}`"
			    if [ "x${coretest}" != "x" ] ; then
				teststr="core-${SYS}.tar"
				if [ "x`echo ${coretest} | grep core-${SYS}.tar`" == "x" ] ; then
				    printerror "Trying to install system ${SYS} when `retn 2 ${coretest}` is already installed." 1
				    exit 1
				fi
			    fi
			fi			
			;;
		    VERSION )
			if [ "`retnp 2 ${arr[$n]}`" != "${VERSION_STRING}" ] ; then
			    ver_num="`retnp 3 ${arr[$n]}`"
			    printline "+++ NOTICE: a newer version of ciao-install is available (${ver_num}) +++"
			    printline "       You are using ${VERSION_STRING}"
			fi
			;;
		    VALID )
			if [ "${v1}" != "-" ] ; then
			    VALID_SEG="${VALID_SEG} `retnp 2 ${arr[$n]}`"
			else
                            # Validate segments in SEGMENTS variable
			    vset_X="`replace_space X ${VALID_SEG}`"
			    let m=1;
			    while [ "x`retn ${m} ${SEGMENTS}`" != "x" ] ; do
				Xseg="X`retn ${m} ${SEGMENTS}`X"
				test_seg="`\echo ${vset_X} | grep ${Xseg}`"
				if [ "x${test_seg}" == "x" ] ; then
				    printerror "Segment `retn ${m} ${SEGMENTS}` is not valid." 1
				    exit 1
				fi
				let m=${m}+1;
			    done
			fi
			;;
		    DL )
			dlarea="${v1}"
			;;
		    DEP )

                        # build dependency list

			seg_X="`replace_space X ${SEGMENTS}`"
			if [ "${v1}" != "-" ] ; then
			    if [ "x`\echo ${seg_X} | grep X${v1}X`" != "x" ] ; then
				seg_string="`retnp 2 ${arr[$n]}`"
				seg="`build_dep ${seg_string}`"
				SEGMENTS="${seg}"
			    fi
			else
			    if [[ ${subsetlen} -ne -1 ]] ; then
				let i=0;
				while [ ${i} -lt ${subsetlen} ] ; do
                                    # if both files in the subset exist in SEGMENTS
                                    # remove the first
				    sub1="`retn 1 ${subsetarr[${i}]}`"
				    sub2="`retn 2 ${subsetarr[${i}]}`"
				    if [ "x`\echo ${seg_X} | grep X${seg1}X`" != "x" ] && [ "x`\echo ${seg_X} | grep X${seg2}X`" != "x" ] ; then
					SEGMENTS="`remove_element ${sub1} ${SEGMENTS}`"
				    fi
				    let i=${i}+1;
				done
			    fi
			fi
			;;
		    SYS )
			if [ "x`retn 2 ${arr[$n]}`" == "xall" ] ; then
			    lsys="${SYS}"
			else
			    lsys="${v1}"
			fi
			;;
		    SEG )
			if [ "x${lsys}" == "x${SYS}" ] ; then
			    if [ "x`\echo ${seg_X} | grep X${v1}X`" != "x" ] ; then
				getseg="${v1}"
			    else
				getseg="n"
			    fi
			fi
			;;
		    SUBSET )
                        # Segment 2 is a subset of segment 1
			if [ "${v1}" != "-" ] ; then
			    v2="`retn 3 ${arr[$n]}`"
			    tmpsubset="${tmpsubset}${v1} ${v2}$'\n'"
			else
			    savIFS="${IFS}"
			    IFS=$'\n'
			    subsetarr=( ${tmpsubset} )
			    IFS="${savIFS}"
			    subsetlen=${#subsetarr[@]}
			fi
			;;
		    FILE )
			if [ "x${lsys}" == "x${SYS}" ] && [ "${getseg}" != "n" ] ; then
			    case "${getseg}" in
				CALDB* )
				    if [ "${NOCALDB}" != "y" ] ; then
                                        if [ "${CALDB_DIR}" != "CIAO" ] && [ "${CALDB_DIR}" != "${INS_DIR}/${CIAO_DIR}/CALDB" ] ; then
                                            if [ ! -e "${INS_DIR}/${CIAO_DIR}/CALDB" ] ; then
                                                ln -s "${CALDB_DIR}" "${INS_DIR}/${CIAO_DIR}/CALDB"
                                            fi
                                        fi
					ins="${INS_DIR}/${CIAO_DIR}/CALDB"
					if [  "${getseg}" == "CALDB_main" ] ; then
					    CHECKCAL="y"
					fi
					eqv="`check_eqv ${getseg}`"
					if [ "${eqv}" == "FILE" ] || [ "${eqv}" == "n" ] ; then
					    install_file "${dlarea}" "${ins}" "`retn 2 ${arr[$n]}`" "`retn 3 ${arr[$n]}`" "`retn 4 ${arr[$n]}`" "`retn 5 ${arr[$n]}`"
					elif [ "${eqv}" == "y" ] ; then
					    printline "File CALDB main already installed ${ins}"
					fi
				    else
					printline "Omitting install of CALDB file ${v1}"
				    fi
				    ;;
				* )
				    ins="${INS_DIR}"
				    install_file "${dlarea}" "${ins}" "`retn 2 ${arr[$n]}`" "`retn 3 ${arr[$n]}`" "`retn 4 ${arr[$n]}`" "`retn 5 ${arr[$n]}`"
				    ;;
			    esac
			fi
			;;
		    PATCH )
			if [ "x${lsys}" == "x${SYS}" ] && [ "${getseg}" != "n" ] ; then
			    eqv="`check_eqv ${getseg}`"
			    if [ "${eqv}" == "PATCH" ] ; then
				if [ "${CALDB_DIR}" == "CIAO" ] ; then
				    cdb="${CIAO_DIR}/CALDB"
				else
				    cdb="${CALDB_DIR}"
				fi
				install_patch "${dlarea}" "`retn 2 ${arr[$n]}`" "`retn 3 ${arr[$n]}`" "`retn 4 ${arr[$n]}`" "`retn 5 ${arr[$n]}`" "${cdb}"
			    elif [ "${eqv}" == "n" ] ; then
				install_patch "${dlarea}" "`retn 2 ${arr[$n]}`" "`retn 3 ${arr[$n]}`" "`retn 4 ${arr[$n]}`" "`retn 5 ${arr[$n]}`"
			    fi
			fi
			;;
		    EQV )
                       # read in what installed files qualify for downloading the patch
                       # This should be generalized someday so multiple EQV statements
                       # can be used.

			EQV_LIST=(`retnp 2 ${arr[$n]}`)
			;;
		    CKLIB )
                        # some segments require libraries that may or may not exist on some
                        # systems (for example chips requires libGL. While we can expect that
                        # on the Macs, not all Linux systems have it installed by default.

			if [ "${DOWNLOAD_ONLY}" != "y" ] ; then
			    ckseg="`retn 2 ${arr[$n]}`"
			    tmpseg="`replace_space X ${SEGMENTS}`"
			    if [ "x`\echo ${tmpseg} | grep X${ckseg}X`" != "x" ] ; then
				baselib="`retn 3 ${arr[$n]}`"
				libver="`retn 4 ${arr[$n]}`"
				if [ "x${libver}" != "x" ] && [ "x${libver}" != "x-" ] ; then
				    libver=".${libver}"
				else
				    libver=""
				fi
				case ${SYS}
				    in
				    osx* ) cklib="${baselib}${libver}.dylib" ;;
				    * ) cklib="${baselib}.so${libver}" ;;
				esac
				found="n"
				if [ "`test_command ldconfig`" != "n" ] ; then
				    if [ "x`ldconfig -p 2>/dev/null | grep ${cklib} 2>/dev/null`" != "x" ] ; then
					found="y"
				    fi
				elif [ "`test_command locate`" != "n" ] ; then
				    if [ "x`locate ${cklib} 2>/dev/null | grep ${cklib} 2>/dev/null`" != "x" ] ; then
					found="y"
				    fi
				fi
				if [ "${found}" == "n" ] ; then
				    if [ "${SYS}" == "Linux64" ] ; then
					Lib="lib64"
				    else
					Lib="lib"
				    fi
                                    # check some standard places. I am not happy with this as I would
                                    # rather look at the system load path instead of guessing.
				    if [ -f "/usr/${Lib}/${cklib}" ] || \
					[ -f "/${Lib}/${cklib}" ] || \
					[ -f "/usr/X11/${Lib}/${cklib}" ] || \
					[ -f "/usr/X11R6/${Lib}/${cklib}" ] ; then
					found="y"
				    fi
				fi
				if [ "${found}" != "y" ] ; then
				    printline "Warning: You requested the segment ${ckseg} which requires ${cklib}"
				    printline "However I could not verify that it exists on your system. I can continue"
				    printline "with the installation but you may experience problems."
				    printline "Please contact the CXC help desk if you have any questions."
				    if [ ${BATCH} != "y" ] ; then
					result=`get_input "Should I continue? (y\n) (y)"`
					case ${result}
					    in
					    n* | N* )
						exit 1 ;;
					    * ) printline "Continuing";;
					esac
				    fi
				fi
			    fi
			fi
			;;
		    * )
			printline "Unimplemented tag ${tag} found in control file"
			printline "Your copy of ciao-install may be old."
			;;
		esac
	    fi
	    let n=${n}+1;
       done
    fi
    CIAO_DIR="`\cat ${wfbase}`"
    rmall ${USED_FILES}
}

write_defaults()
{
    if [ "x${INS_DIR}" == "x" ] ; then
	ret=`get_defaults INS_DIR`
	if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	    INS_DIR="${ret}"
	fi
    fi
    if [ "x${CALDB_DIR}" == "x" ] ; then
	ret=`get_defaults CALDB_DIR`
	if [ "x${ret}" != "x" ] && [ "x${ret}" != "xNONE" ] ; then
	    CALDB_DIR="${ret}"
	fi
    fi
    \rm -f "${CIAOINSTALLRC}"
    \echo "# This is a generated file. Do not edit." > "${CIAOINSTALLRC}"
    \echo "# Download directory" >> "${CIAOINSTALLRC}"
    \echo "DL_DIR ${DL_DIR}" >> "${CIAOINSTALLRC}"
    \echo "# Install directory" >> "${CIAOINSTALLRC}"
    \echo "INS_DIR ${INS_DIR}" >> "${CIAOINSTALLRC}"
    \echo "# CALDB directory" >> "${CIAOINSTALLRC}"
    \echo "CALDB_DIR ${CALDB_DIR}" >> "${CIAOINSTALLRC}"
    \echo "# Run Smoke tests upon completion?" >> "${CIAOINSTALLRC}"
    \echo "RUN_SMOKE ${RUN_SMOKE}" >> "${CIAOINSTALLRC}"
    \echo "# Delete download tar files after update?" >> "${CIAOINSTALLRC}"
    \echo "DELETE_TAR ${DELETE_TAR}" >> "${CIAOINSTALLRC}"
    \sync
}

update_defaults()
{
    if [ "${BATCH}" == "n" ] && [ "${UPDATE_DEF}" == "y" ] ; then
	ans=`get_input "Save these settings? (y|n) (y)"`
	if [ "x${ans}" == "x" ] ; then
	    write_defaults
	    STEP="done"
	else
	    case ${ans} in
		y* ) write_defaults
		    STEP="done" ;;
		Y* ) write_defaults
		    STEP="done" ;;
		n* ) STEP="done" ;;
		N* ) STEP="done" ;;
		* ) STEP="6" ;;
	    esac
	fi
    else
	STEP="done"
    fi
}

get_user_input()
{

    # here is the processing loop. This will allow users to go back to 
    # previous prompt if needed.

    STEP="1"
    while [ "${STEP}" != "DONE" ] ; do
	case ${STEP} in
	    0 ) exit ${OK} ;;
	    1 ) get_download_area ;;
	    2 ) STEP="3" ;;
	    3 ) get_install_area ;;
	    4 ) run_smoke_tests ;;
	    5 ) delete_tar_files ;;
	    6 ) update_defaults ;;
            * ) STEP="DONE" ;;
	esac
    done
}

check_install()
{

    # Unless force install is set, read the installed-file file.

    \rm -f "${WORKFILE}-ci"
    \echo n >  "${WORKFILE}-ci"
    if [ "x${FORCE_INSTALL}" != "xy" ] ; then
	if [ -f "${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}" ] ; then
	    \cat "${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}" | 
	    while read ftype fname dummy
	    do
		if [ "x${fname}" == "x${2}" ] ; then
		    \rm -f  "${WORKFILE}-ci"
		    \echo y >  "${WORKFILE}-ci"
		    break
		fi
	    done
	fi
    fi
    ret=`\cat "${WORKFILE}-ci"`
    \rm -rf  "${WORKFILE}-ci"
    \echo "${ret}"
}

check_eqv()
{

    # check to see if we should apply the PATCH file or the FILE file.
    # This should be generalized someday so multiple EQV statements
    # can be used.

    # Return codes:
    # n - none of the files are installed
    # y - An equivalent file is installed
    # PATCH - The patch file is required
    # FILE - The full file is required

    if [ "${EQV_LIST[0]}" != "${1}" ] ; then
	\echo "n"
    elif [ "`check_install x ${EQV_LIST[1]}`" == "y" ] ; then
	\echo "y"
    elif [ "`check_install x ${EQV_LIST[2]}`" == "y" ] ; then
	\echo "y"
    else
	\rm -f "${WORKFILE}-eqv"
	let max=${EQV_LIST[3]}+4
	for (( i=4 ; i<${max} ; i++ )) ; do
	    if [ "`check_install x ${EQV_LIST[${i}]}`" == "y" ] ; then
		\touch  "${WORKFILE}-eqv"
	    fi
	done
	if [ -f "${WORKFILE}-eqv" ] ; then
	    echo "PATCH"
	    \rm -rf "${WORKFILE}-eqv"
	else
	    echo "FILE"
	fi
    fi
}


check_download()
{
    # does the file exist in the download directory
    # and is it complete?

    if [ -f "${DL_DIR}/${2}" ] ; then
	if [ "x${INSTALL_ONLY}" != "xy" ] ; then
	    check_file "${DL_DIR}" "${2}" "${3}"
	    if [ "${RET}" != "OK" ] || [ "x${3}" == "x" ] || [ "x${3}" == "x0" ] ; then
		printline "Removing bad file ${DL_DIR}/${2}"
		\rm -f ${EXITFILE}
		\rm -f "${DL_DIR}/${2}"
		ret="n"
	    else
		ret="y"
	    fi
	else
	    ret="y"
	fi
    else
	ret="n"
    fi
    RET=${ret}
}

install_file()
{
    # install a CIAO tar / contrib tar / CALDB tar file

    dlfile="${3}"

    # Don't bother checking if installed if we are only downloading.
    if [ "${DOWNLOAD_ONLY}" != "y" ] ; then
	result="`check_install ${1} ${dlfile} ${4} ${5}`"
    else
	result="n"
    fi
    if [ "${result}" == "n" ] ; then
	
        # do not install if file already installed
	
	check_download "${1}" "${dlfile}" "${4}" "${5}"
	resultcd="${RET}"

	do_install="n"
	if [ "${resultcd}" == "n" ] ; then

            # do not install if download only

	    get_file "${1}" "${dlfile}" "${4}" "${5}" "${6}"
	    resultgf="${RET}"
	    if [ "${resultgf}" == "OK" ] && [ "${DOWNLOAD_ONLY}" != "y" ] ; then
		do_install="y"
	    fi
	elif [ "${DOWNLOAD_ONLY}" != "y" ] ; then 
	    do_install="y"
	else
	    printline "File exists in download directory. Skipping"
	fi
	if [ "${do_install}" != "n" ] ; then
	    if [ ! -f "${DL_DIR}/${dlfile}" ] ; then
		printerror "Unable to download ${3}"
		exit 1
	    fi
	    if [ ! -d "${2}" ] ; then
		\mkdir -p "${2}"
	    fi
	    \cd "${2}"
	    
            # use proper decompress method

	    if [ "x${7}" != "x" ] ; then
		cd "${INS_DIR}/${7}"
		printline "Installing file ${DL_DIR}/${3} in ${7}"
		loc="${INS_DIR}/${7}"
	    else
		printline "Installing file ${DL_DIR}/${3} in ${2}"
		loc="${2}"
	    fi
	    if [ "x${6}" != "x" ] ; then
		check_space "${loc}" "${6}"
		if [ "${RET}" != "0" ] ; then
		    exit ${RET}
		fi
	    fi
	    case "${dlfile}" in
		*tar.gz )
		    ${GUNZIP} "${DL_DIR}/${dlfile}" | ${GTAR} -  2>> ${LOGFILE} ;;
		*.tgz )
		    ${GUNZIP} "${DL_DIR}/${dlfile}" | ${GTAR} -  2>> ${LOGFILE} ;;
		*.tar )
		    ${GTAR} "${DL_DIR}/${dlfile}" 2>> "${LOGFILE}" ;;
		* )
		    printerror "Unknown file type ${dlfile}" ${UNKNOWN_FILE} ;;
	    esac

            # should we clean up the tar files when done?
	    if [ "${DELETE_TAR}" == "y" ] ; then
		\rm -f "${DL_DIR}/${dlfile}"
	    fi

            # check to see if an update script is packaged with the file.

	    if [ -f "${INS_DIR}/${CIAO_DIR}/ciao_fix.sh" ] ; then
		\cd "${INS_DIR}/${CIAO_DIR}"
		./ciao_fix.sh
		\mv -f ciao_fix.sh ciao_fix.sh.${2}
	    fi

            # file processed write uniquely to installed file list.
	    if [ -f "${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}" ] ; then
		if [ "x`grep ${3} ${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}`" == "x" ] ; then
		    \echo "FILE ${dlfile}" >> "${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}"
		fi
	    else
		\echo "FILE ${dlfile}" > "${INS_DIR}/${CIAO_DIR}/${CIAO_INSTALLED}"
	    fi

            # See if we should delete tar files?

	    if [ "${DELETE_TAR}" == "y" ] ; then
		\rm -f "${DL_DIR}/${dlfile}"
	    fi
	fi
    else
	printline "File ${dlfile} already installed in ${2}"
    fi
 }

install_patch()
{
    # install a patch file

    # check to make sure an old patch script doesn't exist
    if [ -f "${INS_DIR}/${CIAO_DIR}/ciao_patch.sh" ] ; then
	\mv -f "${INS_DIR}/${CIAO_DIR}/ciao_patch.sh" "${INS_DIR}/${CIAO_DIR}/ciao_patch.sh.OLD"
    fi
    install_file "${1}" "${INS_DIR}" "${2}" "${3}" "${4}" "${5}" "${6}"

    # if all went well, we should have a patch script ready to go.
    # if there was an error, it would have been already reported.

    if [ -f "${INS_DIR}/${CIAO_DIR}/ciao_patch.sh" ] ; then
	\cd "${INS_DIR}/${CIAO_DIR}"
	ins_source=""
	if [ -d src ] ; then
	    ins_source="-b"
	fi
	./ciao_patch.sh  ${ins_source}
	name_str="`echo ${2} | sed 'y%-% %'`"
	patch_ver="`retn 2 ${name_str}`"
	\mv -f ciao_patch.sh ciao_patch.sh.ciao-${patch_ver}
	\mv -f ciao_cleanup.sh ciao_cleanup.sh.ciao-${patch_ver}
    fi
}

post_process()
{

    # first check to see if we need to make the CALDB link

    if [ "x${NOCALDB}" == "xy" ] ; then
	\rm -rf "${INS_DIR}/${CIAO_DIR}/CALDB"
	\cd "${INS_DIR}/${CIAO_DIR}"
	ln -s ${CALDB_DIR} CALDB
    fi

    # check if we need to chcon the libraries

    ischcon=`test_command chcon`
    if [ "${ischcon}" != "n" ] && [ "`uname -s`" == "Linux" ] ; then
	printline "running chcon to allow CIAO to work with SELinux"
	\cd "${INS_DIR}/${CIAO_DIR}"
	\chcon -R -t textrel_shlib_t * >> ${LOGFILE} 2>/dev/null
    fi
    
    # run configure
    
    printline "Running configure ./configure ${CONFIG_OPT}"

    # test to see if we have caldb4 source installed
    
    if [ -f src/libdev/caldb4/configure ] ; then
	PATH="`pwd`/ots/bin:${PATH}"
	PKG_CONFIG_PATH="`pwd`/ots/lib/pkgconfig"
	if [ -f src/config/fixpc.sh ] ; then
	    bash src/config/fixpc.sh "`pwd`"
	fi
    fi
    
    \cd "${INS_DIR}/${CIAO_DIR}"
    ./configure >> "${LOGFILE}" 2>&1
    
    # re-create the ahelp index
    
    . bin/ciao.bash -o >> "${LOGFILE}"
    if [ -f bin/ahelp ] ; then
	printline "Re-indexing ahelp system"
	ahelp -r 1>/dev/null
    fi
    
    # run python fix script
    
    if [ -f bin/ciao-python-fix ] ; then
	printline "Creating binary compiled python modules"
	bash bin/ciao-python-fix 1>/dev/null
    fi

    # If users have installed source, run the fixpc.sh script

    if [ -f src/config/fixpc.sh ] ; then
	printline "Fixing package config files."
	bash src/config/fixpc.sh 1>/dev/null 2>&1
    fi

    # if smoke tests are to be run do it now

    if [ "x${RUN_SMOKE}" == "xy" ] && [ -f bin/ahelp ] ; then
	printline "Running smoke tests"
	\cd test

	# Make sure the smoke directory is removed
	
	if [ -d "${ASCDS_TMP}/smoke.${USER}" ] ; then
	    \rm -rf "${ASCDS_TMP}/smoke.${USER}"
	fi

	# Make sure we have make
	ismake=`test_command make`
	if [ "${ismake}" != "n" ] ; then
	    ${ismake} -k | tee -a "${LOGFILE}"
	else
	    if [ -f "${ASCDS_WORK_PATH}/smoke.${LOGNAME}/smoketests.txt" ];
	    then
		\rm -f "${ASCDS_WORK_PATH}/smoke.${LOGNAME}/smoketests.txt"
	    fi
	    if [ ! -d "${ASCDS_WORK_PATH}/smoke.${LOGNAME}" ]; then
		\mkdir -p "${ASCDS_WORK_PATH}/smoke.${LOGNAME}"
	    fi
	    \ls "${INS_DIR}/${CIAO_DIR}"/test/smoke/bin/*-smoke*.sh > \
		"${ASCDS_WORK_PATH}/smoke.${LOGNAME}/smoketests.txt"
	    "${INS_DIR}/${CIAO_DIR}"/test/bin/run_smoke_test.sh | tee -a \
		"${LOGFILE}"
	fi
	\sync
	failures="`grep FAIL ${LOGFILE}`"
	if [ "x${failures}" != "x" ] ; then
	    printline " "
	else
	    printline "Smoke tests complete. All tests passed!"
	fi
    fi

    # re-run configure if other install options are passed

    if [ "x${CONFIG_OPT}" != "x" ] ; then
	\cd "${INS_DIR}/${CIAO_DIR}"
	\rm -rf  config.log config.cache config.status
	./configure ${CONFIG_OPT} >> ${LOGFILE} 2>&1
    fi

    # All done print log location
    
    printline "Processing complete!"
    printline "Script Log file is ${LOGFILE}"
    \cd "${STARTDIR}"
}

usage()
{
    \echo "${VERSION_STRING}"
    \echo 
    \echo "Usage: ${0} [options...]"
    \echo
    \echo "  -h --help Print this message"
    \echo "  --download-only Download only Do not install"
    \echo "  --install-only  Install only Do not download"
    \echo "  --download <dir> Download directory"
    \echo "  --prefix <dir> Install directory"
    \echo "  --logdir <dir> Log file directory"
    \echo "  --config <--with-top=dir> Extra configure switches"
    \echo "  --caldb <dir> Location of the CALDB"
    \echo "  --system <system> System to install"
    \echo "           (Linux, Linux64, osxl64, osx64)"
    \echo "  --batch Batch mode (no prompts)"
    \echo "  --silent Silent mode (implies batch) No tty output"
    \echo "  --delete-tar Delete tar files after install."
    \echo "  --add <segment> Add additional segment to CIAO"
    \echo "  -f --force Force re-install"
    \echo "  -v --version Report version and exit"
}

unsupport_sys()
{
    printline "Warning Unsupported system."
    if [ "INSTALL_ONLY" == "y" ] ; then
	printerror "Cannot install."
	exit 1
    fi
    if [ "DOWNLOAD_ONLY" != "y" ] ; then    
	printline "Downloading CIAO only, will not install."
	DOWNLOAD_ONLY="y"
    fi
}


# Get User command line options

\umask 022
CL="$0 $@"
while [ "$#" -ne 0 ]
do
    case "${1}" in
	--download-only | --download-onl | --download-on | --download-o | --download- )
	    DOWNLOAD_ONLY="y"
	    if [ "${INSTALL_ONLY}" != "n" ] ; then
		printerror "Conflicting switch with --download-only"
		exit ${UNKNOWN_ARGUMENT}
	    fi
	    if [ "x${FORCE_INSTALL}" == "xy" ] ; then
		printerror "-f or --force not compatible with --download-only"
		exit 1
	    fi ;;
	--install-only | --install-onl | --install-on | --install-o | --install- )
	    INSTALL_ONLY="y"
	    if [ "${DOWNLOAD_ONLY}" != "n" ] ; then
		printerror "Conflicting switch with --install-only"
		exit ${UNKNOWN_ARGUMENT}
	    fi ;;
	--download )

	    # Download directory (may be directory or link to directory)
	    
	    if [ "x${2}" != "x" ] ; then
		CL_DL_DIR="${2}"
		if [ "${CL_DL_DIR}" == "." ] || [ "${CL_DL_DIR}" == "./" ] ; then
		    CL_DL_DIR="${STARTDIR}"
		else

		    # get full directory name if the user selects a relative path

		    if [ -d "${CL_DL_DIR}" ] ; then
			cd "${CL_DL_DIR}"
			CL_DL_DIR="`pwd`"
			cd "${STARTDIR}"
		    else
			printerror "Download directory ${CL_DL_DIR} Does not exist!" ${DL_DIR_DOES_NOT_EXIST}
			exit ${DL_DIR_DOES_NOT_EXIST}
		    fi
		fi
		shift
	    else
		printerror "Argument expected for ${1}" ${UNKNOWN_ARGUMENT}
		exit ${DL_DIR_DOES_NOT_EXIST}
	    fi ;;
	--prefix | --prefi | --pref | --pre )  # install directory
	    if [ "x${2}" != "x" ] ; then
		CL_INS_DIR=${2}
		if [ "${CL_INS_DIR}" == "." ] || [ "${CL_INS_DIR}" == "./" ] ; then
		    CL_INS_DIR="`pwd`"
		    CL_DL_DIR="${STARTDIR}"
		else

		    # get full directory name if the user selects a relative path.

		    if [ -d "${CL_INS_DIR}" ] ; then
			cd "${CL_INS_DIR}"
			CL_INS_DIR="`pwd`"
			cd "${STARTDIR}"
		    else
			printerror "The install directory ${CL_INS_DIR} Does not exist." ${CL_DIR_DOES_NOT_EXIST}
			exit ${CL_DIR_DOES_NOT_EXIST}
		    fi
		fi
		shift
	    else
		printerror "Argument expected for ${1}"
		exit ${INS_DIR_DOES_NOT_EXIST}
	    fi  ;;
	--system | --sy | --sys | --syst | --syste ) # system to install
	    if [ "x${2}" != "x" ] ; then
		case "${2}" in
		    linux64 | LINUX64 | Linux64 )
			SYS="Linux64" ;;
		    Osxl64 | OSXL64 | osxl64 )
			SYS="osxl64" ;;
		    linux | LINUX | Linux )
			SYS="Linux" ;;
		    Osx64 | OSX64 | osx64 )
			SYS="osx64" ;;
		    * )			
			printerror "Unknown system ${2}"
			exit 1 ;;
		esac
		shift
	    else
		printerror "Argument expected for ${1}" ${UNKNOWN_ARGUMENT}
		exit ${UNKNOWN_ARGUMENT}
	    fi  ;;
	--batch ) # batch mode No prompts, use defaults
	    BATCH="y" ;;
	--silent | --silen | --sile | --sil | --si )  # silent mode (Implies batch mode)
            SILENT="y"
	    BATCH="y" ;;
	--config )  # extra configure switches
	    if [ "x${2}" != "x" ] ; then
		CONFIG_OPT="${2}"
	    else
		\echo "Argument expected for ${1}"
		exit ${UNKNOWN_ARGUMENT}
	    fi ;;
	--logdir | --logdi | --logd | --log | --lo | --l  | -l )
	    if [ "x${2}" != "x" ] ; then
		# Make sure directory exists and is writable

		if [ "${2}" == "." ] || [ "${2}" == "./" ] ; then
		    LOGDIR="`pwd`"
		else
		    LOGDIR="`\echo ${2}`"
		fi
	        if [ ! -d "${LOGDIR}" ] ; then
		    \echo "Invalid argument for --logdir ${LOGDIR}"
		    exit ${UNKNOWN_ARGUMENT}
		fi
	        if [ ! -w "${LOGDIR}" ] ; then
		    \echo "Directory ${LOGDIR} is not writable."
		    exit ${UNKNOWN_ARGUMENT}
		fi
		LOGFILE="${LOGDIR}/${LOGFILE_NAME}"
		\touch "${LOGFILE}"
		if [ ! -f "${LOGFILE}" ] ; then
		    \echo "Log directory not writable for --logdir ${2}"
		    exit ${UNKNOWN_ARGUMENT}
		fi
		shift
	    else
		\echo "Argument expected for ${1}"
		exit ${UNKNOWN_ARGUMENT}
	    fi ;;
	--caldb | --cald | --cal | --ca )
	    # location to install CALDB
	    if [ "x${2}" != "x" ] ; then
		CALDB_DIR="${2}"

		if [ "${CALDB_DIR}" != "CIAO" ] ; then
		    if [ -e "${CALDB_DIR}" ] ; then
			if [ ! -w ${CALDB_DIR} ] ; then
			    printline "CALDB dir ${CALDB_DIR} is not writable. CALDB files will not be installed."
			    NOCALDB="y"
			fi
		    else
			\echo "CALDB area not found!"
			exit ${CALDB_NOT_FOUND}
		    fi
		else
		    CALDB_DIR="CIAO"
		fi
		shift
	    else
		printerror "Argument expected for ${1}" ${CALDB_DIR_DOES_NOT_EXIST}
		exit ${CALDB_DIR_DOES_NOT_EXIST}
	    fi  ;;
	--use-ftp | --use-ft | --use-f )
	    FORCE_FTP="y" ;;
	--force | --forc | --for | -f )   # force install
	    FORCE_INSTALL="y"
	    if [ "x${DOWNLOAD_ONLY}" == "xy" ] ; then
		printerror "-f or --force not compatible with --download-only"
		exit 1
	    fi ;;
	--add | --ad | --a | -a )
	    if [ "x${2}" != "x" ] ; then
		SEGMENTS="${SEGMENTS} `echo ${2} | sed 'y/,/ /'`"
		shift
	    else
		\echo "Argument expected for ${1}"
		exit ${UNKNOWN_ARGUMENT}
	    fi ;;
	--verbose | --verbos | --verbo | --verb )
	    WGETVERB="-v"
	    MFTPVERB=""
	    FTPVERB="-v" ;;
	--server | --serve | --serv | --ser | --se )
	    if [ "x${2}" != "x" ] ; then
		CONTROL_LOCATION="${2}"
		shift
	    else
		printerror "Argument expected for ${1}"
		exit ${UNKNOWN_ARGUMENT}
	    fi ;;
	--version | --versio | --versi | --vers | --ver | --ve | --v | -v )
	    \echo "${VERSION_STRING}"
	    exit 0 ;;
	--delete-tar | --delete-ta | --delete-t | --delete- | --delete | --delet | --dele | --del | --de )
	    export DEF_DELETE_TAR="y"
	    export DELETE_TAR="y" ;;
	-h | --help | --hel | --he | --h )
	    usage
	    exit 0 ;;
	* ) # Unknown switch ${1} passed print help
	    \echo "Unknown switch ${1}"
	    usage
	    exit 1 ;;
    esac
    shift
done

# Make sure SEGMENTS is not empty

if [ "`count_arg ${SEGMENTS}`" == "0" ] ; then
    printline "Error: No Segments defined."
    printline "Please re-download this script or use the --add command line option."
    exit 1
fi

# First verify that we have the tools needed to install

case "`uname -s`" in
    Linux* )
	if [ "`uname -m`" != "x86_64" ] ; then
	    RSYS="Linux"
	else
	    RSYS="Linux64"
	fi ;;
    Darwin* | darwin* )

	# get the system version number
	sysver="`uname -r | sed 'y/./ /'`"
	let macver="`retn 1 ${sysver}`"
	proc="`uname -p`"

	# snow leopard (10.x.x) is the oldest supported version
	if (( ${macver} < 10 )) ; then
	    unsupport_sys
	    exit 1
	fi

	# verify that the CPU is 64 bit compatible (only 64 bit machines
	# are supported.
	if [ "x`sysctl hw.cpu64bit_capable | grep 1`" != x ] ; then
	    case ${macver} in
		10 ) RSYS="osx64";;
		* ) RSYS="osxl64";;
	    esac
	else
	    unsupport_sys
	    exit 1
	fi ;;
    * )
	RSYS="Unknown system" ;;
esac

if [ "x${SYS}" == "x" ] ; then
    SYS="${RSYS}"
else
    if [ "${RSYS}" != "${SYS}" ] ; then
	# check to see if system is compatible

	case "${RSYS}" in
	    Linux64 )
		if [ "${SYS}" != "Linux" ] ; then
		    SYSERR="n"
		else
		    printline "Warning: Installing 32 bit version on a 64 bit machine."
		fi ;;
	    osx64 )
		# trying to install Mac 11 (Lion) on Snow Leopard (Mac 10)
		unsupport_sys
		exit 1 ;;
	    osxl64 )
		printline "Warning: Installing ${SYS} on ${RSYS} system"
		SYSERR="n";;
	    * )
		SYSERR="n" ;;
	esac
	if [ "${SYSERR}" != "OK" ] ; then
	    if [ "${DOWNLOAD_ONLY}" != "y" ] ; then
		printline "WARNING: Attempting to install <${SYS}> on <${RSYS}>"
		printline "The files can be unpacked but configure cannot be run"
		printline "and the ahelp indexes and python modules cannot be created."
		printline "If you would like to just download the tarfiles, please"
		printline "use the --download-only switch on the command line."
		ansok="n"
		until [ "${ansok}" == "y" ] ; do
		    if [ "${BATCH}" != "y" ] ; then
			ans=`get_input "Should I continue? (y|n) (n)"`
			if [ "x${ans}" != "x" ] ; then
			    case ${ans} in
				y | Y | ye | yes | YE | YES | Yes | Ye | Yes ) ansok="y"
				    ans="y";;
				n | N | no | NO | No ) ansok="y"
				    ans="n" ;;
				* ) ans="m" ;;
			    esac
			else
			    ans="n"
			    ansok="y"
			fi
		    else
			ansok="y"
			ans="y"
		    fi
		done
		if [ "${ans}" == "n" ] ; then
		    printline "You can download the ${RSYS} version of CIAO with the command:"
		    printline "  > bash ${0} --system ${RSYS}"
		    exit 1
		fi
	    else
                # Mismatched systems but downloading only,
                # just warn and continue

		printline "WARNING: Attempting to download <${SYS}> on <${RSYS}>"
	    fi    
	fi
    fi
fi

if [ -f "${EXITFILE}" ] ; then
    RET="`cat ${EXITFILE}`" ; \rm -f ${EXITFILE} ; exit ${RET}
fi
\touch ${LOGFILE}
\echo ${CL} >> ${LOGFILE}
printline "${VERSION_STRING}"
printline "Requested packages: ${SEGMENTS}"
uname -a >> ${LOGFILE}

printline "Script log file is ${LOGFILE}"

if [ "x${SUDO_USER}" != "x" ] ; then
    printline "Error: DO NOT run ${0} with sudo ${0}"
    printline "This will cause permission issues at run time!"
    exit 1
fi

if [ "x${USER}" == "xroot" ] ; then
    printline "WARNING: Installing CIAO as root!"
    printline "Please consider installing as a non-privileged user."
fi

verify_tools

# If the user has any defaults already, let use them instead of
# our defaults

if [ -f "${EXITFILE}" ] ; then
    RET="`cat ${EXITFILE}`" ; \rm -f ${EXITFILE} ; exit ${RET}
fi
get_all_defaults

# Prompt the user for input. Create any directories needed

if [ -f "${EXITFILE}" ] ; then
    RET="`cat ${EXITFILE}`" ; \rm -f ${EXITFILE} ; exit ${RET}
fi
get_user_input

# install the required CIAO files

if [ -f "${EXITFILE}" ] ; then
    RET="`cat ${EXITFILE}`" ; \rm -f ${EXITFILE} ; exit ${RET}
fi

# print out what system they are installing.

case "${SYS}"
    in
    osxl64 ) printline "Preparing to install CIAO for Lion";;
    osx64 ) printline "Preparing to install CIAO for Snow Leopard";;
    Linux ) printline "Preparing to install CIAO for Linux 32 bit";;
    Linux64 ) printline "Preparing to install CIAO for Linux 64 bit";;
esac

read_control

# Do any post processing here. (rebuild ahelp index, build python modules, etc.)

if [ -f "${EXITFILE}" ] ; then
    RET="`cat ${EXITFILE}`" ; \rm -f ${EXITFILE} ; exit ${RET}
fi
if [ "${DOWNLOAD_ONLY}" != "y" ] && [ "${SYSERR}" == "OK" ] ; then
    post_process
fi
if [ -f "${EXITFILE}" ] ; then
    RET="`cat ${EXITFILE}`" ; \rm -f ${EXITFILE} ; exit ${RET}
fi
exit 0


