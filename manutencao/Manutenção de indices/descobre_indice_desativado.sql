--Server para encontrar indices desativados 

SELECT
sys.objects.name AS Tabela,
sys.indexes.name AS Indice
FROM sys.indexes
inner join sys.objects ON sys.objects.object_id = sys.indexes.object_id
WHERE sys.indexes.is_disabled = 1
ORDER BY
sys.objects.name,
sys.indexes.name