package away3d.core.managers
{
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;

	internal class AGALProgram3DCache
	{
		// POLICY RELATED CODE
		/**
		 * throws an error on cache overflow 
		 */		
		public static const ERROR_ON_OVERFLOW:String = "AGALProgram3DCachePolicyErrorOnOverflow";
		
		/**
		 * increases by 1 the size of the cache on cache overflow 
		 */
		public static const RESIZE_ON_OVERFLOW:String = "AGALProgram3DCachePolicyResizeOnOverflow";
		
		protected static const _validPolicies:Array = [
			ERROR_ON_OVERFLOW,
			RESIZE_ON_OVERFLOW
		]
		
		/**
		 * Checks whether the given cachePolicy is a valid one or not 
		 * @param cachePolicy
		 * @return 
		 */		
		protected static function policyIsValid(cachePolicy:String):Boolean
		{
			return _validPolicies.indexOf(cachePolicy) != -1;
		}
		
		// user set params
		protected var _cacheSize:uint;
		protected var _cachePolicy:String;
		
		// utility vars
		protected var _actualSize:uint;
		protected var _agalToCompiledShader:Dictionary;
		protected var _agalHistory:Vector.<String>;
		

		public function AGALProgram3DCache(cacheSize:uint, cachePolicy:String=AGALProgram3DCache.ERROR_ON_OVERFLOW)
		{
			_actualSize = 0;
			_agalToCompiledShader = new Dictionary();
			_agalHistory = new Vector.<String>();
			
			this.cacheSize = cacheSize;
			this.cachePolicy = cachePolicy;
		}
		

		// getters / setters
		
		/**
		 * Whether the cache can store one item or not.
		 * If cachePolicy value is RESIZE_ON_OVERFLOW it always returns true.
		 * @return Boolean
		 */		
		public function canStore():Boolean
		{
			return _cachePolicy==RESIZE_ON_OVERFLOW?true:_actualSize<_cacheSize;
		}
		
		/**
		 * Stores given compiledShader ByteArray using the given agal String as key. 
		 * @param agal : the actual shader AGAL code
		 * @param compiledShader : the compiled AGAL code
		 * @param overWriteIfExisting : if false and the given agal is already stored results in an error, 
		 * otherwise it overwrites the stored compiled shader with the given one.
		 * 
		 * @return the given compiledShader
		 */		
		public function store(agal:String,compiledShader:ByteArray,overWriteIfExisting:Boolean=true):ByteArray
		{
			if(_agalToCompiledShader[agal]!=null && !overWriteIfExisting){
				throw(new Error("AGAL already stored, can't overwrite it"));
				return;
			}
			if(canStore()){
				_agalToCompiledShader[agal] = compiledShader;
				_agalHistory.push(agal);
				++_actualSize;
				return compiledShader;
			}
			return null;
		}
		
		/**
		 * Removes the given agal and the compiled shader associated to it from the cache.
		 * @param agal code String.
		 * @return Boolean indicating the result of the operation. False means the given agal was not stored.
		 */		
		public function remove(agal:String):Boolean
		{
			var index:int = _agalHistory.indexOf(agal);
			if(index!=-1){
				delete _agalToCompiledShader[agal];
				_agalHistory.splice(index,1);
				--_actualSize;
				return true;
			}
			
			return false;
		}
		
		
		/**
		 * Returns the previously stored compiled shader.
		 * @param agal code String
		 * @return Compiled shader ByteArray 
		 */		
		public function getCompiledShaderForAGAL(agal:String):ByteArray
		{
			return _agalToCompiledShader[agal] as ByteArray;
		}
		
		
		/**
		 * Removes all stored agal\compile shader pairs from cache.
		 */		
		public function clear():void
		{
			while(_agalHistory.length>0){
				delete _agalToCompiledShader[_agalHistory.pop()];
			}
			_actualSize = 0;
		}
		
		/**
		 * Clears the cache and removes all data structures in it.
		 * After this method call this instance of AGALProgram3DCache is no more utilizable.
		 */		
		public function dispose():void
		{
			clear();
			_agalHistory = null;
			_agalToCompiledShader = null;
		}
		
		
		/**
		 *  Max amount of items to be stored in this cache
		 */		
		public function get cacheSize():uint
		{
			return _cacheSize;
		}

		public function set cacheSize(value:uint):void
		{
			_cacheSize = value;
		}

		/**
		 * Actual occupation of this cache.
		 * Getter only. 
		 * @return uint
		 */		
		public function get actualSize():uint
		{
			return _actualSize;
		}

		/**
		 * Cache policy. 
		 * It must be ERROR_ON_OVERFLOW or RESIZE_ON_OVERFLOW
		 * It determines the behavior of the cache when it reaches the max amount of stored items.
		 */		
		public function get cachePolicy():String
		{
			return _cachePolicy;
		}

		public function set cachePolicy(value:String):void
		{
			if(!policyIsValid(value))
				throw(new Error("invalid cache policy "+value));
			_cachePolicy = value;
		}

	}
}