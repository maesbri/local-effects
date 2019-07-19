#!/bin/bash
CODE="CODE2006"
VALUE="30000"
#CODE="CODE2012"
#VALUE="31000"

LAYER="trees"
if [[ $# -eq 0 ]] ; then
    echo -e "\e[33mERROR: No city name provided!\e[0m"
    exit 1
fi
CITY=$(echo "$1" | awk '{print toupper($0)}')
FOLDER_UA="data/"$CITY"/ua"
FILE_UA=`ls -la $FOLDER_UA/*.shp | cut -f 10 -d ' '`
SHP_UA=`ogrinfo $FILE_UA | grep '1:' | cut -f 2 -d ' '`
#NAME=$(echo $SHP_UA"_"$LAYER | awk '{print tolower($0)}')
NAME=$(echo $CITY"_"$LAYER | awk '{print tolower($0)}')

FOLDER_STL="data/"$CITY"/stl"
FILE_STL=`ls -la $FOLDER_STL/*.shp | cut -f 10 -d ' '`
SHP_STL=`ogrinfo $FILE_STL | grep '1:' | cut -f 2 -d ' '`

if [ ! "$FILE_UA" ] || [ ! "$FILE_STL" ]; then
    echo "ERROR: City data not found!"
else

#TREES URBAN ATLAS
#WATCH OUT CODE IS (31000 in UA2012 but it is 30000 in UA 2006)
echo "...Extract Urban Atlas data..."
#ogr2ogr -overwrite -sql "SELECT Shape_Area as area, Shape_Leng as perimeter FROM "$SHP_UA" WHERE "$CODE"='31000'" $NAME"_UA" $FILE_UA
ogr2ogr -overwrite -sql "SELECT Shape_Area as area FROM "$SHP_UA" WHERE "$CODE"='30000'" $NAME"_UA" $FILE_UA
shp2pgsql -k -s 3035 -I -d $NAME"_UA"/$SHP_UA.shp $NAME > $NAME"_UA.sql"
rm -r $NAME"_UA"
psql -d clarity -U postgres -f $NAME"_UA.sql"
rm $NAME"_UA.sql"

#trees STL
##MIRAR A VER SI ESTO ESTA ENTRANDO EN LA MISMA TABLA!!!!
echo "...Extract STL data..."
ogr2ogr -sql "SELECT Shape_Area as area FROM "$SHP_STL" WHERE STL=1" $NAME"_STL" $FILE_STL
shp2pgsql -k -s 3035 -I -a $NAME"_STL"/$SHP_STL.shp $NAME > $NAME"_STL.sql"
rm -r $NAME"_STL"
psql -d clarity -U postgres -f $NAME"_STL.sql"
rm $NAME"_STL.sql"

#GEOMETRY INTEGRITY CHECK
echo "...doing geometry integrity checks..."
psql -U "postgres" -d "clarity" -c "UPDATE "$NAME" SET geom=St_MakeValid(St_Multi(St_Buffer(geom,0.0001)));"
psql -U "postgres" -d "clarity" -c "SELECT * FROM "$NAME" WHERE NOT ST_Isvalid(geom);" > check.out
COUNT=`sed -n '3p' < check.out | cut -f 1 -d ' ' | cut -f 2 -d '('`
if [ $COUNT -gt 0 ];
then
        echo $COUNT "Problems found"
        echo "...deleting affected geometries to avoid further problems with them..."
        psql -U "postgres" -d "clarity" -c "DELETE FROM "$NAME" WHERE NOT ST_Isvalid(geom);"
fi
rm check.out

#ADD RELATION COLUMNS
echo "...adding relational columns..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD city integer;"
psql -U "postgres" -d "clarity" -c "SELECT id from city where name='"$CITY"';" > id.out
ID=`sed "3q;d" id.out | cut -f 3 -d ' '`
echo "ID CIUDAD:" $ID
rm id.out
psql -U "postgres" -d "clarity" -c "UPDATE "$NAME" SET city="$ID";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD CONSTRAINT "$NAME"_city_fkey FOREIGN KEY (city) REFERENCES city (id);"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD cell integer;"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD CONSTRAINT "$NAME"_cell_fkey FOREIGN KEY (cell) REFERENCES laea_etrs_500m (gid);"

#MAKING GOEMETRIES GRID LIKE
echo "...generating grided geometries..."
psql -U "postgres" -d "clarity" -c "SELECT to_regclass('public."$NAME"_grid');" > check.out
FOUND=`sed "3q;d" check.out | cut -f 2 -d ' '`
rm check.out
if [ $FOUND ];
then
        echo "...deleting old table..."
        psql -U "postgres" -d "clarity" -c "DROP TABLE "$NAME"_grid;"
fi
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" DROP COLUMN area;"
psql -U "postgres" -d "clarity" -c "CREATE TABLE "$NAME"_grid (LIKE "$NAME" INCLUDING ALL);"
psql -U "postgres" -d "clarity" -c "INSERT INTO "$NAME"_grid (geom,city,cell) (SELECT ST_Multi(ST_Intersection(ST_Union(a.geom), m.geom)) as geom,"$ID" as city, m.gid as cell FROM "$NAME" a, laea_etrs_500m m, city c WHERE c.name='"$CITY"' AND ST_Intersects(c.bbox,m.geom) AND ST_Intersects(a.geom, m.geom) GROUP BY m.geom,m.gid);"
psql -U "postgres" -d "clarity" -c "DROP TABLE "$NAME" CASCADE;"
NAME=$(echo $CITY"_"$LAYER"_GRID" | awk '{print tolower($0)}')

#PARAMETERS
PARAMETERS="parameters"
ALBEDO=`grep -i -F [$LAYER] $PARAMETERS/albedo.dat | cut -f 2 -d ' '`
EMISSIVITY=`grep -i -F [$LAYER] $PARAMETERS/emissivity.dat | cut -f 2 -d ' '`
TRANSMISSIVITY=`grep -i -F [$LAYER] $PARAMETERS/transmissivity.dat | cut -f 2 -d ' '`
VEGETATION_SHADOW=`grep -i -F [$LAYER] $PARAMETERS/vegetation_shadow.dat | cut -f 2 -d ' '`
RUNOFF_COEFFICIENT=`grep -i -F [$LAYER] $PARAMETERS/run_off_coefficient.dat | cut -f 2 -d ' '`

#remove intersections with previous layers
echo "...removing water intersections..."
psql -U "postgres" -d "clarity" -c "UPDATE "$NAME" set geom=sq.geom from (SELECT ST_Multi(ST_CollectionExtract(ST_Difference( ST_Union(t.geom),ST_Multi(ST_Intersection(ST_Union(t.geom),ST_Union(r.geom))) ),3 ) )  as geom, m.gid FROM "$NAME" t, water r, land_use_grid g, laea_etrs_500m m WHERE g.city=1 AND g.cell=m.gid AND m.gid=t.cell AND r.cell=t.cell GROUP BY m.gid,m.geom) sq where cell=sq.gid;"
echo "...removing roads intersections..."
psql -U "postgres" -d "clarity" -c "UPDATE "$NAME" set geom=sq.geom from (SELECT ST_Multi(ST_CollectionExtract(ST_Difference( ST_Union(t.geom),ST_Multi(ST_Intersection(ST_Union(t.geom),ST_Union(r.geom))) ),3 ) )  as geom, m.gid FROM "$NAME" t, roads r, land_use_grid g, laea_etrs_500m m WHERE g.city=1 AND g.cell=m.gid AND m.gid=t.cell AND r.cell=t.cell GROUP BY m.gid,m.geom) sq where cell=sq.gid;"
echo "...removing railways intersections..."
psql -U "postgres" -d "clarity" -c "UPDATE "$NAME" set geom=sq.geom from (SELECT ST_Multi(ST_CollectionExtract(ST_Difference( ST_Union(t.geom),ST_Multi(ST_Intersection(ST_Union(t.geom),ST_Union(r.geom))) ),3 ) )  as geom, m.gid FROM "$NAME" t, railways r, land_use_grid g, laea_etrs_500m m WHERE g.city=1 AND g.cell=m.gid AND m.gid=t.cell AND r.cell=t.cell GROUP BY m.gid,m.geom) sq where cell=sq.gid;"

#adding rest of parameters
echo "...Adding rest of parameters..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD albedo real DEFAULT "$ALBEDO";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD emissivity real DEFAULT "$EMISSIVITY";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD transmissivity real DEFAULT "$TRANSMISSIVITY";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD vegetation_shadow real DEFAULT "$VEGETATION_SHADOW";"
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD run_off_coefficient real DEFAULT "$RUNOFF_COEFFICIENT";"

#Adding FUA_TUNNEL, apply 1 as default
echo "...Adding FUA_TUNNEL..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD fua_tunnel real DEFAULT 1;"
FUA_TUNNEL=`grep -i -F ['dense_urban_fabric'] $PARAMETERS/fua_tunnel.dat | cut -f 2 -d ' '`
psql -U "postgres" -d "clarity" -c "UPDATE public.\""$NAME"\" x SET fua_tunnel="$FUA_TUNNEL" FROM "$CITY"_layers9_12 l WHERE ("$CODE"='11100' OR "$CODE"='11210') AND ST_Intersects( x.geom , l.geom );"
FUA_TUNNEL=`grep -i -F ['medium_urban_fabric'] $PARAMETERS/fua_tunnel.dat | cut -f 2 -d ' '`
psql -U "postgres" -d "clarity" -c "UPDATE public.\""$NAME"\" x SET fua_tunnel="$FUA_TUNNEL" FROM "$CITY"_layers9_12 l WHERE "$CODE"='11220' AND ST_Intersects( x.geom , l.geom );"

#building shadow 1 by default(not intersecting) then update with value 0 when intersecting
echo "...Adding building shadow..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD building_shadow smallint DEFAULT 1;"
psql -U "postgres" -d "clarity" -c "UPDATE public.\""$NAME"\" x SET building_shadow=0 FROM "$CITY"_layers9_12 l WHERE ST_Intersects( x.geom , l.geom );"

###HILLSHADE GREEN FRACTION, we do not know where to get tree type... so we set default value 0.37
echo "...Adding hillshade green fraction..."
psql -U "postgres" -d "clarity" -c "ALTER TABLE "$NAME" ADD hillshade_green_fraction real DEFAULT 0.37;"

#Clusterization
echo "...Clusterizing..."
#psql -U "postgres" -d "clarity" -c "CLUSTER public.\""$NAME"\" USING public.\""$NAME"\"_pkey;"

#TAKE EVERYTHING FROM CITY TABLE TO GENERAL TABLE
#psql -U "postgres" -d "clarity" -c "INSERT INTO trees (SELECT * FROM "$NAME");"
#psql -U "postgres" -d "clarity" -c "DROP TABLE "$NAME";"
fi