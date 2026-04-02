SELECT NAME
	,CASE is_read_committed_snapshot_on
		WHEN 1
			THEN 'ENABLED'
		WHEN 0
			THEN 'DISABLED'
		END AS 'Read_Committed_Snapshot'
FROM SYS.DATABASES
WHERE NAME = 'Siga_CAI'
