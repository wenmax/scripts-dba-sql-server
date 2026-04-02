# MSSQLAutoRestore
Automatically restores databases from ola hallengrens backups.


Usage:
exec dbo.DatabaseRestoreTest 
  @RunCheckDB = 'Y'
  ,@Database = 'TestDb'
  ,@BackupPath = 'G:\backups\\servername\TestDb\'
  ,@MoveFiles = 'Y'
  ,@MoveDataDrive = 'X:\Data\'
  ,@MoveLogDrive = 'X:\Logs\'
  ,@TestRestore ='Y'

@RunCheckDb (Y or N)
will run Ola's standard dbcc check db and log to commandlog

@Database
database name to restore, you can change this if you wanted to restore a different name

@BackupPath
the root folder of the backup you want to restore, by default it will try the copy only backup. Still work to do on differentials.

@MoveFiles (Y or N)
useful if you are restoring to a test server and want to restore different paths

@MoveDataDrive / @MoveLogDrive
if @MoveFiles is Y then it will attempt to restore to these locations

@TestRestore (Y / N)
if set to Y then will remove the database after the restore, ideal when testing restores.
