/***********************************************************************************************************************************
(C) 2016, Fabricio Lima Soluções em Banco de Dados

Site: http://www.fabriciolima.net/

Feedback: fabricioflima@gmail.com
***********************************************************************************************************************************/


/*******************************************************************************************************************************
--	Instruções de utilização do script.
*******************************************************************************************************************************/
--	1) Basta executar (apertar F5) e os alertas de severidade serão criados.


/*******************************************************************************************************************************
--	ALERTAS DE SEVERIDADE CRÍTICOS DO SQL SERVER
*******************************************************************************************************************************/

GO

--------------------------------------------------------------------------------------------------------------------------------
--	Severity 021 - Fatal Error in Database Processes
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Severity 021' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]  @name = N'Severity 021'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Severity 021', 
		@message_id = 0,
		@severity = 21, 
		@enabled = 1, 
		@delay_between_responses = 60,
		@include_event_description_in = 1
    
GO

EXEC [msdb].[dbo].[sp_add_notification]
		@alert_name = N'Severity 021',
		@operator_name = N'Alerta_BD', 
		@notification_method = 7
    
GO

--------------------------------------------------------------------------------------------------------------------------------
--	Severity 022 - Fatal Error: Table INTegrity Suspect
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Severity 022' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]  @name = N'Severity 022'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Severity 022', 
		@message_id = 0,
		@severity = 22, 
		@enabled = 1, 
		@delay_between_responses = 60,
		@include_event_description_in = 1
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Severity 022',
		@operator_name = N'Alerta_BD', 
		@notification_method = 7
    
GO

--------------------------------------------------------------------------------------------------------------------------------
--	Severity 023 - Fatal Error: Database INTegrity Suspect
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Severity 023' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]  @name = N'Severity 023'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Severity 023', 
		@message_id = 0,
		@severity = 23, 
		@enabled = 1, 
		@delay_between_responses = 60,
		@include_event_description_in = 1
    
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Severity 023',
		@operator_name = N'Alerta_BD', 
		@notification_method = 7
    
GO

--------------------------------------------------------------------------------------------------------------------------------
--	Severity 024 - Fatal Error: Hardware Error
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Severity 024' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]  @name = N'Severity 024'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Severity 024', 
		@message_id = 0,
		@severity = 24, 
		@enabled = 1, 
		@delay_between_responses = 60,
		@include_event_description_in = 1
    
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Severity 024',
		@operator_name = N'Alerta_BD', 
		@notification_method = 7
    
GO


--------------------------------------------------------------------------------------------------------------------------------
--	Severity 025 - Fatal Error
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Severity 025' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]  @name = N'Severity 025'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Severity 025', 
		@message_id = 0,
		@severity = 25, 
		@enabled = 1, 
		@delay_between_responses = 60,
		@include_event_description_in = 1
    
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Severity 025',
		@operator_name = N'Alerta_BD', 
		@notification_method = 7
    
GO


/*******************************************************************************************************************************
--	ALERTAS DE PAGINAS CORROMPIDAS
*******************************************************************************************************************************/

--------------------------------------------------------------------------------------------------------------------------------
--	Error Number 823
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Error Number 823' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]   @name = N'Error Number 823'
END
   
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Error Number 823',
		@message_id = 823,
		@severity = 0,
		@enabled = 1,
		@delay_between_responses = 60,
		@include_event_description_in = 1
		
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Error Number 823', 
		@operator_name = N'Alerta_BD', 
		@notification_method = 7;

GO

--------------------------------------------------------------------------------------------------------------------------------
--	Error Number 824
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Error Number 824' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]   @name = N'Error Number 824'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Error Number 824',
		@message_id = 824,
		@severity = 0,
		@enabled = 1,
		@delay_between_responses = 60,
		@include_event_description_in = 1
 
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Error Number 824',
		@operator_name = N'Alerta_BD', 
		@notification_method = 7;

GO

--------------------------------------------------------------------------------------------------------------------------------
--	Error Number 825
--------------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT * FROM [msdb].[dbo].[sysalerts] WHERE name = 'Error Number 825' )
BEGIN
	EXEC [msdb].[dbo].[sp_delete_alert]   @name = N'Error Number 825'
END
	
EXEC [msdb].[dbo].[sp_add_alert] 
		@name = N'Error Number 825',
		@message_id = 825,
		@severity = 0,
		@enabled = 1,
		@delay_between_responses = 60,
		@include_event_description_in = 1
		
GO

EXEC [msdb].[dbo].[sp_add_notification] 
		@alert_name = N'Error Number 825', 
		@operator_name = N'Alerta_BD', 
		@notification_method = 7;

GO