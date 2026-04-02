/***********************************************************************************************************************************
(C) 2017, Fabricio Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
***********************************************************************************************************************************/


/*******************************************************************************************************************************
--	Instruções de utilização do script.
*******************************************************************************************************************************/
/*
	Apertar F5 para executar todo o script.
*/

SET NOCOUNT ON

GO

EXEC [sp_configure] 'show advanced option', 1

RECONFIGURE with OVERRIDE

EXEC [sp_configure] 'Ole Automation Procedures', 1

RECONFIGURE with OVERRIDE
 
EXEC [sp_configure] 'show advanced option', 0

RECONFIGURE with OVERRIDE

GO

USE [Traces]

/*******************************************************************************************************************************
--	Tabela de controle que será utilizada para armazenar o Historico da tabela Suspect Pages.
*******************************************************************************************************************************/
IF ( OBJECT_ID('[dbo].[Historico_Suspect_Pages]') IS NOT NULL )
	DROP TABLE [dbo].[Historico_Suspect_Pages]

CREATE TABLE [dbo].[Historico_Suspect_Pages](
	[database_id] [int] NOT NULL,
	[file_id] [int] NOT NULL,
	[page_id] [bigint] NOT NULL,
	[event_type] [int] NOT NULL,
	[Dt_Corrupcao] [datetime] NOT NULL
) ON [PRIMARY]


/*******************************************************************************************************************************
--	CRIA OS ALERTAS
*******************************************************************************************************************************/

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Processo_Bloqueado]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Processo_Bloqueado]
GO

