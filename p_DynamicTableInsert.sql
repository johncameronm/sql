IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[p_DynamicTableInsert]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[p_DynamicTableInsert]
GO

SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO


CREATE PROCEDURE [dbo].[p_DynamicTableInsert]
	@xmlPass xml
	,@TableName varchar(256)
AS
BEGIN
--debug
/*
declare 
	@xmlpass xml
	,@TableName varchar(100)
select 
	@xmlpass = '<ROOT>
<row Ticker="  " Amount="" Units="" ActionCode="" TradeDate="" UtCode="ct" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ct" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ct" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ut" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ut" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ut" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ut" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ut" TradeDateString="" CreatedTS="" CreatedBy="" />
<row Ticker="" Amount="" Units="" ActionCode="" TradeDate="" UtCode="ut" TradeDateString="" CreatedTS="" CreatedBy="" />
</ROOT>'
	,@TableName = 'tempTbl'
*/

IF OBJECT_ID('tempdb..#tmp_columns') IS NOT NULL
	DROP TABLE #tmp_columns

DECLARE
	@NameColumns nvarchar(max), 
	@TypeColumns nvarchar(max),
	@SQL nvarchar(max),
	@Query nvarchar(max),
	@Params nvarchar(max),
	@docHandle INT

SELECT 
	c.column_id
	,ColumnName = c.name
	,ColumnType = c.name + ' ' + t.name + 
		case 
		when t.name in('varchar', 'nvarchar') then '(' + convert(nvarchar(10), c.max_length) + ')' 
		when t.name in ('decimal') then '(' + convert(nvarchar(10), c.precision) + ',' + convert(nvarchar(10), c.scale) + ')' 
		else '' end
	,t.precision
INTO #tmp_columns
FROM sys.columns c
INNER JOIN sys.types t 
	ON c.user_type_id = t.user_type_id
LEFT OUTER JOIN
  sys.index_columns ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id
LEFT OUTER JOIN
  sys.indexes i ON ic.object_id = i.object_id AND ic.index_id = i.index_id
WHERE
  c.object_id = OBJECT_ID(@TableName)
 and (i.is_primary_key = 0 or i.is_primary_key is null)
ORDER BY c.column_id asc

SELECT 
	@NameColumns = stuff((SELECT ', ' + ColumnName FROM (SELECT ColumnName FROM #tmp_columns) X
		FOR XML PATH('')),1,1,'')
	,@TypeColumns = stuff((SELECT ', ' + ColumnType FROM (SELECT ColumnType FROM #tmp_columns) X
		FOR XML PATH('')),1,2,'')

--EXEC sp_xml_preparedocument @docHandle OUTPUT, @xmlPass

SELECT 
	@Query = N'
		DECLARE @docHandle int
		EXEC sp_xml_preparedocument @docHandle OUTPUT, @xmlPass
		INSERT INTO ' + @TableName + '
		SELECT ' + @NameColumns + ' FROM OPENXML(@docHandle, ''/ROOT/row'', 1) WITH (' + @TypeColumns + ')'
	,@Params = N'@xmlPass xml'

exec sp_executesql @Query, @Params, @xmlPass

END
GO


