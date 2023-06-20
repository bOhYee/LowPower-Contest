proc swap_to_hvt {} {

    set library_name "CORE65LPHVT"

    foreach_in_collection cell [get_cells] {

        set ref_name [get_attribute $cell ref_name]
        set has_substituted [regsub {_LL} $ref_name "_LH" new_ref_name]

        if {$has_substituted != 0} {
            size_cell $cell "${library_name}/${new_ref_name}" 
        }
    }
}

proc swap_to_lvt {} {

    set library_name "CORE65LPLVT"

    foreach_in_collection cell [get_cells] {

        set ref_name [get_attribute $cell ref_name]
        set has_substituted [regsub {_LH} $ref_name "_LL" new_ref_name]

        if {$has_substituted != 0} {
            size_cell $cell "${library_name}/${new_ref_name}"
        }
    }
}

proc swap_cell_to_lvt {cell} {

    set library_name "CORE65LPLVT"

    set ref_name [get_attribute $cell ref_name]
    set has_substituted [regsub {_LH} $ref_name "_LL" new_ref_name]

    if {$has_substituted != 0} {
        size_cell $cell "${library_name}/${new_ref_name}"
    }     
}

proc swap_cell_to_hvt {cell} {

    set library_name "CORE65LPHVT"

    set ref_name [get_attribute $cell ref_name]
    set has_substituted [regsub {_LL} $ref_name "_LH" new_ref_name]

    if {$has_substituted != 0} {
        size_cell $cell "${library_name}/${new_ref_name}"
    } 
}

proc check_contest_constraints {slackThreshold maxFanoutEndpointCost} {

    # Check slack
    set msc_slack [get_attribute [get_timing_paths] slack]
    
    if {$msc_slack < 0} {
        return 0
    }

    # Check fanout endpoint cost
    foreach_in_collection cell [get_cells] {
        set paths [get_timing_paths -through $cell -nworst 1 -max_paths 10000 -slack_lesser_than $slackThreshold]
        set cell_fanout_endpoint_cost 0.0

        foreach_in_collection path $paths {
            set this_cost [expr $slackThreshold - [get_attribute $path slack]]
            set cell_fanout_endpoint_cost [expr $cell_fanout_endpoint_cost + $this_cost]
        }
        
        if {$cell_fanout_endpoint_cost >= $maxFanoutEndpointCost} {
            set cell_name [get_attribute $cell full_name]
            set cell_ref_name [get_attribute $cell ref_name]
            return 0
        }
    }

    return 1
}

proc compute_fanout_cost {cell slackThreshold} {

    set cells ""
    set totalCells 0
    set cell_fanout_endpoint_cost 0.0
    set paths [get_timing_paths -through $cell -nworst 1 -max_paths 10000 -slack_lesser_than $slackThreshold]

    foreach_in_collection path $paths {
        set this_cost [expr $slackThreshold - [get_attribute $path slack]]
        set cell_fanout_endpoint_cost [expr $cell_fanout_endpoint_cost + $this_cost]

        foreach_in_collection point [get_attribute $path points] {

            # Recover pin informations
            set pin [get_attribute $point object]
            set name_pin [get_attribute $pin full_name]

            # Need to verify that is an output pin (in order to not have duplicates)
            if { [regexp "(U.*/Z)" $name_pin] == 0 } {
                continue;
            }

            # Recover associated cell informations
            set cell [get_attribute $pin cell]
            set full_name [get_attribute $cell full_name]
            lappend cells $full_name

            incr totalCells
        }
    }

    return "$cell_fanout_endpoint_cost $totalCells $cells"
}

proc extractCellsInfo {slackThreshold} {
    
    set tempList ""
    set retList ""

    # Structure of cellInfo:
    #   0 - Full name of the cell
    #   1 - Power of LVT variant
    #   2 - Slack of the worst path passing through the LVT cell
    #   3 - Power of HVT variant
    #   4 - Slack of the worst path passing through the HVT cell
    #   5 - Difference of power (LVT - HVT)
    #   6 - Difference in slack (LVT - HVT)
    #   7 - List
    #   7.1 - Fanout endpoint cost
    #   7.2 - Number of cells of worst critical path for fanout endpoint cost
    #   7.3 - Violating cells

    # Recover LVT related informations
    swap_to_lvt
    foreach_in_collection cell [get_cells] {
        set cellInfo ""
        lappend cellInfo [get_attribute $cell full_name]
        lappend cellInfo [get_attribute $cell leakage_power]
        lappend cellInfo [get_attribute [get_timing_paths -through $cell] slack]

        lappend tempList $cellInfo
    }
    
    
    # Recover HVT related informations
    swap_to_hvt
    foreach cellInfo $tempList {
        set cell [get_cells [lindex $cellInfo 0]]
        set worstPathForCell [get_timing_paths -through $cell]

        lappend cellInfo [get_attribute $cell leakage_power]
        lappend cellInfo [get_attribute $worstPathForCell slack]
        lappend cellInfo [expr [lindex $cellInfo 1] - [lindex $cellInfo 3]]
        lappend cellInfo [expr [lindex $cellInfo 2] - [lindex $cellInfo 4]]
        lappend cellInfo [compute_fanout_cost $cell $slackThreshold]

        lappend retList $cellInfo
    }
    return $retList;
}

