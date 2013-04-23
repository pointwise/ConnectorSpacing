#
# Copyright 2012 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Glyph script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
# _____________________________________________________________________________
# _____________________________________________________________________________
#
#                         AVERAGE SPACING UTILITY
# _____________________________________________________________________________
# _____________________________________________________________________________
#
# Author:  Michael Kurtz
# Version: 1.0
# Date:    May 15, 2012
#
#   ========================  NOTES ============================
#
#   This script prompts the user to select a domain, and then
#   finds the spacings at the connector endpoints within and touching
#   (emanating from) the domain's edges. The user may then select
#   whether they want to apply the average spacing of the connectors
#   within and/or touching the domain edges to the connector endpoints
#   within and/or touching the domain's edges.
#
#   ============================================================

package require PWI_Glyph 2.3
pw::Script loadTk
set saveColor ""
set saveColorMode ""
set dom_A ""

# _______________________________ SET COLOR ___________________________________

proc setColor { color colorMode } {
  global saveColor saveColorMode dom_A
  $dom_A setColor $color
  $dom_A setRenderAttribute ColorMode $colorMode
  pw::Display update
}


# _____________________________________________________________________________
#
#                      GET ACTUAL SPACING CONSTRAINTS
# _____________________________________________________________________________
proc getActualSpacing { con loc } {
  if { $loc == 1 } {
    set node [$con getNode $loc]
  } else {   ; # $loc >1
    set node [$con getNode 2]
  }

  set xyz2 [$node getXYZ]

  if { $loc==1 } {
    # Set it to the second point on the con if we are interested in the beg.
    set xyz [$con getXYZ 2]
  } else {    ;# $loc > 1
    # Set it to 2nd to last point on the con if we are interested in the end
    set xyz [$con getXYZ [expr $loc -1]]
  }

  set spac [pwu::Vector3 length [pwu::Vector3 subtract $xyz $xyz2]]
  return $spac
}


# _____________________________________________________________________________
#
#                      GET THE CURRENT SPACING CONSTRAINTS
# _____________________________________________________________________________

proc getCurrentSpacing { } {
  global Spacing domCons domNodes oppSpacing dom_A
  set domNodes [list]
  set edgeCount [$dom_A getEdgeCount]

  # Loop through all Edges
  for { set i 0 } { $i<$edgeCount } { incr i } {
    set edge [$dom_A getEdge [expr $i+1]]
    set conCount [$edge getConnectorCount]

    # Create a full list of connectors
    for { set j 0 } { $j<$conCount } { incr j } {
      # Make sure they are of this domain
      lappend domCons [$edge getConnector [expr $j + 1]]
    }
  }

  # GET SPACINGS
  foreach con $domCons {
    # Get nodes of the connector
    set nodes [$con getNode 1]
    lappend nodes [$con getNode 2]

    # Loop through nodes
    foreach node $nodes {
      # Check for null sets (no adjacent connectors)
      if { ! [info exists Spacing(adj,$node)] } {
        set Spacing(adj,$node) [list]
      }

      if { ! [info exists Spacing(dom,$node)] } {
        set Spacing(dom,$node) [list]
      }

      # Make sure the node has not already been accounted for
      if { [lsearch $domNodes $node] == -1 } {
        lappend domNodes $node

        set nodeCons [$node getConnectors]

        # For each connector on the node
        foreach ncon $nodeCons {
          # ADJACENT CONNECTORS-------
          # Get actual name of the con
          set nconName [$ncon getName]
          set oppSpacing($node,$nconName) [list]

          if { [lsearch $domCons $ncon] == -1 } {
            set subConCount [$ncon getSubConnectorCount]

            # See if this connector's beginning node is the right node
            # (The one on the dom)
            if { [[$ncon getNode Begin] equals $node] } {
              set tSpace [[[$ncon getDistribution 1] getBeginSpacing] getValue]

              if { $tSpace == 0.0 } {
                # If the spacing doesn't exist, calculate it
                lappend Spacing(adj,$node) [getActualSpacing $ncon 1]
              } else {
                lappend Spacing(adj,$node) $tSpace
              }

              # Save opposite spacing
              set oppSpacing($node,$nconName) \
                [[[$ncon getDistribution 1] getEndSpacing] getValue]

            # See if this connector's ending node is the right node
            # (The one on the dom)
            } else {

              set tSpace \
                [[[$ncon getDistribution $subConCount] getEndSpacing] getValue]

              if { $tSpace == 0.0 } {
                # If the spacing doesn't exist, calculate it
                set dim [$ncon getDimension]
                set Spacing(adj,$node) [getActualSpacing $ncon $dim]
              } else {
                lappend Spacing(adj,$node) $tSpace
              }

              # Save opposite spacing
              set oppSpacing($node,$nconName) \
                [[[$ncon getDistribution $subConCount] getBeginSpacing] \
                  getValue]
            }

          # DOMAIN CONNECTORS-------
          } else {
            set subConCount [$ncon getSubConnectorCount]

            # Check if the beginning node is the correct node
            if { [[$ncon getNode Begin] equals $node] } {

              set tSpace [[[$ncon getDistribution 1] getBeginSpacing] getValue]

              if { $tSpace == 0.0 } {
                set Spacing(dom,$node) [getActualSpacing $ncon 1]
              } else {
                lappend Spacing(dom,$node) $tSpace
              }
              # Save opposite spacing
              set oppSpacing($node,$nconName) \
                [[[$ncon getDistribution 1] getEndSpacing] getValue]

            # Check if the ending node is the correct node
            } else {
              set tSpace \
                [[[$ncon getDistribution $subConCount] getEndSpacing] getValue]

              if { $tSpace == 0.0 } {
                # If the spacing doesn't exist, calculate it
                set dim [$ncon getDimension]
                set Spacing(dom,$node) [getActualSpacing $ncon $dim]
              } else {
                lappend Spacing(dom,$node) $tSpace
              }
              # Save opposite spacing
              set oppSpacing($node,$nconName) [
                [[$ncon getDistribution $subConCount] getBeginSpacing] \
                getValue]
            }
          }
        }
      }
    }
  }
}


