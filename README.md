\# Scripts DBA - Operações Diárias



Coleção de scripts SQL Server para monitoramento, manutenção e troubleshooting.



\## 📂 Categorias



\- \*\*monitoramento/\*\* - Verificar saúde e status dos bancos

\- \*\*manutencao/\*\* - Rebuild de índices, atualizar estatísticas, limpeza

\- \*\*performance/\*\* - Análise de queries lentas, deadlocks, wait stats

\- \*\*seguranca/\*\* - Auditoria, permissões, logins

\- \*\*backup-restore/\*\* - Operações de backup e restauração

\- \*\*troubleshooting/\*\* - Investigação e resolução de problemas

\- \*\*utilitarios/\*\* - Scripts auxiliares frequentes



\## 🚀 Como Usar



1\. Conecte ao SQL Server

2\. Selecione o banco de dados (ou use `master` se necessário)

3\. Execute o script com `Ctrl+E` (SSMS)



\## ⚙️ Customização



Antes de executar, verifique:

\- Nome do banco de dados

\- Thresholds de fragmentação

\- Período de retenção de backups



\## 📝 Exemplos de Uso Rápido



```sql

\-- Verificar espaço em disco

:r ".\\monitoramento\\verificar-space-disco.sql"



\-- Ver conexões ativas

:r ".\\monitoramento\\listar-conexoes-ativas.sql"



\-- Rebuild de índices

:r ".\\manutencao\\rebuild-indexes.sql"

