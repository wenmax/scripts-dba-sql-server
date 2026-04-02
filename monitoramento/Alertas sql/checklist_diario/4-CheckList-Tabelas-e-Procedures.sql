/*******************************************************************************************************************************
(C) 2016, Fabricio Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/

/*******************************************************************************************************************************

--	Criação das tabelas que serão utilizadas para gerar o relatório do CheckList em HTML

--	INSTRUÇÕES DE USO: 

--	Apenas executar os scripts e conferir AS tabelas e procedures criadas na database desejada.

*******************************************************************************************************************************/

/*******************************************************************************************************************************
--	Database que será utilizada para armazenar os dados do CheckList. Se for necessário, altere o nome da mesma.
*******************************************************************************************************************************/
use Traces

GO
/*******************************************************************************************************************************
--	Criação das tabelas para armazenar os dados do CheckList
*******************************************************************************************************************************/
IF (OBJECT_ID('[dbo].[CheckList_Espaco_Disco]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Espaco_Disco]

CREATE TABLE [dbo].[CheckList_Espaco_Disco] (
	[DriveName]			VARCHAR(256) NULL,
	[TotalSize_GB]		BIGINT NULL,
	[FreeSpace_GB]		BIGINT NULL,
	[SpaceUsed_GB]		BIGINT NULL,
	[SpaceUsed_Percent] DECIMAL(9, 3) NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Arquivos_Dados]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Arquivos_Dados]

CREATE TABLE [dbo].[CheckList_Arquivos_Dados] (
	[Server]			VARCHAR(50),
	[Nm_Database]		VARCHAR(100),
	[Logical_Name]		VARCHAR(100),
	[FileName]			VARCHAR(200),
	[Total_Reservado]	NUMERIC(15,2),
	[Total_Utilizado]	NUMERIC(15,2),
	[Espaco_Livre (MB)] NUMERIC(15,2), 
	[Espaco_Livre (%)]	NUMERIC(15,2), 
	[MaxSize]			INT,
	[Growth]			VARCHAR(25),
	[NextSize]			NUMERIC(15,2),
	[Fl_Situacao]		CHAR(1)
)

IF (OBJECT_ID('[dbo].[CheckList_Arquivos_Log]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Arquivos_Log]

CREATE TABLE [dbo].[CheckList_Arquivos_Log] (
	[Server]			VARCHAR(50),
	[Nm_Database]		VARCHAR(100),
	[Logical_Name]		VARCHAR(100),
	[FileName]			VARCHAR(200),
	[Total_Reservado]	NUMERIC(15,2),
	[Total_Utilizado]	NUMERIC(15,2),
	[Espaco_Livre (MB)] NUMERIC(15,2), 
	[Espaco_Livre (%)]	NUMERIC(15,2), 
	[MaxSize]			INT,
	[Growth]			VARCHAR(25),
	[NextSize]			NUMERIC(15,2),
	[Fl_Situacao]		CHAR(1)
)

IF (OBJECT_ID('[dbo].[CheckList_Database_Growth]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Database_Growth]
	
CREATE TABLE [dbo].[CheckList_Database_Growth] (
	[Nm_Servidor]	VARCHAR(50) NULL,
	[Nm_Database]	VARCHAR(100) NULL,
	[Tamanho_Atual] NUMERIC(38, 2) NULL,
	[Cresc_1_dia]	NUMERIC(38, 2) NULL,
	[Cresc_15_dia]	NUMERIC(38, 2) NULL,
	[Cresc_30_dia]	NUMERIC(38, 2) NULL,
	[Cresc_60_dia]	NUMERIC(38, 2) NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Database_Growth_Email]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Database_Growth_Email]
	
CREATE TABLE [dbo].[CheckList_Database_Growth_Email] (
	[Nm_Servidor]	VARCHAR(50) NULL,
	[Nm_Database]	VARCHAR(100) NULL,
	[Tamanho_Atual] NUMERIC(38, 2) NULL,
	[Cresc_1_dia]	NUMERIC(38, 2) NULL,
	[Cresc_15_dia]	NUMERIC(38, 2) NULL,
	[Cresc_30_dia]	NUMERIC(38, 2) NULL,
	[Cresc_60_dia]	NUMERIC(38, 2) NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Table_Growth]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Table_Growth]
	
CREATE TABLE [dbo].[CheckList_Table_Growth] (
	[Nm_Servidor]	VARCHAR(50) NULL,
	[Nm_Database]	VARCHAR(100) NULL,
	[Nm_Tabela]		VARCHAR(100) NULL,
	[Tamanho_Atual] NUMERIC(38, 2) NULL,
	[Cresc_1_dia]	NUMERIC(38, 2) NULL,
	[Cresc_15_dia]	NUMERIC(38, 2) NULL,
	[Cresc_30_dia]	NUMERIC(38, 2) NULL,
	[Cresc_60_dia]	NUMERIC(38, 2) NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Table_Growth_Email]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Table_Growth_Email]
	
CREATE TABLE [dbo].[CheckList_Table_Growth_Email] (
	[Nm_Servidor]	VARCHAR(50) NULL,
	[Nm_Database]	VARCHAR(100) NULL,
	[Nm_Tabela]		VARCHAR(100) NULL,
	[Tamanho_Atual] NUMERIC(38, 2) NULL,
	[Cresc_1_dia]	NUMERIC(38, 2) NULL,
	[Cresc_15_dia]	NUMERIC(38, 2) NULL,
	[Cresc_30_dia]	NUMERIC(38, 2) NULL,
	[Cresc_60_dia]	NUMERIC(38, 2) NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Utilizacao_Arquivo_Writes]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Utilizacao_Arquivo_Writes]

CREATE TABLE [dbo].[CheckList_Utilizacao_Arquivo_Writes](
	[Nm_Database] [nvarchar](200) NOT NULL,
	[file_id] [smallint] NULL,	
	[io_stall_write_ms] [bigint] NULL,
	[num_of_writes] [bigint] NULL,
	[avg_write_stall_ms] [numeric](15, 1) NULL
) ON [PRIMARY]

IF (OBJECT_ID('[dbo].[CheckList_Utilizacao_Arquivo_Reads]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Utilizacao_Arquivo_Reads]

CREATE TABLE [dbo].[CheckList_Utilizacao_Arquivo_Reads](
	[Nm_Database] [nvarchar](200) NOT NULL,
	[file_id] [smallint] NULL,
	[io_stall_read_ms] [bigint] NULL,
	[num_of_reads] [bigint] NULL,
	[avg_read_stall_ms] [numeric](15, 1) NULL
) ON [PRIMARY]

IF (OBJECT_ID('[dbo].[CheckList_Databases_Sem_Backup]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Databases_Sem_Backup]
	
CREATE TABLE [dbo].[CheckList_Databases_Sem_Backup] (
	[Nm_Database] VARCHAR(100) NOT NULL	
)

IF (OBJECT_ID('[dbo].[CheckList_Backups_Executados]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Backups_Executados]
	
CREATE TABLE [dbo].[CheckList_Backups_Executados] (
	[Database_Name]			VARCHAR(128) NULL,
	[Name]					VARCHAR(128) NULL,
	[Backup_Start_Date]		DATETIME NULL,
	[Tempo_Min]				INT NULL,
	[Position]				INT NULL,
	[Server_Name]			VARCHAR(128) NULL,
	[Recovery_Model]		VARCHAR(60) NULL,
	[Logical_Device_Name]	VARCHAR(128) NULL,
	[Device_Type]			TINYINT NULL,
	[Type]					CHAR(1) NULL,
	[Tamanho_MB]			NUMERIC(15, 2) NULL
)

IF ( OBJECT_ID('[dbo].[CheckList_Queries_Running]') IS NOT NULL )
	DROP TABLE [dbo].[CheckList_Queries_Running]
				
CREATE TABLE [dbo].[CheckList_Queries_Running] (		
	[dd hh:mm:ss.mss]		VARCHAR(20),
	[database_name]			NVARCHAR(128),		
	[login_name]			NVARCHAR(128),
	[host_name]				NVARCHAR(128),
	[start_time]			DATETIME,
	[status]				VARCHAR(30),
	[session_id]			INT,
	[blocking_session_id]	INT,
	[wait_info]				VARCHAR(MAX),
	[open_tran_count]		INT,
	[CPU]					VARCHAR(MAX),
	[reads]					VARCHAR(MAX),
	[writes]				VARCHAR(MAX),
	[sql_command]			VARCHAR(MAX)
)

IF (OBJECT_ID('[dbo].[CheckList_Jobs_Failed]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Jobs_Failed]
	
CREATE TABLE [dbo].[CheckList_Jobs_Failed] (
	[Server]		VARCHAR(50),
	[Job_Name]		VARCHAR(255),
	[Status]		VARCHAR(25),
	[Dt_Execucao]	VARCHAR(20),
	[Run_Duration]	VARCHAR(8),
	[SQL_Message]	VARCHAR(4490)
)

IF (OBJECT_ID('[dbo].[CheckList_Alteracao_Jobs]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Alteracao_Jobs]

CREATE TABLE [dbo].[CheckList_Alteracao_Jobs] (
	[Nm_Job]			VARCHAR(1000),
	[Fl_Habilitado]		TINYINT,
	[Dt_Criacao]		DATETIME,
	[Dt_Modificacao]	DATETIME,
	[Nr_Versao]			SMALLINT
)

IF (OBJECT_ID('[dbo].[CheckList_Job_Demorados]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Job_Demorados]

CREATE TABLE [dbo].[CheckList_Job_Demorados] (
	[Job_Name]		VARCHAR(255) NULL,
	[Status]		VARCHAR(19) NULL,
	[Dt_Execucao]	VARCHAR(30) NULL,
	[Run_Duration]	VARCHAR(8) NULL,
	[SQL_Message]	VARCHAR(3990) NULL
) 

IF (OBJECT_ID('[dbo].[CheckList_Jobs_Running]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Jobs_Running]
	
CREATE TABLE [dbo].[CheckList_Jobs_Running](
	[Nm_JOB] [varchar](256) NULL,
	[Dt_Inicio] [varchar](16) NULL,
	[Qt_Duracao] [varchar](60) NULL,
	[Nm_Step] [varchar](256) NULL
) ON [PRIMARY]
	
IF (OBJECT_ID('[dbo].[CheckList_Traces_Queries]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Traces_Queries]
	
CREATE TABLE [dbo].[CheckList_Traces_Queries] (
	[PrefixoQuery]	VARCHAR(400),
	[QTD]			INT,
	[Total]			NUMERIC(15,2),
	[Media]			NUMERIC(15,2),
	[Menor]			NUMERIC(15,2),
	[Maior]			NUMERIC(15,2),
	[Writes]		BIGINT,
	[CPU]			BIGINT,
	[Reads]			BIGINT,
	[Ordem]			TINYINT
)

IF (OBJECT_ID('[dbo].[CheckList_Traces_Queries_Geral]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Traces_Queries_Geral]
	
CREATE TABLE [dbo].[CheckList_Traces_Queries_Geral] (
	[Data]	VARCHAR(50),
	[QTD]	INT
)

IF (OBJECT_ID('[dbo].[CheckList_Conexao_Aberta]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Conexao_Aberta]

CREATE TABLE [dbo].[CheckList_Conexao_Aberta](
	[login_name] [nvarchar](256) NULL,
	[session_count] [int] NULL
) ON [PRIMARY]

IF (OBJECT_ID('[dbo].[CheckList_Conexao_Aberta_Email]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Conexao_Aberta_Email]

CREATE TABLE [dbo].[CheckList_Conexao_Aberta_Email](
	[Nr_Ordem] INT NULL,
	[login_name] [nvarchar](256) NULL,
	[session_count] [int] NULL
) ON [PRIMARY]

IF (OBJECT_ID('[dbo].[CheckList_Contadores]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Contadores]
	
CREATE TABLE [dbo].[CheckList_Contadores] (
	[Hora]			TINYINT,
	[Nm_Contador]	VARCHAR(60),
	[Media]			BIGINT
)

IF (OBJECT_ID('[dbo].[CheckList_Contadores_Email]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Contadores_Email]

CREATE TABLE [dbo].[CheckList_Contadores_Email](
	[Hora] [varchar](30) NOT NULL,
	[BatchRequests] [varchar](30) NOT NULL,
	[CPU] [varchar](30) NOT NULL,
	[Page_Life_Expectancy] [varchar](30) NOT NULL,
	[User_Connection] [varchar](30) NOT NULL,
	[Qtd_Queries_Lentas] [varchar](30) NOT NULL,
	[Reads_Queries_Lentas] [varchar](30) NOT NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Fragmentacao_Indices]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Fragmentacao_Indices]
	
CREATE TABLE [dbo].[CheckList_Fragmentacao_Indices] (
	[Dt_Referencia]					DATETIME NULL,
	[Nm_Servidor]					VARCHAR(100) NULL,
	[Nm_Database]					VARCHAR(1000) NULL,
	[Nm_Tabela]						VARCHAR(1000) NULL,
	[Nm_Indice]						VARCHAR(1000) NULL,
	[Avg_Fragmentation_In_Percent]	NUMERIC(5, 2) NULL,
	[Page_Count]					INT NULL,
	[Fill_Factor]					TINYINT NULL,
	[Fl_Compressao]					TINYINT NULL
)

IF (OBJECT_ID('[dbo].[CheckList_Waits_Stats]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Waits_Stats]
	
CREATE TABLE [dbo].[CheckList_Waits_Stats] (
	[WaitType]			VARCHAR(100),
	[Min_Log]			DATETIME,
	[Max_Log]			DATETIME,
	[DIf_Wait_S]		DECIMAL(14, 2),
	[DIf_Resource_S]	DECIMAL(14, 2),
	[DIf_Signal_S]		DECIMAL(14, 2),
	[DIf_WaitCount]		BIGINT,
	[DIf_Percentage]	DECIMAL(4, 2),
	[Last_Percentage]	DECIMAL(4, 2)
)

IF (OBJECT_ID('[dbo].[CheckList_SQLServer_LoginFailed]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_SQLServer_LoginFailed]
	
CREATE TABLE [dbo].[CheckList_SQLServer_LoginFailed] (	
	[Text]		VARCHAR(MAX),
	[Qt_Erro]	INT
)

IF (OBJECT_ID('[dbo].[CheckList_SQLServer_LoginFailed_Email]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_SQLServer_LoginFailed_Email]
	
CREATE TABLE [dbo].[CheckList_SQLServer_LoginFailed_Email] (
	[Nr_Ordem]	INT,
	[Text]		VARCHAR(MAX),
	[Qt_Erro]	INT
)

IF (OBJECT_ID('[dbo].[CheckList_SQLServer_ErrorLog]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_SQLServer_ErrorLog]
	
CREATE TABLE [dbo].[CheckList_SQLServer_ErrorLog] (
	[Dt_Log]		DATETIME,
	[ProcessInfo]	VARCHAR(100),
	[Text]			VARCHAR(MAX)
)


GO
IF (OBJECT_ID('[dbo].[fncRetira_Caractere_Invalido_XML]') IS NOT NULL)
	DROP FUNCTION [dbo].[fncRetira_Caractere_Invalido_XML]
GO

/*
OBJETIVO: Procedure responsável por retirar os caracteres inválidos para o XML.

-- EXEMPLO EXECUÇÃO
SELECT dbo.fncRetira_Caractere_Invalido_XML('teste')
*/

CREATE FUNCTION [dbo].[fncRetira_Caractere_Invalido_XML] (
	@Text VARCHAR(MAX)
)
RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @Result NVARCHAR(4000)

	SELECT @Result = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE
							(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE
									(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE
											(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE
													(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE( 
																													@Text
													 ,NCHAR(1),N'?'),NCHAR(2),N'?'),NCHAR(3),N'?'),NCHAR(4),N'?'),NCHAR(5),N'?'),NCHAR(6),N'?')
											 ,NCHAR(7),N'?'),NCHAR(8),N'?'),NCHAR(11),N'?'),NCHAR(12),N'?'),NCHAR(14),N'?'),NCHAR(15),N'?')
									 ,NCHAR(16),N'?'),NCHAR(17),N'?'),NCHAR(18),N'?'),NCHAR(19),N'?'),NCHAR(20),N'?'),NCHAR(21),N'?')
							 ,NCHAR(22),N'?'),NCHAR(23),N'?'),NCHAR(24),N'?'),NCHAR(25),N'?'),NCHAR(26),N'?'),NCHAR(27),N'?')
						 ,NCHAR(28),N'?'),NCHAR(29),N'?'),NCHAR(30),N'?'),NCHAR(31),N'?');

	RETURN @Result
END

GO

/*******************************************************************************************************************************
-- Criação das procedures para popular as tabelas criadas acima:
--	1) Espaço em Disco
--	2) Arquivos MDF e LDF
--	3) Crescimento Database
--	4) Crescimento Tabela
--	5) Backups Executados
--	6) JOBS que Falharam
--	7) JOBS Alterados
--	8) JOBS Demorados
--	9) Trace Queries Demoradas
--	10) Contadores
--	11) Fragmentação de Índices
--	12) Waits Stats
--	13) Error Log SQL
*******************************************************************************************************************************/

-- Libera permissões para pegar informações de acesso a disco com a proc sp_OACreate
EXEC sp_configure 'show advanced option',1

RECONFIGURE WITH OVERRIDE

EXEC sp_configure 'Ole Automation Procedures',1

RECONFIGURE WITH OVERRIDE
 
EXEC sp_configure 'show advanced option',0

RECONFIGURE WITH OVERRIDE

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Espaco_Disco]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Espaco_Disco]
GO

/*******************************************************************************************************************************
--	Espaço em Disco
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Espaco_Disco]
AS
BEGIN
	SET NOCOUNT ON 

	CREATE TABLE #dbspace (
		[Name]		SYSNAME,
		[Caminho]	VARCHAR(200),
		[Tamanho]	VARCHAR(10),
		[Drive]		VARCHAR(30)
	)

	CREATE TABLE [#espacodisco] (
		[Drive]				VARCHAR(10) ,
		[Tamanho (MB)]		INT,
		[Usado (MB)]		INT,
		[Livre (MB)]		INT,
		[Livre (%)]			INT,
		[Usado (%)]			INT,
		[Ocupado SQL (MB)]	INT, 
		[Data]				SMALLDATETIME
	)

	EXEC sp_MSforeachdb '	Use [?] 
							INSERT INTO #dbspace 
							SELECT	CONVERT(VARCHAR(25), DB_NAME())''Database'', CONVERT(VARCHAR(60), FileName),
									CONVERT(VARCHAR(8), Size/128) ''Size in MB'', CONVERT(VARCHAR(30), Name) 
							FROM [sysfiles]'

	DECLARE @hr INT, @fso INT, @size FLOAT, @TotalSpace INT, @MBFree INT, @Percentage INT, 
			@SQLDriveSize INT, @drive VARCHAR(1), @fso_Method VARCHAR(255), @mbtotal INT = 0	
	
	EXEC @hr = [master].[dbo].[sp_OACreate] 'Scripting.FilesystemObject', @fso OUTPUT

	IF (OBJECT_ID('tempdb..#space') IS NOT NULL) 
		DROP TABLE #space

	CREATE TABLE #space (
		[drive] CHAR(1), 
		[mbfree] INT
	)
	
	INSERT INTO #space EXEC [master].[dbo].[xp_fixeddrives]
	
	DECLARE CheckDrives Cursor For SELECT [drive], [mbfree] 
	FROM #space
	
	Open CheckDrives
	FETCH NEXT FROM CheckDrives INTO @drive, @MBFree
	WHILE(@@FETCH_STATUS = 0)
	BEGIN
		SET @fso_Method = 'Drives("' + @drive + ':").TotalSize'
		
		SELECT @SQLDriveSize = SUM(CONVERT(INT, Tamanho)) 
		FROM #dbspace 
		WHERE SUBSTRING(Caminho, 1, 1) = @drive
		
		EXEC @hr = sp_OAMethod @fso, @fso_Method, @size OUTPUT
		
		SET @mbtotal = @size / (1024 * 1024)
		
		INSERT INTO #espacodisco 
		VALUES(	@drive + ':', @mbtotal, @mbtotal-@MBFree, @MBFree, (100 * round(@MBFree, 2) / round(@mbtotal, 2)), 
				(100 - 100 * round(@MBFree,2) / round(@mbtotal, 2)), @SQLDriveSize, GETDATE())

		FETCH NEXT FROM CheckDrives INTO @drive, @MBFree
	END
	CLOSE CheckDrives
	DEALLOCATE CheckDrives

	TRUNCATE TABLE [dbo].[CheckList_Espaco_Disco]
	
	INSERT INTO [dbo].[CheckList_Espaco_Disco]( [DriveName], [TotalSize_GB], [FreeSpace_GB], [SpaceUsed_GB], [SpaceUsed_Percent] )
	SELECT [Drive], [Tamanho (MB)], [Livre (MB)], [Usado (MB)], [Usado (%)] 
	FROM #espacodisco

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Espaco_Disco]( [DriveName], [TotalSize_GB], [FreeSpace_GB], [SpaceUsed_GB], [SpaceUsed_Percent] )
		SELECT 'Sem registro de Espaço em Disco', NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Arquivos_MDF_LDF]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Arquivos_MDF_LDF]
GO

/*******************************************************************************************************************************
--	Arquivos MDF e LDF
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Arquivos_MDF_LDF]
AS
BEGIN
	SET NOCOUNT ON

	-- COLETA DE INFORMAÇÕES SOBRE ARQUIVOS MDF
	IF (OBJECT_ID('tempdb..##MDFs_Sizes') IS NOT NULL)
		DROP TABLE ##MDFs_Sizes

	CREATE TABLE ##MDFs_Sizes (
		[Server]			VARCHAR(50),
		[Nm_Database]		VARCHAR(100),
		[Logical_Name]		VARCHAR(100),
		[Size]				NUMERIC(15,2),
		[Total_Utilizado]	NUMERIC(15,2),
		[Espaco_Livre (MB)] NUMERIC(15,2),
		[Percent_Free] NUMERIC(15,2)
	)

	EXEC sp_MSforeachdb '
		Use [?]

			;WITH cte_datafiles AS 
			(
			  SELECT name, size = size/128.0 FROM sys.database_files
			),
			cte_datainfo AS
			(
			  SELECT	name, CAST(size as numeric(15,2)) as size, 
						CAST( (CONVERT(INT,FILEPROPERTY(name,''SpaceUsed''))/128.0) as numeric(15,2)) as used, 
						free = CAST( (size - (CONVERT(INT,FILEPROPERTY(name,''SpaceUsed''))/128.0)) as numeric(15,2))
			  FROM cte_datafiles
			)

			INSERT INTO ##MDFs_Sizes
			SELECT	@@SERVERNAME, DB_NAME(), name as [Logical_Name], size, used, free,
					percent_free = case when size <> 0 then cast((free * 100.0 / size) as numeric(15,2)) else 0 end
			FROM cte_datainfo	
	'
	
	-- ARMAZENA OS DADOS	
	TRUNCATE TABLE [dbo].[CheckList_Arquivos_Dados]
	TRUNCATE TABLE [dbo].[CheckList_Arquivos_Log]
	
	-- Arquivos de Dados (MDF e NDF)
	INSERT INTO [dbo].[CheckList_Arquivos_Dados] (	[Server], [Nm_Database], [Logical_Name], [FileName], [Total_Reservado], [Total_Utilizado], 
													[Espaco_Livre (MB)], [Espaco_Livre (%)], [MaxSize], [Growth] )
	SELECT	@@SERVERNAME AS [Server],
			DB_NAME(A.database_id) AS [Nm_Database],
			[name] AS [Logical_Name],
			A.[physical_name] AS [Filename],
			B.[Size] AS [Total_Reservado],
			B.[Total_Utilizado],
			B.[Espaco_Livre (MB)] AS [Espaco_Livre (MB)],
			B.[Percent_Free] AS [Espaco_Livre (%)],
			CASE WHEN A.[Max_Size] = -1 THEN -1 ELSE (A.[Max_Size] / 1024) * 8 END AS [MaxSize(MB)], 
			CASE WHEN [is_percent_growth] = 1 
				THEN CAST(A.[Growth] AS VARCHAR) + ' %'
				ELSE CAST(CAST((A.[Growth] * 8 ) / 1024.00 AS NUMERIC(15, 2)) AS VARCHAR) + ' MB'
			END AS [Growth]
	FROM [sys].[master_files] A WITH(NOLOCK)	
		JOIN ##MDFs_Sizes B ON DB_NAME(A.[database_id]) = B.[Nm_Database] and A.[name] = B.[Logical_Name]
	WHERE	A.[type_desc] <> 'FULLTEXT'
			and A.type = 0	-- Arquivos de Dados (MDF e NDF)

	IF ( @@ROWCOUNT = 0 )
	BEGIN
		INSERT INTO [dbo].[CheckList_Arquivos_Dados] (	[Server], [Nm_Database], [Logical_Name], [FileName], [Total_Reservado], [Total_Utilizado], 
														[Espaco_Livre (MB)], [Espaco_Livre (%)], [MaxSize], [Growth], [NextSize], [Fl_Situacao] )
		SELECT	NULL, 'Sem registro dos Arquivos de Dados (MDF e NDF)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END

	-- Arquivos de Log (LDF)
	INSERT INTO [dbo].[CheckList_Arquivos_Log] (	[Server], [Nm_Database], [Logical_Name], [FileName], [Total_Reservado], [Total_Utilizado], 
													[Espaco_Livre (MB)], [Espaco_Livre (%)], [MaxSize], [Growth] )
	SELECT	@@SERVERNAME AS [Server],
			DB_NAME(A.database_id) AS [Nm_Database],
			[name] AS [Logical_Name],
			A.[physical_name] AS [Filename],
			B.[Size] AS [Total_Reservado],
			B.[Total_Utilizado],
			B.[Espaco_Livre (MB)] AS [Espaco_Livre (MB)],
			B.[Percent_Free] AS [Espaco_Livre (%)],
			CASE WHEN A.[Max_Size] = -1 THEN -1 ELSE (A.[Max_Size] / 1024) * 8 END AS [MaxSize(MB)], 
			CASE WHEN [is_percent_growth] = 1 
				THEN CAST(A.[Growth] AS VARCHAR) + ' %'
				ELSE CAST(CAST((A.[Growth] * 8 ) / 1024.00 AS NUMERIC(15, 2)) AS VARCHAR) + ' MB'
			END AS [Growth]
	FROM [sys].[master_files] A WITH(NOLOCK)	
		JOIN ##MDFs_Sizes B ON DB_NAME(A.[database_id]) = B.[Nm_Database] and A.[name] = B.[Logical_Name]
	WHERE	A.[type_desc] <> 'FULLTEXT'
			and A.type = 1	-- Arquivos de Log (LDF)
	
	IF ( @@ROWCOUNT = 0 )
	BEGIN
		INSERT INTO [dbo].[CheckList_Arquivos_Log] (	[Server], [Nm_Database], [Logical_Name], [FileName], [Total_Reservado], [Total_Utilizado], 
														[Espaco_Livre (MB)], [Espaco_Livre (%)], [MaxSize], [Growth], [NextSize], [Fl_Situacao] )
		SELECT	NULL, 'Sem registro dos Arquivos de Log (LDF)', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Database_Growth]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Database_Growth]
GO

/*******************************************************************************************************************************
--	Crescimento Database
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Database_Growth]
AS
BEGIN
	SET NOCOUNT ON

	-- Declara e seta AS variaveis das datas - Tratamento para os casos que ainda não atingiram 60 dias no histórico
	DECLARE @Dt_Hoje DATE, @Dt_1Dia DATE, @Dt_15Dias DATE, @Dt_30Dias DATE, @Dt_60Dias DATE
	
	SELECT	@Dt_Hoje = CAST(GETDATE() AS DATE)
	
	SELECT	@Dt_1Dia =	 MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 1  THEN A.[Dt_Referencia] END)),
			@Dt_15Dias = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 15 THEN A.[Dt_Referencia] END)),
			@Dt_30Dias = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 30 THEN A.[Dt_Referencia] END)),
			@Dt_60Dias = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 60 THEN A.[Dt_Referencia] END))
	FROM [dbo].[Historico_Tamanho_Tabela] A
		JOIN [dbo].[Servidor] B ON A.[Id_Servidor] = B.[Id_Servidor] 
		JOIN [dbo].[Tabela] C ON A.[Id_Tabela] = C.[Id_Tabela]
		JOIN [dbo].[BaseDados] D ON A.[Id_BaseDados] = D.[Id_BaseDados]
	WHERE 	DATEDIFF(DAY,A.[Dt_Referencia], CAST(GETDATE() AS DATE)) <= 60
		AND B.Nm_Servidor = @@SERVERNAME
	
	/*
	-- P/ TESTE
	SELECT @Dt_Hoje Dt_Hoje, @Dt_1Dia Dt_1Dia, @Dt_15Dias Dt_15Dias, @Dt_30Dias Dt_30Dias, @Dt_60Dias Dt_60Dias
	
	SELECT	CONVERT(VARCHAR, GETDATE() ,112) Hoje, CONVERT(VARCHAR, GETDATE()-1 ,112) [1Dia], CONVERT(VARCHAR, GETDATE()-15 ,112) [15Dias],
			CONVERT(VARCHAR, GETDATE()-30 ,112) [30Dias], CONVERT(VARCHAR, GETDATE()-60 ,112) [60Dias]
	*/

	-- Tamanho atual das DATABASES de todos os servidores e crescimento em 1, 15, 30 e 60 dias.
	IF (OBJECT_ID('tempdb..#CheckList_Database_Growth') IS NOT NULL)
		DROP TABLE #CheckList_Database_Growth
	
	CREATE TABLE #CheckList_Database_Growth (
		[Nm_Servidor]	VARCHAR(50) NOT NULL,
		[Nm_Database]	VARCHAR(100) NULL,
		[Tamanho_Atual] NUMERIC(38, 2) NULL,
		[Cresc_1_dia]	NUMERIC(38, 2) NULL,
		[Cresc_15_dia]	NUMERIC(38, 2) NULL,
		[Cresc_30_dia]	NUMERIC(38, 2) NULL,
		[Cresc_60_dia]	NUMERIC(38, 2) NULL
	)
		
	INSERT INTO #CheckList_Database_Growth
	SELECT	B.[Nm_Servidor], [Nm_Database], 
			SUM(CASE WHEN [Dt_Referencia] = @Dt_Hoje   THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Tamanho_Atual],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_1Dia   THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_1_dia],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_15Dias THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_15_dia],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_30Dias THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_30_dia],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_60Dias THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_60_dia]          
	FROM [dbo].[Historico_Tamanho_Tabela] A
		JOIN [dbo].[Servidor] B ON A.[Id_Servidor] = B.[Id_Servidor] 
		JOIN [dbo].[Tabela] C ON A.[Id_Tabela] = C.[Id_Tabela]
		JOIN [dbo].[BaseDados] D ON A.[Id_BaseDados] = D.[Id_BaseDados]
	WHERE	A.[Dt_Referencia] IN ( @Dt_Hoje, @Dt_1Dia, @Dt_15Dias, @Dt_30Dias, @Dt_60Dias ) -- Hoje, 1 dia, 15 dias, 30 dias, 60 dias
		AND B.Nm_Servidor = @@SERVERNAME
	GROUP BY B.[Nm_Servidor], [Nm_Database]
			
	TRUNCATE TABLE [dbo].[CheckList_Database_Growth]
	TRUNCATE TABLE [dbo].[CheckList_Database_Growth_Email]
		
	INSERT INTO [dbo].[CheckList_Database_Growth] ( [Nm_Servidor], [Nm_Database], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
	SELECT	[Nm_Servidor], [Nm_Database], [Tamanho_Atual], 
			[Tamanho_Atual] - [Cresc_1_dia] AS [Cresc_1_dia],
			[Tamanho_Atual] - [Cresc_15_dia] AS [Cresc_15_dia],
			[Tamanho_Atual] - [Cresc_30_dia] AS [Cresc_30_dia],
			[Tamanho_Atual] - [Cresc_60_dia] AS [Cresc_60_dia]
	FROM #CheckList_Database_Growth

	IF (@@ROWCOUNT <> 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Database_Growth_Email] ( [Nm_Servidor], [Nm_Database], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
		SELECT	TOP 10
				[Nm_Servidor], [Nm_Database], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia]
		FROM [dbo].[CheckList_Database_Growth]
		ORDER BY ABS([Cresc_1_dia]) DESC, ABS([Cresc_15_dia]) DESC, ABS([Cresc_30_dia]) DESC, ABS([Cresc_60_dia]) DESC, [Tamanho_Atual] DESC
	
		INSERT INTO [dbo].[CheckList_Database_Growth_Email] ( [Nm_Servidor], [Nm_Database], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
		SELECT NULL, 'TOTAL GERAL', SUM([Tamanho_Atual]), SUM([Cresc_1_dia]), SUM([Cresc_15_dia]), SUM([Cresc_30_dia]), SUM([Cresc_60_dia])
		FROM [dbo].[CheckList_Database_Growth]
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[CheckList_Database_Growth_Email] ( [Nm_Servidor], [Nm_Database], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
		SELECT NULL, 'Sem registro de Crescimento de mais de 1 MB das Bases', NULL, NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Table_Growth]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Table_Growth]	
GO

/*******************************************************************************************************************************
--	Crescimento Tabela
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Table_Growth]
AS
BEGIN
	SET NOCOUNT ON

	-- Declara e seta AS variaveis das datas - Tratamento para os casos que ainda não atingiram 60 dias no histórico
	DECLARE @Dt_Hoje DATE, @Dt_1Dia DATE, @Dt_15Dias DATE, @Dt_30Dias DATE, @Dt_60Dias DATE
	
	SELECT	@Dt_Hoje = CAST(GETDATE() AS DATE)
	
	SELECT	@Dt_1Dia   = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 1  THEN A.[Dt_Referencia] END)),
			@Dt_15Dias = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 15 THEN A.[Dt_Referencia] END)),
			@Dt_30Dias = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 30 THEN A.[Dt_Referencia] END)),
			@Dt_60Dias = MIN((CASE WHEN DATEDIFF(DAY,A.[Dt_Referencia], @Dt_Hoje) <= 60 THEN A.[Dt_Referencia] END))
	FROM [dbo].[Historico_Tamanho_Tabela] A
		JOIN [dbo].[Servidor] B ON A.[Id_Servidor] = B.[Id_Servidor] 
		JOIN [dbo].[Tabela] C ON A.[Id_Tabela] = C.[Id_Tabela]
		JOIN [dbo].[BaseDados] D ON A.[Id_BaseDados] = D.[Id_BaseDados]
	WHERE 	DATEDIFF(DAY,A.[Dt_Referencia], CAST(GETDATE() AS DATE)) <= 60
		AND B.Nm_Servidor = @@SERVERNAME
	
	/*
	-- P/ TESTE
	SELECT @Dt_Hoje Dt_Hoje, @Dt_1Dia Dt_1Dia, @Dt_15Dias Dt_15Dias, @Dt_30Dias Dt_30Dias, @Dt_60Dias Dt_60Dias
	
	SELECT	CONVERT(VARCHAR, GETDATE() ,112) Hoje, CONVERT(VARCHAR, GETDATE()-1 ,112) [1Dia], CONVERT(VARCHAR, GETDATE()-15 ,112) [15Dias],
			CONVERT(VARCHAR, GETDATE()-30 ,112) [30Dias], CONVERT(VARCHAR, GETDATE()-60 ,112) [60Dias]
	*/

	-- Tamanho atual das DATABASES de todos os servidores e crescimento em 1, 15, 30 e 60 dias.
	IF (OBJECT_ID('tempdb..#CheckList_Table_Growth') IS NOT NULL)
		DROP TABLE #CheckList_Table_Growth
	
	CREATE TABLE #CheckList_Table_Growth (
		[Nm_Servidor]	VARCHAR(50) NOT NULL,
		[Nm_Database]	VARCHAR(100) NULL,
		[Nm_Tabela]		VARCHAR(100) NULL,
		[Tamanho_Atual] NUMERIC(38, 2) NULL,
		[Cresc_1_dia]	NUMERIC(38, 2) NULL,
		[Cresc_15_dia]	NUMERIC(38, 2) NULL,
		[Cresc_30_dia]	NUMERIC(38, 2) NULL,
		[Cresc_60_dia]	NUMERIC(38, 2) NULL		
	)
		
	INSERT INTO #CheckList_Table_Growth
	SELECT	B.[Nm_Servidor], [Nm_Database], [Nm_Tabela], 
			SUM(CASE WHEN [Dt_Referencia] = @Dt_Hoje   THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Tamanho_Atual],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_1Dia   THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_1_dia],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_15Dias THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_15_dia],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_30Dias THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_30_dia],
			SUM(CASE WHEN [Dt_Referencia] = @Dt_60Dias THEN A.[Nr_Tamanho_Total] ELSE 0 END) AS [Cresc_60_dia]           
	FROM [dbo].[Historico_Tamanho_Tabela] A
		JOIN [dbo].[Servidor] B ON A.[Id_Servidor] = B.[Id_Servidor] 
		JOIN [dbo].[Tabela] C ON A.[Id_Tabela] = C.[Id_Tabela]
		JOIN [dbo].[BaseDados] D ON A.[Id_BaseDados] = D.[Id_BaseDados]
	WHERE 	A.[Dt_Referencia] IN( @Dt_Hoje, @Dt_1Dia, @Dt_15Dias, @Dt_30Dias, @Dt_60Dias) -- Hoje, 1 dia, 15 dias, 30 dias, 60 dias
		AND B.Nm_Servidor = @@SERVERNAME
	GROUP BY B.[Nm_Servidor], [Nm_Database], [Nm_Tabela]
			
	TRUNCATE TABLE [dbo].[CheckList_Table_Growth]
	TRUNCATE TABLE [dbo].[CheckList_Table_Growth_Email]
			
	INSERT INTO [dbo].[CheckList_Table_Growth] ( [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
	SELECT	[Nm_Servidor], [Nm_Database], [Nm_Tabela], [Tamanho_Atual], 
			[Tamanho_Atual] - [Cresc_1_dia] AS [Cresc_1_dia],
			[Tamanho_Atual] - [Cresc_15_dia] AS [Cresc_15_dia],
			[Tamanho_Atual] - [Cresc_30_dia] AS [Cresc_30_dia],
			[Tamanho_Atual] - [Cresc_60_dia] AS [Cresc_60_dia]
	FROM #CheckList_Table_Growth
	
	IF (@@ROWCOUNT <> 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Table_Growth_Email] ( [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
		SELECT	TOP 10
				[Nm_Servidor], [Nm_Database], [Nm_Tabela], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia]
		FROM [dbo].[CheckList_Table_Growth]
		ORDER BY ABS([Cresc_1_dia]) DESC, ABS([Cresc_15_dia]) DESC, ABS([Cresc_30_dia]) DESC, ABS([Cresc_60_dia]) DESC, [Tamanho_Atual] DESC
	
		INSERT INTO [dbo].[CheckList_Table_Growth_Email] ( [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
		SELECT NULL, 'TOTAL GERAL', NULL, SUM([Tamanho_Atual]), SUM([Cresc_1_dia]), SUM([Cresc_15_dia]), SUM([Cresc_30_dia]), SUM([Cresc_60_dia])
		FROM [dbo].[CheckList_Table_Growth]
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[CheckList_Table_Growth_Email] ( [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Tamanho_Atual], [Cresc_1_dia], [Cresc_15_dia], [Cresc_30_dia], [Cresc_60_dia] )
		SELECT NULL, 'Sem registro de Crescimento de mais de 1 MB das Tabelas', NULL, NULL, NULL, NULL, NULL, NULL
	END
END


GO
IF (OBJECT_ID('[dbo].[stpCheckList_Utilizacao_Arquivo]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Utilizacao_Arquivo]	
GO	

/*******************************************************************************************************************************
--	Utilização Arquivo
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpCheckList_Utilizacao_Arquivo]
AS
BEGIN
	DECLARE @Dt_Referencia DATETIME = CAST(GETDATE()-1 AS DATE)

	-- WRITES
	if (OBJECT_ID('tempdb..#arquivos_writes') is not null)
		drop table #arquivos_writes

	select  TOP 10
			A.Nm_Database, A.file_id
			, B.io_stall_write_ms - A.io_stall_write_ms AS io_stall_write_ms		
			, B.num_of_writes - A.num_of_writes AS num_of_writes
			, CASE WHEN (1.0 + B.num_of_writes - A.num_of_writes) <> 0 THEN
					CAST(((B.io_stall_write_ms - A.io_stall_write_ms)/(1.0+ B.num_of_writes - A.num_of_writes)) AS NUMERIC(15,1)) 
				ELSE
					0
			  END AS [avg_write_stall_ms]
	into #arquivos_writes		  
	from [dbo].Historico_Utilizacao_Arquivo A
	JOIN [dbo].Historico_Utilizacao_Arquivo B on	A.Nm_Database = B.Nm_Database and A.file_id = B.file_id
													and B.Dt_Registro >= @Dt_Referencia and B.Dt_Registro < @Dt_Referencia + 1
													and DATEPART(HH,B.Dt_Registro) = 18 and DATEPART(MINUTE,B.Dt_Registro) BETWEEN 0 AND 5	-- 18 HORAS
	where	A.Dt_Registro >= @Dt_Referencia and A.Dt_Registro < @Dt_Referencia + 1
			and DATEPART(HH,A.Dt_Registro) = 9 and DATEPART(MINUTE,A.Dt_Registro) BETWEEN 0 AND 5											-- 9 HORAS	
	order by num_of_writes  DESC 
	
	-- READS
	if (OBJECT_ID('tempdb..#arquivos_reads') is not null)
		drop table #arquivos_reads

	select  TOP 10
			A.Nm_Database, A.file_id
			, B.io_stall_read_ms - A.io_stall_read_ms AS io_stall_read_ms
			, B.num_of_reads - A.num_of_reads AS num_of_reads		
			, CASE WHEN (1.0 + B.num_of_reads - A.num_of_reads) <> 0 THEN
					CAST(((B.io_stall_read_ms - A.io_stall_read_ms)/(1.0 + B.num_of_reads - A.num_of_reads)) AS NUMERIC(15,1))
				ELSE 
					0
			  END AS [avg_read_stall_ms]
	into #arquivos_reads		  
	from [dbo].Historico_Utilizacao_Arquivo A
	JOIN [dbo].Historico_Utilizacao_Arquivo B on	A.Nm_Database = B.Nm_Database and A.file_id = B.file_id
													and B.Dt_Registro >= @Dt_Referencia and B.Dt_Registro < @Dt_Referencia + 1
													and DATEPART(HH,B.Dt_Registro) = 18 and DATEPART(MINUTE,B.Dt_Registro) BETWEEN 0 AND 5	-- 18 HORAS
	where	A.Dt_Registro >= @Dt_Referencia and A.Dt_Registro < @Dt_Referencia + 1
			and DATEPART(HH,A.Dt_Registro) = 9 and DATEPART(MINUTE,A.Dt_Registro) BETWEEN 0 AND 5											-- 9 HORAS	
	order by num_of_reads  DESC 

	-- WRITES
	TRUNCATE TABLE [dbo].[CheckList_Utilizacao_Arquivo_Writes]
	
	INSERT INTO [dbo].[CheckList_Utilizacao_Arquivo_Writes]
	SELECT *
	FROM #arquivos_writes

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Utilizacao_Arquivo_Writes]
		SELECT 'Sem registro de Utilização dos Arquivos - Writes', NULL, NULL, NULL, NULL
	END
	
	-- READS
	TRUNCATE TABLE [dbo].[CheckList_Utilizacao_Arquivo_Reads]
	
	INSERT INTO [dbo].[CheckList_Utilizacao_Arquivo_Reads]
	SELECT *
	FROM #arquivos_reads
	
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Utilizacao_Arquivo_Reads]
		SELECT 'Sem registro de Utilização dos Arquivos - Reads', NULL, NULL, NULL, NULL
	END
END


GO
IF (OBJECT_ID('[dbo].[stpCheckList_Databases_Sem_Backup]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Databases_Sem_Backup]	
GO	
	
/*******************************************************************************************************************************
--	Databases Sem Backup
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpCheckList_Databases_Sem_Backup]
AS
BEGIN
	DECLARE @Dt_Referencia DATETIME
	SELECT @Dt_Referencia = GETDATE()
	
	-- Verifica as databases sem backup nas últimas 16 horas
	IF ( OBJECT_ID('tempdb..#checklist_databases_sem_backup') IS NOT NULL)
	DROP TABLE #checklist_databases_sem_backup

	SELECT A.name AS Nm_Database
	INTO #checklist_databases_sem_backup
	FROM [sys].[databases] A
	LEFT JOIN [msdb].[dbo].[backupset] B ON B.[database_name] = A.name AND [type] IN ('D','I')
											and [backup_start_date] >= DATEADD(hh, -16, @Dt_Referencia)
	WHERE	B.[database_name] IS NULL AND A.[name] NOT IN ('tempdb','ReportServerTempDB') AND state_desc <> 'OFFLINE'
	
	TRUNCATE TABLE [dbo].[CheckList_Databases_Sem_Backup]
	
	INSERT INTO [dbo].[CheckList_Databases_Sem_Backup] (Nm_Database)
	select Nm_Database 
	from #checklist_databases_sem_backup
			  
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Databases_Sem_Backup] ( Nm_Database )
		SELECT 'Sem registro de Databases Sem Backup nas últimas 16 horas.'
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Backups_Executados]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Backups_Executados]	
GO	
	
/*******************************************************************************************************************************
--	5) Backups Executados
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Backups_Executados]
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Dt_Referencia DATETIME
	SELECT @Dt_Referencia = GETDATE()

	TRUNCATE TABLE [dbo].[CheckList_Backups_Executados]
	
	INSERT INTO [dbo].[CheckList_Backups_Executados] (	[Database_Name], [Name], [Backup_Start_Date], [Tempo_Min], [Position], [Server_Name],
														[Recovery_Model], [Logical_Device_Name], [Device_Type], [Type], [Tamanho_MB] )
	SELECT	[database_name], [name], [backup_start_date], DATEdiff(mi, [backup_start_date], [backup_finish_date]) AS [Tempo_Min], 
			[position], [server_name], [recovery_model], isnull([logical_device_name], ' ') AS [logical_device_name],
			[device_type], [type], CAST([backup_size]/1024/1024 AS NUMERIC(15,2)) AS [Tamanho (MB)]
	FROM [msdb].[dbo].[backupset] B
		JOIN [msdb].[dbo].[backupmediafamily] BF ON B.[media_set_id] = BF.[media_set_id]
	WHERE [backup_start_date] >= DATEADD(hh, -24 ,@Dt_Referencia) AND [type] in ('D','I')
		  
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Backups_Executados] (	[Database_Name], [Name], [Backup_Start_Date], [Tempo_Min], [Position], [Server_Name],
															[Recovery_Model], [Logical_Device_Name], [Device_Type], [Type], [Tamanho_MB] )
		SELECT 'Sem registro de Backup FULL ou Diferencial nas últimas 24 horas.', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END
END
GO

IF (OBJECT_ID('[dbo].[stpCheckList_Queries_Running]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Queries_Running]
GO

/*******************************************************************************************************************************
--	Queries em Execução
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Queries_Running]
AS
BEGIN
	SET NOCOUNT ON 

	IF ( OBJECT_ID('tempdb..#Resultado_WhoisActive') IS NOT NULL )
		DROP TABLE #Resultado_WhoisActive
				
	CREATE TABLE #Resultado_WhoisActive (		
		[dd hh:mm:ss.mss]		VARCHAR(20),
		[database_name]			NVARCHAR(128),		
		[login_name]			NVARCHAR(128),
		[host_name]				NVARCHAR(128),
		[start_time]			DATETIME,
		[status]				VARCHAR(30),
		[session_id]			INT,
		[blocking_session_id]	INT,
		[wait_info]				VARCHAR(MAX),
		[open_tran_count]		INT,
		[CPU]					VARCHAR(MAX),
		[reads]					VARCHAR(MAX),
		[writes]				VARCHAR(MAX),
		[sql_command]			XML
	)
	
	-- Retorna todos os processos que estão sendo executados no momento
	EXEC [dbo].[sp_whoisactive]
			@get_outer_command =	1,
			@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
			@destination_table =	'#Resultado_WhoisActive'

	ALTER TABLE #Resultado_WhoisActive
	ALTER COLUMN [sql_command] VARCHAR(MAX)
	
	UPDATE #Resultado_WhoisActive
	SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')

	-- Exclui os registros das queries com menos de 2 horas de execução
	DELETE #Resultado_WhoisActive	
	where DATEDIFF(MINUTE, start_time, GETDATE()) < 120
	
	TRUNCATE TABLE [dbo].[CheckList_Queries_Running]

	INSERT INTO [dbo].[CheckList_Queries_Running]
	SELECT * FROM #Resultado_WhoisActive

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Queries_Running]( [dd hh:mm:ss.mss], database_name, login_name, host_name, start_time, status, session_id, blocking_session_id, wait_info, open_tran_count, CPU, reads, writes, sql_command )
		SELECT NULL, 'Sem registro de Queries executando a mais de 2 horas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Alteracao_Jobs]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Alteracao_Jobs]
GO

/*******************************************************************************************************************************
--	JOBS Alterados
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Alteracao_Jobs]
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @hoje VARCHAR(8), @ontem VARCHAR(8)	
	SELECT	@ontem  = CONVERT(VARCHAR(8),(DATEADD (DAY, -1, GETDATE())), 112),
			@hoje = CONVERT(VARCHAR(8), GETDATE()+1, 112)

	TRUNCATE TABLE [dbo].[CheckList_Alteracao_Jobs]

	INSERT INTO [dbo].[CheckList_Alteracao_Jobs] ( [Nm_Job], [Fl_Habilitado], [Dt_Criacao], [Dt_Modificacao], [Nr_Versao] )
	SELECT	[name] AS [Nm_Job], CONVERT(SMALLINT, [enabled]) AS [Fl_Habilitado], CONVERT(SMALLDATETIME, [date_created]) AS [Dt_Criacao], 
			CONVERT(SMALLDATETIME, [date_modified]) AS [Dt_Modificacao], [version_number] AS [Nr_Versao]
	FROM [msdb].[dbo].[sysjobs]  sj     
	WHERE	( [date_created] >= @ontem AND [date_created] < @hoje) OR ([date_modified] >= @ontem AND [date_modified] < @hoje)	
	 
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Alteracao_Jobs] ( [Nm_Job], [Fl_Habilitado], [Dt_Criacao], [Dt_Modificacao], [Nr_Versao] )
		SELECT 'Sem registro de JOB Alterado', NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Jobs_Failed]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Jobs_Failed]
GO

/*******************************************************************************************************************************
--	JOBS que Falharam
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Jobs_Failed]
AS
BEGIN
	SET NOCOUNT ON
	
	IF (OBJECT_ID('tempdb..#Result_History_Jobs') IS NOT NULL)
		DROP TABLE #Result_History_Jobs

	CREATE TABLE #Result_History_Jobs (
		[Cod] INT IDENTITY(1,1),
		[Instance_Id] INT,
		[Job_Id] VARCHAR(255),
		[Job_Name] VARCHAR(255),
		[Step_Id] INT,
		[Step_Name] VARCHAR(255),
		[SQl_Message_Id] INT,
		[Sql_Severity] INT,
		[SQl_Message] VARCHAR(4490),
		[Run_Status] INT,
		[Run_Date] VARCHAR(20),
		[Run_Time] VARCHAR(20),
		[Run_Duration] INT,
		[Operator_Emailed] VARCHAR(100),
		[Operator_NetSent] VARCHAR(100),
		[Operator_Paged] VARCHAR(100),
		[Retries_Attempted] INT,
		[Nm_Server] VARCHAR(100)  
	)

	DECLARE @hoje VARCHAR(8), @ontem VARCHAR(8)	
	SELECT	@ontem = CONVERT(VARCHAR(8),(DATEADD (DAY, -1, GETDATE())), 112), 
			@hoje = CONVERT(VARCHAR(8), GETDATE() + 1, 112)

	INSERT INTO #Result_History_Jobs
	EXEC [msdb].[dbo].[sp_help_jobhistory] @mode = 'FULL', @start_run_date = @ontem

	TRUNCATE TABLE [dbo].[CheckList_Jobs_Failed]
	
	INSERT INTO [dbo].[CheckList_Jobs_Failed] ( [Server], [Job_Name], [Status], [Dt_Execucao], [Run_Duration], [SQL_Message] )
	SELECT	Nm_Server AS [Server], [Job_Name], 
			CASE	WHEN [Run_Status] = 0 THEN 'Failed'
					WHEN [Run_Status] = 1 THEN 'Succeeded'
					WHEN [Run_Status] = 2 THEN 'Retry (step only)'
					WHEN [Run_Status] = 3 THEN 'Cancelled'
					WHEN [Run_Status] = 4 THEN 'In-progress message'
					WHEN [Run_Status] = 5 THEN 'Unknown' 
			END [Status],
			CAST(	[Run_Date] + ' ' +
					RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-3), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-1), 2), 2) AS VARCHAR) AS [Dt_Execucao],
			RIGHT('00' + SUBSTRING(CAST([Run_Duration] AS VARCHAR),(LEN([Run_Duration])-5),2), 2) + ':' +
			RIGHT('00' + SUBSTRING(CAST([Run_Duration] AS VARCHAR),(LEN([Run_Duration])-3),2), 2) + ':' +
			RIGHT('00' + SUBSTRING(CAST([Run_Duration] AS VARCHAR),(LEN([Run_Duration])-1),2), 2) AS [Run_Duration],
			CAST([SQl_Message] AS VARCHAR(3990)) AS [SQl_Message]
	FROM #Result_History_Jobs 
	WHERE 
		  CAST([Run_Date] + ' ' + RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
			  RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-3), 2), 2) + ':' +
			  RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-1), 2), 2) AS DATETIME) >= @ontem + ' 08:00' 
		  AND  /*dia anterior no horário*/
			CAST([Run_Date] + ' ' + RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
			  RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-3), 2), 2) + ':' +
			  RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-1), 2), 2) AS DATETIME) < @hoje
		  --AND [Step_Id] = 0 tratamento para o Retry do Job
		  AND [Run_Status] <> 1
	 
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Jobs_Failed] ( [Server], [Job_Name], [Status], [Dt_Execucao], [Run_Duration], [SQL_Message] )
		SELECT NULL, 'Sem registro de Falha de JOB', NULL, NULL, NULL, NULL		
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Job_Demorados]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Job_Demorados]	
GO	

