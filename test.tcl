#!/usr/bin/env expect
log_user 0

# begin with a clean slate
spawn ./bin/tackle ls tutstack
expect {
    "tutstack" {
        set preinstalled true
        exec ./bin/tackle rm tutstack
    }
    "Error" {
        puts "Could not setup clean test enviornment"
        exit 1
    }
    "\n" {
        set preinstalled false
    }
}

spawn ./bin/tackle ls tutstack
expect {
    "tutstack" {dict set results ls false}
    "Error"    {dict set results ls false}
    "\n"       {dict set results ls true}
}


spawn ./bin/tackle search tutstack
expect {
    "An example Tcl package" {dict set results search true}
    "Error"                  {dict set results search false}
    "\n"                     {dict set results search false}
}

spawn ./bin/tackle add tutstack
expect {
    "Added package tutstack"        {dict set results add true}
    "tutstack is already installed" {dict set results add false}
    "Error"                         {dict set results add false}
    "\n"                            {dict set results add false}
}

spawn ./bin/tackle show tutstack
expect {
    "An example Tcl package" {dict set results show true}
    "Error"                  {dict set results show false}
    "\n"                     {dict set results show false}
}

spawn ./bin/tackle rm tutstack
expect {
    "Removed tutstack"          {dict set results rm true}
    "tutstack is not installed" {dict set results rm false}
    "Error"                     {dict set results rm false}
    "\n"                        {dict set results rm false}
}

if $preinstalled {
    exec ./bin/tackle add tutstack
}

set passed 0
set failed 0

foreach {command result} $results {
    if $result {
        append verbose "✅ $command\n"
        incr passed
    } else {
        append verbose "❌ $command\n"
        incr failed
    }
}

if {$failed ne 0} {
    puts "❌ $failed tests failed."
    puts $verbose
    exit 1
} else {
    puts "✅ All $passed tests passed."
}

