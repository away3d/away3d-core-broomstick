package away3d.loaders.parsers
{
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.library.assets.BitmapDataAsset;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.BitmapMaterial;

	import flash.display.BitmapData;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	use namespace arcane;
	
	/**
	 * File loader for the 3DS file format.
	 */
	public class Max3DSParser extends ParserBase
	{
		private const LIMIT:uint = 64998;
		private var _startedParsing : Boolean;
		private var _mesh:Mesh;
		private var _meshList:Vector.<MaterialRef> = new Vector.<MaterialRef>();
		private var _materialList:Vector.<MaterialDefinition> = new Vector.<MaterialDefinition>();
		private var _geometry:Geometry;
		private var _materialName:String;
		private var _activeData:FaceData;
		private var _indv:uint;
		private var _ind:uint;
		private var _induv:uint;
		private var _dependencyCount:uint = 0;
		private var _transform:Matrix3D;
		private var _holder:Vector3D;
		
		
		//>----- Color Types --------------------------------------------------------
		
		private const AMBIENT:String = "ambient";
		private const DIFFUSE:String = "diffuse";
		private const SPECULAR:String = "specular";
		private const GLOSS:String = "gloss";
		
		//>----- Main Chunks --------------------------------------------------------
		
		//private const PRIMARY:int = 0x4D4D;
		private const EDIT3DS:int = 0x3D3D;  // Start of our actual objects
		private const KEYF3DS:int = 0xB000;  // Start of the keyframe information
		
		//>----- General Chunks -----------------------------------------------------
		
		//private const VERSION:int = 0x0002;
		//private const MESH_VERSION:int = 0x3D3E;
		//private const KFVERSION:int = 0x0005;
		private const COLOR_F:int = 0x0010;
		private const COLOR_RGB:int = 0x0011;
		//private const LIN_COLOR_24:int = 0x0012;
		//private const LIN_COLOR_F:int = 0x0013;
		//private const INT_PERCENTAGE:int = 0x0030;
		//private const FLOAT_PERC:int = 0x0031;
		//private const MASTER_SCALE:int = 0x0100;
		//private const IMAGE_FILE:int = 0x1100;
		//private const AMBIENT_LIGHT:int = 0X2100;
		
		//>----- Object Chunks -----------------------------------------------------
		
		private const MESH:int = 0x4000;
		private const MESH_OBJECT:int = 0x4100;
		private const MESH_VERTICES:int = 0x4110;
		//private const VERTEX_FLAGS:int = 0x4111;
		private const MESH_FACES:int = 0x4120;
		private const MESH_MATER:int = 0x4130;
		private const MESH_TEX_VERT:int = 0x4140;
		//private const MESH_XFMATRIX:int = 0x4160;
		//private const MESH_COLOR_IND:int = 0x4165;
		//private const MESH_TEX_INFO:int = 0x4170;
		//private const HEIRARCHY:int = 0x4F00;
		
		//>----- Material Chunks ---------------------------------------------------
		
		private const MATERIAL:int = 0xAFFF;
		private const MAT_NAME:int = 0xA000;
		private const MAT_AMBIENT:int = 0xA010;
		private const MAT_DIFFUSE:int = 0xA020;
		private const MAT_SPECULAR:int = 0xA030;
		private const MAT_SHININESS:int = 0xA040;
		//private const MAT_FALLOFF:int = 0xA052;
		//private const MAT_EMISSIVE:int = 0xA080;
		//private const MAT_SHADER:int = 0xA100;
		private const MAT_TEXMAP:int = 0xA200;
		private const MAT_TEXFLNM:int = 0xA300;
		//private const OBJ_LIGHT:int = 0x4600;
		//private const OBJ_CAMERA:int = 0x4700;
		
		//>----- KeyFrames Chunks --------------------------------------------------
		
		private const ANIM_HEADER:int = 0xB00A;
		private const ANIM_OBJ:int = 0xB002;
		private const ANIM_NAME:int = 0xB010;
		private const ANIM_PIVOT:int = 0xB013;
		//private const ANIM_POS:int = 0xB020;
		//private const ANIM_ROT:int = 0xB021;
		//private const ANIM_SCALE:int = 0xB022;
		
		
		/**
		 * Max3DSParser provides a parser for the 3ds data type.
		 * @param uri The url or id of the data or file to be parsed.
		 * @param extra The holder for extra contextual data that the parser might need.
		 */
		public function Max3DSParser()
		{
			super(ParserDataFormat.BINARY);
		}
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "3ds";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data : *) : Boolean 
		{
			var ba : ByteArray;
			
			ba = ByteArray(data);
			ba.position = 0;
			
			// "Magic" two first bytes of 3DS are 0x4d4d
			return (ba.readShort() == 0x4d4d);
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency:ResourceDependency):void
		{
			if (resourceDependency.assets.length != 1)
				return;
			
			var resource:BitmapDataAsset = resourceDependency.assets[0] as BitmapDataAsset;
			_dependencyCount--;
			
			if (resource && resource.bitmapData && isBitmapDataValid(resource.bitmapData))
				setSourceToMaterial(resourceDependency.id, resource.bitmapData);
			
			if(_dependencyCount == 0)
				buildMaterials();
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			if (resourceDependency.assets.length != 1)
				return;
			
			var resource:BitmapDataAsset = resourceDependency.assets[0] as BitmapDataAsset;
			_dependencyCount--;
			
			if(_dependencyCount == 0)
				buildMaterials();
		}
		
		
		/**
		 * @inheritDoc
		 */
		protected override function proceedParsing() : Boolean
		{
			if(!_startedParsing){
				_startedParsing = true;
				_byteData.position = 0;
				_byteData.endian = Endian.LITTLE_ENDIAN;
				
				//first chunk is always the primary, so we simply read it and parse it
				var chunk:Chunk3ds = new Chunk3ds();
				readChunk(chunk);
				parse3DS(chunk);
				if(!parsingFailure){
					buildMeshGeometry();
					
					if(_dependencyCount == 0)
						buildMaterials();
					
					return PARSING_DONE;
				}
				
				return MORE_TO_PARSE;
			} else{
				return MORE_TO_PARSE;
			}
		}
		
		/**
		 * Read id and length of 3ds chunk
		 * @param chunk 
		 */		
		private function readChunk(chunk:Chunk3ds):void
		{
			try{
				chunk.id = _byteData.readUnsignedShort();
				chunk.length = _byteData.readUnsignedInt();
				chunk.bytesRead = 6;
			} catch (e:Error){
				parsingFailure = true;
				throw new Error("3DS file probably damaged");
			}
		}
		
		/**
		 * Skips past a chunk. If we don't understand the meaning of a chunk id,
		 * we just skip past it.
		 * @param chunk
		 */		
		private function skipChunk(chunk:Chunk3ds):void
		{
			_byteData.position += chunk.length - chunk.bytesRead;
			chunk.bytesRead = chunk.length;
		}
		
		/**
		 * Read the base 3DS object.
		 * @param chunk
		 */		
		private function parse3DS(chunk:Chunk3ds):void
		{
			while (chunk.bytesRead < chunk.length)
			{
				var subChunk:Chunk3ds = new Chunk3ds();
				readChunk(subChunk);
				switch (subChunk.id)
				{
					case EDIT3DS:
						parseEdit3DS(subChunk);
						break;
					case KEYF3DS:
						parseKey3DS(subChunk);
						break;
					default:
						skipChunk(subChunk);
				}
				chunk.bytesRead += subChunk.length;
			}
		}
		
		/**
		 * Read the Edit chunk
		 * @param chunk
		 */
		private function parseEdit3DS(chunk:Chunk3ds):void
		{
			while (chunk.bytesRead < chunk.length) {
				var subChunk:Chunk3ds = new Chunk3ds();
				readChunk(subChunk);
				switch (subChunk.id) {
					case MATERIAL:
						parseMaterial(subChunk);
						break;
					case MESH:
						readMeshName(subChunk);
						parseMesh(subChunk);
						
						/*todo
						if (centerMeshes) {
						_geometry.maxX = -Infinity;
						_geometry.minX = Infinity;
						_geometry.maxY = -Infinity;
						_geometry.minY = Infinity;
						_geometry.maxZ = -Infinity;
						_geometry.minZ = Infinity;
						for each (var _vertex:Vertex in _verticesDictionary) {
						if (_geometry.maxX < _vertex._x)
						_geometry.maxX = _vertex._x;
						if (_geometry.minX > _vertex._x)
						_geometry.minX = _vertex._x;
						if (_geometry.maxY < _vertex._y)
						_geometry.maxY = _vertex._y;
						if (_geometry.minY > _vertex._y)
						_geometry.minY = _vertex._y;
						if (_geometry.maxZ < _vertex._z)
						_geometry.maxZ = _vertex._z;
						if (_geometry.minZ > _vertex._z)
						_geometry.minZ = _vertex._z;
						}
						}*/
						
						break;
					default:
						skipChunk(subChunk);
				}
				
				chunk.bytesRead += subChunk.length;
			}
		}
		
		/**
		 * Read the Key chunk
		 * @param chunk
		 */
		private function parseKey3DS(chunk:Chunk3ds):void
		{
			while (chunk.bytesRead < chunk.length)
			{
				var subChunk:Chunk3ds = new Chunk3ds();
				readChunk(subChunk);
				switch (subChunk.id)
				{
					case ANIM_HEADER:
						testChunk(subChunk);
						break;
					case ANIM_OBJ:
						parseAnimation(subChunk);
						break;
					default:
						skipChunk(subChunk);
				}
				
				chunk.bytesRead += subChunk.length;
			}
		}
		
		private function testChunk(chunk:Chunk3ds):void
		{
			_byteData.position += chunk.length - chunk.bytesRead;
			chunk.bytesRead = chunk.length;
		}
		
		//*****MATERIALS *******
		private function buildMaterials():void
		{
			var md:MaterialDefinition;
			var m:Mesh;
			var matLength:uint = _materialList.length;
			var i:uint;
			var j:uint;
			var matref:MaterialRef;
			var bmMaterial:BitmapMaterial;
			for(i = 0;i<_meshList.length;++i){
				matref = _meshList[i];
				for(j = 0;j<matLength;++j){
					md = _materialList[j];
					if(md.materialID == matref.materialID){
						bmMaterial = BitmapMaterial(matref.mesh.material);
						bmMaterial.bitmapData = md.bitmapData;
						/* to do split
						bmMaterial.ambientMethod = md.ambientColor;
						bmMaterial.specularMethod = md.specularColor;
						bmMaterial.diffuseMethod = md.diffuseColor;
						//need normalize probably
						bmMaterial.gloss = md.gloss;
						bmMaterial.specular = md.specular;
						*/
						_meshList.splice(i, 1);
						--i;
					}
				}			 
			}
		}
		
		private function setSourceToMaterial(id:String, bitmapData:BitmapData ):void
		{
			var md:MaterialDefinition;
			for(var i:uint = 0;i<_materialList.length;++i){
				md = _materialList[i];
				if(md.materialID == id){
					md.bitmapData = bitmapData;
					break;
				}
			}
			
			if(_dependencyCount == 0)
				buildMaterials();
		}
		
		private function parseMaterial(chunk:Chunk3ds):void
		{
			while (chunk.bytesRead < chunk.length) {
				var subChunk:Chunk3ds = new Chunk3ds();
				readChunk(subChunk);
				switch (subChunk.id) {
					case MAT_NAME:
						readMaterialName(subChunk);
						break;
					case MAT_AMBIENT:
						readColor(AMBIENT);
						break;
					case MAT_DIFFUSE:
						readColor(DIFFUSE);
						break;
					case MAT_SPECULAR:
						readColor(SPECULAR);
						break;
					case MAT_SHININESS:
						readColor(GLOSS);
						break;
					case MAT_TEXMAP:
						parseMaterial(subChunk);
						break;
					case MAT_TEXFLNM:
						readTextureFileName(subChunk);
						break;
					default:
						skipChunk(subChunk);
				}
				chunk.bytesRead += subChunk.length;
			}
		}
		
		private function readMaterialName(chunk:Chunk3ds):void
		{
			_materialName = readASCIIZString(_byteData);
			chunk.bytesRead = chunk.length;
		}
		
		private function readTextureFileName(chunk:Chunk3ds):void
		{
			var filename:String = readASCIIZString(_byteData);
			var ext:String = filename.substring(filename.length-4, filename.length).toLowerCase();
			
			if(ext == ".jpg" || ext == ".png"){
				addDependency(_materialName, new URLRequest(filename));
				++_dependencyCount;
			}
			
			var md:MaterialDefinition = _materialList[_materialList.length-1];
			var defaultmap:BitmapData = defaultBitmapData;
			md.materialID = _materialName;
			md.url = filename;
			md.bitmapData = defaultmap;
			
			chunk.bytesRead = chunk.length;
		}
		
		/**
		 * Read the Mesh Material chunk
		 * @param chunk
		 */
		private function readMeshMaterial(chunk:Chunk3ds):void
		{
			var materialRef:String = readASCIIZString(_byteData);
			_meshList[_meshList.length-1].materialID = materialRef;
			
			chunk.bytesRead += materialRef.length +1;
			
			var numFaces:int = _byteData.readUnsignedShort();
			var i:uint = 0;
			
			chunk.bytesRead += 2;
			// to do look at multiple materials
			var materialid:uint;
			while (i < numFaces) {
				materialid = _byteData.readUnsignedShort();
				chunk.bytesRead += 2;
				i++;
			}
		}
		
		private function readColor(type:String):void
		{
			var value:Number;
			var chunk:Chunk3ds = new Chunk3ds();
			readChunk(chunk);
			switch (chunk.id) {
				case COLOR_RGB:
					value = readColorRGB(chunk);
					break;
				case COLOR_F:
					//trace("COLOR_F not implemented yet");
					skipChunk(chunk);
					break;
				default:
					//trace("unknown ambient color format");
					skipChunk(chunk);
			}
			
			var md:MaterialDefinition = new MaterialDefinition();
			_materialList.push(md);
			//type (shading) md.materialType = "SHADING_MATERIAL" : "COLOR_MATERIAL";
			
			switch (type) {
				case AMBIENT:
					md.ambient = value;
					break;
				case DIFFUSE:
					md.diffuse = value;
					break;
				case SPECULAR:
					md.specular = value;
					break;
				case GLOSS:
					md.gloss = value;
			}
		}
		
		private function readColorRGB(chunk:Chunk3ds):int
		{
			var color:int = 0;
			var i:uint = 0;
			
			while( i < 3) {
				var c:int = _byteData.readUnsignedByte();
				color += c*Math.pow(0x100, 2-i);
				chunk.bytesRead++;
				i++;
			}
			
			return color;
		}
		
		//*****ANIMATION *******
		private function parseAnimation(chunk:Chunk3ds):void
		{
			while (chunk.bytesRead < chunk.length) {
				var subChunk:Chunk3ds = new Chunk3ds();
				readChunk(subChunk);
				switch (subChunk.id) {
					case ANIM_NAME:
						readAnimationName(subChunk);
						break;
					case ANIM_PIVOT:
						readPivot(subChunk);
						break;
					/*
					case ANIM_POS:
					readPosTrack(subChunk);
					break;
					case ANIM_ROT:
					readRotTrack(subChunk);
					break;
					case ANIM_SCALE:
					readScaleTrack(subChunk);
					break;
					*/
					default:
						skipChunk(subChunk);
				}
				
				chunk.bytesRead += subChunk.length;
			}
		}
		
		private function readAnimationName(chunk:Chunk3ds):void
		{
			var meshref:String = readASCIIZString(_byteData);
			chunk.bytesRead += meshref.length + 1;
			
			var flags1:int = _byteData.readUnsignedShort();
			flags1;
			chunk.bytesRead += 2;
			
			var flags2:int = _byteData.readUnsignedShort();
			flags2;
			chunk.bytesRead += 2;
			
			var heirarchy:int = _byteData.readUnsignedShort();
			heirarchy;
			chunk.bytesRead += 2;
		}
		
		private function readPivot(chunk:Chunk3ds):void
		{
			var x:Number = _byteData.readFloat();
			var y:Number = _byteData.readFloat();
			var z:Number = _byteData.readFloat();
			_mesh.transform.appendTranslation(-z, y, -x);
			chunk.bytesRead = chunk.length;
		}
		/*
		private function readPosTrack(chunk:Chunk3ds):void
		{
		_byteData.position += 10;
		
		var numFrames:uint = _byteData.readUnsignedShort();
		
		_byteData.position += 2;
		
		for (var i:int = 0; i < numFrames; ++i)
		{
		_byteData.readUnsignedShort();
		_byteData.readUnsignedInt();
		var x:Number = _byteData.readFloat();
		var y:Number = _byteData.readFloat();
		var z:Number = _byteData.readFloat();
		_mesh.transform.appendTranslation(-z, y, -x);
		}
		
		chunk.bytesRead = chunk.length;
		}
		
		private function readRotTrack(chunk:Chunk3ds):void
		{
		_byteData.position += 10;
		
		var numFrames:uint = _byteData.readUnsignedShort();
		
		_byteData.position += 2;
		
		for (var i:int = 0; i < numFrames; ++i)
		{
		_byteData.readUnsignedShort();
		_byteData.readUnsignedInt();
		var rot:Number = _byteData.readFloat()*180/Math.PI;
		var x:Number = _byteData.readFloat();
		var y:Number = _byteData.readFloat();
		var z:Number = _byteData.readFloat();
		_mesh.transform.prependRotation(rot, new Vector3D(-z, y, -x));
		}
		
		chunk.bytesRead = chunk.length;
		}
		
		private function readScaleTrack(chunk:Chunk3ds):void
		{
		_byteData.position += 10;
		
		var numFrames:uint = _byteData.readUnsignedShort();
		
		_byteData.position += 2;
		
		for (var i:int = 0; i < numFrames; ++i)
		{
		_byteData.readUnsignedShort();
		_byteData.readUnsignedInt();
		var x:Number = _byteData.readFloat();
		var y:Number = _byteData.readFloat();
		var z:Number = _byteData.readFloat();
		_mesh.transform.prependScale(-z, y, -x);
		}
		
		chunk.bytesRead = chunk.length;
		}
		*/
		
		//*****GEOMETRY *******
		private function parseMesh(chunk:Chunk3ds):void
		{
			while (chunk.bytesRead < chunk.length) {
				var subChunk:Chunk3ds = new Chunk3ds();
				readChunk(subChunk);
				switch (subChunk.id) {
					case MESH_OBJECT:
						parseMesh(subChunk);
						break;
					case MESH_VERTICES:
						readMeshVertices(subChunk);
						break;
					case MESH_FACES:
						readMeshFaces(subChunk);
						parseMesh(subChunk);
						break;
					case MESH_MATER:
						readMeshMaterial(subChunk);
						break;
					case MESH_TEX_VERT:
						readMeshTexVert(subChunk);
						break;
					default:
						skipChunk(subChunk);
				}
				chunk.bytesRead += subChunk.length;
			}
		}
		
		private function buildMeshGeometry():void
		{
			var vertices:Vector.<Number> = _activeData.vertices;
			var indices:Vector.<uint> = _activeData.indices;
			var uvs:Vector.<Number> = _activeData.uvs;
			var vertLength:uint ;
			
			var sub_geom:SubGeometry;
			//Todo check on limit
			//for(i=0;i<subGeomsData.length;i+=3){
			sub_geom = new SubGeometry();
			_geometry.addSubGeometry(sub_geom);
			sub_geom.updateVertexData(vertices);
			sub_geom.updateIndexData(indices);
			sub_geom.updateUVData(uvs);
			//}
			
		}
		
		private function readMeshName(chunk:Chunk3ds):void
		{
			if(_ind > 0)
				buildMeshGeometry();
			
			var meshName:String = readASCIIZString(_byteData);
			_geometry = new Geometry();
			_mesh = new Mesh(null, _geometry);
			_mesh.name = meshName;
			var bitmapMaterial:BitmapMaterial = new BitmapMaterial(defaultBitmapData);
			bitmapMaterial.name = meshName;
			_mesh.material = bitmapMaterial;
			var newRef:MaterialRef = new MaterialRef();
			newRef.mesh = _mesh;
			newRef.materialID = _materialName;
			_meshList.push(newRef);
			_activeData = new FaceData();
			_indv = _ind = _induv = 0;
			
			chunk.bytesRead += meshName.length + 1;
			
			// TODO: I think this is happening too early. Make sure this doesn't
			// happen until after the entire mesh data has been parsed.
			finalizeAsset(_mesh);
		}
		
		private function readMeshVertices(chunk:Chunk3ds):void
		{
			var numVerts:int = _byteData.readUnsignedShort();
			var i:uint = 0;
			
			chunk.bytesRead += 2;
			
			if(!_holder){
				_holder = new Vector3D(-1,0,0);
				_transform = new Matrix3D();
				_transform.prependRotation(90, _holder);
			}
			
			while (i < numVerts) {
				_holder.x = _byteData.readFloat();
				_holder.y = _byteData.readFloat();
				_holder.z = _byteData.readFloat();
				
				_holder = _transform.deltaTransformVector(_holder);
				_activeData.vertices[_indv++] = _holder.x;
				_activeData.vertices[_indv++] = _holder.y;
				_activeData.vertices[_indv++] = _holder.z;
				
				chunk.bytesRead += 12;
				i++;
			}
		}
		
		private function readMeshFaces(chunk:Chunk3ds):void
		{
			var numFaces:int = _byteData.readUnsignedShort();
			var i:uint = 0;
			//var bVisible:Boolean;
			
			chunk.bytesRead += 2;
			while (i < numFaces) {
				//invert faces for away
				_activeData.indices[_ind++] = _byteData.readUnsignedShort();
				_activeData.indices[_ind++] = _byteData.readUnsignedShort();
				_activeData.indices[_ind++] = _byteData.readUnsignedShort();
				
				//do we need this? we skip for now
				//bVisible = _byteData.readUnsignedShort() as Boolean;
				_byteData.readUnsignedShort();
				chunk.bytesRead += 8;
				i++;
			}
		}
		
		private function readMeshTexVert(chunk:Chunk3ds):void
		{
			var numUVs:int = _byteData.readUnsignedShort();
			var i:uint = 0;
			
			chunk.bytesRead += 2;
			while (i < numUVs) {
				_activeData.uvs[_induv++] = _byteData.readFloat();
				_activeData.uvs[_induv++] = 1-_byteData.readFloat();
				
				chunk.bytesRead += 8;
				i++;
			}
		}
		
		/**
		 * Reads a null-terminated ascii string out of a byte array.
		 * @param data The byte array to read from.
		 * @return The string read, without the null-terminating character.
		 */		
		private function readASCIIZString(data:ByteArray):String
		{
			var l:int = data.length - data.position;
			var tempByteArray:ByteArray = new ByteArray();
			var i:uint = 0;
			
			while(i < l) {
				var c:int = data.readByte();
				
				if (c == 0)
				{
					break;
				}
				tempByteArray.writeByte(c);
				i++;
			}
			
			var asciiz:String = "";
			tempByteArray.position = 0;
			for (i = 0; i < tempByteArray.length; ++i)
			{
				asciiz += String.fromCharCode(tempByteArray.readByte());
			}
			return asciiz;
		}
		
	}
}

import away3d.entities.Mesh;

import flash.display.BitmapData;

class Chunk3ds
{	
	public var id:int;
	public var length:int;
	public var bytesRead:int;	 
}

class MaterialDefinition
{

	public var materialID:String;
	public var url:String;
	public var bitmapData:BitmapData;
	public var ambient:Number;
	public var diffuse:Number;
	public var specular:Number;
	public var gloss:Number;
	//public var materialType:String;
}

class FaceData
{
	public var vertices : Vector.<Number> = new Vector.<Number>();
	public var uvs : Vector.<Number> = new Vector.<Number>();
	public var indices : Vector.<uint> = new Vector.<uint>();
}

class MaterialRef
{
	public var mesh:Mesh;
	public var materialID:String;
}

