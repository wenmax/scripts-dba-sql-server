USE master
set dateformat dmy
--Declarar Variáveis
DECLARE @DeviceName VARCHAR(255)
DECLARE @File VARCHAR(255)
DECLARE @Creation DATETIME
DECLARE @OldPlus DATETIME
declare @t1 varchar(100)
declare @t2 varchar(100)

-- Declarar o cursor
DECLARE bud CURSOR
FOR
select F.logical_device_name
	,F.physical_device_name
	,S.backup_finish_date
	from MSDB..backupmediafamily F 
	Inner join MSDB..backupset S ON F.media_set_id = S.media_set_id
	where F.logical_device_name not in (select name from sys.backup_devices where name like 'ReportServer_%')

-- Open the cursor
OPEN bud

-- Loop através do cursor
FETCH NEXT
FROM bud
INTO @DeviceName
	,@File
	,@Creation

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @OldPlus = DATEADD(day, 10, @Creation)
		print @oldPlus

	IF convert(VARCHAR(50), @OldPlus, 101) <= convert(VARCHAR(50), getdate(), 101)
	
	BEGIN
		print @DeviceName
		print @File
		print @Creation
		EXEC sp_dropdevice @DeviceName
			--,DELFILE

			--DELETE
		--FROM sys.Backup_Devices
		--WHERE name = @DeviceName
		--	AND physical_name = @File
			--AND BackupDeviceCreation = @Creation
	END

	FETCH NEXT
	FROM bud
	INTO @DeviceName
		,@File
		,@Creation
END

CLOSE bud

DEALLOCATE bud

select * 
from sys.backup_devices

--USE msdb;  
--GO  
--EXEC sp_delete_backuphistory @oldest_date = '2018/03/15';

--declare @nome_logical table ( name varchar(256))
--insert into @nome_logical
--select name
--from sys.backup_devices 
----where logical_name not like '%_log'

--select* from  @nome_logical
--EXEC sp_dropdevice 'db_dba_01102018',DELFILE