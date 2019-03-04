#!/bin/bash

###############
# GRASS SETUP #
###############

echo "...GRASS setup..."
# path to GRASS binaries and libraries:
export GISBASE=/usr/lib/grass74
export PATH=$PATH:$GISBASE/bin:$GISBASE/scripts
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$GISBASE/lib

# set PYTHONPATH to include the GRASS Python lib
if [ ! "$PYTHONPATH" ] ; then
   PYTHONPATH="$GISBASE/etc/python"
else
   PYTHONPATH="$GISBASE/etc/python:$PYTHONPATH"
fi
export PYTHONPATH

# use process ID (PID) as lock file number:
export GIS_LOCK=$$

# settings for graphical output to PNG file (optional)
export GRASS_PNGFILE=/tmp/grass6output.png
export GRASS_TRUECOLOR=TRUE
export GRASS_WIDTH=900
export GRASS_HEIGHT=1200
export GRASS_PNG_COMPRESSION=1
export GRASS_MESSAGE_FORMAT=plain

# path to GRASS settings file
export GISRC=$HOME/.grassrc7

# path to GRASS settings file
export GISRC=/tmp/grass7-${USER}-$GIS_LOCK/gisrc
# remove any leftover files/folder
rm -fr /tmp/grass7-${USER}-$GIS_LOCK
mkdir /tmp/grass7-${USER}-$GIS_LOCK
export TMPDIR="/tmp/grass7-${USER}-$GIS_LOCK"
# set GISDBASE, LOCATION_NAME, and/or MAPSET
echo "GISDBASE: /home/mario.nunez/script/grass" >>$GISRC
echo "LOCATION_NAME: location" >>$GISRC
echo "MAPSET: PERMANENT" >>$GISRC
# start in text mode
echo "GRASS_GUI: text" >>$GISRC


###########################
# VEGETATION SCRIPT START #
###########################
echo "...Urban Atlas data extraction..."

LAYER="vegetation"
FILE1="../data/UA_IT003L3_NAPOLI/Shapefiles/IT003L3_NAPOLI_UA2012.shp"
SHP=`ogrinfo $FILE1 | grep '1:' | cut -f 2 -d ' '`
NAME=$SHP"_"$LAYER

#PARAMETERS
PARAMETERS="../parameters"
ALBEDO=`grep -i -F [$LAYER] $PARAMETERS/albedo.dat | cut -f 2 -d ' '`
EMISSIVITY=`grep -i -F [$LAYER] $PARAMETERS/emissivity.dat | cut -f 2 -d ' '`
TRANSMISSIVITY=`grep -i -F [$LAYER] $PARAMETERS/transmissivity.dat | cut -f 2 -d ' '`
VEGETATION_SHADOW=`grep -i -F [$LAYER] $PARAMETERS/vegetation_shadow.dat | cut -f 2 -d ' '`
RUNOFF_COEFFICIENT=`grep -i -F [$LAYER] $PARAMETERS/run_off_coefficient.dat | cut -f 2 -d ' '`

#URBAN ATLAS (14100 gren urban areas, 14200 sport and leisure facilities, 32000 herbaceous vegetation, 33000 Open spaces with little or no vegetations)
ogr2ogr -sql "SELECT area,perimeter FROM "$SHP" WHERE CODE2012='14100' OR CODE2012='14200' OR CODE2012='32000' OR CODE2012='33000'" $NAME $FILE1
shp2pgsql -s 3035 -I -S -d $NAME/$SHP.shp $NAME > $NAME".sql"
rm -r $NAME
psql -d clarity -U postgres -f $NAME".sql"
rm $NAME".sql"

