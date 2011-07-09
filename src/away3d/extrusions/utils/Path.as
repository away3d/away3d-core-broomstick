﻿package away3d.extrusions.utils
{
	import flash.geom.Vector3D;

	//import away3d.containers.Scene3D;
	//import away3d.extrusions.utils.PathDebug;

	/**
	 * Holds information about a single Path definition.
	 * DEBUG OPTION OUT AT THIS TIME OF DEV
	 */
    public class Path
    {
		/**
		 * Creates a new <code>Path</code> object.
		 * 
		 * @param	 aVectors		[optional] An array of a series of Vector3D's organized in the following fashion. [a,b,c,a,b,c etc...] a = pEnd, b=pControl (control point), c = v2
		 */
		 
        public function Path(aVectors:Vector.<Vector3D> = null)
        {
			if(aVectors!= null && aVectors.length < 3)
				throw new Error("Path Vector.<Vector3D> must contain at least 3 Vector3D's");
			
            _segments = new Vector.<PathSegment>();
			
			if(aVectors != null)
				for(var i:int = 0; i<aVectors.length; i+=3)
					_segments.push( new PathSegment(aVectors[i], aVectors[i+1], aVectors[i+2]));
			 
        }
		
		 
		//private var _pathDebug:PathDebug;
		 
        private var _segments:Vector.<PathSegment>;
		
		/**
    	 * The worldAxis of reference
    	 */
		public var worldAxis:Vector3D = new Vector3D(0,1,0);
    	
		
        private var _smoothed:Boolean;
		/**
    	 * returns true if the smoothPath handler is being used.
    	 */
		public function get smoothed():Boolean
		{
			return _smoothed;
		}
		
		private var _averaged:Boolean;
		/**
    	* returns true if the averagePath handler is being used.
    	*/
		public function get averaged():Boolean
		{
			return _averaged;
		}
		
		/**
		 * display the path in scene
		 */
		/*public function debugPath(scene:Scene3D):void
        {
			_pathDebug = new PathDebug(scene, this);
        }*/
		/**
		 * Defines if the anchors must be displayed if debugPath has been called. if false, only curves are displayed
		 */
		/*public function get showAnchors():Boolean
        {
			if(!_pathDebug)
				throw new Error("Patheditor not set yet! Use Path.debugPath() method first");
				
			return _pathDebug.showAnchors;
		}
		public function set showAnchors(b:Boolean):void
        {
			if(!_pathDebug)
				throw new Error("Patheditor not set yet! Use Path.debugPath() method first");
			
			_pathDebug.showAnchors = b;
        }
		 */
		/**
		 * Defines if the path data must be visible or not if debugPath has been called
		 */
		 /*
		public function get display():Boolean
        {
			return _pathDebug.display;
		}
		public function set display(b:Boolean):void
        {
			if(!_pathDebug)
				throw new Error("Patheditor not set yet! Use Path.debugPath() method first");
			
			_pathDebug.display = b;
        }*/
		
		 
		/**
		 * adds a PathSegment to the path
		 * @see PathSegment:
		 */
		public function add(ps:PathSegment):void
        {
			_segments.push(ps);
        }
		
		/**
		 * returns the length of the Path elements array
		 * 
		 * @return	an integer: the length of the Path elements array
		 */
		public function get length():int
        {
			return _segments.length;
        }
		
		/**
		 * returns the Vector.<PathSegment> holding the elements (PathSegment) of the path
		 * 
		 * @return	a Vector.<PathSegment>: holding the elements (PathSegment) of the path
		 */
		public function get segments():Vector.<PathSegment>
        {
			return _segments;
        }
		
		/**
		 * returns a given PathSegment from the path (PathSegment holds 3 Vector3D's)
		 * 
		 * @param	 indice uint. the indice of a given PathSegment		
		 * @return	given PathSegment from the path
		 */
		public function getSegmentAt(indice:uint):PathSegment
        {
			return _segments[indice];
        }
        
		/**
		 * removes a segment in the path according to id.
		 *
		 * @param	 index	int. The index in path of the to be removed curvesegment 
		 * @param	 join 		Boolean. If true previous and next segments coordinates are reconnected
		 */
		public function removeSegment(index:int, join:Boolean = false):void
        {
			if(_segments.length == 0 || _segments[index ] == null )
				return;
			
			if(join && index < _segments.length-1 && index>0){
				var seg:PathSegment = _segments[index];
				var prevSeg:PathSegment = _segments[index-1];
				var nextSeg:PathSegment = _segments[index+1];
				prevSeg.pControl.x = (prevSeg.pControl.x+seg.pControl.x)*.5;
				prevSeg.pControl.y = (prevSeg.pControl.y+seg.pControl.y)*.5;
				prevSeg.pControl.z = (prevSeg.pControl.z+seg.pControl.z)*.5;
				nextSeg.pControl.x = (nextSeg.pControl.x+seg.pControl.x)*.5;
				nextSeg.pControl.y = (nextSeg.pControl.y+seg.pControl.y)*.5;
				nextSeg.pControl.z = (nextSeg.pControl.z+seg.pControl.z)*.5;
				prevSeg.pEnd.x = (seg.pStart.x + seg.pEnd.x)*.5;
				prevSeg.pEnd.y = (seg.pStart.y + seg.pEnd.y)*.5;
				prevSeg.pEnd.z = (seg.pStart.z + seg.pEnd.z)*.5;
				nextSeg.pStart.x = prevSeg.pEnd.x;
				nextSeg.pStart.y = prevSeg.pEnd.y;
				nextSeg.pStart.z = prevSeg.pEnd.z;
				
				/*if(_pathDebug != null)
					_pathDebug.updateAnchorAt(index-1);
					_pathDebug.updateAnchorAt(index+1);*/
			}
			
			if(_segments.length > 1){
				_segments.splice(index, 1);
			} else{
				_segments = new Vector.<PathSegment>();
			}
        }
		
		/**
		 * handler will smooth the path using anchors as control vector of the PathSegments 
		 * note that this is not dynamic, the PathSegments values are overwrited
		 */
		public function smoothPath():void
        {
			if(_segments.length <= 2)
				return;
			 
			_smoothed = true;
			_averaged = false;
			 
			var x:Number;
			var y:Number;
			var z:Number;
			var seg0:Vector3D;
			var seg1:Vector3D;
			var tmp:Vector.<Vector3D> = new Vector.<Vector3D>();
			var i:uint;
			
			var startseg:Vector3D = new Vector3D(_segments[0].pStart.x, _segments[0].pStart.y, _segments[0].pStart.z);
			var endseg:Vector3D = new Vector3D(_segments[_segments.length-1].pEnd.x, 
																		_segments[_segments.length-1].pEnd.y,
																		_segments[_segments.length-1].pEnd.z);
			for(i = 0; i< length-1; ++i)
			{
				if(_segments[i].pControl == null)
					_segments[i].pControl = _segments[i].pEnd;
				
				if(_segments[i+1].pControl == null)
					_segments[i+1].pControl = _segments[i+1].pEnd;
				
				seg0 = _segments[i].pControl;
				seg1 = _segments[i+1].pControl;
				x = (seg0.x + seg1.x) * .5;
				y = (seg0.y + seg1.y) * .5;
				z = (seg0.z + seg1.z) * .5;
				
				tmp.push( startseg,  new Vector3D(seg0.x, seg0.y, seg0.z), new Vector3D(x, y, z));
				startseg = new Vector3D(x, y, z);
				_segments[i] = null;
			}
			
			seg0 = _segments[_segments.length-1].pControl;
			tmp.push( startseg,  new Vector3D((seg0.x+seg1.x)*.5, (seg0.y+seg1.y)*.5, (seg0.z+seg1.z)*.5), endseg);
			
			_segments = new Vector.<PathSegment>();
			
			for(i = 0; i<tmp.length; i+=3)
				_segments.push( new PathSegment(tmp[i], tmp[i+1], tmp[i+2]) );
				tmp[i] = tmp[i+1] = tmp[i+2] = null;
			 
			tmp = null;
		}
		
		/**
		 * handler will average the path using averages of the PathSegments
		 * note that this is not dynamic, the path values are overwrited
		 */
		public function averagePath():void
        {
			_averaged = true;
			_smoothed = false;
			
			for(var i:uint = 0; i<_segments.length; ++i){
				_segments[i].pControl.x = (_segments[i].pStart.x+_segments[i].pEnd.x)*.5;
				_segments[i].pControl.y = (_segments[i].pStart.y+_segments[i].pEnd.y)*.5;
				_segments[i].pControl.z = (_segments[i].pStart.z+_segments[i].pEnd.z)*.5;
			}
        }
        
  		public function continuousCurve(points:Vector.<Vector3D>, closed:Boolean = false):void
  		{
  			var aVectors:Vector.<Vector3D> = new Vector.<Vector3D>();
  			var i:uint;
  			var X:Number;
			var Y:Number;
			var Z:Number;
			var midPoint:Vector3D;
			
  			// Find the mid points and inject them into the array.
  			for(i = 0; i < points.length - 1; i++)
  			{
  				var currentPoint:Vector3D = points[i];
  				var nextPoint:Vector3D = points[i+1];
  				
  				X = (currentPoint.x + nextPoint.x)/2;
  				Y = (currentPoint.y + nextPoint.y)/2;
  				Z = (currentPoint.z + nextPoint.z)/2;
  				midPoint = new Vector3D(X, Y, Z);
  				
  				if (i) aVectors.push(midPoint);
  				
  				if (i < points.length - 2 || closed) {
	  				aVectors.push(midPoint);
	  				aVectors.push(nextPoint);
  				}
  			}
  			
  			if(closed) {
	  			currentPoint = points[points.length-1];
	  			nextPoint = points[0];
	  			X = (currentPoint.x + nextPoint.x)/2;
  				Y = (currentPoint.y + nextPoint.y)/2;
  				Z = (currentPoint.z + nextPoint.z)/2;
  				midPoint = new Vector3D(X, Y, Z);
  				
  				aVectors.push(midPoint);
  				aVectors.push(midPoint);
  				aVectors.push(points[0]);
  				aVectors.push(aVectors[0]);
	  		}
	  		
            _segments = new Vector.<PathSegment>();
			
			for(i = 0; i< aVectors.length; i+=3)
				_segments.push( new PathSegment(aVectors[i], aVectors[i+1], aVectors[i+2]));
  		}
		
    }
}