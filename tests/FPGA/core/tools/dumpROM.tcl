# Dump ROM (instance 0) para verificar se o programa foi carregado corretamente
package require ::quartus::insystem_memory_edit

set OUTFILE  [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "output_mifs/rom_dump.mif"}]

set JTAG "USB-Blaster"
if { [catch { set jc [exec jtagconfig] } err] } {
} else {
    foreach line [split $jc "\n"] {
        if {[regexp {^\s*\d+\)\s+(.+)$} $line -> hwname]} {
            set JTAG [string trim $hwname]; break
        }
    }
}

set DEV_NAME "@1: 5CE(BA4|FA4) (0x02B050DD)"

catch { end_memory_edit }
begin_memory_edit -hardware_name $JTAG -device_name $DEV_NAME

# Dump ROM = instance 0
save_content_from_memory_to_file \
    -instance_index 0 \
    -mem_file_path  $OUTFILE \
    -mem_file_type  "mif"

catch { end_memory_edit }
puts "ROM dump: $OUTFILE"
exit 0
