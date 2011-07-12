package away3d.loaders.parsers
{
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.core.base.data.UV;
	import away3d.core.base.data.Vertex;
	import away3d.entities.Mesh;
	import away3d.library.assets.BitmapDataAsset;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.BitmapMaterial;
	import away3d.materials.ColorMaterial;
	import away3d.materials.methods.BasicSpecularMethod;
	
	import flash.display.BitmapData;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	
	use namespace arcane;
	
	/**
	 * OBJParser provides a parser for the OBJ data type.
	 */
	public class JSONOBJParser extends ParserBase
	{
		private var _startedParsing : Boolean;
		private const LIMIT:uint = 64998;
		private var _currentObject : ObjectGroup;
		private var _currentGroup : Group;
		private var _currentMaterialGroup : MaterialGroup;
		private var _objects : Vector.<ObjectGroup>;
		private var _materialIDs : Vector.<String>;
		private var _materialLoaded : Vector.<LoadedMaterial>;
		private var _materialSpecularData : Vector.<SpecularData>;
		private var _meshes : Vector.<Mesh>;
		private var _lastMtlID:String;
		private var _objectIndex : uint;
		private var _realIndices : Array;
		private var _vertexIndex : uint;
		private var _jsonOBJ:Object;
		private var _mtlLib : Boolean;
		private var _mtlLibLoaded : Boolean = true;
		private var _isQuad: Boolean = false;
		private var _idCount : uint;
		private var _activeMaterialID:String = "";
		
		private var _vertices : Vector.<Vertex>;
		private var _vertexNormals : Vector.<Vertex>;
		private var _uvs : Vector.<UV>;
		
		private var _scale : Number;
		
		/**
		 * Creates a new JSONOBJParser object.
		 * @param uri The url or id of the data or file to be parsed.
		 * @param extra The holder for extra contextual data that the parser might need.
		 */
		public function JSONOBJParser(scale:Number = 1)
		{
			super(ParserDataFormat.PLAIN_TEXT);
			_scale = scale;
		}
		
		/**
		 * Scaling factor applied directly to vertices data
		 * @param value The scaling factor.
		 */
		public function set scale(value:Number):void
		{
			_scale = value;
		}
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "js";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data : *) : Boolean
		{
			var content : String = String(data);
			var hasModel : Boolean = content.indexOf("model") != -1;
			return hasModel;
		}
		
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency:ResourceDependency):void
		{
			if (resourceDependency.assets.length != 1)
				return;
			
			var asset:BitmapDataAsset = resourceDependency.assets[0] as BitmapDataAsset;
			
			if (asset){
				var lm:LoadedMaterial = new LoadedMaterial();
				lm.materialID = resourceDependency.id;
				lm.bitmapData = isBitmapDataValid(asset.bitmapData)? asset.bitmapData : defaultBitmapData ;
				_materialLoaded.push(lm);
				
				if(_meshes.length>0)
					applyMaterial(lm);
			}
		}
		
		/**
		* @inheritDoc
		*/
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			var lm:LoadedMaterial = new LoadedMaterial();
			lm.materialID = resourceDependency.id;
			lm.bitmapData = defaultBitmapData;
			
			_materialLoaded.push(lm);
		}
		
		public function trimJSON( s:String ):String
		{
			var trim:RegExp = /var model = /gi;
			s = s.replace(trim, '{"model":');
			trim = /var model=/gi;
			s = s.replace(trim, '{"model":');
			trim = /postMessage\( model \);/gi;
			s = s.replace(trim, '');
			trim = /postMessage\(model\);/gi;
			s = s.replace(trim, '');
			trim = /close\(\);/gi;
			s = s.replace(trim, '');
			trim = /};/gi;
			s = s.replace(trim, '}}');
			return s.replace( /^([\s|\t|\n]+)?(.*)([\s|\t|\n]+)?$/gm, "$2" );
		}
		
		
		/**
		* @inheritDoc
		*/
		override protected function proceedParsing() : Boolean
		{
			var line:String;
			var creturn:String = String.fromCharCode(10);
			var trunk:Array;
			
			if(_textData.indexOf(creturn) == -1)
				creturn = String.fromCharCode(13);
			
			if(!_startedParsing){
				_startedParsing = true;
				_vertices = new Vector.<Vertex>();
				_vertexNormals = new Vector.<Vertex>();
				_materialIDs = new Vector.<String>();
				_materialLoaded = new Vector.<LoadedMaterial>();
				_meshes = new Vector.<Mesh>();
				_uvs = new Vector.<UV>();
				_jsonOBJ = JSON.parse(trimJSON(_textData));
				_objects = new Vector.<ObjectGroup>();
				_objectIndex = 0;
			}
			
			createObject();
			createGroup();
			parseFace();
			parseVertex();
			parseUV() ;
			parseVertexNormal();
			translate();
			parseMaterial();
			return PARSING_DONE;
		}
		
		
		/**
		* Converts the parsed data into an Away3D scenegraph structure
		*/
		private function translate() :void
		{
			var groups : Vector.<Group> = _objects[_objectIndex].groups;
			var numGroups : uint = groups.length;
			var materialGroups : Vector.<MaterialGroup>;
			var numMaterialGroups : uint;
			var geometry : Geometry;
			var mesh : Mesh;
			var meshid:uint;
			
			var m : uint;
			var sm : uint;
			var bmMaterial:BitmapMaterial;

			for (var g : uint = 0; g < numGroups; ++g) {
				geometry = new Geometry();
				materialGroups = groups[g].materialGroups;
				numMaterialGroups = materialGroups.length;
				translateMaterialGroup(materialGroups[g], geometry);
				bmMaterial = new BitmapMaterial(defaultBitmapData);
				mesh = new Mesh(bmMaterial, geometry);
				meshid = _meshes.length;
				mesh.name = "jsonObj"+meshid;
				_meshes[meshid] = mesh;
				
				if(groups[g].materialID != ""){
					bmMaterial.name = groups[g].materialID+"~"+mesh.name;
				} else {
					bmMaterial.name = _lastMtlID+"~"+mesh.name;
				}
				
				if(mesh.subMeshes.length >1){
					for (sm = 1; sm<mesh.subMeshes.length; ++sm)
						mesh.subMeshes[sm].material = bmMaterial;
				}
				
				finalizeAsset(mesh);
			}
		}
		
		/* If no uv's are found (often seen case with obj format) parser generates a new set of default uv's */
		private function addDefaultUVs(vertices : Vector.<Number>, uvs: Vector.<Number>) :Vector.<Number>
		{
			var j:uint = 0;
			for (var i :uint = 0; i<vertices.length; i+=3){
				if(j == 0){
					uvs.push(0, 1);
				} else if(j == 1){
					uvs.push(.5, 0);
				} else{
					uvs.push(1, 1);
				}
				
				j = (j+1>2)? 0 : j++;
			}
			
			return uvs;
		}
		
		/**
		 * Translates an obj's material group to a subgeometry.
		 * @param materialGroup The material group data to convert.
		 * @param geometry The Geometry to contain the converted SubGeometry.
		 */
		private function translateMaterialGroup(materialGroup : MaterialGroup, geometry : Geometry) : void
		{
			var faces : Vector.<FaceData> = materialGroup.faces;
			var face : FaceData;
			var numFaces : uint = faces.length;
			var numVerts : uint;
			
			var vertices:Vector.<Number> = new Vector.<Number>();
			var uvs:Vector.<Number> = new Vector.<Number>();
			var normals:Vector.<Number> = new Vector.<Number>();
			var indices:Vector.<uint> = new Vector.<uint>();
			 
			_realIndices = [];
			_vertexIndex = 0;

			var j:uint;
			try{
			for (var i : uint = 0; i < numFaces; ++i) {
				face = faces[i];
				numVerts = face.indexIds.length - 1;
				for (j = 1; j < numVerts; ++j) {
					translateVertexData(face, j, vertices, uvs, indices, normals);
					translateVertexData(face, 0, vertices, uvs, indices, normals);
					translateVertexData(face, j+1, vertices, uvs, indices, normals);
				}
			}
			}catch(e:Error){
				trace(e);
				
			}

			var vlength:uint = vertices.length;
			 
			if(vlength > 0){
				
				if(vlength <= LIMIT){
					 
					buildSubGeometry(geometry, vertices, uvs, indices, normals);
					
				} else {
					
					var nvertices:Vector.<Number> = new Vector.<Number>();
					var nuvs:Vector.<Number> = new Vector.<Number>();
					var nnormals:Vector.<Number> = new Vector.<Number>();
					var nindices:Vector.<uint> = new Vector.<uint>();
					
					var ind:uint;
					var vind:uint;
					var uvind:uint;
					 
					vlength = 0;
					
					for (i = 0; i < indices.length; ++i) {
						
						if(vlength+3 > LIMIT){
							vlength = 0;
							buildSubGeometry(geometry, nvertices, nuvs, nindices, nnormals);
							nvertices = new Vector.<Number>();
							nuvs = new Vector.<Number>();
							nnormals = new Vector.<Number>();
							nindices = new Vector.<uint>();
						}
						
						ind = indices[i];
						vind = ind*3;
						uvind = ind*2;
						nindices.push(nvertices.length/3);
						nvertices.push(vertices[vind], vertices[vind+1], vertices[vind+2]);
						try{
						nuvs.push(uvs[uvind], uvs[uvind+1]);
						}catch(e:Error){
							trace('no uv data');
						}
						if(normals[vind]) nnormals.push(normals[vind], normals[vind+1], normals[vind+2]);
						
						vlength+=3;
						
						
					}
					
					buildSubGeometry(geometry, nvertices, nuvs, nindices, nnormals);
					
				}
			}
		}
		
		private function buildSubGeometry(geometry:Geometry, vertices:Vector.<Number>, uvs:Vector.<Number>, indices:Vector.<uint>, normals:Vector.<Number>):void
		{
			if(vertices.length == 0) return;
			
			var subGeom : SubGeometry = new SubGeometry();
			subGeom.autoDeriveVertexTangents = true;
			 
			if(uvs.length == 0 && vertices.length > 0)
				uvs = addDefaultUVs(vertices, uvs);
			
			subGeom.updateVertexData(vertices);
			subGeom.updateIndexData(indices);
			subGeom.updateUVData(uvs);
			
			var deriveVN:Boolean = normals.length>0? true :false;
			subGeom.autoDeriveVertexNormals = deriveVN;
			
			if(deriveVN) subGeom.updateVertexNormalData(normals);
			
			geometry.addSubGeometry(subGeom);
		}

		private function translateVertexData(face : FaceData, vertexIndex : int, vertices:Vector.<Number>, uvs:Vector.<Number>, indices:Vector.<uint>, normals:Vector.<Number>) : void
		{
			var index : uint;
			var vertex : Vertex;
			var vertexNormal : Vertex;
			var uv : UV;

			if (!_realIndices[face.indexIds[vertexIndex]]) {
				index = _vertexIndex;
				_realIndices[face.indexIds[vertexIndex]] = ++_vertexIndex;
				vertex = _vertices[face.vertexIndices[vertexIndex]-1];
				vertices.push(vertex.x * _scale, vertex.y * _scale, vertex.z * _scale);
				if (face.normalIndices.length > 0) {
					try{
					vertexNormal = _vertexNormals[face.normalIndices[vertexIndex]-1];
					normals.push(vertexNormal.x, vertexNormal.y, vertexNormal.z);
					}catch(e:Error){
						trace(e);
					}
				}
				
				if (face.uvIndices.length > 0 ){
					
					try {
						uv = _uvs[face.uvIndices[vertexIndex]-1];
						uvs.push(uv.u, uv.v);
						
					} catch(e:Error) {
						
						switch(vertexIndex){
							case 0:
								uvs.push(0, 1);
								break;
							case 1:
								uvs.push(.5, 0);
								break;
							case 2:
								uvs.push(1, 1);
						}
					}
					
				}

			} else {
				index = _realIndices[face.indexIds[vertexIndex]] - 1;
			}
			indices.push(index);
		}
		
		
		/**
		 * Creates a new object group.
		 * @param trunk The data block containing the object tag and its parameters
		 */
		private function createObject() : void
		{
			_currentGroup = null;
			_currentMaterialGroup = null;
			_objects.push(_currentObject = new ObjectGroup());
			_currentObject.name = 'jsonOBJ';
			//if (trunk) _currentObject.name = trunk[1];
		}
		
		/**
		 * Creates a new group.
		 * @param trunk The data block containing the group tag and its parameters
		 */
		private function createGroup() : void
		{
			_currentGroup = new Group();
			for(var i:uint=0; i<_jsonOBJ.model.materials.length; i++){
			
			_currentGroup.materialID = 'g' + i;
			_currentGroup.name = 'g' + i;
			_currentObject.groups.push(_currentGroup);
			createMaterialGroup(null);
			}
		}
		
		/**
		 * Creates a new material group.
		 * @param trunk The data block containing the material tag and its parameters
		 */
		private function createMaterialGroup(trunk : Array) : void
		{
			_currentMaterialGroup = new MaterialGroup();
			//if (trunk) _currentMaterialGroup.url = trunk[1];
			_currentGroup.materialGroups.push(_currentMaterialGroup);
		}
		
		/**
		 * Reads the next vertex coordinates.
		 * @param trunk The data block containing the vertex tag and its parameters
		 */
		private function parseVertex() : void
		{
			var currentVert:uint =0;
			for(var i:uint = 0; i < _jsonOBJ.model.vertices.length; i++){
			 if(currentVert == i){
				 _vertices.push(new Vertex(parseFloat(_jsonOBJ.model.vertices[i]), parseFloat(_jsonOBJ.model.vertices[i+1]), -parseFloat(_jsonOBJ.model.vertices[i+2])));
				 currentVert = i+3;
			 }
			}
		}
		
		/**
		 * Reads the next uv coordinates.
		 * @param trunk The data block containing the uv tag and its parameters
		 */
		private function parseUV() : void
		{
			var currentVert:uint =0;
			
			for(var i:uint = 0; i < _jsonOBJ.model.uvs[0].length; i++){
				if(currentVert == i){
					_uvs.push(new UV(parseFloat(_jsonOBJ.model.uvs[0][i]),parseFloat(_jsonOBJ.model.uvs[0][i+1])));
					currentVert = i+2;
				}
			}
		}
		
		/**
		 * Reads the next vertex normal coordinates.
		 * @param trunk The data block containing the vertex normal tag and its parameters
		 */
		private function parseVertexNormal() : void
		{
			var currentVert:uint =0;
			for(var i:uint = 0; i < _jsonOBJ.model.normals.length; i++){
				if(currentVert == i){
					_vertexNormals.push(new Vertex(parseFloat(_jsonOBJ.model.normals[i]), parseFloat(_jsonOBJ.model.normals[i+1]), -parseFloat(_jsonOBJ.model.normals[i+2])));
					currentVert = i+3;
				}
			}
		}
		
		/**
		 * Reads the next face's indices.
		 * @param trunk The data block containing the face tag and its parameters
		 */
		private function parseFace() : void
		{	
			var currentVert:uint =1;
			for(var i:uint = 0; i < _jsonOBJ.model.faces.length; i++){
				var id:Number = _jsonOBJ.model.faces[0];
				var face : FaceData = new FaceData();
				var num1:int;
				var num2:int;
				var num3:int;
				
				var num4:int;
				var num5:int;
				var num6:int;
		
				var num7:int;
				var num8:int;
				var num9:int;
				
				var grp:int;
				if(id === _jsonOBJ.model.faces[11]){
				if(currentVert == i){
					num1 = parseInt(_jsonOBJ.model.faces[i])+1;
					num2 = parseInt(_jsonOBJ.model.faces[i+1])+1;
					num3 = parseInt(_jsonOBJ.model.faces[i+2])+1;
					
					num4 = parseInt(_jsonOBJ.model.faces[i+4])+1;
					num5 = parseInt(_jsonOBJ.model.faces[i+5])+1;
					num6 = parseInt(_jsonOBJ.model.faces[i+6])+1;
					
					num7 = parseInt(_jsonOBJ.model.faces[i+7])+1;
					num8 = parseInt(_jsonOBJ.model.faces[i+8])+1;
					num9 = parseInt(_jsonOBJ.model.faces[i+9])+1;
					
					face.vertexIndices.push(num1, num2,num3);
					face.uvIndices.push(num4,num5,num6)
					face.normalIndices.push(num7, num8, num9)
					face.indexIds.push(num1+'/'+num4+'/'+num7,num2+'/'+num5+'/'+num8,num3+'/'+num6+'/'+num9);
					grp = parseInt(_jsonOBJ.model.faces[i+3]);
					_currentGroup.materialGroups[grp].faces.push(face);
					//_currentMaterialGroup.faces.push(face);
					currentVert = i+11;
				}
				}else{
					_isQuad = true;
					// converts Quad data to triangles //
					if(currentVert == i){
					num1 = parseInt(_jsonOBJ.model.faces[i])+1;
					num2 = parseInt(_jsonOBJ.model.faces[i+1])+1;
					num3 = parseInt(_jsonOBJ.model.faces[i+2])+1;
					num4 = parseInt(_jsonOBJ.model.faces[i+3])+1;
		
					num5 = parseInt(_jsonOBJ.model.faces[i+5])+1;
					num6 = parseInt(_jsonOBJ.model.faces[i+6])+1;
					num7 = parseInt(_jsonOBJ.model.faces[i+7])+1;
					num8 = parseInt(_jsonOBJ.model.faces[i+8])+1;
					
					face.vertexIndices.push(num1, num2,num3);
					face.vertexIndices.push(num1, num3,num4);
					face.normalIndices.push(num5, num6, num7);
					face.normalIndices.push(num5, num7, num8);
					
					face.indexIds.push(num1+'/'+'/'+num5,num2+'/'+'/'+num6,num3+'/'+'/'+num7);
					face.indexIds.push(num1+'/'+'/'+num5,num3+'/'+'/'+num7,num4+'/'+'/'+num8);
					
					grp = parseInt(_jsonOBJ.model.faces[i+4]);
					
					_currentGroup.materialGroups[grp].faces.push(face);
					//_currentMaterialGroup.faces.push(face);
					currentVert = i+10;
					}
				}
			}
			
		}
		
		private function parseMaterial():void{
			//var materialDefinitions:Array = data.split('newmtl');
			var lines:Array;
			var trunk:Array;
			var j:uint;
			var mMaterial:BitmapMaterial;
			
			var basicSpecularMethod:BasicSpecularMethod;
			var useSpecular:Boolean;
			var useColor:Boolean;
			var diffuseColor:uint;
			var ambientColor:uint;
			var specularColor:uint;
			var specular:Number;
			var alpha:Number;
			var mapkd:String;
			
			diffuseColor = ambientColor = specularColor = 0xFFFFFF;
			specular = 0;
			useSpecular = false;
			useColor = false;
			alpha = 1;
			mapkd = "";
			var matArray:Array = new Array();
			var matBitArray:Array = new Array();
			var matClArray:Array = new Array();
			
			for(var i:uint = 0; i < _jsonOBJ.model.materials.length; i++){
				var lm:LoadedMaterial = new LoadedMaterial();
				var s:String = _jsonOBJ.model.materials[i].DbgName;
				
				if(s.charAt(0) != "#"){
				
					try{
					ambientColor =	_jsonOBJ.model.materials[i].colorAmbient[0]*255 << 16 | _jsonOBJ.model.materials[i].colorAmbient[1]*255 << 8 || _jsonOBJ.model.materials[i].colorAmbient[2]*255 ; 
					lm.ambientColor = ambientColor;
					}catch(e:Error){
						trace(e);
					}
					
					try{
					specularColor = _jsonOBJ.model.materials[i].colorSpecular[0]*255 << 16 | _jsonOBJ.model.materials[i].colorSpecular[1]*255 << 8 || _jsonOBJ.model.materials[i].colorSpecular[2]*255 ;
					basicSpecularMethod = new BasicSpecularMethod();
					basicSpecularMethod.specularColor = specularColor;
					basicSpecularMethod.specular = specular;
					lm.specularMethod = basicSpecularMethod;
					}catch(e:Error){
						trace(e);
					}
					
					try{
					diffuseColor = _jsonOBJ.model.materials[i].colorDiffuse[0]*255 << 16 | _jsonOBJ.model.materials[i].colorDiffuse[1]*255 << 8 || _jsonOBJ.model.materials[i].colorDiffuse[2]*255 ;
					lm.bitmapData = new BitmapData(256, 256, false, diffuseColor);
					}catch(e:Error){
						trace(e);
					}
					matArray.push(lm);
					addDependency('mat'+i, new URLRequest(_jsonOBJ.model.materials[i].mapDiffuse))

				}else{
					var clMat:ColorMaterial;
					var sLen:int = s.length + 1;
					s = s.slice(1, sLen);
					s = '0x'+s;
					var clr:int = int(s);
					lm.bitmapData = new BitmapData(256, 256, false, clr);
					clMat = new ColorMaterial(clr);
					clMat.bothSides = true;
					matArray.push(lm);
					matClArray.push(clMat);
				}
			}
			
			var mesh:Mesh;
			var mat:BitmapMaterial;
			for(var f:uint = 0; f <_meshes.length;++f){
				mesh = _meshes[f];
				mesh.material.name = 'mat'+f;
				if(matClArray.length <= 0){
					mat = BitmapMaterial(mesh.material);
					try{
						mat.bitmapData = matArray[f].bitmapData;
						mat.ambientColor = matArray[f].ambientColor;
						mat = matBitArray[f];
					}catch(e:Error){
						trace(e);
					}
				}else{
					mesh.material = matClArray[f];
				}
			}
		}
		
		private function applyMaterial(lm:LoadedMaterial) : void
		{
			var meshID:String;
			var decomposeID:Array;
			var mesh:Mesh;
			var mat:BitmapMaterial;
			var j:uint;
			var specularData:SpecularData;
			
			for(var i:uint = 0; i <_meshes.length;++i){
				mesh = _meshes[i];
				decomposeID = mesh.material.name.split("~");
				
				if(decomposeID[0] == lm.materialID){
					mesh.material.name = decomposeID[1];
					mat = BitmapMaterial(mesh.material);
					mat.bitmapData = lm.bitmapData;
					mat.ambientColor = lm.ambientColor;
					mat.mipmap = false;
					mat.bothSides = true;
					if(lm.specularMethod){
						mat.specularMethod = lm.specularMethod;
					} else if(_materialSpecularData){
						for(j = 0;j<_materialSpecularData.length;++j){
							specularData = _materialSpecularData[j];
							if(specularData.materialID == lm.materialID){
								mat.specularMethod = specularData.basicSpecularMethod;
								mat.ambientColor = specularData.ambientColor;
								_materialSpecularData.splice(j,1);
								break;
							}
						}
					}
					_meshes.splice(i, 1);
					--i;
				}
			}
		}
		
		private function applyMaterials() : void
		{
			if(_materialLoaded.length == 0)
				return;
			
			for(var i:uint = 0; i <_materialLoaded.length;++i)
				applyMaterial(_materialLoaded[i]);
		}		
		
		
		/*private function applyMaterial(lm:LoadedMaterial) : void
		{
			var meshID:String;
			var decomposeID:Array;
			var mesh:Mesh;
			var mat:BitmapMaterial;
			var j:uint;
			var specularData:SpecularData;
			
			for(var i:uint = 0; i <_meshes.length;++i){
				mesh = _meshes[i];
				decomposeID = mesh.material.name.split("~");
				
				if(decomposeID[0] == lm.materialID){
					mesh.material.name = decomposeID[1];
					mat = BitmapMaterial(mesh.material);
					mat.bitmapData = lm.bitmapData;
					mat.ambientColor = lm.ambientColor;
					
					if(lm.specularMethod){
						mat.specularMethod = lm.specularMethod;
					} else if(_materialSpecularData){
						for(j = 0;j<_materialSpecularData.length;++j){
							specularData = _materialSpecularData[j];
							if(specularData.materialID == lm.materialID){
								mat.specularMethod = specularData.basicSpecularMethod;
								mat.ambientColor = specularData.ambientColor;
								_materialSpecularData.splice(j,1);
								break;
							}
						}
					}
					
					_meshes.splice(i, 1);
					--i;
				}
			}
		}
		
		private function applyMaterials() : void
		{
			if(_materialLoaded.length == 0)
				return;
			
			for(var i:uint = 0; i <_materialLoaded.length;++i)
				applyMaterial(_materialLoaded[i]);
		}*/
		
	}
}

