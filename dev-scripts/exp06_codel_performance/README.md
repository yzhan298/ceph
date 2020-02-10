## Testing CoDel with Raw Device (performance is important!!!)

In order to improve the performance, we need to do these things:

do\_cmake should have flag -DCMAKE\_BUILD\_TYPE=RelWithDebInfo to disable debug mode
vstart needs to specify the osd device
vstart should not use -d opthion

