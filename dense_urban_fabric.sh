#!/bin/bash

LAYER="dense_urban_fabric"
FILE="data/UA_IT003L3_NAPOLI/Shapefiles/IT003L3_NAPOLI_UA2012.shp"
#FILE=$1
SHP=`ogrinfo $FILE | grep '1:' | cut -f 2 -d ' '`
NAME=$SHP"_"$LAYER

#PARAMETERS
ALBEDO=`grep -i -F [$LAYER] parameters/albedo.dat | cut -f 2 -d ' '`
EMISSIVITY=`grep -i -F [$LAYER] parameters/emissivity.dat | cut -f 2 -d ' '`
TRANSMISSIVITY=`grep -i -F [$LAYER] parameters/transmissivity.dat | cut -f 2 -d ' '`
RUNOFF_COEFFICIENT=`grep -i -F [$LAYER] parameters/run_off_coefficient.dat | cut -f 2 -d ' '`
CONTEXT=`grep -i -F [$LAYER] parameters/context.dat | cut -f 2 -d ' '`
FUA_TUNNEL=`grep -i -F [$LAYER] parameters/fua_tunnel.dat | cut -f 2 -d ' '`

#DENSE URBAN FABRIC (11100 continuous urban fabric, 11210 discontinuous dense urban fabric)
ogr2ogr -sql "SELECT area,perimeter FROM "$SHP" WHERE CODE2012='11100' OR CODE2012='11210'" $NAME $FILE
shp2pgsql -k -s 3035 -S -I -d $NAME/$SHP.shp $NAME > $NAME".sql"
rm -r $NAME
psql -d clarity -U postgres -f $NAME".sql"
rm $NAME".sql"
#adding rest of the parameters
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD albedo real DEFAULT "$ALBEDO";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD emissivity real DEFAULT "$EMISSIVITY";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD transmissivity real DEFAULT "$TRANSMISSIVITY";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD run_off_coefficient real DEFAULT "$RUNOFF_COEFFICIENT";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD context real DEFAULT "$CONTEXT";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD fua_tunnel real DEFAULT "$FUA_TUNNEL";"

#Clusterization
#psql -U "postgres" -d "clarity" -c "CLUSTER public.\""$NAME"\" USING public.\""$NAME"\"_pkey;"

#FALTA VOLCAR SOBRE TABLA ROADS GLOBAL Y BORRAR LA TABLA ROADS DEL SHAPEFILE ACTUAL(ITALIA-NAPOLES)
#psql -U "postgres" -d "clarity" -c "INSERT INTO dense_urban_fabric(SELECT NEXTVAL('dense_urban_frabric_gid_seq'), area, perimeter, code2012, geom, albedo, emissivity, transmissivity, run_off_coedfficient, context, fua_tunnel FROM "$NAME");"
#psql -U "postgres" -d "clarity" -c "DROP TABLE "$NAME";"
