--CONSULTA JOBS QUE FORAM EXECUTADOS NA MADRUGA  

Select
*
From
msdb..sysjobhistory as sysjobhistory
Join msdb..sysjobs as sysjobs on sysjobhistory.job_id=sysjobhistory.job_id
Where
Name='nome da tarefa'
Order By
Run_Date Desc,
run_time Desc