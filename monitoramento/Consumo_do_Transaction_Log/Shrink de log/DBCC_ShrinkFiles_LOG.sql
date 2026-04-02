USE db_DBA
GO

;WITH cte_DataSpace
AS
(
	SELECT DISTINCT
		database_id,				
		SUM(size) OVER (PARTITION BY database_id) AS [size]
	FROM sys.master_files
	WHERE type = 0
	AND database_id > 7
)
SELECT 
	DB_NAME(m.database_id)	AS [db_name],
	m.name					AS [file_name],
	d.size					AS [sizeDados],
	m.size					AS [sizeLog],
	'USE ' + QUOTENAME(DB_NAME(m.database_id)) + '; DBCC SHRINKFILE (''' + m.name + ''',1024);' AS [comando]
FROM sys.master_files m
INNER JOIN cte_DataSpace d
ON m.database_id = d.database_id
WHERE m.type = 1
AND m.size >= d.size






