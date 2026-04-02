-- monitoramento/verificar-locks.sql
/*
===============================================
Script: Verificar Locks (Bloqueios)
Versão: 2.0 (Compatível SQL Server 2005+)
Data: 2026-04-02
Objetivo: Identificar sessions bloqueadas e bloqueadores
Uso: Executar quando há lentidão ou travamento
Parâmetros: Nenhum
Exemplo: :r ".\monitoramento\verificar-locks.sql"
===============================================
*/

-- =============================================
-- 1. BLOQUEADORES E BLOQUEADOS (Compatível)
-- =============================================
SELECT 
    es.session_id,
    es.login_name AS Usuario,
    es.host_name AS Computador,
    DB_NAME(er.database_id) AS Banco,
    er.command AS Comando,
    er.status AS Status,
    DATEDIFF(SECOND, er.start_time, GETDATE()) AS DuracaoSegundos,
    er.wait_time AS TempoEsperaMS,
    er.last_wait_type AS UltimoTipoEspera
FROM 
    sys.dm_exec_sessions es
INNER JOIN 
    sys.dm_exec_requests er ON es.session_id = er.session_id
WHERE 
    es.session_id > 50
ORDER BY 
    er.wait_time DESC;

-- performance/analisar-plano-execucao-cache.sql
/*
===============================================
Script: Analisar Plano de Execução do Cache
Versão: 1.0
Data: 2026-04-02
Objetivo: Comparar performance entre queries antes/depois
Uso: Execute as queries e analise os planos salvos
===============================================
*/

-- =============================================
-- 1. VER PLANOS EM CACHE (Todos os queries executados)
-- =============================================
SELECT 
    qt.text AS QueryText,
    qs.execution_count AS Execucoes,
    qs.total_elapsed_time / 1000000 AS TotalTempoMS,
    (qs.total_elapsed_time / qs.execution_count) / 1000 AS TempoMedioMS,
    qs.total_logical_reads AS LeiturasTotais,
    qs.creation_time AS DataCriacao,
    qs.last_execution_time AS UltimaExecucao,
    qp.query_plan AS PlanoXML
FROM 
    sys.dm_exec_query_stats qs
CROSS APPLY 
    sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY 
    sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE 
    qt.text LIKE '%FilteredAbox%' 
    OR qt.text LIKE '%lpshistory%'
ORDER BY 
    qs.total_elapsed_time DESC;

-- =============================================
-- 2. TOP 10 QUERIES MAIS LENTAS (Com Plano)
-- =============================================
SELECT TOP 10
    (qs.total_elapsed_time / qs.execution_count) / 1000000 AS TempoMedioSegundos,
    qs.execution_count AS Execucoes,
    qs.total_logical_reads AS LeiturasTotais,
    SUBSTRING(qt.text, 1, 100) AS Query,
    qs.last_execution_time AS UltimaExecucao,
    qp.query_plan AS PlanoXML
FROM 
    sys.dm_exec_query_stats qs
CROSS APPLY 
    sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY 
    sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY 
    (qs.total_elapsed_time / qs.execution_count) DESC;



-- =============================================
-- 2. DETALHES DO SQL SENDO EXECUTADO
-- =============================================
SELECT 
    es.session_id AS SessionID,
    es.login_name AS Usuario,
    DB_NAME(er.database_id) AS Banco,
    er.command AS Comando,
    er.status AS Status,
    DATEDIFF(SECOND, er.start_time, GETDATE()) AS DuracaoSegundos,
    st.text AS ComandoSQL,
    er.wait_time AS TempoEsperaMS,
    er.total_elapsed_time / 1000 AS TempoTotalMS
FROM 
    sys.dm_exec_sessions es
INNER JOIN 
    sys.dm_exec_requests er ON es.session_id = er.session_id
CROSS APPLY 
    sys.dm_exec_sql_text(er.sql_handle) st
WHERE 
    es.session_id > 50
