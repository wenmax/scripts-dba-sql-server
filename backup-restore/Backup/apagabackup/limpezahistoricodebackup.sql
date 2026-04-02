select * 
from backupsetTransact-SQL

select  * from backupfile -- 2 milhões de registros
select *  from backupset  -- 1 milhão  de  registros
select count (*) from backupfile


DECLARE @d datetime

SET @d = DATEADD(dd, -30, GETDATE())

exec msdb.dbo.sp_delete_backuphistory @d

--historico de job 

SELECT A.Step_Id
	,A.Message
	,A.Run_Date
FROM msdb.dbo.Sysjobhistory A
JOIN msdb.dbo.Sysjobs B ON A.Job_Id = B.Job_Id
WHERE B.Name LIKE ' % Teste history % '
	AND A.Run_Date >= '20110308' — Data em que o job foi executado.
ORDER BY step_id