# _____________________________________________________________________________
#
#                            CREATE DISTRIBUTIONS
# _____________________________________________________________________________

proc createDist { ncon node nconName subConCount avgSpacing } {

  global oppSpacing dist distDom
  if { $subConCount == 1 } {

    if { ! [info exists distDom($nconName)] } {
       set distDom($nconName) [pw::DistributionTanh create]
    }

    if { [[$ncon getNode 1] equals $node] } {
      # Must make a different dist array for cons w/ no subs
      $distDom($nconName) setBeginSpacing $avgSpacing

    } else {
      $distDom($nconName) setEndSpacing $avgSpacing
    }
  } else {    ;# $subConCount>1
    if { ! [info exists dist($node,$nconName)] } {
      set dist($node,$nconName) [pw::DistributionTanh create]
    }

    if { [[$ncon getNode Begin] equals $node] } {
      $dist($node,$nconName) setBeginSpacing $avgSpacing
      $dist($node,$nconName) setEndSpacing $oppSpacing($node,$nconName)
    } else {
      $dist($node,$nconName) setEndSpacing $avgSpacing
      $dist($node,$nconName) setBeginSpacing $oppSpacing($node,$nconName)
    }
  }
}


# ____________________ GET ACTUAL BREAK POINT SPACING ________________________

proc getBpSpac { con bpIndex loc curLoc} {
  set subConDim [$con getSubConnectorDimension $bpIndex]
  set curLoc [expr $curLoc + $subConDim - 1]

  set xyz [$con getXYZ $curLoc ]
  switch $loc {
    end {
      set xyz2 [$con getXYZ [expr $curLoc - 1]]
    }
    begin {
      set xyz2 [$con getXYZ [expr $curLoc + 1]]
    }
  }
  set spac [pwu::Vector3 length [pwu::Vector3 subtract $xyz2 $xyz]]

  return [list $spac $curLoc]
}


# _____________________________________________________________________________
#
#                              OK/CANCEL BUTTONS
# _____________________________________________________________________________

