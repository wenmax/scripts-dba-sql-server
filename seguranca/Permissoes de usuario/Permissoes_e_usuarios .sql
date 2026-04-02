USE SpliceMTV
GO

CREATE USER splmtv_admin FOR LOGIN splmtv_admin
GO
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE TO splmtv_admin
GO
sp_addrolemember 'db_datareader', 'splmtv_admin'
GO
sp_addrolemember 'db_datawriter', 'splmtv_admin'
GO

CREATE USER radar_daer FOR LOGIN radar_daer
GO
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE TO radar_daer
GO

sp_addrolemember 'db_datareader', 'radar_daer'
GO
sp_addrolemember 'db_datawriter', 'radar_daer'
GO
