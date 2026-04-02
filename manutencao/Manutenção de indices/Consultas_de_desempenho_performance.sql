-- Tabelas que não possuem chave primária
use st1714_l3
GO

SELECT DISTINCT name AS NomeTabela,p.rows
FROM sys.tables t    
JOIN sys.partitions p ON p.object_id = t.object_id
WHERE type = 'U'
and OBJECTPROPERTY(t.OBJECT_ID,'TableHasPrimaryKey') = 0
ORDER BY p.rows DESC;


--Tabelas que mais seriam beneficiadas com novos índices.
use Siga_CAI
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
use Siga_CAI
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
                                                    AND database_id = @DatabaseID --and mid.object_id = object_id(‘tabela’)  -- se desejar ver apenas para uma      tabela específica 
													order by Impacto DESC;


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


-- Avaliando fragmentação dos indices 
use st1714_l3
go
DECLARE @DatabaseID int

SET @DatabaseID = DB_ID()

SELECT DB_NAME(@DatabaseID) AS DatabaseName,
       schemas.[name] AS SchemaName,
       objects.[name] AS ObjectName,
       indexes.[name] AS IndexName,
       objects.type_desc AS ObjectType,
       indexes.type_desc AS IndexType,
       dm_db_index_physical_stats.partition_number AS PartitionNumber,
       dm_db_index_physical_stats.page_count AS [PageCount],
       dm_db_index_physical_stats.avg_fragmentation_in_percent AS AvgFragmentationInPercent
FROM sys.dm_db_index_physical_stats (@DatabaseID, NULL, NULL, NULL, 'LIMITED') dm_db_index_physical_stats
INNER JOIN sys.indexes indexes ON dm_db_index_physical_stats.[object_id] = indexes.[object_id] AND dm_db_index_physical_stats.index_id = indexes.index_id
INNER JOIN sys.objects objects ON indexes.[object_id] = objects.[object_id]
INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id]
WHERE objects.[type] IN('U','V')
AND objects.is_ms_shipped = 0
AND indexes.[type] IN(1,2,3,4)
AND indexes.is_disabled = 0
AND indexes.is_hypothetical = 0
AND dm_db_index_physical_stats.alloc_unit_type_desc = 'IN_ROW_DATA'
AND dm_db_index_physical_stats.index_level = 0
AND dm_db_index_physical_stats.page_count >= 1000




----Option 1
SELECT DISTINCT so.name
FROM syscomments sc
INNER JOIN sysobjects so ON sc.id=so.id
WHERE sc.TEXT LIKE '%tablename%'
----Option 2
SELECT DISTINCT o.name, o.xtype
FROM syscomments c
INNER JOIN sysobjects o ON c.id=o.id
WHERE c.TEXT LIKE '%tablename%'


--Descobre a primary key das tabelas de um banco 

SELECT
K_Table = FK.TABLE_NAME,
FK_Column = CU.COLUMN_NAME,
PK_Table = PK.TABLE_NAME,
PK_Column = PT.COLUMN_NAME,
Constraint_Name = C.CONSTRAINT_NAME
FROM INFORMATION_SCHEMA.REFERENTIAL_CONSTRAINTS C
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS FK ON C.CONSTRAINT_NAME = FK.CONSTRAINT_NAME
INNER JOIN INFORMATION_SCHEMA.TABLE_CONSTRAINTS PK ON C.UNIQUE_CONSTRAINT_NAME = PK.CONSTRAINT_NAME
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE CU ON C.CONSTRAINT_NAME = CU.CONSTRAINT_NAME
INNER JOIN (
SELECT i1.TABLE_NAME, i2.COLUMN_NAME
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS i1
INNER JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE i2 ON i1.CONSTRAINT_NAME = i2.CONSTRAINT_NAME
WHERE i1.CONSTRAINT_TYPE = 'PRIMARY KEY'
) PT ON PT.TABLE_NAME = PK.TABLE_NAME
---- optional:
--ORDER BY
--1,2,3,4
--WHERE PK.TABLE_NAME='something'WHERE FK.TABLE_NAME='something'
--WHERE PK.TABLE_NAME IN ('one_thing', 'another')
--WHERE FK.TABLE_NAME IN ('one_thing', 'another')


--Colunas que sao chave primaria 

SELECT A.Name,Col.Column_Name from 

    INFORMATION_SCHEMA.TABLE_CONSTRAINTS Tab, 

    INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE Col ,

    (select NAME from dbo.sysobjects where xtype='u') AS A

WHERE 

    Col.Constraint_Name = Tab.Constraint_Name

    AND Col.Table_Name = Tab.Table_Name

    AND Constraint_Type = 'PRIMARY KEY '

    AND Col.Table_Name = A.Name


