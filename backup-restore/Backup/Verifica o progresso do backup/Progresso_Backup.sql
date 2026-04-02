

SELECT session_id as SPID, command, a.text AS Query, start_time, percent_complete, dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
FROM sys.dm_exec_requests r CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a
WHERE r.command in ('BACKUP DATABASE','RESTORE DATABASE','RESTORE HEADERONLY')



USE master;
GO
SELECT S.Host_Name AS [HostName], 
       S.Login_Name AS [LoginName], 
       R.Session_ID AS [SessionID], 
       CAST(R.Percent_Complete AS DECIMAL(10, 3)) AS [Percent], 
       ISNULL(DATEDIFF(minute, S.Last_Request_Start_Time, GETDATE()), 0) [MinutesRunning], 
       Start_Time AS [StartTime], 
       DATEADD(second, Estimated_Completion_Time / 1000, GETDATE()) AS [EstimatedCompletion], 
       DB_NAME(R.Database_ID) AS [DatabaseName], 
       (CASE
            WHEN S.Program_Name LIKE 'SQLAgent - TSQL JobStep (Job %'
            THEN J.Name
            ELSE S.Program_Name
        END) AS [ProgramName], 
       R.Command, 
       B.Text
FROM sys.dm_exec_requests R WITH(NOLOCK)
     JOIN sys.dm_exec_sessions S WITH(NOLOCK) ON R.Session_ID = S.Session_ID
     OUTER APPLY sys.dm_exec_sql_text(R.SQL_Handle) B
     LEFT OUTER JOIN msdb.dbo.sysjobs J WITH(NOLOCK) ON(SUBSTRING(LEFT(J.Job_ID, 8), 7, 2) + SUBSTRING(LEFT(J.Job_ID, 8), 5, 2) + SUBSTRING(LEFT(J.Job_ID, 8), 3, 2) + SUBSTRING(LEFT(J.Job_ID, 8), 1, 2)) = SUBSTRING(S.Program_Name, 32, 8)
WHERE R.Session_ID > 50
      AND R.Session_ID <> @@SPID
      AND S.[Host_Name] IS NOT NULL
      AND R.Command in ('BACKUP DATABASE','RESTORE DATABASE','RESTORE HEADERONLY')
ORDER BY S.[Host_Name], 
         S.Login_Name;