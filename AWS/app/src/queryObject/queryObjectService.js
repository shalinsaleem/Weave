'use strict';
/**
 * Query Object Service provides access to the main "singleton" query object.
 *
 * Don't worry, it will be possible to manage more than one query object in the
 * future.
 */
var aws = {};
//using value recipes so that these tools could be used elsewhere as well TODO: make them into directives
QueryObject.value('indicator_tool', {
												title : 'Indicator',
												template_url : 'src/analysis/indicator/indicator.tpl.html',
												description : 'Choose an Indicator for the Analysis',
												category : 'indicatorfilter'
});

QueryObject.value('geoFilter_tool',{
										title : 'Geography Filter',
										template_url : 'src/analysis/data_filters/geography.tpl.html',
										description : 'Filter data by States and Counties',
										category : 'datafilter'
});

QueryObject.value('timeFilter_tool', {
											title : 'Time Period Filter',
											template_url : 'src/analysis/data_filters/time_period.tpl.html',
											description : 'Filter data by Time Period',
											category : 'datafilter'
});

QueryObject.value('byVariableFilter_tool', {
													title : 'By Variable Filter',
													template_url : 'src/analysis/data_filters/by_variable.tpl.html',
													description : 'Filter data by Variables',
													category : 'datafilter'
});

QueryObject.value('BarChartTool',{
										id : 'BarChartTool',
										title : 'Bar Chart Tool',
										template_url : 'src/visualization/tools/barChart/bar_chart.tpl.html'

});

QueryObject.value('MapTool', {
									id : 'MapTool',
									title : 'Map Tool',
									template_url : 'src/visualization/tools/mapChart/map_chart.tpl.html'
});

QueryObject.value('ScatterPlotTool', {
											id : 'ScatterPlotTool',
											title : 'Scatter Plot Tool',
											template_url : 'src/visualization/tools/scatterPlot/scatter_plot.tpl.html',
											description : 'Display a Scatter Plot in Weave'
});

QueryObject.value('DataTableTool', {
											id : 'DataTableTool',
											title : 'Data Table Tool',
											template_url : 'src/visualization/tools/dataTable/data_table.tpl.html',
											description : 'Display a Data Table in Weave'
});

QueryObject.value('color_Column', {	
											id : 'color_Column',
											title : 'Color Column',
											template_url : 'src/visualization/tools/color/color_Column.tpl.html',
											description : 'Set the color column in Weave'
});


QueryObject.value('key_Column', {
										id : 'Key_Column', 
										title : 'Key Column',
										template_url : 'src/visualization/tools/color/key_Column.tpl.html',
										description : 'Set the key column in Weave'
});
QueryObject.service('runQueryService', ['errorLogService','$modal', function(errorLogService, $modal){

	/**
	 * This function is a wrapper for making a request to a JSON RPC servlet
	 * 
	 * @param {string} url
	 * @param {string} method The method name to be passed to the servlet
	 * @param {?Array|Object} params An array of object to be passed as parameters to the method 
	 * @param {Function} resultHandler A callback function that handles the servlet result
	 * @param {string|number=}queryId
	 * @see aws.addBusyListener
	 */
	this.queryRequest = function(url, method, params, resultHandler, queryId)
	{
	    var request = {
	        jsonrpc: "2.0",
	        id: queryId || "no_id",
	        method: method,
	        params: params
	    };
	    
	    $.post(url, JSON.stringify(request), handleResponse, "text");

	    function handleResponse(response)
	    {
	    	// parse result for target window to use correct Array implementation
	    	response = JSON.parse(response);
	    	
	        if (response.error)
	        {	
	        	console.log(JSON.stringify(response, null, 3));
	        	//log the error
	        	errorLogService.logInErrorLog(response.error.message);
	        	//open the error log
	        	$modal.open(errorLogService.errorLogModalOptions);
	        }
	        else if (resultHandler){
	            return resultHandler(response.result, queryId);
	        }
	    }
	};
	
	
	/**
	 * Makes a batch request to a JSON RPC 2.0 service. This function requires jQuery for the $.post() functionality.
	 * @param {string} url The URL of the service.
	 * @param {string} method Name of the method to call on the server for each entry in the queryIdToParams mapping.
	 * @param {Array|Object} queryIdToParams A mapping from queryId to RPC parameters.
	 * @param {function(Array|Object)} resultsHandler Receives a mapping from queryId to RPC result.
	 */
	this.bulkQueryRequest = function(url, method, queryIdToParams, resultsHandler)
	{
		var batch = [];
		for (var queryId in queryIdToParams)
			batch.push({jsonrpc: "2.0", id: queryId, method: method, params: queryIdToParams[queryId]});
		$.post(url, JSON.stringify(batch), handleBatch, "json");
		function handleBatch(batchResponse)
		{
			var results = Array.isArray(queryIdToParams) ? [] : {};
			for (var i in batchResponse)
			{
				var response = batchResponse[i];
				if (response.error)
					console.log(JSON.stringify(response, null, 3));
				else
					results[response.id] = response.result;
			}
			if (resultsHandler)
				resultsHandler(results);
		}
	};
}]);


