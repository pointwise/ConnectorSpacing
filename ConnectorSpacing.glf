#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################

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
  pack [label .but.logo -image [cadenceLogo] -bd 0 -relief flat] \
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

# ________________________CADENCE DESIGN SYSTEMS LOGO__________________________

proc cadenceLogo { } {
  set logoData "
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7"

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


#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
