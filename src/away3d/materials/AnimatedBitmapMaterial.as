﻿package away3d.materials
{
	import away3d.arcane;

	import flash.display.BitmapData;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.utils.getTimer;

	use namespace arcane;
	
    /**
    * Class allows fast rendering of animations by caching bitmapdata objects for each frame.
	* The sequence of bitmapdatas are generated from a movieclip source or can be an array of bitmadatas passed to the class.
    * Suitable for short animations.
	*/
    public class AnimatedBitmapMaterial extends BitmapMaterial
    {
		private var _broadcaster:Sprite = new Sprite();
		private var _playing:Boolean;
		private var _index:uint;
		private var _cache:Array;
		private var _nmCache:Array;
		private var _autoPlay:Boolean;
		private var _loop:Boolean;
        
		private function update(event:Event = null):void
        {
			if (_index < _cache.length - 1)
				_index++;
			else if (_loop)
				_index = 0;
				
			bitmapData = BitmapData(_cache[_index]);
			
			if(_nmCache && _nmCache[_index])
				normalMap = BitmapData(_nmCache[_index]);
		}
    	
		/**
		 * Creates a new <code>AnimatedBitmapMaterial</code> object.
		 *
		 * @param	movie							[optional] The movieclip to be bitmap cached for use in the material. 
		 * if no movieclip is provided, defaultBitmapData parameter must be set. Default is null.
		 * @param	loop								[optional]	If the sequence is played over and over.Default is true;
		 * @param	autoPlay						[optional]	If the sequence is playing automatically. Default is true;
		 * @param	index								[optional]	The index at which the sequence will start first. Default = 0;
		 * @param	defaultBitmapData			[optional]	Default bitmapdata used till a setFrames or setMovie is used. Default = null;
		 */
        public function AnimatedBitmapMaterial(movie:MovieClip=null, loop:Boolean = true, autoPlay:Boolean = false, index:uint = 0, defaultBitmapData:BitmapData = null)
        {
			if(movie){
				setMovie(movie);
			} else {
				_cache = [defaultBitmapData];
				_index = 0;
			}
			
			_loop = loop;
			_autoPlay = autoPlay;
			
			super(_cache[_index]);
			
			this.index = index;
			
			if(_cache.length >1){
				
				if (autoPlay)
					play();
				
				if (loop || autoPlay)
					update();
			}
			 
        }
        
        /**
        * Resumes playback of the animation
        */
        public function play():void
        {
        	if (!_playing) {
	        	_playing = true;
				
				if(!_broadcaster.hasEventListener(Event.ENTER_FRAME))
	        		_broadcaster.addEventListener(Event.ENTER_FRAME, update);
	        }
        }
        
        /**
        * Halts playback of the animation
        */
        public function stop():void
        {
        	if (_playing) {
	        	_playing = false;
				
				if(_broadcaster.hasEventListener(Event.ENTER_FRAME))
	        		_broadcaster.removeEventListener(Event.ENTER_FRAME, update);
	        }        	
        }
		
    	/**
    	 * Resets the movieclip used by the material.
    	 * 
    	 * @param	movie	The movieclip to be bitmap cached for use in the material.
    	 */
		public function setMovie(movie:MovieClip):void
		{
			_cache = [];
			
			//determine boundaries of this movie
			var i:int;
			var rect:Rectangle;
			var minX:Number = 100000;
			var minY:Number = 100000;
			var maxX:Number = -100000;
			var maxY:Number = -100000;
			
			i = movie.totalFrames;
			while (i--)
			{
				movie.gotoAndStop(i);
				rect = movie.getBounds(movie);
				if (minX > rect.left)
				minX = rect.left;
				if (minY > rect.top)
				minY = rect.top;
				if (maxX < rect.right)
				maxX = rect.right;
				if (maxY < rect.bottom)
				maxY = rect.bottom;
			}
			
			//draw the cached bitmaps
			var W:int = maxX - minX;
			var H:int = maxY - minY;
			var mat:Matrix = new Matrix(1, 0, 0, 1, -minX, -minY);
			var tmp_bmd:BitmapData;
			var timer:int = getTimer();
			for(i=1; i<movie.totalFrames+1; ++i) {
				//draw frame and store in cache
				movie.gotoAndStop(i);
				tmp_bmd = new BitmapData(W, H, true, 0x00FFFFFF);
				tmp_bmd.draw(movie, mat, null, null, tmp_bmd.rect, true);
				_cache.push(tmp_bmd);
			
				//error timeout for time over 3 seconds
				if (getTimer() - timer > 3000) throw new Error("AnimatedBitmapMaterial contains too many frames. MovieMaterial should be used instead.");
			 
			}
			
			if(_cache.length <2)
				stop();
		}
		
		/**
		 * Resets the cached bitmapData objects making up the animation with a pre-defined array.
		 * @param	dispose	If the previous sequence maps needs to be disposed. Default is false;
		 */
		public function setMaps(sources:Array, dispose:Boolean = false):void
        {
			var i:uint;
			 
			if(dispose && _cache.length>0){
				var actualMap:BitmapData = bitmapData;
				for(i = 0; i<_cache.length;++i){
					if(_cache[i] != actualMap)
						_cache[i].dispose();
				}
			}
			 
			var _length:int = sources.length;
			_cache = [];
			if (_index > _length - 1)
				_index = _length - 1;
			
			for(i = 0; i<_length; ++i){
				_cache.push(sources[i]);
			}
			
			bitmapData = BitmapData(_cache[_index]);
			 
			if(_cache.length <2)
				stop();
		}
		
		
		/**
		 * Resets the cached normalMaps bitmapData objects making up the animation with a pre-defined array.
		 * @param	dispose	If the previous sequence maps needs to be disposed. Default is false;
		 */
		public function setNormalMaps(nmsources:Array, dispose:Boolean = false):void
        {
			var i:uint;
			 
			if(dispose && _cache.length>0){
				var actualNM:BitmapData = normalMap;
				for(i = 0; i<_cache.length;++i){
					if(_nmCache[i] != actualNM)
						_nmCache[i].dispose();
				}
			}
			 
			var _length:int = nmsources.length;
			_nmCache = [];
			 
			for(i = 0; i<_length; ++i)
				_nmCache.push(nmsources[i]);
			 
			update();
		}
		
		/**
		 * Defines if the sequence plays in a loop. If not and played, the sequence stops at the last valid index.
		 */
		public function set loop(b:Boolean):void
        {
			_loop = b; 
		}
		public function get loop():Boolean
        {
			return _loop;		
		}
		
		/**
		 * Indicates whether the animation will start playing on initialisation.
		 * If false, only the first frame is displayed.
		 */
		public function set autoPlay(b:Boolean):void
        {
			_autoPlay = b; 
		}
		public function get autoPlay():Boolean
        {
			return _autoPlay;		
		}
		
		/**
		 * Manually sets the frame index of the animation.
		 */
		public function set index(f:int):void
        {
			_index = (f<0)? 0 : (f>_cache.length - 1)? _cache.length - 1 : f; 
			bitmapData = BitmapData(_cache[_index]);
			
			if(_nmCache && _nmCache[_index])
				normalMap = BitmapData(_nmCache[_index]);
		}
		/**
		 * returns the frame index of the animation.
		 */
		public function get index():int
        {
			return _index;		
		}
		
		/**
		 * Manually clears all frames of the animation.
		 * a new series of bitmapdatas will be required using the setFrames handler.
		  * @param	disposeNormalMaps  	If normalMaps needs to be disposed as well. Default is false;
		 */
		public function clear(disposeNormalMaps:Boolean = false):void
        {
			stop();
			var i:uint;
			var _length:int = _cache.length;
			var actualMap:BitmapData = bitmapData;
			if(_length>0){
				for(i = 0; i<_length;++i){
					if(_cache[i] != actualMap)
						_cache[i].dispose();
				}
			}
			_cache = [];
			
			if(disposeNormalMaps){
				_length = _nmCache.length;
				actualMap = normalMap;
				if(_length>0){
					for(i = 0; i<_length;++i){
						if(_nmCache[i] != actualMap)
							_nmCache[i].dispose();
					}
				}
				_nmCache = [];
			}
		}
		/**
		 * returns the frames of the animation.
		 * an array of bitmapdatas
		 */
		public function get sources():Array
		{
			return _cache;
		}
		
		/**
		 * returns the frames of the animation.
		 * an array of bitmapdatas
		 */
		public function get normalMapSources():Array
		{
			if(!_nmCache)
				return null;
				
			return _nmCache;
		}
    }
}