QueryObject.service("queryService", ['$q', '$rootScope', 'WeaveService', 'runQueryService',
                                     'dataServiceURL', 'adminServiceURL','projectManagementURL', 'scriptManagementURL','computationServiceURL',
                                     'BarChartTool', 'MapTool', 'DataTableTool', 'ScatterPlotTool', 'color_Column', 'key_Column',
                         function($q, scope, WeaveService, runQueryService, 
                        		 dataServiceURL, adminServiceURL, projectManagementURL, scriptManagementURL, computationServiceURL,
                        		 BarChartTool, MapTool, DataTableTool, ScatterPlotTool, color_Column, key_Column) {
    
	var SaveState =  function () {
        sessionStorage.queryObject = angular.toJson(queryObject);
    };

    var RestoreState = function () {
    	this.queryObject = angular.fromJson(sessionStorage.queryObject);
    };

	var that = this; // point to this for async responses

	this.queryObject = {
			title : "Beta Query Object",
			date : new Date(),
    		author : "",
    		dataTable : "",
			ComputationEngine : "R",
			Indicator : "",
			IndicatorRemap : [],
			filters : {
				or : []
			},
			GeographyFilter : {
				stateColumn:{},
				countyColumn:{},
				metadataTable:{}
			},
			openInNewWindow : false,
			scriptOptions : {},
			scriptSelected : "",
			TimePeriodFilter : {},
			ByVariableFilters : [],
			ByVariableColumns : [],
			properties : {
				validationStatus : "test",
				isQueryValid : false
			},
			visualizations : {
				MapTool : {
					title : 'Map Tool',
					template_url : 'src/visualization/tools/mapChart/map_chart.tpl.html',
					enabled : false
				},
				BarChartTool : {
					title : 'Bar Chart Tool',
					template_url : 'src/visualization/tools/barChart/bar_chart.tpl.html',
					enabled : false
				},
				DataTableTool : {
					title : 'Data Table Tool',
					template_url : 'src/visualization/tools/dataTable/data_table.tpl.html',
					enabled : false
				},
				ScatterPlotTool : {
					title : 'Scatter Plot Tool',
					template_url : 'src/visualization/tools/scatterPlot/scatter_plot.tpl.html',
					enabled : false
				},
				color_Column : {
					title : "Color Column",
					template_url : 'src/visualization/tools/color/color_Column.tpl.html'
				},
				key_Column : {
					title : "Key Column",
					template_url : 'src/visualization/tools/color/key_Column.tpl.html'
				}
			},
			resultSet : {}
	};    		
    
	
	this.cache = {
			dataTableList : [],
			scriptList : [],
			filters : [],
			numericalColumns : []
	};



	
	/**
     * This function wraps the async aws runScript function into an angular defer/promise
     * So that the UI asynchronously wait for the data to be available...
     */
    this.runScript = function(scriptName) {
        
    	var deferred = $q.defer();

    	runQueryService.queryRequest(computationServiceURL, 'runScript', [scriptName], function(result){	
    		scope.$safeApply(function() {
				deferred.resolve(result);
			});
		});
    	
        return deferred.promise;
    };
    
    
    /**
     * this function pulls data before running a script
     * @param inputs the ids of the columns to pull the data
     * @param reMaps remapObjects to overwrite data values temporarily
     */
    this.getDataFromServer = function(inputs, reMaps) {
    	
    	var deferred = $q.defer();

    	runQueryService.queryRequest(computationServiceURL, 'getDataFromServer', [inputs, reMaps], function(result){	
    		scope.$safeApply(function() {
				deferred.resolve(result);
			});
		});
    	
        return deferred.promise;
    };
    
	
	/**
     * This function wraps the async aws getListOfScripts function into an angular defer/promise
     * So that the UI asynchronously wait for the data to be available...
     */
    this.getListOfScripts = function(forceUpdate) {
    	if(!forceUpdate) {
			return this.cache.scriptList;
    	} else {
    		runQueryService.queryRequest(scriptManagementURL, 'getListOfScripts', null, function(result){
    			that.cache.scriptList = result;
    		});
    	}
    };

    /**
     * returns the base64 encoded session state of the visualizations generated by a query object
     */
    this.getSessionState = function(params){
    	if(!(WeaveService.weaveWindow.closed)){
    		var base64SessionState = WeaveService.getSessionState();
    		this.writeSessionState(base64SessionState, params);
    	}
    };
   
    this.writeSessionState = function(base64String, params){
    	var projectName;
    	var userName;
    	var queryObjectTitles;
    	var projectDescription;
    	
    	if(angular.isDefined(params.projectEntered))
    		{
	    		projectName = params.projectEntered;
	    		projectDescription = "This project belongs to " + projectName;
    		}
    	else
    		{
	    		projectName = "Other";
	    		projectDescription = "These query objects do not belong to any project"; 
    		}
    	if(angular.isDefined(params.queryTitleEntered)){
    		queryObjectTitles = params.queryTitleEntered;
    		this.queryObject.title = queryObjectTitles;
    	}
    	else
    		 queryObjectTitles = this.queryObject.title;
    	if(angular.isDefined(params.userName)){
    		userName = params.userName;
    		this.queryObject.author = userName;
    	}
    	else
    		userName = "Awesome User";
    	
    	var qo =this.queryObject;
    	   	for(var key in qo.scriptOptions) {
    	    		var input = qo.scriptOptions[key];
    	    		//console.log(typeof input);
    	    		switch(typeof input) {
    	    			
    	    			case 'string' :
    	    				var inputVal = tryParseJSON(input);
    	    				if(inputVal) {  // column input
    	    					qo.scriptOptions[key] = inputVal;
    	    				} else { // regular string
    	    					qo.scriptOptions[key] = input;
    	    				}
    	    				break;
    	    			
    	    			default:
    	    				console.log("unknown script input type");
    	    		}
    	    	}
    	    	if (typeof(qo.Indicator) == 'string'){
    	    		var inputVal = tryParseJSON(qo.Indicator);
    				if(inputVal) {  // column input
    					qo.Indicator = inputVal;
    				} else { // regular string
    					qo.Indicator = input;
    				}
    	    	}
    	var queryObjectJsons = angular.toJson(qo);
    	var resultVisualizations = base64String;
    	
    	
    	runQueryService.queryRequest(projectManagementURL, 'writeSessionState', [userName, projectDescription, queryObjectTitles, queryObjectJsons, resultVisualizations, projectName], function(result){
    		console.log("adding status", result);
    		alert(queryObjectTitles + " has been added");
    	});
    };
    
    /**
     * This function wraps the async aws getListOfScripts function into an angular defer/promise
     * So that the UI asynchronously wait for the data to be available...
     */
    this.getScriptMetadata = function(scriptName, forceUpdate) {
        
    	var deferred = $q.defer();

    	if (!forceUpdate) {
    		return this.cache.scriptMetadata;
    	}
    	if(scriptName) {
    		runQueryService.queryRequest(scriptManagementURL, 'getScriptMetadata', [scriptName], function(result){
    			that.cache.scriptMetadata = result;
    			scope.$safeApply(function() {
    				deferred.resolve(that.cache.scriptMetadata);
    			});
    		});
    	}
        return deferred.promise;
    };

	/**
	  * This function makes nested async calls to the aws function getEntityChildIds and
	  * getDataColumnEntities in order to get an array of dataColumnEntities children of the given id.
	  * We use angular deferred/promises so that the UI asynchronously wait for the data to be available...
	  */
	this.getDataColumnsEntitiesFromId = function(id, forceUpdate) {
		
		var deferred = $q.defer();

		if(!forceUpdate) {
			return that.cache.columns;
		} else {
			if(id) {
				runQueryService.queryRequest(dataServiceURL, "getEntityChildIds", [id], function(idsArray) {
					//console.log("idsArray", idsArray);
					runQueryService.queryRequest(dataServiceURL, "getEntitiesById", [idsArray], function (dataEntityArray){
						//console.log("dataEntirtyArray", dataEntityArray);
						//console.log("columns", that.cache.columnsb);
						
						that.cache.numericalColumns = [];//collects numerical columns for statistics calculation
						
						that.cache.columns = $.map(dataEntityArray, function(entity) {
							if(entity.publicMetadata.hasOwnProperty("aws_metadata")) {//will work if the column already has the aws_metadata as part of its public metadata
								var metadata = angular.fromJson(entity.publicMetadata.aws_metadata);
								
								if(metadata.hasOwnProperty("columnType")) {
									var columnObject = {};
									columnObject.id = entity.id;
									columnObject.title = entity.publicMetadata.title;
									columnObject.columnType = metadata.columnType;
									columnObject.varType = metadata.varType;
									columnObject.description = metadata.description || "";
									
									if(metadata.varRange)
										columnObject.varRange = metadata.varRange;
//									//pick all numerical columns and create a matrix
									if(metadata.varRange && (metadata.varType == "continuous") && (metadata.columnType != "geography"))
										{
											that.cache.numericalColumns.push(columnObject);
										}
									return columnObject;

								}
								else//handling an empty aws-metadata object 
									{
									
										var columnObject = {};
										columnObject.id = entity.id;
										columnObject.title = entity.publicMetadata.title;
										columnObject.columnType = "";
										columnObject.description =  "";
										
										return columnObject;
									}
								
							}
							else{//if its doesnt have aws_metadata as part of its public metadata, create a partial aws_metadata object
								
									var columnObject = {};
									columnObject.id = entity.id;
									columnObject.title = entity.publicMetadata.title;
									columnObject.columnType = "";
									columnObject.description =  "";
									
									return columnObject;
								
							}
						});
						scope.$safeApply(function() {
							deferred.resolve(that.cache.columns);
						});
					});
				});
				
			}
		}
        return deferred.promise;
    };
    
    this.getEntitiesById = function(idsArray, forceUpdate) {
    	
    	var deferred = $q.defer();

		if(!forceUpdate) {
			return that.cache.dataColumnEntities;
		} else {
			if(idsArray) {
				runQueryService.queryRequest(dataServiceURL, "getEntitiesById", [idsArray], function (dataEntityArray){
					
					that.cache.dataColumnEntities = dataEntityArray;
					
					scope.$safeApply(function() {
						deferred.resolve(that.cache.dataColumnEntities);
					});
				});
			}
		}
		
        return deferred.promise;
    	
    };
        
        
    /**
	  * This function makes nested async calls to the aws function getEntityIdsByMetadata and
	  * getDataColumnEntities in order to get an array of dataColumnEntities children that have metadata of type geometry.
	  * We use angular deferred/promises so that the UI asynchronously wait for the data to be available...
	  */
	this.getGeometryDataColumnsEntities = function(forceUpdate) {

		var deferred = $q.defer();

		if(!forceUpdate) {
			return that.cache.geometryColumns;
		}
		
		runQueryService.queryRequest(dataServiceURL, 'getEntityIdsByMetadata', [{"dataType" :"geometry"}, 1], function(idsArray){
			runQueryService.queryRequest(dataServiceURL, 'getEntitiesById', [idsArray], function(dataEntityArray){
				that.cache.geometryColumns = $.map(dataEntityArray, function(entity) {
					return {
						id : entity.id,
						title : entity.publicMetadata.title,
						keyType : entity.publicMetadata.keyType
					};
				});
				scope.$safeApply(function() {
					deferred.resolve(that.cache.geometryColumns);
				});
			});
		});

		return deferred.promise;
    };
    
    /**
     * This function wraps the async aws getDataTableList to get the list of all data tables
     * again angular defer/promise so that the UI asynchronously wait for the data to be available...
     */
    this.getDataTableList = function(forceUpdate){
    	var deferred = $q.defer();

    	if(!forceUpdate) {
			return that.cache.dataTableList;
    	} else {
    		runQueryService.queryRequest(dataServiceURL, 'getDataTableList', null, function(EntityHierarchyInfoArray){
    			that.cache.dataTableList = EntityHierarchyInfoArray;
    			scope.$safeApply(function() {
    				deferred.resolve(that.cache.dataTableList);
    			});
    		 });
    	}
        return deferred.promise;
    };
        
    this.getDataMapping = function(varValues)
    {
        	var deferred = $q.defer();

        	var callback = function(result)
        	{
         		scope.$safeApply(function(){
                   deferred.resolve(result);
         		});
        	};

         	if (Array.isArray(varValues))
         	{
         		setTimeout(function(){ callback(varValues); }, 0);
         		return deferred.promise;
         	}

         	//if (typeof varValues == 'string')
         	//	varValues = {"aws_id": varValues};
         		
         	runQueryService.queryRequest(dataServiceURL, 'getColumn', [varValues, NaN, NaN, null],
         		function(columnData) {
         			var result = [];
         			for (var i in columnData.keys) 
         				result[i] = {"value": columnData.keys[i], "label": columnData.data[i]};
         			callback(result);
     			}
     		);
	        return deferred.promise;
    };
        
      
      
        this.getDataSetFromTableId = function(id,forceUpdate){
          	
        	var deferred = $q.defer();
        	
        	if(!forceUpdate) {
      			return this.cache.geographyMetadata;
        	} else {
        		runQueryService.queryRequest(dataServiceURL, "getEntityChildIds", [id], function(ids){
        			runQueryService.queryRequest(dataServiceURL, "getDataSet", [ids], function(result){
        				that.cache.geographyMetadata = result;
        				scope.$safeApply(function() {
            				deferred.resolve(that.cache.geographyMetadata);
            			});
        			});
        		});
        	}
        	
            return deferred.promise;
        };
        
        this.updateEntity = function(user, password, entityId, diff) {

        	var deferred = $q.defer();
            
        	runQueryService.queryRequest(adminServiceURL, 'updateEntity', [user, password, entityId, diff], function(){
                
            	scope.$safeApply(function(){
                    deferred.resolve();
                });
            });
            return deferred.promise;
        };
        
         // Source: http://www.bennadel.com/blog/1504-Ask-Ben-Parsing-CSV-Strings-With-Javascript-Exec-Regular-Expression-Command.htm
         // This will parse a delimited string into an array of
         // arrays. The default delimiter is the comma, but this
         // can be overriden in the second argument.
 
        this.CSVToArray = function(strData, strDelimiter) {
            // Check to see if the delimiter is defined. If not,
            // then default to comma.
            strDelimiter = (strDelimiter || ",");
            // Create a regular expression to parse the CSV values.
            var objPattern = new RegExp((
            // Delimiters.
            "(\\" + strDelimiter + "|\\r?\\n|\\r|^)" +
            // Quoted fields.
            "(?:\"([^\"]*(?:\"\"[^\"]*)*)\"|" +
            // Standard fields.
            "([^\"\\" + strDelimiter + "\\r\\n]*))"), "gi");
            // Create an array to hold our data. Give the array
            // a default empty first row.
            var arrData = [[]];
            // Create an array to hold our individual pattern
            // matching groups.
            var arrMatches = null;
            // Keep looping over the regular expression matches
            // until we can no longer find a match.
            while (arrMatches = objPattern.exec(strData)) {
                // Get the delimiter that was found.
                var strMatchedDelimiter = arrMatches[1];
                // Check to see if the given delimiter has a length
                // (is not the start of string) and if it matches
                // field delimiter. If id does not, then we know
                // that this delimiter is a row delimiter.
                if (strMatchedDelimiter.length && (strMatchedDelimiter != strDelimiter)) {
                    // Since we have reached a new row of data,
                    // add an empty row to our data array.
                    arrData.push([]);
                }
                // Now that we have our delimiter out of the way,
                // let's check to see which kind of value we
                // captured (quoted or unquoted).
                if (arrMatches[2]) {
                    // We found a quoted value. When we capture
                    // this value, unescape any double quotes.
                    var strMatchedValue = arrMatches[2].replace(
                    new RegExp("\"\"", "g"), "\"");
                } else {
                    // We found a non-quoted value.
                    var strMatchedValue = arrMatches[3];
                }
                // Now that we have our value string, let's add
                // it to the data array.
                arrData[arrData.length - 1].push(strMatchedValue);
            }
            // Return the parsed data.
            return (arrData);
        };
}]);