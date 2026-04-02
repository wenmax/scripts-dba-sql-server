
SELECT schema_name(schema_id) AS NomeSchema
	,object_name(o.object_id) AS NomeTabela
	,i.NAME AS NomeIndex
	,index_id IndexId
	,o.type Tipo
	,STATS_DATE(o.object_id, index_id) AS DataEstatistica
FROM sys.indexes i
JOIN sys.objects o ON i.object_id = o.object_id
WHERE o.object_id > 100
	AND index_id > 0
	AND is_ms_shipped = 0;

--Podemos atualizar todo o banco de dados.

--EXEC sp_updatestats;

--Podemos atualizar uma tabela.

--UPDATE STATISTICS <banco>.<schema>.<tabela>; 
--GO

--Ou podemos atualizar um índice especifico

--UPDATE STATISTICS <banco>.<schema>.<tabela> <indice>; 
--GO