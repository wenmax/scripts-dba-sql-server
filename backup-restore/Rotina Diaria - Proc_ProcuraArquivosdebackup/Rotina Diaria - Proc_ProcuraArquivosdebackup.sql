-- ============================ --
-- Title: Search Backup Archive	--
-- Type: Stored Procedure		--
-- Author: Leandro Ribeiro		--
-- Create Date: 18/08/2011		--
-- ============================ --
-- Twitter: @sqlleroy			--
-- blog: sqlleroy.com			--
-- ============================ --
USE master
GO

IF OBJECT_ID('[prd_SearchBackupArchive]') IS NOT NULL
	DROP PROC [prd_SearchBackupArchive]
GO

CREATE PROC [prd_SearchBackupArchive](
  @Database			VARCHAR(30)
 ,@Extension		CHAR(4)
 ,@PathBackup		VARCHAR (100)
 ,@DbSystem			BIT	
 -- Find backup archives with a last modified date less than or equal to the current date minus "@SeekDaysAgo" days.
 ,@SeekDaysAgo		VARCHAR(3)
 ,@LastBackup		VARCHAR(100) OUTPUT
 )
AS
BEGIN
	SET NOCOUNT ON;
	SET QUOTED_IDENTIFIER ON;
	SET ANSI_WARNINGS ON;
	
	DECLARE	
		 @Command VARCHAR(1000)
		,@Error VARCHAR(100)

	DECLARE @Forfiles TABLE (CMD VARCHAR(200))

	-- ======================= --
	-- Create temporary tables --
	-- ======================= --
	IF OBJECT_ID ('tempdb..##ArqBck') IS NOT NULL DROP TABLE ##ArqBck
	
	CREATE TABLE ##ArqBck (PhysicalName VARCHAR(100), DatabaseName SYSNAME, DayTime VARCHAR(15))

	IF OBJECT_ID ('tempdb..#Forfiles') IS NOT NULL DROP TABLE #Forfiles
	
	CREATE TABLE #Forfiles (CMD VARCHAR(200))
	 
	-- ============================================================ --
	-- MS-DOS Command for returning contained archives in directory --
	-- ============================================================ --
	IF @Database = ''
		SELECT @Command = 'forfiles /P ' + @PathBackup +
							CASE WHEN @SeekDaysAgo > 0 THEN ' /D -' + @SeekDaysAgo ELSE '' END +
							' /M *' + @Extension + ' /C "cmd /c echo @file"';
	ELSE
		SELECT @Command = 'forfiles /P ' + @PathBackup +
							CASE WHEN @SeekDaysAgo > 0 THEN ' /D -' + @SeekDaysAgo ELSE '' END +
							' /M ' + @Database + '*' + @Extension + ' /C "cmd /c echo @file"';

	EXEC sp_configure 'show advanced options', 1
	RECONFIGURE WITH OVERRIDE

	EXEC sp_configure 'xp_cmdshell', 1
	RECONFIGURE WITH OVERRIDE
	
	INSERT INTO #Forfiles
	EXEC xp_cmdshell @Command
	
	EXEC sp_configure 'xp_cmdshell', 0
	RECONFIGURE WITH OVERRIDE
	
	EXEC sp_configure 'show advanced options', 0
	RECONFIGURE WITH OVERRIDE
	
	SELECT @Error = CMD FROM #Forfiles WHERE CMD LIKE 'ERRO:%'

	IF @Error <> ''
	BEGIN
		SELECT @Error
		RAISERROR (@Error,10,1)
		DROP TABLE ##ArqBck
	END
	ELSE
	BEGIN
		-- Adjusting the field to facilitate the subsequent writing
		UPDATE #Forfiles SET CMD = REPLACE(CMD,'"','')

		-- =============================== --
		-- Store result in temporary table --
		-- =============================== --
			SELECT @Command = 
				'INSERT INTO ##ArqBck
				 SELECT
					CMD PhysicalName,
					SUBSTRING(CMD, 0,CHARINDEX(''_backup'',CMD)) DatabaseName,
					CASE CONVERT(VARCHAR(2),SERVERPROPERTY(''productversion''))
					WHEN 9 THEN REPLACE(SUBSTRING(CMD, CHARINDEX(''_backup'',CMD) +7 ,13),''_'','''')
					ELSE REPLACE(SUBSTRING(CMD, CHARINDEX(''_backup'',CMD) +8 ,15),''_'','''')
					END DayTime
				 FROM #Forfiles
				 WHERE CMD IS NOT NULL' + CHAR(13)
				
		-- Whenever want exclude system databases when search all databases
		IF @DbSystem = 0 AND @database = ''
			SELECT @Command = @Command + ' AND SUBSTRING(REPLACE(CMD,''"'',''''), 0,CHARINDEX(''_backup'',REPLACE(CMD,''"'',''''))) NOT IN (''master'',''msdb'',''model'',''tempdb'')'

		EXEC (@Command)

		-- ================== --
		-- Index result table --
		-- ================== --
		IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ArqBck')
		CREATE NONCLUSTERED INDEX IX_ArqBck ON ##ArqBck (DayTime, DatabaseName) INCLUDE (PhysicalName)
	
		-- Return last backup name the database
		IF @Database <> ''
			SELECT @LastBackup = PhysicalName FROM ##ArqBck ORDER BY DayTime ASC
		
	END
END


EXEC sys.sp_MS_marksystemobject '[prd_SearchBackupArchive]'
go