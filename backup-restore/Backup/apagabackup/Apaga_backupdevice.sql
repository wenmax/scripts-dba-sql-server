declare @devicebackup varchar(1000)

select @devicebackup = name 
from sys.backup_devices
where name like 'SCOServer_%'




select @devicebackup

EXEC sp_dropdevice @devicebackup --, 'delfile' ;  
GO 582

select name
from sys.backup_devices
where name like 'SCOServer_%'