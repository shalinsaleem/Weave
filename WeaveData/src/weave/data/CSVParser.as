/*
    Weave (Web-based Analysis and Visualization Environment)
    Copyright (C) 2008-2011 University of Massachusetts Lowell

    This file is a part of Weave.

    Weave is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License, Version 3,
    as published by the Free Software Foundation.

    Weave is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.data
{
	import flash.utils.getTimer;
	
	import mx.utils.ObjectUtil;
	import mx.utils.StringUtil;
	
	import weave.api.WeaveAPI;
	import weave.api.core.ILinkableObject;
	import weave.api.data.ICSVParser;
	import weave.api.getCallbackCollection;
	import weave.compiler.StandardLib;
	import weave.utils.AsyncSort;

	/**
	 * This is an all-static class containing functions to parse and generate valid CSV files.
	 * Ported from AutoIt Script to Flex. Original author: adufilie
	 * 
	 * @author skolman
	 * @author adufilie
	 */	
	public class CSVParser implements ICSVParser, ILinkableObject
	{
		private static const CR:String = '\r';
		private static const LF:String = '\n';
		private static const CRLF:String = '\r\n';
		
		/**
		 * @param delimiter
		 * @param quote
		 * @param asyncMode If this is set to true, parseCSV() will work asynchronously and trigger callbacks when it finishes.
		 *                  Note that if asyncMode is enabled, you can only parse one CSV string at a time. 
		 */		
		public function CSVParser(asyncMode:Boolean = false, delimiter:String = ',', quote:String = '"')
		{
			this.asyncMode = asyncMode;
			if (delimiter && delimiter.length == 1)
				this.delimiter = delimiter;
			if (quote && quote.length == 1)
				this.quote = quote;
		}
		
		// modes set in constructor
		private var asyncMode:Boolean;
		private var delimiter:String = ',';
		private var quote:String = '"';
		private var removeBlankLines:Boolean = true;
		private var parseTokens:Boolean = true;
		
		// async state
		private var csvData:String;
		private var csvDataArray:Array;
		
		/**
		 * @return  The resulting two-dimensional Array from the last call to parseCSV().
		 */
		public function get parseResult():Array
		{
			return csvDataArray;
		}
		
		/**
		 * @inheritDoc
		 */
		public function parseCSV(csvData:String):Array
		{
			if (asyncMode)
			{
				this.csvData = csvData;
				this.csvDataArray = [];
				WeaveAPI.StageUtils.startTask(this, parseIterate, WeaveAPI.TASK_PRIORITY_3_PARSING, parseDone);
			}
			else
			{
				csvDataArray = weave.utils.parseCSV(csvData, delimiter, quote, removeBlankLines, parseTokens);
			}
			
			return csvDataArray;
		}
		
		private function parseIterate(stopTime:int):Number
		{
			weave.utils.parseCSV(csvData, delimiter, quote, removeBlankLines, parseTokens, csvDataArray);
			csvData = null;
			return 1;
		}
		
		private function parseDone():void
		{
			if (asyncMode)
				getCallbackCollection(this).triggerCallbacks();
		}
		
		/**
		 * @inheritDoc
		 */
		public function createCSV(rows:Array):String
		{
			var lines:Array = new Array(rows.length);
			for (var i:int = rows.length; i--;)
			{
				var tokens:Array = new Array(rows[i].length);
				for (var j:int = tokens.length; j--;)
					tokens[j] = createCSVToken(rows[i][j]);
				
				lines[i] = tokens.join(delimiter);
			}
			var csvData:String = lines.join(LF);
			return csvData;
		}
		
		/**
		 * @inheritDoc
		 */
		public function parseCSVRow(csvData:String):Array
		{
			if (csvData == null)
				return null;
			
			var rows:Array = parseCSV(csvData);
			if (rows.length == 0)
				return rows;
			if (rows.length == 1)
				return rows[0];
			// flatten
			return [].concat.apply(null, rows);
		}
		
		/**
		 * @inheritDoc
		 */
		public function createCSVRow(row:Array):String
		{
			return createCSV([row]);
		}
		
		/**
		 * This will surround a string with quotes and use CSV-style escape sequences if necessary.
		 * @param str A String value.
		 * @return The String value using CSV encoding.
		 */
		public function createCSVToken(str:String):String
		{
			if (str == null)
				str = '';
			
			// determine if quotes are necessary
			if ( str.length > 0
				&& str.indexOf(quote) < 0
				&& str.indexOf(delimiter) < 0
				&& str.indexOf(LF) < 0
				&& str.indexOf(CR) < 0
				&& str == StringUtil.trim(str) )
			{
				return str;
			}

			var token:String = quote;
			for (var i:int = 0; i <= str.length; i++)
			{
				var currentChar:String = str.charAt(i);
				if (currentChar == quote)
					token += quote + quote;
				else
					token += currentChar; 
			}
			return token + quote;
		}
		
		/**
		 * @inheritDoc
		 */
		public function convertRowsToRecords(rows:Array, headerDepth:int = 1):Array
		{
			if (rows.length < headerDepth)
				throw new Error("headerDepth is greater than the number of rows");
			assertHeaderDepth(headerDepth);
			
			var records:Array = new Array(rows.length - headerDepth);
			for (var r:int = headerDepth; r < rows.length; r++)
			{
				var record:Object = {};
				var row:Array = rows[r];
				for (var c:int = 0; c < row.length; c++)
				{
					var output:Object = record;
					var cell:Object = row[c];
					for (var h:int = 0; h < headerDepth; h++)
					{
						var colName:String = rows[h][c];
						if (h < headerDepth - 1)
						{
							if (!output[colName])
								output[colName] = {};
							output = output[colName];
						}
						else
							output[colName] = cell;
					}
				}
				records[r - headerDepth] = record;
			}
			return records;
		}
		
		/**
		 * @inheritDoc
		 */
		public function getRecordFieldNames(records:Array, includeNullFields:Boolean = false, headerDepth:int = 1):Array
		{
			assertHeaderDepth(headerDepth);
			
			var nestedFieldNames:Object = {};
			for each (var record:Object in records)
				_outputNestedFieldNames(record, includeNullFields, nestedFieldNames, headerDepth);
			
			var fields:Array = [];
			_collapseNestedFieldNames(nestedFieldNames, fields);
			return fields;
		}
		private function _outputNestedFieldNames(record:Object, includeNullFields:Boolean, output:Object, depth:int):void
		{
			for (var field:String in record)
			{
				if (includeNullFields || record[field] != null)
				{
					if (depth == 1)
					{
						output[field] = false;
					}
					else
					{
						if (!output[field])
							output[field] = {};
						_outputNestedFieldNames(record[field], includeNullFields, output[field], depth - 1);
					}
				}
			}
		}
		private function _collapseNestedFieldNames(nestedFieldNames:Object, output:Array, prefix:Array = null):void
		{
			for (var field:String in nestedFieldNames)
			{
				if (nestedFieldNames[field]) // either an Object or false
				{
					_collapseNestedFieldNames(nestedFieldNames[field], output, prefix ? prefix.concat(field) : [field]);
				}
				else // false means reached full nesting depth
				{
					if (prefix) // is depth > 1?
						output.push(prefix.concat(field)); // output the list of nested field names
					else
						output.push(field); // no array when max depth is 1
				}
			}
		}
		
		/**
		 * @inheritDoc
		 */
		public function convertRecordsToRows(records:Array, columnOrder:Array = null, allowBlankColumns:Boolean = false, headerDepth:int = 1):Array
		{
			assertHeaderDepth(headerDepth);
			
			var fields:Array = columnOrder;
			if (fields == null)
			{
				fields = getRecordFieldNames(records, allowBlankColumns, headerDepth);
				AsyncSort.sortImmediately(fields);
			}
			
			var r:int;
			var c:int;
			var cell:Object;
			var row:Array;
			var rows:Array = new Array(records.length + headerDepth);
			
			// construct multiple header rows from field name chains
			for (r = 0; r < headerDepth; r++)
			{
				row = new Array(fields.length);
				for (c = 0; c < fields.length; c++)
				{
					if (headerDepth > 1)
						row[c] = fields[c][r] || ''; // fields are Arrays
					else
						row[c] = fields[c] || ''; // fields are Strings
				}
				rows[r] = row;
			}
			
			for (r = 0; r < records.length; r++)
			{
				var record:Object = records[r];
				row = new Array(fields.length);
				for (c = 0; c < fields.length; c++)
				{
					if (headerDepth == 1)
					{
						// fields is an Array of Strings
						cell = record[fields[c]];
					}
					else
					{
						// fields is an Array of Arrays
						cell = record;
						for each (var field:String in fields[c])
							if (cell)
								cell = cell[field];
					}
					row[c] = cell != null ? String(cell) : '';
				}
				rows[headerDepth + r] = row;
			}
			return rows;
		}
		
		private static function assertHeaderDepth(headerDepth:int):void
		{
			if (headerDepth < 1)
				throw new Error("headerDepth must be > 0");
		}
		
		//test();
		private static var _tested:Boolean = false;
		private static function test():void
		{
			if (_tested)
				return;
			_tested = true;
			
			var _:Object = {};
			_.parser = WeaveAPI.CSVParser;
			_.csv=[
				"internal,internal,public,public,public,private,private,test",
				"id,type,title,keyType,dataType,connection,sqlQuery,empty",
				"2,1,state name,fips,string,resd,\"select fips,name from myschema.state_data\",",
				"3,1,population,fips,number,resd,\"select fips,pop from myschema.state_data\",",
				"1,0,state data table"
			].join('\n');
			_.table = _.parser.parseCSV(_.csv);
			_.records = _.parser.convertRowsToRecords(_.table, 2);
			_.rows = _.parser.convertRecordsToRows(_.records, null, false, 2);
			_.fields = _.parser.getRecordFieldNames(_.records, false, 2);
			_.fieldOrder = _.parser.parseCSV('internal,id\ninternal,type\npublic,title\npublic,keyType\npublic,dataType\nprivate,connection\nprivate,sqlQuery');
			_.rows2 = _.parser.convertRecordsToRows(_.records, _.fieldOrder, false, 2);
			weaveTrace(ObjectUtil.toString(_));
		}
	}
}
