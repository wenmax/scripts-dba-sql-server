/*******************************************************************************************************************************
(C) 2016, Fabricio Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: contato@fabriciolima.net
*******************************************************************************************************************************/


/***********************************************************************************************************************************
------------------------------------------------------------------------------------------------------------------------------------
--	LEIA-ME!!! INSTRUÇÕES DE EXECUÇÃO:
------------------------------------------------------------------------------------------------------------------------------------
	1)	Alterar os parâmetros da execução da procedure no STEP 2 do JOB de acordo com sua necessidade

-- Exemplo Execução
EXEC[dbo].[stpEnvia_CheckList_Diario_DBA]
	@Nm_Empresa = 'NomeEmpresa',
	@Profile_Email = 'MSSQLServer',
	@Ds_Email = 'E-mail@provedor.com'


	2)	Basta executar o script abaixo para criar uma procedure e um job que chamará essa procedure.
		
***********************************************************************************************************************************/


/*******************************************************************************************************************************
--	Database que será utilizada para armazenar os dados do CheckList. Se for necessário, altere o nome da mesma.
*******************************************************************************************************************************/
USE Traces


/*******************************************************************************************************************************
--	Cria a procedure que envia o E-Mail do CheckList do Banco de Dados
*******************************************************************************************************************************/
IF OBJECT_ID('[dbo].[stpEnvia_CheckList_Diario_DBA]') is not null
	DROP PROCEDURE [dbo].[stpEnvia_CheckList_Diario_DBA]

GO

/****** Object:  StoredProcedure [dbo].[stpEnvia_CheckList_Diario_DBA]    Script Date: 03/06/2016 11:44:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
	
/*
-- Exemplo Execução
EXEC[dbo].[stpEnvia_CheckList_Diario_DBA]
	@Nm_Empresa = 'NomeEmpresa',
	@Profile_Email = 'MSSQLServer',
	@Ds_Email = 'E-mail@provedor.com'
*/	

CREATE PROCEDURE [dbo].[stpEnvia_CheckList_Diario_DBA]
	@Nm_Empresa VARCHAR(100),
	@Profile_Email VARCHAR(100),
	@Ds_Email VARCHAR(MAX)	
