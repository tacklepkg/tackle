#//#
# Tackle is a package manager for the Tcl programming language.
# This file provides a command-line interface, e.g.:
# <pre>
#   $ tackle ls
#   tustack
#   tcllib
#   tcltls
#   $ tackle rm tutstack
#   Removed tutstack.
#   $ tackle ls
#   tcllib
#   tcltls
# </pre>
#
# @author    nat-418
# @version   0.0.6
# @see       https://www.github.com/tacklepkg/tackle
#//#
package require http
package require tls

# We begin by inlining a few dependencies
# =======================================

namespace eval ::targz {
    package require tar
    package require zlib
    namespace export unpack

    # Unpacks a gzipped tarball
    #
    # @param  targz       Path to some file.tar.gz
    # @param  destination Path to an output directory for the archive contents
    # @return Path to the unarchived destination directory
    proc unpack {targz destination} {
        try {
            set unpacked  [lindex [exec tar -xvzf $targz] 0]
            set directory [file join $destination $unpacked]

            file rename $unpacked $directory
            file delete -force $targz

            return $directory
        } on error msg {
            puts "System tar not available, falling back to slow tar..."
            puts $msg
        }

        set tar [file rootname $targz]

        try {
            set chan1 [open $targz rb]
            zlib push gunzip $chan1 
            set contents [read $chan1]
            close $chan1
        } on error msg {
            puts "[redText Error:] Failed to decompress tarball: $targz."
            exit 1
        }
        
        try {
            set chan2 [open $tar wb]
            puts -nonewline $chan2 $contents
            close $chan2
        } on error msg {
            puts "[::termColor::red Error:] Failed to write archive: $tar."
            exit 1
        }
        
        set contents    [::tar::contents $tar]
        set directory   [file root $tar]

        set files [lmap path $contents {file tail $path}]

        foreach path $contents {
            try {
                if {[string index $path end] eq "/"} {
                    file mkdir [file join $destination $path]
                } else {
                    file mkdir [file normalize [file join $destination [file dirname $path]]]
                    set chan3 [open [file join $destination $path] wb]
                    puts -nonewline $chan3 [::tar::get $tar $path]
                    close $chan3
                }
            } on error msg {
                puts "Failed to unarchive $path."
            }
        }

        file delete $targz
        file delete $tar

        return $directory
    }
}

namespace eval ::httpRedirects {
    package require http
    package require uri

    namespace export geturl

    # GETs through HTTP redirects
    #
    # @param  url  URL target for the HTTP request
    # @param  args Options to pass to ::http::geturl
    # @return Token representing the respons to the request
    # @see    https://www.tcl.tk/man/tcl/TclCmd/http.html#M17
    proc geturl {url args} {
        array set URI [::uri::split $url]
        for {set i 0} {$i < 5} {incr i} {
            set token [::http::geturl $url {*}$args]

            if {![string match {30[1237]} [::http::ncode $token]]} {
                return $token
             }

            array set meta [string tolower [set ${token}(meta)]]

            if {![info exist meta(location)]} {
                return $token
            }

            array set uri [::uri::split $meta(location)]

            unset meta

            if {$uri(host) eq {}} {set uri(host) $URI(host)}

            # problem w/ relative versus absolute paths
            set url [::uri::join {*}[array get uri]]
        }
    }
}

namespace eval ::termColor {
    namespace export bright red green yellow

    # Apply ANSI bold color escape sequences to a string and then reset.
    #
    # @param  code Color code
    # @param  str  String to be colored
    # @return String with proper escape codes
    # @see    https://en.wikipedia.org/wiki/ANSI_escape_code
    proc highlight {code str} {
        append result "\033\[$code";
        append result $str
        append result "\033\[0m";

        return $result
    }

    proc bright str {highlight "1;29m" $str}
    proc red    str {highlight "1;31m" $str}
    proc green  str {highlight "1;32m" $str}
    proc yellow str {highlight "1;33m" $str}
}

# Here we define the procedures of Tackle proper
# =============================================

# Helper function to perform a GET request. Throws if response is not 200 OK.
#
# @param  url  URL target for the HTTP request
# @return Body of the HTTP response
proc fetch url {
    set token [::httpRedirects::geturl $url]
    set code  [::http::ncode $token]
    set data  [::http::data $token]

    if {$code ne 200} {
        error "HTTP request for $url failed."
    }

    return $data
}

# Search package index for a given package name
#
# @param  index   Dictionary of installable packages
# @param  tracker Dictionary of installed packages
# @param  query   String of what package we are looking for
# @return Void: side-effect is to print search results
proc search {index tracker {query ""}} {
    try {
        set names [dict keys $index]
    } on error msg {
        puts "[::termColor::red Error:] malformed package index."
    }

    foreach name [lsearch -inline -all $names $query*] {
        dict with index $name {
            if {$type eq "module"} {
                set hiName [::termColor::yellow $name]
            } else {
                set hiName [::termColor::green $name]
            }
            puts "$hiName [::termColor::bright v$version]"
            puts "  $description"
            puts "  [string totitle $type] URL: $url"
            puts ""
        }
    }

    exit
}

