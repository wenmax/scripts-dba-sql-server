--mostra todas as chaves estrangeras do banco de dados

SELECT ForeignKeys.NAME                           [ForeignKeyName], 
       PrimaryKeyTable.NAME                       [PrimaryTableName], 
       PrimaryKeyColumn.NAME                      [PrimaryColumnName], 
       ForeignKeyTable.NAME                       [ReferenceTableName], 
       ForeignKeyColumn.NAME                      [ReferenceColumnName], 
       ForeignKeys.update_referential_action_desc [UpdateAction], 
       ForeignKeys.delete_referential_action_desc [DeleteAction] 
FROM   sys.foreign_keys ForeignKeys 
       JOIN sys.foreign_key_columns ForeignKeyRelationships 
         ON ( ForeignKeys.object_id = 
              ForeignKeyRelationships.constraint_object_id ) 
       JOIN sys.tables ForeignKeyTable 
         ON ForeignKeyRelationships.parent_object_id = ForeignKeyTable.object_id 
       JOIN sys.columns ForeignKeyColumn 
         ON ( ForeignKeyTable.object_id = ForeignKeyColumn.object_id 
              AND ForeignKeyRelationships.parent_column_id = 
            ForeignKeyColumn.column_id ) 
       JOIN sys.tables PrimaryKeyTable 
         ON ForeignKeyRelationships.referenced_object_id = 
            PrimaryKeyTable.object_id 
       JOIN sys.columns PrimaryKeyColumn 
         ON ( PrimaryKeyTable.object_id = PrimaryKeyColumn.object_id 
              AND ForeignKeyRelationships.referenced_column_id = 
                  PrimaryKeyColumn.column_id ) 
ORDER  BY ForeignKeys.NAME