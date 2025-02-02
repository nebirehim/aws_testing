CREATE PROCEDURE PopulateTablesFromSchemas
  @SourceDB NVARCHAR(128),  -- Source database name
  @DestDB NVARCHAR(128),    -- Destination database name
  @Schemas NVARCHAR(MAX)    -- Comma-separated list of schema names
AS
BEGIN
  SET NOCOUNT ON;
  -- Step 1: Declare Variables
  DECLARE @TableName NVARCHAR(128);
  DECLARE @SourceSchema NVARCHAR(128);
  DECLARE @DestSchema NVARCHAR(128);
  DECLARE @SchemaList TABLE (SchemaName NVARCHAR(128));
  -- Step 2: Split the Schema Names into a Table Variable
  INSERT INTO @SchemaList (SchemaName)
  SELECT value FROM STRING_SPLIT(@Schemas, ',');
  -- Step 3: Cursor to Loop Through Schemas
  DECLARE SchemaCursor CURSOR FOR
  SELECT SchemaName
  FROM @SchemaList;
  -- Step 4: Open the Schema Cursor
  OPEN SchemaCursor;
  FETCH NEXT FROM SchemaCursor INTO @SourceSchema;
  -- Step 5: Loop Through Each Schema
  WHILE @@FETCH_STATUS = 0
  BEGIN
      -- Map the destination schema dynamically
      SET @DestSchema = @SourceSchema;
      -- Step 5.1: Cursor to Loop Through Tables in Current Schema
      DECLARE TableCursor CURSOR FOR
      WITH source_schema AS (
          SELECT TABLE_NAME, COLUMN_NAME
          FROM AWSDB.INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA = @SourceSchema
      ),
      dest_schema AS (
          SELECT TABLE_NAME, COLUMN_NAME
          FROM AWSDB_TEST.INFORMATION_SCHEMA.COLUMNS
          WHERE TABLE_SCHEMA = @SourceSchema
      )
      SELECT DISTINCT A.TABLE_NAME
      FROM source_schema A
      JOIN dest_schema B ON A.TABLE_NAME = B.TABLE_NAME
                          AND A.COLUMN_NAME = B.COLUMN_NAME;
      -- Step 5.2: Open the Table Cursor
      OPEN TableCursor;
      FETCH NEXT FROM TableCursor INTO @TableName;
      -- Step 5.3: Loop Through Each Table
      WHILE @@FETCH_STATUS = 0
      BEGIN
          BEGIN TRY
              -- Begin Transaction
              BEGIN TRANSACTION;
              -- Step 5.3.1: Truncate the Table in the Destination Database
              DECLARE @TruncateQuery NVARCHAR(MAX);
              SET @TruncateQuery = 'TRUNCATE TABLE ' + QUOTENAME(@DestDB) + '.' + QUOTENAME(@DestSchema) + '.' + QUOTENAME(@TableName) + ';';
              PRINT 'Truncating table: ' + @DestDB + '.' + @DestSchema + '.' + @TableName;
              EXEC sp_executesql @TruncateQuery;
              -- Step 5.3.2: Populate the Table
              DECLARE @InsertQuery NVARCHAR(MAX);
              SET @InsertQuery = '
              INSERT INTO ' + QUOTENAME(@DestDB) + '.' + QUOTENAME(@DestSchema) + '.' + QUOTENAME(@TableName) + '
              SELECT *
              FROM ' + QUOTENAME(@SourceDB) + '.' + QUOTENAME(@SourceSchema) + '.' + QUOTENAME(@TableName) + ';';
              PRINT 'Populating table: ' + @DestDB + '.' + @SourceSchema + '.' + @TableName;
              EXEC sp_executesql @InsertQuery;
              -- Commit Transaction
              COMMIT TRANSACTION;
          END TRY
          BEGIN CATCH
              -- Rollback Transaction on Error
              ROLLBACK TRANSACTION;
              PRINT 'Error processing table: ' + @SourceSchema + '.' + @TableName;
              PRINT ERROR_MESSAGE();
          END CATCH
          -- Fetch the Next Table
          FETCH NEXT FROM TableCursor INTO @TableName;
      END
      -- Step 5.4: Clean Up Table Cursor
      CLOSE TableCursor;
      DEALLOCATE TableCursor;
      -- Fetch the Next Schema
      FETCH NEXT FROM SchemaCursor INTO @SourceSchema;
  END
  -- Step 6: Clean Up Schema Cursor
  CLOSE SchemaCursor;
  DEALLOCATE SchemaCursor;
  PRINT 'Process Completed!';
END
GO
