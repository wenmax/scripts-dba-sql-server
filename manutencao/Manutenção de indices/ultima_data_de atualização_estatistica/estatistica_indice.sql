
--informaçoes sobre atualização de indices 

select i.name as [nome do indice],
	   stats_date(i.id,i.indid)
from sysobjects  o inner join sysindexes i on o.id = i.id 
 where  o.name ='teste_dois'--nome da tabela entre aspas

 DBCC SHOW_STATISTICS(TB_PEDIDO,PK_PEDIDOS) -- (TABELA,NOME_DO_INDICE)

 --INFORMAÇOES DAS PAGINAS DA TABELA
 DBCC SHOWCONTIG('TB_CLIENTE')


 --DESFRAGMENTAÇÃO DE INDICES
 DBCC INDEXDEFRAG('PEDIDOS','TESTE_DOIS','I_TESTEDOIS')

 --RECONSTRUÇÃO DE INDICES
 --CRIANDO INDICE
 CREATE INDEX IX_TESTE_DOIS_NOME_TESTE
 ON TESTE_DOIS(COD_TESTE)
GO
--RECONSTRUINDO O INDICE 

CREATE INDEX IX_TESTE_DOIS_NOME_TESTE
ON TESTE_DOIS (COD_TESTE)
WITH DROP_EXISTING