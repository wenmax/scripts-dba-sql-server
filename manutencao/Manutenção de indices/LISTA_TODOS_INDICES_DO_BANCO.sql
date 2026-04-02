--LISTA TODOS OS INDICES DE UM BANCO E CRIA O COMANDO DROP OU CREATE DE CADA OBJETO

SELECT t.NAME AS Tabela
	,i.name AS Indice
	,i.type_desc AS TipoIndice
	,REPLACE(REPLACE(KeyColumns, ' ASC ', ''), ' DESC ', '') AS KeyColumns
	,'DROP INDEX ' + i.name + ' ON dbo.' + t.NAME AS ScriptDROP
	,'CREATE ' + CASE 
		WHEN I.is_unique = 1
			THEN 'UNIQUE '
		ELSE ''
		END + I.type_desc COLLATE DATABASE_DEFAULT + ' INDEX ' + I.name + ' ON ' + SCHEMA_NAME(T.schema_id) + '.' + T.name + ' (' + KeyColumns + ') ' + ISNULL(' INCLUDE (' + IncludedColumns + ') ', '') + ' WITH (' + CASE 
		WHEN I.is_padded = 1
			THEN ' PAD_INDEX = ON '
		ELSE ' PAD_INDEX = OFF '
		END + ',' + 'FILLFACTOR = ' + CONVERT(CHAR(5), CASE 
			WHEN I.fill_factor = 0
				THEN 99
			ELSE I.fill_factor
			END) + ',' + -- default value
	'SORT_IN_TEMPDB = OFF ' + ',' + CASE 
		WHEN I.ignore_dup_key = 1
			THEN ' IGNORE_DUP_KEY = ON '
		ELSE ' IGNORE_DUP_KEY = OFF '
		END + ',' + CASE 
		WHEN ST.no_recompute = 0
			THEN ' STATISTICS_NORECOMPUTE = OFF '
		ELSE ' STATISTICS_NORECOMPUTE = ON '
		END + ',' + ' ONLINE = OFF ' + ',' + CASE 
		WHEN I.allow_row_locks = 1
			THEN ' ALLOW_ROW_LOCKS = ON '
		ELSE ' ALLOW_ROW_LOCKS = OFF '
		END + ',' + CASE 
		WHEN I.allow_page_locks = 1
			THEN ' ALLOW_PAGE_LOCKS = ON '
		ELSE ' ALLOW_PAGE_LOCKS = OFF '
		END + ') ON [' + DS.name + ' ] ' AS ScriptCREATE
FROM sys.indexes I
JOIN sys.tables T ON T.object_id = I.object_id
JOIN sys.sysindexes SI ON I.object_id = SI.id
	AND I.index_id = SI.indid
JOIN (
	SELECT *
	FROM (
		SELECT IC2.object_id
			,IC2.index_id
			,STUFF((
					SELECT ', ' + C.name + CASE 
							WHEN MAX(CONVERT(INT, IC1.is_descending_key)) = 1
								THEN ' DESC '
							ELSE ' ASC '
							END
					FROM sys.index_columns IC1
					JOIN sys.columns C ON C.object_id = IC1.object_id
						AND C.column_id = IC1.column_id
						AND IC1.is_included_column = 0
					WHERE IC1.object_id = IC2.object_id
						AND IC1.index_id = IC2.index_id
					GROUP BY IC1.object_id
						,C.name
						,index_id
					ORDER BY MAX(IC1.key_ordinal)
					FOR XML PATH('')
					), 1, 2, '') KeyColumns
		FROM sys.index_columns IC2
		GROUP BY IC2.object_id
			,IC2.index_id
		) tmp3
	) tmp4 ON I.object_id = tmp4.object_id
	AND I.Index_id = tmp4.index_id
JOIN sys.stats ST ON ST.object_id = I.object_id
	AND ST.stats_id = I.index_id
JOIN sys.data_spaces DS ON I.data_space_id = DS.data_space_id
JOIN sys.filegroups FG ON I.data_space_id = FG.data_space_id
LEFT JOIN (
	SELECT *
	FROM (
		SELECT IC2.object_id
			,IC2.index_id
			,STUFF((
					SELECT ', ' + C.name
					FROM sys.index_columns IC1
					JOIN sys.columns C ON C.object_id = IC1.object_id
						AND C.column_id = IC1.column_id
						AND IC1.is_included_column = 1
					WHERE IC1.object_id = IC2.object_id
						AND IC1.index_id = IC2.index_id
					GROUP BY IC1.object_id
						,C.name
						,index_id
					FOR XML PATH('')
					), 1, 2, '') IncludedColumns
		FROM sys.index_columns IC2
		GROUP BY IC2.object_id
			,IC2.index_id
		) tmp1
	WHERE IncludedColumns IS NOT NULL
	) tmp2 ON tmp2.object_id = I.object_id
	AND tmp2.index_id = I.index_id
ORDER BY t.NAME
	,i.index_id
