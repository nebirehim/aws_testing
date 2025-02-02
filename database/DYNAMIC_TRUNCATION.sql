SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- --
-- truncate_referenced_table - assists in truncating a table when you otherwise couldn't due to foreign references
--
-- Marc Ranolfi, 2019-02-05 <mranolfi@gmail.com>
--
-- Based on work by Peter Szanto <https://stackoverflow.com/a/13249209/3258851> and denver_citizen <https://stackoverflow.com/a/3039404/3258851>.
-- Licensed under cc by-sa 3.0 with attribution required <https://stackoverflow.blog/2009/06/25/attribution-required>.
--

ALTER PROCEDURE [AppSchema].[truncate_referenced_table]

  @TableToTruncate                 VARCHAR(64)

AS

BEGIN

SET NOCOUNT ON

-- GLOBAL VARIABLES
DECLARE @i int
DECLARE @Debug bit
DECLARE @Recycle bit
DECLARE @Verbose bit
DECLARE @TableName varchar(80)
DECLARE @FullTableName NVARCHAR(128);
DECLARE @ColumnName varchar(80)
DECLARE @ReferencedTableName varchar(80)
DECLARE @ReferencedColumnName varchar(80)
DECLARE @ConstraintName varchar(250)
DECLARE @IsDisabled int

DECLARE @CreateStatement varchar(max)
DECLARE @AlterStatement varchar(max)
DECLARE @DropStatement varchar(max)
DECLARE @TruncateStatement varchar(max)
DECLARE @CreateStatementTemp varchar(max)
DECLARE @AlterStatementTemp varchar(max)
DECLARE @DropStatementTemp varchar(max)
DECLARE @TruncateStatementTemp varchar(max)
DECLARE @Statement varchar(max)
DECLARE @Alter varchar(max)

        -- 1 = Will not execute statements
 SET @Debug = 0
        -- 0 = Will not create or truncate storage table
        -- 1 = Will create or truncate storage table
 SET @Recycle = 0
        -- 1 = Will print a message on every step
 set @Verbose = 1


 -- Resolve schema-qualified table name
    SELECT @FullTableName = QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_NAME = @TableToTruncate;

    IF @FullTableName IS NULL
    BEGIN
        PRINT 'Error: Table does not exist: ' + @TableToTruncate;
        RETURN;
    END

 SET @i = 1
    SET @CreateStatement = 'ALTER TABLE [AppSchema].[<tablename>]  WITH NOCHECK ADD  CONSTRAINT [<constraintname>] FOREIGN KEY([<column>]) REFERENCES [AppSchema].[<reftable>] ([<refcolumn>])'
	SET @AlterStatement = 'ALTER TABLE [AppSchema].[<tablename>] NOCHECK CONSTRAINT <fk_constraint_name>'
    SET @DropStatement = 'ALTER TABLE [AppSchema].[<tablename>] DROP CONSTRAINT [<constraintname>]'
    SET @TruncateStatement = 'TRUNCATE TABLE [<tablename>]'

-- Drop Temporary tables

IF OBJECT_ID('tempdb..#FKs') IS NOT NULL
    DROP TABLE #FKs

-- GET FKs
SELECT ROW_NUMBER() OVER (ORDER BY OBJECT_NAME(fkc.parent_object_id), clm1.name) as ID,
       OBJECT_NAME(fkc.constraint_object_id) as ConstraintName,
       OBJECT_NAME(fkc.parent_object_id) as TableName,
       clm1.name as ColumnName,
       OBJECT_NAME(fkc.referenced_object_id) as ReferencedTableName,
       clm2.name as ReferencedColumnName,
	   fk.is_disabled as IsDisabled
  INTO #FKs
  FROM sys.foreign_key_columns fkc
       JOIN sys.foreign_keys fk
	     ON fkc.constraint_object_id = fk.object_id
	   JOIN sys.columns clm1
         ON fkc.parent_column_id = clm1.column_id
            AND fkc.parent_object_id = clm1.object_id
       JOIN sys.columns clm2
         ON fkc.referenced_column_id = clm2.column_id
            AND fkc.referenced_object_id= clm2.object_id
 --WHERE OBJECT_NAME(parent_object_id) not in ('//tables that you do not wont to be truncated')
 WHERE OBJECT_NAME(fkc.referenced_object_id) = @TableToTruncate
 ORDER BY OBJECT_NAME(fkc.parent_object_id)


-- Prepare Storage Table
IF Not EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'Internal_FK_Definition_Storage')
   BEGIN
        IF @Verbose = 1
     PRINT '1. Creating Process Specific Tables...'

  -- CREATE STORAGE TABLE IF IT DOES NOT EXISTS
  CREATE TABLE [Internal_FK_Definition_Storage]
  (
   ID int not null identity(1,1) primary key,
   FK_Name varchar(250) not null,
   FK_CreationStatement varchar(max) not null,
   FK_AlterStatement varchar(max) not null,
   FK_DestructionStatement varchar(max) not null,
   Table_TruncationStatement varchar(max) not null
  )
   END
ELSE
   BEGIN
        IF @Recycle = 0
            BEGIN
                IF @Verbose = 1
       PRINT '1. Truncating Process Specific Tables...'

    -- TRUNCATE TABLE IF IT ALREADY EXISTS
    TRUNCATE TABLE [Internal_FK_Definition_Storage]
      END
      ELSE
         PRINT '1. Process specific table will be recycled from previous execution...'
   END


