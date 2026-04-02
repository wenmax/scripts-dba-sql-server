;

WITH IndexesColumns
AS (
	SELECT i.object_id
		,i.index_id
		,i.name
		,Keys = (
			STUFF(CAST((
						SELECT ',' + QUOTENAME(c.name) + ' ' + CASE 
								WHEN is_descending_key = 1
									THEN 'DESC'
								ELSE 'ASC'
								END + ' '
						FROM sys.index_columns ic
						INNER JOIN sys.columns c ON (
								ic.object_id = c.object_id
								AND ic.column_id = c.column_id
								)
						WHERE ic.is_included_column = 0
							AND ic.object_id = i.object_id
							AND ic.index_id = i.index_id
						ORDER BY Key_ordinal ASC
						FOR XML PATH('')
						) AS VARCHAR(MAX)), 1, 1, '')
			)
		,Incl = (
			STUFF(CAST((
						SELECT ',' + QUOTENAME(c.name)
						FROM sys.index_columns ic
						INNER JOIN sys.columns c ON (
								ic.object_id = c.object_id
								AND ic.column_id = c.column_id
								)
						WHERE ic.is_included_column = 1
							AND ic.object_id = i.object_id
							AND ic.index_id = i.index_id
						ORDER BY Key_ordinal ASC
						FOR XML PATH('')
						) AS VARCHAR(MAX)), 1, 1, '')
			)
		,fill_factor
		,is_padded
		,data_space_id
		,[ignore_dup_key]
		,is_unique
		,filter_definition
		,[allow_row_locks]
		,[allow_page_locks]
		,CASE i.type
			WHEN 1
				THEN 'CLUSTERED'
			WHEN 2
				THEN 'NONCLUSTERED'
			ELSE ''
			END AS [IndexType]
		,is_primary_key
	FROM sys.indexes i
	WHERE i.type IN (
			1
			,2
			) -- Apenas CLUSTERED e NONCLUSTERED
		AND is_hypothetical = 0 -- Ignora os índices hipotéticos
		AND is_disabled = 0
	)
SELECT 'CREATE ' + CASE 
		WHEN ics.is_unique = 1
			THEN 'UNIQUE '
		ELSE ''
		END + [IndexType] + ' INDEX ' + QUOTENAME(ics.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) + ' (' + ics.Keys + ') ' + CASE 
		WHEN ics.Incl IS NOT NULL
			THEN ' INCLUDE ' + '( ' + ics.Incl + ' )'
		ELSE ''
		END + CASE 
		WHEN filter_definition IS NOT NULL
			THEN ' WHERE ' + filter_definition
		ELSE ''
		END + ' WITH ( FILLFACTOR = ' + CAST(CASE fill_factor
			WHEN 0
				THEN 100
			ELSE fill_factor
			END AS VARCHAR(3)) + ', ' + 'PAD_INDEX = ' + CASE is_padded
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ', ' + ' IGNORE_DUP_KEY = ' + CASE [ignore_dup_key]
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ', ' + ' ALLOW_ROW_LOCKS = ' + CASE [allow_row_locks]
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ', ' + ' ALLOW_PAGE_LOCKS = ' + CASE [allow_page_locks]
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ')' + ' ON ' + QUOTENAME(FILEGROUP_NAME(ics.data_space_id)) + ';'
FROM IndexesColumns ics
INNER JOIN sys.tables t ON (ics.object_id = t.object_id)
WHERE is_primary_key = 0

UNION ALL

SELECT 'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(t.name) + ' ADD CONSTRAINT ' + QUOTENAME(ics.name) + ' PRIMARY KEY ' + [IndexType] + ' ( ' + ics.Keys + ')' + ' WITH ( FILLFACTOR = ' + CAST(CASE fill_factor
			WHEN 0
				THEN 100
			ELSE fill_factor
			END AS VARCHAR(3)) + ', ' + 'PAD_INDEX = ' + CASE is_padded
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ', ' + ' IGNORE_DUP_KEY = ' + CASE [ignore_dup_key]
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ', ' + ' ALLOW_ROW_LOCKS = ' + CASE [allow_row_locks]
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ', ' + ' ALLOW_PAGE_LOCKS = ' + CASE [allow_page_locks]
		WHEN 1
			THEN ' ON '
		ELSE ' OFF '
		END + ')' + ';'
FROM IndexesColumns ics
INNER JOIN sys.tables t ON (ics.object_id = t.object_id)
WHERE is_primary_key = 1;