/*******************************************************************************************************************************
--	JOBS Demorados
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Job_Demorados]
AS
BEGIN
	SET NOCOUNT ON

	IF (OBJECT_ID('tempdb..#Result_History_Jobs') IS NOT NULL)
		DROP TABLE #Result_History_Jobs
		
	CREATE TABLE #Result_History_Jobs (
		[Cod]				INT	IDENTITY(1,1),
		[Instance_Id]		INT,
		[Job_Id]			VARCHAR(255),
		[Job_Name]			VARCHAR(255),
		[Step_Id]			INT,
		[Step_Name]			VARCHAR(255),
		[Sql_Message_Id]	INT,
		[Sql_Severity]		INT,
		[SQl_Message]		VARCHAR(4490),
		[Run_Status]		INT,
		[Run_Date]			VARCHAR(20),
		[Run_Time]			VARCHAR(20),
		[Run_Duration]		INT,
		[Operator_Emailed]	VARCHAR(100),
		[Operator_NetSent]	VARCHAR(100),
		[Operator_Paged]	VARCHAR(100),
		[Retries_Attempted] INT,
		[Nm_Server]			VARCHAR(100)  
	)
	
	DECLARE @ontem VARCHAR(8)
	SET @ontem  =  CONVERT(VARCHAR(8), (DATEADD(DAY, -1, GETDATE())), 112)

	INSERT INTO #Result_History_Jobs
	EXEC [msdb].[dbo].[sp_help_jobhistory] @mode = 'FULL', @start_run_date = @ontem

	TRUNCATE TABLE [dbo].[CheckList_Job_Demorados]
	
	INSERT INTO [dbo].[CheckList_Job_Demorados] ( [Job_Name], [Status], [Dt_Execucao], [Run_Duration], [SQL_Message] )
	SELECT	[Job_Name], 
			CASE	WHEN [Run_Status] = 0 THEN 'Failed'
					WHEN [Run_Status] = 1 THEN 'Succeeded'
					WHEN [Run_Status] = 2 THEN 'Retry (step only)'
					WHEN [Run_Status] = 3 THEN 'Canceled'
					WHEN [Run_Status] = 4 THEN 'In-progress message'
					WHEN [Run_Status] = 5 THEN 'Unknown' 
			END [Status],
			CAST([Run_Date] + ' ' +
				RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
				RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-3), 2), 2) + ':' +
				RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-1), 2), 2) AS VARCHAR) AS [Dt_Execucao],
			RIGHT('00' + SUBSTRING(CAST(Run_Duration AS VARCHAR),(LEN(Run_Duration)-5), 2), 2)+ ':' +
				RIGHT('00' + SUBSTRING(CAST(Run_Duration AS VARCHAR),(LEN(Run_Duration)-3), 2) ,2) + ':' +
				RIGHT('00' + SUBSTRING(CAST(Run_Duration AS VARCHAR),(LEN(Run_Duration)-1), 2) ,2) AS [Run_Duration],
			CAST([SQl_Message] AS VARCHAR(3990)) AS [SQL_Message]	
	FROM #Result_History_Jobs
	WHERE 
		  CAST([Run_Date] + ' ' + RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
		  RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-3), 2), 2) + ':' +
		  RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-1), 2), 2) AS DATETIME) >= GETDATE() -1 and
		  CAST([Run_Date] + ' ' + RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2)+ ':' +
		  RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-3), 2), 2) + ':' +
		  RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-1), 2), 2) AS DATETIME) < GETDATE() 
		  AND [Step_Id] = 0
		  AND [Run_Status] = 1
		  AND [Run_Duration] >= 100  -- JOBS que demoraram mais de 1 minuto

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Job_Demorados] ( [Job_Name], [Status], [Dt_Execucao], [Run_Duration], [SQL_Message] )
		SELECT 'Sem registro de JOBs Demorados', NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Jobs_Running]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Jobs_Running]	
GO	

/*******************************************************************************************************************************
--	JOBS EM EXECUÇÃO
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpCheckList_Jobs_Running]
AS
BEGIN
	SET NOCOUNT ON

	TRUNCATE TABLE [dbo].[CheckList_Jobs_Running]

	INSERT INTO [dbo].[CheckList_Jobs_Running] (Nm_JOB, Dt_Inicio, Qt_Duracao, Nm_Step)
	SELECT
		j.name AS Nm_JOB,
		CONVERT(VARCHAR(16), start_execution_date,120) AS Dt_Inicio,
		RTRIM(CONVERT(CHAR(17), DATEDIFF(SECOND, CONVERT(DATETIME, start_execution_date), GETDATE()) / 86400)) + ' Dia(s) ' +
		RIGHT('00' + RTRIM(CONVERT(CHAR(7), DATEDIFF(SECOND, CONVERT(DATETIME, start_execution_date), GETDATE()) % 86400 / 3600)), 2) + ' Hora(s) ' +
		RIGHT('00' + RTRIM(CONVERT(CHAR(7), DATEDIFF(SECOND, CONVERT(DATETIME, start_execution_date), GETDATE()) % 86400 % 3600 / 60)), 2) + ' Minuto(s) ' AS Qt_Duracao,
		js.step_name AS Nm_Step
	FROM msdb.dbo.sysjobactivity ja 
	LEFT JOIN msdb.dbo.sysjobhistory jh 
		ON ja.job_history_id = jh.instance_id
	JOIN msdb.dbo.sysjobs j 
	ON ja.job_id = j.job_id
	JOIN msdb.dbo.sysjobsteps js
		ON ja.job_id = js.job_id
		AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
	WHERE	ja.session_id = (SELECT TOP 1 session_id FROM msdb.dbo.syssessions ORDER BY agent_start_date DESC)
			AND start_execution_date is not null
			AND stop_execution_date is null
			AND DATEDIFF(minute,start_execution_date, GETDATE()) >= 10		-- No minimo 10 minutos em execução

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Jobs_Running] (Nm_JOB, Dt_Inicio, Qt_Duracao, Nm_Step)
		SELECT 'Sem JOBs em execução a mais de 10 minutos', NULL, NULL, NULL
	END	
END

GO	
IF (OBJECT_ID('[dbo].[stpCheckList_Conexao_Aberta]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Conexao_Aberta]	
GO	

/*******************************************************************************************************************************
--	Conexoes Abertas
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpCheckList_Conexao_Aberta]
AS
BEGIN
	SET NOCOUNT ON

	TRUNCATE TABLE [dbo].[CheckList_Conexao_Aberta]
	TRUNCATE TABLE [dbo].[CheckList_Conexao_Aberta_Email]

	INSERT INTO [dbo].[CheckList_Conexao_Aberta] ([login_name], [session_count])
	SELECT login_name, COUNT(login_name) AS [session_count] 
	FROM sys.dm_exec_sessions 
	WHERE session_id > 50
	GROUP BY login_name
	ORDER BY COUNT(login_name) DESC, login_name
	
	IF (@@ROWCOUNT <> 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Conexao_Aberta_Email] ([Nr_Ordem], [login_name], [session_count])
		SELECT TOP 10 1, [login_name], [session_count]
		FROM [dbo].[CheckList_Conexao_Aberta]
		ORDER BY [session_count] DESC, [login_name]

		INSERT INTO [dbo].[CheckList_Conexao_Aberta_Email] ([Nr_Ordem], [login_name], [session_count])
		SELECT 2, 'TOTAL', SUM([session_count])
		FROM [dbo].[CheckList_Conexao_Aberta]		
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[CheckList_Conexao_Aberta_Email] ([Nr_Ordem], [login_name], [session_count])
		SELECT NULL, 'Sem conexões de usuários abertas', NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Traces_Queries]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Traces_Queries]	
GO

/*******************************************************************************************************************************
--	Trace Queries Demoradas
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Traces_Queries]
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Dt_Referencia DATETIME
	SET @Dt_Referencia = CAST(GETDATE() AS DATE)
	
	-- Busca as queries lentas
	IF (OBJECT_ID('tempdb..#Queries_Demoradas') IS NOT NULL) 
		DROP TABLE #Queries_Demoradas

	SELECT	[TextData], [NTUserName], [HostName], [ApplicationName], [LoginName], [SPID], [Duration], [StartTime], 
			[EndTime], [ServerName], cast([Reads] AS BIGINT) AS [Reads], [Writes], [CPU], [DataBaseName], [RowCounts], [SessionLoginName]
	INTO #Queries_Demoradas
	FROM [dbo].[Traces] (nolock)
	WHERE	[StartTime] >= DATEADD(DAY, -10, @Dt_Referencia)
			AND [StartTime] < @Dt_Referencia
			AND DATEPART(HOUR, [StartTime]) BETWEEN 7 AND 22	
	
	----------------------------------------------------------------------------------------------------------------------------
	-- DIA ANTERIOR
	----------------------------------------------------------------------------------------------------------------------------
	IF (OBJECT_ID('tempdb..#TOP10_Dia_Anterior') IS NOT NULL) 
		DROP TABLE #TOP10_Dia_Anterior

	SELECT	TOP 10 LTRIM(CAST([TextData] AS CHAR(150))) AS [PrefixoQuery], COUNT(*) AS [QTD], SUM([Duration]) AS [Total], 
			AVG([Duration]) AS [Media], MIN([Duration]) AS [Menor], MAX([Duration]) AS [Maior],  
			SUM([Writes]) AS [Writes], SUM([CPU]) AS [CPU], SUM([Reads]) AS [Reads]
	INTO #TOP10_Dia_Anterior
	FROM #Queries_Demoradas
	WHERE	[StartTime] >= DATEADD(DAY, -1, @Dt_Referencia)
			AND [StartTime] < @Dt_Referencia
	GROUP BY LTRIM(CAST([TextData] AS CHAR(150)))
	ORDER BY COUNT(*) DESC
		
	TRUNCATE TABLE [dbo].[CheckList_Traces_Queries]
		
	INSERT INTO [dbo].[CheckList_Traces_Queries] ( [PrefixoQuery], [QTD], [Total], [Media], [Menor], [Maior], [Writes], [CPU], [Reads], [Ordem] )
	SELECT [PrefixoQuery], [QTD], [Total], [Media], [Menor], [Maior], [Writes], [CPU], [Reads], 1 AS [Ordem]
	FROM #TOP10_Dia_Anterior	
		
	IF (@@ROWCOUNT <> 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Traces_Queries] ( [PrefixoQuery], [QTD], [Total], [Media], [Menor], [Maior], [Writes], [CPU], [Reads], [Ordem] )
		SELECT	'OUTRAS' AS [PrefixoQuery], COUNT(*) AS [QTD], SUM([Duration]) AS [Total], 
				AVG([Duration]) AS [Media], MIN([Duration]) AS [Menor], MAX([Duration]) AS [Maior],  
				SUM([Writes]) AS [Writes], SUM([CPU]) AS [CPU], SUM([Reads]) AS [Reads], 2 AS [Ordem]
		FROM #Queries_Demoradas A
		WHERE	LTRIM(CAST([TextData] AS CHAR(150))) NOT IN (SELECT [PrefixoQuery] FROM #TOP10_Dia_Anterior)
				AND	[StartTime] >= DATEADD(DAY, -1, @Dt_Referencia)
				AND [StartTime] < @Dt_Referencia

		INSERT INTO [dbo].[CheckList_Traces_Queries] ( [PrefixoQuery], [QTD], [Total], [Media], [Menor], [Maior], [Writes], [CPU], [Reads], [Ordem] )
		SELECT	'TOTAL' AS [PrefixoQuery], SUM([QTD]), SUM([Total]), AVG([Media]), MIN([Menor]) AS [Menor], 
				MAX([Maior]) AS [Maior], SUM([Writes]) AS [Writes], SUM([CPU]) AS [CPU], SUM([Reads]) AS [Reads], 3 AS [Ordem]
		FROM [dbo].[CheckList_Traces_Queries]
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[CheckList_Traces_Queries] ( [PrefixoQuery], [QTD], [Total], [Media], [Menor], [Maior], [Writes], [CPU], [Reads], [Ordem] )	
		SELECT 'Sem registro de Queries Demoradas', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1		
	END

	----------------------------------------------------------------------------------------------------------------------------
	-- GERAL - 10 DIAS ATRAS
	----------------------------------------------------------------------------------------------------------------------------	
	IF (OBJECT_ID('tempdb..#TOP10_Geral') IS NOT NULL) 
		DROP TABLE #TOP10_Geral

	SELECT	TOP 10 CONVERT(VARCHAR(10), [StartTime], 120) AS Data, COUNT(*) AS [QTD]
	INTO #TOP10_Geral
	FROM #Queries_Demoradas
	GROUP BY CONVERT(VARCHAR(10), [StartTime], 120)
	
	TRUNCATE TABLE [dbo].[CheckList_Traces_Queries_Geral]
		
	INSERT INTO [dbo].[CheckList_Traces_Queries_Geral] ( [Data], [QTD] )
	SELECT [Data], [QTD]
	FROM #TOP10_Geral
		
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Traces_Queries_Geral] ( [Data], [QTD] )	
		SELECT 'Sem registro de Queries Demoradas', NULL		
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Contadores]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Contadores]
GO

/*******************************************************************************************************************************
--	Contadores
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Contadores]
AS
BEGIN
	SET NOCOUNT ON

	TRUNCATE TABLE [dbo].[CheckList_Contadores]
	TRUNCATE TABLE [dbo].[CheckList_Contadores_Email]

	DECLARE @Dt_Referencia DATETIME
	SET @Dt_Referencia = CAST(GETDATE()-1 AS DATE)
	
	INSERT INTO [dbo].[CheckList_Contadores]( [Hora], [Nm_Contador], [Media] )
	SELECT DATEPART(hh, [Dt_Log]) AS [Hora], [Nm_Contador], AVG([Valor]) AS [Media]
	FROM [dbo].[Registro_Contador] A
		JOIN [dbo].[Contador] B ON A.[Id_Contador] = B.[Id_Contador]
	WHERE [Dt_Log] >= DATEADD(hh, 7, @Dt_Referencia) AND [Dt_Log] < DATEADD(hh, 23, @Dt_Referencia)   
	GROUP BY DATEPART(hh, [Dt_Log]), [Nm_Contador]
	
	INSERT INTO [dbo].[CheckList_Contadores]( [Hora], [Nm_Contador], [Media] )	
	SELECT DATEPART(HH, [StartTime]), 'Qtd Queries Lentas', COUNT(*)
	FROM [dbo].[Traces]
	WHERE	[StartTime] >= @Dt_Referencia AND [StartTime] < @Dt_Referencia + 1
			AND DATEPART(HH, [StartTime]) >= 7 AND DATEPART(HH, [StartTime]) < 23
	GROUP BY DATEPART(HH, [StartTime])
	
	INSERT INTO [dbo].[CheckList_Contadores]( [Hora], [Nm_Contador], [Media] )	
	SELECT DATEPART(HH, [StartTime]), 'Reads Queries Lentas', SUM(CAST(Reads AS BIGINT))
	FROM [dbo].[Traces]
	WHERE	[StartTime] >= @Dt_Referencia AND [StartTime] < @Dt_Referencia + 1
			AND DATEPART(HH, [StartTime]) >= 7 AND DATEPART(HH, [StartTime]) < 23
	GROUP BY DATEPART(HH, [StartTime])
	
	IF NOT EXISTS (SELECT TOP 1 NULL FROM [dbo].[CheckList_Contadores])
	BEGIN
		INSERT INTO [dbo].[CheckList_Contadores]( [Hora], [Nm_Contador], [Media] )
		SELECT NULL, 'Sem registro de Contador', NULL
	END
		
	INSERT INTO [dbo].[CheckList_Contadores_Email]
	SELECT	ISNULL(CAST(U.[Hora]					AS VARCHAR), '-')	AS [Hora], 
			ISNULL(CAST(U.[BatchRequests]			AS VARCHAR), '-')	AS [BatchRequests],
			ISNULL(CAST(U.[CPU]						AS VARCHAR), '-')	AS [CPU],
			ISNULL(CAST(U.[Page Life Expectancy]	AS VARCHAR), '-')	AS [Page_Life_Expectancy], 
			ISNULL(CAST(U.[User_Connection]			AS VARCHAR), '-')	AS [User_Connection],
			ISNULL(CAST(U.[Qtd Queries Lentas]		AS VARCHAR), '-')	AS [Qtd_Queries_Lentas], 
			ISNULL(CAST(U.[Reads Queries Lentas]	AS VARCHAR), '-')	AS [Reads_Queries_Lentas]
	FROM [dbo].[CheckList_Contadores] AS C
	PIVOT	(
				SUM([Media]) 
				FOR [Nm_Contador] IN (	[BatchRequests], [CPU], [Page Life Expectancy], 
										[User_Connection], [Qtd Queries Lentas], [Reads Queries Lentas])
			) AS U
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Fragmentacao_Indices]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Fragmentacao_Indices]
GO

/*******************************************************************************************************************************
--	Fragmentação de Índices
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Fragmentacao_Indices]
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Max_Dt_Referencia DATETIME

	SELECT @Max_Dt_Referencia = MAX(Dt_Referencia) FROM [dbo].[vwHistorico_Fragmentacao_Indice]

	TRUNCATE TABLE [dbo].[CheckList_Fragmentacao_Indices]
	
	INSERT INTO [dbo].[CheckList_Fragmentacao_Indices] (	[Dt_Referencia], [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Nm_Indice], 
															[Avg_Fragmentation_In_Percent], [Page_Count], [Fill_Factor], [Fl_Compressao] )
	SELECT	[Dt_Referencia], [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Nm_Indice], 
			[Avg_Fragmentation_In_Percent], [Page_Count], [Fill_Factor], [Fl_Compressao]
	FROM [dbo].[vwHistorico_Fragmentacao_Indice]
	WHERE	CAST([Dt_Referencia] AS DATE) = CAST(@Max_Dt_Referencia AS DATE)
			AND [Avg_Fragmentation_In_Percent] > 10
			AND [Page_Count] > 1000
	
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Fragmentacao_Indices] (	[Dt_Referencia], [Nm_Servidor], [Nm_Database], [Nm_Tabela], [Nm_Indice], 
																[Avg_Fragmentation_In_Percent], [Page_Count], [Fill_Factor], [Fl_Compressao] )
		SELECT NULL, NULL, 'Sem registro de Índice com mais de 10% de Fragmentação', NULL, NULL, NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_Waits_Stats]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Waits_Stats]
GO

/*******************************************************************************************************************************
--	Waits Stats
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Waits_Stats]
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @Dt_Referencia DATETIME, @Dt_Inicio DATETIME, @Dt_Fim DATETIME
	SET @Dt_Referencia = CAST(GETDATE()-1 AS DATE)
	
	SELECT @Dt_Inicio = DATEADD(hh, 7, @Dt_Referencia), @Dt_Fim = DATEADD(hh, 23, @Dt_Referencia)   

	TRUNCATE TABLE [dbo].[CheckList_Waits_Stats]

	INSERT INTO [dbo].[CheckList_Waits_Stats](	[WaitType], [Min_Log], [Max_Log], [DIf_Wait_S], [DIf_Resource_S], [DIf_Signal_S], 
												[DIf_WaitCount], [DIf_Percentage], [Last_Percentage] )
	EXEC [dbo].[stpHistorico_Waits_Stats] @Dt_Inicio, @Dt_Fim
	
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Waits_Stats](	[WaitType], [Min_Log], [Max_Log], [DIf_Wait_S], [DIf_Resource_S], [DIf_Signal_S], 
													[DIf_WaitCount], [DIf_Percentage], [Last_Percentage] )
		SELECT 'Sem registro de Waits Stats.', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END
END

GO
IF (OBJECT_ID('[dbo].[stpCheckList_SQLServer_ErrorLog]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_SQLServer_ErrorLog]
GO

/*******************************************************************************************************************************
--	Error Log SQL
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_SQLServer_ErrorLog]
AS
BEGIN
	SET NOCOUNT ON

	SET DATEFORMAT MDY

	IF (OBJECT_ID('tempdb..#TempLog') IS NOT NULL)
		DROP TABLE #TempLog
	
	CREATE TABLE #TempLog (
		[LogDate]		DATETIME,
		[ProcessInfo]	NVARCHAR(50),
		[Text]			NVARCHAR(MAX)
	)

	IF (OBJECT_ID('tempdb..#logF') IS NOT NULL)
		DROP TABLE #logF
	
	CREATE TABLE #logF (
		[ArchiveNumber] INT,
		[LogDate]		DATETIME,
		[LogSize]		INT 
	)

	-- Seleciona o número de arquivos.
	INSERT INTO #logF  
	EXEC sp_enumerrorlogs
	
	DELETE FROM #logF
	WHERE LogDate < GETDATE()-2

	DECLARE @TSQL NVARCHAR(2000), @lC INT

	SELECT @lC = MIN(ArchiveNumber) FROM #logF

	-- Loop para realizar a leitura de todo o log
	WHILE @lC IS NOT NULL
	BEGIN
		  INSERT INTO #TempLog
		  EXEC sp_readerrorlog @lC
		  SELECT @lC = MIN(ArchiveNumber) FROM #logF
		  WHERE ArchiveNumber > @lC
	END
	
	TRUNCATE TABLE [dbo].[CheckList_SQLServer_ErrorLog]
	TRUNCATE TABLE [dbo].[CheckList_SQLServer_LoginFailed]
	TRUNCATE TABLE [dbo].[CheckList_SQLServer_LoginFailed_Email]

	-- Login Failed
	INSERT INTO [dbo].[CheckList_SQLServer_LoginFailed]( [Text], [Qt_Erro] )
	SELECT RTRIM([Text]), COUNT(*)
	FROM #TempLog
	WHERE [LogDate] >= GETDATE()-1
		AND [Text] LIKE '%Login failed for user%'
	GROUP BY [Text]
	
	IF (@@ROWCOUNT <> 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_SQLServer_LoginFailed_Email]( [Nr_Ordem], [Text], [Qt_Erro] )
		SELECT TOP 10 1, [Text], [Qt_Erro]
		FROM [dbo].[CheckList_SQLServer_LoginFailed]
		ORDER BY [Qt_Erro] DESC

		INSERT INTO [dbo].[CheckList_SQLServer_LoginFailed_Email]( [Nr_Ordem], [Text], [Qt_Erro] )
		SELECT 2, 'TOTAL', SUM([Qt_Erro])
		FROM [dbo].[CheckList_SQLServer_LoginFailed]
	END
	ELSE
	BEGIN
		INSERT INTO [dbo].[CheckList_SQLServer_LoginFailed_Email]( [Text], [Qt_Erro] )
		SELECT 'Sem registro de Falha de Login', NULL
	END
	
	-- Error Log
	INSERT INTO [dbo].[CheckList_SQLServer_ErrorLog]( [Dt_Log], [ProcessInfo], [Text] )
	SELECT [LogDate], [ProcessInfo], [Text]
	FROM #TempLog
	WHERE [LogDate] >= GETDATE()-1
		AND [ProcessInfo] <> 'Backup'
		AND [Text] NOT LIKE '%CHECKDB%'
		AND [Text] NOT LIKE '%Trace%'
		AND [Text] NOT LIKE '%IDR%'
		AND [Text] NOT LIKE 'AppDomain%'
		AND [Text] NOT LIKE 'Unsafe assembly%'
		AND [Text] NOT LIKE '%Login failed for user%'
		AND [Text] NOT LIKE '%Error:%Severity:%State:%'
		AND [Text] NOT LIKE '%Erro:%Gravidade:%Estado:%'
		AND [Text] NOT LIKE '%No user action is required.%'
		AND [Text] NOT LIKE '%no user action is required.%'
		
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_SQLServer_ErrorLog]( [Dt_Log], [ProcessInfo], [Text] )
		SELECT NULL, NULL, 'Sem registro de Erro no Log'
	END
END

GO

/*******************************************************************************************************************************
--	Tabela de controle que será utilizada para armazenar o Historico dos Alertas.
*******************************************************************************************************************************/
IF ( OBJECT_ID('[dbo].[Alerta]') IS NULL )
BEGIN	
	CREATE TABLE [dbo].[Alerta] (
		[Id_Alerta]		INT IDENTITY PRIMARY KEY,
		[Id_Alerta_Parametro]	INT NOT NULL,
		[Ds_Mensagem]	VARCHAR(2000),
		[Fl_Tipo]		TINYINT,						-- 0: CLEAR / 1: ALERTA
		[Dt_Alerta]		DATETIME DEFAULT(GETDATE())
	)
