#!/bin/bash
#
#  filter.sh: functions for filtering various files
#
#  Copyright (C) 2020  David Marmor
#
#  https://github.com/dmarmor/epichrome
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#


# FILTERFILE -- filter a file using token-text pairs
#   filterfile(sourceFile destFile fileInfo token1 text1 [token2 text2] ...)
function filterfile {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local sourceFile="$1" ; shift
    local destFile="$1"   ; shift
    local fileInfo="$1"   ; shift ; [[ "$fileInfo" ]] || fileInfo="${sourceFile##*/}"
    
    # build sed command
    local sedCommand=
    local arg=
    local isToken=1
    for arg in "$@" ; do
        
        # escape special characters for sed
        arg="${arg//\\/\\\\}"
        arg="${arg//\//\\/}"
        arg="${arg//&/\&}"
        
        if [[ "$isToken" ]] ; then
            
            # starting a new token-text pair
            sedCommand+="s/$arg/"
            isToken=
        else
            # finishing a token-text pair
            sedCommand+="$arg/g; "
            isToken=1
        fi
    done
    
    # filter file
    local destFileTmp=$(tempname "$destFile")
    try "$destFileTmp<" /usr/bin/sed "$sedCommand" "$sourceFile" "Unable to filter $fileInfo."
    
    # move script to permanent home
    # on error, remove temporary file
    if [[ "$ok" ]] ; then
        permanent "$destFileTmp" "$destFile" "$fileInfo"
    else
        rmtemp "$destFileTmp" "$fileInfo"
    fi
}


# FILTERPLIST: write out a new plist file by filtering an input file with PlistBuddy
#   filterplist(srcFile destFile tryErrorID PlistBuddyCommands ...)
function filterplist {
    
    # only run if we're OK
    [[ "$ok" ]] || return 1
    
    # arguments
    local srcFile="$1"    ; shift
    local destFile="$1"   ; shift
    local tryErrorID="$1" ; shift # ID of this plist file for messaging
    
    # create command list
    local pbCommands=( )
    local curCmd=
    for curCmd in "$@" ; do
        pbCommands+=( -c "$curCmd" )
    done
    
    # create name for temp destination file
    local destFileTmp="$(tempname "$destFile")"
    
    # copy source file to temp
    try /bin/cp "$srcFile" "$destFileTmp" "Unable to create temporary $tryErrorID."
    
    [[ "$ok" ]] || return 1
    
    # use PlistBuddy to filter temp plist
    try /usr/libexec/PlistBuddy "${pbCommands[@]}" "$destFileTmp" \
            "Error filtering $tryErrorID."
    
    if [[ "$ok" ]] ; then
        
        # on success, move temp file to permanent location
        permanent "$destFileTmp" "$destFile" "$tryErrorID"
    else
        
        # on error, delete the temp file
        rmtemp "$destFileTmp" "$tryErrorID"
    fi
    
    # return code
    [[ "$ok" ]] && return 0 || return 1
    
}
# $$$$ export -f filterplist


# LPROJESCAPE: escape a string for insertion in an InfoPlist.strings file
#   lprojescape(string)
function lprojescape {
    s="${1/\\/\\\\\\\\}"    # escape backslashes for both sed & .strings file
    s="${s//\//\\/}"        # escape forward slashes for sed only
    s="${s//&/\\&}"         # escape ampersands for sed only
    echo "${s//\"/\\\\\"}"  # escape double quotes for both sed & .strings file
}


# FILTERLPROJ: destructively filter all InfoPlist.strings files in a set of .lproj directories
#   filterlproj(aBasePath aErrID aUsageKey [aStepId])
function filterlproj {
    
    [[ "$ok" ]] || return 1
    
    # turn on nullglob
    local iShoptState=
    shoptset iShoptState nullglob
    
    # arguments
    local aBasePath="$1" ; shift    # folder containing .lproj folders
    local aErrID="$1" ; shift       # info about this filtering for error messages
    local aUsageKey="$1" ; shift    # name to search for in usage description strings
    if [[ ! "$progressDoCalibrate" ]] ; then
        local aStepId="$1" ; shift  # ID for progress messages
    fi
    
    # escape bundle name strings
    local displayName="$(lprojescape "$CFBundleDisplayName")"
    local bundleName="$(lprojescape "$CFBundleName")"
    
    # create sed command
    local sedCommand='s/^(CFBundleName *= *").*("; *)$/\1'"$bundleName"'\2/; s/^(CFBundleDisplayName *= *").*("; *)$/\1'"$displayName"'\2/'
    
    # if we have a usage key, add command for searching usage descriptions
    [[ "$aUsageKey" ]] && sedCommand="$sedCommand; "'s/^((NS[A-Za-z]+UsageDescription) *= *".*)'"$aUsageKey"'(.*"; *)$/\1'"$bundleName"'\3/'
    
    # get list of lproj directories
    local iLprojList=( "$aBasePath/"*.lproj )
    
    # initialize progress increment
    if [[ "$aStepId" ]] ; then
        local iNumLproj=${#iLprojList[@]}
        if [[ "$iNumLproj" -gt 0 ]] ; then
            local iLprojIncrement=
            eval "iLprojIncrement=\$(( \$$aStepId / \$iNumLproj ))"
        fi
    fi
    
    # filter InfoPlist.strings files
    local curLproj=
    for curLproj in "${iLprojList[@]}" ; do
        
        # get paths for current in & out files
        local curStringsIn="$curLproj/InfoPlist.strings"
        local curStringsOutTmp="$(tempname "$curStringsIn")"
        
        if [[ -f "$curStringsIn" ]] ; then
            # filter current localization
            try "$curStringsOutTmp<" /usr/bin/sed -E "$sedCommand" "$curStringsIn" \
                    "Unable to filter $aErrID localization strings."
            
            # move file to permanent home
            permanent "$curStringsOutTmp" "$curStringsIn" "$aErrID localization strings"
            
            # update progress message if requested
            if [[ "$aStepId" ]] ; then
                progress 'iLprojIncrement'
            fi
            
            # on any error, abort
            if [[ ! "$ok" ]] ; then
                # remove temp output file on error
                rmtemp "$curStringsOutTmp" "$aErrID localization strings"
                break
            fi
        fi
    done
    
    # restore nullglob
    shoptrestore iShoptState
    
    # return success or failure
    [[ "$ok" ]] && return 0 || return 1
}
