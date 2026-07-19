#!/usr/bin/gawk -f

BEGIN {
    FS = ","
    print "=== GAWK PERFORMANCE ENGINE ==="
    
    # GAWK Extension: Read native environment and interpreter data
    print "Running GAWK Version: " PROCINFO["version"]
    print "System Architecture:  " PROCINFO["platform"]
    print "------------------------------------------------"
    print "Timestamp \t\t Device \t Status"
    print "------------------------------------------------"
    
    # GAWK Extension: Force case-insensitive string pattern matching
    IGNORECASE = 1
}

# Match any line containing 'm4' regardless of uppercase/lowercase variations
/m4/ {
    # GAWK Extension: Fetch high-resolution epoch time natively
    current_epoch = systime()
    
    # GAWK Extension: Format time without calling bash 'date' commands
    formatted_time = strftime("%Y-%m-%d %H:%M:%S", current_epoch)
    
    # Output formatted logs cleanly
    printf "[%s] \t %s \t\t %s\n", formatted_time, $1, $3
}

END {
    print "------------------------------------------------"
    print "Data processing completed successfully."
}
