/* ***** BEGIN LICENSE BLOCK *****
 *
 * This file is part of Weave.
 *
 * The Initial Developer of Weave is the Institute for Visualization
 * and Perception Research at the University of Massachusetts Lowell.
 * Portions created by the Initial Developer are Copyright (C) 2008-2015
 * the Initial Developer. All Rights Reserved.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/.
 * 
 * ***** END LICENSE BLOCK ***** */

package weave.data.Transforms
{
	import weave.api.core.ILinkableHashMap;
	import weave.api.core.ILinkableVariable;
	import weave.api.data.Aggregation;
	import weave.api.data.ColumnMetadata;
	import weave.api.data.DataType;
	import weave.api.data.IAttributeColumn;
	import weave.api.data.IDataSource;
	import weave.api.data.IQualifiedKey;
	import weave.api.data.IWeaveTreeNode;
	import weave.api.detectLinkableObjectChange;
	import weave.api.linkableObjectIsBusy;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.api.ui.ISelectableAttributes;
	import weave.compiler.StandardLib;
	import weave.core.LinkableHashMap;
	import weave.core.LinkableString;
	import weave.core.LinkableVariable;
	import weave.data.AttributeColumns.DynamicColumn;
	import weave.data.AttributeColumns.NumberColumn;
	import weave.data.AttributeColumns.ProxyColumn;
	import weave.data.AttributeColumns.StringColumn;
	import weave.data.DataSources.AbstractDataSource;
	import weave.data.hierarchy.ColumnTreeNode;
	import weave.utils.ColumnUtils;
	import weave.utils.EquationColumnLib;

	public class GroupedDataTransform extends AbstractDataSource implements ISelectableAttributes
	{
		WeaveAPI.ClassRegistry.registerImplementation(IDataSource, GroupedDataTransform, "Grouped data transform");

		public static const DATA_COLUMNNAME_META:String = "__GroupedDataColumnName__";

		public function GroupedDataTransform()
		{
		}
		
		public function getSelectableAttributeNames():Array
		{
			return ["Group by", "Data to transform"];
		}
		public function getSelectableAttributes():Array
		{
			return [groupByColumn, dataColumns];
		}
		
		override protected function get initializationComplete():Boolean
		{
			return super.initializationComplete
				&& !linkableObjectIsBusy(groupByColumn)
				&& !linkableObjectIsBusy(dataColumns);
		}

		override protected function initialize(forceRefresh:Boolean = false):void
		{
			super.initialize(true);
		}

		public const groupByColumn:DynamicColumn = newLinkableChild(this, DynamicColumn);
		public const groupKeyType:LinkableString = newLinkableChild(this, LinkableString);
		public const dataColumns:ILinkableHashMap = registerLinkableChild(this, new LinkableHashMap(IAttributeColumn));

		/**
		 * The session state maps a column name in dataColumns hash map to a value for its "aggregation" metadata.
		 */
		public const aggregationModes:ILinkableVariable = registerLinkableChild(this, new LinkableVariable(null, typeofIsObject));
		private function typeofIsObject(value:Object):Boolean
		{
			return typeof value == 'object';
		}
		
		override public function getHierarchyRoot():IWeaveTreeNode
		{
			if (!_rootNode)
				_rootNode = new ColumnTreeNode({
					dataSource: this,
					dependency: dataColumns.childListCallbacks,
					data: this,
					label: WeaveAPI.globalHashMap.getName(this),
					hasChildBranches: false,
					children: function():Array {
						return dataColumns.getNames().map(
							function (columnName:String, ..._):* {
								var meta:Object = {};
								meta[DATA_COLUMNNAME_META] = columnName;
								return generateHierarchyNode(meta);
							}
						);
					}
				});
			return _rootNode;
		}

		override protected function generateHierarchyNode(metadata:Object):IWeaveTreeNode
		{
			if (!metadata)
				return null;

			metadata = getColumnMetadata(metadata[DATA_COLUMNNAME_META]);

			if (!metadata)
				return null;

			return new ColumnTreeNode({
				dataSource: this,
				idFields: [DATA_COLUMNNAME_META],
				data: metadata
			});
		}
		
		private function getColumnMetadata(dataColumnName:String):Object
		{
			var column:IAttributeColumn = dataColumns.getObject(dataColumnName) as IAttributeColumn;
			if (!column)
				return null;

			var metadata:Object = ColumnMetadata.getAllMetadata(column);
			metadata[ColumnMetadata.KEY_TYPE] = groupKeyType.value || groupByColumn.getMetadata(ColumnMetadata.DATA_TYPE);
			metadata[DATA_COLUMNNAME_META] = dataColumnName;
			
			var aggState:Object = aggregationModes.getSessionState();
			var aggregation:String = aggState ? aggState[dataColumnName] : null;
			aggregation = aggregation || Aggregation.DEFAULT;
			metadata[ColumnMetadata.AGGREGATION] = aggregation;
			
			if (aggregation != Aggregation.SAME)
				metadata[ColumnMetadata.TITLE] = lang("{0} ({1})", metadata[ColumnMetadata.TITLE], aggregation);

			return metadata;
		}
		
		override protected function requestColumnFromSource(proxyColumn:ProxyColumn):void
		{
			var columnName:String = proxyColumn.getMetadata(DATA_COLUMNNAME_META);
			var metadata:Object = getColumnMetadata(columnName);
			if (!metadata)
			{
				proxyColumn.dataUnavailable();
				return;
			}
			proxyColumn.setMetadata(metadata);
			
			var dataColumn:IAttributeColumn = dataColumns.getObject(columnName) as IAttributeColumn;
			var aggregateColumn:AggregateColumn = proxyColumn.getInternalColumn() as AggregateColumn || new AggregateColumn(this);
			aggregateColumn.setup(metadata, dataColumn, getGroupKeys());

			proxyColumn.setInternalColumn(aggregateColumn);
		}

		private var _groupKeys:Array;
		private function getGroupKeys():Array
		{
			if (detectLinkableObjectChange(getGroupKeys, groupByColumn, groupKeyType))
			{
				_groupKeys = [];
				var stringLookup:Object = {};
				var keyType:String = groupKeyType.value || groupByColumn.getMetadata(ColumnMetadata.DATA_TYPE);
				for each (var key:IQualifiedKey in groupByColumn.keys)
				{
					var localName:String;
					// if the foreign key column is numeric, avoid using the formatted strings as keys
					if (groupByColumn.getMetadata(ColumnMetadata.DATA_TYPE) == DataType.NUMBER)
						localName = groupByColumn.getValueFromKey(key, Number);
					else
						localName = groupByColumn.getValueFromKey(key, String);
					
					if (!stringLookup[localName])
					{
						stringLookup[localName] = true;
						var groupKey:IQualifiedKey = WeaveAPI.QKeyManager.getQKey(keyType, localName);
						_groupKeys.push(groupKey);
					}
				}
			}
			return _groupKeys;
		}
	}
}

