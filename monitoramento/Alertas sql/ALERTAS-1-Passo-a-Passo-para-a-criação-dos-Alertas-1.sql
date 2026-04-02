/***********************************************************************************************************************************
(C) 2016, Fabricio Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: fabricioflima@gmail.com
***********************************************************************************************************************************/


/*******************************************************************************************************************************
--	Sequência de execução de Scripts para criar os Alertas do Banco de Dados.
*******************************************************************************************************************************/

--------------------------------------------------------------------------------------------------------------------------------
-- 1)	Criar o Operator para colocar na Notificação de Falha dos JOBS que serão criados e também nos Alertas de Severidade
--		Cria a Base Traces
--------------------------------------------------------------------------------------------------------------------------------
USE [msdb]

GO

EXEC [msdb].[dbo].[sp_add_operator]
		@name = N'Alerta_BD',
		@enabled = 1,
		@pager_days = 0,
		@email_address = N'E-mail@provedor.com'	-- Para colocar mais destinatarios, basta separar o email com ponto e vírgula ";"
GO

/* 
-- Caso não tenha a base "Traces", execute o codigo abaixo (lembre de alterar o caminho também).
USE master

GO

--------------------------------------------------------------------------------------------------------------------------------
--	1.1) Alterar o caminho para um local existente no seu servidor.
--------------------------------------------------------------------------------------------------------------------------------
CREATE DATABASE [Traces] 
	ON  PRIMARY ( 
		NAME = N'Traces', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\Traces.mdf' , 
		SIZE = 102400KB , FILEGROWTH = 102400KB 
	)
	LOG ON ( 
		NAME = N'Traces_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\Traces_log.ldf' , 
		SIZE = 30720KB , FILEGROWTH = 30720KB 
	)
GO

--------------------------------------------------------------------------------------------------------------------------------
-- 1.2) Utilizar o Recovery Model SIMPLE, pois não tem muito impacto perder 1 dia de informação nessa base de log.
--------------------------------------------------------------------------------------------------------------------------------
ALTER DATABASE [Traces] SET RECOVERY SIMPLE

GO
*/

--------------------------------------------------------------------------------------------------------------------------------
-- 2)	Abrir o script "..\Caminho\ALERTAS - 2 - Criação da Tabela de Controle dos Alertas.txt", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 3)	Abrir o script "..\Caminho\ALERTAS - 3 - PreRequisito - QueriesDemoradas.txt", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 4)	Abrir o script "..\Caminho\ALERTAS - 4 - Criação das Procedures dos Alertas.txt", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 5)	Abrir o script "..\Caminho\ALERTAS - 5 - Criação dos JOBS dos Alertas.txt", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 6)	Abrir o script "..\Caminho\ALERTAS - 6 - Criação dos Alertas de Severidade.txt", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- 7)	Abrir o script "..\Caminho\ALERTAS - 7 - Teste Alertas.txt", ler as instruções e executá-lo.
--------------------------------------------------------------------------------------------------------------------------------