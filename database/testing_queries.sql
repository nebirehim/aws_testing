-- Create Customers Table
CREATE TABLE AppSchema.Customers (
    CustomerID INT PRIMARY KEY,
    CustomerName VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE
);

-- Create Orders Table
CREATE TABLE AppSchema.Sales (
    SalesID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME NOT NULL DEFAULT GETDATE(),
    FOREIGN KEY (CustomerID) REFERENCES AppSchema.Customers(CustomerID)
);

-- Create Products Table
CREATE TABLE AppSchema.Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(100) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL
);

-- Create OrderDetails Table
CREATE TABLE AppSchema.OrderDetails (
    OrderDetailID INT PRIMARY KEY,
    SalesID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    FOREIGN KEY (SalesID) REFERENCES AppSchema.Sales(SalesID),
    FOREIGN KEY (ProductID) REFERENCES AppSchema.Products(ProductID)
);

drop table AppSchema.Customers,AppSchema.OrderDetails,AppSchema.Sales,AppSchema.Products

-- Insert data into Customers
INSERT INTO AppSchema.Customers (CustomerID, CustomerName, Email)
VALUES
    (1, 'Alice Johnson', 'alice.johnson@example.com'),
    (2, 'Bob Smith', 'bob.smith@example.com'),
    (3, 'Charlie Brown', 'charlie.brown@example.com');

-- Insert into Customers
INSERT INTO AppSchema.Customers (CustomerID, CustomerName, Email) VALUES
(1, 'John Doe', 'john.doe@example.com'),
(2, 'Jane Smith', 'jane.smith@example.com'),
(3, 'Michael Johnson', 'michael.johnson@example.com');

-- Insert into Sales
INSERT INTO AppSchema.Sales (SalesID, CustomerID, OrderDate) VALUES
(1, 1, '2024-02-01 10:30:00'),
(2, 2, '2024-02-01 11:00:00'),
(3, 3, '2024-02-01 12:00:00');

-- Insert into Products
INSERT INTO AppSchema.Products (ProductID, ProductName, Price) VALUES
(1, 'Laptop', 1200.00),
(2, 'Smartphone', 800.00),
(3, 'Headphones', 150.00);

-- Insert into OrderDetails
INSERT INTO AppSchema.OrderDetails (OrderDetailID, SalesID, ProductID, Quantity) VALUES
(1, 1, 1, 1), -- John Doe buys a Laptop
(2, 1, 3, 2), -- John Doe buys 2 Headphones
(3, 2, 2, 1), -- Jane Smith buys a Smartphone
(4, 3, 1, 1), -- Michael Johnson buys a Laptop
(5, 3, 2, 1); -- Michael Johnson buys a Smartphone


---------------------------------------------
SELECT
    fk.name AS FK_Name,
    t.name AS Table_Name,
    c.name AS Column_Name,
    ref.name AS Referenced_Table
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
JOIN sys.tables t ON fkc.parent_object_id = t.object_id
JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
JOIN sys.tables ref ON fkc.referenced_object_id = ref.object_id
WHERE SCHEMA_NAME(t.schema_id) = 'AppSchema';




ALTER TABLE AppSchema.Sales DROP CONSTRAINT FK__Sales__CustomerI__60A75C0F;
ALTER TABLE AppSchema.OrderDetails DROP CONSTRAINT FK__OrderDeta__Sales__656C112C;
ALTER TABLE AppSchema.OrderDetails DROP CONSTRAINT FK__OrderDeta__Produ__66603565;
--------------------------------------------
EXEC AppSchema.truncate_referenced_table @TableToTruncate = 'Products';




SELECT ROW_NUMBER() OVER (ORDER BY OBJECT_NAME(fkc.parent_object_id), clm1.name) as ID,
       OBJECT_NAME(fkc.constraint_object_id) as ConstraintName,
       OBJECT_NAME(fkc.parent_object_id) as TableName,
       clm1.name as ColumnName,
       OBJECT_NAME(fkc.referenced_object_id) as ReferencedTableName,
       clm2.name as ReferencedColumnName,
	   fk.is_disabled as IsDisabled

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
 ORDER BY OBJECT_NAME(fkc.parent_object_id)



 SELECT *
FROM AppSchema.Sales