--Listagem 1. Tabelas que não contêm índices clusteriazados.
select distinct(tb.name) as Table_name, p.rows
from sys.objects tb join sys.partitions p on p.object_id = tb.object_id Where type = 'U' and tb.object_id not in (
select ix.object_id from sys.indexes ix where type = 1 )order by p.rows desc