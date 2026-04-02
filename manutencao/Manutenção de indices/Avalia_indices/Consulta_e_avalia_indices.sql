--Listagem 1. Tabelas que não contêm índices clusteriazados.
SELECT DISTINCT (tb.name) AS Table_name
	,p.rows
FROM sys.objects tb
JOIN sys.partitions p ON p.object_id = tb.object_id
WHERE type = 'U'
	AND tb.object_id NOT IN (
		SELECT ix.object_id
		FROM sys.indexes ix
		WHERE type = 1
		)
ORDER BY p.rows DESC

--Listagem 2. Tabelas que não possuem chave primária.

SELECT DISTINCT (tb.name) AS Table_name
	,p.rows
FROM sys.objects tb
JOIN sys.partitions p ON p.object_id = tb.object_id
WHERE type = 'U'
	AND tb.object_id NOT IN (
		SELECT ix.object_id
		FROM sys.key_constraints ix
		WHERE type = 'PK'
		)
ORDER BY p.rows DESC

--Listagem 3. Tabelas que mais seriam beneficiadas com novos índices.

SELECT TOP 15 AVG((avg_total_user_cost * avg_user_impact * (user_seeks + user_scans))) AS Impacto
	,mid.object_id
	,mid.statement AS Tabela
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
	AND database_id = db_id('SWM_CAI ')
GROUP BY mid.object_id
	,mid.statement
ORDER BY Impacto DESC;


--4.Listagem Top 15 índices, sugeridos pelo SGBD.
 
SELECT TOP 15 (avg_total_user_cost * avg_user_impact * (user_seeks + user_scans)) AS Impacto
	,migs.group_handle
	,mid.index_handle
	,migs.user_seeks
	,migs.user_scans
	,mid.object_id
	,mid.statement
	,mid.equality_columns
	,mid.inequality_columns
	,mid.included_columns
FROM sys.dm_db_missing_index_group_stats AS migs
JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
	AND database_id = db_id('SWM_CAI') --and mid.object_id = object_id(‘tabela’) -- se desejar ver apenas para uma tabela específica
ORDER BY Impacto DESC;


--Listagem 5. Índices nunca utilizados pelo SGBD.

SELECT tb.name AS Table_Name
	,ix.name AS Index_Name
	,ix.type_desc
	,leaf_insert_count
	,leaf_delete_count
	,leaf_update_count
	,nonleaf_insert_count
	,nonleaf_delete_count
	,nonleaf_update_count
FROM sys.dm_db_index_usage_stats vw
JOIN sys.objects tb ON tb.object_id = vw.object_id
JOIN sys.indexes ix ON ix.index_id = vw.index_id
	AND ix.object_id = tb.object_id
JOIN sys.dm_db_index_operational_stats(db_id('SWM_CAI'), NULL, NULL, NULL) vwx ON vwx.object_id = tb.object_id
	AND vwx.index_id = ix.index_id
WHERE vw.database_id = db_id('SWM_CAI')
	AND vw.user_seeks = 0
	AND vw.user_scans = 0
	AND vw.user_lookups = 0
	AND vw.system_seeks = 0
	AND vw.system_scans = 0
	AND vw.system_lookups = 0
ORDER BY leaf_insert_count DESC
	,tb.name ASC
	,ix.name ASC

--Listagem 6. Avaliando índices.

SELECT ix.name
	,ix.type_desc
	,vwy.partition_number
	,vw.user_seeks
	,vw.last_user_seek
	,vw.user_scans
	,vw.last_user_scan
	,vw.user_lookups
	,vw.user_updates AS 'Total_User_Escrita'
	,(vw.user_scans + vw.user_seeks + vw.user_lookups) AS 'Total_User_Leitura'
	,vw.user_updates - (vw.user_scans + vw.user_seeks + vw.user_lookups) AS 'Dif_Read_Write'
	,ix.allow_row_locks
	,vwx.row_lock_count
	,row_lock_wait_count
	,row_lock_wait_in_ms
	,ix.allow_page_locks
	,vwx.page_lock_count
	,page_lock_wait_count
	,page_lock_wait_in_ms
	,ix.fill_factor
	,ix.is_padded
	,vwy.avg_fragmentation_in_percent
	,vwy.avg_page_space_used_in_percent
	,ps.in_row_used_page_count AS Total_Pagina_Usada
	,ps.in_row_reserved_page_count AS Total_Pagina_Reservada
	,convert(REAL, ps.in_row_used_page_count) * 8192 / 1024 / 1024 AS Total_Indice_Usado_MB
	,convert(REAL, ps.in_row_reserved_page_count) * 8192 / 1024 / 1024 AS Total_Indice_Reservado_MB
	,page_io_latch_wait_count
	,page_io_latch_wait_in_ms
FROM sys.dm_db_index_usage_stats vw
JOIN sys.indexes ix ON ix.index_id = vw.index_id
	AND ix.object_id = vw.object_id
JOIN sys.dm_db_index_operational_stats(db_id('SWM_CAI'), OBJECT_ID(N'Log'), NULL, NULL) vwx ON vwx.index_id = ix.index_id
	AND ix.object_id = vwx.object_id
JOIN sys.dm_db_index_physical_stats(db_id('SWM_CAI'), OBJECT_ID(N'Log'), NULL, NULL, 'SAMPLED') vwy ON vwy.index_id = ix.index_id
	AND ix.object_id = vwy.object_id
	AND vwy.partition_number = vwx.partition_number
JOIN sys.dm_db_partition_stats PS ON ps.index_id = vw.index_id
	AND ps.object_id = vw.object_id
WHERE vw.database_id = db_id('SWM_CAI')
	AND object_name(vw.object_id) = 'Log'
ORDER BY user_seeks DESC
	,user_scans DESC

--Listagem 7. Tabelas com maior quantidade de índices.
-- Tabelas com maior quantidade de índices e colunas

SELECT x.id
	,x.table_name
	,x.Total_index
	,count(*) AS Total_column
FROM sys.columns cl
JOIN (
	SELECT ix.object_id AS id
		,tb.name AS table_name
		,count(ix.object_id) AS Total_index
	FROM sys.indexes ix
	JOIN sys.objects tb ON tb.object_id = ix.object_id
		AND tb.type = 'u'
	GROUP BY ix.object_id
		,tb.name
	) x ON x.id = cl.object_id
GROUP BY id
	,table_name
	,Total_index 
ORDER BY Total_column DESC

--Listagem 8. Consultas que mais consomem processamento do servidor.

SELECT TOP 10 (total_worker_time / execution_count) / 1000 AS [Avg CPU Time ms]
	,SUBSTRING(st.TEXT, (qs.statement_start_offset / 2) + 1, (
			(
				CASE qs.statement_end_offset
					WHEN - 1
						THEN DATALENGTH(st.TEXT)
					ELSE qs.statement_end_offset
					END - qs.statement_start_offset
				) / 2
			) + 1) AS statement_text
	,execution_count
	,last_execution_time
	,last_worker_time / 1000 AS last_worker_time
	,min_worker_time / 1000 AS min_worker_time
	,max_worker_time / 1000 AS max_worker_time
	,total_physical_reads
	,last_physical_reads
	,min_physical_reads
	,max_physical_reads
	,total_logical_writes
	,last_logical_writes
	,min_logical_writes
	,max_logical_writes
	,query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, DEFAULT, DEFAULT) AS qp
ORDER BY 1 DESC;