import flash.utils.Dictionary;

import weave.api.data.Aggregation;
import weave.api.data.ColumnMetadata;
import weave.api.data.DataType;
import weave.api.data.IAttributeColumn;
import weave.api.data.IPrimitiveColumn;
import weave.api.data.IQualifiedKey;
import weave.api.registerLinkableChild;
import weave.compiler.StandardLib;
import weave.core.SessionManager;
import weave.data.AttributeColumns.AbstractAttributeColumn;
import weave.data.AttributeColumns.NumberColumn;
import weave.data.AttributeColumns.StringColumn;
import weave.data.Transforms.GroupedDataTransform;
import weave.primitives.Dictionary2D;
import weave.utils.ColumnUtils;
import weave.utils.EquationColumnLib;
import weave.utils.VectorUtils;

internal class AggregateColumn extends AbstractAttributeColumn implements IPrimitiveColumn
{
	public function AggregateColumn(source:GroupedDataTransform)
	{
		registerLinkableChild(this, source);
		_groupByColumn = source.groupByColumn;
	}
	
	private var _groupByColumn:IAttributeColumn;
	private var _dataColumn:IAttributeColumn;
	private var _keys:Array;
	private var _cacheTriggerCounter:uint = 0;
	
	public function setup(metadata:Object, dataColumn:IAttributeColumn, keys:Array):void
	{
		if (_dataColumn && _dataColumn != dataColumn)
			(WeaveAPI.SessionManager as SessionManager).unregisterLinkableChild(this, _dataColumn);
		
		_metadata = copyValues(metadata);
		_dataColumn = dataColumn && registerLinkableChild(this, dataColumn);
		_keys = keys;
		_cacheTriggerCounter = 0;
		triggerCallbacks();
	}
	
	override public function getMetadata(propertyName:String):String
	{
		return super.getMetadata(propertyName)
			|| (_dataColumn && _dataColumn.getMetadata(propertyName));
	}
	
