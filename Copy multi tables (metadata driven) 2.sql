--============================================================
-- Step 2: Copy Multiple Tables Driven by Metadata
--============================================================
-- This step reads dbo.TableCopyMeta row by row and performs:
--   1. Conditional DROP of destination table
--   2. Data copy using either:
--        • Standard SELECT INTO from LinkedServer
--        • Customized SQL via OPENQUERY
--   3. Optional post-copy patching (for customized rows)
--
-- Each row in dbo.TableCopyMeta represents one table copy task
--============================================================


--============================================================
-- Variable Declarations
--============================================================
-- Variables correspond one-to-one with columns in dbo.TableCopyMeta
DECLARE @LinkedServer SYSNAME;
DECLARE @SourceDatabase SYSNAME;
DECLARE @SourceSchema SYSNAME;
DECLARE @SourceTable SYSNAME;
DECLARE @DestSchema SYSNAME;
DECLARE @DestTable SYSNAME;
DECLARE @Customerized BIT;
DECLARE @Customerized_SQL NVARCHAR(MAX);
DECLARE @SQL NVARCHAR(MAX);
DECLARE @Patched_SQL NVARCHAR(MAX);


--============================================================
-- Cursor Definition
--============================================================
-- FAST_FORWARD cursor is used for efficient, read-only, forward-only
-- iteration through the metadata table
DECLARE TableCursor CURSOR FAST_FORWARD FOR
    SELECT LinkedServer, SourceDatabase, SourceSchema, SourceTable,
           DestSchema, DestTable, Customerized, Customerized_SQL, Patched_SQL
    FROM dbo.TableCopyMeta;


--============================================================
-- Cursor Initialization
--============================================================
OPEN TableCursor;

FETCH NEXT FROM TableCursor 
INTO @LinkedServer, @SourceDatabase, @SourceSchema, @SourceTable,
     @DestSchema, @DestTable, @Customerized, @Customerized_SQL, @Patched_SQL;


--============================================================
-- Main Processing Loop
--============================================================
WHILE @@FETCH_STATUS = 0
BEGIN
    --========================================================
    -- Step 2.1: Drop Destination Table If It Already Exists
    --========================================================
    -- Ensures SELECT INTO will succeed without name conflicts
    SET @SQL = N'
    IF OBJECT_ID(QUOTENAME(''' + @DestSchema + ''') + ''.'' + QUOTENAME(''' + @DestTable + '''), ''U'') IS NOT NULL
    BEGIN
        DROP TABLE ' + QUOTENAME(@DestSchema) + '.' + QUOTENAME(@DestTable) + ';
    END;
    ';


    --========================================================
    -- Step 2.2: Build SELECT INTO Statement
    --========================================================
    -- Behavior depends on Customerized flag:
    --   Customerized = 1 → Use OPENQUERY with custom SQL
    --   Customerized = 0 → Direct SELECT from LinkedServer
    IF @Customerized = 1
	BEGIN
	    -- Customized copy using OPENQUERY
	    -- Note: Single quotes in SQL are escaped for OPENQUERY
		SET @SQL += N'
		SELECT *
		INTO ' + QUOTENAME(@DestSchema) + '.' + QUOTENAME(@DestTable) + '
		FROM OPENQUERY(' + QUOTENAME(@LinkedServer) + ', ''' 
		      + REPLACE(@Customerized_SQL, '''', '''''') + ''');';
	END
	ELSE
	BEGIN
	    -- Standard copy from LinkedServer.Database.Schema.Table
		SET @SQL += N'
		SELECT *
		INTO ' + QUOTENAME(@DestSchema) + '.' + QUOTENAME(@DestTable) + '
		FROM ' + QUOTENAME(@LinkedServer) + '.' + QUOTENAME(@SourceDatabase) + '.' 
		          + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@SourceTable) + ';';
	END


    --========================================================
    -- Step 2.3: Execute Copy Operation
    --========================================================
	PRINT '----------------------------------------------------';
	PRINT 'Start copying';
    PRINT @SQL; -- Debugging output: review generated SQL
    EXEC sp_executesql @SQL;


    --========================================================
    -- Step 2.4: Optional Post-Copy Patching
    --========================================================
    -- Executed only when Customerized = 1
    IF @Customerized = 1
	BEGIN
	    PRINT '----------------------------------------------------';
	    PRINT 'Start patching';
		PRINT @Patched_SQL; -- Debugging output
	    EXEC sp_executesql @Patched_SQL;
	END


    --========================================================
    -- Step 2.5: Throttle Execution
    --========================================================
    -- Small delay to reduce load on source/destination servers
	WAITFOR DELAY '00:00:05';


    --========================================================
    -- Fetch Next Metadata Row
    --========================================================
    FETCH NEXT FROM TableCursor 
    INTO @LinkedServer, @SourceDatabase, @SourceSchema, @SourceTable,
         @DestSchema, @DestTable, @Customerized, @Customerized_SQL, @Patched_SQL;
END


--============================================================
-- Cleanup
--============================================================
CLOSE TableCursor;
DEALLOCATE TableCursor;
