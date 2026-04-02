IF (OBJECT_ID('tempdb..#FKControl') IS NOT NULL)
BEGIN
	DROP TABLE #FKControl;
END

CREATE TABLE #FKControl (
	tabelaOrigem VARCHAR(250)
	,tabelaDestino VARCHAR(250)
	,comandoCriacao VARCHAR(4000)
	,comandoRemocao VARCHAR(4000)
	);

DECLARE @ACTION VARCHAR(6)

SET @ACTION = 'CREATE'

DECLARE @constID INT
DECLARE @ConstraintName VARCHAR(100)
DECLARE @tabelaOrigem VARCHAR(100)
DECLARE @tabelaDestino VARCHAR(100)
DECLARE @schemaOrigem VARCHAR(100)
DECLARE @schemaDestino VARCHAR(100)

DECLARE listaFK CURSOR
FOR
SELECT DISTINCT const.NAME AS constraintname
	,tabOrigem.NAME AS tabOrigem
	,tabReferencia.NAME AS tabRef
	,fk.constid AS constID
	,schemaOrigem.NAME AS schemaOrigem
	,schemaReferencia.NAME AS schemaReferencia
FROM sysforeignkeys fk
INNER JOIN sysobjects const ON (fk.constid = const.id)
INNER JOIN sysobjects tabOrigem ON (fk.fkeyid = tabOrigem.id)
INNER JOIN sysusers schemaOrigem ON (tabOrigem.uid = schemaOrigem.uid)
INNER JOIN sysobjects tabReferencia ON (fk.rkeyid = tabReferencia.id)
INNER JOIN sysusers schemaReferencia ON (tabReferencia.uid = schemaReferencia.uid)

OPEN listaFK

FETCH NEXT
FROM listaFK
INTO @ConstraintName
	,@tabelaOrigem
	,@tabelaDestino
	,@constID
	,@schemaOrigem
	,@schemaDestino

WHILE @@FETCH_STATUS = 0
BEGIN
	DECLARE @COMANDO VARCHAR(4000)

	SET @COMANDO = 'ALTER TABLE ' + QUOTENAME(@schemaOrigem) + '.' + QUOTENAME(@tabelaOrigem) + ' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(@ConstraintName) + ' FOREIGN KEY ('

	DECLARE colunasTabelas CURSOR
	FOR
	SELECT colunaOrigem.NAME AS Origem
		,colunaReferencias.NAME AS Referencia
	FROM sysforeignkeys fk
	INNER JOIN sysobjects const ON (fk.constid = const.id)
	INNER JOIN sysobjects tabOrigem ON (fk.fkeyid = tabOrigem.id)
	INNER JOIN sysobjects tabReferencia ON (fk.rkeyid = tabReferencia.id)
	INNER JOIN syscolumns colunaOrigem ON (
			colunaOrigem.id = tabOrigem.id
			AND fk.fkey = colunaOrigem.ColOrder
			)
	INNER JOIN syscolumns colunaReferencias ON (
			colunaReferencias.id = tabReferencia.id
			AND fk.rkey = colunaReferencias.ColOrder
			)
	WHERE fk.constid = @constID

	OPEN colunasTabelas

	DECLARE @colunasOrigem VARCHAR(1000)
	DECLARE @colunasDestino VARCHAR(1000)
	DECLARE @colunasOrigemTemp VARCHAR(1000)
	DECLARE @colunasDestinoTemp VARCHAR(1000)

	SET @colunasDestino = '';
	SET @colunasOrigem = '';

	FETCH NEXT
	FROM colunasTabelas
	INTO @colunasOrigemTemp
		,@colunasDestinoTemp

	WHILE @@FETCH_STATUS = 0
	BEGIN
		IF (@colunasDestino <> '')
			SET @colunasDestino = @colunasDestino + ', ' + QUOTENAME(@colunasDestinoTemp)
		ELSE
			SET @colunasDestino = QUOTENAME(@colunasDestinoTemp)

		IF (@colunasOrigem <> '')
			SET @colunasOrigem = @colunasOrigem + ', ' + QUOTENAME(@colunasOrigemTemp)
		ELSE
			SET @colunasOrigem = QUOTENAME(@colunasOrigemTemp)

		FETCH NEXT
		FROM colunasTabelas
		INTO @colunasOrigemTemp
			,@colunasDestinoTemp
	END

	CLOSE colunasTabelas

	DEALLOCATE colunasTabelas

	SET @COMANDO = @COMANDO + @colunasOrigem + ') REFERENCES ' + QUOTENAME(@schemaDestino) + '.' + QUOTENAME(@tabelaDestino) + ' (' + @colunasDestino + ')' + CHAR(13) + 'GO' + CHAR(13);
	SET @COMANDO = @COMANDO + 'ALTER TABLE ' + QUOTENAME(@schemaOrigem) + '.' + QUOTENAME(@tabelaOrigem) + ' CHECK CONSTRAINT ' + @ConstraintName + CHAR(13) + 'GO' + CHAR(13);

	--PRINT @COMANDO ;
	DECLARE @CmdRemocao VARCHAR(4000)

	SET @CmdRemocao = 'ALTER TABLE ' + QUOTENAME(@schemaOrigem) + '.' + QUOTENAME(@tabelaOrigem) + ' DROP CONSTRAINT ' + @ConstraintName

	INSERT INTO #FKControl (
		tabelaOrigem
		,tabelaDestino
		,comandoCriacao
		,comandoRemocao
		)
	VALUES (
		QUOTENAME(@schemaOrigem) + '.' + QUOTENAME(@tabelaOrigem)
		,QUOTENAME(@schemaDestino) + '.' + QUOTENAME(@tabelaDestino)
		,@COMANDO
		,@CmdRemocao
		)

	FETCH NEXT
	FROM listaFK
	INTO @ConstraintName
		,@tabelaOrigem
		,@tabelaDestino
		,@constID
		,@schemaOrigem
		,@schemaDestino
END

CLOSE listaFK

DEALLOCATE listaFK

SELECT *
FROM #FKControl;