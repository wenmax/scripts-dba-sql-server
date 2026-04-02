/*******************************************************************************************************************************
(C) 2016, Fabrício Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/

/*******************************************************************************************************************************
--	Sequência de execução de Scripts para gerar o CheckList do Banco de Dados.
*******************************************************************************************************************************/


--------------------------------------------------------------------------------------------------------------------------------
--	1)	Criar uma database chamada "Traces" no local onde você cria as databases no seu servidor.
--------------------------------------------------------------------------------------------------------------------------------

--	OBS: Caso você utilize uma database diferente de "Traces", será necessário substituir "Traces" por essa database!

--------------------------------------------------------------------------------------------------------------------------------
--	1.1) Alterar o caminho para um local existente no seu servidor.
--------------------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (
	select name
	from sys.databases 
	where name = 'Traces'
)
BEGIN
	CREATE DATABASE [Traces] 
		ON  PRIMARY ( 
			NAME = N'Traces', FILENAME = N'C:\TEMP\Traces.mdf' , 
			SIZE = 500 MB , FILEGROWTH = 500 MB 
		)
		LOG ON ( 
			NAME = N'Traces_log', FILENAME = N'C:\TEMP\Traces_log.ldf' , 
			SIZE = 100 MB , FILEGROWTH = 100 MB 
		)
END
GO

--------------------------------------------------------------------------------------------------------------------------------
-- 1.2) Utilizar o Recovery Model SIMPLE, pois não tem muito impacto perder 1 dia de informação nessa base de log.
--------------------------------------------------------------------------------------------------------------------------------
ALTER DATABASE [Traces] SET RECOVERY SIMPLE
 

 --------------------------------------------------------------------------------------------------------------------------------
-- 2.0)	Criar o Operator para colocar na Notificação de Falha dos JOBS que serão criados e também nos Alertas de Severidade
--------------------------------------------------------------------------------------------------------------------------------
USE [msdb]

GO

IF NOT EXISTS (
	select * 
	from msdb.dbo.sysoperators
	where name = 'Alerta_BD'
)
BEGIN
	EXEC [msdb].[dbo].[sp_add_operator]
		@name = N'Alerta_BD',
		@enabled = 1,
		@pager_days = 0,
		@email_address = N'E-mail@provedor.com'	-- Para colocar mais destinatarios, basta separar os e-mails com ponto e vírgula ";"
END

GO

--------------------------------------------------------------------------------------------------------------------------------
-- 2.1)	Abrir o script "..\Caminho\2 - PreRequisito - QueriesDemoradas.sql", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 2.2) Abrir os JOBS e conferir o JOB de Traces Criado.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 2.3) Conferir se o Trace foi criado corretamente.
--------------------------------------------------------------------------------------------------------------------------------
select * from fn_trace_getinfo (null)

--------------------------------------------------------------------------------------------------------------------------------
-- 2.4) Executar o Job Criado.
--------------------------------------------------------------------------------------------------------------------------------
EXEC msdb.dbo.sp_start_job 'DBA - Trace Banco de Dados'

--------------------------------------------------------------------------------------------------------------------------------
-- 2.5) Testar o Trace.
--------------------------------------------------------------------------------------------------------------------------------
-- Executar essa query.
waitfor delay '00:00:04'

-- Executar o job novamente.
EXEC msdb.dbo.sp_start_job 'DBA - Trace Banco de Dados'

-- Conferir se a query foi logada na tabela.
select * from Traces..Traces WHERE StartTime >= '20170411 12:00'

-- Se retornar um valor nessa tabela, já estamos logando as queries que mais demoram no ambiente!


--------------------------------------------------------------------------------------------------------------------------------
-- 3) Abrir o script "..\Caminho\3 - PreRequisito - DemaisRotinas.sql", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------
-- Esse Script criará as seguintes rotinas com um job para cada rotina:

-- 1) Contadores no SQL Server
-- 2) Tamanho de Tabelas
-- 3) Fragmentação de Índices
-- 4) WaitsStats

--------------------------------------------------------------------------------------------------------------------------------
-- 3.1) Contadores no SQL Server.
--------------------------------------------------------------------------------------------------------------------------------
-- Executar o job.
EXEC msdb.dbo.sp_start_job 'DBA - Carga Contadores SQL Server' 

-- Conferir se os dados estão sendo populados.
SELECT Nm_Contador,Dt_Log,Valor
FROM Traces..Contador A 
JOIN Traces..Registro_Contador B ON A.Id_Contador = B.Id_Contador
ORDER BY 1,2

--------------------------------------------------------------------------------------------------------------------------------
-- 3.2) Carga Fragmentação de índices.
--------------------------------------------------------------------------------------------------------------------------------

/*******************************************************************************************************************************
-- ATENÇÃO!!!
-- Esse job é pesado e pode impactar no desempenho do Banco de Dados. Favor deixar para executar de madrugada!!!
******************************************************************************************************************************/
-- Executar o job.
-- EXEC msdb.dbo.sp_start_job 'DBA - Carga Fragmentacao Indices'

-- Conferir se os dados estão sendo populados.
select *
from Traces..vwHistorico_Fragmentacao_Indice
order by Avg_Fragmentation_In_Percent desc

--------------------------------------------------------------------------------------------------------------------------------
-- 3.3) Tamanho de Tabelas.
--------------------------------------------------------------------------------------------------------------------------------
-- Executar o job.
EXEC msdb.dbo.sp_start_job 'DBA - Carga Tamanho Tabelas' 

-- Tamanho das bases.
select Nm_Database, SUM(Nr_Tamanho_Total) Tamanho_MB
from Traces..vwTamanho_Tabela
where Dt_Referencia = CAST(floor(CAST( GETDATE() AS FLOAT)) AS DATETIME)
group by Nm_Database
order by 2 DESC

-- Tamanho das tabelas.
select Nm_Database,Nm_Tabela, SUM(Nr_Tamanho_Total) Tamanho_MB, SUM(Qt_Linhas) Nr_Linhas
from Traces..vwTamanho_Tabela
WHERE Dt_Referencia = CAST(floor(CAST( GETDATE() AS FLOAT)) AS DATETIME)
group by Nm_Database,Nm_Tabela
order by 3 DESC

--------------------------------------------------------------------------------------------------------------------------------
-- 3.4) Contadores no SQL Server.
--------------------------------------------------------------------------------------------------------------------------------
-- Executar o job
EXEC msdb.dbo.sp_start_job 'DBA - Carga Wait Stats' 

-- Conferir se os dados estão sendo populados.
select top 10 * 
from Traces..Historico_Waits_Stats
where Dt_Referencia = (select max(Dt_Referencia) from Traces..Historico_Waits_Stats)
order by Percentage desc

--------------------------------------------------------------------------------------------------------------------------------
-- 4) Abrir o script "..\Caminho\4 - CheckList - Tabelas e Procedures.sql", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 5) Abrir o script "..\Caminho\5 - CheckList - Procedure de Envio do Email", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------
-- Verificar se o Job foi criado e executar.