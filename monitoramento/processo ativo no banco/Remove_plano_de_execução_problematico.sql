--Como remover um plano de execução específico do cache do SQL Server

--consulta para saber comandos sql que estao em execução
SELECT TOP 10
execution_count,
total_elapsed_time / 1000 as totalDurationms,
total_worker_time / 1000 as totalCPUms,
total_logical_reads,
total_physical_reads,
t.text,
sql_handle,
plan_handle
FROM sys.dm_exec_query_stats s
CROSS APPLY sys.dm_exec_sql_text(s.sql_handle) as t
WHERE t.text LIKE '%linq%' -- parte da consulta executada
ORDER BY total_elapsed_time DESC

-- Remove um plano especifico do cache .  
--DBCC FREEPROCCACHE (0x060006001ECA270EC0215D05000000000000000000000000);  
--GO 
--apagar todo o cache de um determinado database

--DECLARE @DbID INT = (SELECT database_id FROM sys.databases WHERE [name] = 'dirceuresende')
 
--DBCC FLUSHPROCINDB (@DbID)
--GO