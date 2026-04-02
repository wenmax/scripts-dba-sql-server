declare @base varchar (100)
declare @data varchar(8)
declare @devicebackup varchar(1000)

--serve para criar a data do dispositivo
set @data = convert (varchar(2),datepart(day,getdate()-1)) + '0'+convert(varchar(2),datepart(month,getdate())) + convert(varchar(4),datepart(year,getdate()))
print @data
-- seleciona o nome da base 
select @base = database_name
from backupset 

--concatena o nome dabase com a data 
set @devicebackup = @base+'_'+@data

print @devicebackup

--dropa os dispositivos 
EXEC sp_dropdevice @devicebackup --, 'delfile' ;  
GO 6

--select count(*)
--from backupset

--select database_name
--from backupset