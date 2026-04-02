--DESCOBRIR O NOME DOS INDICES DE UM DETERMINADO BANCO
SELECT *
FROM sys.indexes
WHERE [object_id] = OBJECT_ID('[dbo].[tbl_Trf]')


--quais consultas estao utilizando esses indices 

SELECT
    SUBSTRING(C.[text], ( A.statement_start_offset / 2 ) + 1, ( CASE A.statement_end_offset WHEN -1 THEN DATALENGTH(C.[text]) ELSE A.statement_end_offset END - A.statement_start_offset ) / 2 + 1) AS sqltext,
    A.execution_count,
    A.total_logical_reads / execution_count AS avg_logical_reads,
    A.total_logical_writes / execution_count AS avg_logical_writes,
    A.total_worker_time / execution_count AS avg_cpu_time,
    A.last_elapsed_time / execution_count AS avg_elapsed_time,
    A.total_rows / execution_count AS avg_rows,
    A.creation_time,
    A.last_execution_time,
    CAST(query_plan AS XML) AS plan_xml,
    B.query_plan,
    C.[text]
FROM
    sys.dm_exec_query_stats AS A
    CROSS APPLY sys.dm_exec_text_query_plan(A.plan_handle, A.statement_start_offset, A.statement_end_offset) AS B
    CROSS APPLY sys.dm_exec_sql_text(A.[sql_handle]) AS C
WHERE
    B.query_plan LIKE '%NOME DO INDICE%'
    AND B.query_plan NOT LIKE '%dm_exec_text_query_plan%'
ORDER BY
    A.last_execution_time DESC
OPTION(RECOMPILE)