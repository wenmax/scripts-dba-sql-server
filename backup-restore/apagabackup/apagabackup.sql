USE master

--Declarar Variáveis
DECLARE @DeviceName VARCHAR(255)
DECLARE @File VARCHAR(255)
DECLARE @Creation DATETIME
DECLARE @OldPlus DATETIME

-- Declarar o cursor
DECLARE bud CURSOR
FOR
SELECT Name
	,phisicalName
	,BackupDeviceCreation
FROM sys.Backup_Devices
ORDER BY BackupDeviceCreation

-- Open the cursor
OPEN bud

-- Loop através do cursor
FETCH NEXT
FROM bud
INTO @DeviceName
	,@File
	,@Creation

WHILE @@FETCH_STATUS = 0
BEGIN
	SET @OldPlus = DATEADD(day, 7, @Creation)

	IF convert(VARCHAR(50), @OldPlus, 101) <= convert(VARCHAR(50), getdate(), 101)
	BEGIN
		EXEC sp_dropdevice @DeviceName
			,DELFILE

		DELETE
		FROM BackupDevice
		WHERE BackupDeviceName = @DeviceName
			AND BackupDeviceFile = @File
			AND BackupDeviceCreation = @Creation
	END

	FETCH NEXT
	FROM bud
	INTO @DeviceName
		,@File
		,@Creation
END

CLOSE bud

DEALLOCATE bud
