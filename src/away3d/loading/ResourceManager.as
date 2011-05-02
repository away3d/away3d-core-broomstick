﻿package away3d.loading
{
	import away3d.events.LoaderEvent;
	import away3d.events.ResourceEvent;
	import away3d.loading.parsers.AC3DParser;
	import away3d.loading.parsers.AWD1Parser;
	import away3d.loading.parsers.AWD2Parser;
//	import away3d.loading.parsers.ColladaParser;
	import away3d.loading.parsers.ImageParser;
	import away3d.loading.parsers.MD2Parser;
	import away3d.loading.parsers.MD5AnimParser;
	import away3d.loading.parsers.MD5MeshParser;
	import away3d.loading.parsers.Max3DSParser;
	import away3d.loading.parsers.OBJParser;
	import away3d.loading.parsers.ParserBase;
	
	import flash.events.EventDispatcher;

	/**
	 * ResourceManager is a singleton class providing a central access point for external resources and their disposal,
	 * such as meshes, materials, etc, while taking care of loading transparently, when needed.
	 */
	public class ResourceManager extends EventDispatcher
	{
		private static var _instance : ResourceManager;

		private var _resources : Array;
		private var _loadingSessions : Vector.<ResourceLoadSession>;
		private var _parsers : Vector.<Class>;

		/**
		 * Creates a new ResourceManager object. Should NOT be called directly.
		 * @param se Inhibits direct creation.
		 *
		 * @private
		 */
		public function ResourceManager(se : SingletonEnforcer)
		{
			_resources = [];
			_loadingSessions = new Vector.<ResourceLoadSession>();
			_parsers = new Vector.<Class>();
			addParser(AWD1Parser);
			addParser(AWD2Parser);
			addParser(AC3DParser);
			addParser(Max3DSParser);
//			addParser(ColladaParser);
			addParser(MD2Parser);
			addParser(MD5MeshParser);
			addParser(MD5AnimParser);
			addParser(OBJParser);
			addParser(ImageParser);
		}

		/**
		 * Gets the singleton instance of the ResourceManager.
		 */
		public static function get instance() : ResourceManager
		{
			return _instance ||= new ResourceManager(new SingletonEnforcer());
		}

		/**
		 * Retrieve the resource at the given url. Loading and parsing is only performed on the first time for the url,
		 * and if not cleared.
		 *
		 * @param uri The url or id of the resource to be retrieved. If not parsed before, it should be a url.
		 * @param ignoreDependencies Indicates whether or not dependencies should be ignored or loaded.
		 * @param parser An optional parser object that will translate the data into a usable resource.
		 * @return A handle to the retrieved resource.
		 */
		public function getResource(uri : String, ignoreDependencies : Boolean = false, parser : ParserBase = null) : IResource
		{
			if (!_resources[uri]) {
				if (_loadingSessions.indexOf(uri) == -1){
					_resources[uri] = loadResource(uri, ignoreDependencies, parser);
				}
			}
			else {
				dispatchEvent(new ResourceEvent(ResourceEvent.DEPENDENCY_RETRIEVED, _resources[uri], uri));
			}
			
			return _resources[uri];
		}

		/**
		 * Clears the memory used by a resource, including all of its dependencies.
		 *
		 * @param resource The resource to be cleared.
		 */
		public function clearResource(resource : IResource) : void
		{
			for (var key : String in _resources) {
				if (_resources[key] == resource) {
					resource.dispose(true);
					_resources[key] = null;
					return;
				}
				else {
					throw new Error("Resource not found");
				}
			}
		}

		/**
		 * Adds the specified parser class to available resource parsers.
		 * @param parser A Parser class that will translate data being loaded into a usable resource.
		 */
		public function addParser(parser : Class):void
		{
			_parsers.push(parser);
		}
		
		/**
		 * Retrieves the resource parsed from the given data.
		 * @param data The data to be parsed.
		 * @param id The id that will be assigned to the resource. This can later also be used by the getResource method.
		 * @param ignoreDependencies Indicates whether or not dependencies should be ignored or loaded.
		 * @param parser An optional parser object that will translate the data into a usable resource.
		 * @return A handle to the retrieved resource.
		 */
		public function parseData(data : *, id : String, ignoreDependencies : Boolean = true, parser : ParserBase = null) : IResource
		{
			if (!_resources[id]) {
				if (_loadingSessions.indexOf(id) == -1)
					_resources[id] = parseResource(data, id, ignoreDependencies, parser);
			}
			else {
				dispatchEvent(new ResourceEvent(ResourceEvent.DEPENDENCY_RETRIEVED, _resources[id], id));
			}
			return _resources[id];
		}

		/**
		 * Loads a yet unloaded resource file from the given url.
		 * @param url The url of the file to be loaded.
		 * @param ignoreDependencies Indicates whether or not dependencies should be ignored or loaded.
		 * @param parser An optional parser object that will translate the data into a usable resource.
		 * @return A handle to the retrieved resource.
		 */
		private function loadResource(url : String, ignoreDependencies : Boolean = false, parser : ParserBase = null) : IResource
		{
			var session : ResourceLoadSession = new ResourceLoadSession(_parsers);
			_loadingSessions.push(session);
			session.addEventListener(ResourceEvent.RESOURCE_RETRIEVED, onResourceRetrieved);
			session.addEventListener(ResourceEvent.DEPENDENCY_RETRIEVED, onDependencyRetrieved);
			session.addEventListener(LoaderEvent.LOAD_ERROR, onDependencyRetrievingError);
			session.load(url, ignoreDependencies, parser);
			return session.handle;
		}

		/**
		 * Retrieves an unloaded resource parsed from the given data.
		 * @param data The data to be parsed.
		 * @param id The id that will be assigned to the resource. This can later also be used by the getResource method.
		 * @param ignoreDependencies Indicates whether or not dependencies should be ignored or loaded.
		 * @param parser An optional parser object that will translate the data into a usable resource.
		 * @return A handle to the retrieved resource.
		 */
		private function parseResource(data : *, id : String, ignoreDependencies : Boolean = true, parser : ParserBase = null) : IResource
		{
			var session : ResourceLoadSession = new ResourceLoadSession(_parsers);
			_loadingSessions.push(session);
			session.addEventListener(ResourceEvent.RESOURCE_RETRIEVED, onResourceRetrieved);
			session.addEventListener(ResourceEvent.DEPENDENCY_RETRIEVED, onDependencyRetrieved);
			session.parse(data, id, ignoreDependencies, parser);
			return session.handle;
		}

		/**
		 * Called when a dependency was retrieved.
		 */
		private function onDependencyRetrieved(event : ResourceEvent) : void
		{
			if (hasEventListener(ResourceEvent.DEPENDENCY_RETRIEVED))
				dispatchEvent(event);
		}
		
		/**
		 * Called when a an error occurs during dependency retrieving.
		 */
		private function onDependencyRetrievingError(event : LoaderEvent) : void
		{
			var ext:String = event.url.substring(event.url.length-4, event.url.length).toLowerCase();
			if (!(ext== ".jpg" || ext == ".png") && hasEventListener(LoaderEvent.LOAD_ERROR)){
				dispatchEvent(event);
			}
			else if(hasEventListener(LoaderEvent.LOAD_MAP_ERROR)){
				var le:LoaderEvent = new LoaderEvent(LoaderEvent.LOAD_MAP_ERROR, event.resource, event.url, event.message);
				dispatchEvent(le);
			}
			else throw new Error(event.message);
		}

		/**
		 * Called when the resource and all of its dependencies was retrieved.
		 */
		private function onResourceRetrieved(event : ResourceEvent) : void
		{
			var session : ResourceLoadSession = ResourceLoadSession(event.target);
			
			var index : int = _loadingSessions.indexOf(session);
			session.removeEventListener(ResourceEvent.RESOURCE_RETRIEVED, onResourceRetrieved);
			session.removeEventListener(ResourceEvent.DEPENDENCY_RETRIEVED, onDependencyRetrieved);
			session.removeEventListener(LoaderEvent.LOAD_ERROR, onDependencyRetrievingError);
			
			_loadingSessions.splice(index, 1);
			
			if(session.handle){
				dispatchEvent(event);
			}else{
				onResourceError((session is IResource)? IResource(session) : null);
			}
			session.removeEventListener(ResourceEvent.DEPENDENCY_ERROR, onDependencyRetrievingError);
		}
		
		/**
		* Called when unespected error occurs
		*/
		private function onResourceError(session : IResource = null) : void
		{
			var msg:String = "Unexpected parser error";
			if(hasEventListener(ResourceEvent.DEPENDENCY_ERROR)){
				var re:ResourceEvent = new ResourceEvent(ResourceEvent.DEPENDENCY_ERROR, session, "");
				dispatchEvent(re);
			} else{
				throw new Error(msg);
			}
		}
	}
}

// singleton enforcer
class SingletonEnforcer
{
}