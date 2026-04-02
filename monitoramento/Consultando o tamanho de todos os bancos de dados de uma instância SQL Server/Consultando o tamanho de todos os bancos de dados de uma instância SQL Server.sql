
--Consultando o tamanho de todos os bancos de dados de uma instância SQL Server

CREATE PROCEDURE [dbo].[pr_ColetarTamanhoBancosDados] @atualizarUsoDiscos CHAR(1) = 'S'
AS
BEGIN
	/*
        * Definindo as propriedades da transação.
        */
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET NOCOUNT ON;

	/* 
      * Validação dos parâmetros
       */
	IF @atualizarUsoDiscos IS NOT NULL
	BEGIN
		SELECT @atualizarUsoDiscos = LOWER(@atualizarUsoDiscos);

		IF @atualizarUsoDiscos NOT IN (
				's'
				,'n'
				)
		BEGIN
			RAISERROR (
					15143
					,- 1
					,- 1
					,@atualizarUsoDiscos
					);

			RETURN (1);
		END
	END

	/*
        * Declarando as tabelas auxiliares.
       */
	CREATE TABLE #DBSizeTable (
		[DatabaseName] [SYSNAME] NOT NULL
		,-- Nome Banco de Dados
		[TotalDatabaseSizeMB] [DECIMAL](15, 2) NULL
		,-- Tamanho total dos arquivos (LOG + DADOS)
		[DataSizeMB] [DECIMAL](15, 2) NULL
		,-- Tamanho arquivo de dados
		[UnnalocateSpaceMB] AS CASE 
			WHEN DataSizeMB >= ReservedMB
				THEN (DataSizeMB - ReservedMB) * 8 / 1024
			ELSE 0
			END
		,-- Espaço não alocado
		[ReservedMB] [DECIMAL](15, 2) NULL
		,-- Tamanho reservado pelo banco de dados nos arquivos de DADOS
		[DataMB] [DECIMAL](15, 2) NULL
		,-- Tamanho das tabelas arquivos de dados
		[IndexSizeMB] [DECIMAL](15, 2) NULL
		,-- Tamanho dos índices arquivos de dados
		[UnusedMB] [DECIMAL](15, 2) NULL
		,-- Tamanho livre nos arquivos de dados
		[LogSizeMB] [DECIMAL](15, 2) NULL
		,-- Tamanho arquivo de log.
		[LogPercentUsed] [DECIMAL](9, 2) NULL -- Percentual de log utilizado.
		);

	CREATE TABLE #tabelaAlocacao (
		dbname VARCHAR(250)
		,reservedpages BIGINT
		,usedpages BIGINT
		,pages BIGINT
		);

	CREATE TABLE #SQLLOG (
		dbname VARCHAR(200)
		,logsize DECIMAL(12, 5)
		,logspacepercent DECIMAL(12, 5)
		,STATUS TINYINT
		);

	/* 
       * Declaração das variáveis de apoio.
       */
	DECLARE @comandoSize VARCHAR(MAX)
	DECLARE @comandoAllocation VARCHAR(MAX)
	DECLARE @nomeBancoDados VARCHAR(250)

	DECLARE cur_Databases CURSOR
	FOR
	SELECT name
	FROM sys.databases
	WHERE STATE <> 6

	OPEN cur_Databases

	FETCH NEXT
	FROM cur_Databases
	INTO @nomeBancoDados

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (@atualizarUsoDiscos = 'S')
		BEGIN
			DBCC UPDATEUSAGE (@nomeBancoDados)
			WITH NO_INFOMSGS
		END

		-- Coletando tamanho dos arquivos de Dados e Logs
		SELECT @comandoSize = 'INSERT INTO #DBSizeTable (DatabaseName, TotalDatabaseSizeMB, DataSizeMB, LogSizeMB) 
              (SELECT ''' + @nomeBancoDados + ''', 
                         TOTAL_DB_SIZE = (sum(convert(bigint,case when status & 64 = 0 then size else 0 end))+ sum(convert(bigint,case when status & 64 <> 0 then size else 0 end)))*8/1024.,
                          DBSIZE = sum(convert(bigint,case when status & 64 = 0 then size else 0 end))*8/1024.,
                         LOGSIZE = sum(convert(bigint,case when status & 64 <> 0 then size else 0 end))*8/1024.
                    FROM ' + QUOTENAME(@nomeBancoDados) + '.dbo.sysfiles)'

		EXEC (@comandoSize)

		-- Coletando informações sobre as alocações. Espaço reservado, espaço não utilizado, espaço para páginas e índices.
		SELECT @comandoAllocation = 'INSERT INTO #tabelaAlocacao (dbname, reservedpages, usedpages, pages) (SELECT ''' + @nomeBancoDados + ''', sum(a.total_pages), sum(a.used_pages), sum(
                                            CASE
                                                  When it.internal_type IN (202,204,207,211,212,213,214,215,216,221,222,236) Then 0
                                                 When a.type <> 1 and p.index_id < 2 Then a.used_pages
                                                When p.index_id < 2 Then a.data_pages
                                               Else 0
                                              END
                                      )
                                     FROM ' + QUOTENAME(@nomeBancoDados) + '.sys.partitions p JOIN ' + QUOTENAME(@nomeBancoDados) + '.sys.allocation_units a on p.partition_id = a.container_id
                                          LEFT JOIN ' + QUOTENAME(@nomeBancoDados) + 
			'.sys.internal_tables it on p.object_id = it.object_id)'

		EXEC (@comandoAllocation)

		FETCH NEXT
		FROM cur_Databases
		INTO @nomeBancoDados
	END

	CLOSE cur_Databases

	DEALLOCATE cur_Databases

	-- Coletando informações sobre o tamanho e uso dos arquivos de log.
	INSERT INTO #SQLLOG
	EXEC ('DBCC SQLPERF(LOGSPACE)')

	-- Atualizando as informações da tabela.
	UPDATE t
	SET [LogSizeMB] = s.logsize
		,[LogPercentUsed] = s.logspacepercent
	FROM #DBSizeTable t
	INNER JOIN #SQLLOG s ON (t.DatabaseName = s.dbname)

	-- Atualizando informações sobre alocação de páginas
	UPDATE dbsize
	SET ReservedMB = reservedpages * 8 / 1024.
		,DataMB = pages * 8 / 1024.
		,IndexSizeMB = (usedpages - pages) * 8 / 1024.
		,UnusedMB = (reservedpages - usedpages) * 8 / 1024.
	FROM #DBSizeTable dbsize
	INNER JOIN #tabelaAlocacao tabAlocacao ON (dbsize.DatabaseName = tabAlocacao.dbname)

	SELECT *
	FROM #DBSizeTable
END


