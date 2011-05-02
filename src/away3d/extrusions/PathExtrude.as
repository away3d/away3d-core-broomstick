﻿package away3d.extrusions{
	
	import away3d.core.base.data.UV;
	import away3d.core.base.data.Vertex;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.core.base.SubMesh;
	import away3d.materials.MaterialBase;
	import away3d.materials.BitmapMaterial;
	import away3d.loading.parsers.data.DefaultBitmapData;
	import away3d.materials.utils.MultipleMaterials;
	import away3d.bounds.BoundingVolumeBase;
	import away3d.entities.Mesh;
	import away3d.tools.MeshHelper;
	import away3d.extrusions.utils.Path;
	import away3d.extrusions.utils.PathUtils;
	
	import flash.geom.Vector3D;
	import flash.geom.Matrix3D;
	
	public class PathExtrude extends Mesh
	{
		private var _varr:Vector.<Vertex>;
		private var _doubles:Vector.<Vertex> = new Vector.<Vertex>();
		private var _xAxis:Vector3D = new Vector3D(0.0, 0.0, 0.0);
    	private var _yAxis:Vector3D = new Vector3D(0.0, 0.0, 0.0);
    	private var _zAxis:Vector3D = new Vector3D(0.0, 0.0, 0.0);
		private var _worldAxis:Vector3D = new Vector3D(0,1,0);
		private var _trans:Matrix3D = new Matrix3D();
		
		private const LIMIT:uint = 64998;
		private var _path:Path;
		private var _profile:Vector.<Vector3D>;
		private var _centerMesh:Boolean;
		private var _scales:Vector.<Vector3D>;
		private var _rotations:Vector.<Vector3D>;
		private var _materials:Vector.<MaterialBase>;
		private var _activeMaterial:MaterialBase;
		private var _subdivision:uint;
		private var _coverAll:Boolean;
		private var _coverSegment:Boolean;
		private var _flip:Boolean;
		private var _mapfit:Boolean;
		private var _closePath:Boolean;
		private var _alignToPath:Boolean;
		private var _smoothScale:Boolean;
		private var _smoothSurface:Boolean;
		private var _isClosedProfile:Boolean;
		private var _maxIndProfile:uint;
		private var _matIndex:uint = 0;
		private var _segv:Number;
		private var _geomDirty : Boolean = true;
		private var _subGeometry:SubGeometry;
		private var _MaterialsSubGeometries:Vector.<SubGeometryList> = new Vector.<SubGeometryList>();
		private var _uva:UV;
		private var _uvb:UV;
		private var _uvc:UV;
		private var _uvd:UV;
		private var _uvs : Vector.<Number>;
		private var _vertices : Vector.<Number>;
		private var _indices : Vector.<uint>;
		private var _normals : Vector.<Number>;
		private var _normal: Vector3D;
		
		/**
		* Creates a new <code>PathExtrude</code>
		*
		* @param	material			[optional] 	MaterialBase. The PathExtrude (Mesh) material. Optional in constructor, material must be set before PathExtrude object is rendered. Required for the class to work.
		* @param	path				[optional] 	Path. Defines the <code>Path</code> object representing path to extrude along. Required for the class to work.
		* @param	profile			[optional] 	Vector.<Vector3D>. Defines an Vector.<Vector3D> of Vector3D objects representing the profile information to be projected along the Path object. Required for the class to work.
		* @param	subdivision		[optional]	uint. Howmany steps between each PathSegment. If the path holds curves, the higher this value, the higher the curve fidelity. Default and minimum is 2;
		* @param	coverall			[optional] 	Boolean. Defines the uv mapping, when true a unique material is stretched along the entire path/shape. Default is true.
		* @param	coverSegment	[optional] 	Boolean. Defines the uv mapping, when true and coverall is false a unique material is stretched along one PathSegment. Default is false.
		* @param	alignToPath	[optional]	Boolean. If the profile must follow the path or keep its original orientation.
		* @param	centerMesh	[optional] 	Boolean. If the geometry needs to be recentered in its own object space. If the position after generation is set to 0,0,0, the object would be centered in worldspace. Default is false.
		* @param	mapfit			[optional]	Boolean. The UV mapping is percentually spreaded over the width of the path, making texture looking nicer and edits for applications such as a race track, road, more easy.
		* @param	flip				[optional]	Boolean. If the faces must be reversed depending on Vector3D's orientation. Default is false.
		* @param	closePath		[optional]	Boolean. If the last PathSegment entered must be welded back to first one. Executed in a straight manner, its recommanded to pass the first entry to the Path again, as last entry if curves are involved.
		* @param	materials		[optional]	Vector.<MaterialBase>. An optional Vector.<MaterialBase> of different materials that can be alternated along the path if coverAll is false.
		* @param	scales			[optional]	An optional Vector.<Vector3D> of <code>Vector3D</code> objects that defines a series of scales to be set on each PathSegment.
		* @param	smoothScale	[optional]	Boolean. Defines if the scale must be interpolated between values or keep their full aspect on each PathSegment.
		* @param	rotations		[optional]	An optional Vector.<Vector3D> of <code>Vector3D</code> objects that defines a series of rotations to be set on each PathSegment.
		* @param	smoothSurface	[optional]	An optional Boolean. Defines if the surface of the mesh must be smoothed or not.
		*/
		function PathExtrude(	material:MaterialBase = null, path:Path = null, profile:Vector.<Vector3D> = null, subdivision:uint = 2, coverAll:Boolean = true, coverSegment:Boolean = false, alignToPath:Boolean = true, centerMesh:Boolean = false, mapfit:Boolean = false,
							 			flip:Boolean = false, closePath:Boolean = false, materials:Vector.<MaterialBase> = null, scales:Vector.<Vector3D> = null, smoothScale:Boolean = true, rotations:Vector.<Vector3D> = null, smoothSurface:Boolean = true)
		{
			var geom : Geometry = new Geometry();
			_subGeometry = new SubGeometry();
			super((!material)? new BitmapMaterial(DefaultBitmapData.bitmapData) : material, geom);
			
			_activeMaterial = this.material;
			_path = path;
			this.profile = profile;
			this.subdivision = subdivision;
			_coverSegment = coverSegment;
			_coverAll = (_coverSegment)? false : coverAll;
			_alignToPath = alignToPath;
			_centerMesh = centerMesh;
			_mapfit = mapfit;
			_flip = flip;
			_closePath = closePath;
			_materials = (materials)?materials : new Vector.<MaterialBase>();
			_scales = scales;
			_smoothScale = smoothScale;
			_rotations = rotations;
			_smoothSurface = smoothSurface;
		}
		
		/**
		 * @inheritDoc
		 */
		override public function get bounds() : BoundingVolumeBase
		{
			if (_geomDirty) 
				buildExtrude();
			
			return super.bounds;
		}

		/**
		 * @inheritDoc
		 */
		override public function get geometry() : Geometry
		{
			if (_geomDirty) buildExtrude();
			 
			return super.geometry;
		}

		/**
		 * @inheritDoc
		 */
		override public function get subMeshes():Vector.<SubMesh>
		{
			if (_geomDirty) buildExtrude();
			 
			return super.subMeshes;
		}
		
		/**
    	 * Defines whether the mesh is recentered of not after generation
    	 */
    	public function get centerMesh():Boolean
    	{
    		return _centerMesh;
    	}
    	
    	public function set centerMesh(val:Boolean):void
    	{
    		if (_centerMesh == val)
    			return;
    		
    		_centerMesh = val;
			
			if (_centerMesh && this.geometry.subGeometries.length > 0){
				MeshHelper.recenter( this);
			}else{
				invalidateGeometry();
			}
    	}
		
		/**
		 * Invalidates the geometry, causing it to be rebuillded when requested.
		 */
		private function invalidateGeometry() : void
		{
			_geomDirty = true;
			invalidateBounds();
		}
		
		 /**
    	 * Defines the <code>Path</code> object representing path to extrude along. Required.
    	 */ 
		public function get path():Path
    	{
    		return _path;
    	}
		
		public function set path(val:Path):void
    	{
    		_path = val;
    		_geomDirty = true;
    	}
    	
		/**
    	 * Defines a Vector.<Vector3D> of Vector3D objects representing the profile information to be projected along the Path object. Required.
    	 */
		public function get profile():Vector.<Vector3D>
    	{
    		return _profile;
    	}
		
		public function set profile(val:Vector.<Vector3D>):void
    	{
    		_profile = val;
    		
    		if (_profile != null)
				_isClosedProfile = (_profile[0].x == _profile[_profile.length-1].x && _profile[0].y == _profile[_profile.length-1].y && _profile[0].z == _profile[_profile.length-1].z);
			
			_geomDirty = true;
    	}
    	
		/**
    	 * An optional Vector.<Vector3D> of <code>Vector3D</code> objects that defines a series of scales to be set on each PathSegment.
    	 */
		public function get scales():Vector.<Vector3D>
    	{
    		return _scales;
    	}
    	
		public function set scales(val:Vector.<Vector3D>):void
    	{
    		_scales = val;
    		_geomDirty = true;
    	}
		
		/**
    	 * An optional Vector.<Vector3D> of <code>Vector3D</code> objects that defines a series of rotations to be set on each PathSegment.
    	 */
		public function get rotations():Vector.<Vector3D>
    	{
    		return _rotations;
    	}
    	
		public function set rotations(val:Vector.<Vector3D>):void
    	{
    		_rotations = val;
    		_geomDirty = true;
    	}
		
		/**
		 * An optional Vector.<MaterialBase>. It defines a series of materials to be set on each PathSegment if coverAll is set to false.
    	 */
		public function get materials():Vector.<MaterialBase>
    	{
    		return _materials;
    	}
    	
		public function set materials(val:Vector.<MaterialBase>):void
    	{
			if(val == null) return;
    		_materials = val;
    		_geomDirty = true;
    	}
				 
		/**
    	 * Defines the subdivisions created in the mesh for each PathSegment. Defaults to 2, minimum 2.
    	 */ 
		public function get subdivision():int
		{
			return _subdivision;
		}
		
		public function set subdivision(val:int):void
		{
			val = (val<2)? 2 : val;
			
			if (_subdivision == val)
				return;
			
			_subdivision = val;
			_geomDirty = true;
		}
		
		/**
    	 * Defines if the texture(s) should be stretched to cover the entire mesh or per step between segments. Defaults to true.
    	 */
		public function get coverAll():Boolean
		{
			return _coverAll;
		}
		
		public function set coverAll(val:Boolean):void
		{
			if (_coverAll == val)
				return;
			
			_coverAll = val;
			_geomDirty = true;
		}
		
		/**
    	 * Defines if the surface of the mesh must be smoothed or not.
    	 */
		public function get smoothSurface():Boolean
		{
			return _smoothSurface;
		}
		
		public function set smoothSurface(val:Boolean):void
		{
			if (_smoothSurface == val)
				return;
			
			_smoothSurface = val;
			_geomDirty = true;
		}
		 
		/**
    	 * Defines if the texture(s) should applied per segment. Default false.
    	 */
		public function set coverSegment(b:Boolean):void
		{
			_coverSegment = b;
		}
		public function get coverSegment():Boolean
		{
			return _coverSegment;
		}
		
		/**
    	 * Defines if the texture(s) should be projected on the geometry evenly spreaded over the source bitmapdata or using distance/percent. Default is false.
		 * Note that it is NOT suitable if a scale array is being used. The mapping considers first and last profile points are the most distant from each other. most left and most right on the map.
    	 */
		public function get mapfit():Boolean
		{
			return _mapfit;
		}
		
		public function set mapfit(val:Boolean):void
		{
			if (_mapfit == val)
				return;
			
			_mapfit = val;
			_geomDirty = true;
		}
		
		/**
    	 * Defines if the generated faces should be inversed. Default false.
    	 */
		public function get flip():Boolean
		{
			return _flip;
		}
		
		public function set flip(val:Boolean):void
		{
			if (_flip == val)
				return;
			
			_flip = val;
			_geomDirty = true;
		}
		
		/**
    	 * Defines if the last PathSegment should join the first one and close the loop. Defaults to false.
    	 */
		public function get closePath():Boolean
		{
			return _closePath;
		}
		
		public function set closePath(val:Boolean):void
		{
			if (_closePath == val)
				return;
			
			_closePath = val;
			_geomDirty = true;
		}
		
		/**
    	 * Defines if the array of profile points should be orientated on path or not. Default true. Note that Path object's worldaxis property might need to be changed. default = 0,1,0.
    	 * 
    	 * @see #profile
    	 */
		public function get aligntoPath():Boolean
		{
			return _alignToPath;
		}
		
		public function set alignToPath(val:Boolean):void
		{
			if (_alignToPath == val)
				return;
			
			_alignToPath = val;
			_geomDirty = true;
		}
		
		/**
    	 * Defines if a scaling of a PathSegment defined from the scales array of <code>Vector3D</code> objects should affect the whole PathSegment evenly or be smoothly interpolated from previous PathSegment scale. Defaults to true.
    	 */
		public function get smoothScale():Boolean
		{
			return _smoothScale;
		}
		
		public function set smoothScale(val:Boolean):void
		{
			if (_smoothScale == val)
				return;
			
			_smoothScale = val;
			_geomDirty = true;
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
    			
    			var rawData:Vector.<Number> = _trans.rawData;
    			
                rawData[0] = _xAxis.x;
                rawData[1] = _xAxis.y;
                rawData[2] = _xAxis.z;
    
                rawData[4] = -_yAxis.x;
                rawData[5] = -_yAxis.y;
                rawData[6] = -_yAxis.z;
    
                rawData[8] = _zAxis.x;
                rawData[9] = _zAxis.y;
                rawData[10] = _zAxis.z;
				
				_trans.rawData = rawData;
            }
        }
		
		private function generate(points:Vector.<Vector.<Vector3D>>, offsetV:int = 0, closedata:Boolean = false):void
		{
			var uvlength:int = (points.length-1) + offsetV;
			var offset:uint;
			 
			for(var i:uint = 0;i< points.length-1;++i){
				_varr = new Vector.<Vertex>();
				offset = (closedata)? i+uvlength : i;
				 
				extrudePoints( points[i], points[i+1], (1/uvlength)*offset, uvlength, offset/(_subdivision-1));
				
				if(i ==0 && _isClosedProfile)
					_doubles = _varr.concat();
			}
			_varr = _doubles = null;
		}
		 
		private function extrudePoints(points1:Vector.<Vector3D>, points2:Vector.<Vector3D>, vscale:Number, indexv:int, indexp:Number):void
		{
			var i:int;
			var j:int;
			
			var stepx:Number;
			var stepy:Number;
			var stepz:Number;
			 
			var va:Vertex;
			var vb:Vertex;
			var vc:Vertex;
			var vd:Vertex;
			
			var u1:Number;
			var u2:Number;
			var index:uint = 0;
			
			var v1:Number = 0;
			var v2:Number = 0;
			
			var countloop:int = points1.length;
			
			var mat:MaterialBase;
			
			if(_mapfit){
				var dist:Number = 0;
				var tdist:Number;
				var bleft:Vector3D;
				for(i = 0;i<countloop; ++i){
					for(j = 0;j< countloop; ++j){
						if(i != j){
							tdist = Vector3D.distance(points1[i], points1[j]);
							if(tdist>dist){
								dist = tdist;
								bleft = points1[i];
							}
						}
					}
				}
				
			} else {
				var bu:Number = 0;
				var bincu:Number = 1/countloop;
			}
			
			function getDouble(x:Number, y:Number, z:Number ):Vertex
			{
				for(var i:int = 0;i<_doubles.length; ++i){
					if( _doubles[i].x == x && _doubles[i].y == y && _doubles[i].z == z){
						return _doubles[i];
					}
				}
				return new Vertex( x, y, z); 
			}
			 
			for( i = 0; i < countloop; ++i){
				stepx = points2[i].x - points1[i].x;
				stepy = points2[i].y - points1[i].y;
				stepz = points2[i].z - points1[i].z;
				
				for( j = 0; j < 2; ++j){
					if(_isClosedProfile &&  _doubles.length > 0){
						_varr.push( getDouble(points1[i].x+(stepx*j) , points1[i].y+(stepy*j), points1[i].z+(stepz*j) )   );
					} else {
						_varr.push( new Vertex( points1[i].x+(stepx*j) , points1[i].y+(stepy*j), points1[i].z+(stepz*j)) );
					}
				}
			}
			 
			if(_coverSegment) var floored:uint = indexp;
			 
			mat = ( _coverAll || !_materials || _materials.length == 0)? this.material : _materials[_matIndex] ;
			
			var covSub:Boolean = _coverAll && _subdivision > 1;
			var cosegSub:Boolean = _coverSegment && _subdivision > 1;
			 
			for( i = 0; i < countloop-1; ++i){
				
				if(_mapfit){
					u1 = 1-Vector3D.distance(points1[i], bleft) /dist;
					u2 = 1-Vector3D.distance(points1[i+1], bleft) /dist;
					
				} else {
					u1 = 1-bu;
					bu += bincu;
					u2 = 1-bu;
				}
				
				v1 = (covSub)? vscale : ( (cosegSub)? indexp - floored : 0 );
				v2 = (covSub)? vscale+(1/indexv) : ( (cosegSub)? v1+ _segv : 1 );
				 
				_uva.u = u1;
				_uva.v = v1;
				_uvb.u = u1;
				_uvb.v = v2;
				_uvc.u = u2;
				_uvc.v = v2;
				_uvd.u = u2;
				_uvd.v = v1;
				 
				va = _varr[index];
				vb = _varr[index+1];
				vc = _varr[index+3];
				vd = _varr[index+2];
				 
				if(flip){
					addFace(vb, va, vc, _uvb, _uva, _uvc, mat);
					addFace(vc, va, vd, _uvc, _uva, _uvd, mat);
					
				} else {
					addFace(va, vb, vc, _uva, _uvb, _uvc, mat);
					addFace(va, vc, vd, _uva, _uvc, _uvd, mat);
				}
				  
				if(_mapfit) u1 = u2;
				 
				index += 2;
			}
			
			if(_materials && _materials.length>0){
				
				if(_coverSegment && indexp - floored == 0){
					 _matIndex = (_matIndex+1 > _materials.length-1)? 0 : _matIndex+1;
				} else if (!coverAll && !_coverSegment){
					_matIndex = (_matIndex+1 > _materials.length-1)? 0 : _matIndex+1;
				}
			}
		}
		
		private function initHolders():void
		{	
			if(!_uva){
				_uva = new UV(0,0);
				_uvb = new UV(0,0);
				_uvc = new UV(0,0);
				_uvd = new UV(0,0);
				_normal = new Vector3D(0.0, 0.0, 0.0);
			}
			
			if(_materials && _materials.length > 0){
				var sglist:SubGeometryList = new SubGeometryList();
				_MaterialsSubGeometries.push(sglist);
				sglist.subGeometry = new SubGeometry();
				_subGeometry = sglist.subGeometry;
				
				sglist.uvs = _uvs = new Vector.<Number>();
				sglist.vertices = _vertices = new Vector.<Number>();
				if(_smoothSurface) sglist.normals = _normals = new Vector.<Number>();
				sglist.indices = _indices = new Vector.<uint>();
				sglist.material = this.material; 
				sglist.material.name = "baseMaterial";
				
			} else{
				_uvs = new Vector.<Number>();
				_vertices = new Vector.<Number>();
				_indices = new Vector.<uint>();
				if(_smoothSurface) {
					_normals = new Vector.<Number>();
				} else{
					_subGeometry.autoDeriveVertexNormals = true;
				}
           		_subGeometry.autoDeriveVertexTangents = true;
			}
		}
		
		private function getSubGeometryListFromMaterial(mat:MaterialBase):SubGeometryList
		{
			var sglist:SubGeometryList;
			
			for(var i:uint = 0;i<_MaterialsSubGeometries.length;++i){
				if(_MaterialsSubGeometries[i].material == mat){
					sglist = _MaterialsSubGeometries[i];
					break;
				}
			}
			
			if(!sglist){
				sglist = new SubGeometryList();
				_MaterialsSubGeometries.push(sglist);
				sglist.subGeometry = new SubGeometry();
				sglist.uvs = new Vector.<Number>();
				sglist.vertices = new Vector.<Number>();
				sglist.indices = new Vector.<uint>();
				sglist.material = mat;
				if(_smoothSurface) sglist.normals = new Vector.<Number>();
			}
			
			return sglist;
		}
		
		private function calcNormal(v0:Vertex,v1:Vertex,v2:Vertex):void
		{
			var dx1:Number = v2.x-v0.x;
			var dy1:Number = v2.y-v0.y;
			var dz1:Number = v2.z-v0.z;
			var dx2:Number = v1.x-v0.x;
			var dy2:Number = v1.y-v0.y;
			var dz2:Number = v1.z-v0.z;
			
			var cx:Number = dz1*dy2 - dy1*dz2;
			var cy:Number = dx1*dz2 - dz1*dx2;
			var cz:Number = dy1*dx2 - dx1*dy2;
			var d:Number  = 1/Math.sqrt(cx*cx+cy*cy+cz*cz);
			 
			_normal.x = cx*d;
			_normal.y = cy*d;
			_normal.z = cz*d; 
		}
		
		private function addFace(v0:Vertex, v1:Vertex, v2:Vertex, uv0:UV, uv1:UV, uv2:UV, mat:MaterialBase):void
		{
			var subGeom:SubGeometry;
			var uvs:Vector.<Number>;
			var vertices:Vector.<Number>;
			var normals:Vector.<Number>;
			var indices:Vector.<uint>;
			var sglist:SubGeometryList;
			
			var startMat:Boolean;
			 
			if(_activeMaterial != mat && _materials && _materials.length > 0){
				
				_activeMaterial = mat;
				sglist = getSubGeometryListFromMaterial(mat);
				_subGeometry = subGeom = sglist.subGeometry;
				_uvs = uvs = sglist.uvs;
				_vertices = vertices = sglist.vertices;
				_indices = indices = sglist.indices;
				_normals = normals = sglist.normals;
				startMat = true;
				
			} else {

			 	subGeom = _subGeometry;
				uvs = _uvs;
				vertices = _vertices;
				indices = _indices;
				normals = _normals;
			}
			
			if(vertices.length+9>LIMIT){
				subGeom.updateVertexData(vertices);
				subGeom.updateIndexData(indices);
				subGeom.updateUVData(uvs);
				if(_smoothSurface)
					subGeom.updateVertexNormalData(normals);
					
				this.geometry.addSubGeometry(subGeom);
				this.subMeshes[this.subMeshes.length-1].material = mat;
				 
				subGeom = new SubGeometry();
				subGeom.autoDeriveVertexTangents = true;
				if(!_smoothSurface)
					subGeom.autoDeriveVertexNormals = true;
					
				if(_MaterialsSubGeometries && _MaterialsSubGeometries.length > 1){
					sglist = getSubGeometryListFromMaterial(mat);
					sglist.subGeometry = _subGeometry = subGeom;
					sglist.uvs = _uvs = uvs = new Vector.<Number>();
					sglist.vertices = _vertices = vertices = new Vector.<Number>();
					sglist.indices =_indices = indices = new Vector.<uint>();
					if(_smoothSurface)
						sglist.normals = _normals = normals = new Vector.<Number>();
						
				} else {
					
					_subGeometry = subGeom;
					uvs = _uvs = new Vector.<Number>();
					vertices = _vertices = new Vector.<Number>();
					indices = _indices = new Vector.<uint>();
					normals = _normals = new Vector.<Number>();
				}
			} 
			 
			var bv0:Boolean;
			var bv1:Boolean;
			var bv2:Boolean;
			
			var ind0:uint;
			var ind1:uint;
			var ind2:uint;
			
			if(_smoothSurface && !startMat){
				var uvind:uint;
				var uvindV:uint;
				var vind:uint;
				var vindy:uint;
				var vindz:uint;
				var ind:uint;
				var indlength:uint = indices.length;
				calcNormal(v0, v1, v2); 
				 
				if(indlength> 0 ){
					var back:Number = indlength - _maxIndProfile;
					var limitBack:uint = (back<0)? 0 :back;

					for(var i:uint = indlength-1; i > limitBack; --i){
						ind = indices[i];
						vind = ind*3;
						vindy = vind+1;
						vindz = vind+2;
						uvind = ind*2;
						uvindV = uvind+1;
						
						if(bv0 && bv1 && bv2)
							break;
							
						if(!bv0 && vertices[vind] == v0.x && vertices[vindy] == v0.y && vertices[vindz] == v0.z){
							
							if (_coverAll || uvs[uvind] == uv0.u && uvs[uvindV] == uv0.v ){
								normals[vind] = (normals[vind]+_normal.x)*.5;
								normals[vindy] = (normals[vindy]+_normal.y)*.5;
								normals[vindz] = (normals[vindz]+_normal.z)*.5;
								bv0 = true;
								ind0 = ind;
								continue;
							 }
						}
						
						if(!bv1 && vertices[vind] == v1.x && vertices[vindy] == v1.y && vertices[vindz] == v1.z){
							
							 if( _coverAll || uvs[uvind] == uv1.u &&  uvs[uvindV] == uv1.v ){
								normals[vind] = (normals[vind]+_normal.x)*.5;
								normals[vindy] = (normals[vindy]+_normal.y)*.5;
								normals[vindz] = (normals[vindz]+_normal.z)*.5;
								bv1 = true;
								ind1 = ind;
								continue;
							 }
						}
						
						if(!bv2 && vertices[vind] == v2.x && vertices[vindy] == v2.y && vertices[vindz] == v2.z){

							if( _coverAll || uvs[uvind] == uv2.u &&  uvs[uvindV] == uv2.v ){
								normals[vind] = (normals[vind]+_normal.x)*.5;
								normals[vindy] = (normals[vindy]+_normal.y)*.5;
								normals[vindz] = (normals[vindz]+_normal.z)*.5;								
								bv2 = true;
								ind2 = ind;
								continue;
							 }
						}
					}
				}
				
			}
			
			if(!bv0){
				ind0 = vertices.length/3;
				vertices.push(v0.x, v0.y, v0.z);
				uvs.push(uv0.u, uv0.v);
				if(_smoothSurface) normals.push(_normal.x, _normal.y, _normal.z);
			}
			
			if(!bv1){
				ind1 = vertices.length/3;
				vertices.push(v1.x, v1.y, v1.z);
				uvs.push(uv1.u, uv1.v);
				if(_smoothSurface) normals.push(_normal.x, _normal.y, _normal.z);
			}
			
			if(!bv2){
				ind2 = vertices.length/3;
				vertices.push(v2.x, v2.y, v2.z);
				uvs.push(uv2.u, uv2.v);
				if(_smoothSurface) normals.push(_normal.x, _normal.y, _normal.z);
			}
			
			indices.push(ind0, ind1, ind2);
		}
		
    	private function buildExtrude():void
    	{
    		 
			if(_path == null || _path.length == 0 || _profile == null || _profile.length < 2)
				throw new Error("PathExtrude error: invalid Path or profile with unsufficient data");
				
				_geomDirty = false;
				initHolders();
				 
				_worldAxis = _path.worldAxis;
				
				_maxIndProfile = _profile.length*9;
				
				var vSegPts:Vector.<Vector.<Vector3D>> = PathUtils.getPointsOnCurve(_path, _subdivision);
				var vPtsList:Vector.<Vector3D> = new Vector.<Vector3D>();
				var vSegResults:Vector.<Vector.<Vector3D>> = new Vector.<Vector.<Vector3D>>();
				var atmp:Vector.<Vector3D>;
				var tmppt:Vector3D = new Vector3D(0,0,0);
				 
				var i:uint;
				var j:uint;
				var k:uint;
				
				var nextpt:Vector3D;
				if(_coverSegment)_segv = 1/ (_subdivision-1);
				
				if(_closePath) var lastP:Vector.<Vector3D> = new Vector.<Vector3D>();
				
				var rescale:Boolean = (_scales != null);
				if(rescale) var lastscale:Vector3D = (_scales[0] == null)? new Vector3D(1, 1, 1) : _scales[0];
					
				var rotate:Boolean = (_rotations != null);
				
				if(rotate && _rotations.length > 0){
					var lastrotate:Vector3D = _rotations[0];
					var nextrotate:Vector3D;
					var rotation:Vector.<Vector3D> = new Vector.<Vector3D>();
					var tweenrot:Vector3D;
				}
				 
				if(_smoothScale && rescale){
					var nextscale:Vector3D = new Vector3D(1, 1, 1);
					var vScales:Vector.<Vector3D> = Vector.<Vector3D>([lastscale]);
					if(_scales.length!=_path.length+2){
						var lastScl:Vector3D = _scales[_scales.length-1];
						while (_scales.length!=_path.length+2){
							_scales.push(lastScl);
						}
					}
				}
				
				var tmploop:int = _profile.length;
				for (i = 0; i <vSegPts.length; ++i) {
					if(rotate){
						lastrotate = (_rotations[i] == null) ? lastrotate : _rotations[i];
						nextrotate = (_rotations[i+1] == null) ? lastrotate : _rotations[i+1];
						rotation = Vector.<Vector3D>([lastrotate]);
						rotation = rotation.concat(PathUtils.step( lastrotate, nextrotate,  _subdivision));
					}
					
					if(rescale)  lastscale = (!_scales[i])? lastscale : _scales[i];
					 
					if(_smoothScale && rescale ){
						nextscale = (!_scales[i+1]) ? (!_scales[i])? lastscale : _scales[i] : _scales[i+1];
						vScales = vScales.concat(PathUtils.step( lastscale, nextscale, _subdivision));
					}
					
					for(j = 0; j<vSegPts[i].length;++j){
						 
						atmp = new Vector.<Vector3D>();
						atmp = atmp.concat(_profile);
						vPtsList = new Vector.<Vector3D>();
						
						if(rotate)
							tweenrot = rotation[j];

						if(_alignToPath) {
							_trans = new Matrix3D();
							if(i == vSegPts.length -1 && j==vSegPts[i].length-1){
								
								if(_closePath){
									nextpt = vSegPts[0][0];
									orientateAt(nextpt, vSegPts[i][j]);
								} else{
									nextpt = vSegPts[i][j-1];
									orientateAt(vSegPts[i][j], nextpt);
								}
								
							} else {
								nextpt = (j<vSegPts[i].length-1)? vSegPts[i][j+1]:  vSegPts[i+1][0];
								orientateAt(nextpt, vSegPts[i][j]);
							}
						}
						
						for (k = 0; k <tmploop; ++k) {
							
							if(rescale && !_smoothScale){
								atmp[k].x *= lastscale.x;
								atmp[k].y *= lastscale.y;
								atmp[k].z *= lastscale.z;
							}
							 
							if(_alignToPath) {
								tmppt = new Vector3D();
								 
								tmppt.x = atmp[k].x * _trans.rawData[0] + atmp[k].y * _trans.rawData[4] + atmp[k].z * _trans.rawData[8] + _trans.rawData[12];
								tmppt.y = atmp[k].x * _trans.rawData[1] + atmp[k].y * _trans.rawData[5] + atmp[k].z * _trans.rawData[9] + _trans.rawData[13];
								tmppt.z = atmp[k].x * _trans.rawData[2] + atmp[k].y * _trans.rawData[6] + atmp[k].z * _trans.rawData[10] + _trans.rawData[14];
								
								if(rotate)
									tmppt = PathUtils.rotatePoint(tmppt, tweenrot);
								 
								tmppt.x +=  vSegPts[i][j].x;
								tmppt.y +=  vSegPts[i][j].y;
								tmppt.z +=  vSegPts[i][j].z;
								
							} else {
								 
								tmppt = new Vector3D(atmp[k].x+vSegPts[i][j].x, atmp[k].y+vSegPts[i][j].y, atmp[k].z+vSegPts[i][j].z);
							}
							
							vPtsList.push(tmppt );
						}
						
						if(_closePath && i == vSegPts.length-1 &&  j == vSegPts[i].length -1) 
								break;
						
						if(_closePath)
							lastP = vPtsList;
								
						vSegResults.push(vPtsList);
						 
					}
				}
				 
				if(rescale && _smoothScale){
					for (i = 0; i < vScales.length; ++i) {
						 for (j = 0;j < vSegResults[i].length; ++j) {
							vSegResults[i][j].x *= vScales[i].x;
							vSegResults[i][j].y *= vScales[i].y;
							vSegResults[i][j].z *= vScales[i].z;
						 }
					}
					vScales = null;
				}
				
				if(rotate) rotation = null;
				 
				if(_closePath){
					var stepx:Number;
					var stepy:Number;
					var stepz:Number;
					var c:Vector.<Vector3D>;
					var c2:Vector.<Vector.<Vector3D>> = new Vector.<Vector.<Vector3D>>();
					 
					for( i = 1; i < _subdivision+1; ++i){
						c = new Vector.<Vector3D>();
						for(j = 0; j < lastP.length; ++j){
							stepx = (vSegResults[0][j].x - lastP[j].x)/_subdivision;
							stepy = (vSegResults[0][j].y - lastP[j].y)/_subdivision;
							stepz = (vSegResults[0][j].z - lastP[j].z)/_subdivision;
							c.push( new Vector3D( lastP[j].x+(stepx*i) , lastP[j].y+(stepy*i), lastP[j].z+(stepz*i)) );
						}
						c2.push(c);
					}
					
					c2[0] = lastP;
					generate(c2, (_coverAll)? vSegResults.length : 0, _coverAll);
					c = null;
					c2 = null;
				}
				
				generate(vSegResults, (_closePath && _coverAll)? 1 : 0, (_closePath && !_coverAll));
				
				vSegPts = null;
				_varr = null;
				 
				if(_MaterialsSubGeometries && _MaterialsSubGeometries.length>0){
					var sglist:SubGeometryList;
					var sg:SubGeometry;
					for(i = 0;i<_MaterialsSubGeometries.length;++i){
						sglist = _MaterialsSubGeometries[i];
						sg = sglist.subGeometry;
						if(sg && sglist.vertices.length >0){
							this.geometry.addSubGeometry(sg);
							this.subMeshes[this.subMeshes.length-1].material = sglist.material;
							sg.updateVertexData(sglist.vertices);
							sg.updateIndexData(sglist.indices);
							sg.updateUVData(sglist.uvs);
							if(_smoothSurface)
								sg.updateVertexNormalData(sglist.normals);
						}
					}
					
				} else {
					
					_subGeometry.updateVertexData(_vertices);
					_subGeometry.updateIndexData(_indices);
					_subGeometry.updateUVData(_uvs);
					if(_smoothSurface)
						_subGeometry.updateVertexNormalData(_normals);
						
					this.geometry.addSubGeometry(_subGeometry);
				}
				
				/*if(!_coverAll && _smoothSurface){
					for(i = 0;i<this.subMeshes.length;++i){
						this.subMeshes[i].material.repeat = true;
					}
				}*/
				
				if (_centerMesh)
					MeshHelper.recenter( this);
		}
	}
}

class SubGeometryList {
	import away3d.core.base.SubGeometry;
	import away3d.materials.MaterialBase;
	
	public var uvs:Vector.<Number>;
	public var vertices:Vector.<Number>;
	public var normals:Vector.<Number>;
	public var indices:Vector.<uint>;
	public var subGeometry:SubGeometry;
	public var material:MaterialBase;
}