IF @Recycle = 0
   BEGIN

  IF @Verbose = 1
     PRINT '2. Backing up Foreign Key Definitions...'

  -- Fetch and persist FKs
  WHILE (@i <= (SELECT MAX(ID) FROM #FKs))
   BEGIN
    SET @ConstraintName = (SELECT ConstraintName FROM #FKs WHERE ID = @i)
    SET @TableName = (SELECT TableName FROM #FKs WHERE ID = @i)
    SET @ColumnName = (SELECT ColumnName FROM #FKs WHERE ID = @i)
    SET @ReferencedTableName = (SELECT ReferencedTableName FROM #FKs WHERE ID = @i)
    SET @ReferencedColumnName = (SELECT ReferencedColumnName FROM #FKs WHERE ID = @i)
	SET @IsDisabled = (SELECT IsDisabled FROM #FKs WHERE ID = @i)

    SET @DropStatementTemp = REPLACE(REPLACE(@DropStatement,'<tablename>',@TableName),'<constraintname>',@ConstraintName)
    SET @CreateStatementTemp = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@CreateStatement,'<tablename>',@TableName),'<column>',@ColumnName),'<constraintname>',@ConstraintName),'<reftable>',@ReferencedTableName),'<refcolumn>',@ReferencedColumnName)
	SET @AlterStatementTemp = CASE @IsDisabled
	  WHEN 1 THEN REPLACE(REPLACE(@AlterStatement, '<tablename>', @TableName), '<fk_constraint_name>', @ConstraintName)
	  ELSE ''
	END
	SET @TruncateStatementTemp = REPLACE(@TruncateStatement,'<tablename>',@TableName)

    INSERT INTO [Internal_FK_Definition_Storage]
                        SELECT @ConstraintName, @CreateStatementTemp, @AlterStatementTemp, @DropStatementTemp, @TruncateStatementTemp

    SET @i = @i + 1

    IF @Verbose = 1
       PRINT '  > Backing up [' + @ConstraintName + '] from [' + @TableName + ']'

    END
    END
    ELSE
       PRINT '2. Backup up was recycled from previous execution...'

       IF @Verbose = 1
     PRINT '3. Dropping Foreign Keys...'

    -- DROP FOREING KEYS
    SET @i = 1
    WHILE (@i <= (SELECT MAX(ID) FROM [Internal_FK_Definition_Storage]))
          BEGIN
             SET @ConstraintName = (SELECT FK_Name FROM [Internal_FK_Definition_Storage] WHERE ID = @i)
    SET @Statement = (SELECT FK_DestructionStatement FROM [Internal_FK_Definition_Storage] WITH (NOLOCK) WHERE ID = @i)

    IF @Debug = 1
       PRINT @Statement
    ELSE
       EXEC(@Statement)

    SET @i = @i + 1


    IF @Verbose = 1
       PRINT '  > Dropping [' + @ConstraintName + ']'

             END


    IF @Verbose = 1
       PRINT '4. Truncating Tables...'

    -- TRUNCATE TABLES
-- SzP: commented out as the tables to be truncated might also contain tables that has foreign keys
-- to resolve this the stored procedure should be called recursively, but I dont have the time to do it...
 /*
    SET @i = 1
    WHILE (@i <= (SELECT MAX(ID) FROM [Internal_FK_Definition_Storage]))
          BEGIN

    SET @Statement = (SELECT Table_TruncationStatement FROM [Internal_FK_Definition_Storage] WHERE ID = @i)

    IF @Debug = 1
       PRINT @Statement
    ELSE
       EXEC(@Statement)

    SET @i = @i + 1

    IF @Verbose = 1
       PRINT '  > ' + @Statement
          END
*/


    IF @Verbose = 1
       PRINT 'Truncating table: ' + @FullTableName;

    IF @Debug = 1
        PRINT 'TRUNCATE TABLE ' + @FullTableName
    ELSE
        EXEC('TRUNCATE TABLE ' + @FullTableName)


    IF @Verbose = 1
       PRINT '5. Re-creating Foreign Keys...'

    -- CREATE FOREING KEYS
    SET @i = 1
    WHILE (@i <= (SELECT MAX(ID) FROM [Internal_FK_Definition_Storage]))
          BEGIN
             SET @ConstraintName = (SELECT FK_Name FROM [Internal_FK_Definition_Storage] WHERE ID = @i)
    SET @Statement = (SELECT FK_CreationStatement FROM [Internal_FK_Definition_Storage] WHERE ID = @i)
	SET @Alter = (SELECT FK_AlterStatement FROM [Internal_FK_Definition_Storage] WHERE ID = @i)

    IF @Debug = 1
       PRINT @Statement
    ELSE
       EXEC(@Statement)

    IF @Verbose = 1
       PRINT '  > Re-creating [' + @ConstraintName + ']'

	IF @Alter != ''
	BEGIN
		IF @Debug = 1
			PRINT @Alter
		ELSE
			EXEC(@alter)

		IF @Verbose = 1
			PRINT '  > Disabling [' + @ConstraintName + ']'

	END

	SET @i = @i + 1

          END

    IF @Verbose = 1
       PRINT '6. Process Completed'


END
GO