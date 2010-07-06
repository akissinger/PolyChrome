#!/bin/bash
### EDIT THIS!! ################################################################
# make sure this is the profile you will be using the extension with
ff_profile=/home/karolis/.mozilla/firefox/umv7jzqu.Dev
################################################################################


#the directory of the extension
extension=`dirname $0`
cd $extension
extension=`pwd`

#build the polyml binary and place it into the right location
if [ "$1" == "build" ]
then
cd poly
echo "use \"build.ml\";" | poly
if [ ! -e bin/PolyMLext.o ]; then echo "Error compiling the PolyML program"; exit; fi
cd bin
ls
cc -o PolyMLext PolyMLext.o -lpolymain -lpolyml
rm PolyMLext.o
mv PolyMLext ../../polymlext/poly/
cd ../..
fi


#update the extension file and move it to firefox profile
echo "$extension/polymlext" > polymlext@ed.ac.uk
cp polymlext@ed.ac.uk $ff_profile/extensions/


#remove these files to make firefox reregister the updated component
if [ -e $ff_profile/xpti.dat ]; then rm "$ff_profile/xpti.dat"; fi
if [ -e $ff_profile/compreg.dat ]; then rm "$ff_profile/compreg.dat"; fi


#if run is passed as a parameter run firefox
if [ "$1" == "run" ]
then
#NSPR_LOG_MODULES=all:5 firefox
#NSPR_LOG_MODULES=PolyMLDOMModule:5 firefox
firefox
fi