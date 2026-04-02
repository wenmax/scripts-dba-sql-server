
-- Tabelas que não possuem chave primária
use st1714_l3
GO
SELECT DISTINCT DB_NAME() AS Banco ,name AS NomeTabela,p.rows
FROM sys.tables t    
JOIN sys.partitions p ON p.object_id = t.object_id
WHERE type = 'U'
and OBJECTPROPERTY(t.OBJECT_ID,'TableHasPrimaryKey') = 0
ORDER BY p.rows DESC;


--tabelas que nao tem indices clusterizado 
USE st1714_l3
GO
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


--Tabelas que mais seriam beneficiadas com novos índices.
use st1714_l3
go
DECLARE @DatabaseID int

SET @DatabaseID = DB_ID()

SELECT TOP 15 AVG((avg_total_user_cost * avg_user_impact * (user_seeks + user_scans))) AS Impacto, 
              mid.object_id, 
              mid.statement AS Tabela
FROM sys.dm_db_missing_index_group_stats AS migs
     JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
     JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
                                                   AND database_id = @DatabaseID
GROUP BY mid.object_id, 
         mid.statement
ORDER BY Impacto DESC;

-- Top 15 índices, sugeridos pelo SGBD.
use st1714_l3
go
DECLARE @DatabaseID int

SET @DatabaseID = DB_ID()

SELECT TOP 15(avg_total_user_cost * avg_user_impact * (user_seeks + user_scans)) AS Impacto, 
             migs.group_handle, 
             mid.index_handle, 
             migs.user_seeks, 
             migs.user_scans, 
             mid.object_id, 
             mid.statement, 
             mid.equality_columns, 
             mid.inequality_columns, 
             mid.included_columns
FROM sys.dm_db_missing_index_group_stats AS migs
     JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle
     JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle
                                                    AND database_id = @DatabaseID;--and mid.object_id = object_id(‘tabela’)  -- se desejar ver apenas para uma      tabela específica order by Impacto DESC;
-- Índices nunca utilizados pelo SGBD.
use st1714_l3
go
DECLARE @DatabaseID int

SET @DatabaseID = DB_ID()

SELECT tb.name AS Table_Name, 
       ix.name AS Index_Name, 
       ix.type_desc, 
       leaf_insert_count, 
       leaf_delete_count, 
       leaf_update_count, 
       nonleaf_insert_count, 
       nonleaf_delete_count, 
       nonleaf_update_count
FROM sys.dm_db_index_usage_stats vw
     JOIN sys.objects tb ON tb.object_id = vw.object_id
     JOIN sys.indexes ix ON ix.index_id = vw.index_id
                            AND ix.object_id = tb.object_id
     JOIN sys.dm_db_index_operational_stats(@DatabaseID, NULL, NULL, NULL) vwx ON vwx.object_id = tb.object_id
                                                                                              AND vwx.index_id = ix.index_id
WHERE vw.database_id = @DatabaseID
      AND vw.user_seeks = 0
      AND vw.user_scans = 0
      AND vw.user_lookups = 0
      AND vw.system_seeks = 0
      AND vw.system_scans = 0
      AND vw.system_lookups = 0
ORDER BY leaf_insert_count DESC, 
         tb.name ASC, 
         ix.name ASC;

--Avaliação de indices  
use st1714_l3
go
DECLARE @DatabaseID int

SET @DatabaseID = DB_ID()

SELECT @DatabaseID


SELECT 
     DB_NAME(DB_ID()) AS BANCO
	,object_name(vwx.object_id) AS TABELAS
	,ix.name
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
	,convert(REAL, ps.in_row_used_page_count) * 8192 / 1024 / 1024 as Total_Indice_Usado_MB
	,convert(REAL, ps.in_row_reserved_page_count) * 8192 / 1024 / 1024 AS Total_Indice_Reservado_MB
	,page_io_latch_wait_count
	,page_io_latch_wait_in_ms
FROM sys.dm_db_index_usage_stats vw
JOIN sys.indexes ix ON ix.index_id = vw.index_id
	AND ix.object_id = vw.object_id
JOIN sys.dm_db_index_operational_stats(db_id(), NULL, NULL, NULL) vwx ON vwx.index_id = ix.index_id -- segundo parametro da função usar objectid da tabela escolhida  
	AND ix.object_id = vwx.object_id
JOIN sys.dm_db_index_physical_stats(db_id(), NULL, NULL, NULL, 'SAMPLED') vwy ON vwy.index_id = ix.index_id
	AND ix.object_id = vwy.object_id
	AND vwy.partition_number = vwx.partition_number
JOIN sys.dm_db_partition_stats PS ON ps.index_id = vw.index_id
	AND ps.object_id = vw.object_id
WHERE vw.database_id = db_id()
	--AND object_name(vw.object_id) = 'Log'
ORDER BY user_seeks DESC
	,user_scans DESC



select db_id('swm_cai')
select db_id()
select OBJECT_ID(N'tbl_imagem_consulta_gerada')





SELECT dbschemas.[name] as 'Schema',
dbtables.[name] as 'Table',
dbindexes.[name] as 'Index',
indexstats.avg_fragmentation_in_percent,
indexstats.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.database_id = DB_ID()
ORDER BY indexstats.avg_fragmentation_in_percent desc

