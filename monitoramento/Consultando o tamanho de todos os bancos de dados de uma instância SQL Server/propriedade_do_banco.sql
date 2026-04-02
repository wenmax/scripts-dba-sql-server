
--Propriedade do banco 

SELECT * FROM sys.databases
SELECT * FROM sys.schemas
SELECT * FROM sys.objects
SELECT * FROM sys.tables
SELECT * FROM sys.columns
SELECT * FROM sys.identity_columns
SELECT * FROM sys.foreign_keys
SELECT * FROM sys.foreign_key_columns
SELECT * FROM sys.default_constraints
SELECT * FROM sys.check_constraints
SELECT * FROM sys.indexes
SELECT * FROM sys.index_columns
SELECT * FROM sys.triggers
SELECT * FROM sys.views
SELECT * FROM sys.procedures

--Database Diagnostics
--Database size
SELECT * FROM sys.database_files
SELECT * FROM sys.partitions
SELECT * FROM sys.allocation_units

SELECT object_name(a.object_id), c.name, SUM(rows) rows, SUM(total_pages) total_pages, SUM(used_pages) used_pages, SUM(data_pages) data_pages
FROM sys.partitions a INNER JOIN sys.allocation_units b ON a.hobt_id = b.container_id
    INNER JOIN sys.indexes c ON a.object_id = c.object_id and a.index_id = c.index_id
GROUP BY object_name(a.object_id), c.name
ORDER BY object_name(a.object_id), c.name