// value objects:
class ObjectGroup
{
	public var name : String;
	public var groups : Vector.<Group> = new Vector.<Group>();
}

class Group
{
	public var name : String;
	public var materialID : String;
	public var materialGroups : Vector.<MaterialGroup> = new Vector.<MaterialGroup>();
}

class MaterialGroup
{
	public var url : String;
	public var faces : Vector.<FaceData> = new Vector.<FaceData>();
}

class SpecularData
{
	import away3d.materials.methods.BasicSpecularMethod;
	
	public var materialID : String;
	public var basicSpecularMethod : BasicSpecularMethod;
	public var ambientColor:uint = 0xFFFFFF;
}

class LoadedMaterial
{
	import flash.display.BitmapData;
	import away3d.materials.methods.BasicSpecularMethod;
	
	public var materialID:String;
	public var bitmapData:BitmapData;
	
	public var specularMethod:BasicSpecularMethod;
	public var ambientColor:uint = 0xFFFFFF;
}

class FaceData
{
	public var vertexIndices : Vector.<uint> = new Vector.<uint>();
	public var uvIndices : Vector.<uint> = new Vector.<uint>();
	public var normalIndices : Vector.<uint> = new Vector.<uint>();
	public var indexIds : Vector.<String> = new Vector.<String>();	// used for real index lookups
}