# Add (i.e. install) packages
#
# @param  index   Dictionary of installable packages
# @param  tracker Dictionary of installed packages
# @param  names   List of package names to install
# @return         Updated dictionary of installed packages
proc add {index tracker names} {
    upvar tacklepath destination

    set installed      [dict keys $tracker]
    set updatedTracker $tracker

    foreach name $names {
        if {$name in $installed || [file isdirectory $name]} {
            puts "$name is already installed, skipping..."
            continue
        }

        dict set updatedTracker $name [dict get $index $name]

        dict with index $name {
            file mkdir $destination
             
            set payload  [fetch $url]
            set filename [file join $destination [file tail $url]]

            set channel [open $filename wb]
            puts -nonewline $channel $payload
            close $channel

            if {$type eq "package"} {
                set unpacked [::targz::unpack $filename $destination]
                dict set updatedTracker $name path $unpacked
            } else {
                dict set updatedTracker $name path $filename
            }
            
            if {[info exists setup]} {
                exec sh -c [subst $setup]
            }

            puts "Added $type $name v$version"
            puts "from $url"
            puts "to $unpacked"
        }
    }

    return $updatedTracker
}

# Remove (i.e. uninstall) packages
#
# @param  tracker Dictionary of installed packages
# @param  names   List of package names to uninstall
# @return Updated dictionary of installed packages
proc rm {tracker names} {
    upvar tacklepath destination

    set installed      [dict keys $tracker]
    set updatedTracker $tracker

    foreach name $names {
        try {
            set path [dict get $tracker $name path]
        } on error msg {
            puts "$name is not installed, skipping..."
            continue
        }

        if {$name in $installed && [file isdirectory $path]} {
            try {
                set updatedTracker [dict remove $updatedTracker $name]
                file delete -force $path
            } on error msg {
                puts "[::termColor::red Error:] failed to remove $name."
                exit 1
            } finally {
                puts "Removed $name."
            }
        } else {
            puts "[::termColor::red Error:] tracker out of sync with packages."
            exit 1
        }
    }
    
    return $updatedTracker
}

# List installed packages
#
# @param  tracker Dictionary of installed packages
# @param  pattern Glob-style pattern of package names
# @return Void: side-effect is to print package names to the console.
proc ls {tracker pattern} {
    set names [dict keys $tracker]

    if {$names eq ""} exit

    puts [string map {" " \n} [lsearch -inline -all $names $pattern*]]

    exit
}

# Show details of an installed package
#
# @param  tracker Dictionary of installed packages
# @param  name    Name of a pattern to detail
# @return Void: side-effect is to print package details to the console.
proc show {tracker name} {
    try {
        set names [dict keys $tracker]
    } on error msg {
        puts "[::termColor::red Error:] malformed package tracker."
    }

    try {
        dict with tracker $name {
            if {$type eq "module"} {
                set hiName [::termColor::yellow $name]
            } else {
                set hiName [::termColor::green $name]
            }
            puts "$hiName [::termColor::bright v$version]"
            puts "  $description"
            puts "  [string totitle $type] URL: $url"
            puts "  Path: $path"
            puts ""
        }
    } on error msg {
        puts "[::termColor::red Error:] $name is not installed."
    }

    exit
}

# Below we handle user input, execute commands, etc.
# ==================================================

# Do nothing by default
if {$argc eq 0} {
    puts "[::termColor::red Error:] no input given."
    exit 1
}

set command     [lindex $argv 0]
set arguments   [lrange $argv 1 end]
set tacklepath  [file join $::env(HOME) .local share tackle]
set trackerFile [file join $::env(HOME) .config tackle tracker.tackle]

# Create tracker file if it does not already exist.
close [open $trackerFile a]

# Get the record of what is installed
set channel [open $trackerFile r]
set tracker [read $channel]
close $channel

# We don't need network or file modfication to check local state.
if {$command eq "ls" || $command eq "show"} {
    $command $tracker $arguments
    exit
}

# Only search and add need to check the network.
if {$command eq "search" || $command eq "add"} {
    try {
        # Support HTTPS or HTTP requests
        ::http::register https 443 [list ::tls::socket -tls1 1]

        # Get the latest available packages
        set index [fetch \
            https://raw.githubusercontent.com/tacklepkg/packages/master/index.tackle]
    } on error msg {
        puts "[::termColor::red Error:] could not fetch package index."
        exit 1
    }
    set tracker [$command $index $tracker $arguments]
} else {
    set tracker [$command $tracker $arguments]
}

# Update our record of what is installed
set channel2 [open $trackerFile w+]
puts -nonewline $channel2 $tracker
close $channel2