proc compute_score {cell maxFanoutEndpointCost} {

    set powerWeight [expr 100.0 / 100]
    set cellsWeight [expr 100.0 / 100]

    set powerDiff [lindex $cell 5]
    set slackDiff [lindex $cell 6]
    set endpointCost [lindex [lindex $cell 7] 0]
    set totalCells [lindex [lindex $cell 7] 1]
    set endpointCostDiff 0.0
    set bonus 0.0

    # Score function
    if {$endpointCost >= $maxFanoutEndpointCost} {
        set endpointCostDiff [expr $endpointCost - $maxFanoutEndpointCost]
        set bonus [expr 0.0 + [expr $endpointCostDiff / $totalCells]]
    }

    set numerator [expr 0.0 + [expr $powerWeight * $powerDiff]]
    set denominator [expr 0.0 + [expr $cellsWeight * $slackDiff]]
    set score [expr 0.0 + [expr $numerator / $denominator] + $bonus]

    return $score
}

proc rankCells {cells maxFanoutEndpointCost} {

    set scored_cell ""
    set scored_cells ""

    foreach cell $cells {
        set scored_cell ""
        set score [compute_score $cell $maxFanoutEndpointCost]

        lappend scored_cell $cell
        lappend scored_cell $score
        lappend scored_cells $scored_cell
    }

    return [lsort -real -decreasing -index 1 $scored_cells]
}

proc dualVth {slackThreshold maxFanoutEndpointCost} {

    set loopCount 0
    set maxPerc 0
    set maxCounter [expr 0.0 + [expr 0.05 * [sizeof_collection [get_cells]]]]

    # Extract cells informations and convert all cells to HVT at the end of the routine
    set cells [extractCellsInfo $slackThreshold]

    # Score each cell based on its attributes: higher score, higher priority for their substitution
    # Returned cells are ordered by decreasing score
    set ranked_cells [rankCells $cells $maxFanoutEndpointCost]

    # Switch each cell using the order defined before
    foreach cellInfo $ranked_cells {
        set cell_full_name [lindex [lindex $cellInfo 0] 0]
        set cell [get_cells $cell_full_name]

        # Swap the cell and if constraints are met, we're done
        swap_cell_to_lvt $cell
        if {[check_contest_constraints $slackThreshold $maxFanoutEndpointCost] == 1} {
            break;
        }
    }
    
    # We want to check if we could do better by trying to switch LVT cells to HVT while mantaining the slack positive
    set counter 0 
    set violatingCells ""
    set prevSlack [get_attribute [get_timing_paths] slack]

    # Order them by lower priority first since they probably don't matter too much
    set ranked_cells [lsort -real -increasing -index 1 $ranked_cells]

    foreach cellInfo $ranked_cells {
        set cell_full_name [lindex [lindex $cellInfo 0] 0]
        set cell [get_cells $cell_full_name]

        # Swap only to HVT
        if {[regexp {_LH} [get_attribute $cell ref_name]] == 1} {
            continue;
        }

        # Swap the cell and if slack is lower than 0 or 
        # the slack doesn't improve, revert the changes
        swap_cell_to_hvt $cell
        set newSlack [get_attribute [get_timing_paths] slack]

        if {$newSlack < 0 || $prevSlack < $newSlack} {
            incr counter
            swap_cell_to_lvt $cell
        } else {
            lappend violatingCells $cell_full_name
            set prevSlack $newSlack
            set counter 0
        }

        # If we don't substitute any cell 20 times in a row, probably we can't substitute any more cells
        # Close the loop
        if { $counter >= $maxCounter } {
            break;
        }
    }

    # If, after the second optimization round, we can't satisfy the constraints
    # Revert the changes done
    if {[check_contest_constraints $slackThreshold $maxFanoutEndpointCost] == 0} {
        foreach cellName $violatingCells {
            set cell [get_cells $cellName]
            swap_cell_to_lvt $cell
        }
    }

    return 1;
}