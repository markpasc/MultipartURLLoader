package ru.inspirit.net
{
	import flash.errors.IllegalOperationError;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import flash.utils.Endian;
	
	/**
	 * Multipart URL Loader
	 * 
	 * Original idea by Marston Development Studio - http://marstonstudio.com/?p=36
	 * 
	 * History
	 * 2009.15.01 version 1.0
	 * Initial release
	 * 
	 * 2009.19.01 version 1.1
	 * Added options for MIME-types (default is application/octet-stream)
	 * 
	 * 2009.20.01 version 1.2
	 * Added clearVariables and clearFiles methods
	 * Small code refactoring
	 * Public methods documentaion
	 * 
	 * @author Eugene Zatepyakin
	 * @version 1.2
	 * @link http://blog.inspirit.ru/?p=139
	 */
	public class  MultipartURLLoader extends EventDispatcher
	{
		
		private var _loader:URLLoader;
		private var _boundary:String;
		private var _variableNames:Array;
		private var _fileNames:Array;
		private var _variables:Dictionary;
		private var _files:Dictionary;
		
		public function MultipartURLLoader()
		{
			_fileNames = new Array();
			_files = new Dictionary();
			_variableNames = new Array();
			_variables = new Dictionary();
			_loader = new URLLoader();
			_loader.dataFormat = URLLoaderDataFormat.BINARY;
		}
		
		/**
		 * Start uploading data to specified path
		 * 
		 * @param	path	The server script path
		 */
		public function load(path:String):void
		{
			if (path == null || path == '') throw new IllegalOperationError("You cant load without specifing PATH");
			
			var urlRequest : URLRequest = new URLRequest();
			urlRequest.url = path;
			urlRequest.contentType = 'multipart/form-data; boundary=' + getBoundary();
			urlRequest.method = URLRequestMethod.POST;
			urlRequest.data = constructPostData();
			urlRequest.requestHeaders.push( new URLRequestHeader( 'Cache-Control', 'no-cache' ) );
			
			addListener();
			_loader.load(urlRequest);
		}
		
		/**
		 * Stop loader action
		 */		
		public function close():void
		{
			try
			{
				_loader.close();
			}
			catch( e: Error ){ }
		}
		
		/**
		 * Add string variable to loader
		 * If you have already added variable with the same name it will be overwritten
		 * 
		 * @param	name	Variable name
		 * @param	value	Variable value
		 */
		public function addVariable(name:String, value:Object = ''):void
		{
			if (_variableNames.indexOf(name) == -1) {
				_variableNames.push(name);
			}
			_variables[name] = value;
		}
		
		/**
		 * Add file part to loader
		 * If you have already added file with the same fileName it will be overwritten
		 * 
		 * @param	fileContent	File content encoded to ByteArray
		 * @param	fileName	Name of the file
		 * @param	dataField	Name of the field containg file data
		 * @param	contentType	MIME type of the uploading file
		 */		
		public function addFile(fileContent:ByteArray, fileName:String, dataField:String = 'Filedata', contentType:String = 'application/octet-stream'):void
		{
			if (_fileNames.indexOf(fileName) == -1) {
				_fileNames.push(fileName);
				_files[fileName] = new FilePart(fileContent, fileName, dataField, contentType);
			} else {
				var f:FilePart = _files[fileName] as FilePart;
				f.fileContent = fileContent;
				f.fileName = fileName;
				f.dataField = dataField;
				f.contentType = contentType;
			}
		}
		
		/**
		 * Remove all variable parts
		 */
		public function clearVariables():void
		{
			_variableNames = new Array();
			_variables = new Dictionary();
		}
		
		/**
		 * Remove all file parts
		 */
		public function clearFiles():void
		{
			for each(var name:String in _fileNames) 
			{
				(_files[name] as FilePart).dispose();
			}
			_fileNames = new Array();
			_files = new Dictionary();
		}
		
		/**
		 * Dispose all class instance objects
		 */
		public function dispose(): void
		{
			removeListener();
			close();
			
			_loader = null;
			_boundary = null;
			_variableNames = null;
			_variables = null;
			_fileNames = null;
			_files = null;
		}
		
		/**
		 * Generate random boundary
		 * @return	Random boundary
		 */
		public function getBoundary():String
		{
			if (_boundary == null) {
				_boundary = '';
				for (var i:int = 0; i < 0x20; i++ ) {
					_boundary += String.fromCharCode( int( 97 + Math.random() * 25 ) );
				}
			}
			return _boundary;
		}
		
		private function constructPostData():ByteArray
		{
			var postData:ByteArray = new ByteArray();
			postData.endian = Endian.BIG_ENDIAN;
			
			postData = constructVariablesPart(postData);
			postData = constructFilesPart(postData);
			
			postData = BOUNDARY(postData);
			postData = DOUBLEDASH(postData);
			
			return postData;
		}
		
		private function constructVariablesPart(postData:ByteArray):ByteArray
		{
			var i:uint;
			var bytes:String;
			
			for each(var name:String in _variableNames) 
			{
				postData = BOUNDARY(postData);
				postData = LINEBREAK(postData);
				bytes = 'Content-Disposition: form-data; name="' + name + '"';
				for ( i = 0; i < bytes.length; i++ ) {
					postData.writeByte( bytes.charCodeAt(i) );
				}
				postData = LINEBREAK(postData);
				postData = LINEBREAK(postData);
				postData.writeUTFBytes(_variables[name]);
				postData = LINEBREAK(postData);
			}
			
			return postData;
		}
		
		private function constructFilesPart(postData:ByteArray):ByteArray
		{
			var i:uint;
			var bytes:String;
			
			if(_fileNames.length){
				for each(var name:String in _fileNames) 
				{
					postData = getFilePartData(postData, _files[name] as FilePart);
				}	
				postData = LINEBREAK(postData);
				postData = BOUNDARY(postData);
				postData = LINEBREAK(postData);
				bytes = 'Content-Disposition: form-data; name="Upload"';
				for ( i = 0; i < bytes.length; i++ ) {
					postData.writeByte( bytes.charCodeAt(i) );
				}
				postData = LINEBREAK(postData);
				postData = LINEBREAK(postData);
				bytes = 'Submit Query';
				for ( i = 0; i < bytes.length; i++ ) {
					postData.writeByte( bytes.charCodeAt(i) );
				}
				postData = LINEBREAK(postData);
			}
			
			return postData;
		}
		
		private function getFilePartData(postData:ByteArray, part:FilePart):ByteArray
		{
			var i:uint;
			var bytes:String;
			
			postData = BOUNDARY(postData);
			postData = LINEBREAK(postData);
			bytes = 'Content-Disposition: form-data; name="Filename"';
			for ( i = 0; i < bytes.length; i++ ) {
				postData.writeByte( bytes.charCodeAt(i) );
			}
			postData = LINEBREAK(postData);
			postData = LINEBREAK(postData);
			postData.writeUTFBytes(part.fileName);
			postData = LINEBREAK(postData);
			
			postData = BOUNDARY(postData);
			postData = LINEBREAK(postData);
			bytes = 'Content-Disposition: form-data; name="' + part.dataField + '"; filename="';
			for ( i = 0; i < bytes.length; i++ ) {
				postData.writeByte( bytes.charCodeAt(i) );
			}
			postData.writeUTFBytes(part.fileName);
			postData = QUOTATIONMARK(postData);
			postData = LINEBREAK(postData);
			bytes = 'Content-Type: ' + part.contentType;
			for ( i = 0; i < bytes.length; i++ ) {
				postData.writeByte( bytes.charCodeAt(i) );
			}
			postData = LINEBREAK(postData);
			postData = LINEBREAK(postData);
			postData.writeBytes(part.fileContent, 0, part.fileContent.length);
			postData = LINEBREAK(postData);
			
			return postData;
		}
		
		private function onProgress( event: ProgressEvent ): void
		{
			dispatchEvent( event );
		}
		
		private function onComplete( event: Event ): void
		{
			removeListener();
			dispatchEvent( event );
		}
		
		private function onIOError( event: IOErrorEvent ): void
		{
			removeListener();
			dispatchEvent( event );
		}
		
		private function onSecurityError( event: SecurityErrorEvent ): void
		{
			removeListener();
			dispatchEvent( event );
		}
		
		private function onHTTPStatus( event: HTTPStatusEvent ): void
		{
			dispatchEvent( event );
		}
		
		private function addListener(): void
		{
			_loader.addEventListener( Event.COMPLETE, onComplete, false, 0, true );
			_loader.addEventListener( ProgressEvent.PROGRESS, onProgress, false, 0, true );
			_loader.addEventListener( IOErrorEvent.IO_ERROR, onIOError, false, 0, true );
			_loader.addEventListener( HTTPStatusEvent.HTTP_STATUS, onHTTPStatus, false, 0, true );
			_loader.addEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError, false, 0, true );
		}
		
		private function removeListener(): void
		{
			_loader.removeEventListener( Event.COMPLETE, onComplete );
			_loader.removeEventListener( ProgressEvent.PROGRESS, onProgress );
			_loader.removeEventListener( IOErrorEvent.IO_ERROR, onIOError );
			_loader.removeEventListener( HTTPStatusEvent.HTTP_STATUS, onHTTPStatus );
			_loader.removeEventListener( SecurityErrorEvent.SECURITY_ERROR, onSecurityError );
		}
		
		private function BOUNDARY(p:ByteArray):ByteArray
		{
			var l:int = getBoundary().length;
			p = DOUBLEDASH(p);
			for (var i:int = 0; i < l; i++ ) {
				p.writeByte( _boundary.charCodeAt( i ) );
			}
			return p;
		}
		
		private function LINEBREAK(p:ByteArray):ByteArray
		{
			p.writeShort(0x0d0a);
			return p;
		}
		
		private function QUOTATIONMARK(p:ByteArray):ByteArray
		{
			p.writeByte(0x22);
			return p;
		}
		
		private function DOUBLEDASH(p:ByteArray):ByteArray
		{
			p.writeShort(0x2d2d);
			return p;
		}
		
	}
}

internal class FilePart
{
	
	public var fileContent:flash.utils.ByteArray;
	public var fileName:String;
	public var dataField:String;
	public var contentType:String;
	
	public function FilePart(fileContent:flash.utils.ByteArray, fileName:String, dataField:String = 'Filedata', contentType:String = 'application/octet-stream')
	{
		this.fileContent = fileContent;
		this.fileName = fileName;
		this.dataField = dataField;
		this.contentType = contentType;
	}
	
	public function dispose():void
	{
		fileContent = null;
		fileName = null;
		dataField = null;
		contentType = null;
	}
}