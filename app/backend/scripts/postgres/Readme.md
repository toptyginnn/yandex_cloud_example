# Database
## Connect
psql "dbname=**dbname** user=postgres password=postgres host=postgres port=5432" <br />
## Backup
pg_dump -h postgres -U postgres -f ~/backup.sql  -Fc **dbname** <br />
## Restore
pg_restore  -h localhost -U postgres -d **dbname** -v ~/backup.sql <br />
## Scp from server
scp user@**ip**:**path**/backup.sql ~/backup.sql <br />