AS
BEGIN
	/*
	-- P/ TESTE
	DECLARE
		@Nm_Empresa VARCHAR(100) = 'NomeEmpresa',
		@Profile_Email VARCHAR(100) = 'MSSQLServer',
		@Ds_Email VARCHAR(MAX)= 'E-mail@provedor.com'
	*/	

	/***********************************************************************************************************************************
	--	Validação nos Parâmetros de Entrada
	***********************************************************************************************************************************/
	IF (@Nm_Empresa IS NULL OR @Nm_Empresa = '')
	BEGIN
		RAISERROR('Favor informar o Nome da Empresa!',16,1)
		RETURN
	END
	ELSE IF (@Profile_Email IS NULL OR @Profile_Email = '')
	BEGIN
		RAISERROR('Favor informar o Profile de E-mail!',16,1)
		RETURN
	END
	ELSE IF (@Ds_Email IS NULL OR @Ds_Email = '')
	BEGIN
		RAISERROR('Favor informar os Destinatários de E-mail!',16,1)
		RETURN
	END

	/***********************************************************************************************************************************
	--	Disponibilidade SQL Server - HEADER
	***********************************************************************************************************************************/
	DECLARE @DisponibilidadeSQL_Header VARCHAR(MAX)
	SET @DisponibilidadeSQL_Header = '<font color=black size=5>'
	SET @DisponibilidadeSQL_Header = @DisponibilidadeSQL_Header + '<br/> Tempo de Disponibilidade do SQL Server <br/>' 
	SET @DisponibilidadeSQL_Header = @DisponibilidadeSQL_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Disponibilidade SQL Server - BODY
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @DisponibilidadeSQL_Table VARCHAR(MAX)
	SET @DisponibilidadeSQL_Table = CAST( (    
		SELECT td =	DisponibilidadeSQL + '</td>'
		FROM (           
				SELECT	CASE 
							WHEN	(RTRIM(CONVERT(CHAR(17), DATEDIFF(SECOND, CONVERT(DATETIME, [Create_Date]), GETDATE()) / 86400)) = 0) OR
									(RTRIM(CONVERT(CHAR(17), DATEDIFF(SECOND, CONVERT(DATETIME, [Create_Date]), GETDATE()) / 86400)) > 365)
								THEN ' bgcolor=yellow>' 
								ELSE '' 
						END + 
						RTRIM(CONVERT(CHAR(17), DATEDIFF(SECOND, CONVERT(DATETIME, [Create_Date]), GETDATE()) / 86400)) + ' Dia(s) ' +
						RIGHT('00' + RTRIM(CONVERT(CHAR(7), DATEDIFF(SECOND, CONVERT(DATETIME, [Create_Date]), GETDATE()) % 86400 / 3600)), 2) + ' Hora(s) ' +
						RIGHT('00' + RTRIM(CONVERT(CHAR(7), DATEDIFF(SECOND, CONVERT(DATETIME, [Create_Date]), GETDATE()) % 86400 % 3600 / 60)), 2) + ' Minuto(s) '	AS DisponibilidadeSQL
				FROM [sys].[databases]
				WHERE [Database_Id] = 2
				    
			  ) AS D
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX)
	)  
      
	SET @DisponibilidadeSQL_Table =	REPLACE( REPLACE( REPLACE( REPLACE(@DisponibilidadeSQL_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')
    
	SET @DisponibilidadeSQL_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Tempo Disponibilidade</font></th>
				</tr>'    
			+ REPLACE( REPLACE( @DisponibilidadeSQL_Table, '&lt;', '<'), '&gt;', '>')
			+ '</table>'


	/***********************************************************************************************************************************
	--	Espaço em Disco - Header
	***********************************************************************************************************************************/
	DECLARE @EspacoDisco_Header VARCHAR(MAX)
	SET @EspacoDisco_Header = '<font color=black size=5>'
	SET @EspacoDisco_Header = @EspacoDisco_Header + '<br/> Espaço em Disco <br/>' 
	SET @EspacoDisco_Header = @EspacoDisco_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Espaço em Disco - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @EspacoDisco_Table VARCHAR(MAX)
	SET @EspacoDisco_Table = CAST( (    
		SELECT td =				   CASE WHEN [SpaceUsed_Percent] = '-' THEN '' WHEN CAST([SpaceUsed_Percent] AS NUMERIC(9,2)) >= 90 THEN ' bgcolor=yellow>' ELSE '' END + [DriveName]			+ '</td>' +
						+ '<td>' + CASE WHEN [SpaceUsed_Percent] = '-' THEN '' WHEN CAST([SpaceUsed_Percent] AS NUMERIC(9,2)) >= 90 THEN ' bgcolor=yellow>' ELSE '' END + [TotalSize_GB]		+ '</td>' +
						+ '<td>' + CASE WHEN [SpaceUsed_Percent] = '-' THEN '' WHEN CAST([SpaceUsed_Percent] AS NUMERIC(9,2)) >= 90 THEN ' bgcolor=yellow>' ELSE '' END + [SpaceUsed_GB]		+ '</td>' +
						+ '<td>' + CASE WHEN [SpaceUsed_Percent] = '-' THEN '' WHEN CAST([SpaceUsed_Percent] AS NUMERIC(9,2)) >= 90 THEN ' bgcolor=yellow>' ELSE '' END + [FreeSpace_GB]		+ '</td>' +
						+ '<td>' + CASE WHEN [SpaceUsed_Percent] = '-' THEN '' WHEN CAST([SpaceUsed_Percent] AS NUMERIC(9,2)) >= 90 THEN ' bgcolor=yellow>' ELSE '' END + [SpaceUsed_Percent]	+ '</td>'
		FROM (           
				SELECT	[DriveName], 
						ISNULL(CAST([TotalSize_GB]		AS VARCHAR), '-')	AS [TotalSize_GB], 
						ISNULL(CAST([SpaceUsed_GB]		AS VARCHAR), '-')	AS [SpaceUsed_GB],
						ISNULL(CAST([FreeSpace_GB]		AS VARCHAR), '-')	AS [FreeSpace_GB], 
						ISNULL(CAST([SpaceUsed_Percent] AS VARCHAR), '-')	AS [SpaceUsed_Percent] 
				FROM [dbo].[CheckList_Espaco_Disco]
				    
			  ) AS D ORDER BY [DriveName]
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX)
	)  
      
	SET @EspacoDisco_Table =	REPLACE( REPLACE( REPLACE( REPLACE(@EspacoDisco_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')
    
	SET @EspacoDisco_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="100" bgcolor=#0B0B61><font color=white>Drive</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Tamanho (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Utilizado (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Livre (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Utilizado (%)</font></th>
				</tr>'    
			+ REPLACE( REPLACE( @EspacoDisco_Table, '&lt;', '<'), '&gt;', '>')
			+ '</table>' 
              
              
	/***********************************************************************************************************************************
	--	Arquivos Dados - Header
	***********************************************************************************************************************************/
	DECLARE @ArquivosDados_Header VARCHAR(MAX)
	SET @ArquivosDados_Header = '<font color=black size=5>'
	SET @ArquivosDados_Header = @ArquivosDados_Header + '<br/> TOP 5 - Informações dos Arquivos de Dados (MDF e NDF) <br/>' 
	SET @ArquivosDados_Header = @ArquivosDados_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Arquivos Dados - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @ArquivosDados_Table VARCHAR(MAX)
	SET @ArquivosDados_Table = CAST( (
		SELECT td =				  [Nm_Database]			+ 
					'</td><td>' + [Logical_Name]		+ 
					'</td><td>' + [Total_Reservado]		+ 
					'</td><td>' + [Total_Utilizado]		+ 		
					'</td><td>' + [Espaco_Livre (MB)]	+ 
					'</td><td>' + [Espaco_Livre (%)]	+ 
					'</td><td>' + [MAXSIZE]				+ 	
					'</td><td>' + [Growth]				+	'</td>'
	                                    
		FROM (           
				SELECT	TOP 5
						[Nm_Database], 
						ISNULL([Logical_Name], '-')							AS [Logical_Name], 
						ISNULL(CAST([Total_Reservado]	AS VARCHAR), '-')	AS [Total_Reservado], 
						ISNULL(CAST([Total_Utilizado]	AS VARCHAR), '-')	AS [Total_Utilizado],
						ISNULL(CAST([Espaco_Livre (MB)]	AS VARCHAR), '-')	AS [Espaco_Livre (MB)], 
						ISNULL(CAST([Espaco_Livre (%)]	AS VARCHAR), '-')	AS [Espaco_Livre (%)],
						ISNULL(CAST([MaxSize]			AS VARCHAR), '-')	AS [MAXSIZE], 
						ISNULL(CAST([Growth]			AS VARCHAR), '-')	AS [Growth]
				FROM  [dbo].[CheckList_Arquivos_Dados]
				ORDER BY	CAST(REPLACE([Total_Reservado], '-', 0) AS NUMERIC(15,2)) DESC,
							CAST(REPLACE([Total_Utilizado], '-', 0) AS NUMERIC(15,2)) DESC
				    
			  ) AS D ORDER BY	CAST(REPLACE([Total_Reservado], '-', 0) AS NUMERIC(15,2)) DESC,
								CAST(REPLACE([Total_Utilizado], '-', 0) AS NUMERIC(15,2)) DESC
		  FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @ArquivosDados_Table = REPLACE( REPLACE( REPLACE(@ArquivosDados_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @ArquivosDados_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Lógico</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Total Reservado (MB)</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Total Utilizado (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Espaco_Livre (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Espaco_Livre (%)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>MAXSIZE</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Growth</font></th>          
				</tr>'    
            + REPLACE( REPLACE( @ArquivosDados_Table, '&lt;', '<'), '&gt;', '>')   
            + '</table>'

	/***********************************************************************************************************************************
	--	Arquivos Log - Header
	***********************************************************************************************************************************/
	DECLARE @ArquivosLog_Header VARCHAR(MAX)
	SET @ArquivosLog_Header = '<font color=black size=5>'
	SET @ArquivosLog_Header = @ArquivosLog_Header + '<br/> TOP 5 - Informações dos Arquivos de Log (LDF) <br/>' 
	SET @ArquivosLog_Header = @ArquivosLog_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Arquivos Log - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @ArquivosLog_Table VARCHAR(MAX)
	SET @ArquivosLog_Table = CAST( (
		SELECT td =				  [Nm_Database]			+ 
					'</td><td>' + [Logical_Name]		+ 
					'</td><td>' + [Total_Reservado]		+ 
					'</td><td>' + [Total_Utilizado]		+ 		
					'</td><td>' + [Espaco_Livre (MB)]	+ 
					'</td><td>' + [Espaco_Livre (%)]	+ 
					'</td><td>' + [MAXSIZE]				+ 	
					'</td><td>' + [Growth]				+	'</td>'
	                                    
		FROM (           
				SELECT	TOP 5
						[Nm_Database], 
						ISNULL([Logical_Name], '-')							AS [Logical_Name], 
						ISNULL(CAST([Total_Reservado]	AS VARCHAR), '-')	AS [Total_Reservado], 
						ISNULL(CAST([Total_Utilizado]	AS VARCHAR), '-')	AS [Total_Utilizado],
						ISNULL(CAST([Espaco_Livre (MB)]	AS VARCHAR), '-')	AS [Espaco_Livre (MB)], 
						ISNULL(CAST([Espaco_Livre (%)]	AS VARCHAR), '-')	AS [Espaco_Livre (%)],
						ISNULL(CAST([MaxSize]			AS VARCHAR), '-')	AS [MAXSIZE], 
						ISNULL(CAST([Growth]			AS VARCHAR), '-')	AS [Growth]
				FROM  [dbo].[CheckList_Arquivos_Log]
				ORDER BY	CAST(REPLACE([Total_Reservado], '-', 0) AS NUMERIC(15,2)) DESC,
							CAST(REPLACE([Total_Utilizado], '-', 0) AS NUMERIC(15,2)) DESC
				    
			  ) AS D ORDER BY	CAST(REPLACE([Total_Reservado], '-', 0) AS NUMERIC(15,2)) DESC,
								CAST(REPLACE([Total_Utilizado], '-', 0) AS NUMERIC(15,2)) DESC
		  FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @ArquivosLog_Table = REPLACE( REPLACE( REPLACE(@ArquivosLog_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @ArquivosLog_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Lógico</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Total Reservado (MB)</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Total Utilizado (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Espaco_Livre (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Espaco_Livre (%)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>MAXSIZE</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Growth</font></th>          
				</tr>'    
            + REPLACE( REPLACE( @ArquivosLog_Table, '&lt;', '<'), '&gt;', '>')   
            + '</table>' 
            

	/***********************************************************************************************************************************
	--	Crescimento das Bases - Header
	***********************************************************************************************************************************/
	DECLARE @CrescimentoBases_Header VARCHAR(MAX)
	SET @CrescimentoBases_Header = '<font color=black size=5>'
	SET @CrescimentoBases_Header = @CrescimentoBases_Header + '<br/> TOP 10 - Crescimento das Bases <br/>'
	SET @CrescimentoBases_Header = @CrescimentoBases_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Crescimento das Bases - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @CrescimentoBases_Table VARCHAR(MAX)    
	SET @CrescimentoBases_Table = CAST( (    
		SELECT td = CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Nm_Database]	+ '</font>'
															ELSE [Nm_Database]   END  + '</td><td>'  +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Tamanho_Atual]	+ '</font>'
															ELSE [Tamanho_Atual] END  + '</td><td>'  +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_1_dia]	+ '</font>'
															ELSE [Cresc_1_dia]   END  + '</td><td>'  +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_15_dia]	+ '</font>'
															ELSE [Cresc_15_dia]  END  + '</td><td>'  +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_30_dia]	+ '</font>'
															ELSE [Cresc_30_dia]  END  + '</td><td>'  +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_60_dia]	+ '</font>'
															ELSE [Cresc_60_dia]  END  + '</td>'                                 
		FROM (           
				SELECT	TOP 10
						[Nm_Servidor], 
						[Nm_Database], 
						ISNULL(CAST([Tamanho_Atual] AS VARCHAR), '-') AS [Tamanho_Atual],
						ISNULL(CAST([Cresc_1_dia]   AS VARCHAR), '-') AS [Cresc_1_dia],
						ISNULL(CAST([Cresc_15_dia]  AS VARCHAR), '-') AS [Cresc_15_dia], 
						ISNULL(CAST([Cresc_30_dia]  AS VARCHAR), '-') AS [Cresc_30_dia],
						ISNULL(CAST([Cresc_60_dia]  AS VARCHAR), '-') AS [Cresc_60_dia]
				FROM [dbo].[CheckList_Database_Growth_Email]
				WHERE [Nm_Servidor] IS NOT NULL		-- REGISTROS NORMAIS
				
				UNION
				
				SELECT	[Nm_Servidor], 
						[Nm_Database], 
						ISNULL(CAST([Tamanho_Atual] AS VARCHAR), '-') AS [Tamanho_Atual], 
						ISNULL(CAST([Cresc_1_dia]   AS VARCHAR), '-') AS [Cresc_1_dia],
						ISNULL(CAST([Cresc_15_dia]  AS VARCHAR), '-') AS [Cresc_15_dia], 
						ISNULL(CAST([Cresc_30_dia]  AS VARCHAR), '-') AS [Cresc_30_dia],
						ISNULL(CAST([Cresc_60_dia]  AS VARCHAR), '-') AS [Cresc_60_dia]
				FROM [dbo].[CheckList_Database_Growth_Email]
				WHERE [Nm_Servidor] IS NULL			-- TOTAL GERAL
				
			  ) AS D ORDER BY	[Nm_Servidor] DESC,
								CAST(ABS(REPLACE([Cresc_1_dia],  '-', 0)) AS NUMERIC(15,2)) DESC,
								CAST(ABS(REPLACE([Cresc_15_dia], '-', 0)) AS NUMERIC(15,2)) DESC,
								CAST(ABS(REPLACE([Cresc_30_dia], '-', 0)) AS NUMERIC(15,2)) DESC,
								CAST(ABS(REPLACE([Cresc_60_dia], '-', 0)) AS NUMERIC(15,2)) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) )   
      
    SET @CrescimentoBases_Table = REPLACE( REPLACE( REPLACE( REPLACE(@CrescimentoBases_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')
    
	SET @CrescimentoBases_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Tamanho Atual (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 1 Dia (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 15 Dia (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 30 Dia (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 60 Dia (MB)</font></th>               
				</tr>'    
            + REPLACE( REPLACE( @CrescimentoBases_Table, '&lt;', '<'), '&gt;', '>')   
            + '</table>' 
                        

	/***********************************************************************************************************************************
	--	Crescimento das Tabelas - Header
	***********************************************************************************************************************************/
	DECLARE @CrescimentoTabelas_Header VARCHAR(MAX)
	SET @CrescimentoTabelas_Header = '<font color=black size=5>'
	SET @CrescimentoTabelas_Header = @CrescimentoTabelas_Header + '<br/> TOP 10 - Crescimento das Tabelas <br/>' 
	SET @CrescimentoTabelas_Header = @CrescimentoTabelas_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Crescimento das Tabelas - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @CrescimentoTabelas_Table VARCHAR(MAX)    
	SET @CrescimentoTabelas_Table = CAST( (    
		SELECT td = CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Nm_Database]	+ '</font>'
															ELSE [Nm_Database] END   + '</td><td>'	 +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Nm_Tabela]		+ '</font>'
															ELSE [Nm_Tabela] END	 + '</td><td>'	 +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Tamanho_Atual]	+ '</font>'
															ELSE [Tamanho_Atual] END + '</td><td>'   +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_1_dia]	+ '</font>'
															ELSE [Cresc_1_dia] END   + '</td><td>'	 +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_15_dia]	+ '</font>'
															ELSE [Cresc_15_dia] END  + '</td><td>'	 +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_30_dia]	+ '</font>'
															ELSE [Cresc_30_dia] END  + '</td><td>'	 +
					CASE WHEN [Nm_Database] = 'TOTAL GERAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Cresc_60_dia]	+ '</font>'
															ELSE [Cresc_60_dia] END  + '</td>'	                                    
		FROM (
				SELECT	TOP 10
						[Nm_Servidor], 
						[Nm_Database], 
						ISNULL([Nm_Tabela], '-')					   AS [Nm_Tabela], 
						ISNULL(CAST([Tamanho_Atual] AS VARCHAR),  '-') AS [Tamanho_Atual], 
						ISNULL(CAST([Cresc_1_dia]	AS VARCHAR),  '-') AS [Cresc_1_dia],
						ISNULL(CAST([Cresc_15_dia]	AS VARCHAR),  '-') AS [Cresc_15_dia], 
						ISNULL(CAST([Cresc_30_dia]	AS VARCHAR),  '-') AS [Cresc_30_dia],
						ISNULL(CAST([Cresc_60_dia]	AS VARCHAR),  '-') AS [Cresc_60_dia]
				FROM [dbo].[CheckList_Table_Growth_Email]
				WHERE [Nm_Servidor] IS NOT NULL		-- REGISTROS NORMAIS
							
				UNION ALL
				
				SELECT	[Nm_Servidor], 
						[Nm_Database], 
						ISNULL([Nm_Tabela], '-')					   AS [Nm_Tabela], 
						ISNULL(CAST([Tamanho_Atual] AS VARCHAR),  '-') AS [Tamanho_Atual], 
						ISNULL(CAST([Cresc_1_dia]	AS VARCHAR),  '-') AS [Cresc_1_dia],
						ISNULL(CAST([Cresc_15_dia]	AS VARCHAR),  '-') AS [Cresc_15_dia], 
						ISNULL(CAST([Cresc_30_dia]	AS VARCHAR),  '-') AS [Cresc_30_dia],
						ISNULL(CAST([Cresc_60_dia]	AS VARCHAR),  '-') AS [Cresc_60_dia]
				FROM [dbo].[CheckList_Table_Growth_Email]
				WHERE [Nm_Servidor] IS NULL			-- TOTAL GERAL
				
			  ) AS D ORDER BY	[Nm_Servidor] DESC,
								CAST(ABS(REPLACE([Cresc_1_dia],  '-', 0)) AS NUMERIC(15,2)) DESC,
								CAST(ABS(REPLACE([Cresc_15_dia], '-', 0)) AS NUMERIC(15,2)) DESC,
								CAST(ABS(REPLACE([Cresc_30_dia], '-', 0)) AS NUMERIC(15,2)) DESC,
								CAST(ABS(REPLACE([Cresc_60_dia], '-', 0)) AS NUMERIC(15,2)) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @CrescimentoTabelas_Table = REPLACE( REPLACE( REPLACE( REPLACE(@CrescimentoTabelas_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')
    
	SET @CrescimentoTabelas_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Tabela</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Tamanho Atual (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 1 Dia (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 15 Dia (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 30 Dia (MB)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Cresc. 60 Dia (MB)</font></th>
				</tr>'    
            + REPLACE( REPLACE(@CrescimentoTabelas_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'


	/***********************************************************************************************************************************
	--	Utilizacao Arquivos Database - Writes - Header
	***********************************************************************************************************************************/
	DECLARE @UtilizacaoArqWrites_Header VARCHAR(MAX)
	SET @UtilizacaoArqWrites_Header = '<font color=black size=5>'
	SET @UtilizacaoArqWrites_Header = @UtilizacaoArqWrites_Header + '<br/> TOP 10 - Utilização Arquivos Databases - Writes (09:00 - 18:00) <br/>'
	SET @UtilizacaoArqWrites_Header = @UtilizacaoArqWrites_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Utilizacao Arquivos Database - Writes - Informações
	------------------------------------------------------------------------------------------------------------------------------------ 
	DECLARE @UtilizacaoArqWrites_Table VARCHAR(MAX)
	SET @UtilizacaoArqWrites_Table = CAST( (    
		SELECT td =				  Nm_Database			+ 
					'</td><td>' + file_id				+		
					'</td><td>' + io_stall_write_ms		+ 
					'</td><td>' + num_of_writes			+
					'</td><td>' + [avg_write_stall_ms]	+	'</td>'                                     
		FROM (           
				select	Nm_Database,
						ISNULL(CAST(file_id AS VARCHAR), '-') AS file_id,
						ISNULL(CAST(io_stall_write_ms AS VARCHAR), '-') AS io_stall_write_ms,
						ISNULL(CAST(num_of_writes AS VARCHAR), '-') AS num_of_writes,
						ISNULL(CAST([avg_write_stall_ms] AS VARCHAR), '-') AS [avg_write_stall_ms]
				from [dbo].[CheckList_Utilizacao_Arquivo_Writes]
				
			  ) AS D ORDER BY	CAST(CAST(REPLACE([avg_write_stall_ms], '-', 0) AS VARCHAR) AS NUMERIC(15,1)) DESC, 
								CAST(REPLACE(num_of_writes, '-', 0) AS BIGINT) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX)
	)   
      
    SET @UtilizacaoArqWrites_Table = REPLACE( REPLACE( REPLACE(@UtilizacaoArqWrites_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @UtilizacaoArqWrites_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>File ID</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>io_stall_write_ms</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>num_of_writes</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>avg_write_stall_ms</font></th>
				</tr>'    
			+ REPLACE( REPLACE(@UtilizacaoArqWrites_Table, '&lt;', '<'), '&gt;', '>')
			+ '</table>' 
			
			
	/***********************************************************************************************************************************
	--	Utilizacao Arquivos Database - Reads - Header
	***********************************************************************************************************************************/
	DECLARE @UtilizacaoArqReads_Header VARCHAR(MAX)
	SET @UtilizacaoArqReads_Header = '<font color=black size=5>'
	SET @UtilizacaoArqReads_Header = @UtilizacaoArqReads_Header + '<br/> TOP 10 - Utilização Arquivos Databases - Reads (09:00 - 18:00) <br/>'
	SET @UtilizacaoArqReads_Header = @UtilizacaoArqReads_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Utilizacao Arquivos Database - Reads - Informações
	------------------------------------------------------------------------------------------------------------------------------------ 
	DECLARE @UtilizacaoArqReads_Table VARCHAR(MAX)
	SET @UtilizacaoArqReads_Table = CAST( (    
		SELECT td =				  Nm_Database			+ 
					'</td><td>' + file_id				+		
					'</td><td>' + io_stall_read_ms		+ 
					'</td><td>' + num_of_reads			+
					'</td><td>' + [avg_read_stall_ms]	+	'</td>'                                     
		FROM (           
				select	Nm_Database,
						ISNULL(CAST(file_id AS VARCHAR), '-') AS file_id,
						ISNULL(CAST(io_stall_read_ms AS VARCHAR), '-') AS io_stall_read_ms,
						ISNULL(CAST(num_of_reads AS VARCHAR), '-') AS num_of_reads,
						ISNULL(CAST([avg_read_stall_ms] AS VARCHAR), '-') AS [avg_read_stall_ms]
				from [dbo].[CheckList_Utilizacao_Arquivo_Reads]
				
			  ) AS D ORDER BY	CAST(CAST(REPLACE([avg_read_stall_ms], '-', 0) AS VARCHAR) AS NUMERIC(15,1)) DESC, 
								CAST(REPLACE(num_of_reads, '-', 0) AS BIGINT) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @UtilizacaoArqReads_Table = REPLACE( REPLACE( REPLACE(@UtilizacaoArqReads_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @UtilizacaoArqReads_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>File ID</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>io_stall_read_ms</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>num_of_reads</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>avg_read_stall_ms</font></th>
				</tr>'    
			+ REPLACE( REPLACE(@UtilizacaoArqReads_Table, '&lt;', '<'), '&gt;', '>')
			+ '</table>'


	/***********************************************************************************************************************************
	--	Databases Sem Backup - Header
	***********************************************************************************************************************************/
	DECLARE @DatabaseSemBackup_Header VARCHAR(MAX)
	SET @DatabaseSemBackup_Header = '<font color=black size=5>'
	SET @DatabaseSemBackup_Header = @DatabaseSemBackup_Header + '<br/> TOP 10 - Databases Sem Backup nas últimas 16 Horas <br/>'
	SET @DatabaseSemBackup_Header = @DatabaseSemBackup_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Databases Sem Backup - Informações
	------------------------------------------------------------------------------------------------------------------------------------ 
	DECLARE @DatabaseSemBackup_Table VARCHAR(MAX)
	SET @DatabaseSemBackup_Table = CAST( (    
		SELECT td = [Nm_Database] + '</td>'  		                                    
		FROM (           
				SELECT	TOP 10 
						CASE 
							WHEN	[Nm_Database] <> 'Sem registro de Databases Sem Backup nas últimas 16 horas.'
								THEN ' bgcolor=yellow>' 
								ELSE '' 
						END + 
						[Nm_Database] AS [Nm_Database]
				FROM [dbo].[CheckList_Databases_Sem_Backup]	
				ORDER BY [Nm_Database]			
				
			  ) AS D ORDER BY [Nm_Database]
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
        
	SET @DatabaseSemBackup_Table =	REPLACE( REPLACE( REPLACE( REPLACE(@DatabaseSemBackup_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')

	SET @DatabaseSemBackup_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="250" bgcolor=#0B0B61><font color=white>Nome Database</font></th>         
				</tr>'    
			+ REPLACE( REPLACE(@DatabaseSemBackup_Table, '&lt;', '<'), '&gt;', '>')			
			+ '</table>' 


	/***********************************************************************************************************************************
	--	Backups Executados - Header
	***********************************************************************************************************************************/
	DECLARE @Backup_Header VARCHAR(MAX)
	SET @Backup_Header = '<font color=black size=5>'
	SET @Backup_Header = @Backup_Header + '<br/> TOP 10 - Backup FULL e Diferencial das Bases <br/>'
	SET @Backup_Header = @Backup_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Backups Executados - Informações
	------------------------------------------------------------------------------------------------------------------------------------ 
	DECLARE @Backup_Table VARCHAR(MAX)
	SET @Backup_Table = CAST( (    
		SELECT td =				  [Database_Name]		+ 
					'</td><td>' + [Backup_Start_Date]	+ 
					'</td><td>' + [Tempo_Min]			+
					'</td><td>' + [Recovery_Model]		+ 
					'</td><td>' + [Tipo]				+ 		
					'</td><td>' + [Tamanho_MB]			+	'</td>'                                     
		FROM (           
				SELECT	TOP 10
						[Database_Name], 
						ISNULL(CONVERT(VARCHAR, [Backup_Start_Date], 120), '-') AS [Backup_Start_Date], 
						ISNULL(CAST([Tempo_Min] AS VARCHAR), '-')				AS [Tempo_Min],
						ISNULL(CAST([Recovery_Model] AS VARCHAR), '-')			AS [Recovery_Model],
						ISNULL(
							CASE [Type]
								WHEN 'D' THEN 'FULL'
								WHEN 'I' THEN 'Diferencial'
								WHEN 'L' THEN 'Log'
							END, '-')											AS [Tipo],
						ISNULL(CAST([Tamanho_MB] AS VARCHAR), '-')				AS [Tamanho_MB]
				FROM [dbo].[CheckList_Backups_Executados]
				ORDER BY CAST(ABS(REPLACE([Tamanho_MB], '-', 0)) AS NUMERIC(15,2)) DESC
				
			  ) AS D ORDER BY CAST(ABS(REPLACE([Tamanho_MB], '-', 0)) AS NUMERIC(15,2)) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @Backup_Table = REPLACE( REPLACE( REPLACE(@Backup_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @Backup_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="170" bgcolor=#0B0B61><font color=white>Nome Database</font></th>
					<th width="170" bgcolor=#0B0B61><font color=white>Horário Execução</font></th>
					<th width="120" bgcolor=#0B0B61><font color=white>Tempo (min)</font></th>
					<th width="120" bgcolor=#0B0B61><font color=white>Recovery</font></th>
					<th width="120" bgcolor=#0B0B61><font color=white>Tipo Backup</font></th>
					<th width="120" bgcolor=#0B0B61><font color=white>Tamanho (MB)</font></th>             
				</tr>'    
			+ REPLACE( REPLACE(@Backup_Table, '&lt;', '<'), '&gt;', '>')
			+ '</table>'


	/***********************************************************************************************************************************
	--	Queries em Execução - Header
	***********************************************************************************************************************************/ 
	DECLARE @QueriesRunning_Header VARCHAR(MAX)
	SET @QueriesRunning_Header = '<font color=black size=5>'
	SET @QueriesRunning_Header = @QueriesRunning_Header + '<br/> TOP 5 - Queries em Execução a mais de 2 horas <br/>' 
	SET @QueriesRunning_Header = @QueriesRunning_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Queries em Execução - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @QueriesRunning_Table VARCHAR(MAX)    
	SET @QueriesRunning_Table = CAST( (    
		SELECT td =				  [dd hh:mm:ss.mss]			+ 
					'</td><td>' + [database_name]		+ 
					'</td><td>' + [login_name]		+ 
					'</td><td>' + [host_name]		+ 
					'</td><td>' + [start_time]		+
					'</td><td>' + [status]		+ 
					'</td><td>' + [session_id]		+
					'</td><td>' + [blocking_session_id]		+ 
					'</td><td>' + [wait_info]		+
					'</td><td>' + [open_tran_count]		+ 
					'</td><td>' + [CPU]		+
					'</td><td>' + [reads]		+ 
					'</td><td>' + [writes]		+
					'</td><td>' + [sql_command]			+ 	'</td>'                                     
		FROM (	
				SELECT	TOP 5
						ISNULL([dd hh:mm:ss.mss], '-')									AS [dd hh:mm:ss.mss], 
						[database_name], 
						ISNULL([login_name], '-')										AS [login_name], 
						ISNULL([host_name], '-')										AS [host_name], 
						ISNULL(CONVERT(VARCHAR(20), [start_time], 120), '-')			AS [start_time], 
						ISNULL([status], '-')											AS [status], 
						ISNULL(CAST([session_id] AS VARCHAR), '-')						AS [session_id], 
						ISNULL(CAST([blocking_session_id] AS VARCHAR), '-')				AS [blocking_session_id], 
						ISNULL([wait_info], '-')										AS [wait_info], 
						ISNULL(CAST([open_tran_count] AS VARCHAR), '-')					AS [open_tran_count], 
						ISNULL(CAST([CPU] AS VARCHAR), '-')								AS [CPU], 
						ISNULL(CAST([reads] AS VARCHAR), '-')							AS [reads], 
						ISNULL(CAST([writes] AS VARCHAR), '-')							AS [writes], 
						ISNULL(SUBSTRING(CAST([sql_command] AS VARCHAR), 1, 150), '-')	AS [sql_command]						
				FROM [dbo].[CheckList_Queries_Running]
				ORDER BY [start_time]

			  ) AS D ORDER BY [start_time]
		FOR XML PATH( 'tr' )) AS VARCHAR(MAX) 
	)   
      
    SET @QueriesRunning_Table = REPLACE( REPLACE( REPLACE(@QueriesRunning_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @QueriesRunning_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="150" bgcolor=#0B0B61><font color=white>dd hh:mm:ss.mss</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Database</font></th> 
					<th width="150" bgcolor=#0B0B61><font color=white>Login</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Host Name</font></th>        
					<th width="150" bgcolor=#0B0B61><font color=white>Hora Início</font></th>
					<th width="100" bgcolor=#0B0B61><font color=white>Status</font></th> 
					<th width="100" bgcolor=#0B0B61><font color=white>Session ID</font></th>
					<th width="100" bgcolor=#0B0B61><font color=white>Blocking Session ID</font></th>   
					<th width="150" bgcolor=#0B0B61><font color=white>Wait Info</font></th>
					<th width="100" bgcolor=#0B0B61><font color=white>Transações Abertas</font></th> 
					<th width="100" bgcolor=#0B0B61><font color=white>CPU</font></th>
					<th width="100" bgcolor=#0B0B61><font color=white>Reads</font></th> 
					<th width="100" bgcolor=#0B0B61><font color=white>Writes</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Query</font></th>   
				</tr>'    
            + REPLACE( REPLACE(@QueriesRunning_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'

	/***********************************************************************************************************************************
	--	Jobs em Execução - Header
	***********************************************************************************************************************************/ 
	DECLARE @JobsRunning_Header VARCHAR(MAX)
	SET @JobsRunning_Header = '<font color=black size=5>'
	SET @JobsRunning_Header = @JobsRunning_Header + '<br/> TOP 10 - Jobs em Execução <br/>' 
	SET @JobsRunning_Header = @JobsRunning_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Jobs em Execução - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @JobsRunning_Table VARCHAR(MAX)    
	SET @JobsRunning_Table = CAST( (    
		SELECT td =				  [Nm_JOB]			+ 
					'</td><td>' + [Dt_Inicio]		+ 
					'</td><td>' + [Qt_Duracao]		+ 
					'</td><td>' + [Nm_Step]			+ 	'</td>'                                     
		FROM (	
				SELECT	TOP 10
						[Nm_JOB], 
						ISNULL(CONVERT(VARCHAR(16), [Dt_Inicio],120), '-')	AS [Dt_Inicio], 
						ISNULL(Qt_Duracao, '-')								AS [Qt_Duracao], 
						ISNULL([Nm_Step], '-')								AS [Nm_Step]
				FROM [dbo].[CheckList_Jobs_Running]
				ORDER BY [Dt_Inicio]
				
			  ) AS D ORDER BY [Dt_Inicio]
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @JobsRunning_Table = REPLACE( REPLACE( REPLACE(@JobsRunning_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @JobsRunning_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Job</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Data Início</font></th> 
					<th width="200" bgcolor=#0B0B61><font color=white>Duração</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Nome Step</font></th>        
				</tr>'    
            + REPLACE( REPLACE(@JobsRunning_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'

	
	/***********************************************************************************************************************************
	--	Jobs Alterados - Header
	***********************************************************************************************************************************/ 
	DECLARE @JobsAlterados_Header VARCHAR(MAX)
	SET @JobsAlterados_Header = '<font color=black size=5>'
	SET @JobsAlterados_Header = @JobsAlterados_Header + '<br/> TOP 10 - Jobs Alterados <br/>'
	SET @JobsAlterados_Header = @JobsAlterados_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Jobs Alterados - Informações
	------------------------------------------------------------------------------------------------------------------------------------ 
	DECLARE @JobsAlterados_Table VARCHAR(MAX)    
	SET @JobsAlterados_Table = CAST( (    
		SELECT td =				  [Nm_Job]			+ 
					'</td><td>' + [Fl_Habilitado]	+ 
					'</td><td>' + [Dt_Criacao]		+ 
					'</td><td>' + [Dt_Modificacao]  + 
					'</td><td>' + [Nr_Versao]		+	'</td>'                                     
		FROM (	
				SELECT	TOP 10
						[Nm_Job], 
						ISNULL(
							CASE [Fl_Habilitado] 
								WHEN 1 THEN 'SIM' 
								WHEN 0 THEN 'NÃO' 
							END, '-')											AS [Fl_Habilitado], 
						ISNULL(CONVERT(VARCHAR, [Dt_Criacao], 120), '-')		AS [Dt_Criacao],
						ISNULL(CONVERT(VARCHAR, [Dt_Modificacao], 120), '-')	AS [Dt_Modificacao],
						ISNULL(CAST([Nr_Versao] AS VARCHAR), '-')				AS [Nr_Versao]
				FROM [dbo].[CheckList_Alteracao_Jobs]
				ORDER BY [Dt_Modificacao] DESC
				
			  ) AS D 
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @JobsAlterados_Table = REPLACE( REPLACE( REPLACE( @JobsAlterados_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @JobsAlterados_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Job</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Habilitado</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Data Criação</font></th>    
					<th width="200" bgcolor=#0B0B61><font color=white>Data Alteração</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Núm. Versão</font></th>        
				</tr>'    
            + REPLACE( REPLACE(@JobsAlterados_Table, '&lt;', '<'), '&gt;', '>')   
            + '</table>' 


	/***********************************************************************************************************************************
	--	Jobs que Falharam - Header
	***********************************************************************************************************************************/
	DECLARE @JobsFailed_Header VARCHAR(MAX)
	SET @JobsFailed_Header = '<font color=black size=5>'
	SET @JobsFailed_Header = @JobsFailed_Header + '<br/> TOP 10 - Jobs que Falharam <br/>'
	SET @JobsFailed_Header = @JobsFailed_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Jobs que Falharam - Informações
	------------------------------------------------------------------------------------------------------------------------------------ 
	DECLARE @JobsFailed_Table VARCHAR(MAX)    
	SET @JobsFailed_Table = CAST( (    
		SELECT td =				  [Job_Name]	 +
					'</td><td>' + [Status]		 + 
					'</td><td>' + [Dt_Execucao]  + 
					'</td><td>' + [Run_Duration] + 
					'</td><td>' + [SQL_Message]  +	'</td>'                                     
		FROM (
				SELECT	TOP 10
						[Job_Name], 
						ISNULL([Status], '-')								AS [Status], 
						ISNULL(CONVERT(VARCHAR, [Dt_Execucao], 120), '-')	AS [Dt_Execucao], 
						ISNULL([Run_Duration], '-')							AS [Run_Duration], 
						ISNULL([SQL_Message], '-')							AS [SQL_Message]
				FROM [dbo].[CheckList_Jobs_Failed]
				ORDER BY [Dt_Execucao] DESC
				
			  ) AS D ORDER BY [Dt_Execucao] DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @JobsFailed_Table = REPLACE( REPLACE( REPLACE(@JobsFailed_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @JobsFailed_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Job</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Status</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Horário Execução</font></th>    
					<th width="200" bgcolor=#0B0B61><font color=white>Duração (hh:mm:ss)</font></th>
					<th width="400" bgcolor=#0B0B61><font color=white>Mensagem</font></th>        
				</tr>'
            + REPLACE( REPLACE(@JobsFailed_Table, '&lt;', '<'), '&gt;', '>')   
            + '</table>'


	/***********************************************************************************************************************************
	--	Jobs Demorados - Header
	***********************************************************************************************************************************/ 
	DECLARE @TempoJobs_Header VARCHAR(MAX)
	SET @TempoJobs_Header = '<font color=black size=5>'
	SET @TempoJobs_Header = @TempoJobs_Header + '<br/> TOP 10 - Jobs Demorados <br/>' 
	SET @TempoJobs_Header = @TempoJobs_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Jobs Demorados - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @TempoJobs_Table VARCHAR(MAX)    
	SET @TempoJobs_Table = CAST( (    
		SELECT td =				  [Job_Name]	 + 
					'</td><td>' + [Status]		 + 
					'</td><td>' + [Dt_Execucao]  + 
					'</td><td>' + [Run_Duration] + 
					'</td><td>' + [SQL_Message]	 +	'</td>'                                     
		FROM (	
				SELECT	TOP 10
						[Job_Name], 
						ISNULL([Status], '-')								AS [Status], 
						ISNULL(CONVERT(VARCHAR, [Dt_Execucao], 120), '-')	AS [Dt_Execucao], 
						ISNULL([Run_Duration], '-')							AS [Run_Duration], 
						ISNULL([SQL_Message], '-')							AS [SQL_Message]
				FROM [dbo].[CheckList_Job_Demorados]
				ORDER BY [Run_Duration] DESC
				
			  ) AS D 
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @TempoJobs_Table = REPLACE( REPLACE( REPLACE(@TempoJobs_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @TempoJobs_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Job</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Status</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Horário Execução</font></th>    
					<th width="200" bgcolor=#0B0B61><font color=white>Duração</font></th>
					<th width="400" bgcolor=#0B0B61><font color=white>Mensagem</font></th>        
				</tr>'    
            + REPLACE( REPLACE(@TempoJobs_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'


	/***********************************************************************************************************************************
	--	Queries Demoradas - Header
	***********************************************************************************************************************************/
	DECLARE @QueriesDemoradas_Header VARCHAR(MAX)
	SET @QueriesDemoradas_Header = '<font color=black size=5>'
	SET @QueriesDemoradas_Header = @QueriesDemoradas_Header + '<br/> TOP 10 - Queries Demoradas Dia Anterior (07:00 - 23:00) <br/>'
	SET @QueriesDemoradas_Header = @QueriesDemoradas_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Queries Demoradas - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @QueriesDemoradas_Table VARCHAR(MAX)    
	SET @QueriesDemoradas_Table = CAST( (    
		SELECT td =	CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [PrefixoQuery]	+ '</font>'
														ELSE [PrefixoQuery] END  + '</td><td>'	 +
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [QTD]			+ '</font>'
														ELSE [QTD] END			 + '</td><td>'   +
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Total]			+ '</font>'
														ELSE [Total] END		 + '</td><td>'   +
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Media]			+ '</font>'
														ELSE [Media] END		 + '</td><td>'   + 
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Menor]			+ '</font>'
														ELSE [Menor] END		 + '</td><td>'   + 
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Maior]			+ '</font>'
														ELSE [Maior] END		 + '</td><td>'   + 
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Writes]			+ '</font>'
														ELSE [Writes] END		 + '</td><td>'   +
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [CPU]				+ '</font>'
														ELSE [CPU] END			 + '</td><td>'	 +
					CASE WHEN [PrefixoQuery] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Reads]			+ '</font>'
														ELSE [Reads] END			 + '</td>'
		FROM (	
				SELECT	[dbo].[fncRetira_Caractere_Invalido_XML] ([PrefixoQuery])	AS [PrefixoQuery],
						ISNULL(CAST([QTD]	 AS VARCHAR), '-')						AS [QTD],
						ISNULL(CAST([Total]  AS VARCHAR), '-')						AS [Total],
						ISNULL(CAST([Media]  AS VARCHAR), '-')						AS [Media],
						ISNULL(CAST([Menor]  AS VARCHAR), '-')						AS [Menor],
						ISNULL(CAST([Maior]  AS VARCHAR), '-')						AS [Maior],
						ISNULL(CAST([Writes] AS VARCHAR), '-')						AS [Writes],
						ISNULL(CAST([CPU]	 AS VARCHAR), '-')						AS [CPU],
						ISNULL(CAST([Reads]	 AS VARCHAR), '-')						AS [Reads],
						[Ordem]
				FROM [dbo].[CheckList_Traces_Queries]			
			
			  ) AS D ORDER BY [Ordem], LEN([QTD]) DESC, [QTD] DESC
		FOR XML PATH( 'tr' )) AS VARCHAR(MAX) 
	)
	
	-- Correção de BUG de caractere invalido no FOR XML (character (0x0000))
	SELECT @QueriesDemoradas_Table = REPLACE(@QueriesDemoradas_Table, '&#x00;', '')
	  
    SET @QueriesDemoradas_Table = REPLACE( REPLACE( REPLACE( REPLACE(@QueriesDemoradas_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')
    
	SET @QueriesDemoradas_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="400" bgcolor=#0B0B61><font color=white>Prefixo Query (150 caracteres iniciais)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Qtd</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Total (s)</font></th>    
					<th width="150" bgcolor=#0B0B61><font color=white>Média (s)</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Menor (s)</font></th>       
					<th width="150" bgcolor=#0B0B61><font color=white>Maior (s)</font></th>     
					<th width="150" bgcolor=#0B0B61><font color=white>Writes</font></th> 
					<th width="150" bgcolor=#0B0B61><font color=white>CPU</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Reads</font></th>
				</tr>'    
            + REPLACE( REPLACE(@QueriesDemoradas_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'


	/***********************************************************************************************************************************
	--	Queries Demoradas Geral - Header
	***********************************************************************************************************************************/ 
	DECLARE @QueriesDemoradasGeral_Header VARCHAR(MAX)
	SET @QueriesDemoradasGeral_Header = '<font color=black size=5>'
	SET @QueriesDemoradasGeral_Header = @QueriesDemoradasGeral_Header + '<br/> TOP 10 - Queries Demoradas - Últimos 10 Dias (07:00 - 23:00) <br/>' 
	SET @QueriesDemoradasGeral_Header = @QueriesDemoradasGeral_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Queries Demoradas Geral - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @QueriesDemoradasGeral_Table VARCHAR(MAX)    
	SET @QueriesDemoradasGeral_Table = CAST( (    
		SELECT td =				  [Data]	+ 
					'</td><td>' + [QTD]		+	'</td>'                                     
		FROM (	
				SELECT	[Data], 
						ISNULL(CAST([QTD] AS VARCHAR), '-')		AS [QTD]
				FROM [dbo].[CheckList_Traces_Queries_Geral]
				
			  ) AS D ORDER BY [Data] DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @QueriesDemoradasGeral_Table = REPLACE( REPLACE( REPLACE(@QueriesDemoradasGeral_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @QueriesDemoradasGeral_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="200" bgcolor=#0B0B61><font color=white>Data</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Quantidade</font></th>      
				</tr>'    
            + REPLACE( REPLACE(@QueriesDemoradasGeral_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'


	/***********************************************************************************************************************************
	--	Contadores -  Header
	***********************************************************************************************************************************/
	DECLARE @Contadores_Header VARCHAR(MAX)
	SET @Contadores_Header = '<font color=black size=5>'
	SET @Contadores_Header = @Contadores_Header + '<br/> Média Contadores Dia Anterior (07:00 - 23:00) <br/>' 
	SET @Contadores_Header = @Contadores_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Contadores - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Contadores_Table VARCHAR(MAX)    

	SET @Contadores_Table = CAST( (    
		SELECT td =				  [Hora]				 + 	
					'</td><td>' + [BatchRequests]		 + 
					'</td><td>' + [CPU]					 + 
					'</td><td>' + [Page_Life_Expectancy] + 	
					'</td><td>' + [User_Connection]		 +
					'</td><td>' + [Qtd_Queries_Lentas]	 + 	
					'</td><td>' + [Reads_Queries_Lentas] +	'</td>'                                  
		FROM (           
				SELECT	[Hora],
						[BatchRequests],
						[CPU],
						[Page_Life_Expectancy],
						[User_Connection],
						[Qtd_Queries_Lentas],
						[Reads_Queries_Lentas]
				FROM [dbo].[CheckList_Contadores_Email] AS C		
				
			  ) AS D ORDER BY LEN([Hora]), [Hora]
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @Contadores_Table = REPLACE( REPLACE( REPLACE( @Contadores_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @Contadores_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'
            +	'<tr>
					<th width="200" bgcolor=#0B0B61><font color=white>Hora</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Batch Requests</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>CPU</font></th>    
					<th width="200" bgcolor=#0B0B61><font color=white>Page Life Expectancy</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Número de Conexões</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Qtd Queries Lentas</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Reads Queries Lentas</font></th>
				</tr>'    
            + REPLACE( REPLACE(@Contadores_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'

	/***********************************************************************************************************************************
	--	Conexoes Abertas - Header
	***********************************************************************************************************************************/ 
	DECLARE @ConexoesAbertas_Header VARCHAR(MAX)
	SET @ConexoesAbertas_Header = '<font color=black size=5>'
	SET @ConexoesAbertas_Header = @ConexoesAbertas_Header + '<br/> TOP 10 - Conexões Abertas por Usuários <br/>' 
	SET @ConexoesAbertas_Header = @ConexoesAbertas_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Conexoes Abertas - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @ConexoesAbertas_Table VARCHAR(MAX)    
	SET @ConexoesAbertas_Table = CAST( (    
		SELECT td = CASE WHEN [login_name] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [login_name]		+ '</font>'
														ELSE [login_name]   END  + '</td><td>'  +
					CASE WHEN [login_name] = 'TOTAL '	THEN ' bgcolor=#0B0B61><font color=white>' + [session_count]	+ '</font>'
															ELSE [session_count]  END  + '</td>'					                          
		FROM (	
				SELECT	Nr_Ordem,
						ISNULL([login_name], '-')			AS [login_name], 
						CAST([session_count] AS VARCHAR)	AS [session_count]
				FROM [dbo].[CheckList_Conexao_Aberta_Email]
				
			  ) AS D ORDER BY Nr_Ordem, CAST([session_count] AS INT) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    --SET @ConexoesAbertas_Table = REPLACE( REPLACE( REPLACE(@ConexoesAbertas_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @ConexoesAbertas_Table = REPLACE( REPLACE( REPLACE( REPLACE(@ConexoesAbertas_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')

	SET @ConexoesAbertas_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="400" bgcolor=#0B0B61><font color=white>Login Name</font></th> 
					<th width="200" bgcolor=#0B0B61><font color=white>Qtd Conexões</font></th>     
				</tr>'    
            + REPLACE( REPLACE(@ConexoesAbertas_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'


	/***********************************************************************************************************************************
	--	Fragmentação de Índices - Header
	***********************************************************************************************************************************/
	DECLARE @FragmentacaoIndice_Header VARCHAR(MAX)
	SET @FragmentacaoIndice_Header = '<font color=black size=5>'
	SET @FragmentacaoIndice_Header = @FragmentacaoIndice_Header + '<br/> TOP 10 - Fragmentação dos Índices <br/>'
	SET @FragmentacaoIndice_Header = @FragmentacaoIndice_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Fragmentação de Índices - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @FragmentacaoIndice_Table VARCHAR(MAX)    

	SET @FragmentacaoIndice_Table = CAST( (
		SELECT td =				  [Dt_Referencia]				 +
					'</td><td>' + [Nm_Database]					 +
					'</td><td>' + [Nm_Tabela]					 +
					'</td><td>' + [Nm_Indice]					 +
					'</td><td>' + [Avg_Fragmentation_In_Percent] +
					'</td><td>' + [Page_Count]					 +
					'</td><td>' + [Fill_Factor]					 +
					'</td><td>' + [Compressao]					 +	'</td>'
		FROM (
				SELECT	TOP 10
						ISNULL(CONVERT(VARCHAR, [Dt_Referencia], 120), '-')				AS [Dt_Referencia], 
						[Nm_Database], 
						ISNULL([Nm_Tabela], '-')										AS [Nm_Tabela], 
						ISNULL([Nm_Indice], '-')										AS [Nm_Indice],
						ISNULL(CAST([Avg_Fragmentation_In_Percent]	AS VARCHAR), '-')	AS [Avg_Fragmentation_In_Percent],
						ISNULL(CAST([Page_Count]					AS VARCHAR), '-')	AS [Page_Count], 
						ISNULL(CAST([Fill_Factor]					AS VARCHAR), '-')	AS [Fill_Factor],
						ISNULL(	
							CASE [Fl_Compressao]
								WHEN 0 THEN 'Sem Compressão'
								WHEN 1 THEN 'Compressão de Linha' 
								WHEN 2 THEN 'Compressao de Página'
							END, '-') AS [Compressao]
				FROM [dbo].[CheckList_Fragmentacao_Indices]
				ORDER BY CAST(REPLACE([Avg_Fragmentation_In_Percent], '-', 0)  AS NUMERIC(15,2)) DESC
				
		  ) AS D 
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @FragmentacaoIndice_Table = REPLACE( REPLACE( REPLACE( @FragmentacaoIndice_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @FragmentacaoIndice_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="200" bgcolor=#0B0B61><font color=white>Referencia</font></th>
					<th width="300" bgcolor=#0B0B61><font color=white>Database</font></th>
					<th width="300" bgcolor=#0B0B61><font color=white>Tabela</font></th>    
					<th width="200" bgcolor=#0B0B61><font color=white>Indice</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Fragmentacao (%)</font></th>      
					<th width="200" bgcolor=#0B0B61><font color=white>Qtd Páginas</font></th>   
					<th width="200" bgcolor=#0B0B61><font color=white>Fill Factor (%)</font></th> 
					<th width="200" bgcolor=#0B0B61><font color=white>Compressão de Dados</font></th> 
				</tr>'    
            + REPLACE( REPLACE( @FragmentacaoIndice_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'
	
	
	/***********************************************************************************************************************************
	--	Waits Stats -  Header
	***********************************************************************************************************************************/
	DECLARE @WaitsStats_Header VARCHAR(MAX)
	SET @WaitsStats_Header = '<font color=black size=5>'
	SET @WaitsStats_Header = @WaitsStats_Header + '<br/> TOP 10 - Waits Stats Dia Anterior (07:00 - 23:00) <br/>'
	SET @WaitsStats_Header = @WaitsStats_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Waits Stats - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @WaitsStats_Table VARCHAR(MAX)    

	SET @WaitsStats_Table = CAST( (    
		SELECT td =				  [WaitType]		+
					'</td><td>' + [Max_Log]			+
					'</td><td>' + [DIf_Wait_S]		+
					'</td><td>' + [DIf_Resource_S]	+
					'</td><td>' + [DIf_Signal_S]	+
					'</td><td>' + [DIf_WaitCount]	+
					'</td><td>' + [Last_Percentage] +	'</td>'                                     
		FROM (           
				SELECT	TOP 10
						[WaitType], 
						ISNULL(CONVERT(VARCHAR, [Max_Log], 120),     '-') AS [Max_Log],
						ISNULL(CAST([DIf_Wait_S]		AS VARCHAR), '-') AS [DIf_Wait_S], 
						ISNULL(CAST([DIf_Resource_S]	AS VARCHAR), '-') AS [DIf_Resource_S],
						ISNULL(CAST([DIf_Signal_S]		AS VARCHAR), '-') AS [DIf_Signal_S], 
						ISNULL(CAST([DIf_WaitCount]		AS VARCHAR), '-') AS [DIf_WaitCount],
						ISNULL(CAST([Last_Percentage]	AS VARCHAR), '-') AS [Last_Percentage]
				FROM [dbo].[CheckList_Waits_Stats]
				ORDER BY CAST(REPLACE([DIf_Wait_S], '-', 0) AS NUMERIC(15,2)) DESC			
			
		  ) AS D ORDER BY CAST(REPLACE([DIf_Wait_S], '-', 0) AS NUMERIC(15,2)) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @WaitsStats_Table = REPLACE( REPLACE( REPLACE( @WaitsStats_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @WaitsStats_Table =
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="400" bgcolor=#0B0B61><font color=white>WaitType</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Data Log</font></th>    
					<th width="200" bgcolor=#0B0B61><font color=white>Wait (s)</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Resource (s)</font></th>      
					<th width="200" bgcolor=#0B0B61><font color=white>Signal (s)</font></th>   
					<th width="200" bgcolor=#0B0B61><font color=white>Qtd Wait</font></th> 	
					<th width="200" bgcolor=#0B0B61><font color=white>Last (%)</font></th> 			
				</tr>'    
            + REPLACE( REPLACE( @WaitsStats_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'
    
   	/***********************************************************************************************************************************
	--	Alertas Sem CLEAR -  Header
	***********************************************************************************************************************************/
	DECLARE @Alerta_Sem_Clear_Header VARCHAR(MAX)
	SET @Alerta_Sem_Clear_Header = '<font color=black size=5>'
	SET @Alerta_Sem_Clear_Header = @Alerta_Sem_Clear_Header + '<br/> Alertas Sem CLEAR <br/>'
	SET @Alerta_Sem_Clear_Header = @Alerta_Sem_Clear_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Alertas Sem CLEAR - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Alerta_Sem_Clear_Table VARCHAR(MAX)    

	SET @Alerta_Sem_Clear_Table = CAST( (    
		SELECT td =				  [Nm_Alerta]		+
					'</td><td>' + [Ds_Mensagem]		+
					'</td><td>' + [Dt_Alerta]		+	                                     
					'</td><td>' + [Run_Duration]	+	'</td>'
		FROM (           
				SELECT	[Nm_Alerta],
						ISNULL([Ds_Mensagem], '-') AS [Ds_Mensagem],
						ISNULL(CONVERT(VARCHAR, [Dt_Alerta], 120), '-') AS [Dt_Alerta],
						ISNULL([Run_Duration], '-') AS [Run_Duration]
				FROM [dbo].[CheckList_Alerta_Sem_Clear]				
			
		  ) AS D ORDER BY [Dt_Alerta]
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @Alerta_Sem_Clear_Table = REPLACE( REPLACE( REPLACE( @Alerta_Sem_Clear_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @Alerta_Sem_Clear_Table =
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Alerta</font></th>
					<th width="900" bgcolor=#0B0B61><font color=white>Mensagem</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Data</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Duração</font></th>
				</tr>'    
            + REPLACE( REPLACE( @Alerta_Sem_Clear_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'

	/***********************************************************************************************************************************
	--	Alertas -  Header
	***********************************************************************************************************************************/
	DECLARE @Alerta_Header VARCHAR(MAX)
	SET @Alerta_Header = '<font color=black size=5>'
	SET @Alerta_Header = @Alerta_Header + '<br/> TOP 50 - Alertas do Dia Anterior <br/>'
	SET @Alerta_Header = @Alerta_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Alertas - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Alerta_Table VARCHAR(MAX)    

	SET @Alerta_Table = CAST( (    
		SELECT td =				  [Nm_Alerta]		+
					'</td><td>' + [Ds_Mensagem]		+
					'</td><td>' + [Dt_Alerta]		+	                                     
					'</td><td>' + [Run_Duration]	+	'</td>'                                     
		FROM (           
				SELECT	TOP 50
						[Nm_Alerta],
						ISNULL([Ds_Mensagem], '-') AS [Ds_Mensagem],
						ISNULL(CONVERT(VARCHAR, [Dt_Alerta], 120), '-') AS [Dt_Alerta],
						ISNULL([Run_Duration], '-') AS [Run_Duration]
				FROM [dbo].[CheckList_Alerta]
				ORDER BY [Dt_Alerta] DESC				
			
		  ) AS D ORDER BY [Dt_Alerta] DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
      
    SET @Alerta_Table = REPLACE( REPLACE( REPLACE( @Alerta_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
    
	SET @Alerta_Table =
			'<table cellspacing="2" cellpadding="5" border="3">'    
            +	'<tr>
					<th width="300" bgcolor=#0B0B61><font color=white>Nome Alerta</font></th>
					<th width="900" bgcolor=#0B0B61><font color=white>Mensagem</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Data</font></th>	
					<th width="200" bgcolor=#0B0B61><font color=white>Duração</font></th>
				</tr>'    
            + REPLACE( REPLACE( @Alerta_Table, '&lt;', '<'), '&gt;', '>')
            + '</table>'
	

	/***********************************************************************************************************************************
	--	Login Failed - Header
	***********************************************************************************************************************************/
	DECLARE @LoginFailed_Header VARCHAR(MAX)
	SET @LoginFailed_Header = '<font color=black size=5>'
	SET @LoginFailed_Header = @LoginFailed_Header + '<br/> TOP 10 - Login Failed - SQL Server <br/>' 
	SET @LoginFailed_Header = @LoginFailed_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Login Failed - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @LoginFailed_Table VARCHAR(MAX)    

	SET @LoginFailed_Table = CAST( (    		
		SELECT td = CASE WHEN [Text] = 'TOTAL'	THEN ' bgcolor=#0B0B61><font color=white>' + [Text]		+ '</font>'
														ELSE [Text]   END  + '</td><td>'  +
					CASE WHEN [Text] = 'TOTAL '	THEN ' bgcolor=#0B0B61><font color=white>' + [Qt_Erro]	+ '</font>'
															ELSE [Qt_Erro]  END  + '</td>'		                        
		FROM (
				SELECT	TOP 10
						[Nr_Ordem],
						[Text],
						ISNULL(CAST([Qt_Erro] AS VARCHAR), '-') AS [Qt_Erro]
				FROM [dbo].[CheckList_SQLServer_LoginFailed_Email]
				ORDER BY CAST(REPLACE([Qt_Erro], '-', 0) AS INT) DESC

			  ) AS D ORDER BY Nr_Ordem, CAST(REPLACE([Qt_Erro], '-', 0) AS INT) DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)
	
	SET @LoginFailed_Table = REPLACE( REPLACE( REPLACE( REPLACE(@LoginFailed_Table, '&lt;', '<'), '&gt;', '>'), 
													'<td> ', '<td align=center '),'<td>', '<td align=center>')
	    
	SET @LoginFailed_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="400" bgcolor=#0B0B61><font color=white>Usuário</font></th>
					<th width="200" bgcolor=#0B0B61><font color=white>Qtd Erros</font></th>
				</tr>'    
			+ REPLACE( REPLACE( @LoginFailed_Table, '&lt;', '<'), '&gt;', '>')   
			+ '</table>'


	/***********************************************************************************************************************************
	--	Error Log SQL - Header
	***********************************************************************************************************************************/
	DECLARE @LogSQL_Header VARCHAR(MAX)
	SET @LogSQL_Header = '<font color=black size=5>'
	SET @LogSQL_Header = @LogSQL_Header + '<br/> TOP 100 - Error Log do SQL Server <br/>' 
	SET @LogSQL_Header = @LogSQL_Header + '</font>'

	------------------------------------------------------------------------------------------------------------------------------------
	--	Error Log SQL - Informações
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @LogSQL_Table VARCHAR(MAX)    

	SET @LogSQL_Table = CAST( (    
		SELECT td =				  [Dt_Log]		+ 	
					'</td><td>' + [ProcessInfo] + 
					'</td><td>' + [Text]		+ 	'</td>'                                     
		FROM (
				SELECT	TOP 100
						ISNULL(CONVERT(VARCHAR, [Dt_Log], 120), '-') AS [Dt_Log], 
						ISNULL([ProcessInfo], '-')					 AS [ProcessInfo], 
						[Text] 
				FROM [dbo].[CheckList_SQLServer_ErrorLog]
				ORDER BY [Dt_Log] DESC

			  ) AS D ORDER BY [Dt_Log] DESC
		FOR XML PATH( 'tr' ), TYPE ) AS VARCHAR(MAX) 
	)   
	      
	SET @LogSQL_Table = REPLACE( REPLACE( REPLACE(@LogSQL_Table, '&lt;', '<'), '&gt;', '>'), '<td>', '<td align=center>')
	    
	SET @LogSQL_Table = 
			'<table cellspacing="2" cellpadding="5" border="3">'    
			+	'<tr>
					<th width="250" bgcolor=#0B0B61><font color=white>Data Log</font></th>
					<th width="150" bgcolor=#0B0B61><font color=white>Processo</font></th>
					<th width="400" bgcolor=#0B0B61><font color=white>Mensagem</font></th>              
				</tr>'    
			+ REPLACE( REPLACE( @LogSQL_Table, '&lt;', '<'), '&gt;', '>')   
			+ '</table>'
              

	/***********************************************************************************************************************************
	-- Seção em branco para dar espaço entre AS tabelas e os cabeçalhos
	***********************************************************************************************************************************/
	DECLARE @emptybody2 VARCHAR(MAX)  
	SET @emptybody2 =	''  
	SET @emptybody2 =	'<table cellpadding="5" cellspacing="5" border="0">' +              
							'<tr>
								<th width="500">               </th>
							</tr>'
							+ REPLACE( REPLACE( ISNULL(@emptybody2,''), '&lt;', '<'), '&gt;', '>')
						+ '</table>'    

	
	------------------------------------------------------------------------------------------------------------------------------------	
	-- Seta AS Informações do E-Mail
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@importance AS VARCHAR(6) = 'High',			
			@Reportdate DATETIME = GETDATE(),
			@recipientsList VARCHAR(8000),
			@subject AS VARCHAR(500),
			@EmailBody VARCHAR(MAX) = ''
	
	SELECT @subject = 'CheckList Diário do Banco de Dados - ' + @Nm_Empresa + ' - ' + @@SERVERNAME					
				
	IF ( @DisponibilidadeSQL_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @DisponibilidadeSQL_Header + @emptybody2 + @DisponibilidadeSQL_Table + @emptybody2			-- Disponibilidade SQL
	
	IF ( @EspacoDisco_Table IS NOT NULL )	
		SELECT @EmailBody = @EmailBody + @EspacoDisco_Header + @emptybody2 + @EspacoDisco_Table + @emptybody2						-- Espaço em Disco
		
	IF ( @ArquivosDados_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @ArquivosDados_Header + @emptybody2 + @ArquivosDados_Table + @emptybody2					-- Arquivos Dados

	IF ( @ArquivosLog_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @ArquivosLog_Header + @emptybody2 + @ArquivosLog_Table + @emptybody2						-- Arquivos Log
		
	IF ( @CrescimentoBases_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @CrescimentoBases_Header + @emptybody2 + @CrescimentoBases_Table + @emptybody2				-- Crescimento das Bases
		
	IF ( @CrescimentoTabelas_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @CrescimentoTabelas_Header + @emptybody2 + @CrescimentoTabelas_Table + @emptybody2			-- Crescimento das Tabelas
		
	IF ( @UtilizacaoArqWrites_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @UtilizacaoArqWrites_Header + @emptybody2 + @UtilizacaoArqWrites_Table + @emptybody2		-- Utilizacao Arquivos - Wrties
		
	IF ( @UtilizacaoArqReads_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @UtilizacaoArqReads_Header + @emptybody2 + @UtilizacaoArqReads_Table + @emptybody2			-- Utilizacao Arquivos - Reads

	IF ( @DatabaseSemBackup_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @DatabaseSemBackup_Header + @emptybody2 + @DatabaseSemBackup_Table + @emptybody2			-- Databases Sem Backup

	IF ( @Backup_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @Backup_Header + @emptybody2 + @Backup_Table + @emptybody2									-- Backups Executados
	
	IF ( @QueriesRunning_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @QueriesRunning_Header + @emptybody2 + @QueriesRunning_Table + @emptybody2					-- Queries em Execução

	IF ( @JobsRunning_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @JobsRunning_Header + @emptybody2 + @JobsRunning_Table + @emptybody2						-- Jobs em Execução

	IF ( @JobsAlterados_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @JobsAlterados_Header + @emptybody2 + @JobsAlterados_Table + @emptybody2					-- Jobs Alterados

	IF ( @JobsFailed_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @JobsFailed_Header + @emptybody2 + @JobsFailed_Table + @emptybody2							-- Jobs Failed
		
	IF ( @TempoJobs_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @TempoJobs_Header + @emptybody2 + @TempoJobs_Table + @emptybody2							-- Jobs Demorados
	
	IF ( @QueriesDemoradas_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @QueriesDemoradas_Header + @emptybody2 + @QueriesDemoradas_Table + @emptybody2				-- Queries Demoradas

	IF ( @QueriesDemoradasGeral_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @QueriesDemoradasGeral_Header + @emptybody2 + @QueriesDemoradasGeral_Table + @emptybody2	-- Queries Demoradas Geral
		
	IF ( @Contadores_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @Contadores_Header + @emptybody2 + @Contadores_Table + @emptybody2							-- Contadores

	IF ( @ConexoesAbertas_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @ConexoesAbertas_Header + @emptybody2 + @ConexoesAbertas_Table + @emptybody2				-- Conexao Aberta
		
	IF ( @FragmentacaoIndice_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @FragmentacaoIndice_Header + @emptybody2 + @FragmentacaoIndice_Table + @emptybody2			-- Fragmentação Índice
		
	IF ( @WaitsStats_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @WaitsStats_Header + @emptybody2 + @WaitsStats_Table + @emptybody2							-- Waits Stats
		
	IF ( @Alerta_Sem_Clear_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @Alerta_Sem_Clear_Header + @emptybody2 + @Alerta_Sem_Clear_Table + @emptybody2				-- Alerta Sem CLEAR

	IF ( @Alerta_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @Alerta_Header + @emptybody2 + @Alerta_Table + @emptybody2									-- Alertas

	IF ( @LoginFailed_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @LoginFailed_Header + @emptybody2 + @LoginFailed_Table + @emptybody2						-- Login Failed

	IF ( @LogSQL_Table IS NOT NULL )
		SELECT @EmailBody = @EmailBody + @LogSQL_Header + @emptybody2 + @LogSQL_Table + @emptybody2									-- Error Log SQL
	
	
	/***********************************************************************************************************************************
	-- Inclui uma imagem com link para o site do Fabricio Lima
	***********************************************************************************************************************************/
	select @EmailBody = @EmailBody + '<br/><br/>' +
				'<a href="http://www.fabriciolima.net" target=”_blank”> 
					<img src="http://www.fabriciolima.net/wp-content/uploads/2016/04/Logo_Fabricio-Lima_horizontal.png" height="100" width="400"/></a>'
				

	/***********************************************************************************************************************************
	-- Envia o E-Mail do CheckList do Banco de Dados
	***********************************************************************************************************************************/
	EXEC [msdb].[dbo].[sp_send_dbmail]  
			@profile_name = @Profile_Email,
			@recipients = @Ds_Email,			
			@subject = @subject,
			@body = @EmailBody,
			@body_format = 'HTML',    
			@importance = @importance
END


GO

USE [msdb]

GO




/***********************************************************************************************************************************
-- CRIA JOB: [DBA - CheckList do Banco de Dados]
***********************************************************************************************************************************/
BEGIN TRANSACTION
	DECLARE @ReturnCode INT
	SELECT @ReturnCode = 0
	
	------------------------------------------------------------------------------------------------------------------------------------	
	-- Seleciona a Categoria do JOB
	------------------------------------------------------------------------------------------------------------------------------------
	IF NOT EXISTS ( SELECT [name] FROM [msdb].[dbo].[syscategories] WHERE [name] = N'Database Maintenance' AND [category_class] = 1 )
	BEGIN
		EXEC @ReturnCode = [msdb].[dbo].[sp_add_category] @class = N'JOB', @type = N'LOCAL', @name = N'Database Maintenance'
		
		IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	END

	DECLARE @jobId BINARY(16)
	EXEC @ReturnCode = [msdb].[dbo].[sp_add_job]
			@job_name = N'DBA - CheckList do Banco de Dados', 
			@enabled = 1, 
			@notify_level_eventlog = 0, 
			@notify_level_email = 2, 
			@notify_level_netsend = 0, 
			@notify_level_page = 0, 
			@delete_level = 0, 
			@description = N'JOB responsável por enviar o E-Mail com o CheckList do Banco de Dados.', 
			@category_name = N'Database Maintenance', 
			@owner_login_name = N'sa',
			@notify_email_operator_name=N'Alerta_BD',
			@job_id = @jobId OUTPUT
											
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	------------------------------------------------------------------------------------------------------------------------------------	
	-- Cria o Step 1 do JOB - Carga Tabelas CheckList
	------------------------------------------------------------------------------------------------------------------------------------
	EXEC @ReturnCode = [msdb].[dbo].[sp_add_jobstep]
			@job_id = @jobId,
			@step_name = N'DBA - Carga Tabelas CheckList',
			@step_id = 1,
			@cmdexec_success_code = 0,
			@on_success_action = 3,
			@on_success_step_id = 0,
			@on_fail_action = 2,
			@on_fail_step_id = 0,
			@retry_attempts = 0, 
			@retry_interval = 0, 
			@os_run_priority = 0, 
			@subsystem = N'TSQL',
			@command = N'EXEC [dbo].[stpCheckList_Espaco_Disco]				-- Espaço em Disco
EXEC [dbo].[stpCheckList_Arquivos_MDF_LDF]			-- Arquivos MDF e LDF
EXEC [dbo].[stpCheckList_Database_Growth]			-- Crescimento das Bases
EXEC [dbo].[stpCheckList_Table_Growth]				-- Crescimento das Tabelas
EXEC [dbo].[stpCheckList_Utilizacao_Arquivo]		-- Utilizacao Arquivos
EXEC [dbo].[stpCheckList_Databases_Sem_Backup]		-- Databases Sem Backup
EXEC [dbo].[stpCheckList_Backups_Executados]		-- Backups Executados
EXEC [dbo].[stpCheckList_Queries_Running]			-- Queries em Execução
EXEC [dbo].[stpCheckList_Jobs_Failed]				-- Jobs Failed
EXEC [dbo].[stpCheckList_Alteracao_Jobs]			-- Jobs Alterados
EXEC [dbo].[stpCheckList_Job_Demorados]				-- Jobs Demorados
EXEC [dbo].[stpCheckList_Jobs_Running]				-- Jobs em Execução
EXEC [dbo].[stpCheckList_Traces_Queries]			-- Queries Demoradas
EXEC [dbo].[stpCheckList_Contadores]				-- Contadores
EXEC [dbo].[stpCheckList_Conexao_Aberta]			-- Conexões Abertas
EXEC [dbo].[stpCheckList_Fragmentacao_Indices]		-- Fragmentacao Índice
EXEC [dbo].[stpCheckList_Waits_Stats]				-- Waits Stats
EXEC [dbo].[stpCheckList_Alerta]					-- Alertas
EXEC [dbo].[stpCheckList_SQLServer_ErrorLog]		-- Error Log SQL',		
			@database_name = N'Traces',
			@flags = 0
							
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
	------------------------------------------------------------------------------------------------------------------------------------	
	-- Cria o Step 2 do JOB - Envio de E-mail em HTML com o CheckList do Banco de Dados
	------------------------------------------------------------------------------------------------------------------------------------
	EXEC @ReturnCode = [msdb].[dbo].[sp_add_jobstep]
			@job_id = @jobId, 
			@step_name = N'DBA - Envio de E-mail em HTML com o CheckList do Banco de Dados', 
			@step_id = 2, 
			@cmdexec_success_code = 0,
			@on_success_action = 1,
			@on_success_step_id = 0, 
			@on_fail_action = 2,
			@on_fail_step_id = 0, 
			@retry_attempts = 0, 
			@retry_interval = 0, 
			@os_run_priority = 0, 
			@subsystem = N'TSQL', 
			@command = N'EXEC[dbo].[stpEnvia_CheckList_Diario_DBA]
	@Nm_Empresa = ''NomeEmpresa'',
	@Profile_Email = ''MSSQLServer'',
	@Ds_Email = ''E-mail@provedor.com''', 
			@database_name = N'Traces', 
			@flags = 0

	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
	EXEC @ReturnCode = [msdb].[dbo].[sp_update_job] @job_id = @jobId, @start_step_id = 1
	
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
	------------------------------------------------------------------------------------------------------------------------------------	
	-- Cria o Schedule do JOB
	------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @Dt_Atual VARCHAR(8) = CONVERT(VARCHAR(8), GETDATE(), 112)
		
	EXEC @ReturnCode = [msdb].[dbo].[sp_add_jobschedule]
			@job_id = @jobId, 
			@name = N'DIÁRIO - 07:00', 
			@enabled = 1, 
			@freq_type = 4, 
			@freq_interval = 1 , 
			@freq_subday_type = 1, 
			@freq_subday_interval = 0, 
			@freq_relative_interval = 0, 
			@freq_recurrence_factor = 0, 
			@active_start_date = @Dt_Atual,
			@active_end_date = 99991231, 
			@active_start_time = 70000, 
			@active_end_time = 235959, 
			@schedule_uid = N'5db1dad0-4ec4-4cb2-8bb4-6841a8a90cfc'
			
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
	
	EXEC @ReturnCode = [msdb].[dbo].[sp_add_jobserver] @job_id = @jobId, @server_name = N'(local)'
	
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION

GOTO EndSave

QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
    
EndSave:

GO