--Read Excel from file system (network shared too) to SQL Server
--Part 1:

--1. Download and install:
--   Microsoft Access Database Engine 2016 Redistributable (accessdatabaseengine_X64.exe)
--   Do not install 32bit(accessdatabaseengine.exe), its for SSIS development, good to read Excel, but not stable when write
--   Install 64bit(accessdatabaseengine_X64.exe), it don't support SSIS well, but works PERFECT (Read Excel to SQL Server Part 2.sql)

--2. Run below script so you have right permission:
--   (You only need to run below script once)


USE [master]
GO

EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
RECONFIGURE;
GO

SP_CONFIGURE 'XP_CMDSHELL',1         
RECONFIGURE


EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0' , N'AllowInProcess' , 1
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.12.0' , N'DynamicParameters' , 1


EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0' , N'AllowInProcess' , 1
EXEC master.dbo.sp_MSset_oledb_prop N'Microsoft.ACE.OLEDB.16.0' , N'DynamicParameters' , 1
GO




