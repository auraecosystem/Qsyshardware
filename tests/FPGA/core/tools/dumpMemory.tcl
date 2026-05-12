# tools/dumpMemory.tcl
# Uso:
#   quartus_stp -t tools/dumpMemory.tcl <OUTFILE> <INST_IDX>

package require ::quartus::insystem_memory_edit

set OUTFILE  [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "output_mifs/ram_dump.mif"}]
set INST_IDX [expr {[llength $argv] >= 2 ? [lindex $argv 1] : 1}]

# Detecta hardware JTAG
set JTAG "USB-Blaster"
if { [catch { set jc [exec jtagconfig] } err] } {
    puts "jtagconfig nao disponivel, usando: $JTAG"
} else {
    foreach line [split $jc "\n"] {
        if {[regexp {^\s*\d+\)\s+(.+)$} $line -> hwname]} {
            set JTAG [string trim $hwname]
            break
        }
    }
    puts "Usando JTAG: $JTAG"
}

set DEV_NAME "@1: 5CE(BA4|FA4) (0x02B050DD)"

puts ""
puts "Iniciando dump da memoria editavel"
puts "  arquivo de saida: $OUTFILE"
puts "  instance index  : $INST_IDX"
puts "  hardware        : $JTAG"
puts "  device          : $DEV_NAME"
puts ""

catch { end_memory_edit }

if { [catch { begin_memory_edit -hardware_name $JTAG -device_name $DEV_NAME } err] } {
    puts stderr "Erro em begin_memory_edit: $err"
    exit 2
}

# Lista instancias (com -hardware_name e -device_name conforme API desta versao)
set inst_list [list]
if {[catch {
    set inst_list [get_editable_mem_instances \
        -hardware_name $JTAG \
        -device_name   $DEV_NAME]
} gerr]} {
    puts "Aviso ao listar instancias: $gerr"
} else {
    puts "Instancias editaveis (index : description):"
    set i 0
    foreach it $inst_list {
        puts "  $i : $it"
        incr i
    }
}

# Salva conteudo — save_content_from_memory_to_file NAO aceita -hardware_name/-device_name
# nesta versao; usa a sessao aberta por begin_memory_edit
if {[catch {
    save_content_from_memory_to_file \
        -instance_index $INST_IDX   \
        -mem_file_path  $OUTFILE    \
        -mem_file_type  "mif"
} serr]} {
    puts stderr "Erro em save_content_from_memory_to_file: $serr"
    catch { end_memory_edit }
    exit 3
}

catch { end_memory_edit }
puts "Dump concluido: $OUTFILE"
exit 0
