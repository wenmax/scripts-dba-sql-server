USE [CIE] --st1714_l3
GO
-- Declaração de Variáveis --

DECLARE @MIN	TINYINT
DECLARE @MAX	TINYINT
DECLARE @CMD	VARCHAR(MAX)

DECLARE @TabelaDefrag AS TABLE
(
	Linha				TINYINT	IDENTITY(1,1),
	BancoDeDados		VARCHAR(MAX),
	Tabela				VARCHAR(MAX),
	Indece				VARCHAR(MAX),
	Fragmentacao		DECIMAL(10,3),
	Comando				VARCHAR(MAX)	
)

-- Insere os Indeces que serão reconstruidos na @TabelaDefrag --

INSERT INTO @TabelaDefrag
SELECT 
		DB_NAME(database_id)							AS 'BancoDeDados',
		OBJECT_NAME(ps.object_id)						AS 'Tabela',
		i.name											AS 'Indece',
		ROUND(ps.avg_fragmentation_in_percent,1)		AS 'Fragmentacao',
		NULL
FROM 
	sys.indexes AS i WITH(NOLOCK)
INNER JOIN 
	sys.dm_db_index_physical_stats (DB_ID(),NULL, NULL, NULL ,'LIMITED') AS ps 
ON 
	i.object_id = ps.object_id 
AND
	i.index_id = ps.index_id
WHERE 
	i.type IN (1,2) AND
	page_count > 100 AND
	ps.avg_fragmentation_in_percent > 30
ORDER BY i.type, ps.avg_fragmentation_in_percent



-- Atualiza @TabelaDefrag com o Comando que será executado --

;WITH cte_reindex (Tabela, Indece, Comando)
AS
(
	SELECT	Tabela,
			Indece,
			'ALTER INDEX ' + QUOTENAME(Indece) + ' ON ' + QUOTENAME(BancoDeDados) + '.[dbo].'+ QUOTENAME(Tabela) + ' ' + CASE 
																								WHEN Fragmentacao <= 40 THEN 'REORGANIZE'
																								ELSE 'REBUILD'
																							  END
	FROM @TabelaDefrag
)
UPDATE @TabelaDefrag 
	SET Comando = c.Comando
FROM cte_reindex c
INNER JOIN @TabelaDefrag t
ON t.Tabela = c.Tabela
AND t.Indece = c.Indece


-- Informa menor e maior linha da @TabelaDefrag para o WHILE percorrer --

SELECT	@MIN = MIN(Linha),
		@MAX = MAX(Linha)
FROM @TabelaDefrag

--select * from @TabelaDefrag

-- Inicio do While -- 

WHILE @MIN <= @MAX
BEGIN
	
	BEGIN TRY
				
			SELECT @CMD = COMANDO FROM @TabelaDefrag WHERE Linha = @MIN

			--EXECUTE (@CMD) -- Executa comando --
						
	END TRY
	BEGIN CATCH
			
			SELECT 	BancoDeDados,Tabela,Indece,Comando,'S',ERROR_MESSAGE(),GETDATE()
				  FROM @TabelaDefrag
			WHERE Linha = @MIN

	END CATCH


	SET @MIN = @MIN + 1
	print @CMD
	
END
