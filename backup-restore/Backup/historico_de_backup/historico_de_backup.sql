-- Código  Histórico de Backup  Banco de Dados 
SELECT SERVERPROPERTY('Servername') AS 'Servidor'
	,msdb.dbo.backupset.database_name AS 'Database'
	,CASE msdb..backupset.type
		WHEN 'D'
			THEN 'Database'
		WHEN 'L'
			THEN 'Log'
		WHEN 'I'
			THEN 'Diferencial'
		WHEN 'F'
			THEN 'File ou Filegroup'
		WHEN 'G'
			THEN 'Diferencial Arquivo'
		WHEN 'P'
			THEN 'Parcial'
		WHEN 'Q'
			THEN 'Diferencial Parcial'
		END AS 'Tipo do Backup'
	,msdb.dbo.backupset.backup_start_date AS 'Data Execuo'
	,msdb.dbo.backupset.backup_finish_date AS 'Data Encerramento'
	,msdb.dbo.backupset.expiration_date AS 'Data de Expirao'
	,(msdb.dbo.backupset.backup_size / 1024) AS 'Tamanho do  Backup em MBs'
	,msdb.dbo.backupmediafamily.logical_device_name AS 'Dispositivo ou Local de Backup'
	,msdb.dbo.backupmediafamily.physical_device_name AS 'Caminho do Arquivo'
	,msdb.dbo.backupset.description AS 'Descrio'
	,CASE msdb.dbo.backupset.compatibility_level
		WHEN 80
			THEN 'SQL Server 2000'
		WHEN 90
			THEN 'SQL Server 2005'
		WHEN 100
			THEN 'SQL Server 2008 ou SQL Server 2008 R2'
		WHEN 110
			THEN 'SQL Server 2012'
		END AS 'Nvel de Compatibilidade'
	,msdb.dbo.backupset.name AS 'Backup Set'
FROM msdb.dbo.backupmediafamily
INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id
WHERE (CONVERT(DATETIME, msdb.dbo.backupset.backup_start_date, 103) >= GETDATE() - 15) AND msdb.dbo.backupset.database_name = '0710701_Radar'
ORDER BY msdb.dbo.backupset.database_name
	,msdb.dbo.backupset.backup_finish_date DESC