END


GO
IF (OBJECT_ID('[dbo].[CheckList_Alerta]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Alerta]

CREATE TABLE [dbo].[CheckList_Alerta] (
	[Nm_Alerta] VARCHAR(200) NULL,
	[Ds_Mensagem] VARCHAR(200) NULL,
	[Dt_Alerta] DATETIME,
	[Run_Duration] VARCHAR(18)
)

IF (OBJECT_ID('[dbo].[CheckList_Alerta_Sem_Clear]') IS NOT NULL)
	DROP TABLE [dbo].[CheckList_Alerta_Sem_Clear]

CREATE TABLE [dbo].[CheckList_Alerta_Sem_Clear] (
	[Nm_Alerta] VARCHAR(200) NULL,
	[Ds_Mensagem] VARCHAR(200) NULL,
	[Dt_Alerta] DATETIME,
	[Run_Duration] VARCHAR(18)
)

GO

IF (OBJECT_ID('[dbo].[stpCheckList_Alerta]') IS NOT NULL)
	DROP PROCEDURE [dbo].[stpCheckList_Alerta]	
GO

/*******************************************************************************************************************************
--	Alertas
*******************************************************************************************************************************/
CREATE PROCEDURE [dbo].[stpCheckList_Alerta]
AS
BEGIN
	SET NOCOUNT ON

	IF(OBJECT_ID('tempdb..#CheckList_Alerta') IS NOT NULL)
		DROP TABLE #CheckList_Alerta

	CREATE TABLE #CheckList_Alerta (
		Id_Alerta INT,
		Id_Alerta_Parametro INT,
		Nm_Alerta VARCHAR(200),
		Ds_Mensagem VARCHAR(2000),
		Dt_Alerta DATETIME,
		Fl_Tipo BIT,
		Run_Duration VARCHAR(18)
	)

	-- Seta a Data de Referencia
	DECLARE @Dt_Referencia DATETIME = DATEADD(HOUR, -24, GETDATE())

	-- Busca os Alertas a partir da Data de Referência
	INSERT INTO #CheckList_Alerta
	SELECT [Id_Alerta], A.[Id_Alerta_Parametro], [Nm_Alerta], [Ds_Mensagem], [Dt_Alerta], [Fl_Tipo], NULL	
	FROM [dbo].[Alerta] A WITH(NOLOCK)
	JOIN [dbo].[Alerta_Parametro] B WITH(NOLOCK) ON A.Id_Alerta_Parametro = B.Id_Alerta_Parametro
	WHERE [Dt_Alerta] > @Dt_Referencia

	IF(OBJECT_ID('tempdb..#CheckList_Alerta_Clear') IS NOT NULL)
		DROP TABLE #CheckList_Alerta_Clear

	select A.Id_Alerta, A.Dt_Alerta AS Dt_Clear, MAX(B.Dt_Alerta) AS Dt_Alerta
	into #CheckList_Alerta_Clear
	from #CheckList_Alerta A
	JOIN [dbo].[Alerta_Parametro] C WITH(NOLOCK) ON A.Id_Alerta_Parametro = C.Id_Alerta_Parametro
	JOIN [dbo].[Alerta] B ON A.Id_Alerta_Parametro = C.Id_Alerta_Parametro and B.Fl_Tipo = 1 and B.Dt_Alerta < A.Dt_Alerta	
	where A.Fl_Tipo = 0
	group by A.Id_Alerta, A.Dt_Alerta

	UPDATE A
	SET	A.Run_Duration =
			RIGHT('00' + CAST((DATEDIFF(SECOND,B.Dt_Alerta, B.Dt_Clear) / 86400) AS VARCHAR), 2) + ' Dia(s) ' +	-- Dia
			RIGHT('00' + CAST((DATEDIFF(SECOND,B.Dt_Alerta, B.Dt_Clear) / 3600 % 24) AS VARCHAR), 2) + ':' +	-- Hora
			RIGHT('00' + CAST((DATEDIFF(SECOND,B.Dt_Alerta, B.Dt_Clear) / 60 % 60) AS VARCHAR), 2) + ':' +		-- Minutos
			RIGHT('00' + CAST((DATEDIFF(SECOND,B.Dt_Alerta, B.Dt_Clear) % 60) AS VARCHAR), 2)					-- Segundos	
	from #CheckList_Alerta A
	join #CheckList_Alerta_Clear B on A.Id_Alerta = B.Id_Alerta
	
	-- Limpa os dados antigos da tabela do CheckList	
	TRUNCATE TABLE [dbo].[CheckList_Alerta]
	
	INSERT INTO [dbo].[CheckList_Alerta]
	SELECT Nm_Alerta, Ds_Mensagem, Dt_Alerta, Run_Duration 
	FROM #CheckList_Alerta

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Alerta] ( [Nm_Alerta], [Ds_Mensagem], [Dt_Alerta], [Run_Duration] )
		SELECT 'Sem registro de Alertas no dia Anterior', NULL, NULL, NULL
	END

	TRUNCATE TABLE [dbo].[CheckList_Alerta_Sem_Clear]
	
	-- Busca os Alertas que estão sem o CLEAR
	INSERT INTO [dbo].[CheckList_Alerta_Sem_Clear]
	SELECT	[Nm_Alerta], [Ds_Mensagem], [Dt_Alerta],
			RIGHT('00' + CAST((DATEDIFF(SECOND,Dt_Alerta, GETDATE()) / 86400) AS VARCHAR), 2) + ' Dia(s) ' +	-- Dia
			RIGHT('00' + CAST((DATEDIFF(SECOND,Dt_Alerta, GETDATE()) / 3600 % 24) AS VARCHAR), 2) + ':' +		-- Hora
			RIGHT('00' + CAST((DATEDIFF(SECOND,Dt_Alerta, GETDATE()) / 60 % 60) AS VARCHAR), 2) + ':' +			-- Minutos
			RIGHT('00' + CAST((DATEDIFF(SECOND,Dt_Alerta, GETDATE()) % 60) AS VARCHAR), 2) AS [Run_Duration]	-- Segundos	
	FROM [dbo].[Alerta] A WITH(NOLOCK)
	JOIN [dbo].[Alerta_Parametro] B WITH(NOLOCK) ON A.Id_Alerta_Parametro = B.Id_Alerta_Parametro
	WHERE	[Id_Alerta] = ( SELECT MAX([Id_Alerta]) FROM [dbo].[Alerta] B WITH(NOLOCK) WHERE A.Id_Alerta_Parametro = B.Id_Alerta_Parametro )
			AND B.[Fl_Clear] = 1	-- Possui CLEAR
			AND A.[Fl_Tipo] = 1		-- ALERTA
	 
	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT INTO [dbo].[CheckList_Alerta_Sem_Clear] ( [Nm_Alerta], [Ds_Mensagem], [Dt_Alerta], [Run_Duration] )
		SELECT 'Sem registro de Alerta sem CLEAR', NULL, NULL, NULL
	END
END

GO