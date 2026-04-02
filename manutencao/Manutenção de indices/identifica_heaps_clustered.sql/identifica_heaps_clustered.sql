--O script informa o nome e o tipo de tabela, a quantidade de índices e quantidade 
--de registros que ela tem. Ele inclui um parâmetro (@intQtdLimite) para especificar 
--qual número limite de índices a partir do qual precisaremos reavaliar a indexação

USE AdventureWorks2012
GO

DECLARE @intQtdLimite AS INTEGER

SET @intQtdLimite = 5 -- informa limite de 5 índices por tabela
	;

WITH cteObject (
	object_id
	,Tipo
	,NumRegistros
	)
AS (
	SELECT DISTINCT i.object_id
		,i.type_desc AS Tipo
		,SUM(p.rows) AS NumRegistros
	FROM sys.indexes i
	INNER JOIN sys.partitions p ON i.object_id = p.object_id
		AND i.index_id = p.index_id
	WHERE i.type_desc IN (
			'clustered'
			,'heap'
			)
		AND OBJECT_SCHEMA_NAME(i.object_id) <> 'sys' -- exclui catalogos
	GROUP BY i.object_id
		,i.type_desc
	)
SELECT CASE 
		WHEN c.Tipo = 'clustered'
			THEN 'EXCESSO'
		ELSE 'AUSENCIA'
		END AS Problema
	,OBJECT_SCHEMA_NAME(i.object_id) + '.' + OBJECT_NAME(i.object_id) AS Tabela
	,i.object_id
	,c.Tipo
	,COUNT(*) - CASE 
		WHEN c.Tipo = 'clustered'
			THEN 0
		ELSE 1
		END AS NumIndices
	,MAX(c.NumRegistros) AS NumRegistros
FROM sys.indexes i
INNER JOIN cteObject c ON i.object_id = c.object_id
GROUP BY i.object_id
	,c.Tipo
HAVING c.Tipo = 'heap'
	OR COUNT(*) >= @intQtdLimite
ORDER BY 1
	,2
