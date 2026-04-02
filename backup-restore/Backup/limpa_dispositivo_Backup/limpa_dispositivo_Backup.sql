USE [master]
GO

/****** Object:  BackupDevice [msdb_29042018]    Script Date: 04/05/2018 15:33:53 ******/
EXEC master.dbo.sp_addumpdevice  @devtype = N'disk', @logicalname = N'msdb_29042018', @physicalname = N'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Backup\msdb\msdb_29042018.bak'
GO

declare @devicebackup varchar(1000)

select @devicebackup = name  from sys.backup_devices --WHERE name LIKE '%Radar%'



select @devicebackup

DECLARE @DEL VARCHAR(6)

EXEC master.dbo.sp_dropdevice @logicalname = @devicebackup 

--WAITFOR delay '00:00:01'

GO 1000


SELECT *  from sys.backup_devices