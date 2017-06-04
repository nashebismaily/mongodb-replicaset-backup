#!/bin/bash
##########################################
# pass source and destinations
# Compulsory parameters, which need to run the scripts
# Database name or all
#
# Author::  Nasheb Ismaily
#
# All rights reserved - Do Not Redistribute

## Variables ##
MONGO_DBS="$1"
# Mongo host name
MONGO_HOST="$2"
# Mongo port
MONGO_PORT="$3"
# Mongo Collection
MONGO_COL="$4"
# Backup server name, it is optional parameter if you leave "" then it will take backup in same server
BACKUP_SERVER="$5"


#optional Parameters
BACKUP_TMP=~/tmp
BACKUP_DEST=/backups
MONGODUMP_BIN=mongodump
TAR_BIN=/bin/tar

# source mongo install path

. ~mongo/mongo.env
##########################################
BACKUPFILE_DATE=`date +%Y%m%d-%H%M`
# _do_store_archive <Database> <Dump_dir> <Dest_Dir> <Dest_file>
function _do_store_archive {
mkdir -p $3
cd $2
tar -cvzf $3/$4 dump
}

# find  secoundry  replica copy
function select_secondary_member {

    # Return list of with all replica set members
    members=( $(mongo --quiet --host $MONGO_HOST:$MONGO_PORT --eval 'rs.conf().members.forEach(function(x){ print(x.host) })') )

    # Check each replset member to see if it's a secondary and return it.

if [ ${#members[@]} -gt 1 ]; then
   for member in "${members[@]}"; do

      is_secondary=$(mongo --quiet --host $member --eval 'rs.isMaster().secondary')
            case "$is_secondary" in
                'true') # First secondary wins ...
                    secondary=$member
                    break
                ;;
                'false') # Skip particular member if it is a Primary.
                    continue
                ;;
                *) # Skip irrelevant entries. Should not be any anyway ...
                    continue
                ;;
            esac
   done
fi

}


# _do_backup <Database name>
function _do_backup {
UNIQ_DIR="$BACKUP_TMP/$1"`date "+%s"`
OPLOG_DIR="$BACKUP_DEST/oplog"/`date "+%s"`
mkdir -p $UNIQ_DIR/dump
mkdir -p /tmp/oplog/dump
mkdir -p $OPLOG_DIR
echo "dumping Mongo Database $1"

select_secondary_member secondary

echo " #####################################################"
echo "using secondary  " $secondary "replica set for  backup"
echo "######################################################"

if [ -n "$secondary" ]; then
        DBHOST=${secondary%%:*}
        DBPORT=${secondary##*:}
   else
        SECONDARY_WARNING="WARNING: No suitable Secondary found in the Replica Sets. Falling back to ${DBHOST}."
 fi

if [ "all" = "$1" ]; then
  # fsynclock selected  secondary  member to  get  point in time  recover
   mongo --host $DBHOST --port $DBPORT --eval "printjson(db.fsyncLock())"
  # mongodump
   $MONGODUMP_BIN -h $DBHOST:$DBPORT --oplog -o $UNIQ_DIR/dump

   if [ ERRCODE=$? ]; then
      $MONGODUMP_BIN --host $DBHOST --port $DBPORT -d local -c oplog.rs -o /tmp/oplog/dump
      mv /tmp/oplog/dump/local/oplog.rs.bson /tmp/oplog/dump/local/oplog.bson
      mv /tmp/oplog/dump/local/oplog.bson $OPLOG_DIR
      rm -rf /tmp/oplog/
   fi
else
   # fsynclock selected  secondary  member to  get  point in time  recover
   mongo --host $DBHOST --port $DBPORT --eval "printjson(db.fsyncLock())"


        if [ -n "$MONGO_COL" ];  then
        # mongodump
        $MONGODUMP_BIN -h $DBHOST:$DBPORT -d $1 -c MONGO_COL -o $UNIQ_DIR/dump
        else
        $MONGODUMP_BIN -h $DBHOST:$DBPORT -d $1 -o $UNIQ_DIR/dump
        fi
fi

 #unlock  fsync
 mongo --host $DBHOST --port $DBPORT --eval "printjson(db.fsyncUnlock())"

KEY="database-$BACKUPFILE_DATE.tgz"

echo "Archiving Mongo database to $BACKUP_DEST/$1/$KEY"

DEST_DIR=$BACKUP_DEST/$1
_do_store_archive $1 $UNIQ_DIR $DEST_DIR $KEY
rm -rf $UNIQ_DIR


if [ "" = "$BACKUP_SERVER" ]; then
 echo "Backup  rentension server site not  provide"
else
 echo "scp tar files to  backup  site"
 scp $DEST_DIR/$KEY  mongo@$BACKUP_SERVER:/backups
fi

}

# check to see if individual databases have been specified, otherwise backup the whole server
# to "all"
if [ "" = "$MONGO_DBS" ]; then
   MONGO_DB="all"
   _do_backup $MONGO_DB
else
   for MONGO_DB in $MONGO_DBS; do
   _do_backup $MONGO_DB
done
fi