proc push_ok { } {
  global app avg Spacing domCons dom_A domNodes oppSpacing appSub dist \
    distDom saveColorMode saveColor

  # Reset the color of the domain, now that the button has been pressed
  setColor $saveColor $saveColorMode

  # Loop through nodes
  foreach node $domNodes {
    # CALCULATE AVERAGE SPACINGS-------
    set avgSpacing 0.0
    set count 0

    switch -exact $avg {
      avgDomain {
        # ON the Domain
        foreach space $Spacing(dom,$node) {
          set avgSpacing [expr $avgSpacing + $space]
          incr count
        }

        if { $count == 0 } {
          set avgSpacing 0.0
        } else {
          set avgSpacing [expr $avgSpacing/$count]
        }
      }

      avgAdjacent {
        # ADJACENT to domain
        foreach space $Spacing(adj,$node) {
          set avgSpacing [expr $avgSpacing + $space]
          incr count
        }

        if { $count != 0 } {
          set avgSpacing [expr $avgSpacing/$count]
        }
      }

      avgAll {
        # ALL connectors associated with domain
        # IF there are any adjacent spacings
        if { [llength $Spacing(adj,$node)] > 0 } {
          foreach space $Spacing(adj,$node) {
            set avgSpacing [expr $avgSpacing + $space]
            incr count
          }
        }

        foreach space $Spacing(dom,$node) {
          set avgSpacing [expr $avgSpacing + $space]
            incr count
        }

        if { $count == 0 } {
          set avgSpacing 0.0 ;
        } else {
          set avgSpacing [expr $avgSpacing/$count]
        }
      }
    }

    # FIND NEW DISTRIBUTIONS BASED ON AVG SPACING

    set nodeCons [$node getConnectors]

    # Loop through connectors
    foreach ncon $nodeCons {
      # Get the actual name of the con
      set nconName [$ncon getName]
      set subConCount [$ncon getSubConnectorCount]
      incr count

      switch -exact $app {
        appAdjacent {
          # ADJACENT to the Domain
          if { [lsearch $domCons $ncon] == -1 } {
             # Create the adjCons list for use in Modify mode
            lappend adjCons $ncon
            createDist $ncon $node $nconName $subConCount $avgSpacing
          }
        }

        appDomain {
          # ON the Domain
          if { [lsearch $domCons $ncon] != -1 } {
            createDist $ncon $node $nconName $subConCount $avgSpacing
          }
        }

        appAll {
          # ALL connectors associated with domain
          # Create the allCons list for use in Modify mode
          lappend allCons $ncon

          if { [lsearch $domCons $ncon] == -1 } {
            # All ADJACENT connectors
            createDist $ncon $node $nconName $subConCount $avgSpacing
          } else {
            # All DOMAIN connectors
            createDist $ncon $node $nconName $subConCount $avgSpacing
          }
        }
      }
    }
  }

  #  APPLY NEW DISTRIBUTIONS TO CONNECTORS

  # Set Modify mode
  switch -exact $app {
    appAdjacent {
      set conMod [pw::Application begin Modify $adjCons]
    }
    appDomain {
      set conMod [pw::Application begin Modify $domCons]
    }
    appAll {
      set conMod [pw::Application begin Modify $allCons]
    }
  }

  # Loop through nodes
  foreach node $domNodes {
    set nodeCons [$node getConnectors]

    foreach ncon $nodeCons {
      # Get the actual name of the con
      set nconName [$ncon getName]
      set subConCount [$ncon getSubConnectorCount]

      # Check for subconnectors, whether the dist exists, and whether there
      # are actually any adjacent connectors at all
      if { [llength $Spacing(adj,$node)] > 0 } {
        if { $subConCount == 1 && [info exists distDom($nconName)] } {
          $ncon setDistribution 1 $distDom($nconName)
        } elseif { [info exists dist($node,$nconName)] } {
          if { [[$ncon getNode 1] equals $node] } {
            $ncon setDistribution 1 $dist($node,$nconName)
          } else {
            $ncon setDistribution $subConCount $dist($node,$nconName)
          }
        }
      }
    }
  }

  # If the user wants to avg anything on the selected domain we can also
  # alter any break point spacings
  if { $app != "appAdjacent" && $appSub } {
    foreach con $domCons {
      set subConCount [$con getSubConnectorCount]
      set pos 0.0
      set curLoc 1

      for { set i 1 } { $i < [expr $subConCount] } { incr i } {
        # Snag the spacing on either side of the subconnector
        set s1 [[[$con getDistribution $i] getEndSpacing] getValue]
        set s2 [[[$con getDistribution [expr $i + 1]] getBeginSpacing] getValue]

        # Get actual spacings at breakpoints if not explicit
        if { $s1 == 0.0 } {
          set pair [getBpSpac $con $i "end" $curLoc]
          set s1 [lindex $pair 0]
          set curLoc [lindex $pair 1]
        }
        if { $s2 == 0.0 } {
          set pair [getBpSpac $con $i "begin" $curLoc]
          set s2 [lindex $pair 0]
          set curLoc [lindex $pair 1]
        }
        set avgSpacing [expr ($s1 + $s2 ) / 2]

        $con setBreakPointSpacing $i $avgSpacing
      }
    }
  }
  $conMod end
  unset conMod
  exit
}

