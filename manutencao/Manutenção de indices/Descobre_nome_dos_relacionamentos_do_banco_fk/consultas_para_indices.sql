/*Índice não utilizado.
O Script a seguir lista todos os índices que não foram usados. Também gera a instrução de DROP que pode ser útil ao excluir os índices.*/

SELECT o.name, indexname=i.name, i.index_id 
, reads=user_seeks + user_scans + user_lookups 
, writes = user_updates 
, rows = (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.index_id = s.index_id AND s.object_id = p.object_id)
, CASE
 WHEN s.user_updates < 1 THEN 100
 ELSE 1.00 * (s.user_seeks + s.user_scans + s.user_lookups) / s.user_updates
 END AS reads_per_write
, 'DROP INDEX ' + QUOTENAME(i.name) 
+ ' ON ' + QUOTENAME(c.name) + '.' + QUOTENAME(OBJECT_NAME(s.object_id)) as 'drop statement'
FROM sys.dm_db_index_usage_stats s 
INNER JOIN sys.indexes i ON i.index_id = s.index_id AND s.object_id = i.object_id 
INNER JOIN sys.objects o on s.object_id = o.object_id
INNER JOIN sys.schemas c on o.schema_id = c.schema_id
WHERE OBJECTPROPERTY(s.object_id,'IsUserTable') = 1
AND s.database_id = DB_ID() 
AND i.type_desc = 'nonclustered'
AND i.is_primary_key = 0
AND i.is_unique_constraint = 0
AND (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.index_id = s.index_id AND s.object_id = p.object_id) > 10000
ORDER BY reads


--Descobrir todos os índices que estão faltando.
--O SQL Server mantém um registo dos índices que acredita que você deve criar e que ajudarão a melhorar o desempenho das consultas. 
--O Script a seguir lista todos os índices ausentes.
SELECT  sys.objects.name
, (avg_total_user_cost * avg_user_impact) * (user_seeks + user_scans) AS Impact
,  'CREATE NONCLUSTERED INDEX ix_IndexName ON ' + sys.objects.name COLLATE DATABASE_DEFAULT + ' ( ' + IsNull(mid.equality_columns, '') + CASE WHEN mid.inequality_columns IS NULL
                THEN '' 
    ELSE CASE WHEN mid.equality_columns IS NULL
                    THEN '' 
        ELSE ',' END + mid.inequality_columns END + ' ) ' + CASE WHEN mid.included_columns IS NULL
                THEN '' 
    ELSE 'INCLUDE (' + mid.included_columns + ')' END + ';' AS CreateIndexStatement
, mid.equality_columns
, mid.inequality_columns
, mid.included_columns 
    FROM sys.dm_db_missing_index_group_stats AS migs 
            INNER JOIN sys.dm_db_missing_index_groups AS mig ON migs.group_handle = mig.index_group_handle 
            INNER JOIN sys.dm_db_missing_index_details AS mid ON mig.index_handle = mid.index_handle AND mid.database_id = DB_ID() 
            INNER JOIN sys.objects WITH (nolock) ON mid.OBJECT_ID = sys.objects.OBJECT_ID 
    WHERE     (migs.group_handle IN
        ( 
        SELECT     TOP (500) group_handle 
            FROM          sys.dm_db_missing_index_group_stats WITH (nolock) 
            ORDER BY (avg_total_user_cost * avg_user_impact) * (user_seeks + user_scans) DESC))  
        AND OBJECTPROPERTY(sys.objects.OBJECT_ID, 'isusertable')=1 
    ORDER BY 2 DESC , 3 DESC

--Query para descobrir a fragmentação de todos os índices

SELECT object_name(IPS.object_id) AS [TableName], 
   SI.name AS [IndexName], 
   IPS.Index_type_desc, 
   IPS.avg_fragmentation_in_percent, 
   IPS.avg_fragment_size_in_pages, 
   IPS.avg_page_space_used_in_percent, 
   IPS.record_count, 
   IPS.ghost_record_count,
   IPS.fragment_count, 
   IPS.avg_fragment_size_in_pages
FROM sys.dm_db_index_physical_stats(db_id(DB_NAME()), NULL, NULL, NULL , 'DETAILED') IPS
   JOIN sys.tables ST WITH (nolock) ON IPS.object_id = ST.object_id
   JOIN sys.indexes SI WITH (nolock) ON IPS.object_id = SI.object_id AND IPS.index_id = SI.index_id
WHERE ST.is_ms_shipped = 0
order by IPS.avg_fragment_size_in_pages desc

--Encontrando todos os índices.

SELECT OBJECT_SCHEMA_NAME(BaseT.[object_id],DB_ID()) AS [Schema], 
 BaseT.[name] AS [table_name], I.[name] AS [index_name], AC.[name] AS [column_name], 
 I.[type_desc]
FROM sys.[tables] AS BaseT 
 INNER JOIN sys.[indexes] I ON BaseT.[object_id] = I.[object_id] 
 INNER JOIN sys.[index_columns] IC ON I.[object_id] = IC.[object_id] 
 INNER JOIN sys.[all_columns] AC ON BaseT.[object_id] = AC.[object_id] AND IC.[column_id] = AC.[column_id] 
WHERE BaseT.[is_ms_shipped] = 0 AND I.[type_desc] <> 'HEAP'
ORDER BY BaseT.[name], I.[index_id], IC.[key_ordinal]

--Manutenção de índices:

--Rebuild índice.(manual)

USE AdventureWorks2008R2;
GO
ALTER INDEX PK_Employee_BusinessEntityID ON HumanResources.Employee
REBUILD;
GO
--Reorganize índice
USE AdventureWorks2008R2;
GO
ALTER INDEX PK_ProductPhoto_ProductPhotoID ON Production.ProductPhoto
REORGANIZE ;
GO