ORDER BY 
    er.wait_time DESC;

-- =============================================
-- 3. LOCKS ATIVOS NA BASE DE DADOS
-- =============================================
SELECT 
    tl.request_session_id AS SessionID,
    DB_NAME(tl.resource_database_id) AS Banco,
    OBJECT_NAME(tl.resource_associated_entity_id, tl.resource_database_id) AS NomeObjeto,
    tl.resource_type AS TipoDeLock,
    tl.request_type AS TipoDeRequisicao,
    tl.request_status AS Status,
    es.login_name AS Usuario,
    es.host_name AS Computador,
    tl.request_mode AS ModoLock
FROM 
    sys.dm_tran_locks tl
INNER JOIN 
    sys.dm_exec_sessions es ON tl.request_session_id = es.session_id
WHERE 
    tl.resource_database_id = DB_ID()
    AND tl.request_session_id > 50
ORDER BY 
    tl.request_session_id;

-- =============================================
-- 4. RESUMO: SESSIONS COM LOCKS
-- =============================================
SELECT 
    es.session_id AS SessionID,
    es.login_name AS Usuario,
    es.host_name AS Computador,
    DB_NAME(er.database_id) AS Banco,
    COUNT(tl.request_session_id) AS QuantidadeLocks,
    er.command AS UltimoComando,
    DATEDIFF(SECOND, er.start_time, GETDATE()) AS DuracaoSegundos,
    er.wait_time AS TempoEsperaMS
FROM 
    sys.dm_exec_sessions es
LEFT JOIN 
    sys.dm_exec_requests er ON es.session_id = er.session_id
LEFT JOIN 
    sys.dm_tran_locks tl ON es.session_id = tl.request_session_id
WHERE 
    es.session_id > 50
    AND (er.session_id IS NOT NULL OR tl.request_session_id IS NOT NULL)
GROUP BY 
    es.session_id,
    es.login_name,
    es.host_name,
    er.database_id,
    er.command,
    er.start_time,
    er.wait_time
ORDER BY 
    TempoEsperaMS DESC;

-- =============================================
-- 5. VER TODAS AS SESSIONS ATIVAS
-- =============================================
SELECT 
    session_id,
    login_name AS Usuario,
    host_name AS Computador,
    DB_NAME(database_id) AS Banco,
    status
FROM 
    sys.dm_exec_sessions
WHERE 
    session_id > 50
ORDER BY 
    session_id;

-- =============================================
-- 6. PARA MATAR UMA SESSION (USE COM CUIDADO!)
-- =============================================
-- Se precisar matar uma session bloqueadora:
-- KILL <SessionID>
-- Exemplo: KILL 52

-- monitoramento/verificar-locks.sql
/*
===============================================
Script: Verificar Locks (Bloqueios)
Versão: 3.0 (SQL Server 2022)
Data: 2026-04-02
Objetivo: Identificar sessions bloqueadas e bloqueadores
Uso: Executar quando há lentidão ou travamento
Parâmetros: Nenhum
Exemplo: :r ".\monitoramento\verificar-locks.sql"
===============================================
*/

-- =============================================
-- 1. SESSIONS COM REQUESTS ATIVAS
-- =============================================
SELECT 
    es.session_id,
    es.login_name AS Usuario,
    es.host_name AS Computador,
    DB_NAME(er.database_id) AS Banco,
    er.command AS Comando,
    er.status AS Status,
    DATEDIFF(SECOND, er.start_time, GETDATE()) AS DuracaoSegundos,
    er.wait_time AS TempoEsperaMS,
    er.last_wait_type AS UltimoTipoEspera
FROM 
    sys.dm_exec_sessions es
INNER JOIN 
    sys.dm_exec_requests er ON es.session_id = er.session_id
WHERE 
    es.session_id > 50
ORDER BY 
    er.wait_time DESC;