# ______________________________ CANCEL BUTTON ________________________________

proc push_cancel { } {
  global saveColor saveColorMode dom_A
  # Reset the color of the domain, now that the button has been pressed
  if { $dom_A != ""} {
    setColor $saveColor $saveColorMode
  }
  exit
}


# _____________________________________________________________________________
#
#                               GUI CONTROLS
# _____________________________________________________________________________

proc makeWindow { } {
  wm title . "Average Spacing Utility"

  frame .but
  frame .right
  frame .top

  # give frames to geometry manager
  grid .top -row 1 -column 1 -sticky nsew -padx 10
  grid [labelframe .tleft -text "Average the endpoint spacing of" \
    -padx 5 -pady 5] -padx 10 -sticky ew
  grid [labelframe .bleft -text "Apply average spacing to endpoints of" \
    -padx 5 -pady 5] -padx 10 -sticky ew
  grid [labelframe .b -text "Options" -padx 9 -pady 6 ] -padx 10 -sticky ew

  wm title . "Average Connector Spacings"
  label .top.title -text "Average Connector Spacings" -justify center
  set font [.top.title cget -font]
  set fontSize [font actual $font -size]
  set wfont [font create -family [font actual $font -family] -weight bold \
    -size [expr {int(1.5 * $fontSize)}]]
  .top.title configure -font $wfont
  pack .top.title -side top

  global app avg appSub

  # CREATE WIDGETS FOR OUR APPLICATION

  # left top
  radiobutton .tleft.avgInside \
    -text "Connectors in the domain's edges" -variable avg -value avgDomain
  radiobutton .tleft.avgAdjacent \
    -text "Connectors emanating from (touching) the domain's edges" \
    -variable avg -value avgAdjacent
  radiobutton .tleft.avgAll -text "Average all spacings" -variable avg \
    -value avgAll
  .tleft.avgAll select

  # left bottom
  radiobutton .bleft.appInside -text "Connectors in the domain's edges" \
    -variable app -value appDomain
  radiobutton .bleft.appAdjacent \
    -text "Connectors emanating from (touching) the domain's edges" \
    -variable app -value appAdjacent
  radiobutton .bleft.appAll \
    -text "All connectors associated with the selected domain" -variable app \
    -value appAll
  .bleft.appAll select

  # bottom
  checkbutton .b.subCons -text "Include breakpoint spacings" -variable appSub
  .b.subCons select

  # buttons
  pack [button .but.cancel -text Cancel -command { push_cancel }] \
    -side right -padx 5
  pack [button .but.ok -text OK -command { push_ok }] \
    -side right -padx 5
  pack [label .but.logo -image [pwLogo] -bd 0 -relief flat] \
    -side left -padx 5

  # ADDING WIDGETS TO GEOMETRY MANAGER

  # left top
  grid .tleft -in . -row 2 -column 1 -sticky ew
  grid .tleft.avgInside -in .tleft -row 1 -column 1 -sticky w
  grid .tleft.avgAdjacent -in .tleft -row 2 -column 1 -sticky w
  grid .tleft.avgAll -in .tleft -row 3 -column 1 -sticky w

  # left bottom
  grid .bleft -in . -row 3 -column 1 -sticky ew
  grid .bleft.appInside -in .bleft -row 1 -column 1 -sticky w
  grid .bleft.appAdjacent -in .bleft -row 2 -column 1 -sticky w
  grid .bleft.appAll -in .bleft -row 3 -column 1 -sticky w

  # Bottom
  grid .b -in . -row 4 -column 1
  grid .b.subCons -in .b -row 1 -column 1

  # buttons
  grid .but -in . -row 5 -column 1 -ipady 5 -padx 5 -sticky ew
}