/*******************************************************************************************************************************
--	ALERTA: PROCESSO BLOQUEADO
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Processo_Bloqueado]
AS
BEGIN
	SET NOCOUNT ON

	-- Processo Bloqueado
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Processo Bloqueado')
	
	-- Declara as variaveis
	DECLARE	@Subject VARCHAR(500), @Fl_Tipo TINYINT, @Qtd_Segundos INT, @Consulta VARCHAR(8000), @Importance AS VARCHAR(6), @Dt_Atual DATETIME,
			@EmailBody VARCHAR(MAX), @AlertaLockHeader VARCHAR(MAX), @AlertaLockTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
			@AlertaLockRaizHeader VARCHAR(MAX), @AlertaLockRaizTable VARCHAR(MAX), @Processo_Bloqueado_Parametro INT, @Qt_Tempo_Raiz_Lock INT,
			@EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@Processo_Bloqueado_Parametro = Vl_Parametro,		-- Minutos,
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro			-- Processo Bloqueado

	-- Quantidade em Minutos
	SELECT	@Qt_Tempo_Raiz_Lock	= 1		-- Query que esta gerando o lock (rodando a mais de 1 minuto)

	--------------------------------------------------------------------------------------------------------------------------------
	--	Cria Tabela para armazenar os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela que ira armazenar os dados dos processos
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
      
	-- Seta a hora atual
	SELECT @Dt_Atual = GETDATE()

	--------------------------------------------------------------------------------------------------------------------------------
	--	Carrega os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Retorna todos os processos que estão sendo executados no momento
	EXEC [dbo].[sp_whoisactive]
			@get_outer_command =	1,
			@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
			@destination_table =	'#Resultado_WhoisActive'
				    
	-- Altera a coluna que possui o comando SQL
	ALTER TABLE #Resultado_WhoisActive
	ALTER COLUMN [sql_command] VARCHAR(MAX)
	
	UPDATE #Resultado_WhoisActive
	SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
	
	-- select * from #Resultado_WhoisActive
	
	-- Verifica se não existe nenhum processo em Execução
	IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
	BEGIN
		INSERT INTO #Resultado_WhoisActive
		SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )
	
	/*******************************************************************************************************************************
	--	Verifica se existe algum Processo Bloqueado
	*******************************************************************************************************************************/	
	IF EXISTS	(
					SELECT NULL 
					FROM #Resultado_WhoisActive A
					JOIN #Resultado_WhoisActive B ON A.[blocking_session_id] = B.[session_id]
					WHERE	DATEDIFF(SECOND,A.[start_time], @Dt_Atual) > @Processo_Bloqueado_Parametro * 60		-- A query que está sendo bloqueada está rodando a mais 2 minutos
							AND DATEDIFF(SECOND,B.[start_time], @Dt_Atual) > @Qt_Tempo_Raiz_Lock * 60			-- A query que está bloqueando está rodando a mais de 1 minuto
				)
	BEGIN	-- INICIO - ALERTA
		IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
		BEGIN
			--------------------------------------------------------------------------------------------------------------------------------
			--	Verifica a quantidade de processos bloqueados
			--------------------------------------------------------------------------------------------------------------------------------
			-- Declara a variavel e retorna a quantidade de Queries Lentas
			DECLARE @QtdProcessosBloqueados INT = (
										SELECT COUNT(*)
										FROM #Resultado_WhoisActive A
										JOIN #Resultado_WhoisActive B ON A.[blocking_session_id] = B.[session_id]
										WHERE	DATEDIFF(SECOND,A.[start_time], @Dt_Atual) > @Processo_Bloqueado_Parametro	* 60
												AND DATEDIFF(SECOND,B.[start_time], @Dt_Atual) > @Qt_Tempo_Raiz_Lock * 60
									)

			DECLARE @QtdProcessosBloqueadosLocks INT = (
										SELECT COUNT(*)
										FROM #Resultado_WhoisActive A
										WHERE [blocking_session_id] IS NOT NULL
									)

			--------------------------------------------------------------------------------------------------------------------------------
			--	Verifica o Nivel dos Locks
			--------------------------------------------------------------------------------------------------------------------------------
			ALTER TABLE #Resultado_WhoisActive
			ADD Nr_Nivel_Lock TINYINT 

			-- Nivel 0
			UPDATE A
			SET Nr_Nivel_Lock = 0
			FROM #Resultado_WhoisActive A
			WHERE blocking_session_id IS NULL AND session_id IN ( SELECT DISTINCT blocking_session_id 
						FROM #Resultado_WhoisActive WHERE blocking_session_id IS NOT NULL)

			UPDATE A
			SET Nr_Nivel_Lock = 1
			FROM #Resultado_WhoisActive A
			WHERE	Nr_Nivel_Lock IS NULL
					AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 0)

			UPDATE A
			SET Nr_Nivel_Lock = 2
			FROM #Resultado_WhoisActive A
			WHERE	Nr_Nivel_Lock IS NULL
					AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 1)

			UPDATE A
			SET Nr_Nivel_Lock = 3
			FROM #Resultado_WhoisActive A
			WHERE	Nr_Nivel_Lock IS NULL
					AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 2)

			-- Tratamento quando não tem um Lock Raiz
			IF NOT EXISTS(select * from #Resultado_WhoisActive where Nr_Nivel_Lock IS NOT NULL)
			BEGIN
				UPDATE A
				SET Nr_Nivel_Lock = 0
				FROM #Resultado_WhoisActive A
				WHERE session_id IN ( SELECT DISTINCT blocking_session_id 
					FROM #Resultado_WhoisActive WHERE blocking_session_id IS NOT NULL)
          
				UPDATE A
				SET Nr_Nivel_Lock = 1
				FROM #Resultado_WhoisActive A
				WHERE	Nr_Nivel_Lock IS NULL
						AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 0)

				UPDATE A
				SET Nr_Nivel_Lock = 2
				FROM #Resultado_WhoisActive A
				WHERE	Nr_Nivel_Lock IS NULL
						AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 1)

				UPDATE A
				SET Nr_Nivel_Lock = 3
				FROM #Resultado_WhoisActive A
				WHERE	Nr_Nivel_Lock IS NULL
						AND blocking_session_id IN ( SELECT DISTINCT session_id FROM #Resultado_WhoisActive WHERE Nr_Nivel_Lock = 2)
			END

			/*******************************************************************************************************************************
			--	CRIA O EMAIL - ALERTA
			*******************************************************************************************************************************/							
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER - RAIZ LOCK
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLockRaizHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaLockRaizHeader = @AlertaLockRaizHeader + '<BR /> TOP 50 - Processos Raiz Lock <BR />'
			SET @AlertaLockRaizHeader = @AlertaLockRaizHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY - RAIZ LOCK
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLockRaizTable = CAST( (
				SELECT td =				[Nr_Nivel_Lock]			+ '</td>'
							+ '<td>' +	[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								CAST(Nr_Nivel_Lock AS VARCHAR)							AS [Nr_Nivel_Lock],
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
						WHERE Nr_Nivel_Lock IS NOT NULL
						ORDER BY [Nr_Nivel_Lock], [start_time] 
				
					  ) AS D ORDER BY [Nr_Nivel_Lock], [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaLockRaizTable = REPLACE( REPLACE( REPLACE( @AlertaLockRaizTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaLockRaizTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="80"><font color=white>Nivel Lock</font></th>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaLockRaizTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			
						
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLockHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaLockHeader = @AlertaLockHeader + '<BR /> TOP 50 - Processos executando no Banco de Dados <BR />'
			SET @AlertaLockHeader = @AlertaLockHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLockTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
						ORDER BY [start_time]

					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaLockTable = REPLACE( REPLACE( REPLACE( @AlertaLockTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaLockTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaLockTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			              
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/			              
			SELECT	@Importance =	'High',
					@Subject =		'ALERTA: Existe(m) ' + CAST(@QtdProcessosBloqueados AS VARCHAR) + 
									' Processo(s) Bloqueado(s) a mais de ' +  CAST((@Processo_Bloqueado_Parametro) AS VARCHAR) + ' minuto(s)' +
									' e um total de ' + CAST(@QtdProcessosBloqueadosLocks AS VARCHAR) +  ' Lock(s) no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaLockRaizHeader + @EmptyBodyEmail + @AlertaLockRaizTable + @EmptyBodyEmail
									+ @AlertaLockHeader + @EmptyBodyEmail + @AlertaLockTable + @EmptyBodyEmail
				
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
				
			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - ALERTA
			*******************************************************************************************************************************/	
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
					
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 1			
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR				
		IF @Fl_Tipo = 1
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLockHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaLockHeader = @AlertaLockHeader + '<BR /> Processos executando no Banco de Dados <BR />' 
			SET @AlertaLockHeader = @AlertaLockHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLockTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaLockTable = REPLACE( REPLACE( REPLACE( @AlertaLockTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaLockTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaLockTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			              			
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: Não existe mais algum Processo Bloqueado a mais de ' + 
									CAST((@Processo_Bloqueado_Parametro) AS VARCHAR) + ' minuto(s) no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaLockHeader + @EmptyBodyEmail + @AlertaLockTable + @EmptyBodyEmail
				
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
			
			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance

			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0		
		END		
	END		-- FIM - CLEAR
END



GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Arquivo_Log_Full]') IS NOT NULL )
	DROP PROCEDURE [dbo].[stpAlerta_Arquivo_Log_Full]
GO

/*******************************************************************************************************************************
--	ALERTA: ARQUIVO DE LOG FULL
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Arquivo_Log_Full]
AS
BEGIN
	SET NOCOUNT ON

	-- Arquivo de Log Full
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Arquivo de Log Full')
	
	-- Declara as variaveis
	DECLARE @Tamanho_Minimo_Alerta_log INT, @AlertaLogHeader VARCHAR(MAX), @AlertaLogTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
			@Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @Subject VARCHAR(500), @Fl_Tipo TINYINT, @Log_Full_Parametro TINYINT,
			@ResultadoWhoisactiveHeader VARCHAR(MAX), @ResultadoWhoisactiveTable VARCHAR(MAX), @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@Log_Full_Parametro = Vl_Parametro,				-- Percentual
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Arquivo de Log Full

	-- Seta as variaveis
	SELECT	@Tamanho_Minimo_Alerta_log = 500000		-- 500 MB
	
	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA	
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )
	
	-- Cria a tabela que ira armazenar os dados dos processos
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

	-- Cria a tabela que ira armazenar os dados dos arquivos de log
	IF ( OBJECT_ID('tempdb..#Alerta_Arquivo_Log_Full') IS NOT NULL )
		DROP TABLE #Alerta_Arquivo_Log_Full

	SELECT	db.[name] AS [DatabaseName] ,
			CAST(ls.[cntr_value] / 1024.00 AS DECIMAL(18,2)) AS [cntr_value],
			CAST(	CAST(lu.[cntr_value] AS FLOAT) / 
					CASE WHEN CAST(ls.[cntr_value] AS FLOAT) = 0 
							THEN 1 
							ELSE CAST(ls.[cntr_value] AS FLOAT) 
					END AS DECIMAL(18,2)) * 100	AS [Percente_Log_Used] 
	INTO #Alerta_Arquivo_Log_Full
	FROM [sys].[databases] AS db
	JOIN [sys].[dm_os_performance_counters] AS lu  ON db.[name] = lu.[instance_name]
	JOIN [sys].[dm_os_performance_counters] AS ls  ON db.[name] = ls.[instance_name]
	WHERE	lu.[counter_name] LIKE 'Log File(s) Used Size (KB)%'
			AND ls.[counter_name] LIKE 'Log File(s) Size (KB)%'
			AND ls.[cntr_value] > @Tamanho_Minimo_Alerta_log -- Maior que 100 MB
		
	/*******************************************************************************************************************************
	-- Verifica se existe algum LOG com muita utilização
	*******************************************************************************************************************************/
	IF EXISTS(
				SELECT	*
				FROM #Alerta_Arquivo_Log_Full
				WHERE	[Percente_Log_Used] > @Log_Full_Parametro
			 )
	BEGIN	-- INICIO - ALERTA
		IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
		BEGIN
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - DADOS - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			-- Retorna todos os processos que estão sendo executados no momento
			EXEC [dbo].[sp_whoisactive]
					@get_outer_command =	1,
					@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
					@destination_table =	'#Resultado_WhoisActive'
						    
			-- Altera a coluna que possui o comando SQL
			ALTER TABLE #Resultado_WhoisActive
			ALTER COLUMN [sql_command] VARCHAR(MAX)
						
			UPDATE #Resultado_WhoisActive
			SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
			-- select * from #Resultado_WhoisActive
			
			-- Verifica se não existe nenhum processo em Execução
			IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
			BEGIN
				INSERT INTO #Resultado_WhoisActive
				SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
			END		
		
			/*******************************************************************************************************************************
			--	ALERTA - CRIA O EMAIL
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER - LOG FULL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLogHeader = '<font color=black bold=true size= 5>'
			SET @AlertaLogHeader = @AlertaLogHeader + '<BR /> Informações dos Arquivos de Log <BR />'
			SET @AlertaLogHeader = @AlertaLogHeader + '</font>'
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY - LOG FULL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLogTable = CAST( (    
				SELECT td =				[DatabaseName]							+ '</td>'
							+ '<td>' +	CAST([cntr_value] AS VARCHAR)			+ '</td>'
							+ '<td>' +	CAST([Percente_Log_Used] AS VARCHAR)	+ '</td>'
				FROM (	
						-- Dados da Tabela do EMAIL
						SELECT	[DatabaseName],
								[cntr_value],
								[Percente_Log_Used]
						FROM #Alerta_Arquivo_Log_Full
						WHERE	[Percente_Log_Used] > @Log_Full_Parametro

					  ) AS D ORDER BY [Percente_Log_Used] DESC
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			
			-- Corrige a Formatação da Tabela
			SET @AlertaLogTable = REPLACE( REPLACE( REPLACE( @AlertaLogTable, '&lt;', '<' ), '&gt;', '>' ), '<td>', '<td align=center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaLogTable =
					'<table cellspacing="2" cellpadding="5" border="3">'
					+	'<tr>
							<th bgcolor=#0B0B61 width="200"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Tamanho Log (MB)</font></th> 
							<th bgcolor=#0B0B61 width="250"><font color=white>Percentual Log Utilizado (%)</font></th>
						</tr>'
					+ REPLACE( REPLACE( @AlertaLogTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>'
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos executando no Banco de Dados <BR />'
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @ResultadoWhoisactiveTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
		
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'
			
			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'ALERTA: Existe algum Arquivo de Log com mais de ' +  CAST((@Log_Full_Parametro) AS VARCHAR) + '% de utilização no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaLogHeader + @EmptyBodyEmail + @AlertaLogTable + @EmptyBodyEmail + 
									@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail
									
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
						
			/*******************************************************************************************************************************
			--	ALERTA - ENVIA O EMAIL
			*******************************************************************************************************************************/	
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
           	
           	/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 1			
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR
		IF @Fl_Tipo = 1
		BEGIN
			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - DADOS - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------		      
			-- Retorna todos os processos que estão sendo executados no momento
			EXEC [dbo].[sp_whoisactive]
					@get_outer_command =	1,
					@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
					@destination_table =	'#Resultado_WhoisActive'
						    
			-- Altera a coluna que possui o comando SQL
			ALTER TABLE #Resultado_WhoisActive
			ALTER COLUMN [sql_command] VARCHAR(MAX)
			
			UPDATE #Resultado_WhoisActive
			SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
			-- select * from #Resultado_WhoisActive
			
			-- Verifica se não existe nenhum processo em Execução
			IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
			BEGIN
				INSERT INTO #Resultado_WhoisActive
				SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
			END
		
			/*******************************************************************************************************************************
			--	CLEAR - CRIA O EMAIL
			*******************************************************************************************************************************/										

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLogHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaLogHeader = @AlertaLogHeader + '<BR /> Informações dos Arquivos de Log <BR />' 
			SET @AlertaLogHeader = @AlertaLogHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaLogTable = CAST( (    
				SELECT td =				[DatabaseName]							+ '</td>'
							+ '<td>' +	CAST([cntr_value] AS VARCHAR)			+ '</td>'
							+ '<td>' +	CAST([Percente_Log_Used] AS VARCHAR)	+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	[DatabaseName],
								[cntr_value],
								[Percente_Log_Used]
						FROM #Alerta_Arquivo_Log_Full
						 							 
					  ) AS D ORDER BY [Percente_Log_Used] DESC
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			
			-- Corrige a Formatação da Tabela
			SET @AlertaLogTable = REPLACE( REPLACE( REPLACE( @AlertaLogTable, '&lt;', '<' ), '&gt;', '>' ), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaLogTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="200"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Tamanho Log (MB)</font></th> 
							<th bgcolor=#0B0B61 width="250"><font color=white>Percentual Log Utilizado (%)</font></th>          
						</tr>'    
					+ REPLACE( REPLACE( @AlertaLogTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>' 
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos executando no Banco de Dados <BR />'
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @ResultadoWhoisactiveTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'
			
			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: Não existe mais algum Arquivo de Log com mais de ' +  CAST((@Log_Full_Parametro) AS VARCHAR) + '% de utilização no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaLogHeader + @EmptyBodyEmail + @AlertaLogTable + @EmptyBodyEmail + 
									@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail
									
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
						
			/*******************************************************************************************************************************
			--	ALERTA - ENVIA O EMAIL
			*******************************************************************************************************************************/	
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
						
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0		
		END
	END		-- FIM - CLEAR
END



GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Espaco_Disco]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Espaco_Disco]
GO

/*******************************************************************************************************************************
--	ALERTA: ESPAÇO DISCO
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Espaco_Disco]
AS
BEGIN
	SET NOCOUNT ON

	-- Cria as tabelas que irão armazenar as informações do Espaço em Disco	
	IF ( OBJECT_ID('tempdb..#dbspace') IS NOT NULL )
		DROP TABLE #dbspace
		
	CREATE TABLE #dbspace (
		[name]		SYSNAME,
		[caminho]	VARCHAR(200),
		[tamanho]	VARCHAR(10),
		[drive]		VARCHAR(30)
	)
	
	IF ( OBJECT_ID('tempdb..#espacodisco') IS NOT NULL )
		DROP TABLE #espacodisco

	CREATE TABLE [#espacodisco] (
		[Drive]				VARCHAR (10),
		[Tamanho (MB)]		INT,
		[Usado (MB)]		INT,
		[Livre (MB)]		INT,
		[Livre (%)]			INT,
		[Usado (%)]			INT,
		[Ocupado SQL (MB)]	INT, 
		[Data]				SMALLDATETIME
	)
	
	IF ( OBJECT_ID('tempdb..#space') IS NOT NULL ) 
		DROP TABLE #space 

	CREATE TABLE #space (
		[drive]		CHAR(1),
		[mbfree]	INT
	)
			
	-- Popula as tabelas com as informações sobre o Espaço em Disco
	EXEC sp_MSforeachdb 'Use [?] INSERT INTO #dbspace SELECT CONVERT(VARCHAR(25), DB_Name()) ''Database'', CONVERT(VARCHAR(60), FileName), CONVERT(VARCHAR(8), Size / 128) ''Size in MB'', CONVERT(VARCHAR(30), Name) FROM sysfiles'

	-- Declara as variaveis
	DECLARE @hr INT, @fso INT, @mbtotal INT, @TotalSpace INT, @MBFree INT, @Percentage INT,
			@SQLDriveSize INT, @size float, @drive VARCHAR(1), @fso_Method VARCHAR(255)

	SELECT	@mbtotal = 0, 
			@mbtotal = 0
			
	EXEC @hr = [master].[dbo].[sp_OACreate] 'Scripting.FilesystemObject', @fso OUTPUT
		
	INSERT INTO #space 
	EXEC [master].[dbo].[xp_fixeddrives]
	
	-- Utiliza o Cursor para gerar as informações de cada Disco
	DECLARE CheckDrives CURSOR FOR SELECT drive,mbfree FROM #space
	OPEN CheckDrives
	FETCH NEXT FROM CheckDrives INTO @drive, @MBFree
	WHILE(@@FETCH_STATUS = 0)
	BEGIN
		SET @fso_Method = 'Drives("' + @drive + ':").TotalSize'
		
		SELECT @SQLDriveSize = SUM(CONVERT(INT, [tamanho])) 
		FROM #dbspace 
		WHERE SUBSTRING([caminho], 1, 1) = @drive
		
		EXEC @hr = [sp_OAMethod] @fso, @fso_Method, @size OUTPUT
		
		SET @mbtotal =  @size / (1024 * 1024)
		
		INSERT INTO #espacodisco 
		VALUES(	@drive + ':', @mbtotal, @mbtotal - @MBFree, @MBFree, (100 * ROUND(@MBFree, 2) / ROUND(@mbtotal, 2)), 
				(100 - 100 * ROUND(@MBFree, 2) / ROUND(@mbtotal, 2)), @SQLDriveSize, GETDATE())

		FETCH NEXT FROM CheckDrives INTO @drive,@MBFree
	END
	CLOSE CheckDrives
	DEALLOCATE CheckDrives

	-- Tabela com os dados resumidos sobre o Espaço em Disco
	IF ( OBJECT_ID('_DTS_Espacodisco ') IS NOT NULL )
		DROP TABLE _DTS_Espacodisco 

	SELECT [Drive], [Tamanho (MB)], [Usado (MB)], [Livre (MB)], [Livre (%)], [Usado (%)], ISNULL([Ocupado SQL (MB)], 0) AS [Ocupado SQL (MB)] 
	INTO [dbo].[_DTS_Espacodisco]
	FROM #espacodisco

	-- Cria a tabela que ira armazenar os dados dos processos
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

	-- Declara as variaveis
	DECLARE @Subject VARCHAR(500), @Fl_Tipo TINYINT, @Importance AS VARCHAR(6),@EmailBody VARCHAR(MAX), 
			@AlertaDiscoHeader VARCHAR(MAX),@AlertaDiscoTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX), @EmailDestination VARCHAR(500),
			@ResultadoWhoisactiveHeader VARCHAR(MAX), @ResultadoWhoisactiveTable VARCHAR(MAX), @Espaco_Disco_Parametro INT, @ProfileEmail VARCHAR(200)

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	-- Espaco Disco
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Espaco Disco')
	
	SELECT	@Espaco_Disco_Parametro = Vl_Parametro,			-- Percentual
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Espaco Disco

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]		
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )

	/*******************************************************************************************************************************
	--	Verifica o Espaço Livre em Disco
	*******************************************************************************************************************************/
	IF EXISTS	(		
					SELECT NULL 
					FROM [dbo].[_DTS_Espacodisco] 
					WHERE [Usado (%)] > @Espaco_Disco_Parametro
				)
	BEGIN	-- INICIO - ALERTA
		IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
		BEGIN
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - DADOS - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			-- Retorna todos os processos que estão sendo executados no momento
			EXEC [dbo].[sp_whoisactive]
					@get_outer_command =	1,
					@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
					@destination_table =	'#Resultado_WhoisActive'
						    
			-- Altera a coluna que possui o comando SQL
			ALTER TABLE #Resultado_WhoisActive
			ALTER COLUMN [sql_command] VARCHAR(MAX)
			
			UPDATE #Resultado_WhoisActive
			SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
			-- select * from #Resultado_WhoisActive
			
			-- Verifica se não existe nenhum processo em Execução
			IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
			BEGIN
				INSERT INTO #Resultado_WhoisActive
				SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
			END

			/*******************************************************************************************************************************
			--	CRIA O EMAIL - ALERTA
			*******************************************************************************************************************************/
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaDiscoHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaDiscoHeader = @AlertaDiscoHeader + '<BR /> Espaço em Disco no Servidor <BR />' 
			SET @AlertaDiscoHeader = @AlertaDiscoHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaDiscoTable = CAST( (    
				SELECT td =				[Drive]				+ '</td>'
							+ '<td>' +  [Tamanho (MB)]		+ '</td>'
							+ '<td>' +  [Usado (MB)]		+ '</td>'
							+ '<td>' +  [Livre (MB)]		+ '</td>'
							+ '<td>' +  [Livre (%)]			+ '</td>'
							+ '<td>' +  [Usado (%)]			+ '</td>'
							+ '<td>' +  [Ocupado SQL (MB)]	+ '</td>'
				FROM (   
						-- Dados da Tabela do EMAIL       
						SELECT 	[Drive], CAST([Tamanho (MB)] AS VARCHAR) AS [Tamanho (MB)], CAST([Usado (MB)] AS VARCHAR) AS [Usado (MB)], CAST([Livre (MB)] AS VARCHAR) AS [Livre (MB)], 
								CAST([Livre (%)] AS VARCHAR) AS [Livre (%)], CAST([Usado (%)] AS VARCHAR) AS [Usado (%)], CAST([Ocupado SQL (MB)] AS VARCHAR) AS [Ocupado SQL (MB)]
						FROM [Traces].[dbo].[_DTS_Espacodisco]
											
					  ) AS D ORDER BY [Drive]
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaDiscoTable = REPLACE( REPLACE( REPLACE( @AlertaDiscoTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaDiscoTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="100"><font color=white>Drive (%)</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Tamanho (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Usado (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Livre (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Livre (%)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Usado (%)</font></th>  
							<th bgcolor=#0B0B61 width="150"><font color=white>Ocupado SQL (MB)</font></th>				  	  	  	                            
						</tr>'    
					+ REPLACE( REPLACE( @AlertaDiscoTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>' 

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos executando no Banco de Dados <BR />'
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @ResultadoWhoisactiveTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			 
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - ALERTA
			*******************************************************************************************************************************/				              
			SELECT	@Importance =	'High',
					@Subject =		'ALERTA: Existe algum volume de disco com mais de ' +  CAST((@Espaco_Disco_Parametro) AS VARCHAR) + '% de utilização no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaDiscoHeader + @EmptyBodyEmail + @AlertaDiscoTable + @EmptyBodyEmail +
									@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail

			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
				
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,					
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance

			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 1			
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR				
		IF @Fl_Tipo = 1
		BEGIN
			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - DADOS - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------		      
			-- Retorna todos os processos que estão sendo executados no momento
			EXEC [dbo].[sp_whoisactive]
					@get_outer_command =	1,
					@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
					@destination_table =	'#Resultado_WhoisActive'
						    
			-- Altera a coluna que possui o comando SQL
			ALTER TABLE #Resultado_WhoisActive
			ALTER COLUMN [sql_command] VARCHAR(MAX)
			
			UPDATE #Resultado_WhoisActive
			SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
			-- select * from #Resultado_WhoisActive
			
			-- Verifica se não existe nenhum processo em Execução
			IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
			BEGIN
				INSERT INTO #Resultado_WhoisActive
				SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
			END

			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaDiscoHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaDiscoHeader = @AlertaDiscoHeader + '<BR /> Espaço em Disco no Servidor <BR />' 
			SET @AlertaDiscoHeader = @AlertaDiscoHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			--------------------------------------------------------------------------------------------------------------------------------	 
			SET @AlertaDiscoTable = CAST( (    
				SELECT td =				[Drive]				+ '</td>'
							+ '<td>' +  [Tamanho (MB)]		+ '</td>'
							+ '<td>' +  [Usado (MB)]		+ '</td>'
							+ '<td>' +  [Livre (MB)]		+ '</td>'
							+ '<td>' +  [Livre (%)]			+ '</td>'
							+ '<td>' +  [Usado (%)]			+ '</td>'
							+ '<td>' +  [Ocupado SQL (MB)]	+ '</td>'
				FROM (    
						-- Dados da Tabela do EMAIL      
						SELECT 	[Drive], CAST([Tamanho (MB)] AS VARCHAR) AS [Tamanho (MB)], CAST([Usado (MB)] AS VARCHAR) AS [Usado (MB)], CAST([Livre (MB)] AS VARCHAR) AS [Livre (MB)], 
								CAST([Livre (%)] AS VARCHAR) AS [Livre (%)], CAST([Usado (%)] AS VARCHAR) AS [Usado (%)], CAST([Ocupado SQL (MB)] AS VARCHAR) AS [Ocupado SQL (MB)]
						FROM [Traces].[dbo].[_DTS_Espacodisco]
											
					  ) AS D ORDER BY [Drive]
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaDiscoTable = REPLACE( REPLACE( REPLACE( @AlertaDiscoTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaDiscoTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="100"><font color=white>Drive (%)</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Tamanho (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Usado (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Livre (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Livre (%)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Usado (%)</font></th>  
							<th bgcolor=#0B0B61 width="150"><font color=white>Ocupado SQL (MB)</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaDiscoTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>' 

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos executando no Banco de Dados <BR />'
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @ResultadoWhoisactiveTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
				 
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/				              
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: Não existe mais algum volume de disco com mais de ' +  CAST((@Espaco_Disco_Parametro) AS VARCHAR) + '% de utilização no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaDiscoHeader + @EmptyBodyEmail + @AlertaDiscoTable + @EmptyBodyEmail +
									@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail

			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
				
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,					
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
			
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0		
		END
	END		-- FIM - CLEAR
END


GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Consumo_CPU]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Consumo_CPU]
GO

/*******************************************************************************************************************************
--	ALERTA: CONSUMO CPU
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Consumo_CPU]
AS
BEGIN
	SET NOCOUNT ON

	-- Consumo CPU
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Consumo CPU')

	-- Declara as variaveis
	DECLARE	@Subject VARCHAR(500), @Fl_Tipo TINYINT, @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @CPU_Parametro INT,
			@AlertaCPUAgarradosHeader VARCHAR(MAX), @AlertaCPUAgarradosTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
			@ResultadoWhoisactiveHeader VARCHAR(MAX), @ResultadoWhoisactiveTable VARCHAR(MAX), @EmailDestination VARCHAR(500),
			@ProfileEmail VARCHAR(200)

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@CPU_Parametro = Vl_Parametro,					-- Percentual
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Consumo CPU

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )
	
	--------------------------------------------------------------------------------------------------------------------------------
	--	Cria Tabela para armazenar os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela que ira armazenar os dados dos processos
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

	--------------------------------------------------------------------------------------------------------------------------------
	-- Verifica a utilização da CPU
	--------------------------------------------------------------------------------------------------------------------------------	
	IF ( OBJECT_ID('tempdb..#CPU_Utilization') IS NOT NULL )
		DROP TABLE #CPU_Utilization
	
	SELECT TOP(2)
		record_id,
		[SQLProcessUtilization],
		100 - SystemIdle - SQLProcessUtilization as OtherProcessUtilization,
		[SystemIdle],
		100 - SystemIdle AS CPU_Utilization
	INTO #CPU_Utilization
	FROM	( 
				SELECT	record.value('(./Record/@id)[1]', 'int')													AS [record_id], 
						record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int')			AS [SystemIdle],
						record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int')	AS [SQLProcessUtilization], 
						[timestamp] 
				FROM ( 
						SELECT [timestamp], CONVERT(XML, [record]) AS [record] 
						FROM [sys].[dm_os_ring_buffers] 
						WHERE	[ring_buffer_type] = N'RING_BUFFER_SCHEDULER_MONITOR' 
								AND [record] LIKE '%<SystemHealth>%'
					) AS X					   
			) AS Y
	ORDER BY record_id DESC

	/*******************************************************************************************************************************
	--	Verifica se o Consumo de CPU está maior do que o parametro
	*******************************************************************************************************************************/
	IF (
			select CPU_Utilization from #CPU_Utilization
			where record_id = (select max(record_id) from #CPU_Utilization)
		) > @CPU_Parametro
	BEGIN	-- INICIO - ALERTA	
		IF (
			select CPU_Utilization from #CPU_Utilization
			where record_id = (select min(record_id) from #CPU_Utilization)
		) > @CPU_Parametro
		BEGIN
			IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
			BEGIN
				--------------------------------------------------------------------------------------------------------------------------------
				--	ALERTA - DADOS - WHOISACTIVE
				--------------------------------------------------------------------------------------------------------------------------------
				-- Retorna todos os processos que estão sendo executados no momento
				EXEC [dbo].[sp_whoisactive]
						@get_outer_command =	1,
						@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
						@destination_table =	'#Resultado_WhoisActive'
						    
				-- Altera a coluna que possui o comando SQL
				ALTER TABLE #Resultado_WhoisActive
				ALTER COLUMN [sql_command] VARCHAR(MAX)
			
				UPDATE #Resultado_WhoisActive
				SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
				-- select * from #Resultado_WhoisActive
			
				-- Verifica se não existe nenhum processo em Execução
				IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
				BEGIN
					INSERT INTO #Resultado_WhoisActive
					SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
				END
		
				/*******************************************************************************************************************************
				--	CRIA O EMAIL - ALERTA
				*******************************************************************************************************************************/

				--------------------------------------------------------------------------------------------------------------------------------
				--	ALERTA - HEADER
				--------------------------------------------------------------------------------------------------------------------------------
				SET @AlertaCPUAgarradosHeader = '<font color=black bold=true size=5>'			            
				SET @AlertaCPUAgarradosHeader = @AlertaCPUAgarradosHeader + '<BR /> Consumo de CPU no Servidor <BR />' 
				SET @AlertaCPUAgarradosHeader = @AlertaCPUAgarradosHeader + '</font>'

				--------------------------------------------------------------------------------------------------------------------------------
				--	ALERTA - BODY
				--------------------------------------------------------------------------------------------------------------------------------
				SET @AlertaCPUAgarradosTable = CAST( (    
					SELECT td =			[SQLProcessUtilization]	+ '</td>'
							+ '<td>' +	OtherProcessUtilization	+ '</td>'
							+ '<td>' +	[SystemIdle]			+ '</td>'
							+ '<td>' +	CPU_Utilization			+ '</td>'				 

					FROM (  
							-- Dados da Tabela do EMAIL	
							select	TOP 1
									CAST([SQLProcessUtilization] AS VARCHAR) [SQLProcessUtilization],
									CAST((100 - SystemIdle - SQLProcessUtilization) AS VARCHAR) as OtherProcessUtilization,
									CAST([SystemIdle] AS VARCHAR) AS [SystemIdle],
									CAST(100 - SystemIdle AS VARCHAR) AS CPU_Utilization
							from #CPU_Utilization
							order by record_id DESC
						
						  ) AS D 
					FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
				)  
			      
				-- Corrige a Formatação da Tabela
				SET @AlertaCPUAgarradosTable = REPLACE( REPLACE( REPLACE( @AlertaCPUAgarradosTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
				-- Títulos da Tabela do EMAIL
				SET @AlertaCPUAgarradosTable = 
						'<table cellspacing="2" cellpadding="5" border="3">'    
						+	'<tr>
								<th bgcolor=#0B0B61 width="200"><font color=white>SQL Server (%)</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Outros Processos (%)</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Livre (%)</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Utilização Total (%)</font></th>
							</tr>'    
						+ REPLACE( REPLACE( @AlertaCPUAgarradosTable, '&lt;', '<'), '&gt;', '>')   
						+ '</table>'
					
				--------------------------------------------------------------------------------------------------------------------------------
				--	ALERTA - HEADER - WHOISACTIVE
				--------------------------------------------------------------------------------------------------------------------------------
				SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
				SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos executando no Banco de Dados <BR />'
				SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

				--------------------------------------------------------------------------------------------------------------------------------
				--	ALERTA - BODY - WHOISACTIVE
				--------------------------------------------------------------------------------------------------------------------------------
				SET @ResultadoWhoisactiveTable = CAST( (
					SELECT td =				[Duração]				+ '</td>'
								+ '<td>' +  [database_name]			+ '</td>'
								+ '<td>' +  [login_name]			+ '</td>'
								+ '<td>' +  [host_name]				+ '</td>'
								+ '<td>' +  [start_time]			+ '</td>'
								+ '<td>' +  [status]				+ '</td>'
								+ '<td>' +  [session_id]			+ '</td>'
								+ '<td>' +  [blocking_session_id]	+ '</td>'
								+ '<td>' +  [Wait]					+ '</td>'
								+ '<td>' +  [open_tran_count]		+ '</td>'
								+ '<td>' +  [CPU]					+ '</td>'
								+ '<td>' +  [reads]					+ '</td>'
								+ '<td>' +  [writes]				+ '</td>'
								+ '<td>' +  [sql_command]			+ '</td>'

					FROM (  
							-- Dados da Tabela do EMAIL
							SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
									ISNULL([database_name], '-')							AS [database_name],
									ISNULL([login_name], '-')								AS [login_name],
									ISNULL([host_name], '-')								AS [host_name],
									ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
									ISNULL([status], '-')									AS [status],
									ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
									ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
									ISNULL([wait_info], '-')								AS [Wait],
									ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
									ISNULL([CPU], '-')										AS [CPU],
									ISNULL([reads], '-')									AS [reads],
									ISNULL([writes], '-')									AS [writes],
									ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
							FROM #Resultado_WhoisActive
				
						  ) AS D ORDER BY [start_time] 
					FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
				) 
			      
				-- Corrige a Formatação da Tabela
				SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
				-- Títulos da Tabela do EMAIL
				SET @ResultadoWhoisactiveTable = 
						'<table cellspacing="2" cellpadding="5" border="3">'    
						+	'<tr>
								<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
								<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
								<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
								<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
								<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
								<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
								<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
							</tr>'    
						+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
						+ '</table>'
			 
				--------------------------------------------------------------------------------------------------------------------------------
				-- Insere um Espaço em Branco no EMAIL
				--------------------------------------------------------------------------------------------------------------------------------
				SET @EmptyBodyEmail =	''
				SET @EmptyBodyEmail =
						'<table cellpadding="5" cellspacing="5" border="0">' +
							'<tr>
								<th width="500">               </th>
							</tr>'
							+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
						+ '</table>'

				/*******************************************************************************************************************************
				--	Seta as Variáveis do EMAIL
				*******************************************************************************************************************************/			              
				SELECT	@Importance =	'High',
						@Subject =		'ALERTA: O Consumo de CPU está acima de ' +  CAST((@CPU_Parametro) AS VARCHAR) + '% no Servidor: ' + @@SERVERNAME,
						@EmailBody =	@AlertaCPUAgarradosHeader + @EmptyBodyEmail + @AlertaCPUAgarradosTable + @EmptyBodyEmail +
										@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail
			
				/*******************************************************************************************************************************
				-- Inclui uma imagem com link para o site do Fabricio Lima
				*******************************************************************************************************************************/
				select @EmailBody = @EmailBody + '<br/><br/>' +
							'<a href="http://www.fabriciolima.net" target=”_blank”> 
								<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
										height="100" width="400"/>
							</a>'

				/*******************************************************************************************************************************
				--	ENVIA O EMAIL - ALERTA
				*******************************************************************************************************************************/	
				EXEC [msdb].[dbo].[sp_send_dbmail]
						@profile_name = @ProfileEmail,
						@recipients =	@EmailDestination,
						@subject =		@Subject,
						@body =			@EmailBody,
						@body_format =	'HTML',
						@importance =	@Importance
					
				/*******************************************************************************************************************************
				-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
				*******************************************************************************************************************************/
				INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
				SELECT @Id_Alerta_Parametro, @Subject, 1			
			END
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR		
		IF @Fl_Tipo = 1
		BEGIN
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - DADOS - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			-- Retorna todos os processos que estão sendo executados no momento
			EXEC [dbo].[sp_whoisactive]
					@get_outer_command =	1,
					@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
					@destination_table =	'#Resultado_WhoisActive'
						    
			-- Altera a coluna que possui o comando SQL
			ALTER TABLE #Resultado_WhoisActive
			ALTER COLUMN [sql_command] VARCHAR(MAX)
			
			UPDATE #Resultado_WhoisActive
			SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
			-- select * from #Resultado_WhoisActive
			
			-- Verifica se não existe nenhum processo em Execução
			IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
			BEGIN
				INSERT INTO #Resultado_WhoisActive
				SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
			END
		
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaCPUAgarradosHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaCPUAgarradosHeader = @AlertaCPUAgarradosHeader + '<BR /> Consumo de CPU no Servidor <BR />' 
			SET @AlertaCPUAgarradosHeader = @AlertaCPUAgarradosHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			-------------------------------------------------------------------------------------------------------------------------------- 
			SET @AlertaCPUAgarradosTable = CAST( (    
					SELECT td =			[SQLProcessUtilization]	+ '</td>'
							+ '<td>' +	OtherProcessUtilization	+ '</td>'
							+ '<td>' +	[SystemIdle]			+ '</td>'
							+ '<td>' +	CPU_Utilization			+ '</td>'				 

					FROM (  
							-- Dados da Tabela do EMAIL	
							select	TOP 1
									CAST([SQLProcessUtilization] AS VARCHAR) [SQLProcessUtilization],
									CAST((100 - SystemIdle - SQLProcessUtilization) AS VARCHAR) as OtherProcessUtilization,
									CAST([SystemIdle] AS VARCHAR) AS [SystemIdle],
									CAST(100 - SystemIdle AS VARCHAR) AS CPU_Utilization
							from #CPU_Utilization
							order by record_id DESC
						
						  ) AS D 
					FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
				)
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaCPUAgarradosTable = REPLACE( REPLACE( REPLACE( @AlertaCPUAgarradosTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaCPUAgarradosTable = 
						'<table cellspacing="2" cellpadding="5" border="3">'    
						+	'<tr>
								<th bgcolor=#0B0B61 width="200"><font color=white>SQL Server (%)</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Outros Processos (%)</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Livre (%)</font></th>
								<th bgcolor=#0B0B61 width="200"><font color=white>Utilização Total (%)</font></th>
							</tr>'    
						+ REPLACE( REPLACE( @AlertaCPUAgarradosTable, '&lt;', '<'), '&gt;', '>')   
						+ '</table>'
					
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos executando no Banco de Dados <BR />'
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @ResultadoWhoisactiveTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			 
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: O Consumo de CPU está abaixo de ' +  CAST((@CPU_Parametro) AS VARCHAR) + '% no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaCPUAgarradosHeader + @EmptyBodyEmail + @AlertaCPUAgarradosTable + @EmptyBodyEmail +
									@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail
			
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
			
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0		
		END
	END		-- FIM - CLEAR
END

GO

/*

IF ( OBJECT_ID('[dbo].[stpAlerta_MaxSize_Arquivo_SQL]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_MaxSize_Arquivo_SQL]
GO

/*******************************************************************************************************************************
--	ALERTA: MAXSIZE ARQUIVO SQL
*******************************************************************************************************************************/
	
CREATE PROCEDURE [dbo].[stpAlerta_MaxSize_Arquivo_SQL]
AS
BEGIN
	SET NOCOUNT ON

	-- MaxSize Arquivo SQL
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'MaxSize Arquivo SQL')

	-- Cria as tabelas que irão armazenar as informações sobre os arquivos
	IF ( OBJECT_ID('tempdb..##MDFs_Sizes_Alertas') IS NOT NULL )
		DROP TABLE ##MDFs_Sizes_Alertas

	CREATE TABLE ##MDFs_Sizes_Alertas(
		[Server]			VARCHAR(50),
		[Nm_Database]		VARCHAR(100),
		[NomeLogico]		VARCHAR(100),
		[Total_Utilizado]	NUMERIC(15,2),
		[Espaco_Livre (MB)] NUMERIC(15,2),
		[physical_name]		VARCHAR(4000)
	)
	
	IF ( OBJECT_ID('tempdb..#Logs_Sizes') IS NOT NULL )
		DROP TABLE #Logs_Sizes
	
	CREATE TABLE #Logs_Sizes(
		[Server]		VARCHAR(50),
		[Nm_Database]	VARCHAR(100) NOT NULL,
		[Log_Size(KB)]	BIGINT NOT NULL,
		[Log_Used(KB)]	BIGINT NOT NULL,
		[Log_Used(%)]	DECIMAL(22, 2) NULL
	) 
	
	-- Popula os dados
	EXEC sp_MSforeachdb '
		Use [?]
		INSERT INTO ##MDFs_Sizes_Alertas
		SELECT	@@SERVERNAME,
				db_name() AS NomeBase,
				[Name] AS NomeLogico,
				CONVERT(DECIMAL(15,2), ROUND(FILEPROPERTY(a.[Name], ''SpaceUsed'') / 128.000, 2)) AS [Total_Utilizado (MB)], 
				CONVERT(DECIMAL(15,2), ROUND((a.Size-FILEPROPERTY(a.[Name], ''SpaceUsed'')) / 128.000, 2)) AS [Available Space (MB)],
				[Filename] AS physical_name
		FROM [dbo].[sysfiles] a (NOLOCK)
		JOIN [sysfilegroups] b (NOLOCK) ON a.[groupid] = b.[groupid]
		ORDER BY b.[groupname]'	

	-- Busca as informações sobre os arquivos LDF
	INSERT INTO #Logs_Sizes([Server], [Nm_Database], [Log_Size(KB)], [Log_Used(KB)], [Log_Used(%)])
	SELECT	@@SERVERNAME,
			db.[name]									AS [Database Name],
			ls.[cntr_value]								AS [Log Size (KB)] ,
			lu.[cntr_value]								AS [Log Used (KB)] ,
			CAST( CAST(	lu.[cntr_value] AS FLOAT) /	
						CASE WHEN CAST(ls.[cntr_value] AS FLOAT) = 0  
							THEN 1  
							ELSE CAST(ls.[cntr_value] AS FLOAT) 
						END AS DECIMAL(18,2)) * 100		AS [Log Used %]
	FROM [sys].[databases] AS db WITH(NOLOCK)
	JOIN [sys].[dm_os_performance_counters] AS lu WITH(NOLOCK) ON db.[name] = lu.[instance_name]
	JOIN [sys].[dm_os_performance_counters] AS ls WITH(NOLOCK) ON db.[name] = ls.[instance_name]
	WHERE	lu.[counter_name] LIKE 'Log File(s) Used Size (KB)%'
			AND ls.[counter_name] LIKE 'Log File(s) Size (KB)%' 

	-- Cria a tabela com os dados resumidos
	IF ( OBJECT_ID('_Resultado_Alerta_SQLFile') IS NOT NULL )
		DROP TABLE _Resultado_Alerta_SQLFile

	SELECT	@@SERVERNAME					AS [Server],
			DB_NAME(A.[database_id])		AS [Nm_Database],
			[name]							AS Logical_Name,
			CASE WHEN RIGHT(A.[physical_name], 3) = 'mdf' OR RIGHT(A.[physical_name], 3) = 'ndf' 
					THEN B.[Total_Utilizado]
					ELSE (C.[Log_Used(KB)]) / 1024.0
			END								AS [Used(MB)],
			( 
				(	CASE WHEN A.[Max_Size] = -1 
						THEN -1
						ELSE ( A.[Max_Size] / 1024 ) * 8
					END ) - (	CASE WHEN [is_percent_growth] = 1
										THEN ( ( A.[Max_Size] / 1024 ) * 8 ) * ((A.[Growth] / 100.00))
										ELSE CAST(( A.[Growth] * 8 ) / 1024.00 AS NUMERIC(15, 2))
								END ) 
			) * .85 -
			CASE WHEN RIGHT(A.[physical_name], 3) = 'mdf' OR RIGHT(A.[physical_name], 3) = 'ndf' 
					THEN B.[Total_Utilizado]
					ELSE (C.[Log_Used(KB)]) / 1024.0
			END								AS [Alerta],			  
			CASE WHEN A.[name] = 'tempdev' 
					THEN ([Espaco_Livre (MB)] + [Total_Utilizado]) 
					ELSE ([Size] / 1024.0) * 8
			END								AS [Size(MB)],			 
			CASE WHEN RIGHT(A.[physical_name], 3) = 'mdf' OR RIGHT(A.[physical_name], 3) = 'ndf' 
					THEN [Espaco_Livre (MB)]
					ELSE ([Log_Size(KB)] - [Log_Used(KB)]) / 1024.0
			END								AS [Free_Space(MB)],			
			CASE	WHEN A.[name] = 'tempdev'
						THEN ([Espaco_Livre (MB)] / ([Espaco_Livre (MB)] + [Total_Utilizado])) * 100.00
					WHEN RIGHT(A.[physical_name], 3) = 'mdf' OR RIGHT(A.[physical_name], 3) = 'ndf' 
						THEN (([Espaco_Livre (MB)] / ((Size/1024.0) * 8.0))) * 100.0
					ELSE (100.00 - C.[Log_Used(%)])
			END								AS [Free_Space(%)],			
			CASE WHEN A.[Max_Size] = -1 
					THEN -1
					ELSE (A.[Max_Size] / 1024) * 8
			END								AS [MaxSize(MB)],			
			CASE WHEN [is_percent_growth] = 1 
					THEN CAST(A.[Growth] AS VARCHAR) + ' %'
					ELSE CAST (CAST((A.[Growth] * 8) / 1024.00 AS NUMERIC(15, 2)) AS VARCHAR) + ' MB'
			END								AS [Growth]
	INTO [dbo].[_Resultado_Alerta_SQLFile]
	FROM [sys].[master_files] A WITH(NOLOCK) 
	JOIN ##MDFs_Sizes_Alertas B ON A.[physical_name] = B.[physical_name]
	JOIN #Logs_Sizes C ON C.[Nm_Database] = db_name(A.[database_id])
	WHERE   A.[type_desc] <> 'FULLTEXT'
			AND A.[Max_Size] NOT IN ( -1 )
			AND CASE WHEN A.[Max_Size] = -1 THEN -1
					 ELSE ( A.[Max_Size] / 1024 ) * 8
				END <> 2097152
		
	-- Declara as variaveis					
	DECLARE @Subject VARCHAR(500), @Fl_Tipo TINYINT, @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @Maxsize_Parametro INT,
			@AlertaMDFLDFHeader VARCHAR(MAX), @AlertaMDFLDFTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX), @EmailDestination VARCHAR(500),
			@ProfileEmail VARCHAR(200)

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]		
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@Maxsize_Parametro = Vl_Parametro * 1000,		-- Tamanho (MB)
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- MaxSize Arquivo SQL

	/*******************************************************************************************************************************
	--	Verifica se existe algum arquivo MDF ou LDF próximo do MaxSize
	*******************************************************************************************************************************/
	IF EXISTS	(
					SELECT NULL
					FROM [dbo].[_Resultado_Alerta_SQLFile]
					WHERE	(
								CASE WHEN [MaxSize(MB)] >= 150000 
										THEN	CASE WHEN (([MaxSize(MB)] - [Used(MB)]) < @Maxsize_Parametro) 
														THEN 1 
														ELSE 0 
												END
										ELSE	CASE WHEN [Alerta] < 0 
													THEN 1 
													ELSE 0 
												END 
								END
							) = 1
				)
	BEGIN	-- INICIO - ALERTA		
		IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - ALERTA
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaMDFLDFHeader = '<font color=black bold=true size=5>'				            
			SET @AlertaMDFLDFHeader = @AlertaMDFLDFHeader + '<BR /> Informações arquivos .LDF e .MDF com "MaxSize" especificado <BR />' 
			SET @AlertaMDFLDFHeader = @AlertaMDFLDFHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaMDFLDFTable = CAST( (    
				SELECT td =				[Nm_Database]			+ '</td>'
							+ '<td>' +	[Logical_Name]			+ '</td>'
							+ '<td>' +	[Tamanho_Atual (MB)]	+ '</td>'
							+ '<td>' +	[Livre (MB)]			+ '</td>'
							+ '<td>' +	[Utilizado (MB)]		+ '</td>'		
							+ '<td>' +	[MaxSize(MB)]			+ '</td>'
							+ '<td>' +	[Growth]				+ '</td>'
				FROM (  
						-- Dados da Tabela do EMAIL       
						SELECT	DISTINCT 
								[Nm_Database],
								[Logical_Name],
								CAST([Size(MB)] AS VARCHAR)			AS [Tamanho_Atual (MB)],
								CAST([Free_Space(MB)] AS VARCHAR)	AS [Livre (MB)], 
								CAST([Used(MB)] AS VARCHAR)			AS [Utilizado (MB)],
								CAST([MaxSize(MB)] AS VARCHAR)		AS [MaxSize(MB)], 
								[Growth]
						FROM [Traces].[dbo].[_Resultado_Alerta_SQLFile]
						WHERE	(
									CASE WHEN [MaxSize(MB)] >= 150000 
											THEN	CASE WHEN (([MaxSize(MB)] - [Used(MB)]) < 15000) 
															THEN 1 
															ELSE 0 
													END 
									ELSE	CASE WHEN [Alerta] < 0 
													THEN 1 
													ELSE 0 
											END 
									END
								) = 1	
								
					  ) AS D ORDER BY [Livre (MB)] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaMDFLDFTable = REPLACE( REPLACE( REPLACE( @AlertaMDFLDFTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaMDFLDFTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="70"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Nome Lógico</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Tamanho Atual (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Livre (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Utilizado (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>MaxSize (MB)</font></th>  		
							<th bgcolor=#0B0B61 width="100"><font color=white>Crescimento</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaMDFLDFTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>' 
			 
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - ALERTA
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'ALERTA: Existe algum arquivo MDF ou LDF com risco de estouro do Maxsize no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaMDFLDFHeader + @EmptyBodyEmail + @AlertaMDFLDFTable + @EmptyBodyEmail

			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'

			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
			
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 1			
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR			
		IF @Fl_Tipo = 1
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaMDFLDFHeader = '<font color=black bold=true size=5>'				            
			SET @AlertaMDFLDFHeader = @AlertaMDFLDFHeader + '<BR /> Informações arquivos .LDF e .MDF com "MaxSize" especificado <BR />' 
			SET @AlertaMDFLDFHeader = @AlertaMDFLDFHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			-------------------------------------------------------------------------------------------------------------------------------- 
			SET @AlertaMDFLDFTable = CAST( (    
				SELECT td =				[Nm_Database]			+ '</td>'
							+ '<td>' +	[Logical_Name]			+ '</td>'
							+ '<td>' +	[Tamanho_Atual (MB)]	+ '</td>'
							+ '<td>' +	[Livre (MB)]			+ '</td>'
							+ '<td>' +	[Utilizado (MB)]		+ '</td>'		
							+ '<td>' +	[MaxSize(MB)]			+ '</td>'
							+ '<td>' +	[Growth]				+ '</td>'
				FROM (  
						-- Dados da Tabela do EMAIL						
						SELECT	DISTINCT 
								[Nm_Database],
								[Logical_Name],
								CAST([Size(MB)] AS VARCHAR)			AS [Tamanho_Atual (MB)],
								CAST([Free_Space(MB)] AS VARCHAR)	AS [Livre (MB)], 
								CAST([Used(MB)] AS VARCHAR)			AS [Utilizado (MB)],
								CAST([MaxSize(MB)] AS VARCHAR)		AS [MaxSize(MB)], 
								[Growth]
						FROM [Traces].[dbo].[_Resultado_Alerta_SQLFile]
						
				  ) AS D ORDER BY [Utilizado (MB)] DESC
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaMDFLDFTable = REPLACE( REPLACE( REPLACE( @AlertaMDFLDFTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaMDFLDFTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="70"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Nome Lógico</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Tamanho Atual (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Livre (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>Utilizado (MB)</font></th>  
							<th bgcolor=#0B0B61 width="100"><font color=white>MaxSize (MB)</font></th>  		
							<th bgcolor=#0B0B61 width="100"><font color=white>Crescimento</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaMDFLDFTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>'
			 
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/					              
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: Não existe mais algum arquivo MDF ou LDF com risco de estouro do Maxsize no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaMDFLDFHeader + @EmptyBodyEmail + @AlertaMDFLDFTable + @EmptyBodyEmail

			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'

			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance	
					
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0			
		END
	END		-- FIM - CLEAR
END
*/

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Tempdb_Utilizacao_Arquivo_MDF]') IS NOT NULL )
	DROP PROCEDURE [dbo].[stpAlerta_Tempdb_Utilizacao_Arquivo_MDF]
GO

/*******************************************************************************************************************************
--	ALERTA: TEMPDB UTILIZACAO ARQUIVO MDF
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Tempdb_Utilizacao_Arquivo_MDF]
AS
BEGIN
	SET NOCOUNT ON

	-- Tamanho Arquivo MDF Tempdb
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Tempdb Utilizacao Arquivo MDF')

	declare @Tempo_Conexoes_Hs tinyint, @Tempdb_Parametro int, @EmailDestination VARCHAR(500), @Tamanho_Tempdb INT, @ProfileEmail VARCHAR(200)
	
	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@Tempdb_Parametro = Vl_Parametro,				-- Percentual
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Tempdb Utilizacao Arquivo

	-- Conexões mais antigas que 1 hora
	SELECT	@Tempo_Conexoes_Hs = 1,
			@Tamanho_Tempdb = 10000		--	10 GB
				
	-- Declara as variaveis
	DECLARE	@Subject VARCHAR(500), @Fl_Tipo TINYINT, @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @AlertaTamanhoMDFTempdbHeader VARCHAR(MAX), 
			@AlertaTamanhoMDFTempdbTable VARCHAR(MAX), @AlertaTempdbUtilizacaoArquivoHeader VARCHAR(MAX), @AlertaTamanhoMDFTempdbConexoesTable VARCHAR(MAX), 
			@EmptyBodyEmail VARCHAR(MAX), @AlertaTempdbProcessoExecHeader VARCHAR(MAX), @AlertaTempdbProcessoExecTable VARCHAR(MAX), @Dt_Atual DATETIME

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )
	
	-- Busca as informações do Tempdb
	IF ( OBJECT_ID('tempdb..#Alerta_Tamanho_MDF_Tempdb') IS NOT NULL )
		DROP TABLE #Alerta_Tamanho_MDF_Tempdb

	select 
		file_id,
		reserved_MB = CAST((unallocated_extent_page_count+version_store_reserved_page_count+user_object_reserved_page_count +
							internal_object_reserved_page_count+mixed_extent_page_count)*8/1024. AS numeric(15,2)) ,
		unallocated_extent_MB = CAST(unallocated_extent_page_count*8/1024. AS NUMERIC(15,2)),
		internal_object_reserved_MB = CAST(internal_object_reserved_page_count*8/1024. AS NUMERIC(15,2)),
		version_store_reserved_MB = CAST(version_store_reserved_page_count*8/1024. AS NUMERIC(15,2)),
		user_object_reserved_MB = convert(numeric(10,2),round(user_object_reserved_page_count*8/1024.,2))
	into #Alerta_Tamanho_MDF_Tempdb
	from tempdb.sys.dm_db_file_space_usage
	
	IF ( OBJECT_ID('tempdb..#Alerta_Tamanho_MDF_Tempdb_Conexoes') IS NOT NULL )
		DROP TABLE #Alerta_Tamanho_MDF_Tempdb_Conexoes

	-- Busca as transações que estão abertas
	CREATE TABLE #Alerta_Tamanho_MDF_Tempdb_Conexoes(
		[session_id] [smallint] NULL,
		[login_time] [varchar](40) NULL,
		[login_name] [nvarchar](128) NULL,
		[host_name] [nvarchar](128) NULL,
		[open_transaction_Count] [int] NULL,
		[status] [nvarchar](30) NULL,
		[cpu_time] [int] NULL,
		[total_elapsed_time] [int] NULL,
		[reads] [bigint] NULL,
		[writes] [bigint] NULL,
		[logical_reads] [bigint] NULL
	) ON [PRIMARY]

	-- Query Alerta Tempdb - Conexões abertas - Incluir no Alerta TempDb
	INSERT INTO #Alerta_Tamanho_MDF_Tempdb_Conexoes
	SELECT	TOP 50 session_id, convert(varchar(20),login_time,120) AS login_time, login_name, host_name, 
			/*open_transaction_Count,*/ NULL, status, cpu_time, total_elapsed_time, reads, writes, logical_reads	
	FROM sys.dm_exec_sessions
	WHERE	session_id > 50 
			--and open_transaction_Count > 0
			and dateadd(hour,-@Tempo_Conexoes_Hs,getdate()) > login_time
	ORDER BY logical_reads DESC			
			
	-- Tratamento caso não retorne nenhuma conexão
	IF NOT EXISTS (SELECT TOP 1 session_id FROM #Alerta_Tamanho_MDF_Tempdb_Conexoes)
	BEGIN
		INSERT INTO #Alerta_Tamanho_MDF_Tempdb_Conexoes
		VALUES(NULL, 'Sem conexao aberta a mais de 1 hora', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL)
	END
	
	--------------------------------------------------------------------------------------------------------------------------------
	--	Cria Tabela para armazenar os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela que ira armazenar os dados dos processos
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
      
	-- Seta a hora atual
	SELECT @Dt_Atual = GETDATE()

	--------------------------------------------------------------------------------------------------------------------------------
	--	Carrega os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Retorna todos os processos que estão sendo executados no momento
	EXEC [dbo].[sp_whoisactive]
			@get_outer_command =	1,
			@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
			@destination_table =	'#Resultado_WhoisActive'
				    
	-- Altera a coluna que possui o comando SQL
	ALTER TABLE #Resultado_WhoisActive
	ALTER COLUMN [sql_command] VARCHAR(MAX)
	
	UPDATE #Resultado_WhoisActive
	SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
	
	-- select * from #Resultado_WhoisActive
	
	-- Verifica se não existe nenhum processo em Execução
	IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
	BEGIN
		INSERT INTO #Resultado_WhoisActive
		SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END
	
	/*******************************************************************************************************************************
	--	Verifica se o Consumo do Arquivo do Tempdb está muito grande
	*******************************************************************************************************************************/
	IF EXISTS	(
					select TOP 1 unallocated_extent_MB 
					from #Alerta_Tamanho_MDF_Tempdb
					where	reserved_MB > @Tamanho_Tempdb 
							and unallocated_extent_MB < reserved_MB * (1 - (@Tempdb_Parametro / 100.0))
				)

	BEGIN	-- INICIO - ALERTA				
		IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - ALERTA - TAMANHO ARQUIVO MDF TEMPDB
			*******************************************************************************************************************************/
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTamanhoMDFTempdbHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaTamanhoMDFTempdbHeader = @AlertaTamanhoMDFTempdbHeader + '<BR /> Tamanho Arquivo MDF Tempdb <BR />' 
			SET @AlertaTamanhoMDFTempdbHeader = @AlertaTamanhoMDFTempdbHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTamanhoMDFTempdbTable = CAST( (    
				SELECT td =				CAST(file_id AS VARCHAR)						+ '</td>'
							+ '<td>' +  CAST(reserved_MB AS VARCHAR)					+ '</td>'
							+ '<td>' +  CAST(Pr_Utilizado AS VARCHAR)					+ '</td>'	
							+ '<td>' +  CAST(unallocated_extent_MB AS VARCHAR)			+ '</td>'
							+ '<td>' +  CAST(internal_object_reserved_MB AS VARCHAR)	+ '</td>'
							+ '<td>' +  CAST(version_store_reserved_MB AS VARCHAR)		+ '</td>'
							+ '<td>' +  CAST(user_object_reserved_MB AS VARCHAR)		+ '</td>'
				FROM (  
						-- Dados da Tabela do EMAIL
						select	file_id, 
								reserved_MB,
								CAST( ((1 - (unallocated_extent_MB / reserved_MB)) * 100) AS NUMERIC(15,2)) AS Pr_Utilizado,
								unallocated_extent_MB,
								internal_object_reserved_MB,
								version_store_reserved_MB,
								user_object_reserved_MB 
						from #Alerta_Tamanho_MDF_Tempdb
						
					  ) AS D 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)
						      
			-- Corrige a Formatação da Tabela
			SET @AlertaTamanhoMDFTempdbTable = REPLACE( REPLACE( REPLACE( @AlertaTamanhoMDFTempdbTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaTamanhoMDFTempdbTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="200"><font color=white>File ID</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Reservado (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Percentual Utilizado (%)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Não Alocado (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Objetos Internos (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Version Store (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Objetos de Usuário (MB)</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaTamanhoMDFTempdbTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'					
			      
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - ALERTA - CONEXOES COM TRANSACAO ABERTA
			*******************************************************************************************************************************/
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTempdbUtilizacaoArquivoHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaTempdbUtilizacaoArquivoHeader = @AlertaTempdbUtilizacaoArquivoHeader + '<BR /> TOP 50 - Conexões com Transação Aberta <BR />' 
			SET @AlertaTempdbUtilizacaoArquivoHeader = @AlertaTempdbUtilizacaoArquivoHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTamanhoMDFTempdbConexoesTable = CAST( (    
				SELECT td =				session_id				+ '</td>'					 
							+ '<td>' +  login_time				+ '</td>'
							+ '<td>' +  login_name				+ '</td>'
							+ '<td>' +  host_name				+ '</td>'
							+ '<td>' +  open_transaction_Count	+ '</td>'
							+ '<td>' +	status					+ '</td>'
							+ '<td>' +  cpu_time				+ '</td>'
							+ '<td>' +  total_elapsed_time		+ '</td>'
							+ '<td>' +  reads 					+ '</td>'
							+ '<td>' +  writes 					+ '</td>'
							+ '<td>' +  logical_reads			+ '</td>'
				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL(CAST(session_id AS VARCHAR), '-') AS session_id, 
								ISNULL(login_time, '-') AS login_time, 
								ISNULL(login_name, '-') AS login_name,
								ISNULL(host_name, '-') AS host_name,
								ISNULL(CAST(open_transaction_Count AS VARCHAR),'-') AS open_transaction_Count, 
								ISNULL(status, '-') AS status, 
								ISNULL(CAST(cpu_time AS VARCHAR),'-') AS cpu_time, 
								ISNULL(CAST(total_elapsed_time AS VARCHAR),'-') AS total_elapsed_time, 
								ISNULL(CAST(reads AS VARCHAR),'-') AS reads, 
								ISNULL(CAST(writes AS VARCHAR),'-') AS writes, 
								ISNULL(CAST(logical_reads AS VARCHAR),'-') AS logical_reads
						FROM #Alerta_Tamanho_MDF_Tempdb_Conexoes
						 						
					  ) AS D ORDER BY CAST(REPLACE([logical_reads], '-', 0) AS BIGINT) DESC
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaTamanhoMDFTempdbConexoesTable = REPLACE( REPLACE( REPLACE( @AlertaTamanhoMDFTempdbConexoesTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaTamanhoMDFTempdbConexoesTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="100"><font color=white>session_id</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>login_time</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>login_name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>host_name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>open_transaction_Count</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>status</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>cpu_time</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>total_elapsed_time</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>reads</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>writes</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>logical_reads</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaTamanhoMDFTempdbConexoesTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTempdbProcessoExecHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaTempdbProcessoExecHeader = @AlertaTempdbProcessoExecHeader + '<BR /> TOP 50 - Processos executando no Banco de Dados <BR />'
			SET @AlertaTempdbProcessoExecHeader = @AlertaTempdbProcessoExecHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTempdbProcessoExecTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
						ORDER BY [start_time]

					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaTempdbProcessoExecTable = REPLACE( REPLACE( REPLACE( @AlertaTempdbProcessoExecTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaTempdbProcessoExecTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaTempdbProcessoExecTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'

			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/			              
			SELECT	@Importance =	'High',
					@Subject =		'ALERTA: O Tamanho do Arquivo MDF do Tempdb está acima de 70% no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaTamanhoMDFTempdbHeader + @EmptyBodyEmail + @AlertaTamanhoMDFTempdbTable + @EmptyBodyEmail +
									@AlertaTempdbUtilizacaoArquivoHeader + @EmptyBodyEmail + @AlertaTamanhoMDFTempdbConexoesTable + @EmptyBodyEmail +
									@AlertaTempdbProcessoExecHeader + @EmptyBodyEmail + @AlertaTempdbProcessoExecTable + @EmptyBodyEmail
			
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
			
			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - ALERTA
			*******************************************************************************************************************************/	
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
					
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 1			
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR		
		IF @Fl_Tipo = 1
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR - TAMANHO ARQUIVO MDF TEMPDB
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTamanhoMDFTempdbHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaTamanhoMDFTempdbHeader = @AlertaTamanhoMDFTempdbHeader + '<BR /> Tamanho Arquivo MDF Tempdb <BR />' 
			SET @AlertaTamanhoMDFTempdbHeader = @AlertaTamanhoMDFTempdbHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			-------------------------------------------------------------------------------------------------------------------------------- 
			SET @AlertaTamanhoMDFTempdbTable = CAST( (    
				SELECT td =				CAST(file_id AS VARCHAR)						+ '</td>'
							+ '<td>' +  CAST(reserved_MB AS VARCHAR)					+ '</td>'
							+ '<td>' +  CAST(Pr_Utilizado AS VARCHAR)					+ '</td>'					 
							+ '<td>' +  CAST(unallocated_extent_MB AS VARCHAR)			+ '</td>'
							+ '<td>' +  CAST(internal_object_reserved_MB AS VARCHAR)	+ '</td>'
							+ '<td>' +  CAST(version_store_reserved_MB AS VARCHAR)		+ '</td>'
							+ '<td>' +  CAST(user_object_reserved_MB AS VARCHAR)		+ '</td>'
				FROM (  
						-- Dados da Tabela do EMAIL
						select	file_id,
								reserved_MB,
								CAST( ((1 - (unallocated_extent_MB / reserved_MB)) * 100) AS NUMERIC(15,2)) AS Pr_Utilizado,
								unallocated_extent_MB,
								internal_object_reserved_MB,
								version_store_reserved_MB,
								user_object_reserved_MB 
						from #Alerta_Tamanho_MDF_Tempdb
						
					  ) AS D 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaTamanhoMDFTempdbTable = REPLACE( REPLACE( REPLACE( @AlertaTamanhoMDFTempdbTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaTamanhoMDFTempdbTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="200"><font color=white>File ID</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Reservado (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Percentual Utilizado (%)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Não Alocado (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Objetos Internos (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Version Store (MB)</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Espaço Objetos de Usuário (MB)</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaTamanhoMDFTempdbTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			 
			 /*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR - CONEXOES COM TRANSACAO ABERTA
			*******************************************************************************************************************************/
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTempdbUtilizacaoArquivoHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaTempdbUtilizacaoArquivoHeader = @AlertaTempdbUtilizacaoArquivoHeader + '<BR /> TOP 50 - Conexões com Transação Aberta <BR />' 
			SET @AlertaTempdbUtilizacaoArquivoHeader = @AlertaTempdbUtilizacaoArquivoHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTamanhoMDFTempdbConexoesTable = CAST( (    
				SELECT td =				session_id				+ '</td>'					 
							+ '<td>' +  login_time				+ '</td>'
							+ '<td>' +  login_name				+ '</td>'
							+ '<td>' +  host_name				+ '</td>'
							+ '<td>' +  open_transaction_Count	+ '</td>'
							+ '<td>' +	status					+ '</td>'
							+ '<td>' +  cpu_time				+ '</td>'
							+ '<td>' +  total_elapsed_time		+ '</td>'
							+ '<td>' +  reads 					+ '</td>'
							+ '<td>' +  writes 					+ '</td>'
							+ '<td>' +  logical_reads			+ '</td>'
				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	ISNULL(CAST(session_id AS VARCHAR), '-') AS session_id, 
								ISNULL(login_time, '-') AS login_time, 
								ISNULL(login_name, '-') AS login_name,
								ISNULL(host_name, '-') AS host_name,
								ISNULL(CAST(open_transaction_Count AS VARCHAR),'-') AS open_transaction_Count, 
								ISNULL(status, '-') AS status, 
								ISNULL(CAST(cpu_time AS VARCHAR),'-') AS cpu_time, 
								ISNULL(CAST(total_elapsed_time AS VARCHAR),'-') AS total_elapsed_time, 
								ISNULL(CAST(reads AS VARCHAR),'-') AS reads, 
								ISNULL(CAST(writes AS VARCHAR),'-') AS writes, 
								ISNULL(CAST(logical_reads AS VARCHAR),'-') AS logical_reads
						FROM #Alerta_Tamanho_MDF_Tempdb_Conexoes
						
					  ) AS D ORDER BY CAST(REPLACE([logical_reads], '-', 0) AS BIGINT) DESC
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaTamanhoMDFTempdbConexoesTable = REPLACE( REPLACE( REPLACE( @AlertaTamanhoMDFTempdbConexoesTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaTamanhoMDFTempdbConexoesTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="100"><font color=white>session_id</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>login_time</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>login_name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>host_name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>open_transaction_Count</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>status</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>cpu_time</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>total_elapsed_time</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>reads</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>writes</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>logical_reads</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaTamanhoMDFTempdbConexoesTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTempdbProcessoExecHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaTempdbProcessoExecHeader = @AlertaTempdbProcessoExecHeader + '<BR /> TOP 50 - Processos executando no Banco de Dados <BR />'
			SET @AlertaTempdbProcessoExecHeader = @AlertaTempdbProcessoExecHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaTempdbProcessoExecTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
						ORDER BY [start_time]

					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaTempdbProcessoExecTable = REPLACE( REPLACE( REPLACE( @AlertaTempdbProcessoExecTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaTempdbProcessoExecTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaTempdbProcessoExecTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'

			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: O Tamanho do Arquivo MDF do Tempdb está abaixo de 70% no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaTamanhoMDFTempdbHeader + @EmptyBodyEmail + @AlertaTamanhoMDFTempdbTable + @EmptyBodyEmail +
									@AlertaTempdbUtilizacaoArquivoHeader + @EmptyBodyEmail + @AlertaTamanhoMDFTempdbConexoesTable + @EmptyBodyEmail+
									@AlertaTempdbProcessoExecHeader + @EmptyBodyEmail + @AlertaTempdbProcessoExecTable + @EmptyBodyEmail
			
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
			
			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
			
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0		
		END
	END		-- FIM - CLEAR
END
GO

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Conexao_SQLServer]') IS NOT NULL )
	DROP PROCEDURE [dbo].[stpAlerta_Conexao_SQLServer]
GO

/*******************************************************************************************************************************
--	ALERTA: CONEXAO SQL SERVER
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Conexao_SQLServer]
AS
BEGIN
	SET NOCOUNT ON

	-- Conexões SQL Server
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Conexão SQL Server')

	-- Declara as variaveis
	DECLARE @Dt_Atual DATETIME, @EmailBody VARCHAR(MAX), @AlertaConexaoSQLServerHeader VARCHAR(MAX), @AlertaConexaoSQLServerTable VARCHAR(MAX), 
			@EmptyBodyEmail VARCHAR(MAX), @Importance AS VARCHAR(6), @Subject VARCHAR(500), @Qtd_Conexoes INT, @Conexoes_SQLServer_Parametro INT, 
			@Fl_Tipo INT, @EmailDestination VARCHAR(500), @AlertaConexaoProcessosExecHeader VARCHAR(MAX), @AlertaConexaoProcessosExecTable VARCHAR(MAX),
			@ProfileEmail VARCHAR(200)

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@Conexoes_SQLServer_Parametro = Vl_Parametro,	-- Quantidade
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Conexões SQL Server

	SELECT @Qtd_Conexoes = count(*) FROM sys.dm_exec_sessions WHERE session_id > 50

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )

	--------------------------------------------------------------------------------------------------------------------------------
	--	Cria Tabela para armazenar os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela que ira armazenar os dados dos processos
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
      
	-- Seta a hora atual
	SELECT @Dt_Atual = GETDATE()

	--------------------------------------------------------------------------------------------------------------------------------
	--	Carrega os Dados da sp_whoisactive
	--------------------------------------------------------------------------------------------------------------------------------
	-- Retorna todos os processos que estão sendo executados no momento
	EXEC [dbo].[sp_whoisactive]
			@get_outer_command =	1,
			@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
			@destination_table =	'#Resultado_WhoisActive'
				    
	-- Altera a coluna que possui o comando SQL
	ALTER TABLE #Resultado_WhoisActive
	ALTER COLUMN [sql_command] VARCHAR(MAX)
	
	UPDATE #Resultado_WhoisActive
	SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
	
	-- select * from #Resultado_WhoisActive
	
	-- Verifica se não existe nenhum processo em Execução
	IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
	BEGIN
		INSERT INTO #Resultado_WhoisActive
		SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END
	
	/*******************************************************************************************************************************
	--	Verifica se o limite de conexões para o Alerta foi atingido
	*******************************************************************************************************************************/
	IF (@Qtd_Conexoes > @Conexoes_SQLServer_Parametro)
	BEGIN	-- INICIO - ALERTA		
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
					
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - CONEXÕES - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaConexaoSQLServerHeader = '<font color=black bold=true size=5>'				            
		SET @AlertaConexaoSQLServerHeader = @AlertaConexaoSQLServerHeader + '<BR /> TOP 25 - Conexões Abertas no SQL Server <BR />' 
		SET @AlertaConexaoSQLServerHeader = @AlertaConexaoSQLServerHeader + '</font>'
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - CONEXÕES - BODY 
		--------------------------------------------------------------------------------------------------------------------------------
		if object_id('tempdb..#ConexoesAbertas') is not null
			drop table #ConexoesAbertas

		SELECT	TOP 25 IDENTITY(INT, 1, 1) AS id, 
				replace(replace(ec.client_net_address,'<',''),'>','') client_net_address, 
				case when es.[program_name] = '' then 'Sem nome na string de conexão' else [program_name] end [program_name], 
				es.[host_name], es.login_name, /*db_name(database_id)*/ '' Base,
				COUNT(ec.session_id)  AS [connection count] 
		into #ConexoesAbertas
		FROM sys.dm_exec_sessions AS es  
		INNER JOIN sys.dm_exec_connections AS ec ON es.session_id = ec.session_id   
		GROUP BY ec.client_net_address, es.[program_name], es.[host_name],/*db_name(database_id),*/ es.login_name  			
		order by [connection count] desc
				
		SET @AlertaConexaoSQLServerTable = CAST( (    
			SELECT td =		client_net_address	+ '</td>' 
				+ '<td>' +  [program_name]		+ '</td>'
				+ '<td>' +  [host_name]			+ '</td>'
				+ '<td>' +  login_name			+ '</td>'
				+ '<td>' +  Base				+ '</td>'
				+ '<td>' +  [connection count] 	+ '</td>'			

			FROM (
					SELECT	client_net_address, 
							[program_name], 
							[host_name], login_name, Base,
							cast([connection count] as varchar) [connection count] ,id
					FROM #ConexoesAbertas 		
					
					) AS D ORDER BY id 
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
		)
		
		-- Corrige a Formatação da Tabela
		SET @AlertaConexaoSQLServerTable = REPLACE( REPLACE( REPLACE( @AlertaConexaoSQLServerTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
		
		-- Títulos da Tabela do EMAIL
		SET @AlertaConexaoSQLServerTable = 
				'<table cellspacing="2" cellpadding="5" border="3">'
				+	'<tr>
						<th bgcolor=#0B0B61 width="50"><font color=white>IP</font></th>
						<th bgcolor=#0B0B61 width="50"><font color=white>Aplicacao</font></th>
						<th bgcolor=#0B0B61 width="50"><font color=white>Hostname</font></th>
						<th bgcolor=#0B0B61 width="50"><font color=white>Login</font></th>
						<th bgcolor=#0B0B61 width="50"><font color=white>Database</font></th>
						<th bgcolor=#0B0B61 width="10"><font color=white>Qtd. Conexões</font></th>
					</tr>'    
				+ REPLACE( REPLACE( @AlertaConexaoSQLServerTable, '&lt;', '<'), '&gt;', '>')
				+ '</table>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaConexaoProcessosExecHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaConexaoProcessosExecHeader = @AlertaConexaoProcessosExecHeader + '<BR /> TOP 50 - Processos executando no Banco de Dados <BR />'
			SET @AlertaConexaoProcessosExecHeader = @AlertaConexaoProcessosExecHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaConexaoProcessosExecTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
						ORDER BY [start_time]

					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaConexaoProcessosExecTable = REPLACE( REPLACE( REPLACE( @AlertaConexaoProcessosExecTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaConexaoProcessosExecTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaConexaoProcessosExecTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			              
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'
				
		
		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Existem ' + cast(@Qtd_Conexoes as varchar) + ' Conexões Abertas no SQL Server no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@AlertaConexaoSQLServerHeader + @EmptyBodyEmail + @AlertaConexaoSQLServerTable + @EmptyBodyEmail + 
								@AlertaConexaoProcessosExecHeader + @EmptyBodyEmail + @AlertaConexaoProcessosExecTable + @EmptyBodyEmail
				
		/*******************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		*******************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'
		
		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients = @EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

   		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/		
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR		
		IF @Fl_Tipo = 1
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR
			*******************************************************************************************************************************/
					
			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaConexaoSQLServerHeader = '<font color=black bold=true size=5>'				            
			SET @AlertaConexaoSQLServerHeader = @AlertaConexaoSQLServerHeader + '<BR /> Conexões abertas no SQL Server <BR />' 
			SET @AlertaConexaoSQLServerHeader = @AlertaConexaoSQLServerHeader + '</font>'
		
			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY 
			--------------------------------------------------------------------------------------------------------------------------------		

			if object_id('tempdb..#ConexoesAbertas_Clear') is not null
				drop table #ConexoesAbertas_Clear

			SELECT	top 25 IDENTITY(INT, 1, 1) AS id, 
					replace(replace(ec.client_net_address,'<',''),'>','') client_net_address, 
					case when es.[program_name] = '' then 'Sem nome na string de conexão' else [program_name] end [program_name], 
					es.[host_name], es.login_name, /*db_name(database_id)*/ '' Base,
					COUNT(ec.session_id)  AS [connection count] 
			into #ConexoesAbertas_Clear
			FROM sys.dm_exec_sessions AS es  
			INNER JOIN sys.dm_exec_connections AS ec  
			ON es.session_id = ec.session_id   
			GROUP BY ec.client_net_address, es.[program_name], es.[host_name],/*db_name(database_id),*/ es.login_name  			
			order by [connection count] desc
		
			SET @AlertaConexaoSQLServerTable = CAST( (    
				SELECT td =  client_net_address + '</td>' 
				+ '<td>' +  [program_name]			+ '</td>'
				+ '<td>' +  [host_name]			+ '</td>'
				+ '<td>' +  login_name			+ '</td>'
				+ '<td>' +  Base			+ '</td>'
				+ '<td>' +  [connection count] 			+ '</td>'			

				FROM (
						SELECT client_net_address, 
						[program_name], 
						[host_name], login_name, Base,
						cast([connection count] as varchar) [connection count] ,id
						FROM #ConexoesAbertas_Clear 		
					
					  ) AS D ORDER BY id 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)  
		
			-- Corrige a Formatação da Tabela
			SET @AlertaConexaoSQLServerTable = REPLACE( REPLACE( REPLACE( @AlertaConexaoSQLServerTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
		
			-- Títulos da Tabela do EMAIL
			SET @AlertaConexaoSQLServerTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'
					+	'<tr>
							<th bgcolor=#0B0B61 width="50"><font color=white>IP</font></th>
							<th bgcolor=#0B0B61 width="50"><font color=white>Aplicacao</font></th>
							<th bgcolor=#0B0B61 width="50"><font color=white>Hostname</font></th>
							<th bgcolor=#0B0B61 width="50"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="50"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="10"><font color=white>Qtd. Conexões</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaConexaoSQLServerTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>'
			
			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaConexaoProcessosExecHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaConexaoProcessosExecHeader = @AlertaConexaoProcessosExecHeader + '<BR /> TOP 50 - Processos executando no Banco de Dados <BR />'
			SET @AlertaConexaoProcessosExecHeader = @AlertaConexaoProcessosExecHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaConexaoProcessosExecTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
						ORDER BY [start_time]

					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaConexaoProcessosExecTable = REPLACE( REPLACE( REPLACE( @AlertaConexaoProcessosExecTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @AlertaConexaoProcessosExecTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="300"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @AlertaConexaoProcessosExecTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'
			              
		
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'
		
			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: Existem ' + cast(@Qtd_Conexoes as varchar) + ' Conexões Abertas no SQL Server no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaConexaoSQLServerHeader + @EmptyBodyEmail + @AlertaConexaoSQLServerTable + @EmptyBodyEmail+ 
									@AlertaConexaoProcessosExecHeader + @EmptyBodyEmail + @AlertaConexaoProcessosExecTable + @EmptyBodyEmail
				
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'
		
			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients = @EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance

   			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/		
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0		
		END
	END		-- FIM - CLEAR
END

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Erro_Banco_Dados]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Erro_Banco_Dados]
GO

/*******************************************************************************************************************************
--	ALERTA: ERRO BANCO DE DADOS
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Erro_Banco_Dados]
AS
BEGIN
	SET NOCOUNT ON

	-- Declara as variaveis
	DECLARE @Subject VARCHAR(500), @Fl_Tipo TINYINT, @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
			@AlertaPaginaCorrompidaHeader VARCHAR(MAX), @AlertaPaginaCorrompidaTable VARCHAR(MAX), @EmailDestination VARCHAR(500),
			@AlertaStatusDatabasesHeader VARCHAR(MAX), @AlertaStatusDatabasesTable VARCHAR(MAX), @ProfileEmail VARCHAR(200)		
	
	-- Página Corrompida
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Página Corrompida')

	/*******************************************************************************************************************************
	--	ALERTA: PAGINA CORROMPIDA
	*******************************************************************************************************************************/
	IF(OBJECT_ID('temp..#temp_Corrupcao_Pagina') IS NOT NULL) DROP TABLE #temp_Corrupcao_Pagina

	SELECT SP.*
	INTO #temp_Corrupcao_Pagina
	FROM [msdb].[dbo].[suspect_pages] SP
	LEFT JOIN [dbo].[Historico_Suspect_Pages] HSP ON	SP.database_id = HSP.database_id AND SP.file_id = HSP.file_id
														AND SP.[page_id] = HSP.[page_id]
														AND CAST(SP.last_update_date AS DATE) = CAST(HSP.Dt_Corrupcao AS DATE)
	WHERE 	HSP.[page_id] IS NULL

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	-- Status Database
	SELECT @Id_Alerta_Parametro = 8	-- SELECT * FROM [Traces].[dbo].Alerta_Parametro
	
	SELECT	@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Página Corrompida

	/*******************************************************************************************************************************
	-- Verifica se existe alguma Página Corrompida
	*******************************************************************************************************************************/
	IF EXISTS (SELECT TOP 1 page_id FROM #temp_Corrupcao_Pagina) 
	BEGIN	-- INICIO - ALERTA	
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/			

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaPaginaCorrompidaHeader = '<font color=black bold=true size=5>'			            
		SET @AlertaPaginaCorrompidaHeader = @AlertaPaginaCorrompidaHeader + '<BR /> Páginas Corrompidas <BR />' 
		SET @AlertaPaginaCorrompidaHeader = @AlertaPaginaCorrompidaHeader + '</font>'

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaPaginaCorrompidaTable = CAST( (    
			SELECT td =				Nm_Database			+ '</td>'
						+ '<td>' +	file_id				+ '</td>'
						+ '<td>' +	page_id				+ '</td>'
						+ '<td>' +	event_type			+ '</td>'
						+ '<td>' +	error_count			+ '</td>'
						+ '<td>' +	last_update_date	+ '</td>'

			FROM (
					-- Dados da Tabela do EMAIL
					SELECT	B.name AS Nm_Database, 
							CAST(file_id AS VARCHAR) AS file_id, 
							CAST(page_id AS VARCHAR) AS page_id, 
							CAST(event_type AS VARCHAR) AS event_type, 
							CAST(error_count AS VARCHAR) AS error_count,								
							CONVERT(VARCHAR(20), last_update_date, 120) AS last_update_date
					FROM #temp_Corrupcao_Pagina A
					JOIN [sys].[databases] B ON B.[database_id] = A.[database_id]
					
			) AS D
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
		)   
			      
		-- Corrige a Formatação da Tabela
		SET @AlertaPaginaCorrompidaTable = REPLACE( REPLACE( REPLACE( @AlertaPaginaCorrompidaTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
		-- Títulos da Tabela do EMAIL
		SET @AlertaPaginaCorrompidaTable = 
				'<table cellspacing="2" cellpadding="5" border="3">'    
				+	'<tr>
						<th bgcolor=#0B0B61 width="300"><font color=white>Nome Database</font></th>
						<th bgcolor=#0B0B61 width="150"><font color=white>File_Id</font></th>
						<th bgcolor=#0B0B61 width="150"><font color=white>Page_Id</font></th>
						<th bgcolor=#0B0B61 width="150"><font color=white>Event_Type</font></th>
						<th bgcolor=#0B0B61 width="150"><font color=white>Error_Count</font></th>
						<th bgcolor=#0B0B61 width="180"><font color=white>Last_Update_Date</font></th>
					</tr>'    
				+ REPLACE( REPLACE( @AlertaPaginaCorrompidaTable, '&lt;', '<'), '&gt;', '>')
				+ '</table>' 
			
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'

		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Existe alguma Página Corrompida no Banco de Dados no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@AlertaPaginaCorrompidaHeader + @EmptyBodyEmail + @AlertaPaginaCorrompidaTable + @EmptyBodyEmail 
		
		/*******************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		*******************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'	

		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas
		*******************************************************************************************************************************/
		INSERT INTO [dbo].[Historico_Suspect_Pages]
		SELECT	[database_id] ,
				[file_id] ,
				[page_id] ,
				[event_type] ,
				[last_update_date]
		FROM #temp_Corrupcao_Pagina

		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1	
	END		-- FIM - ALERTA
			

	/*******************************************************************************************************************************
	--	ALERTA: DATABASE INDISPONIVEL
	*******************************************************************************************************************************/	
	-- Status Database
	SELECT @Id_Alerta_Parametro = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Status Database')
	
	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	SELECT	@EmailDestination = Ds_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Status Database

	-- Verifica o último Tipo do Alerta registrado -> 0: CLEAR / 1: ALERTA
	SELECT @Fl_Tipo = [Fl_Tipo]
	FROM [dbo].[Alerta]		
	WHERE [Id_Alerta] = (SELECT MAX(Id_Alerta) FROM [dbo].[Alerta] WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro )
	
	/*******************************************************************************************************************************
	-- Verifica se alguma Database não está ONLINE
	*******************************************************************************************************************************/ 
	IF EXISTS	(
					SELECT NULL
					FROM [sys].[databases]
					WHERE [state_desc] NOT IN ('ONLINE','RESTORING')
				)
	BEGIN	-- INICIO - ALERTA		
		IF ISNULL(@Fl_Tipo, 0) = 0	-- Envia o Alerta apenas uma vez
		BEGIN			
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - ALERTA
			*******************************************************************************************************************************/

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaStatusDatabasesHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaStatusDatabasesHeader = @AlertaStatusDatabasesHeader + '<BR /> Status das Databases <BR />' 
			SET @AlertaStatusDatabasesHeader = @AlertaStatusDatabasesHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaStatusDatabasesTable = CAST( (    
				SELECT td =				[name]			+ '</td>'
							+ '<td>' +	[state_desc]	+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL  
						SELECT [name], [state_desc]
						FROM [sys].[databases]
						WHERE [state_desc] NOT IN ('ONLINE','RESTORING')
						
					  ) AS D ORDER BY [name]
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaStatusDatabasesTable = REPLACE( REPLACE( REPLACE( @AlertaStatusDatabasesTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaStatusDatabasesTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="200"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Status</font></th>        
						</tr>'    
					+ REPLACE( REPLACE( @AlertaStatusDatabasesTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>' 
			             
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'ALERTA: Existe alguma Database que não está ONLINE no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaStatusDatabasesHeader + @EmptyBodyEmail + @AlertaStatusDatabasesTable + @EmptyBodyEmail
			
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'	

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - ALERTA
			*******************************************************************************************************************************/
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
					
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 1			
		END
	END		-- FIM - ALERTA
	ELSE 
	BEGIN	-- INICIO - CLEAR			
		IF ISNULL(@Fl_Tipo, 0) = 1
		BEGIN
			/*******************************************************************************************************************************
			--	CRIA O EMAIL - CLEAR
			*******************************************************************************************************************************/			

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - HEADER
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaStatusDatabasesHeader = '<font color=black bold=true size=5>'			            
			SET @AlertaStatusDatabasesHeader = @AlertaStatusDatabasesHeader + '<BR /> Status das Databases <BR />' 
			SET @AlertaStatusDatabasesHeader = @AlertaStatusDatabasesHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	CLEAR - BODY
			--------------------------------------------------------------------------------------------------------------------------------
			SET @AlertaStatusDatabasesTable = CAST( (    
				SELECT td =				[name]			+ '</td>'
							+ '<td>' +	[state_desc]	+ '</td>'

				FROM (
						-- Dados da Tabela do EMAIL
						SELECT [name], [state_desc]
						FROM [sys].[databases]
					
				) AS D ORDER BY [name]
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
			)   
			      
			-- Corrige a Formatação da Tabela
			SET @AlertaStatusDatabasesTable = REPLACE( REPLACE( REPLACE( @AlertaStatusDatabasesTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
			-- Títulos da Tabela do EMAIL
			SET @AlertaStatusDatabasesTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="200"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Status</font></th>        
						</tr>'    
					+ REPLACE( REPLACE( @AlertaStatusDatabasesTable, '&lt;', '<'), '&gt;', '>')
					+ '</table>' 
			
			--------------------------------------------------------------------------------------------------------------------------------
			-- Insere um Espaço em Branco no EMAIL
			--------------------------------------------------------------------------------------------------------------------------------
			SET @EmptyBodyEmail =	''
			SET @EmptyBodyEmail =
					'<table cellpadding="5" cellspacing="5" border="0">' +
						'<tr>
							<th width="500">               </th>
						</tr>'
						+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
					+ '</table>'

			/*******************************************************************************************************************************
			--	Seta as Variáveis do EMAIL
			*******************************************************************************************************************************/
			SELECT	@Importance =	'High',
					@Subject =		'CLEAR: Não existe mais alguma Database que não está ONLINE no Servidor: ' + @@SERVERNAME,
					@EmailBody =	@AlertaStatusDatabasesHeader + @EmptyBodyEmail + @AlertaStatusDatabasesTable + @EmptyBodyEmail 
			
			/*******************************************************************************************************************************
			-- Inclui uma imagem com link para o site do Fabricio Lima
			*******************************************************************************************************************************/
			select @EmailBody = @EmailBody + '<br/><br/>' +
						'<a href="http://www.fabriciolima.net" target=”_blank”> 
							<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
									height="100" width="400"/>
						</a>'	

			/*******************************************************************************************************************************
			--	ENVIA O EMAIL - CLEAR
			*******************************************************************************************************************************/
			EXEC [msdb].[dbo].[sp_send_dbmail]
					@profile_name = @ProfileEmail,
					@recipients =	@EmailDestination,
					@subject =		@Subject,
					@body =			@EmailBody,
					@body_format =	'HTML',
					@importance =	@Importance
						
			/*******************************************************************************************************************************
			-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 0 : CLEAR
			*******************************************************************************************************************************/
			INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
			SELECT @Id_Alerta_Parametro, @Subject, 0
		END
	END		-- FIM - CLEAR
END


GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Queries_Demoradas]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Queries_Demoradas]
GO

/*******************************************************************************************************************************
--	ALERTA: QUERIES DEMORADAS
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Queries_Demoradas]
AS
BEGIN
	SET NOCOUNT ON

	-- Queries Demoradas
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Queries Demoradas')

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Queries_Demoradas_Parametro INT, @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	SELECT	@Queries_Demoradas_Parametro = Vl_Parametro,	-- Quantidade
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Queries Demoradas

	-- Cria a tabela com as queries demoradas
	IF ( OBJECT_ID('tempdb..#Queries_Demoradas_Temp') IS NOT NULL )
		DROP TABLE #Queries_Demoradas_Temp

	SELECT	[StartTime], 
			[DataBaseName], 
			[Duration],
			[Reads],
			[Writes],
			[CPU],
			[TextData]
	INTO #Queries_Demoradas_Temp
	FROM [dbo].[Traces]
	WHERE [StartTime] >= DATEADD(mi, -5, GETDATE())
	ORDER BY [Duration] DESC

	-- Declara a variavel e retorna a quantidade de Queries Lentas
	DECLARE @Quantidade_Queries_Demoradas INT = ( SELECT COUNT(*) FROM #Queries_Demoradas_Temp ) 
	
	/*******************************************************************************************************************************
	--	Verifica se existem mais de 100 Queries Lentas nos últimos 5 minutos
	*******************************************************************************************************************************/
	IF (@Quantidade_Queries_Demoradas > @Queries_Demoradas_Parametro)
	BEGIN
		-- Cria a tabela que ira armazenar os dados dos processos
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

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - DADOS - WHOISACTIVE
		--------------------------------------------------------------------------------------------------------------------------------
		-- Retorna todos os processos que estão sendo executados no momento
		EXEC [dbo].[sp_whoisactive]
				@get_outer_command =	1,
				@output_column_list =	'[dd hh:mm:ss.mss][database_name][login_name][host_name][start_time][status][session_id][blocking_session_id][wait_info][open_tran_count][CPU][reads][writes][sql_command]',
				@destination_table =	'#Resultado_WhoisActive'
						    
		-- Altera a coluna que possui o comando SQL
		ALTER TABLE #Resultado_WhoisActive
		ALTER COLUMN [sql_command] VARCHAR(MAX)
			
		UPDATE #Resultado_WhoisActive
		SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
			
		-- select * from #Resultado_WhoisActive
			
		-- Verifica se não existe nenhum processo em Execução
		IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
		BEGIN
			INSERT INTO #Resultado_WhoisActive
			SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
		END

		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		-- Declara as variaveis
		DECLARE @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @AlertaQueriesLentasHeader VARCHAR(MAX),
				@ResultadoWhoisactiveHeader VARCHAR(MAX), @ResultadoWhoisactiveTable VARCHAR(MAX),
				@AlertaQueriesLentasTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX), @Subject VARCHAR(500)

		--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - HEADER - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> TOP 50 - Processos executando no Banco de Dados <BR />'
			SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

			--------------------------------------------------------------------------------------------------------------------------------
			--	ALERTA - BODY - WHOISACTIVE
			--------------------------------------------------------------------------------------------------------------------------------
			SET @ResultadoWhoisactiveTable = CAST( (
				SELECT td =				[Duração]				+ '</td>'
							+ '<td>' +  [database_name]			+ '</td>'
							+ '<td>' +  [login_name]			+ '</td>'
							+ '<td>' +  [host_name]				+ '</td>'
							+ '<td>' +  [start_time]			+ '</td>'
							+ '<td>' +  [status]				+ '</td>'
							+ '<td>' +  [session_id]			+ '</td>'
							+ '<td>' +  [blocking_session_id]	+ '</td>'
							+ '<td>' +  [Wait]					+ '</td>'
							+ '<td>' +  [open_tran_count]		+ '</td>'
							+ '<td>' +  [CPU]					+ '</td>'
							+ '<td>' +  [reads]					+ '</td>'
							+ '<td>' +  [writes]				+ '</td>'
							+ '<td>' +  [sql_command]			+ '</td>'

				FROM (  
						-- Dados da Tabela do EMAIL
						SELECT	TOP 50
								ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
								ISNULL([database_name], '-')							AS [database_name],
								ISNULL([login_name], '-')								AS [login_name],
								ISNULL([host_name], '-')								AS [host_name],
								ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
								ISNULL([status], '-')									AS [status],
								ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
								ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
								ISNULL([wait_info], '-')								AS [Wait],
								ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
								ISNULL([CPU], '-')										AS [CPU],
								ISNULL([reads], '-')									AS [reads],
								ISNULL([writes], '-')									AS [writes],
								ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
						FROM #Resultado_WhoisActive
				
					  ) AS D ORDER BY [start_time] 
				FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
			) 
			      
			-- Corrige a Formatação da Tabela
			SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			
			-- Títulos da Tabela do EMAIL
			SET @ResultadoWhoisactiveTable = 
					'<table cellspacing="2" cellpadding="5" border="3">'    
					+	'<tr>
							<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
							<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
							<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
							<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
							<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
							<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
							<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
						</tr>'    
					+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
					+ '</table>'

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaQueriesLentasHeader = '<font color=black bold=true size=5>'		            
		SET @AlertaQueriesLentasHeader = @AlertaQueriesLentasHeader + '<BR /> TOP 50 - Queries Demoradas <BR />' 
		SET @AlertaQueriesLentasHeader = @AlertaQueriesLentasHeader + '</font>'

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------	 
		SET @AlertaQueriesLentasTable = CAST( (    
			SELECT td =				[StartTime]		+ '</td>'
						+ '<td>' +  [DataBaseName]	+ '</td>'
						+ '<td>' +  [Duration]		+ '</td>'
						+ '<td>' +  [Reads]			+ '</td>'
						+ '<td>' +  [Writes]		+ '</td>'	
						+ '<td>' +  [CPU]			+ '</td>'	
						+ '<td>' +  [TextData]		+ '</td>'
			FROM (  
					-- Dados da Tabela do EMAIL
					SELECT	TOP 50
							CONVERT(VARCHAR(20), [StartTime], 120)	AS [StartTime], 
							[DataBaseName], 
							CAST([Duration] AS VARCHAR)				AS [Duration],
							CAST([Reads] AS VARCHAR)				AS [Reads],
							CAST([Writes] AS VARCHAR)				AS [Writes],
							CAST([CPU] AS VARCHAR)					AS [CPU],
							SUBSTRING([TextData], 1, 150)			AS [TextData]
					FROM #Queries_Demoradas_Temp
					ORDER BY [Duration] DESC
					
				  ) AS D ORDER BY CAST([Duration] AS NUMERIC(15,2)) DESC
		  FOR XML PATH( 'tr' )) AS VARCHAR(MAX) 
		)   
		      
		-- Corrige a Formatação da Tabela
		SET @AlertaQueriesLentasTable = REPLACE( REPLACE( REPLACE( @AlertaQueriesLentasTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
		    
		-- Títulos da Tabela do EMAIL
		SET @AlertaQueriesLentasTable = 
				'<table cellspacing="2" cellpadding="5" border="3">'    
				+	'<tr>
						<th bgcolor=#0B0B61 width="100"><font color=white>StartTime</font></th>
						<th bgcolor=#0B0B61 width="50"><font color=white>DataBaseName</font></th>
						<th bgcolor=#0B0B61 width="70"><font color=white>Duration</font></th>				  
						<th bgcolor=#0B0B61 width="70"><font color=white>Reads</font></th>
						<th bgcolor=#0B0B61 width="70"><font color=white>Writes</font></th>
						<th bgcolor=#0B0B61 width="70"><font color=white>CPU</font></th>
						<th bgcolor=#0B0B61 width="300"><font color=white>TextData (150 caracteres iniciais)</font></th>				  
					</tr>'    
				+ REPLACE( REPLACE( @AlertaQueriesLentasTable, '&lt;', '<'), '&gt;', '>')
				+ '</table>' 
				
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'
								
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'

		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Existem ' + CAST(@Quantidade_Queries_Demoradas AS VARCHAR) + ' queries demoradas nos últimos 5 minutos no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail +
								@AlertaQueriesLentasHeader + @EmptyBodyEmail + @AlertaQueriesLentasTable + @EmptyBodyEmail
				
		/***********************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		***********************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'
		  		
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance
	END
END

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Job_Falha]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Job_Falha]
GO

/*******************************************************************************************************************************
--	ALERTA: JOB FALHA
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Job_Falha]
AS
BEGIN
	SET NOCOUNT ON
		
	IF ( OBJECT_ID('tempdb..#Result_History_Jobs') IS NOT NULL )
		DROP TABLE #Result_History_Jobs

	CREATE TABLE #Result_History_Jobs (
		[Cod]				INT IDENTITY(1,1),
		[Instance_Id]		INT,
		[Job_Id]			VARCHAR(255),
		[Job_Name]			VARCHAR(255),
		[Step_Id]			INT,
		[Step_Name]			VARCHAR(255),
		[SQl_Message_Id]	INT,
		[Sql_Severity]		INT,
		[SQl_Message]		VARCHAR(4490),
		[Run_Status]		INT,
		[Run_Date]			VARCHAR(20),
		[Run_Time]			VARCHAR(20),
		[Run_Duration]		INT,
		[Operator_Emailed]	VARCHAR(100),
		[Operator_NetSent]	VARCHAR(100),
		[Operator_Paged]	VARCHAR(100),
		[Retries_Attempted]	INT,
		[Nm_Server]			VARCHAR(100)  
	)

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	DECLARE @JobFailed_Parametro INT, @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	-- Job Falha
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Job Falha')

	SELECT	@JobFailed_Parametro = Vl_Parametro,			-- Horas
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Jobs Failed

	-- Declara as variaveis
	DECLARE @Dt_Inicial VARCHAR (8), @Dt_Referencia DATETIME	

	SELECT @Dt_Referencia = GETDATE()

	SELECT	@Dt_Inicial  =	CONVERT(VARCHAR(8), (DATEADD (HOUR, -@JobFailed_Parametro, @Dt_Referencia)), 112)
	
	INSERT INTO #Result_History_Jobs
	EXEC [msdb].[dbo].[sp_help_jobhistory] 
			@mode = 'FULL', 
			@start_run_date = @Dt_Inicial

	-- Busca os dados dos JOBS que Falharam
	IF ( OBJECT_ID('tempdb..#Alerta_Job_Falharam') IS NOT NULL )
		DROP TABLE #Alerta_Job_Falharam
	
	SELECT	TOP 50
			[Nm_Server] AS [Server],
			[Job_Name], 
			CASE	WHEN [Run_Status] = 0 THEN 'Failed'
					WHEN [Run_Status] = 1 THEN 'Succeeded'
					WHEN [Run_Status] = 2 THEN 'Retry (step only)'
					WHEN [Run_Status] = 3 THEN 'Cancelled'
					WHEN [Run_Status] = 4 THEN 'In-progress message'
					WHEN [Run_Status] = 5 THEN 'Unknown' 
			END AS [Status],
			CAST(	[Run_Date] + ' ' +
					RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-5), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-3), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-1), 2), 2) AS VARCHAR
				) AS [Dt_Execucao],
			RIGHT('00' + SUBSTRING(CAST([Run_Duration] AS VARCHAR), (LEN([Run_Duration])-5), 2), 2) + ':' +
			RIGHT('00' + SUBSTRING(CAST([Run_Duration] AS VARCHAR), (LEN([Run_Duration])-3), 2), 2) + ':' +
			RIGHT('00' + SUBSTRING(CAST([Run_Duration] AS VARCHAR), (LEN([Run_Duration])-1), 2), 2) AS [Run_Duration],
			CAST([SQl_Message] AS VARCHAR(3990)) AS [SQL_Message]
	INTO #Alerta_Job_Falharam
	FROM #Result_History_Jobs 
	WHERE 
		 -- [Step_Id] = 0 AND condição para o retry
		  [Run_Status] <> 1 AND
		  CAST	(	
					[Run_Date] + ' ' + RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-3), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time], (LEN([Run_Time])-1), 2), 2) AS DATETIME
				) >= DATEADD(HOUR, -@JobFailed_Parametro, @Dt_Referencia) AND
		  CAST	(	[Run_Date] + ' ' + RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-5), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-3), 2), 2) + ':' +
					RIGHT('00' + SUBSTRING([Run_Time],(LEN([Run_Time])-1), 2), 2) AS DATETIME
				) < @Dt_Referencia
	ORDER BY [Dt_Execucao] DESC
			
	/*******************************************************************************************************************************
	--	Verifica se algum JOB Falhou
	*******************************************************************************************************************************/
	IF EXISTS(SELECT * FROM #Alerta_Job_Falharam)
	BEGIN
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		-- Declara as variaveis
		DECLARE @EmailBody VARCHAR(MAX), @AlertaLogHeader VARCHAR(MAX), @AlertaJobFailed VARCHAR(MAX), 
				@EmptyBodyEmail VARCHAR(MAX), @Importance AS VARCHAR(6), @Subject VARCHAR(500)
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaLogHeader = '<font color=black bold=true size=5>'				            
		SET @AlertaLogHeader = @AlertaLogHeader + '<BR /> TOP 50 - Jobs que Falharam nas últimas ' +  CAST((@JobFailed_Parametro) AS VARCHAR) + ' Horas <BR />' 
		SET @AlertaLogHeader = @AlertaLogHeader + '</font>'
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaJobFailed = CAST( (    
			SELECT td =				[Job_Name]		+ '</td>'
						+ '<td>' +	[Status]		+ '</td>'
						+ '<td>' +	[Dt_Execucao]	+ '</td>'
						+ '<td>' +	[Run_Duration]	+ '</td>'
						+ '<td>' +	[SQL_Message]	+ '</td>'
			FROM (           
					-- Dados da Tabela do EMAIL
					SELECT	[Job_Name], 
							[Status], 
							[Dt_Execucao], 
							[Run_Duration], 
							[SQL_Message] 
					FROM #Alerta_Job_Falharam
					
				  ) AS D ORDER BY [Dt_Execucao] DESC
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
		)
		
		-- Corrige a Formatação da Tabela
		SET @AlertaJobFailed = REPLACE( REPLACE( REPLACE( @AlertaJobFailed, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
		
		-- Títulos da Tabela do EMAIL
		SET @AlertaJobFailed = 
				'<table cellspacing="2" cellpadding="5" border="3">'    
				+	'<tr>
						<th bgcolor=#0B0B61 width="300"><font color=white>Nome do JOB</font></th>
						<th bgcolor=#0B0B61 width="150"><font color=white>Status</font></th>
						<th bgcolor=#0B0B61 width="150"><font color=white>Data da Execução</font></th>
						<th bgcolor=#0B0B61 width="100"><font color=white>Duração</font></th>
						<th bgcolor=#0B0B61 width="400"><font color=white>Mensagem Erro</font></th>
					</tr>'    
				+ REPLACE( REPLACE( @AlertaJobFailed, '&lt;', '<'), '&gt;', '>')   
				+ '</table>'			              
		
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'
			
		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Jobs que Falharam nas últimas ' +  CAST((@JobFailed_Parametro) AS VARCHAR) + ' Horas no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@AlertaLogHeader + @EmptyBodyEmail + @AlertaJobFailed + @EmptyBodyEmail
		
		/*******************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		*******************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'
		
		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/	
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1
	END	
END

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_SQL_Server_Reiniciado]') IS NOT NULL )
	DROP PROCEDURE [dbo].[stpAlerta_SQL_Server_Reiniciado]
GO

/*******************************************************************************************************************************
--	ALERTA: SQL Server Reiniciado
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_SQL_Server_Reiniciado]
AS
BEGIN
	SET NOCOUNT ON

	-- SQL Server Reiniciado
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'SQL Server Reiniciado')

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	DECLARE @SQL_Reiniciado_Parametro INT, @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	SELECT	@SQL_Reiniciado_Parametro = Vl_Parametro,		-- Minutos
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- SQL Server Reiniciado

	-- Verifica se o SQL Server foi Reiniciado
	IF ( OBJECT_ID('tempdb..#Alerta_SQL_Reiniciado') IS NOT NULL ) 
		DROP TABLE #Alerta_SQL_Reiniciado
	
	SELECT [create_date]
	INTO #Alerta_SQL_Reiniciado
	FROM [sys].[databases] WITH(NOLOCK)
	WHERE	[database_id] = 2 -- Verifica a Database "TempDb"
			AND [create_date] >= DATEADD(MINUTE, -@SQL_Reiniciado_Parametro, GETDATE())
	
	/*******************************************************************************************************************************
	--	Verifica se o SQL foi Reiniciado
	*******************************************************************************************************************************/
	IF EXISTS( SELECT * FROM #Alerta_SQL_Reiniciado )
	BEGIN
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		-- Declara as variaveis
		DECLARE @EmailBody VARCHAR(MAX), @AlertaLogHeader VARCHAR(MAX), @AlertaSQLReiniciado VARCHAR(MAX), 
				@EmptyBodyEmail VARCHAR(MAX), @Importance AS VARCHAR(6), @Subject VARCHAR(500)
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaLogHeader = '<font color=black bold=true size= 5>'
		SET @AlertaLogHeader = @AlertaLogHeader + '<BR /> SQL Server Reiniciado nos últimos ' +  CAST((@SQL_Reiniciado_Parametro) AS VARCHAR) + ' Minutos <BR />'
		SET @AlertaLogHeader = @AlertaLogHeader + '</font>'
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaSQLReiniciado = CAST( (
			SELECT td =  [Create_Date] + '</td>'
			FROM (      
					-- Dados da Tabela do EMAIL
					SELECT CONVERT(VARCHAR(20), [create_date], 120) AS [Create_Date]
					FROM #Alerta_SQL_Reiniciado
		
				  ) AS D
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
		)
		
		-- Corrige a Formatação da Tabela
		SET @AlertaSQLReiniciado = REPLACE( REPLACE( REPLACE( @AlertaSQLReiniciado, '&lt;', '<' ), '&gt;', '>' ), '<td>', '<td align = center>')
		
		-- Títulos da Tabela do EMAIL
		SET @AlertaSQLReiniciado =	
				'<table cellspacing="2" cellpadding="5" border="3">'
				+	'<tr>
						<th width="400" bgcolor=#0B0B61><font color=white>Horário Restart</font></th>
					 </tr>'
				+ REPLACE( REPLACE( @AlertaSQLReiniciado, '&lt;', '<' ), '&gt;', '>' )
				+ '</table>'
			
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'
		
		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: SQL Server Reiniciado nos últimos ' +  CAST((@SQL_Reiniciado_Parametro) AS VARCHAR) + ' Minutos no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@AlertaLogHeader + @EmptyBodyEmail + @AlertaSQLReiniciado + @EmptyBodyEmail
		
		/*******************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		*******************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'
		
		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1
	END
END

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Database_Criada]') IS NOT NULL )
	DROP PROCEDURE [dbo].[stpAlerta_Database_Criada]
GO

/*******************************************************************************************************************************
--	ALERTA: Database Criada
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Database_Criada]
AS
BEGIN
	SET NOCOUNT ON

	-- Database Criada
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Database Criada')

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Database_Criada_Parametro INT, @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	SELECT	@Database_Criada_Parametro = Vl_Parametro,		-- Horas
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Database Criada

	-- Verifica se alguma base foi criada no dia anterior
	IF ( OBJECT_ID('tempdb..#Alerta_Base_Criada') IS NOT NULL ) 
		DROP TABLE #Alerta_Base_Criada
	
	SELECT [name], [recovery_model_desc], [create_date]
	INTO #Alerta_Base_Criada
	FROM [sys].[databases] WITH(NOLOCK)
	WHERE	[database_id] <> 2 -- Desconsidera a Database "TempDb"
			AND [create_date] >= DATEADD(HOUR, -@Database_Criada_Parametro, GETDATE())
	
	/*******************************************************************************************************************************
	--	Verifica se alguam base foi criada
	*******************************************************************************************************************************/
	IF EXISTS( SELECT * FROM #Alerta_Base_Criada )
	BEGIN
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		-- Declara as variaveis
		DECLARE @EmailBody VARCHAR(MAX), @AlertaLogHeader VARCHAR(MAX), @AlertaBaseCriada VARCHAR(MAX), 
				@EmptyBodyEmail VARCHAR(MAX), @Importance AS VARCHAR(6), @Subject VARCHAR(500)
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaLogHeader = '<font color=black bold=true size= 5>'
		SET @AlertaLogHeader = @AlertaLogHeader + '<BR /> Database Criada nas últimas ' +  CAST((@Database_Criada_Parametro) AS VARCHAR) + ' Horas <BR />'
		SET @AlertaLogHeader = @AlertaLogHeader + '</font>'
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaBaseCriada = CAST( (
			SELECT td =  
								[name]					+ '</td>'
					+ '<td>' +	[recovery_model_desc]	+ '</td>'
					+ '<td>' +  [Create_Date]			+ '</td>'
			FROM (      
					-- Dados da Tabela do EMAIL
					SELECT [name], [recovery_model_desc], CONVERT(VARCHAR(20), [create_date], 120) AS [Create_Date]
					FROM #Alerta_Base_Criada
		
				  ) AS D
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
		)
		
		-- Corrige a Formatação da Tabela
		SET @AlertaBaseCriada = REPLACE( REPLACE( REPLACE( @AlertaBaseCriada, '&lt;', '<' ), '&gt;', '>' ), '<td>', '<td align = center>')
		
		-- Títulos da Tabela do EMAIL
		SET @AlertaBaseCriada =	
				'<table cellspacing="2" cellpadding="5" border="3">'
				+	'<tr>
						<th width="300" bgcolor=#0B0B61><font color=white>Nome</font></th>
						<th width="300" bgcolor=#0B0B61><font color=white>Recovery Model</font></th>
						<th width="300" bgcolor=#0B0B61><font color=white>Data Criação</font></th>
					 </tr>'
				+ REPLACE( REPLACE( @AlertaBaseCriada, '&lt;', '<' ), '&gt;', '>' )
				+ '</table>'
			
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'
		
		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Database Criada nas últimas ' +  CAST((@Database_Criada_Parametro) AS VARCHAR) + ' Horas no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@AlertaLogHeader + @EmptyBodyEmail + @AlertaBaseCriada + @EmptyBodyEmail
		
		/*******************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		*******************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'
		
		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1
	END
END

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_Database_Sem_Backup]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpAlerta_Database_Sem_Backup]
GO

/*******************************************************************************************************************************
--	ALERTA: DATABASE SEM BACKUP
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_Database_Sem_Backup]
AS
BEGIN
	SET NOCOUNT ON

	-- Databases sem Backup
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Database sem Backup')

	-- Declara as variaveis
	DECLARE @Qtd_Databases_Total INT, @Qtd_Databases_Restore INT

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Database_Sem_Backup_Parametro INT, @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	SELECT	@Database_Sem_Backup_Parametro = Vl_Parametro,		-- Horas
			@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro			-- Databases sem Backup

	-- Verifica a Quantidade Total de Databases
	IF ( OBJECT_ID('tempdb..#alerta_backup_databases_todas') IS NOT NULL )
		DROP TABLE #alerta_backup_databases_todas

	SELECT [name] AS [Nm_Database]
	INTO #alerta_backup_databases_todas
	FROM [sys].[databases]
	WHERE [name] NOT IN ('tempdb', 'ReportServerTempDB') AND state_desc <> 'OFFLINE'

	SELECT @Qtd_Databases_Total = COUNT(*)
	FROM #alerta_backup_databases_todas

	-- Verifica a Quantidade de Databases que tiveram Backup nas ultimas 14 horas
	IF ( OBJECT_ID('tempdb..#alerta_backup_databases_com_backup') IS NOT NULL)
		DROP TABLE #alerta_backup_databases_com_backup

	SELECT DISTINCT [database_name] AS [Nm_Database]
	INTO #alerta_backup_databases_com_backup
	FROM [msdb].[dbo].[backupset] B
	JOIN [msdb].[dbo].[backupmediafamily] BF ON B.[media_set_id] = BF.[media_set_id]
	WHERE	[backup_start_date] >= DATEADD(hh, -@Database_Sem_Backup_Parametro, GETDATE())
			AND [type] IN ('D','I')

	SELECT @Qtd_Databases_Restore = COUNT(*) 
	FROM #alerta_backup_databases_com_backup
	
	/*******************************************************************************************************************************
	--	Verifica se menos de 70 % das databases tiveram Backup
	*******************************************************************************************************************************/
	if(@Qtd_Databases_Restore < @Qtd_Databases_Total * 0.7)
	BEGIN	
		-- Databases que não tiveram Backup
		IF ( OBJECT_ID('tempdb..#alerta_backup_databases_sem_backup') IS NOT NULL )
			DROP TABLE #alerta_backup_databases_sem_backup
		
		SELECT A.[Nm_Database]
		INTO #alerta_backup_databases_sem_backup
		FROM #alerta_backup_databases_todas A WITH(NOLOCK)
		LEFT JOIN #alerta_backup_databases_com_backup B WITH(NOLOCK) ON A.[Nm_Database] = B.[Nm_Database]
		WHERE B.[Nm_Database] IS NULL
		
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		-- Declara as variaveis
		DECLARE @EmailBody VARCHAR(MAX), @AlertaLogHeader VARCHAR(MAX), @AlertaLogTable VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
				@Importance AS VARCHAR(6), @Subject VARCHAR(500)
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaLogHeader = '<font color=black bold=true size=5>'				            
		SET @AlertaLogHeader = @AlertaLogHeader + '<BR /> Databases sem Backup nas últimas ' +  CAST((@Database_Sem_Backup_Parametro) AS VARCHAR) + ' Horas <BR />' 
		SET @AlertaLogHeader = @AlertaLogHeader + '</font>'
		
		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaLogTable = CAST( (    
			SELECT td =  [Nm_Database] + '</td>' 

			FROM (
					-- Dados da Tabela do EMAIL
					SELECT [Nm_Database]
					FROM #alerta_backup_databases_sem_backup
					
				  ) AS D ORDER BY [Nm_Database] DESC
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
		)  
		
		-- Corrige a Formatação da Tabela
		SET @AlertaLogTable = REPLACE( REPLACE( REPLACE( @AlertaLogTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
		
		-- Títulos da Tabela do EMAIL
		SET @AlertaLogTable = 
				'<table cellspacing="2" cellpadding="5" border="3">'
				+	'<tr>
						<th width="200" bgcolor=#0B0B61><font color=white>Database</font></th> 
					</tr>'    
				+ REPLACE( REPLACE( @AlertaLogTable, '&lt;', '<'), '&gt;', '>')
				+ '</table>'
		
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'
		
		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Existem Databases sem Backup nas últimas ' +  CAST((@Database_Sem_Backup_Parametro) AS VARCHAR) + ' Horas no Servidor: ' + @@SERVERNAME,
				@EmailBody =	@AlertaLogHeader + @EmptyBodyEmail + @AlertaLogTable + @EmptyBodyEmail
				
		/*******************************************************************************************************************************
		-- Inclui uma imagem com link para o site do Fabricio Lima
		*******************************************************************************************************************************/
		select @EmailBody = @EmailBody + '<br/><br/>' +
					'<a href="http://www.fabriciolima.net" target=”_blank”> 
						<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
								height="100" width="400"/>
					</a>'
		
		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

   		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/		
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1
	END
END

GO
IF ( OBJECT_ID('[dbo].[stpCHECKDB_Databases]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpCHECKDB_Databases]
GO

/*******************************************************************************************************************************
--	ALERTA: CHECKDB DATABASES
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpCHECKDB_Databases]
AS
BEGIN
	SET NOCOUNT ON
	
	-- Declara a tabela que irá armazenar o nome das Databases
	DECLARE @Databases TABLE ( 
		[Id_Database] INT IDENTITY(1, 1), 
		[Nm_Database] VARCHAR(50)
	)

	-- Declara as variaveis
	DECLARE @Total INT, @Loop INT, @Nm_Database VARCHAR(50)
	
	-- Busca o nome das Databases
	INSERT INTO @Databases( [Nm_Database] )
	SELECT [name]
	FROM [master].[sys].[databases]
	WHERE	[name] NOT IN ('tempdb')  -- Colocar o nome da Database aqui, caso deseje desconsiderar alguma
			AND [state_desc] = 'ONLINE'

	-- Quantidade Total de Databases (utilizado no Loop abaixo)
	SELECT @Total = MAX([Id_Database])
	FROM @Databases

	SET @Loop = 1

	-- Realiza o CHECKDB para cada Database
	WHILE ( @Loop <= @Total )
	BEGIN
		SELECT @Nm_Database = [Nm_Database]
		FROM @Databases
		WHERE [Id_Database] = @Loop

		DBCC CHECKDB(@Nm_Database) WITH NO_INFOMSGS 
		SET @Loop = @Loop + 1
	END
END

GO
IF ( OBJECT_ID('[dbo].[stpAlerta_CheckDB]') IS NOT NULL )
	DROP PROCEDURE [dbo].[stpAlerta_CheckDB]
GO

/*******************************************************************************************************************************
--	ALERTA: BANCO DE DADOS CORROMPIDO
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpAlerta_CheckDB]
AS
BEGIN
	SET NOCOUNT ON

	SET DATEFORMAT MDY

	IF ( OBJECT_ID('tempdb..#TempLog') IS NOT NULL ) 
		DROP TABLE #TempLog
	
	CREATE TABLE #TempLog (
		[LogDate]		DATETIME,
		[ProcessInfo]	NVARCHAR(50),
		[Text]			NVARCHAR(MAX)
	)

	IF ( OBJECT_ID('tempdb..#logF') IS NOT NULL ) 
		DROP TABLE #logF
	
	CREATE TABLE #logF (
		ArchiveNumber     INT,
		LogDate           DATETIME,
		LogSize           INT 
	)

	-- Seleciona o número de arquivos.
	INSERT INTO #logF  
	EXEC sp_enumerrorlogs
	
	DELETE FROM #logF
	WHERE LogDate < GETDATE()-2

	DECLARE @TSQL NVARCHAR(2000), @lC INT	

	SELECT @lC = MIN(ArchiveNumber) FROM #logF

	--Loop para realizar a leitura de todo o log
	WHILE @lC IS NOT NULL
	BEGIN
		  INSERT INTO #TempLog
		  EXEC sp_readerrorlog @lC
		  
		  SELECT @lC = MIN(ArchiveNumber) 
		  FROM #logF
		  WHERE ArchiveNumber > @lC
	END

	IF OBJECT_ID('_Result_Corrupcao') IS NOT NULL
		DROP TABLE _Result_Corrupcao
		
	SELECT	LogDate,
			SUBSTRING(Text, 15, CHARINDEX(')', Text, 15) - 15) AS Nm_Database,
			SUBSTRING(Text,charindex('found',Text),(charindex('Elapsed time',Text)-charindex('found',Text))) AS Erros,   
			Text 
	INTO _Result_Corrupcao
	FROM #TempLog
	WHERE LogDate >= GETDATE() - 1	 
		and Text like '%DBCC CHECKDB (%'
		and Text not like '%IDR%'
		and substring(Text,charindex('found',Text), charindex('Elapsed time',Text) - charindex('found',Text)) <> 'found 0 errors and repaired 0 errors.'

	-- Declara as variaveis
	DECLARE @Subject VARCHAR(500), @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
			@AlertaBancoCorrompidoHeader VARCHAR(MAX), @AlertaBancoCorrompidoTable VARCHAR(MAX), @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	
	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	-- Banco de Dados Corrompido
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Banco de Dados Corrompido')

	SELECT	@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Banco de Dados Corrompido

	/*******************************************************************************************************************************
	-- Verifica se existe algum Banco de Dados Corrompido
	*******************************************************************************************************************************/
	IF EXISTS (SELECT NULL FROM [Traces].[dbo].[_Result_Corrupcao]) 
	BEGIN	-- INICIO - ALERTA
		/*******************************************************************************************************************************
		--	CRIA O EMAIL - ALERTA
		*******************************************************************************************************************************/			

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - HEADER
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaBancoCorrompidoHeader = '<font color=black bold=true size=5>'			            
		SET @AlertaBancoCorrompidoHeader = @AlertaBancoCorrompidoHeader + '<BR /> Banco de Dados Corrompido <BR />' 
		SET @AlertaBancoCorrompidoHeader = @AlertaBancoCorrompidoHeader + '</font>'

		--------------------------------------------------------------------------------------------------------------------------------
		--	ALERTA - BODY
		--------------------------------------------------------------------------------------------------------------------------------
		SET @AlertaBancoCorrompidoTable = CAST( (    
			SELECT td =				[LogDate]		+ '</td>'
						+ '<td>' +	[Nm_Database]	+ '</td>'
						+ '<td>' +	[Erros]			+ '</td>'
						+ '<td>' +	[Text]			+ '</td>'

			FROM (
					-- Dados da Tabela do EMAIL
					SELECT	CONVERT(VARCHAR(20), [LogDate], 120) AS [LogDate],
							[Nm_Database],
							[Erros],
							[Text]
					FROM [Traces].[dbo].[_Result_Corrupcao]
					
			) AS D
			FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX) 
		)   
			      
		-- Corrige a Formatação da Tabela
		SET @AlertaBancoCorrompidoTable = REPLACE( REPLACE( REPLACE( @AlertaBancoCorrompidoTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
			    
		-- Títulos da Tabela do EMAIL
		SET @AlertaBancoCorrompidoTable = 
				'<table cellspacing="2" cellpadding="5" border="3">'
				+	'<tr>
						<th bgcolor=#0B0B61 width="100"><font color=white>Data Log</font></th>
						<th bgcolor=#0B0B61 width="180"><font color=white>Nome Database</font></th>
						<th bgcolor=#0B0B61 width="200"><font color=white>Erros</font></th>
						<th bgcolor=#0B0B61 width="300"><font color=white>Descrição</font></th>
					</tr>'    
				+ REPLACE( REPLACE( @AlertaBancoCorrompidoTable, '&lt;', '<'), '&gt;', '>')
				+ '</table>' 
			
		--------------------------------------------------------------------------------------------------------------------------------
		-- Insere um Espaço em Branco no EMAIL
		--------------------------------------------------------------------------------------------------------------------------------
		SET @EmptyBodyEmail =	''
		SET @EmptyBodyEmail =
				'<table cellpadding="5" cellspacing="5" border="0">' +
					'<tr>
						<th width="500">               </th>
					</tr>'
					+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
				+ '</table>'

		/*******************************************************************************************************************************
		--	Seta as Variáveis do EMAIL
		*******************************************************************************************************************************/
		SELECT	@Importance =	'High',
				@Subject =		'ALERTA: Existe algum Banco de Dados Corrompido no Servidor: ' + @@SERVERNAME + '. Verifique com urgência!',
				@EmailBody =	@AlertaBancoCorrompidoHeader + @EmptyBodyEmail + @AlertaBancoCorrompidoTable + @EmptyBodyEmail
			
		/*******************************************************************************************************************************
		--	ENVIA O EMAIL - ALERTA
		*******************************************************************************************************************************/
		EXEC [msdb].[dbo].[sp_send_dbmail]
				@profile_name = @ProfileEmail,
				@recipients =	@EmailDestination,
				@subject =		@Subject,
				@body =			@EmailBody,
				@body_format =	'HTML',
				@importance =	@Importance

		/*******************************************************************************************************************************
		-- Insere um Registro na Tabela de Controle dos Alertas -> Fl_Tipo = 1 : ALERTA
		*******************************************************************************************************************************/
		INSERT INTO [dbo].[Alerta] ( [Id_Alerta_Parametro], [Ds_Mensagem], [Fl_Tipo] )
		SELECT @Id_Alerta_Parametro, @Subject, 1		
	END		-- FIM - ALERTA
				
	IF ( OBJECT_ID('_Result_Corrupcao') IS NOT NULL )
		DROP TABLE _Result_Corrupcao
END

GO
IF ( OBJECT_ID('[dbo].[stpEnvia_Email_Processos_Execucao]') IS NOT NULL ) 
	DROP PROCEDURE [dbo].[stpEnvia_Email_Processos_Execucao]
GO

/*******************************************************************************************************************************
--	PROCEDURE ENVIA EMAIL WHOISACTIVE DBA
*******************************************************************************************************************************/

CREATE PROCEDURE [dbo].[stpEnvia_Email_Processos_Execucao]
AS
BEGIN
	SET NOCOUNT ON

	-- Declara as variaveis
	DECLARE	@Subject VARCHAR(500), @Importance AS VARCHAR(6), @EmailBody VARCHAR(MAX), @EmptyBodyEmail VARCHAR(MAX),
			@ResultadoWhoisactiveHeader VARCHAR(MAX), @ResultadoWhoisactiveTable VARCHAR(MAX), @EmailDestination VARCHAR(500), @ProfileEmail VARCHAR(200)
	 
	-- Cria a tabela que ira armazenar os dados dos processos
	IF ( OBJECT_ID('TempDb..#Resultado_WhoisActive') IS NOT NULL )
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
				    
    -- Altera a coluna que possui o comando SQL
	ALTER TABLE #Resultado_WhoisActive
	ALTER COLUMN [sql_command] VARCHAR(MAX)
	
	UPDATE #Resultado_WhoisActive
	SET [sql_command] = REPLACE( REPLACE( REPLACE( REPLACE( CAST([sql_command] AS VARCHAR(1000)), '<?query --', ''), '--?>', ''), '&gt;', '>'), '&lt;', '')
	
	-- select * from #Resultado_WhoisActive
	
	-- Verifica se não existe nenhum processo em Execução
	IF NOT EXISTS ( SELECT TOP 1 * FROM #Resultado_WhoisActive )
	BEGIN
		INSERT INTO #Resultado_WhoisActive
		SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
	END

	--------------------------------------------------------------------------------------------------------------------------------
	-- Recupera os parametros do Alerta
	--------------------------------------------------------------------------------------------------------------------------------
	-- Processos em Execução
	DECLARE @Id_Alerta_Parametro INT = (SELECT Id_Alerta_Parametro FROM [Traces].[dbo].Alerta_Parametro (NOLOCK) WHERE Nm_Alerta = 'Processos em Execução')
	
	SELECT	@EmailDestination = Ds_Email,
			@ProfileEmail = Ds_Profile_Email
	FROM [dbo].[Alerta_Parametro]
	WHERE [Id_Alerta_Parametro] = @Id_Alerta_Parametro		-- Processos em Execução

	/*******************************************************************************************************************************
	--	CRIA O EMAIL
	*******************************************************************************************************************************/							

	--------------------------------------------------------------------------------------------------------------------------------
	--	HEADER
	--------------------------------------------------------------------------------------------------------------------------------
	SET @ResultadoWhoisactiveHeader = '<font color=black bold=true size=5>'			            
	SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '<BR /> Processos em Execução no Banco de Dados <BR />'
	SET @ResultadoWhoisactiveHeader = @ResultadoWhoisactiveHeader + '</font>'

	--------------------------------------------------------------------------------------------------------------------------------
	--	BODY
	--------------------------------------------------------------------------------------------------------------------------------
	SET @ResultadoWhoisactiveTable = CAST( (
		SELECT td =				[Duração]				+ '</td>'
					+ '<td>' +  [database_name]			+ '</td>'
					+ '<td>' +  [login_name]			+ '</td>'
					+ '<td>' +  [host_name]				+ '</td>'
					+ '<td>' +  [start_time]			+ '</td>'
					+ '<td>' +  [status]				+ '</td>'
					+ '<td>' +  [session_id]			+ '</td>'
					+ '<td>' +  [blocking_session_id]	+ '</td>'
					+ '<td>' +  [Wait]					+ '</td>'
					+ '<td>' +  [open_tran_count]		+ '</td>'
					+ '<td>' +  [CPU]					+ '</td>'
					+ '<td>' +  [reads]					+ '</td>'
					+ '<td>' +  [writes]				+ '</td>'
					+ '<td>' +  [sql_command]			+ '</td>'

		FROM (  
				-- Dados da Tabela do EMAIL
				SELECT	ISNULL([dd hh:mm:ss.mss], '-')							AS [Duração], 
						ISNULL([database_name], '-')							AS [database_name],
						ISNULL([login_name], '-')								AS [login_name],
						ISNULL([host_name], '-')								AS [host_name],
						ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')	AS [start_time],
						ISNULL([status], '-')									AS [status],
						ISNULL(CAST([session_id] AS VARCHAR), '-')				AS [session_id],
						ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')		AS [blocking_session_id],
						ISNULL([wait_info], '-')								AS [Wait],
						ISNULL(CAST([open_tran_count] AS VARCHAR), '-')			AS [open_tran_count],
						ISNULL([CPU], '-')										AS [CPU],
						ISNULL([reads], '-')									AS [reads],
						ISNULL([writes], '-')									AS [writes],
						ISNULL(SUBSTRING([sql_command], 1, 300), '-')			AS [sql_command]
				FROM #Resultado_WhoisActive
		
			  ) AS D ORDER BY [start_time] 
		FOR XML PATH( 'tr' ), TYPE) AS VARCHAR(MAX)
	) 
	      
	-- Corrige a Formatação da Tabela
	SET @ResultadoWhoisactiveTable = REPLACE( REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align = center>')
	
	-- Títulos da Tabela do EMAIL
	SET @ResultadoWhoisactiveTable = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th bgcolor=#0B0B61 width="140"><font color=white>[dd hh:mm:ss.mss]</font></th>
					<th bgcolor=#0B0B61 width="100"><font color=white>Database</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>Login</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>Host Name</font></th>
					<th bgcolor=#0B0B61 width="200"><font color=white>Hora Início</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>Status</font></th>
					<th bgcolor=#0B0B61 width="30"><font color=white>ID Sessão</font></th>
					<th bgcolor=#0B0B61 width="60"><font color=white>ID Sessão Bloqueando</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>Wait</font></th>
					<th bgcolor=#0B0B61 width="60"><font color=white>Transações Abertas</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>CPU</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>Reads</font></th>
					<th bgcolor=#0B0B61 width="120"><font color=white>Writes</font></th>
					<th bgcolor=#0B0B61 width="1000"><font color=white>Query</font></th>
				</tr>'    
			+ REPLACE( REPLACE( @ResultadoWhoisactiveTable, '&lt;', '<'), '&gt;', '>')   
			+ '</table>' 
	              
	--------------------------------------------------------------------------------------------------------------------------------
	-- Insere um Espaço em Branco no EMAIL
	--------------------------------------------------------------------------------------------------------------------------------
	SET @EmptyBodyEmail =	''
	SET @EmptyBodyEmail =
			'<table cellpadding="5" cellspacing="5" border="0">' +
				'<tr>
					<th width="500">               </th>
				</tr>'
				+ REPLACE( REPLACE( ISNULL(@EmptyBodyEmail,''), '&lt;', '<'), '&gt;', '>')
			+ '</table>'

	/*******************************************************************************************************************************
	--	Seta as variavis do Email
	*******************************************************************************************************************************/
	SELECT	@Importance =	'High',
			@Subject =		'Processos em execução no Servidor: ' + @@SERVERNAME,
			@EmailBody =	@ResultadoWhoisactiveHeader + @EmptyBodyEmail + @ResultadoWhoisactiveTable + @EmptyBodyEmail

	/***********************************************************************************************************************************
	-- Inclui uma imagem com link para o site do Fabricio Lima
	***********************************************************************************************************************************/
	select @EmailBody = @EmailBody + '<br/><br/>' +
				'<a href="http://www.fabriciolima.net" target=”_blank”> 
					<img	src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png"
							height="100" width="400"/>
				</a>'
		
	/*******************************************************************************************************************************
	--	ENVIA O EMAIL
	*******************************************************************************************************************************/		
	EXEC [msdb].[dbo].[sp_send_dbmail]
			@profile_name = @ProfileEmail,
			@recipients =	@EmailDestination ,
			@subject =		@Subject,
			@body =			@EmailBody,
			@body_format =	'HTML',
			@importance =	@Importance
END