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
	import away3d.materials.methods.BasicSpecularMethod;

	import flash.display.BitmapData;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;

	use namespace arcane;
	
	/**
	 * OBJParser provides a parser for the OBJ data type.
	 */
	public class OBJParser extends ParserBase
	{
		private var _startedParsing : Boolean;
		private var _charIndex:uint;
		private var _oldIndex:uint;
		private var _stringLength:uint;
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
		
		private var _mtlLib : Boolean;
		private var _mtlLibLoaded : Boolean = true;
		private var _idCount : uint;
		private var _activeMaterialID:String = "";
		
		private var _vertices : Vector.<Vertex>;
		private var _vertexNormals : Vector.<Vertex>;
		private var _uvs : Vector.<UV>;
		
		private var _scale : Number;
		
		/**
		 * Creates a new OBJParser object.
		 * @param uri The url or id of the data or file to be parsed.
		 * @param extra The holder for extra contextual data that the parser might need.
		 */
		public function OBJParser(scale:Number = 1)
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
			return extension == "obj";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data : *) : Boolean
		{
			var content : String = String(data);
			
			var hasV : Boolean = content.indexOf("\nv ") != -1;
			var hasF : Boolean = content.indexOf("\nf ") != -1;
			
			return hasV && hasF;
		}
		
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency:ResourceDependency):void
		{
			if (resourceDependency.id == 'mtl') {
				var ba : ByteArray = resourceDependency.data;
				
				parseMtl(ba.readUTFBytes(ba.bytesAvailable));
			}
			else {
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
			
			if(_meshes.length>0)
				applyMaterial(lm);
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
				_stringLength = _textData.length;
				_charIndex = _textData.indexOf(creturn, 0);
				_oldIndex = 0;
				_objects = new Vector.<ObjectGroup>();
				_objectIndex = 0;
			}
			
			while(_charIndex<_stringLength && hasTime()){
				_charIndex = _textData.indexOf(creturn, _oldIndex);
				
				if(_charIndex == -1)
					_charIndex = _stringLength;
				
				line = _textData.substring(_oldIndex, _charIndex);
				line = line.split('\r').join("");
				
				trunk = line.replace("  "," ").split(" ");
				_oldIndex = _charIndex+1;
				parseLine(trunk);
			}
			
			if(_charIndex >= _stringLength){
				
				if(_mtlLib  && !_mtlLibLoaded)
					return MORE_TO_PARSE;
				
				try {
					translate();
					applyMaterials();
					
					return PARSING_DONE;
					
				} catch(e:Error){
					parsingFailure = true;
					trace("parsing failure");
					
					//TODO: DEAL WITH THIS ERROR!
					return PARSING_DONE;
				}
			}
			
			return MORE_TO_PARSE;
		}
		
		/**
		* Parses a single line in the OBJ file.
		*/
		private function parseLine(trunk : Array) : void
		{
			switch (trunk[0]) {
				case "mtllib":
					_mtlLib = true;
					_mtlLibLoaded = false;
					loadMtl (trunk[1]);
					break;
				case "g":
					createGroup(trunk);
					break;
				case "o":
					createObject(trunk);
					break;
				case "usemtl":
					if(_mtlLib){
						_materialIDs.push(trunk[1]);
						_activeMaterialID = trunk[1];
						if(_currentGroup) _currentGroup.materialID= _activeMaterialID;
					}
					break;
				case "v":
					parseVertex(trunk);
					break;
				case "vt":
					parseUV(trunk);
					break;
				case "vn":
					parseVertexNormal(trunk);
					break;
				case "f":
					parseFace(trunk);
			}
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
				for (m = 0; m < numMaterialGroups; ++m) {
					translateMaterialGroup(materialGroups[m], geometry);
				}
				bmMaterial = new BitmapMaterial(defaultBitmapData);
				mesh = new Mesh(bmMaterial, geometry);
				meshid = _meshes.length;
				mesh.name = "obj"+meshid;
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
			for (var i : uint = 0; i < numFaces; ++i) {
				face = faces[i];
				numVerts = face.indexIds.length - 1;
				for (j = 1; j < numVerts; ++j) {
					translateVertexData(face, j, vertices, uvs, indices, normals);
					translateVertexData(face, 0, vertices, uvs, indices, normals);
					translateVertexData(face, j+1, vertices, uvs, indices, normals);
				}
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
						nuvs.push(uvs[uvind], uvs[uvind+1]);
						
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
					vertexNormal = _vertexNormals[face.normalIndices[vertexIndex]-1];
					normals.push(vertexNormal.x, vertexNormal.y, vertexNormal.z);
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
		private function createObject(trunk : Array) : void
		{
			_currentGroup = null;
			_currentMaterialGroup = null;
			_objects.push(_currentObject = new ObjectGroup());
			if (trunk) _currentObject.name = trunk[1];
		}
		
		/**
		 * Creates a new group.
		 * @param trunk The data block containing the group tag and its parameters
		 */
		private function createGroup(trunk : Array) : void
		{
			if (!_currentObject) createObject(null);
			_currentGroup = new Group();
			
			_currentGroup.materialID = _activeMaterialID;
			
			if (trunk) _currentGroup.name = trunk[1];
			_currentObject.groups.push(_currentGroup);
			
			createMaterialGroup(null);
		}
		
		/**
		 * Creates a new material group.
		 * @param trunk The data block containing the material tag and its parameters
		 */
		private function createMaterialGroup(trunk : Array) : void
		{
			_currentMaterialGroup = new MaterialGroup();
			if (trunk) _currentMaterialGroup.url = trunk[1];
			_currentGroup.materialGroups.push(_currentMaterialGroup);
		}
		
		/**
		 * Reads the next vertex coordinates.
		 * @param trunk The data block containing the vertex tag and its parameters
		 */
		private function parseVertex(trunk : Array) : void
		{
			_vertices.push(new Vertex(parseFloat(trunk[1]), parseFloat(trunk[2]), -parseFloat(trunk[3])));
		}
		
		/**
		 * Reads the next uv coordinates.
		 * @param trunk The data block containing the uv tag and its parameters
		 */
		private function parseUV(trunk : Array) : void
		{
			_uvs.push(new UV(parseFloat(trunk[1]), 1-parseFloat(trunk[2])));
		}
		
		/**
		 * Reads the next vertex normal coordinates.
		 * @param trunk The data block containing the vertex normal tag and its parameters
		 */
		private function parseVertexNormal(trunk : Array) : void
		{
			_vertexNormals.push(new Vertex(parseFloat(trunk[1]), parseFloat(trunk[2]), -parseFloat(trunk[3])));
		}
		
		/**
		 * Reads the next face's indices.
		 * @param trunk The data block containing the face tag and its parameters
		 */
		private function parseFace(trunk : Array) : void
		{
			var len : uint = trunk.length;
			var face : FaceData = new FaceData();
			
			if (!_currentGroup) createGroup(null);
			
			var indices : Array;
			for (var i : uint = 1; i < len; ++i) {
				if (trunk[i] == "") continue;
				indices = trunk[i].split("/");
				face.vertexIndices.push(parseInt(indices[0]));
				if (indices[1] && String(indices[1]).length > 0) face.uvIndices.push(parseInt(indices[1]));
				if (indices[2] && String(indices[2]).length > 0) face.normalIndices.push(parseInt(indices[2]));
				face.indexIds.push(trunk[i]);
			}
			
			_currentMaterialGroup.faces.push(face);
		}
		
		private function parseMtl(data : String):void
		{
			var materialDefinitions:Array = data.split('newmtl');
			var lines:Array;
			var trunk:Array;
			var j:uint;
			
			var basicSpecularMethod:BasicSpecularMethod;
			var useSpecular:Boolean;
			var useColor:Boolean;
			var diffuseColor:uint;
			var ambientColor:uint;
			var specularColor:uint;
			var specular:Number;
			var alpha:Number;
			var mapkd:String;
			
			for(var i:uint = 0;i<materialDefinitions.length;++i){
				
				lines = materialDefinitions[i].split('\r').join("").split('\n');
				
				if(lines.length == 1)
					lines = materialDefinitions[i].split(String.fromCharCode(13));
				
				diffuseColor = ambientColor = specularColor = 0xFFFFFF;
				specular = 0;
				useSpecular = false;
				useColor = false;
				alpha = 1;
				mapkd = "";
				
				for(j = 0;j<lines.length;++j){
					lines[j] = lines[j].replace(/\s+$/,"");
					
					if(lines[j].substring(0,1) != "#" && lines[j] != ""){
						trunk = lines[j].split(" ");
						
						if(String(trunk[0]).charCodeAt(0) == 9 || String(trunk[0]).charCodeAt(0) == 32)
							trunk[0] = trunk[0].substring(1, trunk[0].length);
						
						if(j == 0){
							
							_lastMtlID = trunk.join("");
							
						} else {
							
							switch (trunk[0]) {
								
								case "Ka":
									if(trunk[1] && !isNaN(Number(trunk[1])) && trunk[2] && !isNaN(Number(trunk[2])) && trunk[3] && !isNaN(Number(trunk[3])))
										ambientColor = trunk[1]*255 << 16 | trunk[2]*255 << 8 | trunk[3]*255;
									break;
								
								case "Ks":
									if(trunk[1] && !isNaN(Number(trunk[1])) && trunk[2] && !isNaN(Number(trunk[2])) && trunk[3] && !isNaN(Number(trunk[3]))){
										specularColor = trunk[1]*255 << 16 | trunk[2]*255 << 8 | trunk[3]*255;
										useSpecular = true;
									}
									break;
								
								case "Ns":
									if(trunk[1] && !isNaN(Number(trunk[1]))) specular = Number(trunk[1]) * 0.001;
									if(specular == 0) useSpecular = false;
									break;
								
								case "Kd":
									if(trunk[1] && !isNaN(Number(trunk[1])) && trunk[2] && !isNaN(Number(trunk[2])) && trunk[3] && !isNaN(Number(trunk[3]))){
										diffuseColor = trunk[1]*255 << 16 | trunk[2]*255 << 8 | trunk[3]*255;
										useColor = true;
									}
									break;
								
								case "tr":
								case "d":
									if(trunk[1] && !isNaN(Number(trunk[1]))) alpha = Number(trunk[1]);
									break;
								
								case "map_Kd":
									mapkd = parseMapKdString(trunk);
									mapkd = mapkd.replace(/\\/g, "/");
							}
						}
					}
				}
				
				if(mapkd != ""){
					
					if(useSpecular){
						
						basicSpecularMethod = new BasicSpecularMethod();
						basicSpecularMethod.specularColor = specularColor;
						basicSpecularMethod.specular = specular;
						
						var specularData:SpecularData = new SpecularData();
						specularData.basicSpecularMethod = basicSpecularMethod;
						specularData.materialID = _lastMtlID;
						
						if(!_materialSpecularData)
							_materialSpecularData  = new Vector.<SpecularData>();
						
						_materialSpecularData.push(specularData);
					}
					
					addDependency(_lastMtlID, new URLRequest(mapkd));
					
					
				} else if(useColor && !isNaN(diffuseColor)){
					
					var lm:LoadedMaterial = new LoadedMaterial();
					lm.materialID = _lastMtlID;
					
					if(alpha == 0)
						trace("Warning: an alpha value of 0 was found in mtl color tag (Tr or d) ref:"+_lastMtlID+", mesh(es) using it will be invisible!");
					
					lm.bitmapData = new BitmapData(256, 256, (alpha == 1)? false : true, diffuseColor); 
					lm.ambientColor = ambientColor;
					
					if(useSpecular){
						basicSpecularMethod = new BasicSpecularMethod();
						basicSpecularMethod.specularColor = specularColor;
						basicSpecularMethod.specular = specular;
						lm.specularMethod = basicSpecularMethod;
					}
					
					_materialLoaded.push(lm);
					
					if(_meshes.length>0)
						applyMaterial(lm);
					
				}
			}
			
			_mtlLibLoaded = true;
		}
		
		private function parseMapKdString(trunk:Array):String
		{
			var url:String = "";
			var i:int;
			var breakflag:Boolean;
			
			for(i = 1; i < trunk.length;) {
				switch(trunk[i]) {
					case "-blendu" :
					case "-blendv" :
					case "-cc" :
					case "-clamp" :
					case "-texres" :
						i += 2;		//Skip ahead 1 attribute
						break;
					case "-mm" :
						i += 3;		//Skip ahead 2 attributes
						break;
					case "-o" :
					case "-s" :
					case "-t" :
						i += 4;		//Skip ahead 3 attributes
						continue;
					default :
						breakflag = true;
						break;
				}
				
				if(breakflag)
					break;
			}
			
			//Reconstruct URL/filename
			for(i; i < trunk.length; i++) {
				url += trunk[i];
				url += " ";
			}
			
			//Remove the extraneous space and/or newline from the right side
			url = url.replace(/\s+$/,"");
			
			return url;
		}
		
		private function loadMtl(mtlurl:String):void
		{
			// Add raw-data dependency to queue and load dependencies now,
			// which will pause the parsing in the meantime.
			addDependency('mtl', new URLRequest(mtlurl), true);
			pauseAndRetrieveDependencies();
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
		
	}
}

import away3d.materials.methods.BasicSpecularMethod;

import flash.display.BitmapData;

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
	public var materialID : String;
	public var basicSpecularMethod : BasicSpecularMethod;
	public var ambientColor:uint = 0xFFFFFF;
}

class LoadedMaterial
{
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