# _____________________________________________________________________________
#
#                           USER DOMAIN SELECTION
# _____________________________________________________________________________

proc selectDomain { } {
  set mask [pw::Display createSelectionMask -requireDomain Defined]
  set desc "Please select the domain \
      spacing constraints you would like to alter."

  pw::Display selectEntities -selectionmask $mask -single -description \
      $desc result

  global saveColor dom_A saveColorMode
  set dom_A $result(Domains)

  set saveColor [$dom_A getColor]
  set saveColorMode [$dom_A getRenderAttribute ColorMode]
  set lightBlue "0x00BBFFFF"
  $dom_A setColor $lightBlue
  $dom_A setRenderAttribute ColorMode Entity
  pw::Display update

  # Call getCurrentSpacing procedure
  getCurrentSpacing
}

# ______________________________POINTWISE LOGO_________________________________

proc pwLogo { } {
  set logoData "
  R0lGODlheAAYAIcAAAAAAAICAgUFBQkJCQwMDBERERUVFRkZGRwcHCEhISYmJisrKy0tLTIyMjQ0
  NDk5OT09PUFBQUVFRUpKSk1NTVFRUVRUVFpaWlxcXGBgYGVlZWlpaW1tbXFxcXR0dHp6en5+fgBi
  qQNkqQVkqQdnrApmpgpnqgpprA5prBFrrRNtrhZvsBhwrxdxsBlxsSJ2syJ3tCR2siZ5tSh6tix8
  ti5+uTF+ujCAuDODvjaDvDuGujiFvT6Fuj2HvTyIvkGKvkWJu0yUv2mQrEOKwEWNwkaPxEiNwUqR
  xk6Sw06SxU6Uxk+RyVKTxlCUwFKVxVWUwlWWxlKXyFOVzFWWyFaYyFmYx16bwlmZyVicyF2ayFyb
  zF2cyV2cz2GaxGSex2GdymGezGOgzGSgyGWgzmihzWmkz22iymyizGmj0Gqk0m2l0HWqz3asznqn
  ynuszXKp0XKq1nWp0Xaq1Hes0Xat1Hmt1Xyt0Huw1Xux2IGBgYWFhYqKio6Ojo6Xn5CQkJWVlZiY
  mJycnKCgoKCioqKioqSkpKampqmpqaurq62trbGxsbKysrW1tbi4uLq6ur29vYCu0YixzYOw14G0
  1oaz14e114K124O03YWz2Ie12oW13Im10o621Ii22oi23Iy32oq52Y252Y+73ZS51Ze81JC625G7
  3JG825K83Je72pW93Zq92Zi/35G+4aC90qG+15bA3ZnA3Z7A2pjA4Z/E4qLA2KDF3qTA2qTE3avF
  36zG3rLM3aPF4qfJ5KzJ4LPL5LLM5LTO4rbN5bLR6LTR6LXQ6r3T5L3V6cLCwsTExMbGxsvLy8/P
  z9HR0dXV1dbW1tjY2Nra2tzc3N7e3sDW5sHV6cTY6MnZ79De7dTg6dTh69Xi7dbj7tni793m7tXj
  8Nbk9tjl9N3m9N/p9eHh4eTk5Obm5ujo6Orq6u3t7e7u7uDp8efs8uXs+Ozv8+3z9vDw8PLy8vL0
  9/b29vb5+/f6+/j4+Pn6+/r6+vr6/Pn8/fr8/Pv9/vz8/P7+/gAAACH5BAMAAP8ALAAAAAB4ABgA
  AAj/AP8JHEiwoMGDCBMqXMiwocOHECNKnEixosWLGDNqZCioo0dC0Q7Sy2btlitisrjpK4io4yF/
  yjzKRIZPIDSZOAUVmubxGUF88Aj2K+TxnKKOhfoJdOSxXEF1OXHCi5fnTx5oBgFo3QogwAalAv1V
  yyUqFCtVZ2DZceOOIAKtB/pp4Mo1waN/gOjSJXBugFYJBBflIYhsq4F5DLQSmCcwwVZlBZvppQtt
  D6M8gUBknQxA879+kXixwtauXbhheFph6dSmnsC3AOLO5TygWV7OAAj8u6A1QEiBEg4PnA2gw7/E
  uRn3M7C1WWTcWqHlScahkJ7NkwnE80dqFiVw/Pz5/xMn7MsZLzUsvXoNVy50C7c56y6s1YPNAAAC
  CYxXoLdP5IsJtMBWjDwHHTSJ/AENIHsYJMCDD+K31SPymEFLKNeM880xxXxCxhxoUKFJDNv8A5ts
  W0EowFYFBFLAizDGmMA//iAnXAdaLaCUIVtFIBCAjP2Do1YNBCnQMwgkqeSSCEjzzyJ/BFJTQfNU
  WSU6/Wk1yChjlJKJLcfEgsoaY0ARigxjgKEFJPec6J5WzFQJDwS9xdPQH1sR4k8DWzXijwRbHfKj
  YkFO45dWFoCVUTqMMgrNoQD08ckPsaixBRxPKFEDEbEMAYYTSGQRxzpuEueTQBlshc5A6pjj6pQD
  wf9DgFYP+MPHVhKQs2Js9gya3EB7cMWBPwL1A8+xyCYLD7EKQSfEF1uMEcsXTiThQhmszBCGC7G0
  QAUT1JS61an/pKrVqsBttYxBxDGjzqxd8abVBwMBOZA/xHUmUDQB9OvvvwGYsxBuCNRSxidOwFCH
  J5dMgcYJUKjQCwlahDHEL+JqRa65AKD7D6BarVsQM1tpgK9eAjjpa4D3esBVgdFAB4DAzXImiDY5
  vCFHESko4cMKSJwAxhgzFLFDHEUYkzEAG6s6EMgAiFzQA4rBIxldExBkr1AcJzBPzNDRnFCKBpTd
  gCD/cKKKDFuYQoQVNhhBBSY9TBHCFVW4UMkuSzf/fe7T6h4kyFZ/+BMBXYpoTahB8yiwlSFgdzXA
  5JQPIDZCW1FgkDVxgGKCFCywEUQaKNitRA5UXHGFHN30PRDHHkMtNUHzMAcAA/4gwhUCsB63uEF+
  bMVB5BVMtFXWBfljBhhgbCFCEyI4EcIRL4ChRgh36LBJPq6j6nS6ISPkslY0wQbAYIr/ahCeWg2f
  ufFaIV8QNpeMMAkVlSyRiRNb0DFCFlu4wSlWYaL2mOp13/tY4A7CL63cRQ9aEYBT0seyfsQjHedg
  xAG24ofITaBRIGTW2OJ3EH7o4gtfCIETRBAFEYRgC06YAw3CkIqVdK9cCZRdQgCVAKWYwy/FK4i9
  3TYQIboE4BmR6wrABBCUmgFAfgXZRxfs4ARPPCEOZJjCHVxABFAA4R3sic2bmIbAv4EvaglJBACu
  IxAMAKARBrFXvrhiAX8kEWVNHOETE+IPbzyBCD8oQRZwwIVOyAAXrgkjijRWxo4BLnwIwUcCJvgP
  ZShAUfVa3Bz/EpQ70oWJC2mAKDmwEHYAIxhikAQPeOCLdRTEAhGIQKL0IMoGTGMgIBClA9QxkA3U
  0hkKgcy9HHEQDcRyAr0ChAWWucwNMIJZ5KilNGvpADtt5JrYzKY2t8nNbnrzm+B8SEAAADs="

  return [image create photo -format GIF -data $logoData]
}


# Select Domain

if [catch { selectDomain } msg] {
  push_cancel
}


# Create Application window
makeWindow
::tk::PlaceWindow . widget

# process Tk events until the window is destroyed
tkwait window .


# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE
# FAULT OR NEGLIGENCE OF POINTWISE.
#
