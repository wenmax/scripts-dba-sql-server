--consultas mais demoradas ordenadas por uso de cpu 

SELECT
	DB_NAME() as [database],
    total_worker_time/execution_count AS Media_CPU,
    total_worker_time AS Total_CPU,
    total_elapsed_time/execution_count AS Media_Duracao,
    total_elapsed_time AS Total_Duracao,
    (total_logical_reads+total_physical_reads)/execution_count AS Media_Leituras,
    (total_logical_reads+total_physical_reads) AS Total_Leituras,
    execution_count AS Total_Execucoes,
    SUBSTRING(st.TEXT, (qs.statement_start_offset/2)+1,
        ((CASE qs.statement_end_offset  WHEN -1 THEN datalength(st.TEXT)  
        ELSE qs.statement_end_offset  
        END - qs.statement_start_offset)/2) + 1
    ) AS Consulta_SQL,
    query_plan AS Plano_Execucao
FROM
    sys.dm_exec_query_stats AS qs  
    cross apply sys.dm_exec_sql_text(qs.sql_handle) AS st  
    cross apply sys.dm_exec_query_plan (qs.plan_handle) AS qp 
ORDER BY
    2 DESC , 1