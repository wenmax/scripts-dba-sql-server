--VERIFICA PROCESSOS ATIVOS NO BANCO

SELECT
	Processo = spid
   ,Computador = hostname
   ,Usuario = loginame
   ,Status = Status
   ,BloqueadoPor = blocked
   ,TipoComando = cmd
   ,Aplicativo = program_name
FROM master..sysprocesses
WHERE Status IN ('runnable', 'suspended')
ORDER BY blocked DESC, status, spid

--visualizar o plano de execução de uma query em execução
SELECT
	A.session_id
   ,B.command
   ,A.login_name
   ,C.query_plan
FROM sys.dm_exec_sessions AS A WITH (NOLOCK)
LEFT JOIN sys.dm_exec_requests AS B WITH (NOLOCK)
	ON A.session_id = B.session_id
OUTER APPLY sys.dm_exec_query_plan(B.[plan_handle]) AS C
WHERE A.session_id > 50
AND A.session_id <> @@spid
AND (A.[status] != 'sleeping'
OR (A.[status] = 'sleeping'
AND A.open_transaction_count > 0))

--	visualizar os planos em cache

SELECT
	cp.objtype AS ObjectType
   ,OBJECT_NAME(st.objectid, st.dbid) AS ObjectName
   ,cp.usecounts AS ExecutionCount
   ,st.text AS QueryText
   ,qp.query_plan AS QueryPlan
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st
ORDER BY ExecutionCount DESC



--descobre cursor api

WITH cte
AS
(SELECT
		session_id
	   ,t.text
	FROM sys.dm_exec_connections c
	CROSS APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) t
	WHERE text LIKE 'FETCH API_CURSOR%')
SELECT DISTINCT
	c.session_id
   ,c.properties
   ,c.creation_time
   ,c.is_open
   ,t.[text]
FROM cte
CROSS APPLY sys.dm_exec_cursors(session_id) c
CROSS APPLY sys.dm_exec_sql_text(c.sql_handle) t


EXEC sp_WhoIsActive

--RECUPERA LISTA DE CONEXOES QUE ESTAO EXECUTANDO ATUALMENTE SOLICITAÇOES  JUNTO COM A CONSULTA QUE ESTA SENDO EXECUTADA  

SELECT
	query_plan
   ,text
   ,*
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_query_plan(plan_handle)
CROSS APPLY sys.dm_exec_sql_text(sql_handle)


--RECUPERA LISTA DE CONEXOES QUE ESTAO EXECUTANDO ATUALMENTE SOLICITAÇOES  JUNTO COM A CONSULTA QUE ESTA SENDO EXECUTADA  

SELECT
	query_plan AS plano_de_execução
   ,text AS Consulta
	--,*
   ,Processo = spid
   ,Computador = hostname
   ,Usuario = loginame
   ,STATUS = a.STATUS
   ,BloqueadoPor = blocked
   ,TipoComando = cmd
   ,Aplicativo = program_name
FROM sys.dm_exec_requests
CROSS APPLY sys.dm_exec_query_plan(plan_handle)
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
CROSS APPLY master..sysprocesses AS a
WHERE a.STATUS IN ('runnable', 'suspended')
ORDER BY blocked DESC, a.status, spid

--Consulta para análise da melhor configuração para o Cost Threshold for Parallelism.

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
WITH XMLNAMESPACES
(DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
	query_plan AS CompleteQueryPlan
   ,n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS StatementText
   ,n.value('(@StatementOptmLevel)[1]', 'VARCHAR(25)') AS StatementOptimizationLevel
   ,n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS StatementSubTreeCost
   ,n.query('.') AS ParallelSubTreeXML
   ,ecp.usecounts
   ,ecp.size_in_bytes
FROM sys.dm_exec_cached_plans AS ecp
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS eqp
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn (n)
WHERE n.query('.').exist('//RelOp[@PhysicalOp="Parallelism"]') = 1



EXEC sp_WhoIsActive

/*Ao executar o script vocês poderão encontrar na primeira linha 
  quem é a sessão principal que está bloqueando as outras sessões, 
  cham123Mudar@ada HEAD. Além disso você também terá acesso a query que está sendo executado por essa sessão.
*/

SET NOCOUNT ON
GO
SELECT
	SPID
   ,BLOCKED
   ,REPLACE(REPLACE(T.text, CHAR(10), ' '), CHAR(13), ' ') AS BATCH INTO #T
FROM sys.sysprocesses R
CROSS APPLY sys.dm_exec_sql_text(R.SQL_HANDLE) T
GO
WITH BLOCKERS (SPID, BLOCKED, LEVEL, BATCH)
AS
(SELECT
		SPID
	   ,BLOCKED
	   ,CAST(REPLICATE('0', 4 - LEN(CAST(SPID AS VARCHAR))) + CAST(SPID AS VARCHAR) AS VARCHAR(1000)) AS LEVEL
	   ,BATCH
	FROM #T R
	WHERE (BLOCKED = 0
	OR BLOCKED = SPID)
	AND EXISTS (SELECT
			*
		FROM #T R2
		WHERE R2.BLOCKED = R.SPID
		AND R2.BLOCKED <> R2.SPID)
	UNION ALL
	SELECT
		R.SPID
	   ,R.BLOCKED
	   ,CAST(BLOCKERS.LEVEL + RIGHT(CAST((1000 + R.SPID) AS VARCHAR(100)), 4) AS VARCHAR(1000)) AS LEVEL
	   ,R.BATCH
	FROM #T AS R
	INNER JOIN BLOCKERS
		ON R.BLOCKED = BLOCKERS.SPID
	WHERE R.BLOCKED > 0
	AND R.BLOCKED <> R.SPID)
SELECT
	N' ' + REPLICATE(N'| ', LEN(LEVEL) / 4 - 1) +
	CASE
		WHEN (LEN(LEVEL) / 4 - 1) = 0 THEN 'HEAD - '
		ELSE '|------ '
	END
	+ CAST(SPID AS NVARCHAR(10)) + N' ' + BATCH AS BLOCKING_TREE
FROM BLOCKERS
ORDER BY LEVEL ASC
GO
DROP TABLE #T
GO


-- Consulta 2 - VERIFICA SESSÕES ATIVAS COM SQL STATEMENT

SELECT	r.session_id
		,r.[status]
		,r.wait_type
		,r.scheduler_id
		,SUBSTRING(qt.[text],r.statement_start_offset/ 2
		,(CASE WHEN r.statement_end_offset=-1            
			THEN LEN(CONVERT(NVARCHAR(MAX),qt.[text]))* 2            
			ELSE r.statement_end_offset        
			END -r.statement_start_offset)/ 2)AS[statement_executing]
		,DB_NAME(qt.[dbid])AS[DatabaseName]
		,OBJECT_NAME(qt.objectid)AS[ObjectName]
		,r.cpu_time
		,r.total_elapsed_time
		,r.reads,r.writes
		,r.logical_reads
		,r.plan_handle
FROM  sys.dm_exec_requests AS r CROSS APPLY sys.dm_exec_sql_text(sql_handle)AS qt 
WHERE status IN ('suspended','running','runnable')
ORDER BY r.scheduler_id,r.[status],r.session_id