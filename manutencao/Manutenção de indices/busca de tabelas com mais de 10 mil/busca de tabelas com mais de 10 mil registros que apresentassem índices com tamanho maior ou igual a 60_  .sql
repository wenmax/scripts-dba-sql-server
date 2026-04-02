--busca de tabelas com mais de 10 mil registros que apresentassem índices
--com tamanho maior ou igual a 60% do tamanho da própria tabela 



USE AdventureWorks2012
GO

DECLARE @decRatio AS DECIMAL(7, 2)
	,@intRowCount AS INTEGER

SET @decRatio = 0.6 -- informa proporção máxima
SET @intRowCount = 10000 -- informa número de registros mínimo
	;

WITH cteData (
	object_id
	,TableName
	,Data_Kb
	,Row_Count
	)
AS (
	SELECT i.object_id
		,OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS TableName
		,SUM(s.[used_page_count]) * 8.0 AS Data_Kb
		,SUM(s.row_count) AS Row_Count
	FROM sys.dm_db_partition_stats s
	INNER JOIN sys.indexes i ON s.object_id = i.object_id
		AND s.index_id = i.index_id
	WHERE OBJECT_SCHEMA_NAME(i.object_id) <> 'sys' -- exclui catalogos
		AND i.type IN (
			0
			,1
			) -- HEAPS ou CLUSTERED
		AND s.Row_Count >= @intRowCount
	GROUP BY i.object_id
	)
	,cteIndex (
	object_id
	,IndexName
	,Index_Kb
	)
AS (
	SELECT i.object_id
		,i.name AS IndexName
		,SUM(s.[used_page_count]) * 8.0 AS Index_Kb
	FROM sys.dm_db_partition_stats s
	INNER JOIN sys.indexes i ON s.object_id = i.object_id
		AND s.index_id = i.index_id
	WHERE OBJECT_SCHEMA_NAME(i.object_id) <> 'sys' -- exclui catalogos
		AND i.type IN (2) -- NONCLUSTERED
	GROUP BY i.object_id
		,i.name
	)
SELECT d.TableName
	,i.IndexName
	,d.Data_Kb
	,i.Index_Kb
	,ROUND((i.Index_Kb / d.Data_Kb * 100.0), 1) AS Ratio
	,d.Row_Count
FROM cteData d
INNER JOIN cteIndex i ON d.object_id = i.object_id
WHERE i.Index_Kb >= @decRatio * d.Data_Kb
ORDER BY d.Row_Count DESC
	,Ratio DESC
