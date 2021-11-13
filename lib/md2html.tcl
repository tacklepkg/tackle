set auto_path ../src/tackle.vfs/lib/

package require Tcl 8.5
package require Markdown
package require textutil

set markdownFile [open [lindex $argv 0] r]
set markdown [read $markdownFile]
close $markdownFile

set html [::Markdown::convert $markdown]

set htmlFile [open [lindex $argv 1] w]
puts $htmlFile $html
close $htmlFile
