package away3d.loaders.parsers
{
	import away3d.animators.VertexAnimator;
	import away3d.animators.data.VertexAnimation;
	import away3d.animators.data.VertexAnimationMode;
	import away3d.animators.data.VertexAnimationSequence;
	import away3d.animators.data.VertexAnimationState;
	import away3d.arcane;
	import away3d.core.base.Geometry;
	import away3d.core.base.SubGeometry;
	import away3d.entities.Mesh;
	import away3d.library.assets.BitmapDataAsset;
	import away3d.loaders.misc.ResourceDependency;
	import away3d.materials.BitmapMaterial;

	import flash.net.URLRequest;
	import flash.utils.Endian;

	use namespace arcane;
	
	/**
	 * MD2Parser provides a parser for the MD2 data type.
	 */
	public class MD2Parser extends ParserBase
	{
		public static var FPS : int = 6;
		
		private var _parsedHeader : Boolean;
		private var _parsedUV : Boolean;
		private var _parsedFaces : Boolean;
		private var _parsedFrames : Boolean;
		
		private var _ident : uint;
		private var _version : uint;
		private var _skinWidth : uint;
		private var _skinHeight : uint;
		private var _frameSize : uint;
		private var _numSkins : uint;
		private var _numVertices : uint;
		private var _numST : uint;
		private var _numTris : uint;
		private var _numGlCmds : uint;
		private var _numFrames : uint;
		private var _offsetSkins : uint;
		private var _offsetST : uint;
		private var _offsetTris : uint;
		private var _offsetFrames : uint;
		private var _offsetGlCmds : uint;
		private var _offsetEnd : uint;
		
		private var _uvIndices : Vector.<Number>;
		private var _indices : Vector.<uint>;
		private var _vertIndices : Vector.<Number>;
		
		// the current subgeom being built
		private var _animator : VertexAnimator;
		private var _firstSubGeom : SubGeometry;
		private var _uvs : Vector.<Number>;
		private var _finalUV : Vector.<Number>;
		
		private var _materialNames : Vector.<String>;
		private var _textureType : String;
		private var _ignoreTexturePath : Boolean;
		private var _mesh : Mesh;
		private var _geometry : Geometry;
		
		/**
		 * Creates a new MD2Parser object.
		 * @param uri The url or id of the data or file to be parsed.
		 * @param extra The holder for extra contextual data that the parser might need.
		 */
		public function MD2Parser(textureType : String = "jpg", ignoreTexturePath : Boolean = true)
		{
			super(ParserDataFormat.BINARY);
			_textureType = textureType;
			_ignoreTexturePath = ignoreTexturePath;
		}
		
		/**
		 * Indicates whether or not a given file extension is supported by the parser.
		 * @param extension The file extension of a potential file to be parsed.
		 * @return Whether or not the given file type is supported.
		 */
		public static function supportsType(extension : String) : Boolean
		{
			extension = extension.toLowerCase();
			return extension == "md2";
		}
		
		/**
		 * Tests whether a data block can be parsed by the parser.
		 * @param data The data block to potentially be parsed.
		 * @return Whether or not the given data is supported.
		 */
		public static function supportsData(data : *) : Boolean
		{
			// todo: implement
			return false;
		}
		
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependency(resourceDependency : ResourceDependency) : void
		{
			if (resourceDependency.assets.length != 1)
				return;
			
			var asset : BitmapDataAsset = resourceDependency.assets[0] as BitmapDataAsset;
			
			if (asset && asset.bitmapData && isBitmapDataValid(asset.bitmapData))
				BitmapMaterial(_mesh.material).bitmapData = asset.bitmapData;
			
		}
		/**
		 * @inheritDoc
		 */
		override arcane function resolveDependencyFailure(resourceDependency:ResourceDependency):void
		{
			// apply system default
			BitmapMaterial(_mesh.material).bitmapData = defaultBitmapData;
		} 
		
		
		/**
		 * @inheritDoc
		 */
		protected override function proceedParsing() : Boolean
		{
			while (hasTime()) {
				if (!_parsedHeader) {
					_byteData.endian = Endian.LITTLE_ENDIAN;
					
					// TODO: Create a mesh only when encountered (if it makes sense
					// for this file format) and return it using finalizeAsset()
					_mesh = new Mesh;
					_mesh.material = new BitmapMaterial(defaultBitmapData);
					
					_geometry = _mesh.geometry;
					_geometry.animation = new VertexAnimation(2, VertexAnimationMode.ABSOLUTE);
					_animator = new VertexAnimator(VertexAnimationState(_mesh.animationState));
					
					
					// Parse header and decompress body
					parseHeader();
					parseMaterialNames();
				}
					
				else {
					if (!_parsedUV) {
						parseUV();
					}
						
					else {
						if (!_parsedFaces) {
							parseFaces();
						}
							
						else {
							if (!_parsedFrames) {
								parseFrames();
							}
								
							else {
								var sub : SubGeometry = new SubGeometry();
								
								_geometry.addSubGeometry(sub);
								sub.updateVertexData(_firstSubGeom.vertexData);
								sub.updateUVData(_firstSubGeom.UVData);
								sub.updateIndexData(_indices);
								
								return true;
							}
						}
					}
				}
			}
			
			// TODO: Can this be done a nicer fashion for this file format? Or does
			// it always just return a single mesh, in which case this should be fine
			finalizeAsset(_mesh);
			
			return false;
		}
		
		/**
		 * Reads in all that MD2 Header data that is declared as private variables.
		 * I know its a lot, and it looks ugly, but only way to do it in Flash
		 */
		private function parseHeader() : void
		{
			_ident = _byteData.readInt();
			_version = _byteData.readInt();
			_skinWidth = _byteData.readInt();
			_skinHeight = _byteData.readInt();
			_frameSize = _byteData.readInt();
			_numSkins = _byteData.readInt();
			_numVertices = _byteData.readInt();
			_numST = _byteData.readInt();
			_numTris = _byteData.readInt();
			_numGlCmds = _byteData.readInt();
			_numFrames = _byteData.readInt();
			_offsetSkins = _byteData.readInt();
			_offsetST = _byteData.readInt();
			_offsetTris = _byteData.readInt();
			_offsetFrames = _byteData.readInt();
			_offsetGlCmds = _byteData.readInt();
			_offsetEnd = _byteData.readInt();
			
			_parsedHeader = true;
		}
		
		/**
		 * Parses the file names for the materials.
		 */
		private function parseMaterialNames() : void
		{
			var url : String;
			var name : String;
			var extIndex : int;
			var slashIndex : int;
			_materialNames = new Vector.<String>();
			_byteData.position = _offsetSkins;
			
			for (var i : uint = 0; i < _numSkins; ++i) {
				name = _byteData.readUTFBytes(64);
				extIndex = name.lastIndexOf(".");
				if (_ignoreTexturePath) {
					slashIndex = name.lastIndexOf("/");
					if (slashIndex < 0) slashIndex = 0;
				}
				
				name = name.substring(slashIndex+1, extIndex);
				url = name+"."+_textureType;
				
				_materialNames[i] = name;
				// only support 1 skin
				if (dependencies.length == 0)
					addDependency(name, new URLRequest(url));
			}
			
			//_mesh.material.name = _materialNames[0];
		}
		
		/**
		 * Parses the uv data for the mesh.
		 */
		private function parseUV() : void
		{
			var j : uint;
			
			_uvs = new Vector.<Number>(_numST * 2);
			_byteData.position = _offsetST;
			for (var i : uint = 0; i < _numST; i++) {
				_uvs[j++] = _byteData.readShort() / _skinWidth;
				_uvs[j++] = _byteData.readShort() / _skinHeight;
			}
			
			_parsedUV = true;
		}
		
		/**
		 * Parses unique indices for the faces.
		 */
		private function parseFaces() : void
		{
			var a : uint, b : uint, c : uint, ta : uint, tb : uint, tc : uint;
			var i : uint;
			
			_vertIndices = new Vector.<Number>();
			_uvIndices = new Vector.<Number>();
			_indices = new Vector.<uint>();
			
			_byteData.position = _offsetTris;
			
			for (i = 0; i < _numTris; i++) {
				//collect vertex indices
				a = _byteData.readUnsignedShort();
				b = _byteData.readUnsignedShort();
				c = _byteData.readUnsignedShort();
				
				//collect uv indices
				ta = _byteData.readUnsignedShort();
				tb = _byteData.readUnsignedShort();
				tc = _byteData.readUnsignedShort();
				
				addIndex(a, ta);
				addIndex(b, tb);
				addIndex(c, tc);
			}
			
			var len : uint = _uvIndices.length;
			_finalUV = new Vector.<Number>(len * 2, true);
			
			for (i = 0; i < len; ++i) {
				_finalUV[uint(i << 1)] = _uvs[uint(_uvIndices[i] << 1)];
				_finalUV[uint(((i << 1) + 1))] = _uvs[uint((_uvIndices[i] << 1) + 1)];
			}
			
			_parsedFaces = true;
		}
		
		/**
		 * Adds a face index to the list if it doesn't exist yet, based on vertexIndex and uvIndex, and adds the
		 * corresponding vertex and uv data in the correct location.
		 * @param vertexIndex The original index in the vertex list.
		 * @param uvIndex The original index in the uv list.
		 */
		private function addIndex(vertexIndex : uint, uvIndex : uint) : void
		{
			var index : int = findIndex(vertexIndex, uvIndex);
			
			if (index == -1) {
				_indices.push(_vertIndices.length);
				_vertIndices.push(vertexIndex);
				_uvIndices.push(uvIndex);
			}
			else {
				_indices.push(index);
			}
		}
		
		/**
		 * Finds the final index corresponding to the original MD2's vertex and uv indices. Returns -1 if it wasn't added yet.
		 * @param vertexIndex The original index in the vertex list.
		 * @param uvIndex The original index in the uv list.
		 * @return The index of the final mesh corresponding to the original vertex and uv index. -1 if it doesn't exist yet.
		 */
		private function findIndex(vertexIndex : uint, uvIndex : uint) : int
		{
			var len : uint = _vertIndices.length;
			
			for (var i : uint = 0; i < len; ++i)
				if (_vertIndices[i] == vertexIndex && _uvIndices[i] == uvIndex) return i;
			
			return -1;
		}
		
		
		/**
		 * Parses all the frame geometries.
		 */
		private function parseFrames() : void
		{
			var sx : Number, sy : Number, sz : Number;
			var tx : Number, ty : Number, tz : Number;
			var geometry : Geometry;
			var subGeom : SubGeometry;
			var vertLen : uint = _vertIndices.length;
			var fvertices : Vector.<Number>;
			var tvertices : Vector.<Number>;
			var i : uint, j : int, k : uint, ch : uint;
			var name : String = "";
			
			_byteData.position = _offsetFrames;
			
			for (i = 0; i < _numFrames; i++) {
				subGeom = new SubGeometry();
				_firstSubGeom ||= subGeom;
				geometry = new Geometry();
				geometry.addSubGeometry(subGeom);
				tvertices = new Vector.<Number>();
				fvertices = new Vector.<Number>(vertLen * 3, true);
				
				sx = _byteData.readFloat();
				sy = _byteData.readFloat();
				sz = _byteData.readFloat();
				
				tx = _byteData.readFloat();
				ty = _byteData.readFloat();
				tz = _byteData.readFloat();
				
				//read frame name
				name = "";
				k = 0;
				for (j = 0; j < 16; j++) {
					ch = _byteData.readUnsignedByte();
					
					if (uint(ch) >= 0x39 && uint(ch) <= 0x7A && k == 0) {
						name += String.fromCharCode(ch);
					}
					
					if (uint(ch) >= 0x30 && uint(ch) <= 0x39) {
						k++;
					}
				}
				
				// Note, the extra data.position++ in the for loop is there
				// to skip over a byte that holds the "vertex normal index"
				for (j = 0; j < _numVertices; j++,_byteData.position++) {
					tvertices.push(sx * _byteData.readUnsignedByte() + tx, sy * _byteData.readUnsignedByte() + ty, sz * _byteData.readUnsignedByte() + tz);
				}
				
				k = 0;
				for (j = 0; j < vertLen; j++) {
					fvertices[k++] = tvertices[uint(_vertIndices[j] * 3)];
					fvertices[k++] = tvertices[uint(_vertIndices[j] * 3 + 2)];
					fvertices[k++] = tvertices[uint(_vertIndices[j] * 3 + 1)];
				}
				
				subGeom.updateVertexData(fvertices);
				subGeom.updateUVData(_finalUV);
				subGeom.updateIndexData(_indices);
				
				var seq : VertexAnimationSequence = VertexAnimationSequence(_animator.getSequence(name));
				if (!seq) {
					seq = new VertexAnimationSequence(name);
					_animator.addSequence(seq);
				}
				seq.addFrame(geometry, 1000 / FPS);
			}
			
			
			finalizeAsset(_animator);
			_parsedFrames = true;
		}
		
	}
}