-- =============================================
-- 2. SQL SENDO EXECUTADO (COM TIMEOUT)
-- =============================================
SELECT 
    es.session_id AS SessionID,
    es.login_name AS Usuario,
    DB_NAME(er.database_id) AS Banco,
    er.command AS Comando,
    er.status AS Status,
    DATEDIFF(SECOND, er.start_time, GETDATE()) AS DuracaoSegundos,
    SUBSTRING(st.text, 1, 100) AS ComandoSQL,
    er.wait_time AS TempoEsperaMS
FROM 
    sys.dm_exec_sessions es
INNER JOIN 
    sys.dm_exec_requests er ON es.session_id = er.session_id
CROSS APPLY 
    sys.dm_exec_sql_text(er.sql_handle) st
WHERE 
    es.session_id > 50
ORDER BY 
    er.wait_time DESC;

-- =============================================
-- 3. LOCKS ATIVOS POR TABELA
-- =============================================
SELECT 
    tl.request_session_id AS SessionID,
    DB_NAME(tl.resource_database_id) AS Banco,
    OBJECT_NAME(tl.resource_associated_entity_id, tl.resource_database_id) AS Tabela,
    tl.resource_type AS TipoDeLock,
    tl.request_type AS TipoRequisicao,
    tl.request_status AS Status,
    tl.request_mode AS ModoLock,
    es.login_name AS Usuario,
    es.host_name AS Computador
FROM 
    sys.dm_tran_locks tl
INNER JOIN 
    sys.dm_exec_sessions es ON tl.request_session_id = es.session_id
WHERE 
    tl.resource_database_id = DB_ID()
    AND tl.request_session_id > 50
ORDER BY 
    tl.request_session_id;

-- =============================================
-- 4. RESUMO SIMPLES: QUEM ESTÁ LOCKED
-- =============================================
SELECT DISTINCT
    es.session_id AS SessionID,
    es.login_name AS Usuario,
    es.host_name AS Computador,
    DB_NAME(er.database_id) AS Banco,
    er.command AS UltimoComando,
    DATEDIFF(SECOND, er.start_time, GETDATE()) AS DuracaoSegundos,
    er.wait_time AS TempoEsperaMS
FROM 
    sys.dm_exec_sessions es
LEFT JOIN 
    sys.dm_exec_requests er ON es.session_id = er.session_id
LEFT JOIN 
    sys.dm_tran_locks tl ON es.session_id = tl.request_session_id
WHERE 
    es.session_id > 50
    AND (er.session_id IS NOT NULL OR tl.request_session_id IS NOT NULL)
ORDER BY 
    er.wait_time DESC;

-- =============================================
-- 5. VER TODAS AS SESSIONS ATIVAS
-- =============================================
SELECT 
    session_id,
    login_name AS Usuario,
    host_name AS Computador,
    DB_NAME(database_id) AS Banco,
    status
FROM 
    sys.dm_exec_sessions
WHERE 
    session_id > 50
    AND status = 'running'
ORDER BY 
    session_id;

-- =============================================
-- 6. BLOCKING CHAIN (Cadeia de Bloqueio)
-- =============================================
SELECT 
    session_id,
    blocking_session_id,
    DB_NAME(database_id) AS Banco,
    login_name AS Usuario,
    host_name AS Computador,
    status,
    DATEDIFF(SECOND, last_request_end_time, GETDATE()) AS SegundosInativo
FROM 
    sys.dm_exec_sessions
WHERE 
    blocking_session_id <> 0
    OR session_id IN (SELECT blocking_session_id FROM sys.dm_exec_sessions WHERE blocking_session_id <> 0)
ORDER BY 
    blocking_session_id DESC, 
    session_id;

-- =============================================
-- 7. PARA MATAR UMA SESSION (USE COM CUIDADO!)
-- =============================================
-- Se precisar matar uma session bloqueadora:
-- KILL <SessionID>
-- Exemplo: KILL 52

-- Para ver a session antes de matar:
/*
SELECT * FROM sys.dm_exec_sessions WHERE session_id = 52;
*/