package require ::quartus::insystem_memory_edit

set INFILE [expr {[llength $argv] >= 1 ? [lindex $argv 0] : ""}]
if {$INFILE eq ""} {
    puts stderr "Uso: quartus_stp -t tools/loadROM.tcl <mif_file>"
    exit 1
}

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

puts "Hardware: $JTAG"
puts "Device:   $DEV_NAME"
puts "Arquivo:  $INFILE"
puts ""

catch { end_memory_edit }

# Abre sessao
if { [catch { begin_memory_edit -hardware_name $JTAG -device_name $DEV_NAME } err] } {
    puts stderr "ERRO begin_memory_edit: $err"
    exit 2
}
puts "Sessao aberta OK"

# Lista instancias para confirmar que ROM esta acessivel
if { [catch {
    set inst_list [get_editable_mem_instances -hardware_name $JTAG -device_name $DEV_NAME]
    puts "Instancias:"
    set i 0
    foreach it $inst_list { puts "  $i: $it"; incr i }
} gerr] } {
    puts "Aviso ao listar: $gerr"
}

# Tenta carregar — instance 0 = ROM
puts ""
puts "Carregando ROM (instance 0) com $INFILE ..."
if { [catch {
    update_content_to_memory_from_file \
        -instance_index 0       \
        -mem_file_path  $INFILE \
        -mem_file_type  "mif"
} err] } {
    puts stderr "ERRO update_content_to_memory_from_file: $err"
    catch { end_memory_edit }
    exit 3
}
puts "update_content_to_memory_from_file: OK"

# Faz leitura de volta para verificar
puts ""
puts "Verificando conteudo (lendo palavra 0)..."
if { [catch {
    set word0 [read_content_from_memory -instance_index 0 -start_address 0 -word_count 4]
    puts "Palavras 0-3 apos escrita: $word0"
} rerr] } {
    puts "Aviso ao ler de volta: $rerr"
}

catch { end_memory_edit }
puts "Feito."
exit 0