	override public function getMetadataPropertyNames():Array
	{
		if (_dataColumn)
			return VectorUtils.union(super.getMetadataPropertyNames(), _dataColumn.getMetadataPropertyNames());
		return super.getMetadataPropertyNames();
	}

	/**
	 * @inheritDoc
	 */
	override public function get keys():Array
	{
		return _keys;
	}
	
	/**
	 * @inheritDoc
	 */
	override public function containsKey(key:IQualifiedKey):Boolean
	{
		return _dataColumn && _dataColumn.containsKey(key);
	}
	
	public function deriveStringFromNumber(value:Number):String
	{
		return ColumnUtils.deriveStringFromNumber(_dataColumn, value);
	}
	
	/**
	 * @inheritDoc
	 */
	override public function getValueFromKey(groupKey:IQualifiedKey, dataType:Class = null):*
	{
		if (triggerCounter != _cacheTriggerCounter)
		{
			_cacheTriggerCounter = triggerCounter;
			dataCache = new Dictionary2D();
		}
		
		if (!dataType)
			dataType = Array;
		
		var cache:Dictionary = dataCache.dictionary[dataType] as Dictionary;
		if (!cache)
			dataCache.dictionary[dataType] = cache = new Dictionary();
		var value:* = cache[groupKey];
		if (value === undefined)
		{
			value = getAggregateValue(groupKey, dataType);
			cache[groupKey] = value === undefined ? UNDEFINED : value;
		}
		else if (value === UNDEFINED)
			value = undefined;
		return value;
	}
	
	private static const UNDEFINED:Object = {}; // used as a placeholder for undefined values in dataCache
	
	/**
	 * Computes an aggregated value.
	 * @param groupKey A key that references a String value and is associated with a set of input keys.
	 * @param dataType The dataType parameter passed to the EquationColumn.
	 */
	public function getAggregateValue(groupKey:IQualifiedKey, dataType:Class):*
	{
		if (groupKey.keyType != this.getMetadata(ColumnMetadata.KEY_TYPE))
			return undefined;
		
		if (!dataType)
			dataType = Array;
		
		// get input keys from groupKey
		var keys:Array = EquationColumnLib.getAssociatedKeys(_groupByColumn, groupKey, true);
		var meta_dataType:String = _dataColumn ? _dataColumn.getMetadata(ColumnMetadata.DATA_TYPE) : null;
		var inputType:Class = DataType.getClass(meta_dataType);

		if (dataType === Array)
		{
			// We want a flat Array of values, not a nested Array, so we request the original input type
			// in case they need to be pre-aggregated.
			return getValues(_dataColumn, keys, inputType);
		}
		
		var meta_aggregation:String = this.getMetadata(ColumnMetadata.AGGREGATION) || Aggregation.DEFAULT;
		
		if (inputType === Number || inputType === Date)
		{
			var array:Array = this.getValueFromKey(groupKey, Array) as Array;
			var number:Number = NumberColumn.aggregate(array, meta_aggregation);
			
			if (dataType === Number)
				return number;
			
			if (dataType === Date)
				return new Date(number);
			
			if (dataType === String)
			{
				if (isNaN(number) && array && array.length > 1 && meta_aggregation == Aggregation.SAME)
					return StringColumn.AMBIGUOUS_DATA;
				return ColumnUtils.deriveStringFromNumber(_dataColumn, number)
					|| StandardLib.formatNumber(number);
			}
			
			return undefined;
		}
		
		if (inputType === String)
		{
			// get a list of values of the requested type, then treat them as Strings and aggregate the Strings
			var values:Array = getValues(_dataColumn, keys, dataType);

			var string:String = StringColumn.aggregate(values, meta_aggregation);
			
			if (dataType === Number)
				return StandardLib.asNumber(string);
			
			if (dataType === String)
				return string;
			
			return undefined;
		}
		
		if (meta_dataType === DataType.GEOMETRY)
		{
			if (dataType === String)
				return this.containsKey(groupKey) ? 'Geometry(' + groupKey.keyType + '#' + groupKey.localName + ')' : '';
		}
		
		return undefined;
	}
	
	/**
	 * Gets an Array of values from a column, excluding missing data.
	 * Flattens Arrays.
	 */
	private static function getValues(column:IAttributeColumn, keys:Array, dataType:Class):Array
	{
		var values:Array = [];
		if (!column)
			return values;
		for each (var key:IQualifiedKey in keys)
		{
			if (!column.containsKey(key))
				continue;
			var value:* = column.getValueFromKey(key, dataType);
			if (value is Array)
				values.push.apply(values, value);
			else
				values.push(value);
		}
		return values;
	}
}
