ConnectorSpacing
===============
Copyright 2021 Cadence Design Systems, Inc. All rights reserved worldwide.

This script is a tool for making the grid spacing around the perimeter of the selected domain consistent with its neighboring domains. As shown in the image of the script's user interface, you are given three sets of options.

1. Which spacings are to be averaged
    * Ones on the connectors in the selected domain
    * Ones on the connectors in the selected domain's neighbors
    * All spacings on connectors in the selected domain and its neighbors
2. Where the average spacing is to be applied
    * On the connectors in the selected domain
    * On connectors in the neighboring domains
    * On connectors in the selected domain and its neighbors
3. Whether or not to include spacing at break points (as opposed to only spacings at nodes)

![GUIImage](https://raw.github.com/pointwise/ConnectorSpacing/master/ConnectorSpacing-Tk.png)

An illustration of the script's effects is shown below.

![GridImage](https://raw.github.com/pointwise/ConnectorSpacing/master/ConnectorSpacing-Grid.png)

Disclaimer
----------
This file is licensed under the Cadence Public License Version 1.0 (the "License"), a copy of which is found in the LICENSE file, and is distributed "AS IS." 
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE. 
Please see the License for the full text of applicable terms. 

