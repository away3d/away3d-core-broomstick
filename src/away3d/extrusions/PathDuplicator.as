﻿package away3d.extrusions {

	import away3d.containers.ObjectContainer3D;
	import away3d.containers.Scene3D;
	import away3d.entities.Mesh;
	import away3d.extrusions.utils.Path;
	import away3d.extrusions.utils.PathUtils;

	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;

	public class PathDuplicator{
		 
		private var _xAxis:Vector3D = new Vector3D();
    	private var _yAxis:Vector3D = new Vector3D();
    	private var _zAxis:Vector3D = new Vector3D();
		private var _transform:Matrix3D;
		private var _worldAxis:Vector3D;
		private var _path:Path;
		private var _scene:Scene3D;
		private var _meshes:Vector.<Mesh>;
		private var _meshesindex:int = 0;
		private var _clones:Vector.<Mesh>;
		private var _repeat:uint;
		private var _alignToPath:Boolean;
		private var _randomRotationY:Boolean;
		private var _segmentSpread:Boolean = false;
		private var _mIndex:uint;
		private var _count:uint;
		private var _container:ObjectContainer3D;
		 
		/**
		* Creates a new <code>PathDuplicator</code>
		* Class replicates and distribute one or more mesh(es) along a path. The offsets are defined by the position of the object. 0,0,0 would place the center of the mesh exactly on Path.
		* 
		* @param	path						[optional]	A Path object. The _path definition.
		* @param	meshes					[optional]	Vector.<Mesh>. One or more meshes to repeat along the path.
		* @param	scene						[optional]	Scene3D. The scene where to addchild the meshes if no ObjectContainer3D is provided.
		* @param	repeat					[optional]	uint. Howmany times a mesh is cloned per PathSegment. Default is 1.
		* @param	alignToPath			[optional]	Boolean. If the alignment of the clones must follow the path. Default is true.
		* @param	segmentSpread		[optional]	Boolean. If more than one Mesh is passed, it defines if the clones alternate themselves per PathSegment or each repeat. Default is false.
		* @param container				[optional]	ObjectContainer3D. If an ObjectContainer3D is provided, the meshes are addChilded to it instead of directly into the scene. The container is NOT addChilded to the scene by default.
		* @param	randomRotationY	[optional]	Boolean. If the clones must have a random rotationY added to them.
		* 
		*/
		function PathDuplicator(path:Path = null, meshes:Vector.<Mesh> = null, scene:Scene3D = null, repeat:uint = 1, alignToPath:Boolean = true, segmentSpread:Boolean = true, container:ObjectContainer3D = null, randomRotationY:Boolean = false)
		{
			_path = path;
			_meshes = meshes;
			_scene = scene;
			this.repeat = repeat;
			_alignToPath = alignToPath;
			_segmentSpread = segmentSpread;
			_randomRotationY = randomRotationY;
		}
		
		/**
    	 * If a container is provided, the meshes are addChilded to it instead of directly into the scene. The container is NOT addChilded to the scene.
    	 */ 
		public function set container(cont:ObjectContainer3D):void
		{
			_container = cont;
		}
		public function get container():ObjectContainer3D
		{
			return _container;
		}
		
		/**
    	 * Defines the resolution between each PathSegments. Default 1, is also minimum.
    	 */ 
		public function set repeat(val:uint):void
		{
			_repeat = (val<1)? 1 :val;
		}
		public function get repeat():uint
		{
			return _repeat;
		}
		
		/**
    	 * Defines if the profile point array should be orientated on path or not. Default true.
    	 */
		public function set alignToPath(b:Boolean):void
		{
			_alignToPath = b;
		}
		public function get alignToPath():Boolean
		{
			return _alignToPath;
		}
		
		/**
    	 * Defines if a clone gets a random rotationY to break visual repetitions, usefull in case of vegetation for instance.
    	 */
		public function set randomRotationY(b:Boolean):void
		{
			_randomRotationY = b;
		}
		public function get randomRotationY():Boolean
		{
			return _randomRotationY;
		}
		
		 /**
    	 * returns a vector with all meshes cloned since last time build method was called. Returns null if build hasn't be called yet.
		 * Another option to retreive the generated meshes is to pass an ObjectContainer3D to the class
    	 */ 
		 public function get clones():Vector.<Mesh>
    	{
    		return _clones;
    	}

		 /**
    	 * Sets and defines the Path object. See extrusions.utils package. Required for this class.
    	 */ 
		 public function set path(p:Path):void
    	{
    		_path = p;
    	}
		 public function get path():Path
    	{
    		return _path;
    	}
		 
		/**
    	* Defines an optional Vector.<Mesh>. One or more meshes to repeat along the path.
		* When the last in the vector is reached, the first in the array will be used, this process go on and on until the last segment.
    	* 
		* @param	ms	A Vector.<Mesh>. One or more meshes to repeat along the path. Required for this class.
		*/
		 public function set meshes(ms:Vector.<Mesh>):void
    	{
    		_meshes = ms;
    	}
		 public function get meshes():Vector.<Mesh>
    	{
    		return _meshes;
    	}
		
		/**
    	 * defines if the meshes[index] is repeated per segments or duplicated after each others. default = false.
    	 */
		 public function set segmentSpread(b:Boolean):void
    	{
    		_segmentSpread = b;
    	}
		 public function get segmentSpread():Boolean
    	{
    		return _segmentSpread;
    	}
		 
		/**
		* Triggers the generation
		*/
		public function build():void
		{
			if(!_path || !_meshes || meshes.length == 0) throw new Error("PathDuplicator error: Missing Path or Meshes data.");
			if(!_scene && !_container) throw new Error("PathDuplicator error: Missing Scene3D or ObjectConatiner3D.");
			
			_mIndex = _meshes.length-1;
			_worldAxis = _path.worldAxis;
			_count = 0;
			
			_clones = new Vector.<Mesh>();
			
			var segments:Vector.<Vector.<Vector3D>> = PathUtils.getPointsOnCurve(_path, _repeat);
			var tmppt:Vector3D = new Vector3D();
			 
			var i:uint;
			var j:uint;
			var k:uint;
			var nextpt:Vector3D;
			var m:Mesh;
			var tPosi:Vector3D;
			 
			for (i = 0; i <segments.length; ++i) {
				
				if(!segmentSpread) _mIndex = (_mIndex+1 != _meshes.length)? _mIndex+1 : 0;
				 
				for(j = 0; j<segments[i].length;++j){
					

					if(segmentSpread) _mIndex = (_mIndex+1 != _meshes.length)? _mIndex+1 : 0;
					
					m = _meshes[_mIndex];
					tPosi = m.position;
					 
					if(_alignToPath) {
						_transform = new Matrix3D();
						
						if(i == segments.length -1 && j == segments[i].length-1){
							nextpt = segments[i][j-1];
							orientateAt(segments[i][j], nextpt);
						} else {
							nextpt = (j<segments[i].length-1)? segments[i][j+1]:  segments[i+1][0];
							orientateAt(nextpt, segments[i][j]);
						}
					}
					
					if(_alignToPath) {
						 
						tmppt.x = tPosi.x * _transform.rawData[0] + tPosi.y * _transform.rawData[4] + tPosi.z * _transform.rawData[8] + _transform.rawData[12];
						tmppt.y = tPosi.x * _transform.rawData[1] + tPosi.y * _transform.rawData[5] + tPosi.z * _transform.rawData[9] + _transform.rawData[13];
						tmppt.z = tPosi.x * _transform.rawData[2] + tPosi.y * _transform.rawData[6] + tPosi.z * _transform.rawData[10] + _transform.rawData[14];
				 
						tmppt.x +=  segments[i][j].x;
						tmppt.y +=  segments[i][j].y;
						tmppt.z +=  segments[i][j].z;
						 
					} else {
						
						tmppt = new Vector3D(tPosi.x+segments[i][j].x, tPosi.y+segments[i][j].y, tPosi.z+segments[i][j].z);
					}
					 
					generate(m, tmppt);
				}
				 
			}
			
			segments = null;
		}
		 
		 private function orientateAt(target:Vector3D, position:Vector3D):void
        {
            _zAxis = target.subtract(position);
            _zAxis.normalize();
    
            if (_zAxis.length > 0.1)
            {
                _xAxis = _worldAxis.crossProduct(_zAxis);
                _xAxis.normalize();
    
                _yAxis = _xAxis.crossProduct(_zAxis);
                _yAxis.normalize();
    			
    			var rawData:Vector.<Number> = _transform.rawData;
    			
                rawData[0] = _xAxis.x;
                rawData[1] = _xAxis.y;
                rawData[2] = _xAxis.z;
    
                rawData[4] = -_yAxis.x;
                rawData[5] = -_yAxis.y;
                rawData[6] = -_yAxis.z;
    
                rawData[8] = _zAxis.x;
                rawData[9] = _zAxis.y;
                rawData[10] = _zAxis.z;
				
				_transform.rawData = rawData;
            }
        }
		
		private function generate(m:Mesh, position:Vector3D ):void
        {
			var newClone:Mesh;
			newClone = m.clone() as Mesh;
			newClone.position = position;
			newClone.name = (m.name != null)? m.name+"_"+_count : "clone_"+_count;
			_count++;
			
			if(_randomRotationY)
				newClone.rotationY = Math.random()*360;
			 
			if(_container){
				_container.addChild(newClone);
			} else{
				_scene.addChild(newClone);
			}
			_clones.push(newClone);
		}
		
	}
}