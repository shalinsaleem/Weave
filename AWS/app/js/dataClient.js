/*angular.module('myApp.controllers', []).
  controller('MyCtrl1', [function() {
  }])
  .controller('MyCtrl2', [function() {
  }]);*/

angular.module('myApp.dataClient', [])
.controller('DataClientCtrl', function($scope, $http, dialog){

$scope.dataTables = null;
$scope.conn = {
	serverType: "",
	sqlip:  "demo.oicweave.org",
	sqlport: "3306",
	sqluser: "root",
	sqlpass: "Tc1Sgp7nFc",
	sqldbname: "",
	connectionName: "",
	connectionPass: ""
};

$scope.close = function(result){
    dialog.close(result);
 };

$scope.connect = function(){
	console.log("entered connect fcn");
	var res = $scope.getEntityHierarchyInfo($scope.conn.connectionName, $scope.conn.connectionPass, 0);
	for(var i in res){
		var table = res[i];
		$('#dataTables').append($("<option/>").val(table.id.toString()).text(table.title + " (" + table.numChildren + ")"));
		//appending this table of results to the data table selector
	}
};

/**
 * This function is a wrapper for making a sevlet request to the DataService
 * 
 * @param {string} method The method name to be passed to the servlet
 * @param {Array:Object} params An array of object to be passed as parameters to the method 
 * @param {function} callback A callback function that handles the servlet response
 * 
 * @return void
 */
$scope.queryDataService = function(method, params, callback)
{ 
	var request = {
	               jsonrpc:"2.0",
	               id:"no_id",
	               method : method,
	               params : params
	};
	
	$.post('/WeaveServices/DataService', JSON.stringify(request), callback, "json");
};

/**
 * This function is a wrapper for making a sevlet request to the AdminService
 * 
 * @param {string} method The method name to be passed to the servlet
 * @param {Array:Object} params An array of object to be passed as parameters to the method 
 * @param {function} callback A callback function that handles the servlet response
 * 
 * @return void
 */
$scope.queryAdminService = function(method, params, callback)
{
	var url = '/WeaveServices/AdminService';
	var request = {
	               jsonrpc:"2.0",
	               id:"no_id",
	               method : method,
	               params : params
	};
	
	$.post(url, JSON.stringify(request), callback, "json");
};

$scope.handleResponse = function(){
	console.log("entered Response fcn");
		if(response.error)	
			alert("connection failed"); // TODO change this to a better error handling mechanism
	
		else
		{
			EntityHierarchyInfo = response.result;
		}
	};

/**
 * This function mirrors the getEntityHierarchyInfo on the servlet.
 * 
 * @param {string} connectionName The connection name to authenticate on the database
 * @param {string} password The password to authenticate on the database 
 * @param {int} entityType The entityType
 *  
 * @return {EntityHieraryInfo} An array of EntityHierarchyInfo
 */
$scope.getEntityHierarchyInfo = function(connection, password, entityType) {
	
	var EntityHierarchyInfo = [];
	
	$scope.queryAdminService("getEntityHierarchyInfo", [connection, password, entityType], $scope.handleResponse);
	
	/*function handleResponse(response){

		if(response.error)	
			alert("connection failed"); // TODO change this to a better error handling mechanism
	
		else
		{
			EntityHierarchyInfo = response.result;
		}
	 }*/
	
	 return EntityHierarchyInfo;
};

/**
 * This function mirrors the getColumn on the servlet.
 * 
 * @param {string} user The username for the connection
 * @param {string} password The password for the connection
 *  
 * @return {Object} ConnectionInfo
 */
$scope.getConnectionInfo = function(user, password) {
	
	var connectionInfo = {};
	
	queryAdminService("getConnectionInfo", [user, password], handleResponse);
	
	function handleResponse(response){
		
		if (response.error) {
			alert("connection failed"); // TODO change this to a better error handling mechanism
		}
		else{
			connectionInfo = response.result;
		}
		
		return connectionInfo;
	}	
	
};
		
/**
 * This function mirrors the getEntityChildIds on the servlet.
 * 
 * @param {int} id The parent id.
 *  
 * @return {Array:int} An array of child ids.
 */
function getEntityChildIds(id) {
	
	var childIds = [];

	queryDataService("getEntityChildIds", [id], handleResponse);
	
	function handleResponse(response){

		if(response.error)	
			alert("connection failed"); // TODO change this to a better error handling mechanism
	
		else
		{
			childIds = response.result;
		}
	 }
	
	 return childIds;
}

/**
 * This function mirrors the getEntitiesById on the servlet.
 * 
 * @param {Array:int} ids An array of ids
 *  
 * @return {Array:Object} An array of DataEntity
 */
function getDataColumnEntities(ids) {
	
	var DataEntity = [];
	
	queryDataService("getEntitiesById", [ids], handleResponse);	
	
	function handleResponse(response){

		if(response.error)	
			alert("connection failed"); // TODO change this to a better error handling mechanism
	
		else
		{
			DataEntity = response.result;
		}
	 }
	
	 return DataEntity;
}

/**
 * This function mirrors the getColumn on the servlet.
 * 
 * @param {int} ColumnId The column Id
 * @param {Number} minParam
 * @param {Number} maxParam
 * @param {Array:string} sqlParams
 *  
 * @return {Object} AttributeColumnData
 */
function getColumn(columnId, minParam, maxParam, sqlParams) {
	
	var AttributeColumnData = {};
	
	queryDataService("getColumn", [columnId, minParam, maxParam, sqlParams], handleResponse);	
	
	function handleResponse(response){

		if(response.error)	
			alert("connection failed"); // TODO change this to a better error handling mechanism
	
		else
		{
			AttributeColumnData = response.result;
		}
	 }
	
	 return AttributeColumnData;
}

});
