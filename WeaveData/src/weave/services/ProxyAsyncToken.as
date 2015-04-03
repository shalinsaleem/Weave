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

package weave.services
{
	import flash.events.Event;
	import flash.utils.ByteArray;
	
	import mx.core.mx_internal;
	import mx.messaging.messages.ErrorMessage;
	import mx.rpc.AsyncToken;
	import mx.rpc.Fault;
	import mx.rpc.IResponder;
	import mx.rpc.events.FaultEvent;
	import mx.rpc.events.ResultEvent;
	import mx.utils.ObjectUtil;
	
	import weave.api.reportError;
	import weave.utils.fixErrorMessage;
	
	use namespace mx_internal;

	/**
	 * Provides a way to delay invoking an asynchronous method and cast the result before broadcasting it.
	 * 
	 * @author adufilie
	 */
	public class ProxyAsyncToken extends AsyncToken
	{
		/**
		 * Creates a ProxyAsyncToken.
		 * @param invoke A function which returns the AsyncToken we are proxying.
		 * @param params Parameters to pass to invoke().
		 * @param resultCastFunction Function which accepts ResultEvent.result and returns a modified result.
		 * @param handleErrorMessageObjects If set to true and ResultEvent.result is an ErrorMessage object, calls fault handlers instead of result handlers.
		 */		
		public function ProxyAsyncToken(invoke:Function, params:Array = null, resultCastFunction:Function = null, handleErrorMessageObjects:Boolean = true)
		{
			super();
			
			_invoke = invoke;
			_params = params;
			_resultCastFunction = resultCastFunction;
			_handleErrorMessageObjects = handleErrorMessageObjects;
		}
		
		public var _invoke:Function;
		public var _params:Array;
		public var _resultCastFunction:Function;
		public var _handleErrorMessageObjects:Boolean;

		public var eventReceived:Event = null; // for debugging
		
		// the token associated with the call, null until query is performed
		private var internalAsyncToken:AsyncToken = null;

		// used to keep track of the time spent running responder functions
		private var processingTime:int = 0;
		
		/**
		 * This function will invoke the async method using the parameters previously specified.
		 */
		public function invoke():void
		{
			if (internalAsyncToken != null)
			{
				trace("invoke(): Operation has already been called.", toString());
				return;
			}
			
			internalAsyncToken = _invoke.apply(null, _params);
			
			// forward the event to the responders in this AsyncToken.
			internalAsyncToken.addResponder(new DelayedAsyncResponder(handleResult, handleFault, this));
		}
		
		/**
		 * This function gets called when the internalAsyncToken runs its result functions.
		 * This function will call the result functions of the responders added to this object.
		 */
		private function handleResult(event:ResultEvent, token:Object = null):void
		{
			eventReceived = event;
			
			var fault:Fault;
			try
			{
				if (_resultCastFunction != null && !(_handleErrorMessageObjects && event.result is ErrorMessage))
					event.setResult(_resultCastFunction(event.result));
			}
			catch (e:Error)
			{
				fixErrorMessage(e);
				trace(e.getStackTrace());
				//reportError(e, null, event.result);
				var faultString:String = "Cannot read response from server";
				if (event.result == null || (event.result is ByteArray && (event.result as ByteArray).length == 0))
					faultString = "No response from server";
				fault = new Fault(e.name, faultString, e.message);
				fault.content = event.result;
				handleFault(FaultEvent.createEvent(fault, this));
				return;
			}
			
			// if option is enabled, check if event.result is an ErrorMessage object.
			if (_handleErrorMessageObjects && event.result is ErrorMessage)
			{
				// When an ErrorMessage is returned by the AsyncToken, treat it as a fault.
				var msg:ErrorMessage = event.result as ErrorMessage;
				fault = new Fault(msg.faultCode, msg.faultString, msg.faultDetail);
				fault.message = msg;
				fault.content = event;
				fault.rootCause = this;
				var faultEvent:FaultEvent = FaultEvent.createEvent(fault, this, msg);
				handleFault(faultEvent, token);
				return;
			}
			
			// broadcast result to responders in the order they were added
			if (responders != null)
				for (var i:int = 0; i < responders.length; i++)
					(responders[i] as IResponder).result(event);
		}
		/**
		 * This function gets called when the internalAsyncToken runs its fault functions.
		 * This function will call the fault functions of the responders added to this object.
		 */
		private function handleFault(event:FaultEvent, token:Object = null):void
		{
			eventReceived = event;
			
			// broadcast fault to responders in the order they were added
			if (responders != null)
				for (var i:int = 0; i < responders.length; i++)
					(responders[i] as IResponder).fault(event);
		}
		
		protected var truncateToStringOutput:Boolean = true; // set to true to prevent toString() from returning lengthy strings
		
		private function arrayToString(a:Array, truncateItemLength:int = 64, includeBrackets:Boolean = true):String
		{
			var result:String = '';
			var s:String;
			for (var i:int = 0; i < a.length; i++)
			{
				if (i > 0)
					result += ', ';
				
				if (a[i] is Array)
					s = arrayToString(a[i], int.MAX_VALUE, false);
				else if (a[i] is String)
					s = a[i];
				else
					s = ObjectUtil.toString(a[i]);
				
				if (s != null && s.length > truncateItemLength)
					s = s.substr(0, truncateItemLength - 3) + '...';
				
				if (a[i] is String)
					s = '"' + s + '"';
				if (a[i] is Array)
					s = '[' + s + ']';
				
				result += s;
			}
			
			if (includeBrackets)
				return '[' + result + ']'
			
			return result;
		}
		
		override public function toString():String
		{
			return arrayToString(_params);
		}
	}
}
