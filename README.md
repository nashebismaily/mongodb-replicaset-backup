# MongoDB Replicaset Backup

This script will backup a MongoDB Replica Set

## Usage

/bin/bash mongodump_replicaset_backup.sh `<DBS>` `<HOST>` `<PORT>` `<COL>` `<BACKUP_SERVER>  

DBS: 		Database name or all  
HOST:		Mongo host  
PORT:		Mongo port  
COL: 		Mongo collection  
BACKUP_SERVER: 	Backup server name, it is optional parameter if you leave "" then it will take backup in same server  

## Author

Nasheb Ismaily
