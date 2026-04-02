EXECUTE dbo.DatabaseIntegrityCheck
@Databases = 'USER_DATABASES',
@CheckCommands = 'CHECKDB',
@PhysicalOnly = 'Y'