#ESM RASTER
echo "...ESM raster reclassifying..."
FILE2="../data/N20E46/class_40/200km_10m_N20E46_class40.TIF"
#FILE2=$2
NAME2=`echo $FILE2 | rev | cut -f 1 -d '/' | rev | cut -f 1 -d '.'`
#raster reclassification with treshold 25
TIF=$NAME"_calculated.TIF"
SHP2=$NAME"_calculated.shp"
NODATA=`gdalinfo $FILE2 | grep 'NoData' | cut -f 2 -d '='`
python gdal_reclassify.py $FILE2 $TIF -r "$NODATA,1" -c "<25,>=25" -d $NODATA -n true -p "COMPRESS=LZW"
##raster to shapefile polygonization using grass
##gdal_polygonize.py -b 1 $TIF -f "ESRI Shapefile" $SHP2 vegetation value
LAT=`gdalinfo $TIF | grep 'latitude_of_center' | cut -f 2 -d ',' | cut -f 1 -d ']'`
LON=`gdalinfo $TIF | grep 'longitude_of_center' | cut -f 2 -d ',' | cut -f 1 -d ']'`
X=`gdalinfo $TIF | grep 'false_easting' | cut -f 2 -d ',' | cut -f 1 -d ']'`
Y=`gdalinfo $TIF | grep 'false_northing' | cut -f 2 -d ',' | cut -f 1 -d ']'`
N=`gdalinfo $TIF | grep 'Upper Left' | cut -f 6 -d ' ' | cut -f 1 -d ')'`
S=`gdalinfo $TIF | grep 'Lower Right' | cut -f 5 -d ' ' | cut -f 1 -d ')'`
E=`gdalinfo $TIF | grep 'Lower Right' | cut -f 4 -d ' ' | cut -f 1 -d ','`
W=`gdalinfo $TIF | grep 'Upper Left' | cut -f 5 -d ' ' | cut -f 1 -d ','`
RES=`gdalinfo $TIF | grep 'Pixel Size' | cut -f 4 -d ' ' | cut -f 1 -d ',' | cut -f 2 -d '('`

#poligonization with grass
echo "...Poligonize with GRASS..."
g.proj -c proj4="+proj=laea +lat_0=$LAT +lon_0=$LON +x_0=$X +y_0=$Y +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs"
r.external input="$TIF" band=1 output=rast_5bd8903d0a6372 --overwrite -o
g.region n=$N s=$S e=$E w=$W res=$RES
r.to.vect input=rast_5bd8903d0a6372 type="area" column="value" output=output08aad7e15cf0402da3436e32ac40c6c9 --overwrite
v.out.ogr type="auto" input="output08aad7e15cf0402da3436e32ac40c6c9" output="$SHP2" format="ESRI_Shapefile" --overwrite
#result to databse
shp2pgsql -k -s 3035 -S -I -d $SHP2 $NAME2 > $NAME2.sql
psql -d clarity -U postgres -f $NAME2.sql
rm $NAME2.*
psql -U "postgres" -d "clarity" -c "insert into "$NAME" (select nextval('"$NAME"_gid_seq'), ST_Perimeter(geom), ST_Area(geom) from public.\""$NAME2"\");"
psql -U "postgres" -d "clarity" -c "DROP TABLE public.\""$NAME2"\";"

#adding rest of the parameters
echo "...Adding rest of parameters..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD albedo real DEFAULT "$ALBEDO";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD emissivity real DEFAULT "$EMISSIVITY";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD transmissivity real DEFAULT "$TRANSMISSIVITY";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD vegetation_shadow real DEFAULT "$VEGETATION_SHADOW";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD run_off_coefficient real DEFAULT "$RUNOFF_COEFFICIENT";"

#building shadow 1 by default(not interseccting) then update with value 0 when intersecting
echo "...Adding bulding shadow..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD building_shadow smallint DEFAULT 1;"
psql -U "postgres" -d "clarity" -c "UPDATE public.\""$NAME"\" x SET building_shadow=0 FROM "$SHP"_layers9_12 l WHERE ST_Intersects( x.geom , l.geom ) IS TRUE;"

#Clusterization
echo "...Clusterizing..."
#psql -U "postgres" -d "clarity" -c "CLUSTER public.\""$NAME"\" USING public.\""$NAME"\"_pkey;"

#FALTA VOLCAR SOBRE TABLA ROADS GLOBAL Y BORRAR LA TABLA ROADS DEL SHAPEFILE ACTUAL(ITALIA-NAPOLES)
##psql -U "postgres" -d "clarity" -c "INSERT INTO vegetation (SELECT NEXTVAL('vegetation_gid_seq'), area, perimeter, geom, albedo, emissivity, transmissivity, vegetation_shadow, run_off_coefficient, building_shadow FROM "$NAME");"
##psql -U "postgres" -d "clarity" -c "DROP TABLE "$NAME";"